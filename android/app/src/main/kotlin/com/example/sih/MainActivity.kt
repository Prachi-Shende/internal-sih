package com.example.sih

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.wifi.ScanResult
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val STEP_EVENT_CHANNEL = "sih/native_step_events"
    private val IMU_EVENT_CHANNEL = "sih/sensors/imu"
    private val WIFI_SCAN_CHANNEL = "sih/wifi_scan"

    private val ACTIVITY_RECOGNITION_REQUEST = 1001
    private val WIFI_PERMISSIONS_REQUEST = 1002

    private lateinit var sensorManager: SensorManager
    private var wifiManager: WifiManager? = null

    // Step Sensors
    private var stepCounterSensor: Sensor? = null
    private var stepDetectorSensor: Sensor? = null
    private var stepSensorListener: SensorEventListener? = null
    private var pendingStepEventSink: EventChannel.EventSink? = null

    // IMU / Orientation Sensors
    private var accelerometerSensor: Sensor? = null
    private var gyroscopeSensor: Sensor? = null
    private var rotationVectorSensor: Sensor? = null
    private var magnetometerSensor: Sensor? = null
    private var imuSensorListener: SensorEventListener? = null
    private var imuEventSink: EventChannel.EventSink? = null

    // Wi-Fi Scanning
    private var wifiScanReceiver: BroadcastReceiver? = null
    private var pendingScanResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var scanTimeoutRunnable: Runnable? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager

        stepCounterSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        stepDetectorSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)

        accelerometerSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        gyroscopeSensor = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
        // Prefer Game Rotation Vector (unaffected by magnetic anomalies indoors), fallback to Rotation Vector
        rotationVectorSensor = sensorManager.getDefaultSensor(Sensor.TYPE_GAME_ROTATION_VECTOR)
            ?: sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        magnetometerSensor = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)

        // 1. Step Events Channel
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            STEP_EVENT_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                if (events == null) return
                pendingStepEventSink = events
                checkPermissionAndStartSteps()
            }

            override fun onCancel(arguments: Any?) {
                stopStepSensors()
                pendingStepEventSink = null
            }
        })

        // 2. High-Rate IMU & Rotation Vector Channel
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            IMU_EVENT_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                if (events == null) return
                imuEventSink = events
                startImuSensors()
            }

            override fun onCancel(arguments: Any?) {
                stopImuSensors()
                imuEventSink = null
            }
        })

        // 3. Real Android Wi-Fi Scan Method Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIFI_SCAN_CHANNEL
        ).setMethodCallHandler { call, result ->
            handleWifiMethodCall(call, result)
        }
    }

    private fun handleWifiMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val wm = wifiManager
        if (wm == null) {
            result.error("UNAVAILABLE", "WifiManager not available on this device", null)
            return
        }

        when (call.method) {
            "isWifiEnabled" -> {
                try {
                    result.success(wm.isWifiEnabled)
                } catch (e: Exception) {
                    result.success(false)
                }
            }

            "checkPermissions" -> {
                val fineLocationGranted = ContextCompat.checkSelfPermission(
                    this, Manifest.permission.ACCESS_FINE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
                val wifiStateGranted = ContextCompat.checkSelfPermission(
                    this, Manifest.permission.ACCESS_WIFI_STATE
                ) == PackageManager.PERMISSION_GRANTED

                result.success(fineLocationGranted && wifiStateGranted)
            }

            "requestPermissions" -> {
                val permissions = mutableListOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                    Manifest.permission.ACCESS_WIFI_STATE,
                    Manifest.permission.CHANGE_WIFI_STATE
                )
                ActivityCompat.requestPermissions(
                    this,
                    permissions.toTypedArray(),
                    WIFI_PERMISSIONS_REQUEST
                )
                result.success(true)
            }

            "getScanResults" -> {
                try {
                    val scanResults = formatScanResults(wm.scanResults)
                    result.success(scanResults)
                } catch (e: Exception) {
                    result.error("SCAN_ERROR", e.message, null)
                }
            }

            "startScan" -> {
                val fineLocation = ContextCompat.checkSelfPermission(
                    this, Manifest.permission.ACCESS_FINE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED

                if (!fineLocation) {
                    result.error("PERMISSION_DENIED", "ACCESS_FINE_LOCATION permission is required for Wi-Fi scanning", null)
                    return
                }

                if (!wm.isWifiEnabled) {
                    result.error("WIFI_DISABLED", "Wi-Fi radio is disabled", null)
                    return
                }

                // If a scan is already waiting, cancel previous timeout
                scanTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
                pendingScanResult?.error("SUPERSEDED", "New scan requested", null)
                pendingScanResult = result

                registerWifiScanReceiver()

                val scanStarted = try {
                    wm.startScan()
                } catch (e: Exception) {
                    false
                }

                // Setup 3.5-second timeout fallback (returns latest cached scan results if broadcast takes too long or throttled)
                scanTimeoutRunnable = Runnable {
                    val res = pendingScanResult
                    pendingScanResult = null
                    if (res != null) {
                        try {
                            val cachedResults = formatScanResults(wm.scanResults)
                            res.success(cachedResults)
                        } catch (e: Exception) {
                            res.success(emptyList<Map<String, Any>>())
                        }
                    }
                }
                mainHandler.postDelayed(scanTimeoutRunnable!!, 3500)
            }

            else -> result.notImplemented()
        }
    }

    private fun registerWifiScanReceiver() {
        if (wifiScanReceiver != null) return

        wifiScanReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == WifiManager.SCAN_RESULTS_AVAILABLE_ACTION) {
                    scanTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
                    val res = pendingScanResult
                    pendingScanResult = null

                    if (res != null) {
                        try {
                            val results = wifiManager?.scanResults ?: emptyList()
                            val formatted = formatScanResults(results)
                            res.success(formatted)
                        } catch (e: Exception) {
                            res.error("SCAN_ERROR", e.message, null)
                        }
                    }
                }
            }
        }

        val intentFilter = IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION)
        registerReceiver(wifiScanReceiver, intentFilter)
    }

    private fun unregisterWifiScanReceiver() {
        wifiScanReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                // Ignore if not registered
            }
        }
        wifiScanReceiver = null
    }

    private fun formatScanResults(results: List<ScanResult>?): List<Map<String, Any>> {
        if (results == null) return emptyList()

        return results.map { scan ->
            mapOf(
                "bssid" to (scan.BSSID ?: ""),
                "ssid" to (scan.SSID ?: ""),
                "rssi" to scan.level,
                "frequencyMhz" to scan.frequency,
                "timestamp" to scan.timestamp
            )
        }
    }

    // Step Counter / Detector Permission & Registration
    private fun checkPermissionAndStartSteps() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val permissionGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACTIVITY_RECOGNITION
            ) == PackageManager.PERMISSION_GRANTED

            if (permissionGranted) {
                startStepSensors()
            } else {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
                    ACTIVITY_RECOGNITION_REQUEST
                )
            }
        } else {
            startStepSensors()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == ACTIVITY_RECOGNITION_REQUEST) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startStepSensors()
            }
        }
    }

    private fun startStepSensors() {
        if (stepSensorListener != null) return

        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent?) {
                if (event == null) return
                val sink = pendingStepEventSink ?: return

                when (event.sensor.type) {
                    Sensor.TYPE_STEP_DETECTOR -> {
                        sink.success(
                            mapOf(
                                "event" to "step_detected",
                                "count" to 1,
                                "timestamp" to System.currentTimeMillis()
                            )
                        )
                    }
                    Sensor.TYPE_STEP_COUNTER -> {
                        sink.success(
                            mapOf(
                                "event" to "step_counter",
                                "totalSteps" to event.values[0].toInt(),
                                "timestamp" to System.currentTimeMillis()
                            )
                        )
                    }
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        stepSensorListener = listener

        stepDetectorSensor?.let {
            sensorManager.registerListener(listener, it, SensorManager.SENSOR_DELAY_FASTEST)
        }
        stepCounterSensor?.let {
            sensorManager.registerListener(listener, it, SensorManager.SENSOR_DELAY_FASTEST)
        }
    }

    private fun stopStepSensors() {
        stepSensorListener?.let { sensorManager.unregisterListener(it) }
        stepSensorListener = null
    }

    // High-Rate IMU Sensor Listener
    private fun startImuSensors() {
        if (imuSensorListener != null) return

        val samplingDelay = SensorManager.SENSOR_DELAY_GAME

        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent?) {
                if (event == null) return
                val sink = imuEventSink ?: return

                val timeSec = event.timestamp / 1_000_000_000.0

                when (event.sensor.type) {
                    Sensor.TYPE_ACCELEROMETER -> {
                        sink.success(
                            mapOf(
                                "sensor" to "accel",
                                "x" to event.values[0].toDouble(),
                                "y" to event.values[1].toDouble(),
                                "z" to event.values[2].toDouble(),
                                "timestamp" to timeSec
                            )
                        )
                    }
                    Sensor.TYPE_GYROSCOPE -> {
                        sink.success(
                            mapOf(
                                "sensor" to "gyro",
                                "x" to event.values[0].toDouble(),
                                "y" to event.values[1].toDouble(),
                                "z" to event.values[2].toDouble(),
                                "timestamp" to timeSec
                            )
                        )
                    }
                    Sensor.TYPE_GAME_ROTATION_VECTOR, Sensor.TYPE_ROTATION_VECTOR -> {
                        val quat = FloatArray(4)
                        SensorManager.getQuaternionFromVector(quat, event.values)
                        sink.success(
                            mapOf(
                                "sensor" to "rotation_vector",
                                "qw" to quat[0].toDouble(),
                                "qx" to quat[1].toDouble(),
                                "qy" to quat[2].toDouble(),
                                "qz" to quat[3].toDouble(),
                                "timestamp" to timeSec
                            )
                        )
                    }
                    Sensor.TYPE_MAGNETIC_FIELD -> {
                        sink.success(
                            mapOf(
                                "sensor" to "mag",
                                "x" to event.values[0].toDouble(),
                                "y" to event.values[1].toDouble(),
                                "z" to event.values[2].toDouble(),
                                "timestamp" to timeSec
                            )
                        )
                    }
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        imuSensorListener = listener

        accelerometerSensor?.let {
            sensorManager.registerListener(listener, it, samplingDelay)
        }
        gyroscopeSensor?.let {
            sensorManager.registerListener(listener, it, samplingDelay)
        }
        rotationVectorSensor?.let {
            sensorManager.registerListener(listener, it, samplingDelay)
        }
        magnetometerSensor?.let {
            sensorManager.registerListener(listener, it, samplingDelay)
        }
    }

    private fun stopImuSensors() {
        imuSensorListener?.let { sensorManager.unregisterListener(it) }
        imuSensorListener = null
    }

    override fun onDestroy() {
        stopStepSensors()
        stopImuSensors()
        unregisterWifiScanReceiver()
        scanTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        super.onDestroy()
    }
}
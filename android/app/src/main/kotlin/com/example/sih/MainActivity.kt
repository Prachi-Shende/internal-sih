package com.example.sih

import android.Manifest
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    private val STEP_EVENT_CHANNEL = "sih/native_step_events"
    private val IMU_EVENT_CHANNEL = "sih/sensors/imu"

    private val ACTIVITY_RECOGNITION_REQUEST = 1001

    private lateinit var sensorManager: SensorManager

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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager

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
                imuEventSink = events
                val samplingDelay = when ((arguments as? Map<*, *>)?.get("rate") as? String) {
                    "fastest" -> SensorManager.SENSOR_DELAY_FASTEST
                    "game" -> SensorManager.SENSOR_DELAY_GAME
                    "ui" -> SensorManager.SENSOR_DELAY_UI
                    else -> SensorManager.SENSOR_DELAY_GAME
                }
                startImuSensors(samplingDelay)
            }

            override fun onCancel(arguments: Any?) {
                stopImuSensors()
                imuEventSink = null
            }
        })
    }

    private fun checkPermissionAndStartSteps() {
        val eventSink = pendingStepEventSink ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACTIVITY_RECOGNITION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            eventSink.success(
                mapOf(
                    "type" to "status",
                    "status" to "REQUESTING_PERMISSION"
                )
            )
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
                ACTIVITY_RECOGNITION_REQUEST
            )
            return
        }

        startStepSensors(eventSink)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != ACTIVITY_RECOGNITION_REQUEST) return

        val eventSink = pendingStepEventSink ?: return

        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            startStepSensors(eventSink)
        } else {
            eventSink.success(
                mapOf(
                    "type" to "status",
                    "status" to "PERMISSION_DENIED"
                )
            )
            eventSink.error(
                "ACTIVITY_RECOGNITION_DENIED",
                "Physical activity permission was denied.",
                null
            )
        }
    }

    private fun startStepSensors(eventSink: EventChannel.EventSink) {
        stopStepSensors()

        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                when (event.sensor.type) {
                    Sensor.TYPE_STEP_COUNTER -> {
                        eventSink.success(
                            mapOf(
                                "type" to "counter",
                                "steps" to event.values[0].toInt()
                            )
                        )
                    }
                    Sensor.TYPE_STEP_DETECTOR -> {
                        eventSink.success(
                            mapOf(
                                "type" to "detector",
                                "steps" to 1
                            )
                        )
                    }
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        stepSensorListener = listener
        var registered = false

        stepCounterSensor?.let {
            registered = sensorManager.registerListener(
                listener,
                it,
                SensorManager.SENSOR_DELAY_NORMAL
            ) || registered
        }

        stepDetectorSensor?.let {
            registered = sensorManager.registerListener(
                listener,
                it,
                SensorManager.SENSOR_DELAY_NORMAL
            ) || registered
        }

        if (!registered) {
            eventSink.success(mapOf("type" to "status", "status" to "NO_STEP_SENSOR"))
            eventSink.error("NO_STEP_SENSOR", "Android step sensors could not be registered.", null)
            return
        }

        eventSink.success(mapOf("type" to "status", "status" to "AVAILABLE"))
    }

    private fun stopStepSensors() {
        stepSensorListener?.let { sensorManager.unregisterListener(it) }
        stepSensorListener = null
    }

    private fun startImuSensors(samplingDelay: Int) {
        stopImuSensors()

        val sink = imuEventSink ?: return

        val qArray = FloatArray(4)

        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                val currentSink = imuEventSink ?: return

                // Calculate accurate timestamp in seconds
                val timeSec = System.currentTimeMillis() / 1000.0

                when (event.sensor.type) {
                    Sensor.TYPE_ACCELEROMETER -> {
                        currentSink.success(
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
                        currentSink.success(
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
                        SensorManager.getQuaternionFromVector(qArray, event.values)
                        // qArray is [w, x, y, z] in Android SensorManager
                        val qw = qArray[0].toDouble()
                        val qx = qArray[1].toDouble()
                        val qy = qArray[2].toDouble()
                        val qz = qArray[3].toDouble()

                        currentSink.success(
                            mapOf(
                                "sensor" to "rotation_vector",
                                "qx" to qx,
                                "qy" to qy,
                                "qz" to qz,
                                "qw" to qw,
                                "isGameRotation" to (event.sensor.type == Sensor.TYPE_GAME_ROTATION_VECTOR),
                                "timestamp" to timeSec
                            )
                        )
                    }
                    Sensor.TYPE_MAGNETIC_FIELD -> {
                        currentSink.success(
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
        super.onDestroy()
    }
}
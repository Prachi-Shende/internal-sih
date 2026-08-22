package com.example.sih

import android.Manifest
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    private val STEP_EVENT_CHANNEL = "sih/native_step_events"

    private val ACTIVITY_RECOGNITION_REQUEST = 1001

    private lateinit var sensorManager: SensorManager

    private var stepCounterSensor: Sensor? = null
    private var stepDetectorSensor: Sensor? = null

    private var stepSensorListener: SensorEventListener? = null

    private var pendingEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        sensorManager =
            getSystemService(SENSOR_SERVICE) as SensorManager

        stepCounterSensor =
            sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

        stepDetectorSensor =
            sensorManager.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            STEP_EVENT_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {

            override fun onListen(
                arguments: Any?,
                events: EventChannel.EventSink?
            ) {

                if (events == null) return

                pendingEventSink = events

                checkPermissionAndStart()
            }

            override fun onCancel(arguments: Any?) {

                stopSensors()

                pendingEventSink = null
            }
        })
    }

    private fun checkPermissionAndStart() {

        val eventSink = pendingEventSink ?: return

        // Android 10+
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
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

        startSensors(eventSink)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {

        super.onRequestPermissionsResult(
            requestCode,
            permissions,
            grantResults
        )

        if (requestCode != ACTIVITY_RECOGNITION_REQUEST) {
            return
        }

        val eventSink = pendingEventSink ?: return

        if (
            grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        ) {

            startSensors(eventSink)

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

    private fun startSensors(
        eventSink: EventChannel.EventSink
    ) {

        stopSensors()

        val listener = object : SensorEventListener {

            override fun onSensorChanged(event: SensorEvent) {

                when (event.sensor.type) {

                    Sensor.TYPE_STEP_COUNTER -> {

                        val totalSteps =
                            event.values[0].toInt()

                        eventSink.success(
                            mapOf(
                                "type" to "counter",
                                "steps" to totalSteps
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

            override fun onAccuracyChanged(
                sensor: Sensor?,
                accuracy: Int
            ) {
                // Not required.
            }
        }

        stepSensorListener = listener

        var registered = false

        stepCounterSensor?.let {

            registered =
                sensorManager.registerListener(
                    listener,
                    it,
                    SensorManager.SENSOR_DELAY_NORMAL
                ) || registered
        }

        stepDetectorSensor?.let {

            registered =
                sensorManager.registerListener(
                    listener,
                    it,
                    SensorManager.SENSOR_DELAY_NORMAL
                ) || registered
        }

        if (!registered) {

            eventSink.success(
                mapOf(
                    "type" to "status",
                    "status" to "NO_STEP_SENSOR"
                )
            )

            eventSink.error(
                "NO_STEP_SENSOR",
                "Android step sensors could not be registered.",
                null
            )

            return
        }

        eventSink.success(
            mapOf(
                "type" to "status",
                "status" to "AVAILABLE"
            )
        )
    }

    private fun stopSensors() {

        stepSensorListener?.let {

            sensorManager.unregisterListener(it)

        }

        stepSensorListener = null
    }

    override fun onDestroy() {

        stopSensors()

        super.onDestroy()
    }
}
import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

class ImuSensor {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;

  AccelerometerEvent? latestAccelerometer;
  GyroscopeEvent? latestGyroscope;
  MagnetometerEvent? latestMagnetometer;

  void Function()? onSensorUpdate;

  void start() {
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      latestAccelerometer = event;
      onSensorUpdate?.call();
    });

    _gyroscopeSubscription = gyroscopeEventStream().listen((event) {
      latestGyroscope = event;
      onSensorUpdate?.call();
    });

    _magnetometerSubscription = magnetometerEventStream().listen((event) {
      latestMagnetometer = event;
      onSensorUpdate?.call();
    });
  }

  void stop() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
  }

  void dispose() {
    stop();
  }
}

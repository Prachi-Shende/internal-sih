import 'dart:async';
import 'dart:math';

import 'models/sensor_snapshot.dart';
import 'sensors/imu_sensor.dart';
import 'sensors/step_sensor.dart';
import 'sensors/gps_sensor.dart';

class SensorCoordinator {
  final ImuSensor imuSensor;
  final StepSensor stepSensor;
  final GpsSensor gpsSensor;
  double _filteredMagnitude = 0.0;
  double _previousMagnitude = 0.0;

  bool _isWalking = false;

  Timer? _gpsTimer;

  double? _accelerationMagnitude;

  double? _latitude;
  double? _longitude;
  double? _gpsAccuracy;

  int _steps = 0;

  String _movementStatus = 'unknown';

  bool _gpsAvailable = false;
  bool _stepSensorAvailable = false;

  void Function(SensorSnapshot snapshot)? onSnapshot;

  SensorCoordinator({
    required this.imuSensor,
    required this.stepSensor,
    required this.gpsSensor,
  });

  void start() {
    _startImu();
    _startSteps();
    _startGps();
  }

  void _startImu() {
    imuSensor.onSensorUpdate = () {
      final accel = imuSensor.latestAccelerometer;

      if (accel != null) {
        final magnitude = sqrt(
          accel.x * accel.x + accel.y * accel.y + accel.z * accel.z,
        );

        _accelerationMagnitude = magnitude;

        _filteredMagnitude = 0.15 * magnitude + 0.85 * _filteredMagnitude;

        final delta = (_filteredMagnitude - _previousMagnitude).abs();

        _previousMagnitude = _filteredMagnitude;

        _isWalking = delta > 0.8;

        _movementStatus = _isWalking ? 'walking' : 'stationary';
      }

      _emitSnapshot();
    };

    imuSensor.start();
  }

  void _startSteps() {
    stepSensor.start(
      onStepUpdate: (steps) {
        _steps = steps;
        _emitSnapshot();
      },

      onStatusUpdate: (status) {
        _stepSensorAvailable = status == 'AVAILABLE';
        _movementStatus = status;
        _emitSnapshot();
      },

      onError: (error) {
        _stepSensorAvailable = false;
        _emitSnapshot();
      },
    );
  }

  void _startGps() {
    _readGps();

    _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) => _readGps());
  }

  Future<void> _readGps() async {
    try {
      final reading = await gpsSensor.getCurrentPosition();

      if (reading == null) {
        _gpsAvailable = false;
      } else {
        _latitude = reading.latitude;
        _longitude = reading.longitude;
        _gpsAccuracy = reading.accuracy;
        _gpsAvailable = true;
      }

      _emitSnapshot();
    } catch (_) {
      _gpsAvailable = false;
      _emitSnapshot();
    }
  }

  void _emitSnapshot() {
    onSnapshot?.call(
      SensorSnapshot(
        latitude: _latitude,
        longitude: _longitude,
        gpsAccuracy: _gpsAccuracy,
        accelerationMagnitude: _accelerationMagnitude,
        steps: _steps,
        movementStatus: _movementStatus,
        gpsAvailable: _gpsAvailable,
        stepSensorAvailable: _stepSensorAvailable,
        timestamp: DateTime.now(),
      ),
    );
  }

  void dispose() {
    _gpsTimer?.cancel();
    imuSensor.dispose();
    stepSensor.dispose();
  }
}

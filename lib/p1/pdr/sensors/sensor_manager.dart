import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/orientation_sample.dart';
import '../models/pdr_config.dart';
import '../models/sensor_sample.dart';

/// Unified sensor reading containing synchronized IMU data and hardware orientation.
typedef PdrSensorPacket = ({
  SensorSample sample,
  OrientationSample? orientation,
});

/// Sensor acquisition layer that coordinates high-rate native Android channels
/// with graceful fallback to `sensors_plus` plugins.
class SensorManager {
  final PdrConfig config;

  static const EventChannel _nativeImuChannel = EventChannel('sih/sensors/imu');

  StreamSubscription? _nativeSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<MagnetometerEvent>? _magSubscription;

  final StreamController<PdrSensorPacket> _packetController =
      StreamController<PdrSensorPacket>.broadcast();

  Stream<PdrSensorPacket> get sensorStream => _packetController.stream;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  bool _isUsingNative = false;
  bool get isUsingNative => _isUsingNative;

  // Temporary sample alignment buffers for fallback mode
  double? _lastTimestamp;
  double _lastAx = 0.0, _lastAy = 0.0, _lastAz = 9.81;
  double _lastGx = 0.0, _lastGy = 0.0, _lastGz = 0.0;
  double? _lastMx, _lastMy, _lastMz;
  OrientationSample? _latestOrientation;

  SensorManager({required this.config});

  /// Starts listening to sensor streams.
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    _lastTimestamp = null;

    try {
      _startNativeStream();
    } catch (e) {
      debugPrint('SensorManager: Native IMU channel failed, falling back to sensors_plus: $e');
      _startFallbackSensorsPlus();
    }
  }

  void _startNativeStream() {
    _isUsingNative = true;
    final rateParam = config.samplingRateHz >= 90.0
        ? 'fastest'
        : (config.samplingRateHz >= 45.0 ? 'game' : 'ui');

    _nativeSubscription = _nativeImuChannel
        .receiveBroadcastStream({'rate': rateParam})
        .listen(
      (dynamic event) {
        if (event is! Map) return;

        final sensorType = event['sensor'] as String?;
        final t = (event['timestamp'] as num?)?.toDouble() ?? (DateTime.now().millisecondsSinceEpoch / 1000.0);

        if (sensorType == 'rotation_vector') {
          final qx = (event['qx'] as num?)?.toDouble() ?? 0.0;
          final qy = (event['qy'] as num?)?.toDouble() ?? 0.0;
          final qz = (event['qz'] as num?)?.toDouble() ?? 0.0;
          final qw = (event['qw'] as num?)?.toDouble() ?? 1.0;
          final isGame = event['isGameRotation'] as bool? ?? true;

          _latestOrientation = OrientationSample.fromQuaternion(
            timestamp: t,
            qx: qx,
            qy: qy,
            qz: qz,
            qw: qw,
            isGameRotation: isGame,
            confidence: 0.95,
          );
          return;
        }

        if (sensorType == 'accel') {
          final ax = (event['x'] as num?)?.toDouble() ?? 0.0;
          final ay = (event['y'] as num?)?.toDouble() ?? 0.0;
          final az = (event['z'] as num?)?.toDouble() ?? 9.81;

          _processAndEmit(
            t: t,
            ax: ax,
            ay: ay,
            az: az,
            gx: _lastGx,
            gy: _lastGy,
            gz: _lastGz,
            mx: _lastMx,
            my: _lastMy,
            mz: _lastMz,
            orientation: _latestOrientation,
          );
        } else if (sensorType == 'gyro') {
          _lastGx = (event['x'] as num?)?.toDouble() ?? 0.0;
          _lastGy = (event['y'] as num?)?.toDouble() ?? 0.0;
          _lastGz = (event['z'] as num?)?.toDouble() ?? 0.0;
        } else if (sensorType == 'mag') {
          _lastMx = (event['x'] as num?)?.toDouble();
          _lastMy = (event['y'] as num?)?.toDouble();
          _lastMz = (event['z'] as num?)?.toDouble();
        }
      },
      onError: (dynamic err) {
        debugPrint('Native IMU stream error: $err. Switching to fallback.');
        _stopNative();
        _startFallbackSensorsPlus();
      },
      cancelOnError: false,
    );
  }

  void _startFallbackSensorsPlus() {
    _isUsingNative = false;

    // Use sensors_plus streams with sampling period
    final samplingDuration = Duration(microseconds: (1000000 / config.samplingRateHz).round());

    _accelSubscription = accelerometerEventStream(samplingPeriod: samplingDuration).listen((event) {
      final nowSec = DateTime.now().millisecondsSinceEpoch / 1000.0;
      _lastAx = event.x;
      _lastAy = event.y;
      _lastAz = event.z;

      _processAndEmit(
        t: nowSec,
        ax: _lastAx,
        ay: _lastAy,
        az: _lastAz,
        gx: _lastGx,
        gy: _lastGy,
        gz: _lastGz,
        mx: _lastMx,
        my: _lastMy,
        mz: _lastMz,
        orientation: null, // will be handled by internal AHRS solver
      );
    });

    _gyroSubscription = gyroscopeEventStream(samplingPeriod: samplingDuration).listen((event) {
      _lastGx = event.x;
      _lastGy = event.y;
      _lastGz = event.z;
    });

    _magSubscription = magnetometerEventStream(samplingPeriod: samplingDuration).listen((event) {
      _lastMx = event.x;
      _lastMy = event.y;
      _lastMz = event.z;
    });
  }

  void _processAndEmit({
    required double t,
    required double ax,
    required double ay,
    required double az,
    required double gx,
    required double gy,
    required double gz,
    double? mx,
    double? my,
    double? mz,
    OrientationSample? orientation,
  }) {
    if (_lastTimestamp == null) {
      _lastTimestamp = t;
      return;
    }

    final dt = t - _lastTimestamp!;

    // Sanity checks on delta time dt
    if (dt <= 0.0) {
      // Duplicate or out-of-order timestamp, discard
      return;
    }

    if (dt > 0.5) {
      // Large gap (e.g. background suspension), reset baseline dt
      _lastTimestamp = t;
      return;
    }

    _lastTimestamp = t;

    final sample = SensorSample(
      timestamp: t,
      dt: dt,
      ax: ax,
      ay: ay,
      az: az,
      gx: gx,
      gy: gy,
      gz: gz,
      mx: mx,
      my: my,
      mz: mz,
    );

    if (!sample.isValid) return;

    if (!_packetController.isClosed) {
      _packetController.add((sample: sample, orientation: orientation));
    }
  }

  void _stopNative() {
    _nativeSubscription?.cancel();
    _nativeSubscription = null;
  }

  void _stopFallback() {
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _magSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription = null;
    _magSubscription = null;
  }

  /// Stops all active sensor streams.
  void stop() {
    _isRunning = false;
    _stopNative();
    _stopFallback();
    _lastTimestamp = null;
  }

  void dispose() {
    stop();
    _packetController.close();
  }
}

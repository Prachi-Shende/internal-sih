import 'dart:math';

/// Represents a single raw/aligned sensor snapshot from the device's IMU.
class SensorSample {
  /// Timestamp in seconds (derived from hardware/clock time).
  final double timestamp;

  /// Time interval since the previous sample in seconds.
  final double dt;

  /// Accelerometer readings in phone frame (m/s²), including gravity.
  final double ax;
  final double ay;
  final double az;

  /// Gyroscope readings in phone frame (rad/s).
  final double gx;
  final double gy;
  final double gz;

  /// Optional Magnetometer readings in phone frame (μT).
  final double? mx;
  final double? my;
  final double? mz;

  const SensorSample({
    required this.timestamp,
    required this.dt,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    this.mx,
    this.my,
    this.mz,
  });

  /// Computes the raw total acceleration magnitude: ||a|| = sqrt(ax² + ay² + az²).
  double get accelerationMagnitude => sqrt(ax * ax + ay * ay + az * az);

  /// Computes the gyroscope rotational energy / angular rate norm: ||g|| = sqrt(gx² + gy² + gz²).
  double get gyroMagnitude => sqrt(gx * gx + gy * gy + gz * gz);

  /// Checks if all values in this sample are valid finite numbers.
  bool get isValid =>
      timestamp.isFinite &&
      dt.isFinite &&
      dt > 0.0 &&
      ax.isFinite &&
      ay.isFinite &&
      az.isFinite &&
      gx.isFinite &&
      gy.isFinite &&
      gz.isFinite;

  @override
  String toString() {
    return 'SensorSample(t=${timestamp.toStringAsFixed(3)}s, dt=${(dt * 1000).toStringAsFixed(1)}ms, '
        'acc=[${ax.toStringAsFixed(2)}, ${ay.toStringAsFixed(2)}, ${az.toStringAsFixed(2)}], '
        'gyro=[${gx.toStringAsFixed(2)}, ${gy.toStringAsFixed(2)}, ${gz.toStringAsFixed(2)}])';
  }
}

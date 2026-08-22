import 'dart:math';

import '../models/orientation_sample.dart';
import '../models/sensor_sample.dart';

/// Lightweight on-device Complementary / AHRS orientation filter.
/// Fuses gyroscope angular velocity with accelerometer gravity direction
/// to produce a smooth, drift-free unit quaternion without gimbal lock.
class AhrsFusion {
  // Quaternion state [qx, qy, qz, qw]
  double qx = 0.0;
  double qy = 0.0;
  double qz = 0.0;
  double qw = 1.0;

  /// Accelerometer correction gain (0.01 to 0.05).
  final double gain;

  AhrsFusion({this.gain = 0.03});

  /// Updates orientation estimate with a new IMU sample.
  OrientationSample update(SensorSample sample) {
    final dt = sample.dt;
    if (dt <= 0.0 || dt > 0.2) {
      return _buildOrientationSample(sample.timestamp);
    }

    // 1. Gyroscope Quaternion Integration (First-order Runge-Kutta)
    // q_dot = 0.5 * q * omega
    final gx = sample.gx;
    final gy = sample.gy;
    final gz = sample.gz;

    final qDotX = 0.5 * (qw * gx + qy * gz - qz * gy);
    final qDotY = 0.5 * (qw * gy - qx * gz + qz * gx);
    final qDotZ = 0.5 * (qw * gz + qx * gy - qy * gx);
    final qDotW = 0.5 * (-qx * gx - qy * gy - qz * gz);

    qx += qDotX * dt;
    qy += qDotY * dt;
    qz += qDotZ * dt;
    qw += qDotW * dt;

    // 2. Accelerometer Gravity Correction (Tilt Correction)
    final ax = sample.ax;
    final ay = sample.ay;
    final az = sample.az;
    final aNorm = sqrt(ax * ax + ay * ay + az * az);

    // Only apply gravity correction if acceleration is close to 1g (stationary or steady motion)
    if (aNorm > 8.0 && aNorm < 11.5) {
      final nax = ax / aNorm;
      final nay = ay / aNorm;
      final naz = az / aNorm;

      // Estimated gravity direction in body frame from current quaternion
      // v = [2(qx*qz - qw*qy), 2(qw*qx + qy*qz), qw^2 - qx^2 - qy^2 + qz^2]
      final vx = 2.0 * (qx * qz - qw * qy);
      final vy = 2.0 * (qw * qx + qy * qz);
      final vz = qw * qw - qx * qx - qy * qy + qz * qz;

      // Error is cross product between measured gravity and estimated gravity
      final ex = nay * vz - naz * vy;
      final ey = naz * vx - nax * vz;
      final ez = nax * vy - nay * vx;

      // Apply proportional correction
      qx += ex * gain;
      qy += ey * gain;
      qz += ez * gain;
    }

    // 3. Normalize Quaternion
    _normalize();

    return _buildOrientationSample(sample.timestamp);
  }

  void _normalize() {
    final norm = sqrt(qx * qx + qy * qy + qz * qz + qw * qw);
    if (norm > 0.0) {
      qx /= norm;
      qy /= norm;
      qz /= norm;
      qw /= norm;
    } else {
      qx = 0.0;
      qy = 0.0;
      qz = 0.0;
      qw = 1.0;
    }
  }

  OrientationSample _buildOrientationSample(double timestamp) {
    return OrientationSample.fromQuaternion(
      timestamp: timestamp,
      qx: qx,
      qy: qy,
      qz: qz,
      qw: qw,
      isGameRotation: true,
      confidence: 0.85,
    );
  }

  void reset({double initialHeadingDeg = 0.0}) {
    // Yaw rotation around Z axis in ENU: yaw = (90 - heading) * pi / 180
    final yaw = (90.0 - initialHeadingDeg) * pi / 180.0;
    qx = 0.0;
    qy = 0.0;
    qz = sin(yaw / 2.0);
    qw = cos(yaw / 2.0);
  }
}

import 'dart:math';

/// Represents 3D orientation in world coordinate frame (ENU: East-North-Up).
class OrientationSample {
  final double timestamp;

  /// Quaternion components [qx, qy, qz, qw] representing rotation
  /// from phone frame to world navigation frame (ENU).
  final double qx;
  final double qy;
  final double qz;
  final double qw;

  /// Heading in radians [0, 2π), where 0 = North, π/2 = East, π = South, 3π/2 = West.
  final double headingRadians;

  /// Heading in degrees [0, 360).
  final double headingDegrees;

  /// Pitch angle in radians (rotation around X axis).
  final double pitch;

  /// Roll angle in radians (rotation around Y axis).
  final double roll;

  /// True if computed from Game Rotation Vector (6-DoF gyro+accel, no magnetic drift).
  final bool isGameRotation;

  /// Orientation confidence score [0.0, 1.0].
  final double confidence;

  const OrientationSample({
    required this.timestamp,
    required this.qx,
    required this.qy,
    required this.qz,
    required this.qw,
    required this.headingRadians,
    required this.headingDegrees,
    required this.pitch,
    required this.roll,
    this.isGameRotation = true,
    this.confidence = 1.0,
  });

  /// Factory constructor to compute Euler angles and heading from a unit quaternion.
  factory OrientationSample.fromQuaternion({
    required double timestamp,
    required double qx,
    required double qy,
    required double qz,
    required double qw,
    bool isGameRotation = true,
    double confidence = 1.0,
  }) {
    // Normalize quaternion if needed
    final norm = sqrt(qx * qx + qy * qy + qz * qz + qw * qw);
    final nqx = norm > 0.0 ? qx / norm : 0.0;
    final nqy = norm > 0.0 ? qy / norm : 0.0;
    final nqz = norm > 0.0 ? qz / norm : 0.0;
    final nqw = norm > 0.0 ? qw / norm : 1.0;

    // Roll (x-axis rotation)
    final sinrCosp = 2.0 * (nqw * nqx + nqy * nqz);
    final cosrCosp = 1.0 - 2.0 * (nqx * nqx + nqy * nqy);
    final roll = atan2(sinrCosp, cosrCosp);

    // Pitch (y-axis rotation)
    final sinp = 2.0 * (nqw * nqy - nqz * nqx);
    final pitch = sinp.abs() >= 1.0
        ? (sinp.isNegative ? -pi / 2 : pi / 2)
        : asin(sinp);

    // Yaw / Azimuth (z-axis rotation)
    final sinyCosp = 2.0 * (nqw * nqz + nqx * nqy);
    final cosyCosp = 1.0 - 2.0 * (nqy * nqy + nqz * nqz);
    final yaw = atan2(sinyCosp, cosyCosp);

    // Convert Yaw to clockwise heading from North (0° = North, 90° = East, 180° = South, 270° = West)
    // Standard ENU Yaw is counter-clockwise from East: 0 = East, π/2 = North.
    // Navigation azimuth = (90° - yaw_in_deg) % 360°.
    final rawHeadingDeg = (90.0 - (yaw * 180.0 / pi)) % 360.0;
    final headingDegrees = rawHeadingDeg < 0.0 ? rawHeadingDeg + 360.0 : rawHeadingDeg;
    final headingRadians = headingDegrees * pi / 180.0;

    return OrientationSample(
      timestamp: timestamp,
      qx: nqx,
      qy: nqy,
      qz: nqz,
      qw: nqw,
      headingRadians: headingRadians,
      headingDegrees: headingDegrees,
      pitch: pitch,
      roll: roll,
      isGameRotation: isGameRotation,
      confidence: confidence,
    );
  }

  /// Identity orientation (facing North, horizontal).
  static const OrientationSample identity = OrientationSample(
    timestamp: 0.0,
    qx: 0.0,
    qy: 0.0,
    qz: 0.0,
    qw: 1.0,
    headingRadians: 0.0,
    headingDegrees: 0.0,
    pitch: 0.0,
    roll: 0.0,
    isGameRotation: true,
    confidence: 0.5,
  );

  @override
  String toString() {
    return 'OrientationSample(heading=${headingDegrees.toStringAsFixed(1)}°, '
        'pitch=${(pitch * 180 / pi).toStringAsFixed(1)}°, roll=${(roll * 180 / pi).toStringAsFixed(1)}°, '
        'conf=${(confidence * 100).toStringAsFixed(0)}%)';
  }
}

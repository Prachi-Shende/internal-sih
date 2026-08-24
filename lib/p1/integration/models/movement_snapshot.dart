import '../../pdr/models/pdr_state.dart';

/// Clean application-level DTO representing pedestrian kinematics and inertial dead reckoning metrics.
/// Consumed by P2 (Map Navigation), P3 (Gait & Hazard Intelligence), and P6 (UI).
class MovementSnapshot {
  /// Cumulative validated steps detected by the sensor pipeline.
  final int steps;

  /// Accumulated walking distance in meters since session start.
  final double distanceMeters;

  /// Smoothed walking heading in degrees [0.0, 360.0) clockwise from True North.
  final double headingDegrees;

  /// Cardinal / intercardinal direction (e.g. 'NORTH', 'NORTH_EAST', 'EAST', etc.).
  final String direction;

  /// Estimated walking speed in meters per second.
  final double speedMps;

  /// Estimated stride / step length in meters.
  final double strideLengthMeters;

  /// True if zero-motion / resting state is detected.
  final bool isStationary;

  /// True if active walking gait is detected.
  final bool isWalking;

  /// Confidence score of step detection in range [0.0, 1.0].
  final double stepConfidence;

  /// Confidence score of heading estimation in range [0.0, 1.0].
  final double headingConfidence;

  /// Composite PDR inertial confidence score in range [0.0, 1.0].
  final double overallConfidence;

  /// Eastward local Cartesian offset in meters from origin (relative frame).
  final double localX;

  /// Northward local Cartesian offset in meters from origin (relative frame).
  final double localY;

  /// Timestamp when this movement snapshot was recorded.
  final DateTime timestamp;

  const MovementSnapshot({
    required this.steps,
    required this.distanceMeters,
    required this.headingDegrees,
    required this.direction,
    required this.speedMps,
    required this.strideLengthMeters,
    required this.isStationary,
    required this.isWalking,
    required this.stepConfidence,
    required this.headingConfidence,
    required this.overallConfidence,
    required this.localX,
    required this.localY,
    required this.timestamp,
  });

  /// Computes human-readable cardinal string from heading angle.
  static String computeCardinalDirection(double degrees) {
    const directions = [
      'NORTH',
      'NORTH_EAST',
      'EAST',
      'SOUTH_EAST',
      'SOUTH',
      'SOUTH_WEST',
      'WEST',
      'NORTH_WEST',
    ];
    final normalized = (degrees % 360 + 360) % 360;
    final index = ((normalized + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  /// Factory constructing [MovementSnapshot] directly from existing [PdrState].
  factory MovementSnapshot.fromPdrState(
    PdrState? state, {
    DateTime? fallbackTimestamp,
  }) {
    final s = state ?? PdrState.initial();
    return MovementSnapshot(
      steps: s.stepCount,
      distanceMeters: s.totalDistance,
      headingDegrees: s.headingDegrees,
      direction: computeCardinalDirection(s.headingDegrees),
      speedMps: s.velocity,
      strideLengthMeters: s.currentStepLength,
      isStationary: s.isStationary,
      isWalking: s.isWalking,
      stepConfidence: s.stepConfidence,
      headingConfidence: s.headingConfidence,
      overallConfidence: s.overallConfidence,
      localX: s.x,
      localY: s.y,
      timestamp: fallbackTimestamp ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'steps': steps,
      'distanceMeters': distanceMeters,
      'headingDegrees': headingDegrees,
      'direction': direction,
      'speedMps': speedMps,
      'strideLengthMeters': strideLengthMeters,
      'isStationary': isStationary,
      'isWalking': isWalking,
      'stepConfidence': stepConfidence,
      'headingConfidence': headingConfidence,
      'overallConfidence': overallConfidence,
      'localX': localX,
      'localY': localY,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory MovementSnapshot.fromJson(Map<String, dynamic> json) {
    return MovementSnapshot(
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      headingDegrees: (json['headingDegrees'] as num?)?.toDouble() ?? 0.0,
      direction: json['direction'] as String? ?? 'NORTH',
      speedMps: (json['speedMps'] as num?)?.toDouble() ?? 0.0,
      strideLengthMeters: (json['strideLengthMeters'] as num?)?.toDouble() ?? 0.70,
      isStationary: (json['isStationary'] as bool?) ?? true,
      isWalking: (json['isWalking'] as bool?) ?? false,
      stepConfidence: (json['stepConfidence'] as num?)?.toDouble() ?? 0.8,
      headingConfidence: (json['headingConfidence'] as num?)?.toDouble() ?? 0.9,
      overallConfidence: (json['overallConfidence'] as num?)?.toDouble() ?? 0.85,
      localX: (json['localX'] as num?)?.toDouble() ?? 0.0,
      localY: (json['localY'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'MovementSnapshot(steps: $steps, dist: ${distanceMeters.toStringAsFixed(1)}m, '
        'heading: ${headingDegrees.toStringAsFixed(0)}° ($direction), speed: ${speedMps.toStringAsFixed(2)}m/s, '
        'status: ${isStationary ? "STATIONARY" : (isWalking ? "WALKING" : "MOVING")})';
  }
}

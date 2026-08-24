import 'dart:math';

/// A 2D point representation in local Cartesian coordinates (meters).
class Point2D {
  final double x; // East meters
  final double y; // North meters
  final double timestamp;
  final double? headingDegrees;

  const Point2D({
    required this.x,
    required this.y,
    required this.timestamp,
    this.headingDegrees,
  });

  double distanceTo(Point2D other) {
    final dx = other.x - x;
    final dy = other.y - y;
    return sqrt(dx * dx + dy * dy);
  }

  @override
  String toString() => 'Point2D(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}

/// Comprehensive real-time state of the Pedestrian Dead Reckoning (PDR) engine.
class PdrState {
  /// Eastward position in meters relative to origin.
  final double x;

  /// Northward position in meters relative to origin.
  final double y;

  /// Total accumulated walking distance in meters.
  final double totalDistance;

  /// Total validated steps detected.
  final int stepCount;

  /// Current estimated stride / step length in meters.
  final double currentStepLength;

  /// Current smoothed heading in degrees [0, 360), clockwise from North.
  final double headingDegrees;

  /// Current smoothed heading in radians.
  final double headingRadians;

  /// Estimated walking speed / velocity in m/s.
  final double velocity;

  /// Whether the user is currently stationary (zero-motion detected).
  final bool isStationary;

  /// Whether the user is actively taking steps.
  final bool isWalking;

  /// Confidence score of recent step detections [0.0, 1.0].
  final double stepConfidence;

  /// Confidence score of current heading estimation [0.0, 1.0].
  final double headingConfidence;

  /// Overall composite PDR system confidence score [0.0, 1.0].
  final double overallConfidence;

  /// Timestamp of the last accepted step (seconds).
  final double lastStepTimestamp;

  /// Timestamp of this state snapshot (seconds).
  final double timestamp;

  /// Full historical trajectory points.
  final List<Point2D> trajectory;

  const PdrState({
    required this.x,
    required this.y,
    required this.totalDistance,
    required this.stepCount,
    required this.currentStepLength,
    required this.headingDegrees,
    required this.headingRadians,
    required this.velocity,
    required this.isStationary,
    required this.isWalking,
    required this.stepConfidence,
    required this.headingConfidence,
    required this.overallConfidence,
    required this.lastStepTimestamp,
    required this.timestamp,
    required this.trajectory,
  });

  /// Initial idle state.
  static PdrState initial({double initialHeading = 0.0}) {
    final rad = initialHeading * pi / 180.0;
    return PdrState(
      x: 0.0,
      y: 0.0,
      totalDistance: 0.0,
      stepCount: 0,
      currentStepLength: 0.70,
      headingDegrees: initialHeading,
      headingRadians: rad,
      velocity: 0.0,
      isStationary: true,
      isWalking: false,
      stepConfidence: 0.8,
      headingConfidence: 0.9,
      overallConfidence: 0.85,
      lastStepTimestamp: 0.0,
      timestamp: 0.0,
      trajectory: [Point2D(x: 0.0, y: 0.0, timestamp: 0.0, headingDegrees: initialHeading)],
    );
  }

  PdrState copyWith({
    double? x,
    double? y,
    double? totalDistance,
    int? stepCount,
    double? currentStepLength,
    double? headingDegrees,
    double? headingRadians,
    double? velocity,
    bool? isStationary,
    bool? isWalking,
    double? stepConfidence,
    double? headingConfidence,
    double? overallConfidence,
    double? lastStepTimestamp,
    double? timestamp,
    List<Point2D>? trajectory,
  }) {
    return PdrState(
      x: x ?? this.x,
      y: y ?? this.y,
      totalDistance: totalDistance ?? this.totalDistance,
      stepCount: stepCount ?? this.stepCount,
      currentStepLength: currentStepLength ?? this.currentStepLength,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      headingRadians: headingRadians ?? this.headingRadians,
      velocity: velocity ?? this.velocity,
      isStationary: isStationary ?? this.isStationary,
      isWalking: isWalking ?? this.isWalking,
      stepConfidence: stepConfidence ?? this.stepConfidence,
      headingConfidence: headingConfidence ?? this.headingConfidence,
      overallConfidence: overallConfidence ?? this.overallConfidence,
      lastStepTimestamp: lastStepTimestamp ?? this.lastStepTimestamp,
      timestamp: timestamp ?? this.timestamp,
      trajectory: trajectory ?? this.trajectory,
    );
  }

  @override
  String toString() {
    return 'PdrState(pos=(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})m, '
        'dist=${totalDistance.toStringAsFixed(2)}m, steps=$stepCount, '
        'L=${currentStepLength.toStringAsFixed(2)}m, heading=${headingDegrees.toStringAsFixed(1)}°, '
        'conf=${(overallConfidence * 100).toStringAsFixed(0)}%, '
        'status=${isStationary ? "STATIONARY" : (isWalking ? "WALKING" : "MOVING")})';
  }
}

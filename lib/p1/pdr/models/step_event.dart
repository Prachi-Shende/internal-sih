/// Detailed record of an accepted pedestrian step.
class StepEvent {
  /// Sequential index of the step (1-indexed).
  final int stepIndex;

  /// Hardware timestamp when the step peak occurred (in seconds).
  final double timestamp;

  /// Estimated stride/step length for this step (in meters).
  final double stepLength;

  /// Heading when the step occurred (in degrees [0, 360), 0=North, 90=East).
  final double headingDegrees;

  /// Heading in radians.
  final double headingRadians;

  /// Eastward displacement in meters (dx = stepLength * sin(heading)).
  final double dx;

  /// Northward displacement in meters (dy = stepLength * cos(heading)).
  final double dy;

  /// Updated East coordinate after this step (in meters).
  final double x;

  /// Updated North coordinate after this step (in meters).
  final double y;

  /// Confidence score for this individual step [0.0, 1.0].
  final double confidence;

  /// Peak acceleration magnitude during this step cycle (m/s²).
  final double peakAcceleration;

  /// Valley/trough acceleration magnitude during this step cycle (m/s²).
  final double valleyAcceleration;

  /// Peak prominence (peak - valley) in m/s².
  final double prominence;

  /// Duration of this step cycle in seconds (interval from previous step).
  final double stepDuration;

  const StepEvent({
    required this.stepIndex,
    required this.timestamp,
    required this.stepLength,
    required this.headingDegrees,
    required this.headingRadians,
    required this.dx,
    required this.dy,
    required this.x,
    required this.y,
    required this.confidence,
    required this.peakAcceleration,
    required this.valleyAcceleration,
    required this.prominence,
    required this.stepDuration,
  });

  @override
  String toString() {
    return 'StepEvent(#$stepIndex, L=${stepLength.toStringAsFixed(2)}m, '
        'heading=${headingDegrees.toStringAsFixed(1)}°, pos=(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}), '
        'conf=${(confidence * 100).toStringAsFixed(0)}%, duration=${stepDuration.toStringAsFixed(2)}s)';
  }
}

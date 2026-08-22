import '../models/position_estimate.dart';

/// Result produced when evaluating a positioning estimate against spatial map constraints.
class MapConstraintResult {
  /// The constrained position (snapped or original).
  final PositionEstimate constrainedPosition;

  /// Whether the coordinate was modified to obey floor plan / road network geometry.
  final bool wasSnapped;

  /// Displacement distance in meters between unconstrained and constrained points.
  final double distanceCorrectionMeters;

  /// Whether the coordinate is physically plausible and accepted.
  final bool isAccepted;

  const MapConstraintResult({
    required this.constrainedPosition,
    required this.wasSnapped,
    this.distanceCorrectionMeters = 0.0,
    required this.isAccepted,
  });
}

/// Abstract contract for spatial geometry and corridor constraint filters (Step 4 foundation).
abstract class MapConstraintProvider {
  /// Applies map boundary and obstacle constraints to an incoming position estimate.
  Future<MapConstraintResult> constrain(PositionEstimate position);
}

/// Baseline pass-through provider used prior to full Step 4 map-matching integration.
class PassThroughMapConstraintProvider implements MapConstraintProvider {
  @override
  Future<MapConstraintResult> constrain(PositionEstimate position) async {
    return MapConstraintResult(
      constrainedPosition: position,
      wasSnapped: false,
      distanceCorrectionMeters: 0.0,
      isAccepted: true,
    );
  }
}

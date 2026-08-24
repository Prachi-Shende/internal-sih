import 'dart:math';

import '../../pdr/utils/geo_utils.dart';
import '../models/position_estimate.dart';
import '../models/position_source.dart';
import 'map_constraint_provider.dart';
import 'walkable_graph.dart';

/// Offline corridor map matching service that constrains drifting dead-reckoning positions
/// to verified walkable corridors and hallways.
class GraphMapMatcher implements MapConstraintProvider {
  final WalkableGraph graph;

  /// Maximum distance in meters to snap a drifting position to a walkable hallway segment.
  final double maxSnappingDistanceMeters;

  const GraphMapMatcher({
    required this.graph,
    this.maxSnappingDistanceMeters = 15.0,
  });

  @override
  Future<MapConstraintResult> constrain(PositionEstimate position) async {
    if (graph.isEmpty) {
      return MapConstraintResult(
        constrainedPosition: position,
        wasSnapped: false,
        distanceCorrectionMeters: 0.0,
        isAccepted: true,
      );
    }

    final snapped = graph.snapToNearestEdge(position.latitude, position.longitude);
    if (snapped == null || snapped.distanceMeters > maxSnappingDistanceMeters) {
      // Too far from known walkable corridors or outside graph boundary.
      // Retain original unconstrained estimate to avoid artificial distortion.
      return MapConstraintResult(
        constrainedPosition: position,
        wasSnapped: false,
        distanceCorrectionMeters: 0.0,
        isAccepted: true,
      );
    }

    // Apply corridor constraint with modest uncertainty improvement
    final improvedUncertainty = max(3.0, position.uncertaintyMeters * 0.85);
    final improvedConfidence = min(0.98, position.confidence + 0.05);

    final constrainedPos = PositionEstimate(
      latitude: snapped.latitude,
      longitude: snapped.longitude,
      source: position.source == PositionSource.gps
          ? PositionSource.gps
          : PositionSource.mapMatched,
      confidence: improvedConfidence,
      uncertaintyMeters: improvedUncertainty,
      timestamp: position.timestamp,
      speedMps: position.speedMps,
      headingDegrees: position.headingDegrees,
      isAbsolute: position.isAbsolute,
      isDegraded: position.isDegraded,
    );

    final correctionDist = GeoUtils.haversineDistance(
      lat1: position.latitude,
      lon1: position.longitude,
      lat2: snapped.latitude,
      lon2: snapped.longitude,
    );

    return MapConstraintResult(
      constrainedPosition: constrainedPos,
      wasSnapped: correctionDist > 0.1,
      distanceCorrectionMeters: correctionDist,
      isAccepted: true,
    );
  }

  /// Synchronous helper to constrain a position.
  PositionEstimate constrainSync(PositionEstimate position) {
    if (graph.isEmpty) return position;
    final snapped = graph.snapToNearestEdge(position.latitude, position.longitude);
    if (snapped == null || snapped.distanceMeters > maxSnappingDistanceMeters) {
      return position;
    }

    final improvedUncertainty = max(3.0, position.uncertaintyMeters * 0.85);
    final improvedConfidence = min(0.98, position.confidence + 0.05);

    return PositionEstimate(
      latitude: snapped.latitude,
      longitude: snapped.longitude,
      source: position.source == PositionSource.gps
          ? PositionSource.gps
          : PositionSource.mapMatched,
      confidence: improvedConfidence,
      uncertaintyMeters: improvedUncertainty,
      timestamp: position.timestamp,
      speedMps: position.speedMps,
      headingDegrees: position.headingDegrees,
      isAbsolute: position.isAbsolute,
      isDegraded: position.isDegraded,
    );
  }
}

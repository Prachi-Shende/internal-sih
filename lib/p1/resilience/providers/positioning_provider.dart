import '../models/position_estimate.dart';
import '../models/position_source.dart';

/// Common abstraction contract for all underlying positioning technologies.
abstract class PositioningProvider {
  /// The positioning source classification of this provider.
  PositionSource get source;

  /// Whether this positioning provider is currently active and delivering valid fixes.
  bool get isAvailable;

  /// Continuous stream of position estimates produced by this provider.
  Stream<PositionEstimate> get positionStream;

  /// Most recent position estimate output.
  PositionEstimate? get currentPosition;

  /// Starts positioning acquisition.
  Future<void> start();

  /// Stops positioning acquisition.
  Future<void> stop();
}

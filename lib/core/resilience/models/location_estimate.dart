import 'positioning_source.dart';

class LocationEstimate {
  final double latitude;
  final double longitude;

  /// Estimated horizontal accuracy in metres.
  final double accuracy;

  /// Estimated uncertainty radius in metres.
  final double uncertaintyRadius;

  final DateTime timestamp;

  final PositioningSource source;

  const LocationEstimate({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.uncertaintyRadius,
    required this.timestamp,
    required this.source,
  });

  @override
  String toString() {
    return 'LocationEstimate('
        'lat: $latitude, '
        'lon: $longitude, '
        'accuracy: ${accuracy.toStringAsFixed(1)}m, '
        'uncertainty: ${uncertaintyRadius.toStringAsFixed(1)}m, '
        'source: $source'
        ')';
  }
}

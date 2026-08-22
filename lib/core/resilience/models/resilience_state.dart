import 'location_estimate.dart';
import 'positioning_source.dart';

enum ConnectivityStatus { online, offline, unknown }

enum ResilienceMode { normal, gpsFallback, offline, gpsAndInternetFallback }

class ResilienceState {
  final LocationEstimate? location;

  final PositioningSource positioningSource;

  final ConnectivityStatus connectivityStatus;

  final ResilienceMode mode;

  final bool gpsAvailable;
  final bool internetAvailable;

  final double confidence;

  final DateTime timestamp;

  const ResilienceState({
    required this.location,
    required this.positioningSource,
    required this.connectivityStatus,
    required this.mode,
    required this.gpsAvailable,
    required this.internetAvailable,
    required this.confidence,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'ResilienceState('
        'source: $positioningSource, '
        'mode: $mode, '
        'gps: $gpsAvailable, '
        'internet: $internetAvailable, '
        'confidence: ${(confidence * 100).toStringAsFixed(1)}%'
        ')';
  }
}

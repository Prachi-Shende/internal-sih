import 'position_source.dart';

/// Unified best-estimate position output produced by the positioning subsystem.
class PositionEstimate {
  /// WGS-84 Latitude in degrees.
  final double latitude;

  /// WGS-84 Longitude in degrees.
  final double longitude;

  /// Underlying source of this position estimate.
  final PositionSource source;

  /// Confidence score of this estimate [0.0 to 1.0].
  final double confidence;

  /// Estimated horizontal uncertainty / circular error probability in meters.
  final double uncertaintyMeters;

  /// Timestamp when this measurement / estimate was generated.
  final DateTime timestamp;

  /// True if position is derived from absolute global coordinates (e.g. GPS, Anchor).
  /// False if derived purely from relative inertial propagation.
  final bool isAbsolute;

  /// True if positioning quality has degraded (e.g. dead reckoning without fresh GPS anchor).
  final bool isDegraded;

  /// Optional heading angle in degrees [0, 360) clockwise from True North.
  final double? headingDegrees;

  /// Optional instantaneous speed estimate in meters per second.
  final double? speedMps;

  /// Optional altitude in meters above sea level.
  final double? altitude;

  const PositionEstimate({
    required this.latitude,
    required this.longitude,
    required this.source,
    required this.confidence,
    required this.uncertaintyMeters,
    required this.timestamp,
    required this.isAbsolute,
    required this.isDegraded,
    this.headingDegrees,
    this.speedMps,
    this.altitude,
  });

  PositionEstimate copyWith({
    double? latitude,
    double? longitude,
    PositionSource? source,
    double? confidence,
    double? uncertaintyMeters,
    DateTime? timestamp,
    bool? isAbsolute,
    bool? isDegraded,
    double? headingDegrees,
    double? speedMps,
    double? altitude,
  }) {
    return PositionEstimate(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      uncertaintyMeters: uncertaintyMeters ?? this.uncertaintyMeters,
      timestamp: timestamp ?? this.timestamp,
      isAbsolute: isAbsolute ?? this.isAbsolute,
      isDegraded: isDegraded ?? this.isDegraded,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      speedMps: speedMps ?? this.speedMps,
      altitude: altitude ?? this.altitude,
    );
  }

  @override
  String toString() {
    return 'PositionEstimate('
        'lat: ${latitude.toStringAsFixed(6)}, '
        'lon: ${longitude.toStringAsFixed(6)}, '
        'source: ${source.name}, '
        'conf: ${(confidence * 100).toStringAsFixed(0)}%, '
        'unc: ±${uncertaintyMeters.toStringAsFixed(1)}m, '
        'deg: $isDegraded)';
  }
}

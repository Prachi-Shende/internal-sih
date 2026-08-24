import '../../resilience/models/position_estimate.dart';

/// Clean application-level DTO representing current geodetic position and quality.
/// Consumed by P2 (Maps), P3 (Safety Risk Intelligence), P5 (Backend), and P6 (UI).
class PositionSnapshot {
  /// Estimated WGS-84 Latitude in degrees. Null if no position fix is available.
  final double? latitude;

  /// Estimated WGS-84 Longitude in degrees. Null if no position fix is available.
  final double? longitude;

  /// Active positioning source (e.g. 'gps', 'pdr', 'wifiFingerprint', 'fused', 'mapMatched', 'lastKnown').
  final String? source;

  /// Estimated positioning confidence score in range [0.0, 1.0].
  final double? confidence;

  /// Horizontal circular error uncertainty in meters.
  final double? uncertaintyMeters;

  /// True if positioning quality has degraded (e.g. dead reckoning without fresh absolute anchor).
  final bool isDegraded;

  /// True if position was derived from an absolute global fix (GPS or matched Wi-Fi landmark).
  final bool isAbsolute;

  /// Timestamp when this position snapshot was recorded.
  final DateTime timestamp;

  const PositionSnapshot({
    this.latitude,
    this.longitude,
    this.source,
    this.confidence,
    this.uncertaintyMeters,
    this.isDegraded = false,
    this.isAbsolute = false,
    required this.timestamp,
  });

  /// Returns true if coordinates are present and non-zero.
  bool get hasValidFix =>
      latitude != null &&
      longitude != null &&
      !(latitude == 0.0 && longitude == 0.0);

  /// Factory converting internal [PositionEstimate] to a public [PositionSnapshot].
  factory PositionSnapshot.fromPositionEstimate(
    PositionEstimate? estimate, {
    DateTime? fallbackTimestamp,
  }) {
    if (estimate == null) {
      return PositionSnapshot(
        latitude: null,
        longitude: null,
        source: null,
        confidence: null,
        uncertaintyMeters: null,
        isDegraded: true,
        isAbsolute: false,
        timestamp: fallbackTimestamp ?? DateTime.now(),
      );
    }

    return PositionSnapshot(
      latitude: estimate.latitude,
      longitude: estimate.longitude,
      source: estimate.source.name,
      confidence: estimate.confidence,
      uncertaintyMeters: estimate.uncertaintyMeters,
      isDegraded: estimate.isDegraded,
      isAbsolute: estimate.isAbsolute,
      timestamp: estimate.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'source': source,
      'confidence': confidence,
      'uncertaintyMeters': uncertaintyMeters,
      'isDegraded': isDegraded,
      'isAbsolute': isAbsolute,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory PositionSnapshot.fromJson(Map<String, dynamic> json) {
    return PositionSnapshot(
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      source: json['source'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      uncertaintyMeters: (json['uncertaintyMeters'] as num?)?.toDouble(),
      isDegraded: (json['isDegraded'] as bool?) ?? false,
      isAbsolute: (json['isAbsolute'] as bool?) ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'PositionSnapshot(lat: ${latitude?.toStringAsFixed(6)}, '
        'lon: ${longitude?.toStringAsFixed(6)}, source: $source, '
        'conf: ${confidence != null ? (confidence! * 100).toStringAsFixed(0) : "null"}%, '
        'unc: ±${uncertaintyMeters?.toStringAsFixed(1) ?? "null"}m)';
  }
}

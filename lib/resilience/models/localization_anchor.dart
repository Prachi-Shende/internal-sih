import 'position_source.dart';
import 'wifi_fingerprint.dart';

/// Represents a known, georeferenced landmark with an associated radio fingerprint.
class LocalizationAnchor {
  /// Unique anchor identifier (e.g. `anchor_hotel_lobby_01`).
  final String id;

  /// Human-readable descriptor for this landmark (e.g. "Hotel Grand Lobby").
  final String name;

  /// WGS-84 Latitude in degrees.
  final double latitude;

  /// WGS-84 Longitude in degrees.
  final double longitude;

  /// Optional vertical floor / level index (0 = Ground, 1 = 1st Floor, -1 = Basement).
  final int? floor;

  /// Stored Wi-Fi radio fingerprint measured at this location.
  final WifiFingerprint fingerprint;

  /// Intrinsic survey confidence of this anchor [0.0 to 1.0].
  final double confidence;

  /// Baseline horizontal uncertainty radius in meters (typically 5m - 12m for Wi-Fi).
  final double uncertaintyMeters;

  /// Position source classification.
  final PositionSource source;

  /// Optional metadata (building ID, venue type, notes).
  final Map<String, dynamic> metadata;

  const LocalizationAnchor({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.floor,
    required this.fingerprint,
    this.confidence = 0.85,
    this.uncertaintyMeters = 8.0,
    this.source = PositionSource.wifiFingerprint,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        if (floor != null) 'floor': floor,
        'fingerprint': fingerprint.toJson(),
        'confidence': confidence,
        'uncertaintyMeters': uncertaintyMeters,
        'source': source.name,
        'metadata': metadata,
      };

  factory LocalizationAnchor.fromJson(Map<String, dynamic> json) {
    return LocalizationAnchor(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      floor: json['floor'] as int?,
      fingerprint: WifiFingerprint.fromJson(json['fingerprint'] as Map<String, dynamic>),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.85,
      uncertaintyMeters: (json['uncertaintyMeters'] as num?)?.toDouble() ?? 8.0,
      source: PositionSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => PositionSource.wifiFingerprint,
      ),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  @override
  String toString() {
    return 'LocalizationAnchor($id - "$name" @ ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)} [±${uncertaintyMeters}m])';
  }
}

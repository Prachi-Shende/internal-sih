import '../../pdr/utils/geo_utils.dart';
import '../models/localization_anchor.dart';
import '../models/position_source.dart';
import '../models/wifi_fingerprint.dart';

/// Contract for offline on-device storage of georeferenced radio localization anchors.
abstract class LocalizationAnchorRepository {
  /// Retrieves all anchors stored in the offline repository.
  Future<List<LocalizationAnchor>> getAllAnchors();

  /// Retrieves an anchor by its unique identifier.
  Future<LocalizationAnchor?> getAnchorById(String id);

  /// Retrieves candidate anchors within a geographical radius of a known point.
  Future<List<LocalizationAnchor>> getNearbyAnchors({
    required double latitude,
    required double longitude,
    double radiusMeters = 200.0,
  });

  /// Adds or updates an anchor in the repository.
  Future<void> addAnchor(LocalizationAnchor anchor);

  /// Clears all stored anchors.
  Future<void> clear();
}

/// In-memory offline anchor repository pre-populated with deterministic demo landmarks.
class InMemoryLocalizationAnchorRepository implements LocalizationAnchorRepository {
  final Map<String, LocalizationAnchor> _anchors = {};

  InMemoryLocalizationAnchorRepository({bool populateDemoAnchors = true}) {
    if (populateDemoAnchors) {
      _loadDemoAnchors();
    }
  }

  void _loadDemoAnchors() {
    final now = DateTime(2026, 1, 1, 12, 0, 0);

    final demoAnchors = [
      LocalizationAnchor(
        id: 'anchor_hotel_lobby_01',
        name: 'Hotel Grand Lobby (Ground Floor)',
        latitude: 19.076000,
        longitude: 72.877700,
        floor: 0,
        confidence: 0.90,
        uncertaintyMeters: 7.0,
        source: PositionSource.wifiFingerprint,
        fingerprint: WifiFingerprint(
          timestamp: now,
          observations: const [
            WifiAccessPointObservation(bssid: '00:11:22:33:44:01', ssid: 'Hotel_Guest_Lobby', rssi: -45, channel: 1),
            WifiAccessPointObservation(bssid: '00:11:22:33:44:02', ssid: 'Hotel_Admin_Internal', rssi: -52, channel: 6),
            WifiAccessPointObservation(bssid: '00:11:22:33:44:03', ssid: 'Cafe_Express_WiFi', rssi: -68, channel: 11),
          ],
        ),
      ),
      LocalizationAnchor(
        id: 'anchor_corridor_02',
        name: 'Grand West Corridor (PDR Midpoint)',
        latitude: 19.076060,
        longitude: 72.877710,
        floor: 0,
        confidence: 0.88,
        uncertaintyMeters: 8.5,
        source: PositionSource.wifiFingerprint,
        fingerprint: WifiFingerprint(
          timestamp: now,
          observations: const [
            WifiAccessPointObservation(bssid: '00:11:22:33:44:02', ssid: 'Hotel_Admin_Internal', rssi: -48, channel: 6),
            WifiAccessPointObservation(bssid: '00:11:22:33:44:03', ssid: 'Cafe_Express_WiFi', rssi: -50, channel: 11),
            WifiAccessPointObservation(bssid: '00:11:22:33:44:04', ssid: 'Corridor_Repeater_02', rssi: -60, channel: 36),
          ],
        ),
      ),
      LocalizationAnchor(
        id: 'anchor_courtyard_03',
        name: 'North Courtyard Entrance',
        latitude: 19.076120,
        longitude: 72.877750,
        floor: 0,
        confidence: 0.85,
        uncertaintyMeters: 10.0,
        source: PositionSource.wifiFingerprint,
        fingerprint: WifiFingerprint(
          timestamp: now,
          observations: const [
            WifiAccessPointObservation(bssid: '00:11:22:33:44:04', ssid: 'Corridor_Repeater_02', rssi: -44, channel: 36),
            WifiAccessPointObservation(bssid: '00:11:22:33:44:05', ssid: 'Courtyard_Outdoor_AP', rssi: -55, channel: 149),
            WifiAccessPointObservation(bssid: '00:11:22:33:44:06', ssid: 'Public_City_Mesh', rssi: -72, channel: 1),
          ],
        ),
      ),
    ];

    for (final anchor in demoAnchors) {
      _anchors[anchor.id] = anchor;
    }
  }

  @override
  Future<List<LocalizationAnchor>> getAllAnchors() async {
    return _anchors.values.toList();
  }

  @override
  Future<LocalizationAnchor?> getAnchorById(String id) async {
    return _anchors[id];
  }

  @override
  Future<List<LocalizationAnchor>> getNearbyAnchors({
    required double latitude,
    required double longitude,
    double radiusMeters = 200.0,
  }) async {
    return _anchors.values.where((anchor) {
      final dist = GeoUtils.haversineDistance(
        lat1: latitude,
        lon1: longitude,
        lat2: anchor.latitude,
        lon2: anchor.longitude,
      );
      return dist <= radiusMeters;
    }).toList();
  }

  @override
  Future<void> addAnchor(LocalizationAnchor anchor) async {
    _anchors[anchor.id] = anchor;
  }

  @override
  Future<void> clear() async {
    _anchors.clear();
  }
}

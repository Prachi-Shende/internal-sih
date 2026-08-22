import '../../pdr/models/pdr_state.dart';
import '../models/localization_anchor.dart';

/// Contract for on-device offline spatial maps, walkable grids, and safe-haven corridors.
abstract class OfflineMapProvider {
  /// Whether the map database is loaded and ready for spatial queries.
  bool get isReady;

  /// Checks if a geocoordinate lies within a walkable pedestrian corridor (not inside a wall/hazard).
  bool isWalkable(double latitude, double longitude);

  /// Snaps a position to the nearest walkable corridor point if inside an obstruction.
  Point2D? nearestWalkablePoint(double latitude, double longitude);

  /// Retrieves emergency safe havens (security posts, exits, medical rooms) near a coordinate.
  List<LocalizationAnchor> nearbySafeLocations(double latitude, double longitude);

  /// Computes a safe walkable path between two points avoiding known obstacles.
  List<Point2D> routeBetween({
    required double startLat,
    required double startLon,
    required double destLat,
    required double destLon,
  });
}

/// Lightweight mock offline map provider preparing architecture for Step 4.
class MockOfflineMapProvider implements OfflineMapProvider {
  @override
  bool get isReady => true;

  @override
  bool isWalkable(double latitude, double longitude) => true;

  @override
  Point2D? nearestWalkablePoint(double latitude, double longitude) =>
      Point2D(x: latitude, y: longitude, timestamp: 0.0);

  @override
  List<LocalizationAnchor> nearbySafeLocations(double latitude, double longitude) =>
      const [];

  @override
  List<Point2D> routeBetween({
    required double startLat,
    required double startLon,
    required double destLat,
    required double destLon,
  }) {
    return [
      Point2D(x: startLat, y: startLon, timestamp: 0.0),
      Point2D(x: destLat, y: destLon, timestamp: 0.0),
    ];
  }
}

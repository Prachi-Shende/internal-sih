import 'dart:math';

/// Geographic utilities for converting between local Cartesian navigation coordinates
/// (X=East meters, Y=North meters) and WGS-84 Geodetic coordinates (Latitude, Longitude).
class GeoUtils {
  /// WGS-84 equatorial Earth radius in meters.
  static const double earthRadiusMeters = 6378137.0;

  /// Converts local displacement (eastMeters, northMeters) relative to a reference origin
  /// into WGS-84 (latitude, longitude) in degrees.
  static ({double latitude, double longitude}) localMetersToLatLng({
    required double originLat,
    required double originLon,
    required double eastMeters,
    required double northMeters,
  }) {
    final originLatRad = originLat * pi / 180.0;

    // Displacement in latitude: dLat = northMeters / R
    final dLat = (northMeters / earthRadiusMeters) * (180.0 / pi);

    // Displacement in longitude: dLon = eastMeters / (R * cos(lat))
    final cosLat = cos(originLatRad);
    final dLon = cosLat.abs() > 1e-7
        ? (eastMeters / (earthRadiusMeters * cosLat)) * (180.0 / pi)
        : 0.0;

    return (
      latitude: originLat + dLat,
      longitude: originLon + dLon,
    );
  }

  /// Converts a WGS-84 (latitude, longitude) into local Cartesian displacement (East, North meters)
  /// relative to a reference origin.
  static ({double eastMeters, double northMeters}) latLngToLocalMeters({
    required double originLat,
    required double originLon,
    required double targetLat,
    required double targetLon,
  }) {
    final originLatRad = originLat * pi / 180.0;

    final dLat = (targetLat - originLat) * (pi / 180.0);
    final dLon = (targetLon - originLon) * (pi / 180.0);

    final northMeters = dLat * earthRadiusMeters;
    final eastMeters = dLon * earthRadiusMeters * cos(originLatRad);

    return (
      eastMeters: eastMeters,
      northMeters: northMeters,
    );
  }

  /// Computes Great-Circle / Haversine distance in meters between two geodetic points.
  static double haversineDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final phi1 = lat1 * pi / 180.0;
    final phi2 = lat2 * pi / 180.0;
    final deltaPhi = (lat2 - lat1) * pi / 180.0;
    final deltaLambda = (lon2 - lon1) * pi / 180.0;

    final a = sin(deltaPhi / 2.0) * sin(deltaPhi / 2.0) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2.0) * sin(deltaLambda / 2.0);

    final c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a));
    return earthRadiusMeters * c;
  }
}

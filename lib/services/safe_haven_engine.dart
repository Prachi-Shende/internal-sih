import 'dart:math' as math;
import 'models.dart';

/// P3 Day 2 Safe-Haven Recommendation & Ranking Engine.
/// 
/// Computes the Safe Arrival Score (0–100) using:
/// Safe Arrival Score = Distance Score + Place Type Security + Availability + Location Confidence - Path Risk Penalty
/// 
/// Core Guarantee: The safest choice is NOT necessarily the closest choice.
class SafeHavenEngine {
  SafeHavenEngine._();

  /// Calculates the Safe Arrival Score for a single location.
  static int calculateScore({
    required SafeLocation location,
    required double userLat,
    required double userLon,
    required LocationConfidence locationConfidence,
    required List<Hotspot> hotspots,
  }) {
    // 1. Distance Score (Proximity bonus, max 35 pts)
    final distanceMeters = _calculateDistance(userLat, userLon, location.lat, location.lon);
    final distanceScore = (35.0 - (distanceMeters / 20.0)).clamp(0.0, 35.0).round();

    // 2. Place Type Security Weight (Max 25 pts)
    int placeTypeScore = 10;
    final typeLower = location.type.toLowerCase();
    if (typeLower.contains('police') || typeLower.contains('law')) {
      placeTypeScore = 25; // Armed law enforcement & maximum safety
    } else if (typeLower.contains('hospital') || typeLower.contains('medical') || typeLower.contains('clinic')) {
      placeTypeScore = 20; // Staffed 24/7, emergency care
    } else if (typeLower.contains('tourist') || typeLower.contains('public') || typeLower.contains('help')) {
      placeTypeScore = 15; // Government tourist assistance desk
    } else if (typeLower.contains('hotel') || typeLower.contains('resort') || typeLower.contains('lobby')) {
      placeTypeScore = 10; // Private security & lighted lobby
    }

    // 3. Operating Status & Staffing (Max 25 pts)
    int availabilityScore = 0;
    if (location.isOpen) availabilityScore += 15;
    if (location.isStaffed) availabilityScore += 10;

    // 4. Location Confidence Bonus (P1 Input — Max 15 pts)
    int confidenceBonus = 5;
    if (locationConfidence == LocationConfidence.high) {
      confidenceBonus = 15;
    } else if (locationConfidence == LocationConfidence.medium) {
      confidenceBonus = 10;
    }

    // 5. Path & Area Risk Penalty (P2 Input — Up to -30 pts penalty)
    // Checks if the path vector midpoint or destination falls inside an active P2 crime hotspot
    int pathPenalty = 0;
    final midLat = (userLat + location.lat) / 2.0;
    final midLon = (userLon + location.lon) / 2.0;

    for (final h in hotspots) {
      final distToMid = _calculateDistance(midLat, midLon, h.centerLat, h.centerLon);
      final distToLoc = _calculateDistance(location.lat, location.lon, h.centerLat, h.centerLon);
      
      // If path midpoint or destination is inside hotspot radius
      if (distToMid < h.radius * 0.8 || distToLoc < h.radius * 0.8) {
        if (h.risk == RiskLevel.high || h.risk == RiskLevel.critical) {
          pathPenalty = math.max(pathPenalty, 30);
        } else if (h.risk == RiskLevel.medium) {
          pathPenalty = math.max(pathPenalty, 15);
        }
      }
    }

    final rawScore = distanceScore + placeTypeScore + availabilityScore + confidenceBonus - pathPenalty;
    return rawScore.clamp(0, 100);
  }

  /// Ranks a list of SafeLocations so the SAFEST option (highest score)
  /// is returned first at index 0.
  static List<SafeLocation> rankLocations({
    required List<SafeLocation> locations,
    required double userLat,
    required double userLon,
    required LocationConfidence locationConfidence,
    required List<Hotspot> hotspots,
  }) {
    List<SafeLocation> scoredList = locations.map((loc) {
      final distanceMeters = _calculateDistance(userLat, userLon, loc.lat, loc.lon);
      final score = calculateScore(
        location: loc,
        userLat: userLat,
        userLon: userLon,
        locationConfidence: locationConfidence,
        hotspots: hotspots,
      );

      return SafeLocation(
        id: loc.id,
        name: loc.name,
        distance: distanceMeters,
        type: loc.type,
        isOpen: loc.isOpen,
        isStaffed: loc.isStaffed,
        score: score,
        lat: loc.lat,
        lon: loc.lon,
      );
    }).toList();

    scoredList.sort((a, b) => b.score.compareTo(a.score));
    return scoredList;
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = math.cos;
    var a = 0.5 - c((lat2 - lat1) * p) / 2 + c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)) * 1000;
  }
}

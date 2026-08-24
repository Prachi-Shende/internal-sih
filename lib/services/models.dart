import 'package:flutter/foundation.dart';

enum RiskLevel { low, medium, high, critical, unknown }
enum LocationConfidence { high, medium, low }
enum SystemState { normal, gpsDegraded, offline, recovery }

class LocationEstimate {
  final double lat;
  final double lon;
  final String source; // 'GPS' or 'PDR'
  final LocationConfidence confidence;

  LocationEstimate({
    required this.lat,
    required this.lon,
    required this.source,
    required this.confidence,
  });
}

class Hotspot {
  final String id;
  final String name;
  final RiskLevel risk;
  final int reportedIncidents;
  final int recentIncidents;
  final double score;
  final double radius; // meters
  final double centerLat;
  final double centerLon;

  Hotspot({
    required this.id,
    required this.name,
    required this.risk,
    required this.reportedIncidents,
    required this.recentIncidents,
    required this.score,
    required this.radius,
    required this.centerLat,
    required this.centerLon,
  });
}

class SafeLocation {
  final String id;
  final String name;
  final double distance; // meters
  final String type;
  final bool isOpen;
  final bool isStaffed;
  final int score;
  final double lat;
  final double lon;

  SafeLocation({
    required this.id,
    required this.name,
    required this.distance,
    required this.type,
    required this.isOpen,
    required this.isStaffed,
    required this.score,
    required this.lat,
    required this.lon,
  });
}

class CommunicationStatus {
  final bool internet;
  final bool sms;
  final bool relay;
  final bool offlineQueue;
  final String selectedChannel;

  CommunicationStatus({
    required this.internet,
    required this.sms,
    required this.relay,
    required this.offlineQueue,
    required this.selectedChannel,
  });
}

class TripDestination {
  final String id;
  final String name;
  final String location;
  final String imageUrl;
  final double rating;
  final bool isPopular;

  TripDestination({
    required this.id,
    required this.name,
    required this.location,
    required this.imageUrl,
    required this.rating,
    this.isPopular = false,
  });
}

class TimelineEvent {
  final DateTime time;
  final String title;
  final String description;
  final String state; // 'completed', 'current', 'warning', 'emergency'
  final String icon; // Icon name reference

  TimelineEvent({
    required this.time,
    required this.title,
    required this.description,
    required this.state,
    required this.icon,
  });
}

/// Output of the RiskEngine computation.
class RiskAssessment {
  final RiskLevel risk;
  final int score; // 0-100
  final List<String> reasons;

  const RiskAssessment({
    required this.risk,
    required this.score,
    required this.reasons,
  });

  Map<String, dynamic> toJson() => {
        'risk': risk.name,
        'score': score,
        'reasons': reasons,
      };
}

/// Structured Telemetry payload capturing live P1 & P2 telemetry signals.
class TelemetryData {
  final double lat;
  final double lon;
  final String locationSource;     // 'GPS', 'PDR', 'WIFI'
  final LocationConfidence locationConfidence; // high, medium, low
  final double uncertaintyMeters;  // e.g. 5.0m vs 85.0m
  final bool isDegraded;           // true if GPS lost
  final bool isStationary;         // true if stopped moving
  final double? routeDeviationMeters; // distance off planned route

  final String geofenceState;      // 'INSIDE', 'APPROACHING', 'OUTSIDE'
  final double hotspotDistanceMeters; // distance to nearest hotspot center
  final Hotspot? nearbyHotspot;
  final String? hotspotRiskLevel;  // 'HIGH', 'MEDIUM', 'LOW'
  final int reportedIncidents;     // incident count in zone

  final DateTime currentTime;
  final bool userReportedUnsafe;

  TelemetryData({
    required this.lat,
    required this.lon,
    required this.locationSource,
    required this.locationConfidence,
    required this.uncertaintyMeters,
    required this.isDegraded,
    required this.isStationary,
    this.routeDeviationMeters,
    required this.geofenceState,
    required this.hotspotDistanceMeters,
    this.nearbyHotspot,
    this.hotspotRiskLevel,
    required this.reportedIncidents,
    required this.currentTime,
    required this.userReportedUnsafe,
  });
}

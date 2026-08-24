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

class BreadcrumbPoint {
  final double lat;
  final double lon;
  final String source; // 'GPS', 'PDR', 'WIFI'
  final bool isEstimated; // true if PDR/WIFI, false if GPS
  final DateTime timestamp;
  final double? speed;
  final double? heading;
  final RiskLevel riskLevel;

  BreadcrumbPoint({
    required this.lat,
    required this.lon,
    required this.source,
    required this.isEstimated,
    required this.timestamp,
    this.speed,
    this.heading,
    this.riskLevel = RiskLevel.low,
  });
}

class JourneySummary {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final double distanceMeters;
  final int stepCount;
  final List<BreadcrumbPoint> routePoints;
  final int safetyEventsCount;
  final int riskAlertsCount;

  JourneySummary({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.distanceMeters,
    required this.stepCount,
    required this.routePoints,
    this.safetyEventsCount = 0,
    this.riskAlertsCount = 0,
  });

  Duration get duration => endTime.difference(startTime);
}

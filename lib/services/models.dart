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
  final double radius; // meters

  Hotspot({
    required this.id,
    required this.name,
    required this.risk,
    required this.reportedIncidents,
    required this.recentIncidents,
    required this.radius,
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

  SafeLocation({
    required this.id,
    required this.name,
    required this.distance,
    required this.type,
    required this.isOpen,
    required this.isStaffed,
    required this.score,
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

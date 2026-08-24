import 'models.dart';

class MockData {
  static List<TripDestination> popularDestinations = [
    TripDestination(
      id: 'd1',
      name: 'Nusa Dua Beach',
      location: 'Bali, Indonesia',
      imageUrl: 'https://images.unsplash.com/photo-1537996194471-e657df975ab4',
      rating: 4.8,
      isPopular: true,
    ),
    TripDestination(
      id: 'd2',
      name: 'Mount Cook',
      location: 'Canterbury, New Zealand',
      imageUrl: 'https://images.unsplash.com/photo-1590483864402-9a3d46387063',
      rating: 4.9,
      isPopular: true,
    ),
    TripDestination(
      id: 'd3',
      name: 'Southern Alps',
      location: 'New Zealand',
      imageUrl: 'https://images.unsplash.com/photo-1606132711718-fdb6938a08ce',
      rating: 4.7,
      isPopular: false,
    ),
    TripDestination(
      id: 'd4',
      name: 'Cape Town',
      location: 'South Africa',
      imageUrl: 'https://images.unsplash.com/photo-1580060839134-75a5edca2e99',
      rating: 4.9,
      isPopular: true,
    ),
  ];

  static LocationEstimate initialLocation = LocationEstimate(
    lat: -8.7941,
    lon: 115.2266, // near Nusa Dua
    source: 'GPS',
    confidence: LocationConfidence.high,
  );

  static List<SafeLocation> safeLocations = [
    SafeLocation(
      id: 's1',
      name: 'Nusa Dua Central Police Station',
      distance: 500,
      type: 'Police Station',
      isOpen: true,
      isStaffed: true,
      score: 90,
      lat: -8.7910,
      lon: 115.2230,
    ),
    SafeLocation(
      id: 's2',
      name: 'Benoa 24/7 Emergency Hospital',
      distance: 700,
      type: 'Hospital',
      isOpen: true,
      isStaffed: true,
      score: 81,
      lat: -8.7890,
      lon: 115.2280,
    ),
    SafeLocation(
      id: 's3',
      name: 'Tourist Assistance & Help Desk',
      distance: 350,
      type: 'Tourist Center',
      isOpen: true,
      isStaffed: true,
      score: 88,
      lat: -8.7930,
      lon: 115.2240,
    ),
    SafeLocation(
      id: 's4',
      name: 'Grand Hyatt Hotel Security Lobby',
      distance: 250,
      type: 'Hotel',
      isOpen: true,
      isStaffed: true,
      score: 74,
      lat: -8.7965,
      lon: 115.2260,
    ),
  ];

  static Hotspot mockHotspot = Hotspot(
    id: 'h1',
    name: 'Kuta Night Market Area',
    risk: RiskLevel.high,
    reportedIncidents: 12,
    recentIncidents: 3,
    score: 85.0,
    radius: 1500, // 1.5 km
    centerLat: -8.7970,
    centerLon: 115.2250,
  );

  static List<Hotspot> hotspots = [mockHotspot];

  static CommunicationStatus normalComm = CommunicationStatus(
    internet: true,
    sms: true,
    relay: true,
    offlineQueue: true,
    selectedChannel: 'INTERNET',
  );

  static CommunicationStatus offlineComm = CommunicationStatus(
    internet: false,
    sms: false,
    relay: true,
    offlineQueue: true,
    selectedChannel: 'RELAY',
  );

  static List<TimelineEvent> mockTimeline = [
    TimelineEvent(
      time: DateTime.now().subtract(const Duration(minutes: 5)),
      title: 'GPS signal lost',
      description: 'System automatically switched to PDR.',
      state: 'warning',
      icon: 'map_pin_off',
    ),
    TimelineEvent(
      time: DateTime.now().subtract(const Duration(minutes: 4)),
      title: 'PDR activated',
      description: 'Journey is being estimated accurately.',
      state: 'completed',
      icon: 'navigation',
    ),
    TimelineEvent(
      time: DateTime.now().subtract(const Duration(minutes: 1)),
      title: 'High-risk hotspot detected',
      description: 'Reported incidents concentrated nearby.',
      state: 'emergency',
      icon: 'alert_circle',
    ),
  ];
}

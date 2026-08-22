import 'models.dart';

class MockData {
  static final List<TripDestination> popularDestinations = [
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

  static final LocationEstimate initialLocation = LocationEstimate(
    lat: -8.7941,
    lon: 115.2266, // near Nusa Dua
    source: 'GPS',
    confidence: LocationConfidence.high,
  );

  static final List<SafeLocation> safeLocations = [
    SafeLocation(
      id: 's1',
      name: 'Tourist Help Centre',
      distance: 120,
      type: 'Public Services',
      isOpen: true,
      isStaffed: true,
      score: 95,
    ),
    SafeLocation(
      id: 's2',
      name: 'Bumbu Bali',
      distance: 280,
      type: 'Restaurant',
      isOpen: true,
      isStaffed: true,
      score: 88,
    ),
    SafeLocation(
      id: 's3',
      name: 'Grand Hyatt Security',
      distance: 450,
      type: 'Hotel Security',
      isOpen: true,
      isStaffed: true,
      score: 92,
    ),
  ];

  static final Hotspot mockHotspot = Hotspot(
    id: 'h1',
    name: 'Kuta Night Market Area',
    risk: RiskLevel.high,
    reportedIncidents: 12,
    recentIncidents: 4,
    radius: 300,
  );

  static final CommunicationStatus normalComm = CommunicationStatus(
    internet: true,
    sms: true,
    relay: true,
    offlineQueue: true,
    selectedChannel: 'INTERNET',
  );

  static final CommunicationStatus offlineComm = CommunicationStatus(
    internet: false,
    sms: false,
    relay: true,
    offlineQueue: true,
    selectedChannel: 'RELAY',
  );

  static final List<TimelineEvent> mockTimeline = [
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

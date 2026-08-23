import 'models.dart';

class MockData {
  static List<TripDestination> popularDestinations = [
    // Mountains
    TripDestination(id: 'm1', name: 'Mount Cook', location: 'New Zealand', imageUrl: 'https://picsum.photos/seed/m1/400/300', rating: 4.9, isPopular: true, category: 'Mountains'),
    TripDestination(id: 'm2', name: 'Swiss Alps', location: 'Switzerland', imageUrl: 'https://picsum.photos/seed/m2/400/300', rating: 4.8, isPopular: true, category: 'Mountains'),
    TripDestination(id: 'm3', name: 'Banff National Park', location: 'Canada', imageUrl: 'https://picsum.photos/seed/m3/400/300', rating: 4.7, isPopular: false, category: 'Mountains'),
    TripDestination(id: 'm4', name: 'Patagonia Andes', location: 'Argentina', imageUrl: 'https://picsum.photos/seed/m4/400/300', rating: 4.9, isPopular: false, category: 'Mountains'),
    
    // Waterfalls
    TripDestination(id: 'w1', name: 'Niagara Falls', location: 'Canada/USA', imageUrl: 'https://picsum.photos/seed/w1/400/300', rating: 4.7, isPopular: true, category: 'Waterfalls'),
    TripDestination(id: 'w2', name: 'Victoria Falls', location: 'Zambia', imageUrl: 'https://picsum.photos/seed/w2/400/300', rating: 4.9, isPopular: true, category: 'Waterfalls'),
    TripDestination(id: 'w3', name: 'Iguazu Falls', location: 'Brazil', imageUrl: 'https://picsum.photos/seed/w3/400/300', rating: 4.8, isPopular: false, category: 'Waterfalls'),
    TripDestination(id: 'w4', name: 'Angel Falls', location: 'Venezuela', imageUrl: 'https://picsum.photos/seed/w4/400/300', rating: 4.9, isPopular: false, category: 'Waterfalls'),

    // Desert
    TripDestination(id: 'd1', name: 'Sahara Dunes', location: 'Morocco', imageUrl: 'https://picsum.photos/seed/d1/400/300', rating: 4.8, isPopular: true, category: 'Desert'),
    TripDestination(id: 'd2', name: 'Wadi Rum', location: 'Jordan', imageUrl: 'https://picsum.photos/seed/d2/400/300', rating: 4.7, isPopular: true, category: 'Desert'),
    TripDestination(id: 'd3', name: 'Atacama', location: 'Chile', imageUrl: 'https://picsum.photos/seed/d3/400/300', rating: 4.9, isPopular: false, category: 'Desert'),
    TripDestination(id: 'd4', name: 'Mojave Desert', location: 'USA', imageUrl: 'https://picsum.photos/seed/d4/400/300', rating: 4.6, isPopular: false, category: 'Desert'),

    // Beaches
    TripDestination(id: 'b1', name: 'Nusa Dua Beach', location: 'Indonesia', imageUrl: 'https://picsum.photos/seed/b1/400/300', rating: 4.8, isPopular: true, category: 'Beaches'),
    TripDestination(id: 'b2', name: 'Bora Bora', location: 'French Polynesia', imageUrl: 'https://picsum.photos/seed/b2/400/300', rating: 4.9, isPopular: true, category: 'Beaches'),
    TripDestination(id: 'b3', name: 'Maldives Atoll', location: 'Maldives', imageUrl: 'https://picsum.photos/seed/b3/400/300', rating: 4.9, isPopular: false, category: 'Beaches'),
    TripDestination(id: 'b4', name: 'Cancun Sands', location: 'Mexico', imageUrl: 'https://picsum.photos/seed/b4/400/300', rating: 4.7, isPopular: false, category: 'Beaches'),
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
      name: 'Tourist Help Centre',
      distance: 120,
      type: 'Public Services',
      isOpen: true,
      isStaffed: true,
      score: 95,
      lat: -8.7950,
      lon: 115.2260,
    ),
    SafeLocation(
      id: 's2',
      name: 'Bumbu Bali',
      distance: 280,
      type: 'Restaurant',
      isOpen: true,
      isStaffed: true,
      score: 88,
      lat: -8.7960,
      lon: 115.2280,
    ),
    SafeLocation(
      id: 's3',
      name: 'Grand Hyatt Security',
      distance: 450,
      type: 'Hotel Security',
      isOpen: true,
      isStaffed: true,
      score: 92,
      lat: -8.7920,
      lon: 115.2250,
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

  static List<Trip> mockUpcomingTrips = [
    Trip(id: 't1', title: 'Cape York Adventure', dateString: 'leaving 13/10/2026', imageUrl: 'https://picsum.photos/seed/capeyork/300/300', isUpcoming: true),
    Trip(id: 't2', title: 'Fraser Island Getaway', dateString: 'leaving 27/12/2026', imageUrl: 'https://picsum.photos/seed/fraser/300/300', isUpcoming: true),
  ];

  static List<Trip> mockPastTrips = [
    Trip(id: 't3', title: 'Double Island Excursion', dateString: '10/09 - 12/09/2021', imageUrl: 'https://picsum.photos/seed/doubleisland/300/300', isUpcoming: false),
  ];
}

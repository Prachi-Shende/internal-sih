import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../config.dart';
import 'models.dart';
import 'mock_data.dart';
import 'api_service.dart';
import 'session_service.dart';

// P1 Core Subsystem Imports
import '../p1/integration/p1_integration_facade.dart';
import '../p1/integration/models/p1_system_snapshot.dart';
import '../p1/integration/models/movement_snapshot.dart';
import '../p1/integration/models/resilience_snapshot.dart';
import '../p1/pdr/core/pdr_engine.dart';
import '../p1/resilience/core/resilience_engine.dart';
import '../p1/resilience/map/graph_map_matcher.dart';
import '../p1/resilience/map/walkable_graph.dart';
import '../p1/resilience/models/gps_health.dart';
import '../p1/resilience/models/position_estimate.dart';
import '../p1/resilience/models/position_source.dart';
import '../p1/resilience/models/resilience_state.dart';
import '../p1/resilience/providers/pdr_positioning_provider.dart';
import '../p1/resilience/sensors/android_wifi_scanner.dart';
import '../p1/resilience/sensors/wifi_scanner.dart';
import '../p1/safety/core/safety_engine.dart';
import '../p1/safety/models/safety_event.dart';
import '../p1/safety/storage/file_safety_event_store.dart';
import '../p1/safety/transport/real_http_safety_event_transport.dart';

/// Central Reactive State Orchestrator for Travara.
/// Directly drives the P1 Resilient Positioning Engine, PDR Kinematics,
/// Offline Safety Event Queue, and Backend Telemetry Ingestion.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  // P1 Subsystem Engines
  late final PdrEngine _pdrEngine;
  late final ResilienceEngine _resilienceEngine;
  late final SafetyEngine _safetyEngine;
  late final P1IntegrationFacade _p1Facade;

  // Runtime State
  SystemState _systemState = SystemState.normal;
  LocationEstimate _currentLocation = MockData.initialLocation;
  CommunicationStatus _communicationStatus = MockData.normalComm;
  RiskLevel _currentRisk = RiskLevel.low;
  bool _isEmergencyActive = false;
  int _pendingOfflineEventsCount = 0;
  bool _isSimulationActive = false;

  MovementSnapshot _latestMovement = MovementSnapshot.fromPdrState(null);
  ResilienceSnapshot _latestResilience = ResilienceSnapshot.fromResilienceState(ResilienceState.initial());

  String _userName = 'Explorer';
  String _userEmail = '';

  Timer? _pollingTimer;
  StreamSubscription<P1SystemSnapshot>? _snapshotSub;
  StreamSubscription<SafetyEvent>? _safetyEventSub;
  StreamSubscription<Position>? _geolocatorSub;
  String _geofenceState = 'OUTSIDE';

  // Travel History Breadcrumbs
  final List<BreadcrumbPoint> _currentJourneyPoints = [];
  final List<JourneySummary> _savedJourneys = [];

  // Getters
  SystemState get systemState => _systemState;
  LocationEstimate get currentLocation => _currentLocation;
  CommunicationStatus get communicationStatus => _communicationStatus;
  RiskLevel get currentRisk => _currentRisk;
  bool get isEmergencyActive => _isEmergencyActive;
  int get pendingOfflineEventsCount => _pendingOfflineEventsCount;
  bool get isSimulationActive => _isSimulationActive;

  MovementSnapshot get latestMovement => _latestMovement;
  ResilienceSnapshot get latestResilience => _latestResilience;
  P1IntegrationFacade get p1Facade => _p1Facade;
  ResilienceEngine get resilienceEngine => _resilienceEngine;
  PdrEngine get pdrEngine => _pdrEngine;
  SafetyEngine get safetyEngine => _safetyEngine;

  String get userName => _userName;
  String get userEmail => _userEmail;
  String get geofenceState => _geofenceState;

  List<BreadcrumbPoint> get currentJourneyPoints => List.unmodifiable(_currentJourneyPoints);
  List<JourneySummary> get savedJourneys => List.unmodifiable(_savedJourneys);

  AppState() {
    WidgetsBinding.instance.addObserver(this);
    _initP1Subsystem();
    _initDemoJourneys();

    // Start cloud polling & location services
    _startPolling();
    _startGpsSensorFallback();

    // Firebase Auth integration
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      ApiService.sessionId = await SessionService.getOrCreateSessionId();
      if (user != null) {
        _fetchUserData(user.uid);
      } else {
        _userName = 'Explorer';
        _userEmail = '';
      }
      _isEmergencyActive = false;
      _fetchUnifiedState();
      notifyListeners();
    });
  }

  /// Initializes P1 Engines, PDR, Multi-Tier Resilience Orchestrator & Safety Queue.
  void _initP1Subsystem() {
    _pdrEngine = PdrEngine();
    final pdrProvider = PdrPositioningProvider(engine: _pdrEngine);

    final wifiScanner = defaultTargetPlatform == TargetPlatform.android
        ? AndroidWifiScanner()
        : SimulatedWifiScanner();
    final mapMatcher = GraphMapMatcher(graph: WalkableGraph.demoVenue());

    _resilienceEngine = ResilienceEngine(
      pdrProvider: pdrProvider,
      wifiScanner: wifiScanner,
      mapConstraintProvider: mapMatcher,
    );

    _safetyEngine = SafetyEngine(
      resilienceEngine: _resilienceEngine,
      store: FileSafetyEventStore(),
      transport: RealHttpSafetyEventTransport(
        baseUrl: AppConfig.apiBaseUrl,
        endpointPath: '/api/safety-events',
      ),
    );

    _p1Facade = P1IntegrationFacade(
      resilienceEngine: _resilienceEngine,
      pdrEngine: _pdrEngine,
      safetyEngine: _safetyEngine,
    );

    // Start background engines
    _resilienceEngine.start();
    _pdrEngine.start();
    _safetyEngine.start();

    // Subscribe to unified P1 snapshot stream
    _snapshotSub = _p1Facade.snapshotStream.listen(_handleP1Snapshot);

    // Subscribe to safety events for offline queue badge updates
    _safetyEventSub = _safetyEngine.eventStream.listen((_) => _updatePendingEventsCount());
    _updatePendingEventsCount();
  }

  /// Processes live P1 system snapshot updates from sensors, GPS, and PDR.
  void _handleP1Snapshot(P1SystemSnapshot snapshot) {
    _latestMovement = snapshot.movement;
    _latestResilience = snapshot.resilience;

    // 1. Update Geographic Positioning
    if (snapshot.position.latitude != null && snapshot.position.longitude != null) {
      final lat = snapshot.position.latitude!;
      final lon = snapshot.position.longitude!;
      final confVal = snapshot.position.confidence ?? 0.8;
      final sourceStr = (snapshot.position.source ?? 'GPS').toUpperCase();

      LocationConfidence conf = LocationConfidence.high;
      if (confVal < 0.4) {
        conf = LocationConfidence.low;
      } else if (confVal < 0.7) {
        conf = LocationConfidence.medium;
      }

      _currentLocation = LocationEstimate(
        lat: lat,
        lon: lon,
        source: sourceStr,
        confidence: conf,
      );

      // Record Breadcrumb for Travel History
      _recordBreadcrumb(
        lat,
        lon,
        sourceStr,
        sourceStr != 'GPS',
        speed: snapshot.movement.speedMps,
        heading: snapshot.movement.headingDegrees,
      );

      // Post live telemetry to backend if online
      if (snapshot.connectivity.isOnline && !AppConfig.MOCK_MODE) {
        ApiService.postLocation(
          lat,
          lon,
          sourceStr,
          confVal,
        );
      }
    }

    // 2. Map Multi-Tier Resilience State
    if (!snapshot.connectivity.isOnline) {
      _systemState = SystemState.offline;
    } else if (snapshot.resilience.mode == 'pdrFallback' || snapshot.position.isDegraded) {
      _systemState = SystemState.gpsDegraded;
    } else {
      _systemState = SystemState.normal;
    }

    // 3. Update Connectivity Status
    _communicationStatus = CommunicationStatus(
      internet: snapshot.connectivity.isOnline,
      sms: snapshot.connectivity.cellularAvailable,
      relay: snapshot.connectivity.cellularAvailable,
      offlineQueue: _pendingOfflineEventsCount > 0,
      selectedChannel: snapshot.connectivity.activeDeliveryChannel,
    );

    notifyListeners();
  }

  Future<void> _updatePendingEventsCount() async {
    try {
      final pending = await _safetyEngine.getPendingEvents();
      _pendingOfflineEventsCount = pending.length;
      notifyListeners();
    } catch (_) {}
  }

  void _recordBreadcrumb(double lat, double lon, String source, bool isEstimated,
      {double? speed, double? heading}) {
    // Avoid redundant duplicates within 2 meters
    if (_currentJourneyPoints.isNotEmpty) {
      final last = _currentJourneyPoints.last;
      final dLat = (lat - last.lat).abs();
      final dLon = (lon - last.lon).abs();
      if (dLat < 0.00002 && dLon < 0.00002) return;
    }

    final point = BreadcrumbPoint(
      lat: lat,
      lon: lon,
      source: source,
      isEstimated: isEstimated,
      timestamp: DateTime.now(),
      speed: speed,
      heading: heading,
      riskLevel: _currentRisk,
    );
    _currentJourneyPoints.add(point);

    // Maintain an active live journey entry in savedJourneys (index 0)
    final liveJourneyIndex = _savedJourneys.indexWhere((j) => j.id == 'live-active-journey');
    final activeSummary = JourneySummary(
      id: 'live-active-journey',
      title: 'Current Active Route (Live)',
      startTime: _currentJourneyPoints.first.timestamp,
      endTime: DateTime.now(),
      distanceMeters: _latestMovement.distanceMeters,
      stepCount: _latestMovement.steps,
      safetyEventsCount: _pendingOfflineEventsCount,
      riskAlertsCount: _currentRisk != RiskLevel.low ? 1 : 0,
      routePoints: List.from(_currentJourneyPoints),
    );

    if (liveJourneyIndex >= 0) {
      _savedJourneys[liveJourneyIndex] = activeSummary;
    } else {
      _savedJourneys.insert(0, activeSummary);
    }
  }

  /// Backup Geolocator subscription to directly feed GPS coordinates on physical hardware.
  Future<void> _startGpsSensorFallback() async {
    if (AppConfig.MOCK_MODE) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _resilienceEngine.gpsProvider.injectSimulatedPosition(
        PositionEstimate(
          latitude: position.latitude,
          longitude: position.longitude,
          source: PositionSource.gps,
          confidence: 0.95,
          uncertaintyMeters: position.accuracy > 0 ? position.accuracy : 4.0,
          timestamp: position.timestamp,
          isAbsolute: true,
          isDegraded: false,
          headingDegrees: position.heading >= 0 ? position.heading : null,
          speedMps: position.speed >= 0 ? position.speed : null,
          altitude: position.altitude,
        ),
      );
    } catch (e) {
      debugPrint("Initial GPS lock: $e");
    }

    _geolocatorSub?.cancel();
    _geolocatorSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen((Position position) {
      _resilienceEngine.gpsProvider.injectSimulatedPosition(
        PositionEstimate(
          latitude: position.latitude,
          longitude: position.longitude,
          source: PositionSource.gps,
          confidence: 0.95,
          uncertaintyMeters: position.accuracy > 0 ? position.accuracy : 4.0,
          timestamp: position.timestamp,
          isAbsolute: true,
          isDegraded: false,
          headingDegrees: position.heading >= 0 ? position.heading : null,
          speedMps: position.speed >= 0 ? position.speed : null,
          altitude: position.altitude,
        ),
      );
    });
  }

  void _startPolling() {
    if (_pollingTimer != null && _pollingTimer!.isActive) return;
    _fetchUnifiedState();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchUnifiedState();
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _fetchUnifiedState() async {
    if (AppConfig.MOCK_MODE) return;

    final data = await ApiService.getUnifiedState();
    if (data != null) {
      _currentRisk = ApiService.parseRiskLevel(data['risk']);

      // P2 Geofence Transition Handling
      final newGeofenceState = data['geofence_state'] as String? ?? 'OUTSIDE';
      if (newGeofenceState != _geofenceState) {
        _geofenceState = newGeofenceState;
        _postGeofenceRiskAssessment(newGeofenceState, data['geofence_hotspot_id'] as String?);
      }

      // Refresh Hotspots & Safe Havens
      final hotspots = await ApiService.getHotspots();
      if (hotspots.isNotEmpty) {
        MockData.mockHotspot = hotspots.first;
        MockData.hotspots = hotspots;
      }

      final safeLocs = await ApiService.getSafeLocations(_currentLocation.lat, _currentLocation.lon);
      if (safeLocs.isNotEmpty) {
        MockData.safeLocations = safeLocs;
      }

      _updatePendingEventsCount();
      notifyListeners();
    }
  }

  void _postGeofenceRiskAssessment(String geofenceState, String? hotspotId) {
    RiskLevel risk;
    int score;
    List<String> reasons;

    switch (geofenceState) {
      case 'INSIDE':
        risk = RiskLevel.high;
        score = 75;
        reasons = ['Inside a reported crime hotspot', 'High reported-crime concentration'];
        break;
      case 'APPROACHING':
        risk = RiskLevel.medium;
        score = 45;
        reasons = ['Approaching a reported crime hotspot (within 300m)', 'Proceed with caution'];
        break;
      default:
        risk = RiskLevel.low;
        score = 10;
        reasons = ['No active hotspot in vicinity'];
    }

    ApiService.postRiskAssessment(
      riskLevel: risk,
      score: score,
      reasons: reasons,
      hotspotId: hotspotId,
    );
  }

  /// Triggers full Emergency SOS through P1 Safety Engine.
  /// 1. Snapshots resilient position (GPS or PDR).
  /// 2. Persists to local FileSafetyEventStore FIRST (survives app kill).
  /// 3. Transmits via HTTP or queues offline automatically.
  /// 4. Notifies backend incident dispatcher & records blockchain hash.
  Future<void> activateSafetyAssist() async {
    _isEmergencyActive = true;
    _currentRisk = RiskLevel.critical;

    // 1. Dispatch resilient P1 SafetyEvent
    try {
      await _safetyEngine.createSos(metadata: {
        'session_id': ApiService.sessionId,
        'user_name': _userName,
        'user_email': _userEmail,
      });
      await _updatePendingEventsCount();
    } catch (e) {
      debugPrint("SafetyEngine SOS Dispatch: $e");
    }

    // 2. Also notify Backend Incident Router
    double confidenceFloat = _currentLocation.confidence == LocationConfidence.high
        ? 0.95
        : (_currentLocation.confidence == LocationConfidence.medium ? 0.60 : 0.25);

    ApiService.createIncident(
      _currentLocation.lat,
      _currentLocation.lon,
      _currentLocation.source,
      confidenceFloat,
      riskLevel: _currentRisk,
    );

    ApiService.postRiskAssessment(
      riskLevel: RiskLevel.critical,
      score: 85,
      reasons: ['User triggered I Feel Unsafe', 'Manual SOS activation'],
    );

    notifyListeners();
  }

  void resolveIncident() {
    _isEmergencyActive = false;
    _currentRisk = RiskLevel.low;
    _systemState = SystemState.normal;
    notifyListeners();
  }

  // ── DEVELOPER SIMULATION SANDBOX CONTROLS ─────────────────────────────────
  // Drives the ACTUAL P1 Resilience Engine state machine.

  void setSimulationMode(bool enabled) {
    _isSimulationActive = enabled;
    if (!enabled) {
      _resilienceEngine.setOverrideMode(ResilienceOverrideMode.auto);
    }
    notifyListeners();
  }

  void simulateGpsState(GpsHealth health) {
    _isSimulationActive = true;
    if (health == GpsHealth.active) {
      _resilienceEngine.setOverrideMode(ResilienceOverrideMode.forceGps);
    } else if (health == GpsHealth.stale) {
      _resilienceEngine.setOverrideMode(ResilienceOverrideMode.simulateGpsLoss);
    } else {
      _resilienceEngine.setOverrideMode(ResilienceOverrideMode.simulateGpsLoss);
    }
    notifyListeners();
  }

  void simulateInternetState(bool online) {
    _isSimulationActive = true;
    if (online) {
      _resilienceEngine.setOverrideMode(ResilienceOverrideMode.auto);
    } else {
      _resilienceEngine.setOverrideMode(ResilienceOverrideMode.simulateOffline);
    }
    notifyListeners();
  }

  void simulateFourCase(int caseNumber) {
    _isSimulationActive = true;
    switch (caseNumber) {
      case 1: // Case 1: GPS Active + Internet Online
        _resilienceEngine.setOverrideMode(ResilienceOverrideMode.forceGps);
        break;
      case 2: // Case 2: GPS Degraded + Internet Online
        _resilienceEngine.setOverrideMode(ResilienceOverrideMode.simulateGpsLoss);
        break;
      case 3: // Case 3: GPS Active + Internet Offline
        _resilienceEngine.setOverrideMode(ResilienceOverrideMode.forceGps);
        _resilienceEngine.connectivityService.setSimulatedStatus(false);
        break;
      case 4: // Case 4: GPS Lost + Internet Offline
        _resilienceEngine.setOverrideMode(ResilienceOverrideMode.simulateTotalBlackout);
        break;
    }
    notifyListeners();
  }

  void resetSimulation() {
    _isSimulationActive = false;
    _resilienceEngine.setOverrideMode(ResilienceOverrideMode.auto);
    _isEmergencyActive = false;
    _currentRisk = RiskLevel.low;
    notifyListeners();
  }

  // ── TRAVEL HISTORY INITIALIZATION ──────────────────────────────────────────
  void _initDemoJourneys() {
    final now = DateTime.now();
    _savedJourneys.add(JourneySummary(
      id: 'journey-001',
      title: 'South Mumbai Heritage Walk',
      startTime: now.subtract(const Duration(days: 1, hours: 2)),
      endTime: now.subtract(const Duration(days: 1)),
      distanceMeters: 3420,
      stepCount: 4620,
      safetyEventsCount: 0,
      riskAlertsCount: 1,
      routePoints: [
        BreadcrumbPoint(lat: 18.9220, lon: 72.8347, source: 'GPS', isEstimated: false, timestamp: now.subtract(const Duration(hours: 2))),
        BreadcrumbPoint(lat: 18.9255, lon: 72.8322, source: 'GPS', isEstimated: false, timestamp: now.subtract(const Duration(hours: 1, minutes: 45))),
        BreadcrumbPoint(lat: 18.9280, lon: 72.8310, source: 'PDR', isEstimated: true, timestamp: now.subtract(const Duration(hours: 1, minutes: 30))),
        BreadcrumbPoint(lat: 18.9320, lon: 72.8315, source: 'PDR', isEstimated: true, timestamp: now.subtract(const Duration(hours: 1, minutes: 15))),
        BreadcrumbPoint(lat: 18.9350, lon: 72.8340, source: 'GPS', isEstimated: false, timestamp: now.subtract(const Duration(hours: 1))),
      ],
    ));

    _savedJourneys.add(JourneySummary(
      id: 'journey-002',
      title: 'Bandra Bandstand Evening Promenade',
      startTime: now.subtract(const Duration(days: 2, hours: 3)),
      endTime: now.subtract(const Duration(days: 2, hours: 1, minutes: 30)),
      distanceMeters: 2150,
      stepCount: 2900,
      safetyEventsCount: 0,
      riskAlertsCount: 0,
      routePoints: [
        BreadcrumbPoint(lat: 19.0430, lon: 72.8190, source: 'GPS', isEstimated: false, timestamp: now.subtract(const Duration(days: 2, hours: 3))),
        BreadcrumbPoint(lat: 19.0480, lon: 72.8210, source: 'GPS', isEstimated: false, timestamp: now.subtract(const Duration(days: 2, hours: 2, minutes: 15))),
        BreadcrumbPoint(lat: 19.0520, lon: 72.8235, source: 'GPS', isEstimated: false, timestamp: now.subtract(const Duration(days: 2, hours: 1, minutes: 30))),
      ],
    ));
  }

  Future<void> _fetchUserData(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _userName = data['fullName'] ?? 'Explorer';
        _userEmail = data['email'] ?? '';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('User data fetch: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _startGpsSensorFallback();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _stopPolling();
      _geolocatorSub?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _snapshotSub?.cancel();
    _safetyEventSub?.cancel();
    _geolocatorSub?.cancel();
    _resilienceEngine.dispose();
    _pdrEngine.dispose();
    _safetyEngine.dispose();
    _p1Facade.dispose();
    super.dispose();
  }
}

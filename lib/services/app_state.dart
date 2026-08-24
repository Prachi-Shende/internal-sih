import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'models.dart';
import 'mock_data.dart';
import '../config.dart';
import 'api_service.dart';
import 'session_service.dart';
import 'risk_engine.dart';
import 'safe_haven_engine.dart';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  SystemState _systemState = SystemState.normal;
  LocationEstimate _currentLocation = MockData.initialLocation;
  CommunicationStatus _communicationStatus = MockData.normalComm;
  RiskAssessment _riskAssessment = const RiskAssessment(
    risk: RiskLevel.low,
    score: 0,
    reasons: ['No significant risk factors detected'],
  );
  RiskLevel _currentRisk = RiskLevel.low;
  bool _isEmergencyActive = false;
  
  String _userName = 'Explorer';
  String _userEmail = '';
  
  Timer? _pollingTimer;
  StreamSubscription<Position>? _locationSubscription;
  final bool _isLocalOfflineQueueActive = false; // Source of truth for local offline queue
  String _geofenceState = 'OUTSIDE'; // Tracks last P2 geofence state for transition detection

  AppState() {
    WidgetsBinding.instance.addObserver(this);
    
    // Start polling immediately with the device UUID session
    _startPolling();
    _startRealLocationTracking();

    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      // Re-initialize ApiService session ID
      ApiService.sessionId = await SessionService.getOrCreateSessionId();

      if (user != null) {
        _fetchUserData(user.uid);
      } else {
        _userName = 'Explorer';
        _userEmail = '';
      }
      
      // Reset state and fetch live data for the new user/session
      _isEmergencyActive = false;
      _currentLocation = MockData.initialLocation;
      _recomputeRisk();
      _fetchUnifiedState();
      
      notifyListeners();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _startRealLocationTracking();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _stopPolling();
      _locationSubscription?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _locationSubscription?.cancel();
    super.dispose();
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = math.cos;
    var a = 0.5 - c((lat2 - lat1) * p) / 2 + c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)) * 1000;
  }

  Future<void> _startRealLocationTracking() async {
    if (AppConfig.MOCK_MODE) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    // 1. Fetch immediate position first
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _updateLocationAndPost(position);
    } catch (e) {
      debugPrint("Could not get initial position: $e");
    }

    // 2. Start listening for subsequent changes
    _locationSubscription?.cancel();
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen((Position position) {
      _updateLocationAndPost(position);
    });
  }

  void _updateLocationAndPost(Position position) {
    LocationConfidence conf = LocationConfidence.high;
    if (position.accuracy > 30) conf = LocationConfidence.medium;
    if (position.accuracy > 100) conf = LocationConfidence.low;

    _currentLocation = LocationEstimate(
      lat: position.latitude,
      lon: position.longitude,
      source: 'GPS',
      confidence: conf,
    );

    ApiService.postLocation(
      position.latitude,
      position.longitude,
      'GPS',
      conf == LocationConfidence.high ? 0.9 : 0.5,
    );

    _recomputeRisk();
    notifyListeners();
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

  /// Recomputes risk score and ranks Safe-Haven destinations (P3 Day 1 & Day 2)
  void _recomputeRisk({bool userReportedUnsafe = false}) {
    Hotspot? closestHotspot;
    double minDistance = double.infinity;

    for (final h in MockData.hotspots) {
      double dist = _calculateDistance(
        _currentLocation.lat,
        _currentLocation.lon,
        h.centerLat,
        h.centerLon,
      );
      if (dist < minDistance) {
        minDistance = dist;
        closestHotspot = h;
      }
    }

    double uncertaintyMeters = 5.0;
    if (_currentLocation.confidence == LocationConfidence.medium) uncertaintyMeters = 35.0;
    if (_currentLocation.confidence == LocationConfidence.low) uncertaintyMeters = 95.0;

    bool isDegraded = _currentLocation.source == 'PDR' || _systemState == SystemState.gpsDegraded;

    final telemetry = TelemetryData(
      lat: _currentLocation.lat,
      lon: _currentLocation.lon,
      locationSource: _currentLocation.source,
      locationConfidence: _currentLocation.confidence,
      uncertaintyMeters: uncertaintyMeters,
      isDegraded: isDegraded,
      isStationary: false,
      routeDeviationMeters: null,
      geofenceState: _geofenceState,
      hotspotDistanceMeters: minDistance == double.infinity ? -1 : minDistance,
      nearbyHotspot: closestHotspot,
      hotspotRiskLevel: closestHotspot != null ? ApiService.riskLevelToString(closestHotspot.risk) : null,
      reportedIncidents: closestHotspot?.reportedIncidents ?? 0,
      currentTime: DateTime.now(),
      userReportedUnsafe: userReportedUnsafe || _isEmergencyActive,
    );

    _riskAssessment = RiskEngine.assess(telemetry);
    _currentRisk = _riskAssessment.risk;

    // Rank Safe Locations using P3 SafeHavenEngine
    MockData.safeLocations = SafeHavenEngine.rankLocations(
      locations: MockData.safeLocations,
      userLat: _currentLocation.lat,
      userLon: _currentLocation.lon,
      locationConfidence: _currentLocation.confidence,
      hotspots: MockData.hotspots,
    );

    if (!AppConfig.MOCK_MODE) {
      ApiService.postRiskAssessment(
        riskLevel: _riskAssessment.risk,
        score: _riskAssessment.score,
        reasons: _riskAssessment.reasons,
        hotspotId: closestHotspot?.id,
      );
    }
  }

  Future<void> _fetchUnifiedState() async {
    if (AppConfig.MOCK_MODE) {
      _recomputeRisk();
      notifyListeners();
      return;
    }
    
    final data = await ApiService.getUnifiedState();
    if (data != null) {
      _currentLocation = LocationEstimate(
        lat: data['lat'],
        lon: data['lon'],
        source: data['source'],
        confidence: ApiService.parseConfidence(data['confidence'].toDouble()),
      );
      
      _communicationStatus = CommunicationStatus(
        internet: data['internet'],
        sms: data['sms'],
        relay: data['relay'],
        offlineQueue: _isLocalOfflineQueueActive,
        selectedChannel: data['selected_channel'],
      );
      
      if (!data['internet'] && !data['sms']) {
        _systemState = SystemState.offline;
      } else if (data['source'] == 'PDR') {
        _systemState = SystemState.gpsDegraded;
      } else {
        _systemState = SystemState.normal;
      }

      final newGeofenceState = data['geofence_state'] as String? ?? 'OUTSIDE';
      _geofenceState = newGeofenceState;

      final hotspots = await ApiService.getHotspots();
      if (hotspots.isNotEmpty) {
        MockData.mockHotspot = hotspots.first;
        MockData.hotspots = hotspots;
      }

      final safeLocs = await ApiService.getSafeLocations(_currentLocation.lat, _currentLocation.lon);
      if (safeLocs.isNotEmpty) {
        MockData.safeLocations = safeLocs;
      }
      
      _recomputeRisk();
      notifyListeners();
    }
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
      debugPrint('Error fetching user data: $e');
    }
  }
  
  SystemState get systemState => _systemState;
  LocationEstimate get currentLocation => _currentLocation;
  CommunicationStatus get communicationStatus => _communicationStatus;
  RiskAssessment get riskAssessment => _riskAssessment;
  RiskLevel get currentRisk => _riskAssessment.risk;
  bool get isEmergencyActive => _isEmergencyActive;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get geofenceState => _geofenceState;

  void activateSafetyAssist() {
    _isEmergencyActive = true;
    _recomputeRisk(userReportedUnsafe: true);
    
    double confidenceFloat = 0.5;
    if (_currentLocation.confidence == LocationConfidence.high) confidenceFloat = 0.9;
    if (_currentLocation.confidence == LocationConfidence.low) confidenceFloat = 0.2;

    if (!AppConfig.MOCK_MODE) {
      ApiService.createIncident(
        _currentLocation.lat,
        _currentLocation.lon,
        _currentLocation.source,
        confidenceFloat,
        riskLevel: _currentRisk,
      );
    }
    
    notifyListeners();
  }
  
  void resolveIncident() {
    _isEmergencyActive = false;
    _systemState = SystemState.normal;
    _recomputeRisk(userReportedUnsafe: false);
    notifyListeners();
  }

  void simulateGpsDegraded() {
    if (!AppConfig.MOCK_MODE) return;
    _systemState = SystemState.gpsDegraded;
    _currentLocation = LocationEstimate(
      lat: _currentLocation.lat,
      lon: _currentLocation.lon,
      source: 'PDR',
      confidence: LocationConfidence.medium,
    );
    _recomputeRisk();
    notifyListeners();
  }

  void simulateOffline() {
    if (!AppConfig.MOCK_MODE) return; 
    _systemState = SystemState.offline;
    _communicationStatus = MockData.offlineComm;
    _recomputeRisk();
    notifyListeners();
  }

  void resetSimulation() {
    if (!AppConfig.MOCK_MODE) return;
    _systemState = SystemState.normal;
    _currentLocation = MockData.initialLocation;
    _communicationStatus = MockData.normalComm;
    _isEmergencyActive = false;
    _recomputeRisk();
    notifyListeners();
  }
}

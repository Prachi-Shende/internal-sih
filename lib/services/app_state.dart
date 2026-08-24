import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'models.dart';
import 'mock_data.dart';
import '../config.dart';
import 'api_service.dart';
import 'session_service.dart';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  SystemState _systemState = SystemState.normal;
  LocationEstimate _currentLocation = MockData.initialLocation;
  CommunicationStatus _communicationStatus = MockData.normalComm;
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

    // 1. Fetch immediate position first (since distance filter may never trigger if sitting still)
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

  Future<void> _fetchUnifiedState() async {
    if (AppConfig.MOCK_MODE) return; 
    
    final data = await ApiService.getUnifiedState();
    if (data != null) {
      _currentLocation = LocationEstimate(
        lat: data['lat'],
        lon: data['lon'],
        source: data['source'],
        confidence: ApiService.parseConfidence(data['confidence'].toDouble()),
      );
      
      _currentRisk = ApiService.parseRiskLevel(data['risk']);
      
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

      // ── P2 Geofence-driven risk assessment ──────────────────────────────
      // When the geofence state changes (e.g. OUTSIDE → APPROACHING),
      // post a risk assessment to P5 so /risk/latest stays up to date.
      final newGeofenceState = data['geofence_state'] as String? ?? 'OUTSIDE';
      if (newGeofenceState != _geofenceState) {
        _geofenceState = newGeofenceState;
        _postGeofenceRiskAssessment(newGeofenceState, data['geofence_hotspot_id'] as String?);
      }

      // Inject live data into MockData so UI components naturally pick it up
      final hotspots = await ApiService.getHotspots();
      if (hotspots.isNotEmpty) {
        MockData.mockHotspot = hotspots.first;
        MockData.hotspots = hotspots;
      }

      final safeLocs = await ApiService.getSafeLocations(_currentLocation.lat, _currentLocation.lon);
      if (safeLocs.isNotEmpty) {
        MockData.safeLocations = safeLocs;
      }
      
      notifyListeners();
    }
  }

  /// Post a risk assessment to P5 based on P2's geofence transition.
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
      default: // OUTSIDE
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
  RiskLevel get currentRisk => _currentRisk;
  bool get isEmergencyActive => _isEmergencyActive;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get geofenceState => _geofenceState; // P2: 'OUTSIDE' | 'APPROACHING' | 'INSIDE'

  void activateSafetyAssist() {
    _isEmergencyActive = true;
    _currentRisk = RiskLevel.critical;
    
    // Map enum to backend confidence float
    double confidenceFloat = 0.5; // Medium default
    if (_currentLocation.confidence == LocationConfidence.high) confidenceFloat = 0.9;
    if (_currentLocation.confidence == LocationConfidence.low) confidenceFloat = 0.2;

    // FIX: Pass actual current risk level

    ApiService.createIncident(
      _currentLocation.lat,
      _currentLocation.lon,
      _currentLocation.source,
      confidenceFloat,
      riskLevel: _currentRisk,
    );

    // Also post a CRITICAL risk assessment since user explicitly triggered SOS
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

  // Demo overrides - these still work visually in MOCK_MODE
  void simulateGpsDegraded() {
    if (!AppConfig.MOCK_MODE) return; // Prevent silent override when live
    _systemState = SystemState.gpsDegraded;
    _currentLocation = LocationEstimate(
      lat: _currentLocation.lat,
      lon: _currentLocation.lon,
      source: 'PDR',
      confidence: LocationConfidence.medium,
    );
    notifyListeners();
  }

  void simulateOffline() {
    if (!AppConfig.MOCK_MODE) return; 
    _systemState = SystemState.offline;
    _communicationStatus = MockData.offlineComm;
    notifyListeners();
  }

  void resetSimulation() {
    if (!AppConfig.MOCK_MODE) return;
    _systemState = SystemState.normal;
    _currentLocation = MockData.initialLocation;
    _communicationStatus = MockData.normalComm;
    _currentRisk = RiskLevel.low;
    _isEmergencyActive = false;
    notifyListeners();
  }
}

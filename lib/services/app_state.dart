import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';
import 'mock_data.dart';
import 'risk_engine.dart';

class AppState extends ChangeNotifier {
  SystemState _systemState = SystemState.normal;
  LocationEstimate _currentLocation = MockData.initialLocation;
  CommunicationStatus _communicationStatus = MockData.normalComm;
  RiskAssessment _riskAssessment = const RiskAssessment(
    risk: RiskLevel.low,
    score: 0,
    reasons: ['No significant risk factors detected'],
  );
  bool _isEmergencyActive = false;
  
  String _userName = 'Explorer';
  String _userEmail = '';

  AppState() {
    _recomputeRisk();
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _fetchUserData(user.uid);
      } else {
        _userName = 'Explorer';
        _userEmail = '';
        notifyListeners();
      }
    });
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
  RiskLevel get currentRisk => _riskAssessment.risk; // kept for existing UI code
  bool get isEmergencyActive => _isEmergencyActive;
  String get userName => _userName;
  String get userEmail => _userEmail;

  /// Recomputes risk using the P3 RiskEngine.
  ///
  /// TODO(P2): replace MockData.mockHotspot with a live lookup of the
  /// hotspot (if any) containing _currentLocation.
  /// TODO(P1): pass a real routeDeviationMeters once PDR/route tracking
  /// exists; isolation is fixed to false until an isolation signal exists.
  void _recomputeRisk({bool userReportedUnsafe = false}) {
    _riskAssessment = RiskEngine.assess(
      nearbyHotspot: MockData.mockHotspot,
      currentTime: DateTime.now(),
      isIsolated: false,
      routeDeviationMeters: null,
      userReportedUnsafe: userReportedUnsafe,
    );
  }

  void activateSafetyAssist() {
    _isEmergencyActive = true;
    _recomputeRisk(userReportedUnsafe: true);
    notifyListeners();
  }
  
  void resolveIncident() {
    _isEmergencyActive = false;
    _recomputeRisk(userReportedUnsafe: false);
    _systemState = SystemState.normal;
    notifyListeners();
  }

  // Helper methods to simulate state changes if the UI needs it for testing visually
  void simulateGpsDegraded() {
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
    _systemState = SystemState.offline;
    _communicationStatus = MockData.offlineComm;
    notifyListeners();
  }

  void resetSimulation() {
    _systemState = SystemState.normal;
    _currentLocation = MockData.initialLocation;
    _communicationStatus = MockData.normalComm;
    _riskAssessment = const RiskAssessment(
      risk: RiskLevel.low,
      score: 0,
      reasons: ['No significant risk factors detected'],
    );
    _isEmergencyActive = false;
    notifyListeners();
  }
}
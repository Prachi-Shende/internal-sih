import 'package:flutter/foundation.dart';
import 'models.dart';
import 'mock_data.dart';

class AppState extends ChangeNotifier {
  SystemState _systemState = SystemState.normal;
  LocationEstimate _currentLocation = MockData.initialLocation;
  CommunicationStatus _communicationStatus = MockData.normalComm;
  RiskLevel _currentRisk = RiskLevel.low;
  bool _isEmergencyActive = false;
  
  SystemState get systemState => _systemState;
  LocationEstimate get currentLocation => _currentLocation;
  CommunicationStatus get communicationStatus => _communicationStatus;
  RiskLevel get currentRisk => _currentRisk;
  bool get isEmergencyActive => _isEmergencyActive;

  void activateSafetyAssist() {
    _isEmergencyActive = true;
    _currentRisk = RiskLevel.high;
    notifyListeners();
  }
  
  void resolveIncident() {
    _isEmergencyActive = false;
    _currentRisk = RiskLevel.low;
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
    _currentRisk = RiskLevel.low;
    _isEmergencyActive = false;
    notifyListeners();
  }
}

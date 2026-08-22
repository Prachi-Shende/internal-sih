import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitors internet connectivity independently from positioning systems.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  final StreamController<bool> _statusController = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;

  StreamSubscription? _subscription;
  bool _isSimulationMode = false;

  Future<void> start() async {
    if (_isSimulationMode) return;

    try {
      final initial = await _connectivity.checkConnectivity();
      _updateStatus(initial);

      _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
    } catch (e) {
      // Platform plugin unavailable (e.g. headless unit tests)
      _isOnline = true; // default optimistic
    }
  }

  void _updateStatus(List<ConnectivityResult> results) {
    if (_isSimulationMode) return;

    final online = results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.ethernet);

    if (_isOnline != online) {
      _isOnline = online;
      if (!_statusController.isClosed) {
        _statusController.add(online);
      }
    }
  }

  /// Sets simulated internet status for developer testing.
  void setSimulatedStatus(bool online) {
    _isSimulationMode = true;
    _isOnline = online;
    if (!_statusController.isClosed) {
      _statusController.add(online);
    }
  }

  void clearSimulation() {
    _isSimulationMode = false;
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}

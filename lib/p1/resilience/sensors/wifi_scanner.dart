import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/wifi_fingerprint.dart';

/// Common contract for ambient Wi-Fi radio environment scanners.
abstract class WifiScanner {
  /// Whether Wi-Fi hardware scanning is currently supported and permitted.
  bool get isAvailable;

  /// Performs a single point-in-time Wi-Fi scan and returns the observed fingerprint.
  Future<WifiFingerprint?> scan();

  /// Continuous stream of Wi-Fi scan results.
  Stream<WifiFingerprint> get scanStream;

  /// Starts background/periodic scanning if supported.
  Future<void> start();

  /// Stops background scanning.
  Future<void> stop();

  /// Disposes of active resources and controllers.
  void dispose();
}

/// Deterministic Wi-Fi scanner for testing, simulation, and desktop environments.
class SimulatedWifiScanner implements WifiScanner {
  bool _isAvailable = true;
  @override
  bool get isAvailable => _isAvailable;

  final StreamController<WifiFingerprint> _scanController =
      StreamController<WifiFingerprint>.broadcast();
  @override
  Stream<WifiFingerprint> get scanStream => _scanController.stream;

  WifiFingerprint? _lastScan;
  WifiFingerprint? get lastScan => _lastScan;

  bool _isStarted = false;
  Timer? _periodicTimer;

  void setAvailability(bool available) {
    _isAvailable = available;
  }

  /// Injects a specific Wi-Fi fingerprint observation into the scanner.
  void injectScan(WifiFingerprint fingerprint) {
    _lastScan = fingerprint;
    if (!_scanController.isClosed) {
      _scanController.add(fingerprint);
    }
  }

  @override
  Future<WifiFingerprint?> scan() async {
    if (!_isAvailable) {
      debugPrint('[WIFI_SCANNER] Scan failed: Wi-Fi unavailable');
      return null;
    }
    return _lastScan;
  }

  @override
  Future<void> start({Duration interval = const Duration(seconds: 15)}) async {
    if (_isStarted) return;
    _isStarted = true;

    _periodicTimer = Timer.periodic(interval, (_) async {
      if (_isAvailable && _lastScan != null) {
        if (!_scanController.isClosed) {
          _scanController.add(_lastScan!);
        }
      }
    });
  }

  @override
  Future<void> stop() async {
    _isStarted = false;
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  @override
  void dispose() {
    stop();
    _scanController.close();
  }
}

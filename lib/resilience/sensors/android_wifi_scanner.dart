import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/wifi_fingerprint.dart';
import 'wifi_scanner.dart';

/// Operational status of the hardware Wi-Fi scanner.
enum WifiScannerStatus {
  permissionRequired,
  wifiDisabled,
  scanAvailable,
  scanUnavailable,
  scanFailed,
}

/// Production Android hardware Wi-Fi scanner communicating via platform MethodChannel (`sih/wifi_scan`).
class AndroidWifiScanner implements WifiScanner {
  static const MethodChannel _channel = MethodChannel('sih/wifi_scan');

  final StreamController<WifiFingerprint> _scanController =
      StreamController<WifiFingerprint>.broadcast();

  bool _isStarted = false;
  bool _isAvailable = false;
  WifiScannerStatus _status = WifiScannerStatus.scanUnavailable;
  Timer? _periodicScanTimer;

  // Opportunistic background scan interval (e.g., every 15s when active)
  final Duration scanInterval;

  AndroidWifiScanner({this.scanInterval = const Duration(seconds: 15)});

  @override
  bool get isAvailable => _isAvailable;

  WifiScannerStatus get status => _status;

  @override
  Stream<WifiFingerprint> get scanStream => _scanController.stream;

  @override
  Future<void> start() async {
    if (_isStarted) return;
    _isStarted = true;

    // Check availability on current platform
    if (defaultTargetPlatform != TargetPlatform.android) {
      _isAvailable = false;
      _status = WifiScannerStatus.scanUnavailable;
      return;
    }

    try {
      final isEnabled = await isWifiEnabled();
      final hasPerms = await checkPermissions();

      if (!hasPerms) {
        _status = WifiScannerStatus.permissionRequired;
        _isAvailable = false;
      } else if (!isEnabled) {
        _status = WifiScannerStatus.wifiDisabled;
        _isAvailable = false;
      } else {
        _status = WifiScannerStatus.scanAvailable;
        _isAvailable = true;
      }
    } catch (e) {
      _isAvailable = false;
      _status = WifiScannerStatus.scanUnavailable;
    }

    // Start periodic background scan if available
    _periodicScanTimer?.cancel();
    _periodicScanTimer = Timer.periodic(scanInterval, (_) async {
      if (_isStarted && _isAvailable) {
        await scan();
      }
    });
  }

  @override
  Future<void> stop() async {
    _isStarted = false;
    _periodicScanTimer?.cancel();
    _periodicScanTimer = null;
  }

  /// Checks if Wi-Fi radio is enabled on device.
  Future<bool> isWifiEnabled() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final enabled = await _channel.invokeMethod<bool>('isWifiEnabled');
      return enabled ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Checks if location & Wi-Fi permissions are granted.
  Future<bool> checkPermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final granted = await _channel.invokeMethod<bool>('checkPermissions');
      return granted ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Requests location & Wi-Fi permissions.
  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final requested = await _channel.invokeMethod<bool>('requestPermissions');
      return requested ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<WifiFingerprint?> scan() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    try {
      // 1. Check permissions & Wi-Fi status
      final hasPerms = await checkPermissions();
      if (!hasPerms) {
        _status = WifiScannerStatus.permissionRequired;
        _isAvailable = false;
        return null;
      }

      final isEnabled = await isWifiEnabled();
      if (!isEnabled) {
        _status = WifiScannerStatus.wifiDisabled;
        _isAvailable = false;
        return null;
      }

      _status = WifiScannerStatus.scanAvailable;
      _isAvailable = true;

      // 2. Trigger native scan via MethodChannel
      final rawResults = await _channel.invokeMethod<List<dynamic>>('startScan');
      if (rawResults == null) {
        return null;
      }

      final observations = <WifiAccessPointObservation>[];

      for (final item in rawResults) {
        if (item is Map) {
          final bssid = item['bssid']?.toString() ?? '';
          if (bssid.isEmpty || bssid == '00:00:00:00:00:00') continue;

          final ssid = item['ssid']?.toString() ?? '';
          final rssi = (item['rssi'] is num) ? (item['rssi'] as num).toInt() : -99;
          final frequency = (item['frequencyMhz'] is num)
              ? (item['frequencyMhz'] as num).toInt()
              : 2412;

          observations.add(
            WifiAccessPointObservation(
              bssid: bssid,
              ssid: ssid,
              rssi: rssi,
              frequencyMhz: frequency,
            ),
          );
        }
      }

      if (observations.isEmpty) {
        return null;
      }

      final fingerprint = WifiFingerprint(
        timestamp: DateTime.now(),
        observations: observations,
      );

      if (!_scanController.isClosed) {
        _scanController.add(fingerprint);
      }

      return fingerprint;
    } on PlatformException catch (_) {
      _status = WifiScannerStatus.scanFailed;
      return null;
    } catch (_) {
      _status = WifiScannerStatus.scanFailed;
      return null;
    }
  }

  @override
  void dispose() {
    stop();
    _scanController.close();
  }
}

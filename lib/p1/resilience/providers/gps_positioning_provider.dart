import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/gps_health.dart';
import '../models/position_estimate.dart';
import '../models/position_source.dart';
import 'positioning_provider.dart';

/// GPS positioning provider that interfaces with device GNSS hardware via `geolocator`,
/// with explicit GPS health state tracking and tolerant watchdog thresholds.
class GpsPositioningProvider implements PositioningProvider {
  @override
  PositionSource get source => PositionSource.gps;

  bool _isAvailable = false;
  @override
  bool get isAvailable => _isAvailable;

  GpsHealth _health = GpsHealth.disabled;
  GpsHealth get health => _health;

  PositionEstimate? _currentPosition;
  @override
  PositionEstimate? get currentPosition => _currentPosition;

  final StreamController<PositionEstimate> _positionController =
      StreamController<PositionEstimate>.broadcast();
  @override
  Stream<PositionEstimate> get positionStream => _positionController.stream;

  final StreamController<bool> _availabilityController =
      StreamController<bool>.broadcast();
  Stream<bool> get availabilityStream => _availabilityController.stream;

  final StreamController<GpsHealth> _healthController =
      StreamController<GpsHealth>.broadcast();
  Stream<GpsHealth> get healthStream => _healthController.stream;

  StreamSubscription<Position>? _geolocatorSubscription;
  Timer? _heartbeatTimer;

  /// Duration after which a lack of fresh fixes is flagged as STALE (nominal: 10s).
  final Duration staleTimeout;

  /// Duration after which sustained fix absence is declared LOST (nominal: 25s).
  final Duration lossTimeout;

  DateTime? _lastFixTimestamp;
  DateTime? get lastFixTimestamp => _lastFixTimestamp;

  bool _isStarted = false;
  bool _isSimulationMode = false;

  GpsPositioningProvider({
    this.staleTimeout = const Duration(seconds: 10),
    this.lossTimeout = const Duration(seconds: 25),
  });

  @override
  Future<void> start() async {
    if (_isStarted) return;
    _isStarted = true;

    if (_isSimulationMode) return;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setHealth(GpsHealth.disabled);
        _setAvailability(false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setHealth(GpsHealth.disabled);
        _setAvailability(false);
        return;
      }

      _setHealth(GpsHealth.searching);

      // On Android, use distanceFilter: 0 so updates arrive even when phone is stationary on a desk
      late final LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 1),
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        );
      }

      _geolocatorSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _handleGpsReading,
        onError: (dynamic error) {
          debugPrint('GpsPositioningProvider error: $error');
          _setHealth(GpsHealth.lost);
          _setAvailability(false);
        },
      );

      // Watchdog evaluates GPS health continuously every 1 second
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_isSimulationMode) return;

        if (_lastFixTimestamp == null) {
          if (_health != GpsHealth.disabled) {
            _setHealth(GpsHealth.searching);
          }
          return;
        }

        final elapsed = DateTime.now().difference(_lastFixTimestamp!);

        if (elapsed <= staleTimeout) {
          _setHealth(GpsHealth.active);
          _setAvailability(true);
        } else if (elapsed <= lossTimeout) {
          // STALE: Fix is older than 10s, but do NOT declare loss or switch to PDR fallback
          _setHealth(GpsHealth.stale);
          _setAvailability(true);
        } else {
          // LOST: Sustained loss (> 25s) without any satellite fix
          if (_health != GpsHealth.lost) {
            debugPrint('GpsPositioningProvider: Sustained GPS loss (> ${lossTimeout.inSeconds}s)');
            _setHealth(GpsHealth.lost);
            _setAvailability(false);
          }
        }
      });
    } catch (e) {
      debugPrint('GpsPositioningProvider initialization failed: $e');
      _setHealth(GpsHealth.disabled);
      _setAvailability(false);
    }
  }

  void _handleGpsReading(Position pos) {
    _lastFixTimestamp = DateTime.now();

    final confidence = _calculateGpsConfidence(pos.accuracy);

    final estimate = PositionEstimate(
      latitude: pos.latitude,
      longitude: pos.longitude,
      source: PositionSource.gps,
      confidence: confidence,
      uncertaintyMeters: pos.accuracy > 0 ? pos.accuracy : 4.0,
      timestamp: pos.timestamp,
      isAbsolute: true,
      isDegraded: false,
      headingDegrees: pos.heading >= 0 ? pos.heading : null,
      speedMps: pos.speed >= 0 ? pos.speed : null,
      altitude: pos.altitude,
    );

    _currentPosition = estimate;
    _setHealth(GpsHealth.active);
    _setAvailability(true);

    if (!_positionController.isClosed) {
      _positionController.add(estimate);
    }
  }

  double _calculateGpsConfidence(double accuracyMeters) {
    if (accuracyMeters <= 3.0) return 0.98;
    if (accuracyMeters <= 6.0) return 0.95;
    if (accuracyMeters <= 10.0) return 0.90;
    if (accuracyMeters <= 20.0) return 0.75;
    if (accuracyMeters <= 50.0) return 0.55;
    if (accuracyMeters <= 100.0) return 0.35;
    return 0.15;
  }

  void _setHealth(GpsHealth newHealth) {
    if (_health != newHealth) {
      _health = newHealth;
      if (!_healthController.isClosed) {
        _healthController.add(newHealth);
      }
    }
  }

  void _setAvailability(bool available) {
    if (_isAvailable != available) {
      _isAvailable = available;
      if (!_availabilityController.isClosed) {
        _availabilityController.add(available);
      }
    }
  }

  /// Injects a simulated GPS position for testing and developer demonstration.
  void injectSimulatedPosition(PositionEstimate position) {
    _isSimulationMode = true;
    _lastFixTimestamp = DateTime.now();
    _currentPosition = position;
    _setHealth(GpsHealth.active);
    _setAvailability(true);

    if (!_positionController.isClosed) {
      _positionController.add(position);
    }
  }

  /// Injects a simulated GPS health state for testing.
  void injectSimulatedHealth(GpsHealth simulatedHealth) {
    _isSimulationMode = true;
    _setHealth(simulatedHealth);
    _setAvailability(simulatedHealth.isHealthy);
  }

  /// Simulates GPS loss.
  void simulateGpsLoss() {
    _isSimulationMode = true;
    _setHealth(GpsHealth.lost);
    _setAvailability(false);
  }

  /// Clears simulation mode.
  void clearSimulation() {
    _isSimulationMode = false;
  }

  @override
  Future<void> stop() async {
    _isStarted = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _geolocatorSubscription?.cancel();
    _geolocatorSubscription = null;
    _setHealth(GpsHealth.disabled);
    _setAvailability(false);
  }

  void dispose() {
    stop();
    _positionController.close();
    _availabilityController.close();
    _healthController.close();
  }
}

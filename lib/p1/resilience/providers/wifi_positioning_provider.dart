import 'dart:async';
import 'package:flutter/foundation.dart';

import '../localization/wifi_fingerprint_matcher.dart';
import '../models/position_estimate.dart';
import '../models/position_source.dart';
import '../models/wifi_fingerprint.dart';
import '../repositories/localization_anchor_repository.dart';
import '../sensors/wifi_scanner.dart';
import 'positioning_provider.dart';

/// Autonomous positioning provider that acquires ambient Wi-Fi radio environments,
/// matches observed fingerprints against a reference anchor database using Weighted
/// K-Nearest-Neighbors (WKNN), and emits georeferenced [PositionEstimate] snapshots.
class WifiPositioningProvider implements PositioningProvider {
  final WifiScanner scanner;
  final LocalizationAnchorRepository repository;
  final WifiFingerprintMatcher matcher;
  final int kNearestNeighbors;

  final StreamController<PositionEstimate> _positionController =
      StreamController<PositionEstimate>.broadcast();
  final StreamController<bool> _availabilityController =
      StreamController<bool>.broadcast();

  StreamSubscription<WifiFingerprint>? _scanSubscription;

  bool _isStarted = false;
  bool _isAvailable = false;
  PositionEstimate? _currentPosition;
  AnchorMatchResult? _lastMatchResult;

  WifiPositioningProvider({
    WifiScanner? scanner,
    LocalizationAnchorRepository? repository,
    WifiFingerprintMatcher? matcher,
    this.kNearestNeighbors = 3,
  })  : scanner = scanner ?? SimulatedWifiScanner(),
        repository = repository ?? InMemoryLocalizationAnchorRepository(),
        matcher = matcher ?? const WifiFingerprintMatcher();

  @override
  PositionSource get source => PositionSource.wifiFingerprint;

  @override
  bool get isAvailable => _isAvailable;

  @override
  Stream<PositionEstimate> get positionStream => _positionController.stream;

  Stream<bool> get availabilityStream => _availabilityController.stream;

  @override
  PositionEstimate? get currentPosition => _currentPosition;

  AnchorMatchResult? get lastMatchResult => _lastMatchResult;

  @override
  Future<void> start() async {
    if (_isStarted) return;
    _isStarted = true;

    _scanSubscription = scanner.scanStream.listen(_processFingerprint);
    await scanner.start();
  }

  @override
  Future<void> stop() async {
    _isStarted = false;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await scanner.stop();
    _setAvailability(false);
  }

  void _setAvailability(bool available) {
    if (_isAvailable != available) {
      _isAvailable = available;
      if (!_availabilityController.isClosed) {
        _availabilityController.add(available);
      }
    }
  }

  /// Triggers a manual point-in-time scan and matches against the reference database.
  Future<PositionEstimate?> scanAndLocalize() async {
    if (!scanner.isAvailable) {
      debugPrint('[WIFI] REJECT reason=Wi-Fi scanner hardware unavailable or disabled');
      _setAvailability(false);
      return null;
    }

    final fingerprint = await scanner.scan();
    if (fingerprint == null || fingerprint.observations.isEmpty) {
      debugPrint('[WIFI] REJECT reason=Wi-Fi scan produced 0 access points');
      _setAvailability(false);
      return null;
    }

    return _processFingerprint(fingerprint);
  }

  Future<PositionEstimate?> _processFingerprint(WifiFingerprint fingerprint) async {
    try {
      debugPrint('[WIFI] scan=${fingerprint.count} APs');

      if (fingerprint.observations.isEmpty) {
        debugPrint('[WIFI] REJECT reason=No Wi-Fi observations in scan');
        _setAvailability(false);
        return null;
      }

      // Fetch reference dataset
      final candidates = await repository.getAllAnchors();
      if (candidates.isEmpty) {
        debugPrint('[WIFI] REJECT reason=No reference candidate anchors in repository');
        _setAvailability(false);
        return null;
      }

      // Execute WKNN matching
      final result = matcher.matchKnn(
        observed: fingerprint,
        candidateAnchors: candidates,
        k: kNearestNeighbors,
      );
      _lastMatchResult = result;

      if (!result.isAccepted || result.estimatedLatitude == null || result.estimatedLongitude == null) {
        debugPrint('[WIFI] REJECT reason=${result.rejectionReason ?? "Low similarity score or insufficient overlap"}');
        _setAvailability(false);
        return null;
      }

      debugPrint('[WIFI] MATCH candidates=${result.matchedCandidatesCount} bestScore=${(result.similarityScore * 100).toStringAsFixed(1)}%');

      final estimate = PositionEstimate(
        latitude: result.estimatedLatitude!,
        longitude: result.estimatedLongitude!,
        source: PositionSource.wifiFingerprint,
        confidence: result.confidence,
        uncertaintyMeters: result.uncertaintyMeters,
        timestamp: DateTime.now(),
        isAbsolute: true,
        isDegraded: false,
      );

      debugPrint(
        '[WIFI] POSITION lat=${estimate.latitude.toStringAsFixed(6)} '
        'lon=${estimate.longitude.toStringAsFixed(6)} '
        'uncertainty=±${estimate.uncertaintyMeters.toStringAsFixed(1)}m',
      );

      _currentPosition = estimate;
      _setAvailability(true);

      if (!_positionController.isClosed) {
        _positionController.add(estimate);
      }

      return estimate;
    } catch (e) {
      debugPrint('[WIFI] REJECT reason=Unexpected localization exception: $e');
      _setAvailability(false);
      return null;
    }
  }

  void dispose() {
    stop();
    _positionController.close();
    _availabilityController.close();
    scanner.dispose();
  }
}

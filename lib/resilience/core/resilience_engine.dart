import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../pdr/utils/geo_utils.dart';
import '../localization/wifi_fingerprint_matcher.dart';
import '../map/map_constraint_provider.dart';
import '../models/gps_health.dart';
import '../models/position_estimate.dart';
import '../models/position_source.dart';
import '../models/positioning_mode.dart';
import '../models/resilience_event.dart';
import '../models/resilience_state.dart';
import '../models/wifi_fingerprint.dart';
import '../providers/gps_positioning_provider.dart';
import '../providers/pdr_positioning_provider.dart';
import '../repositories/localization_anchor_repository.dart';
import '../sensors/connectivity_service.dart';
import '../sensors/wifi_scanner.dart';
import 'resilience_config.dart';

/// Developer simulation override states for deterministic testing of the 4 cases.
enum ResilienceOverrideMode {
  auto,
  simulateGpsLoss,
  forceGps,
  forcePdr,
  simulateOffline,
  simulateTotalBlackout,
}

/// Orchestrates sensor positioning providers, authoritative handovers,
/// offline anchor corrections, map constraints, and resilience capabilities
/// with robust hysteresis to prevent source flapping during temporary GPS gaps.
class ResilienceEngine {
  final GpsPositioningProvider gpsProvider;
  final PdrPositioningProvider pdrProvider;
  final ConnectivityService connectivityService;
  final WifiScanner wifiScanner;
  final LocalizationAnchorRepository anchorRepository;
  final WifiFingerprintMatcher fingerprintMatcher;
  final MapConstraintProvider mapConstraintProvider;
  final ResilienceConfig config;

  ResilienceState _currentState = ResilienceState.initial();
  ResilienceState get currentState => _currentState;

  final StreamController<ResilienceState> _stateController =
      StreamController<ResilienceState>.broadcast();
  Stream<ResilienceState> get stateStream => _stateController.stream;

  final StreamController<ResilienceEvent> _eventController =
      StreamController<ResilienceEvent>.broadcast();
  Stream<ResilienceEvent> get eventStream => _eventController.stream;

  final List<ResilienceEvent> _eventHistory = [];
  List<ResilienceEvent> get eventHistory => List.unmodifiable(_eventHistory);

  StreamSubscription<PositionEstimate>? _gpsPosSubscription;
  StreamSubscription<bool>? _gpsAvailSubscription;
  StreamSubscription<GpsHealth>? _gpsHealthSubscription;
  StreamSubscription<PositionEstimate>? _pdrPosSubscription;
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<WifiFingerprint>? _wifiScanSubscription;

  ResilienceOverrideMode _overrideMode = ResilienceOverrideMode.auto;
  ResilienceOverrideMode get overrideMode => _overrideMode;

  bool _isStarted = false;
  bool get isRunning => _isStarted;

  PositionEstimate? _lastKnownPosition;
  bool _wasGpsAvailable = false;
  GpsHealth _lastGpsHealth = GpsHealth.disabled;
  String? _lastLoggedTelemetrySignature;

  ResilienceEngine({
    GpsPositioningProvider? gpsProvider,
    PdrPositioningProvider? pdrProvider,
    ConnectivityService? connectivityService,
    WifiScanner? wifiScanner,
    LocalizationAnchorRepository? anchorRepository,
    WifiFingerprintMatcher? fingerprintMatcher,
    MapConstraintProvider? mapConstraintProvider,
    ResilienceConfig? config,
  })  : gpsProvider = gpsProvider ?? GpsPositioningProvider(),
        pdrProvider = pdrProvider ?? PdrPositioningProvider(),
        connectivityService = connectivityService ?? ConnectivityService(),
        wifiScanner = wifiScanner ?? SimulatedWifiScanner(),
        anchorRepository = anchorRepository ?? InMemoryLocalizationAnchorRepository(),
        fingerprintMatcher = fingerprintMatcher ?? const WifiFingerprintMatcher(),
        mapConstraintProvider = mapConstraintProvider ?? PassThroughMapConstraintProvider(),
        config = config ?? ResilienceConfig.standard;

  /// Starts the resilience engine and underlying providers.
  Future<void> start() async {
    if (_isStarted) return;
    _isStarted = true;

    // 1. Start Connectivity monitoring
    _connectivitySubscription = connectivityService.statusStream.listen((online) {
      _currentState = _currentState.copyWith(
        capabilities: _currentState.capabilities.copyWith(internetAvailable: online),
        timestamp: DateTime.now(),
      );
      _logResilienceTelemetry();
      _emitState();
    });
    await connectivityService.start();

    // 2. Start PDR Provider
    _pdrPosSubscription = pdrProvider.positionStream.listen(_handlePdrPosition);
    await pdrProvider.start();

    // 3. Start GPS Provider
    _gpsPosSubscription = gpsProvider.positionStream.listen(_handleGpsPosition);
    _gpsAvailSubscription = gpsProvider.availabilityStream.listen(_handleGpsAvailabilityChange);
    _gpsHealthSubscription = gpsProvider.healthStream.listen(_handleGpsHealthChange);
    await gpsProvider.start();

    // 4. Start Wi-Fi Scanner monitoring
    _wifiScanSubscription = wifiScanner.scanStream.listen(_handleWifiScanResult);
    await wifiScanner.start();

    _currentState = _currentState.copyWith(
      capabilities: _currentState.capabilities.copyWith(
        internetAvailable: connectivityService.isOnline,
        wifiAvailable: wifiScanner.isAvailable,
        gpsHealth: gpsProvider.health,
      ),
      timestamp: DateTime.now(),
    );

    _logResilienceTelemetry();
  }

  void _logResilienceTelemetry() {
    final gpsStr = _currentState.capabilities.gpsHealth.label;
    final netStr = _currentState.capabilities.internetAvailable ? 'ONLINE' : 'OFFLINE';
    final modeStr = _currentState.positioningMode == PositioningMode.gps ? 'GPS' : 'PDR';
    final sourceStr = _currentState.position?.source.name.toUpperCase() ?? 'NONE';
    final statusStr = _currentState.capabilities.internetAvailable
        ? (_currentState.capabilities.gpsHealth == GpsHealth.active ? 'FULL' : 'DEGRADED')
        : 'OFFLINE';

    final signature = '$gpsStr|$netStr|$modeStr|$sourceStr|$statusStr';
    if (_lastLoggedTelemetrySignature != signature) {
      _lastLoggedTelemetrySignature = signature;
      _log('[RESILIENCE] GPS=$gpsStr NET=$netStr MODE=$modeStr SOURCE=$sourceStr STATUS=$statusStr');
    }
  }

  void _recordSourceTransition(PositionSource newSource, {String? customDescription}) {
    final prevSource = _currentState.position?.source;
    if (prevSource != newSource) {
      final desc = customDescription ?? '${prevSource?.name.toUpperCase() ?? "NONE"} → ${newSource.name.toUpperCase()}';
      _currentState = _currentState.copyWith(
        previousPositionSource: prevSource,
        lastTransitionDescription: desc,
        lastTransitionTimestamp: DateTime.now(),
      );
      _logResilienceTelemetry();
    }
  }

  Future<void> _handleGpsPosition(PositionEstimate gpsEstimate) async {
    if (_overrideMode == ResilienceOverrideMode.simulateGpsLoss ||
        _overrideMode == ResilienceOverrideMode.forcePdr ||
        _overrideMode == ResilienceOverrideMode.simulateTotalBlackout) {
      return;
    }

    _lastKnownPosition = gpsEstimate;

    // If recovering from PDR fallback mode, compute discrepancy and re-anchor
    if (_currentState.positioningMode == PositioningMode.pdrFallback) {
      double? discrepancy;
      if (_currentState.position != null) {
        discrepancy = GeoUtils.haversineDistance(
          lat1: _currentState.position!.latitude,
          lon1: _currentState.position!.longitude,
          lat2: gpsEstimate.latitude,
          lon2: gpsEstimate.longitude,
        );
      }
      pdrProvider.setAnchor(gpsEstimate);
      _handleGpsRecovery(discrepancy);
      return;
    }

    // Continuously update PDR anchor without wiping out historical trajectory
    pdrProvider.setAnchor(gpsEstimate);

    // If we are in GPS mode, apply map constraints and emit
    if (_currentState.positioningMode == PositioningMode.gps ||
        _currentState.positioningMode == PositioningMode.recovering) {
      final constraint = await mapConstraintProvider.constrain(gpsEstimate);
      final effectivePos = constraint.constrainedPosition;

      _recordSourceTransition(effectivePos.source);

      _currentState = _currentState.copyWith(
        position: effectivePos,
        isMapConstrained: constraint.wasSnapped,
        lastMapConstraintStatus: constraint.wasSnapped ? 'MATCHED (WALKABLE CORRIDOR)' : 'NOT APPLIED',
        lastMapConstraintDistanceMeters: constraint.distanceCorrectionMeters,
        pdrAnchor: gpsEstimate,
        pdrDisplacementMeters: 0.0,
        positioningMode: PositioningMode.gps,
        capabilities: _currentState.capabilities.copyWith(
          gpsAvailable: true,
          gpsHealth: GpsHealth.active,
        ),
        timestamp: DateTime.now(),
      );
      _logResilienceTelemetry();
      _emitState();
    }
  }

  void _handleGpsHealthChange(GpsHealth health) {
    if (_overrideMode == ResilienceOverrideMode.simulateGpsLoss ||
        _overrideMode == ResilienceOverrideMode.simulateTotalBlackout) {
      health = GpsHealth.lost;
    } else if (_overrideMode == ResilienceOverrideMode.forceGps) {
      health = GpsHealth.active;
    }

    _lastGpsHealth = health;
    _currentState = _currentState.copyWith(
      capabilities: _currentState.capabilities.copyWith(
        gpsHealth: health,
        gpsAvailable: health.isHealthy,
      ),
      timestamp: DateTime.now(),
    );

    // Handle health transitions
    if (health == GpsHealth.active) {
      if (_currentState.positioningMode == PositioningMode.pdrFallback) {
        _handleGpsRecovery();
      }
    } else if (health == GpsHealth.lost || health == GpsHealth.disabled) {
      if (_currentState.positioningMode == PositioningMode.gps) {
        _handleGpsLoss();
      }
    } else if (health == GpsHealth.stale) {
      // STALE: Temporary gap in satellite updates. Do NOT switch to PDR!
      _logResilienceTelemetry();
    }

    _emitState();
  }

  void _handleGpsAvailabilityChange(bool isGpsAvailable) {
    if (_overrideMode == ResilienceOverrideMode.simulateGpsLoss ||
        _overrideMode == ResilienceOverrideMode.simulateTotalBlackout) {
      isGpsAvailable = false;
    } else if (_overrideMode == ResilienceOverrideMode.forceGps) {
      isGpsAvailable = true;
    }

    final wasAvailable = _wasGpsAvailable;
    _wasGpsAvailable = isGpsAvailable;

    _currentState = _currentState.copyWith(
      capabilities: _currentState.capabilities.copyWith(
        gpsAvailable: isGpsAvailable,
        gpsHealth: isGpsAvailable ? GpsHealth.active : GpsHealth.lost,
      ),
      timestamp: DateTime.now(),
    );

    if (isGpsAvailable && !wasAvailable) {
      _handleGpsRecovery();
    } else if (!isGpsAvailable && wasAvailable) {
      _handleGpsLoss();
    }

    _logResilienceTelemetry();
    _emitState();
  }

  void _handleGpsLoss() {
    if (_currentState.positioningMode != PositioningMode.gps) {
      return;
    }

    final anchor = pdrProvider.anchor ?? _lastKnownPosition;
    final previousMode = _currentState.positioningMode;
    const newMode = PositioningMode.pdrFallback;

    // Use current PDR position or last anchor, marked with source PDR
    final rawFallback = pdrProvider.currentPosition ?? anchor;
    final fallbackPos = rawFallback?.copyWith(
      source: PositionSource.pdr,
      isDegraded: true,
      isAbsolute: false,
    );

    _recordSourceTransition(PositionSource.pdr, customDescription: 'GPS → PDR FALLBACK');

    _currentState = _currentState.copyWith(
      positioningMode: newMode,
      position: fallbackPos,
      pdrAnchor: anchor,
      pdrDisplacementMeters: pdrProvider.displacementFromAnchorMeters,
      capabilities: _currentState.capabilities.copyWith(
        gpsAvailable: false,
        gpsHealth: _lastGpsHealth == GpsHealth.disabled ? GpsHealth.disabled : GpsHealth.lost,
      ),
      timestamp: DateTime.now(),
    );

    _emitEvent(ResilienceEvent(
      timestamp: DateTime.now(),
      type: ResilienceEventType.gpsLost,
      previousMode: previousMode,
      newMode: newMode,
      position: fallbackPos,
      confidence: fallbackPos?.confidence,
      diagnosticInfo: 'Sustained GPS loss. Handover to PDR fallback.',
    ));

    _emitEvent(ResilienceEvent(
      timestamp: DateTime.now(),
      type: ResilienceEventType.switchedToPdr,
      previousMode: previousMode,
      newMode: newMode,
      position: fallbackPos,
      confidence: fallbackPos?.confidence,
      diagnosticInfo: 'PDR anchored to ${anchor?.latitude.toStringAsFixed(5)}, ${anchor?.longitude.toStringAsFixed(5)}',
    ));

    _logResilienceTelemetry();
  }

  void _handleGpsRecovery([double? precomputedDiscrepancy]) {
    if (_currentState.positioningMode != PositioningMode.pdrFallback) {
      return;
    }

    final gpsPos = gpsProvider.currentPosition;
    final currentPos = _currentState.position;

    double? discrepancyMeters = precomputedDiscrepancy;

    if (discrepancyMeters == null && gpsPos != null && currentPos != null) {
      discrepancyMeters = GeoUtils.haversineDistance(
        lat1: currentPos.latitude,
        lon1: currentPos.longitude,
        lat2: gpsPos.latitude,
        lon2: gpsPos.longitude,
      );
    }

    final previousMode = _currentState.positioningMode;
    const newMode = PositioningMode.gps;

    if (gpsPos != null) {
      pdrProvider.setAnchor(gpsPos);
    }

    _recordSourceTransition(PositionSource.gps, customDescription: 'PDR → GPS RECOVERED');

    _currentState = _currentState.copyWith(
      positioningMode: newMode,
      position: gpsPos ?? currentPos,
      pdrAnchor: gpsPos,
      pdrDisplacementMeters: 0.0,
      lastDiscrepancyMeters: discrepancyMeters,
      capabilities: _currentState.capabilities.copyWith(
        gpsAvailable: true,
        gpsHealth: GpsHealth.active,
      ),
      timestamp: DateTime.now(),
    );

    _emitEvent(ResilienceEvent(
      timestamp: DateTime.now(),
      type: ResilienceEventType.gpsRecovered,
      previousMode: previousMode,
      newMode: newMode,
      position: gpsPos,
      confidence: gpsPos?.confidence,
      discrepancyMeters: discrepancyMeters,
      diagnosticInfo: discrepancyMeters != null
          ? 'Discrepancy: ${discrepancyMeters.toStringAsFixed(1)}m'
          : 'GPS fix restored',
    ));

    _emitEvent(ResilienceEvent(
      timestamp: DateTime.now(),
      type: ResilienceEventType.pdrReanchored,
      previousMode: PositioningMode.recovering,
      newMode: newMode,
      position: gpsPos,
      confidence: gpsPos?.confidence,
      diagnosticInfo: 'PDR coordinate frame re-anchored to fresh GPS fix',
    ));

    _logResilienceTelemetry();
  }

  Future<void> _handlePdrPosition(PositionEstimate pdrEstimate) async {
    // If in PDR fallback mode, apply map constraints and update the active position
    if (_currentState.positioningMode == PositioningMode.pdrFallback ||
        _overrideMode == ResilienceOverrideMode.forcePdr ||
        !_currentState.capabilities.gpsAvailable) {
      final constraint = await mapConstraintProvider.constrain(pdrEstimate);
      final effectivePos = constraint.constrainedPosition;

      if (constraint.wasSnapped && !_currentState.isMapConstrained) {
        _log('[RESILIENCE] MAP CONSTRAINT APPLIED (${constraint.distanceCorrectionMeters.toStringAsFixed(1)}m)');
        _emitEvent(ResilienceEvent(
          timestamp: DateTime.now(),
          type: ResilienceEventType.mapConstraintApplied,
          position: effectivePos,
          diagnosticInfo: 'Position snapped ${constraint.distanceCorrectionMeters.toStringAsFixed(1)}m to walkable corridor',
        ));
      }

      // If at anchor point (displacement == 0) and anchor was wifiFingerprint, preserve wifiFingerprint source
      final anchorSource = pdrProvider.anchor?.source;
      final finalSource = (pdrProvider.displacementFromAnchorMeters == 0.0 && anchorSource == PositionSource.wifiFingerprint)
          ? PositionSource.wifiFingerprint
          : PositionSource.pdr;

      final updatedPos = effectivePos.copyWith(source: finalSource);

      _recordSourceTransition(updatedPos.source);

      _currentState = _currentState.copyWith(
        position: updatedPos,
        isMapConstrained: constraint.wasSnapped,
        lastMapConstraintStatus: constraint.wasSnapped ? 'MATCHED (WALKABLE CORRIDOR)' : 'NOT APPLIED',
        lastMapConstraintDistanceMeters: constraint.distanceCorrectionMeters,
        pdrDisplacementMeters: pdrProvider.displacementFromAnchorMeters,
        timestamp: DateTime.now(),
      );
      _emitState();
    }
  }

  // ============================================================
  // WI-FI OFFLINE LOCALIZATION & ANCHOR RE-ANCHORING
  // ============================================================

  /// Triggers an immediate Wi-Fi radio scan and matches against local offline anchors.
  Future<AnchorMatchResult?> performWifiLocalizationScan() async {
    if (!wifiScanner.isAvailable || _overrideMode == ResilienceOverrideMode.simulateTotalBlackout) {
      return null;
    }

    _emitEvent(ResilienceEvent(
      timestamp: DateTime.now(),
      type: ResilienceEventType.wifiScanStarted,
      diagnosticInfo: 'Initiating ambient Wi-Fi scan for local anchors',
    ));

    final fingerprint = await wifiScanner.scan();
    if (fingerprint == null) {
      _emitEvent(ResilienceEvent(
        timestamp: DateTime.now(),
        type: ResilienceEventType.wifiScanCompleted,
        diagnosticInfo: 'Wi-Fi scan produced 0 access points',
      ));
      return null;
    }

    return _processWifiFingerprint(fingerprint);
  }

  void _handleWifiScanResult(WifiFingerprint fingerprint) {
    _processWifiFingerprint(fingerprint);
  }

  WifiFingerprint? _lastProcessedFingerprint;

  Future<AnchorMatchResult> _processWifiFingerprint(WifiFingerprint fingerprint) async {
    if (identical(_lastProcessedFingerprint, fingerprint)) {
      final candidates = await anchorRepository.getAllAnchors();
      return fingerprintMatcher.match(observed: fingerprint, candidateAnchors: candidates);
    }
    _lastProcessedFingerprint = fingerprint;

    _currentState = _currentState.copyWith(
      lastWifiScanTimestamp: DateTime.now(),
      wifiScanApsCount: fingerprint.count,
      capabilities: _currentState.capabilities.copyWith(wifiAvailable: true),
    );

    // 1. Fetch offline candidates
    final candidates = await anchorRepository.getAllAnchors();

    // 2. Perform explainable matching
    final matchResult = fingerprintMatcher.match(
      observed: fingerprint,
      candidateAnchors: candidates,
    );

    _emitEvent(ResilienceEvent(
      timestamp: DateTime.now(),
      type: ResilienceEventType.wifiScanCompleted,
      diagnosticInfo: 'Observed ${fingerprint.count} APs. Best candidate: ${matchResult.matchedAnchor?.name ?? "None"}',
    ));

    if (matchResult.isAccepted && matchResult.matchedAnchor != null) {
      final anchor = matchResult.matchedAnchor!;

      // 3. Spatial Plausibility Filter (Anti-Teleportation Check)
      final currentEstimatedPos = _currentState.position ?? pdrProvider.currentPosition;
      double discrepancyMeters = 0.0;

      if (currentEstimatedPos != null) {
        discrepancyMeters = GeoUtils.haversineDistance(
          lat1: currentEstimatedPos.latitude,
          lon1: currentEstimatedPos.longitude,
          lat2: anchor.latitude,
          lon2: anchor.longitude,
        );
      }

      if (discrepancyMeters <= config.maxAnchorDiscrepancyMeters) {
        // ACCEPT ANCHOR: Re-anchor PDR and Reduce Uncertainty
        _log('[WIFI] scan=${fingerprint.count} APs best=${anchor.id} score=${matchResult.similarityScore.toStringAsFixed(2)} common=${matchResult.apOverlapCount} result=ACCEPT distance=${discrepancyMeters.toStringAsFixed(1)}m');

        final previousUncertainty = _currentState.position?.uncertaintyMeters ?? 40.0;

        final anchorPos = PositionEstimate(
          latitude: anchor.latitude,
          longitude: anchor.longitude,
          source: PositionSource.wifiFingerprint,
          confidence: matchResult.confidence,
          uncertaintyMeters: matchResult.uncertaintyMeters,
          timestamp: DateTime.now(),
          isAbsolute: true,
          isDegraded: false,
          headingDegrees: _currentState.position?.headingDegrees,
        );

        final constraint = await mapConstraintProvider.constrain(anchorPos);
        final effectiveAnchorPos = constraint.constrainedPosition;

        // Re-anchor PDR to the accepted landmark without wiping history
        pdrProvider.setAnchor(effectiveAnchorPos);

        _recordSourceTransition(effectiveAnchorPos.source, customDescription: 'PDR → WIFI ANCHOR (${anchor.name})');

        _currentState = _currentState.copyWith(
          position: effectiveAnchorPos,
          isMapConstrained: constraint.wasSnapped,
          lastMapConstraintStatus: constraint.wasSnapped ? 'MATCHED (WALKABLE CORRIDOR)' : 'NOT APPLIED',
          lastMapConstraintDistanceMeters: constraint.distanceCorrectionMeters,
          pdrAnchor: effectiveAnchorPos,
          pdrDisplacementMeters: 0.0,
          lastDiscrepancyMeters: discrepancyMeters,
          lastMatchedAnchor: anchor,
          lastWifiAnchorStatus: 'MATCHED',
          lastWifiCorrectionStatus: 'APPLIED',
          lastWifiSimilarityScore: matchResult.similarityScore,
          previousUncertaintyMeters: previousUncertainty,
          anchorCorrectionCount: _currentState.anchorCorrectionCount + 1,
          timestamp: DateTime.now(),
        );

        _emitEvent(ResilienceEvent(
          timestamp: DateTime.now(),
          type: ResilienceEventType.wifiAnchorMatched,
          position: anchorPos,
          confidence: matchResult.confidence,
          discrepancyMeters: discrepancyMeters,
          diagnosticInfo: 'Matched ${anchor.id} (${anchor.name}) at ${(matchResult.similarityScore * 100).toStringAsFixed(0)}% similarity',
        ));

        _emitEvent(ResilienceEvent(
          timestamp: DateTime.now(),
          type: ResilienceEventType.pdrAnchorCorrected,
          position: anchorPos,
          confidence: matchResult.confidence,
          discrepancyMeters: discrepancyMeters,
          diagnosticInfo: 'PDR coordinate frame re-anchored. Uncertainty reduced to ±${matchResult.uncertaintyMeters.toStringAsFixed(1)}m',
        ));

        if (!_currentState.capabilities.internetAvailable) {
          _emitEvent(ResilienceEvent(
            timestamp: DateTime.now(),
            type: ResilienceEventType.offlineAnchorUsed,
            diagnosticInfo: 'Local on-device anchor repository matched offline without internet',
          ));
        }
      } else {
        // REJECT ANCHOR: Large Discrepancy (Plausibility Failure)
        _log('[WIFI] scan=${fingerprint.count} APs best=${anchor.id} score=${matchResult.similarityScore.toStringAsFixed(2)} common=${matchResult.apOverlapCount} result=REJECT reason=DISCREPANCY_TOO_FAR (${discrepancyMeters.toStringAsFixed(1)}m > ${config.maxAnchorDiscrepancyMeters.toStringAsFixed(0)}m)');

        _currentState = _currentState.copyWith(
          lastWifiAnchorStatus: 'REJECTED — TOO FAR',
          lastWifiCorrectionStatus: 'REJECTED',
          lastWifiSimilarityScore: matchResult.similarityScore,
          timestamp: DateTime.now(),
        );

        _emitEvent(ResilienceEvent(
          timestamp: DateTime.now(),
          type: ResilienceEventType.pdrAnchorCorrectionRejected,
          position: _currentState.position,
          discrepancyMeters: discrepancyMeters,
          diagnosticInfo: 'Discrepancy ${discrepancyMeters.toStringAsFixed(1)}m > ${config.maxAnchorDiscrepancyMeters.toStringAsFixed(0)}m limit. Anti-teleportation triggered.',
        ));
      }
    } else {
      _log('[WIFI] scan=${fingerprint.count} APs best=${matchResult.matchedAnchor?.id ?? "NONE"} score=${matchResult.similarityScore.toStringAsFixed(2)} common=${matchResult.apOverlapCount} result=REJECT reason=${matchResult.rejectionReason ?? "NO_MATCH"}');

      _currentState = _currentState.copyWith(
        lastWifiAnchorStatus: 'NO MATCH',
        lastWifiCorrectionStatus: 'NONE',
        lastWifiSimilarityScore: matchResult.similarityScore,
        timestamp: DateTime.now(),
      );

      _emitEvent(ResilienceEvent(
        timestamp: DateTime.now(),
        type: ResilienceEventType.wifiAnchorRejected,
        diagnosticInfo: matchResult.rejectionReason ?? 'Fingerprint did not match known anchors',
      ));
    }

    _emitState();
    return matchResult;
  }

  /// Resets test session telemetry (event logs, counters, last transitions) without modifying anchors or PDR.
  void resetTestSession() {
    _eventHistory.clear();
    _lastLoggedTelemetrySignature = null;
    _currentState = _currentState.copyWith(
      previousPositionSource: null,
      lastTransitionDescription: null,
      lastTransitionTimestamp: null,
      lastDiscrepancyMeters: null,
      lastMatchedAnchor: null,
      lastWifiScanTimestamp: null,
      wifiScanApsCount: 0,
      lastWifiAnchorStatus: null,
      lastWifiCorrectionStatus: null,
      lastWifiSimilarityScore: null,
      anchorCorrectionCount: 0,
      isMapConstrained: false,
      lastMapConstraintDistanceMeters: null,
      lastMapConstraintStatus: null,
      previousUncertaintyMeters: null,
      pdrDisplacementMeters: 0.0,
      timestamp: DateTime.now(),
    );
    _log('[RESILIENCE] RESET TEST SESSION');
    _emitEvent(ResilienceEvent(
      timestamp: DateTime.now(),
      type: ResilienceEventType.modeChanged,
      diagnosticInfo: 'Test session reset by operator. History cleared.',
    ));
    _logResilienceTelemetry();
    _emitState();
  }

  /// Sets a developer simulation override mode.
  void setOverrideMode(ResilienceOverrideMode mode) {
    _overrideMode = mode;

    switch (mode) {
      case ResilienceOverrideMode.auto:
        gpsProvider.clearSimulation();
        connectivityService.clearSimulation();
        if (wifiScanner is SimulatedWifiScanner) {
          (wifiScanner as SimulatedWifiScanner).setAvailability(true);
        }
        _handleGpsHealthChange(gpsProvider.health);
        break;
      case ResilienceOverrideMode.simulateGpsLoss:
        gpsProvider.simulateGpsLoss();
        _handleGpsHealthChange(GpsHealth.lost);
        break;
      case ResilienceOverrideMode.forceGps:
        _handleGpsHealthChange(GpsHealth.active);
        break;
      case ResilienceOverrideMode.forcePdr:
        _handleGpsHealthChange(GpsHealth.lost);
        break;
      case ResilienceOverrideMode.simulateOffline:
        connectivityService.setSimulatedStatus(false);
        break;
      case ResilienceOverrideMode.simulateTotalBlackout:
        gpsProvider.simulateGpsLoss();
        connectivityService.setSimulatedStatus(false);
        if (wifiScanner is SimulatedWifiScanner) {
          (wifiScanner as SimulatedWifiScanner).setAvailability(false);
        }
        _handleGpsHealthChange(GpsHealth.lost);
        break;
    }
    _logResilienceTelemetry();
    _emitState();
  }

  void _emitState() {
    if (!_stateController.isClosed) {
      _stateController.add(_currentState);
    }
  }

  void _emitEvent(ResilienceEvent event) {
    _eventHistory.insert(0, event);
    if (_eventHistory.length > 50) {
      _eventHistory.removeLast();
    }
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void _log(String message) {
    debugPrint(message);
  }

  Future<void> stop() async {
    _isStarted = false;
    await _gpsPosSubscription?.cancel();
    await _gpsAvailSubscription?.cancel();
    await _gpsHealthSubscription?.cancel();
    await _pdrPosSubscription?.cancel();
    await _connectivitySubscription?.cancel();
    await _wifiScanSubscription?.cancel();
    await gpsProvider.stop();
    await pdrProvider.stop();
    await wifiScanner.stop();
    connectivityService.dispose();
  }

  void dispose() {
    stop();
    _stateController.close();
    _eventController.close();
  }
}

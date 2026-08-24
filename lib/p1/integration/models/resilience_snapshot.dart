import '../../resilience/models/resilience_state.dart';

/// Clean application-level DTO exposing positioning resilience, infrastructure case, and sensor health.
/// Consumed by P2 (Map Mode Selection), P3 (Risk Calculation), P4 (Fallback Triggers), and P6 (UI Badges).
class ResilienceSnapshot {
  /// Active positioning mode (e.g. 'gps', 'pdrFallback', 'recovering').
  final String mode;

  /// Active infrastructure case (e.g. 'case1', 'case2', 'case3', 'case4').
  final String infrastructureCase;

  /// High-level human-readable status banner (e.g. 'CASE 1 — FULLY CONNECTED', 'CASE 4 — OFFLINE DEAD RECKONING').
  final String systemStatusLabel;

  /// Qualitative confidence rating ('HIGH', 'MEDIUM', 'LOW', or 'UNKNOWN').
  final String confidenceRating;

  /// True if GPS hardware receiver has an active, validated satellite fix.
  final bool gpsAvailable;

  /// Granular GPS receiver health state ('disabled', 'searching', 'active', 'stale', 'lost').
  final String gpsHealth;

  /// True if Wi-Fi network scanning hardware is available.
  final bool wifiAvailable;

  /// True if PDR inertial dead reckoning is running and providing updates.
  final bool pdrActive;

  /// Currently active positioning source (e.g. 'gps', 'pdr', 'wifiFingerprint', 'fused', 'mapMatched', 'lastKnown').
  final String? activePositionSource;

  /// Point-in-time confidence score of the active position [0.0, 1.0].
  final double? activeConfidence;

  /// Point-in-time circular error horizontal uncertainty of the active position in meters.
  final double? activeUncertaintyMeters;

  /// True if internet data connection is active.
  final bool internetAvailable;

  /// Relative displacement in meters walked under PDR since the last geodetic anchor.
  final double pdrDisplacementMeters;

  /// Measured discrepancy in meters during the latest anchor or GPS recovery evaluation.
  final double? lastAnchorDiscrepancyMeters;

  /// ID of the latest matched localization landmark anchor.
  final String? lastMatchedAnchorId;

  /// Status of the latest Wi-Fi anchor evaluation ('MATCHED', 'NO MATCH', 'REJECTED — TOO FAR', etc.).
  final String? lastWifiAnchorStatus;

  /// Similarity percentage score of the latest matched Wi-Fi fingerprint anchor [0.0, 1.0].
  final double? lastWifiSimilarityScore;

  /// Total number of opportunistic anchor corrections applied in this session.
  final int anchorCorrectionCount;

  /// True if active position was constrained / snapped to an offline walkable corridor.
  final bool isMapConstrained;

  /// Status label of map corridor snapping evaluation.
  final String? lastMapConstraintStatus;

  /// Timestamp when this resilience snapshot was evaluated.
  final DateTime timestamp;

  const ResilienceSnapshot({
    required this.mode,
    required this.infrastructureCase,
    required this.systemStatusLabel,
    required this.confidenceRating,
    required this.gpsAvailable,
    required this.gpsHealth,
    required this.wifiAvailable,
    required this.pdrActive,
    this.activePositionSource,
    this.activeConfidence,
    this.activeUncertaintyMeters,
    required this.internetAvailable,
    required this.pdrDisplacementMeters,
    this.lastAnchorDiscrepancyMeters,
    this.lastMatchedAnchorId,
    this.lastWifiAnchorStatus,
    this.lastWifiSimilarityScore,
    required this.anchorCorrectionCount,
    required this.isMapConstrained,
    this.lastMapConstraintStatus,
    required this.timestamp,
  });

  /// Factory constructing [ResilienceSnapshot] from existing [ResilienceState].
  factory ResilienceSnapshot.fromResilienceState(
    ResilienceState state, {
    bool pdrIsRunning = true,
  }) {
    return ResilienceSnapshot(
      mode: state.positioningMode.name,
      infrastructureCase: state.infrastructureCase.name,
      systemStatusLabel: state.systemStatusLabel,
      confidenceRating: state.confidenceLabel,
      gpsAvailable: state.capabilities.gpsAvailable,
      gpsHealth: state.capabilities.gpsHealth.name,
      wifiAvailable: state.capabilities.wifiAvailable,
      pdrActive: pdrIsRunning,
      activePositionSource: state.position?.source.name,
      activeConfidence: state.position?.confidence,
      activeUncertaintyMeters: state.position?.uncertaintyMeters,
      internetAvailable: state.capabilities.internetAvailable,
      pdrDisplacementMeters: state.pdrDisplacementMeters,
      lastAnchorDiscrepancyMeters: state.lastDiscrepancyMeters,
      lastMatchedAnchorId: state.lastMatchedAnchor?.id,
      lastWifiAnchorStatus: state.lastWifiAnchorStatus,
      lastWifiSimilarityScore: state.lastWifiSimilarityScore,
      anchorCorrectionCount: state.anchorCorrectionCount,
      isMapConstrained: state.isMapConstrained,
      lastMapConstraintStatus: state.lastMapConstraintStatus,
      timestamp: state.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'infrastructureCase': infrastructureCase,
      'systemStatusLabel': systemStatusLabel,
      'confidenceRating': confidenceRating,
      'gpsAvailable': gpsAvailable,
      'gpsHealth': gpsHealth,
      'wifiAvailable': wifiAvailable,
      'pdrActive': pdrActive,
      'activePositionSource': activePositionSource,
      'activeConfidence': activeConfidence,
      'activeUncertaintyMeters': activeUncertaintyMeters,
      'internetAvailable': internetAvailable,
      'pdrDisplacementMeters': pdrDisplacementMeters,
      'lastAnchorDiscrepancyMeters': lastAnchorDiscrepancyMeters,
      'lastMatchedAnchorId': lastMatchedAnchorId,
      'lastWifiAnchorStatus': lastWifiAnchorStatus,
      'lastWifiSimilarityScore': lastWifiSimilarityScore,
      'anchorCorrectionCount': anchorCorrectionCount,
      'isMapConstrained': isMapConstrained,
      'lastMapConstraintStatus': lastMapConstraintStatus,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ResilienceSnapshot.fromJson(Map<String, dynamic> json) {
    return ResilienceSnapshot(
      mode: json['mode'] as String? ?? 'pdrFallback',
      infrastructureCase: json['infrastructureCase'] as String? ?? 'case4',
      systemStatusLabel: json['systemStatusLabel'] as String? ?? 'UNKNOWN',
      confidenceRating: json['confidenceRating'] as String? ?? 'UNKNOWN',
      gpsAvailable: (json['gpsAvailable'] as bool?) ?? false,
      gpsHealth: json['gpsHealth'] as String? ?? 'disabled',
      wifiAvailable: (json['wifiAvailable'] as bool?) ?? false,
      pdrActive: (json['pdrActive'] as bool?) ?? true,
      activePositionSource: json['activePositionSource'] as String?,
      activeConfidence: (json['activeConfidence'] as num?)?.toDouble(),
      activeUncertaintyMeters: (json['activeUncertaintyMeters'] as num?)?.toDouble(),
      internetAvailable: (json['internetAvailable'] as bool?) ?? false,
      pdrDisplacementMeters: (json['pdrDisplacementMeters'] as num?)?.toDouble() ?? 0.0,
      lastAnchorDiscrepancyMeters: (json['lastAnchorDiscrepancyMeters'] as num?)?.toDouble(),
      lastMatchedAnchorId: json['lastMatchedAnchorId'] as String?,
      lastWifiAnchorStatus: json['lastWifiAnchorStatus'] as String?,
      lastWifiSimilarityScore: (json['lastWifiSimilarityScore'] as num?)?.toDouble(),
      anchorCorrectionCount: (json['anchorCorrectionCount'] as num?)?.toInt() ?? 0,
      isMapConstrained: (json['isMapConstrained'] as bool?) ?? false,
      lastMapConstraintStatus: json['lastMapConstraintStatus'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'ResilienceSnapshot(mode: $mode, case: $infrastructureCase, '
        'source: $activePositionSource, conf: $confidenceRating, '
        'gps: $gpsHealth, net: ${internetAvailable ? "ONLINE" : "OFFLINE"})';
  }
}

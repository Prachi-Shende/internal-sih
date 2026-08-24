import 'infrastructure_case.dart';
import 'localization_anchor.dart';
import 'position_estimate.dart';
import 'positioning_mode.dart';
import 'position_source.dart';
import 'system_capabilities.dart';

/// Single unified state observed by the UI and safety applications.
class ResilienceState {
  /// Current physical hardware capabilities (GPS, Internet, Wi-Fi, etc.).
  final SystemCapabilities capabilities;

  /// Active operational positioning mode.
  final PositioningMode positioningMode;

  /// Current best-estimate position output (GPS, PDR, Wi-Fi Anchor, Map Matched, or Last Known).
  final PositionEstimate? position;

  /// Previous position source before the most recent transition.
  final PositionSource? previousPositionSource;

  /// Human-readable description of the last positioning source / mode transition.
  final String? lastTransitionDescription;

  /// Timestamp of the most recent transition.
  final DateTime? lastTransitionTimestamp;

  /// Current geodetic reference anchor used by the PDR engine.
  final PositionEstimate? pdrAnchor;

  /// Total relative displacement in meters walked under PDR since last anchor.
  final double pdrDisplacementMeters;

  /// Discrepancy distance in meters measured during the most recent GPS recovery or Wi-Fi anchor.
  final double? lastDiscrepancyMeters;

  /// Most recently matched and evaluated localization landmark anchor.
  final LocalizationAnchor? lastMatchedAnchor;

  /// Timestamp of the most recent Wi-Fi scan observation.
  final DateTime? lastWifiScanTimestamp;

  /// Total number of APs detected in the latest Wi-Fi scan.
  final int wifiScanApsCount;

  /// Status of the latest Wi-Fi anchor evaluation ('MATCHED', 'NO MATCH', 'REJECTED — TOO FAR', or null).
  final String? lastWifiAnchorStatus;

  /// Whether the Wi-Fi correction was applied to PDR ('APPLIED', 'REJECTED', or null).
  final String? lastWifiCorrectionStatus;

  /// Similarity percentage of the latest matched anchor (0.0 to 1.0).
  final double? lastWifiSimilarityScore;

  /// Total number of successful opportunistic anchor corrections applied during this session.
  final int anchorCorrectionCount;

  /// Whether the active position was snapped to an offline walkable corridor.
  final bool isMapConstrained;

  /// Distance in meters the position was snapped to the nearest corridor.
  final double? lastMapConstraintDistanceMeters;

  /// Status of map constraint evaluation ('MATCHED (WALKABLE CORRIDOR)', 'NOT APPLIED', etc.).
  final String? lastMapConstraintStatus;

  /// Prior uncertainty value in meters before the latest anchor correction.
  final double? previousUncertaintyMeters;

  /// Timestamp of this state snapshot.
  final DateTime timestamp;

  const ResilienceState({
    required this.capabilities,
    required this.positioningMode,
    required this.position,
    this.previousPositionSource,
    this.lastTransitionDescription,
    this.lastTransitionTimestamp,
    this.pdrAnchor,
    this.pdrDisplacementMeters = 0.0,
    this.lastDiscrepancyMeters,
    this.lastMatchedAnchor,
    this.lastWifiScanTimestamp,
    this.wifiScanApsCount = 0,
    this.lastWifiAnchorStatus,
    this.lastWifiCorrectionStatus,
    this.lastWifiSimilarityScore,
    this.anchorCorrectionCount = 0,
    this.isMapConstrained = false,
    this.lastMapConstraintDistanceMeters,
    this.lastMapConstraintStatus,
    this.previousUncertaintyMeters,
    required this.timestamp,
  });

  /// Automatically derives the active infrastructure case (Case 1, 2, 3, or 4) from capabilities.
  InfrastructureCase get infrastructureCase => InfrastructureCase.fromCapabilities(
        gpsAvailable: capabilities.gpsAvailable,
        internetAvailable: capabilities.internetAvailable,
      );

  /// High-level system state label.
  String get systemStatusLabel {
    if (positioningMode == PositioningMode.recovering) {
      return 'RECOVERING';
    }
    return infrastructureCase.statusLabel;
  }

  /// High-level confidence rating ('HIGH', 'MEDIUM', 'LOW', or 'UNKNOWN').
  String get confidenceLabel {
    if (position == null) return 'UNKNOWN';
    if (position!.confidence >= 0.80) return 'HIGH';
    if (position!.confidence >= 0.50) return 'MEDIUM';
    return 'LOW';
  }

  /// Default idle resilience state.
  static ResilienceState initial() {
    return ResilienceState(
      capabilities: SystemCapabilities.initial,
      positioningMode: PositioningMode.pdrFallback,
      position: null,
      previousPositionSource: null,
      lastTransitionDescription: null,
      lastTransitionTimestamp: null,
      pdrAnchor: null,
      pdrDisplacementMeters: 0.0,
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
      timestamp: DateTime.now(),
    );
  }

  ResilienceState copyWith({
    SystemCapabilities? capabilities,
    PositioningMode? positioningMode,
    PositionEstimate? position,
    PositionSource? previousPositionSource,
    String? lastTransitionDescription,
    DateTime? lastTransitionTimestamp,
    PositionEstimate? pdrAnchor,
    double? pdrDisplacementMeters,
    double? lastDiscrepancyMeters,
    LocalizationAnchor? lastMatchedAnchor,
    DateTime? lastWifiScanTimestamp,
    int? wifiScanApsCount,
    String? lastWifiAnchorStatus,
    String? lastWifiCorrectionStatus,
    double? lastWifiSimilarityScore,
    int? anchorCorrectionCount,
    bool? isMapConstrained,
    double? lastMapConstraintDistanceMeters,
    String? lastMapConstraintStatus,
    double? previousUncertaintyMeters,
    DateTime? timestamp,
  }) {
    return ResilienceState(
      capabilities: capabilities ?? this.capabilities,
      positioningMode: positioningMode ?? this.positioningMode,
      position: position ?? this.position,
      previousPositionSource: previousPositionSource ?? this.previousPositionSource,
      lastTransitionDescription: lastTransitionDescription ?? this.lastTransitionDescription,
      lastTransitionTimestamp: lastTransitionTimestamp ?? this.lastTransitionTimestamp,
      pdrAnchor: pdrAnchor ?? this.pdrAnchor,
      pdrDisplacementMeters: pdrDisplacementMeters ?? this.pdrDisplacementMeters,
      lastDiscrepancyMeters: lastDiscrepancyMeters ?? this.lastDiscrepancyMeters,
      lastMatchedAnchor: lastMatchedAnchor ?? this.lastMatchedAnchor,
      lastWifiScanTimestamp: lastWifiScanTimestamp ?? this.lastWifiScanTimestamp,
      wifiScanApsCount: wifiScanApsCount ?? this.wifiScanApsCount,
      lastWifiAnchorStatus: lastWifiAnchorStatus ?? this.lastWifiAnchorStatus,
      lastWifiCorrectionStatus: lastWifiCorrectionStatus ?? this.lastWifiCorrectionStatus,
      lastWifiSimilarityScore: lastWifiSimilarityScore ?? this.lastWifiSimilarityScore,
      anchorCorrectionCount: anchorCorrectionCount ?? this.anchorCorrectionCount,
      isMapConstrained: isMapConstrained ?? this.isMapConstrained,
      lastMapConstraintDistanceMeters: lastMapConstraintDistanceMeters ?? this.lastMapConstraintDistanceMeters,
      lastMapConstraintStatus: lastMapConstraintStatus ?? this.lastMapConstraintStatus,
      previousUncertaintyMeters: previousUncertaintyMeters ?? this.previousUncertaintyMeters,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'ResilienceState('
        'case: ${infrastructureCase.shortTitle}, '
        'mode: ${positioningMode.name}, '
        'pos: ${position != null ? "${position!.latitude.toStringAsFixed(5)}, ${position!.longitude.toStringAsFixed(5)}" : "NONE"}, '
        'source: ${position?.source.name ?? "NONE"}, '
        'conf: $confidenceLabel, '
        'GPS: ${capabilities.gpsAvailable ? "ON" : "OFF"}, '
        'Net: ${capabilities.internetAvailable ? "ONLINE" : "OFFLINE"}, '
        'Anchor: ${lastMatchedAnchor?.id ?? "NONE"}, '
        'MapMatched: $isMapConstrained)';
  }
}

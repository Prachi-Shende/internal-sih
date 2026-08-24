/// Centralized operational parameters and thresholds for the Resilience Engine.
class ResilienceConfig {
  /// Minimum normalized similarity score to accept a Wi-Fi fingerprint match [0.0 - 1.0].
  final double wifiMatchThreshold;

  /// Minimum common AP BSSIDs required between observation and candidate anchor.
  final int minApOverlapCount;

  /// Maximum spatial discrepancy (meters) allowed between PDR dead-reckoned location
  /// and matched Wi-Fi anchor before the anchor is rejected as implausible (anti-teleportation).
  final double maxAnchorDiscrepancyMeters;

  /// Watchdog timeout without GPS satellite fix before transitioning to PDR fallback.
  final Duration gpsLossTimeout;

  /// Default baseline uncertainty (meters) assigned when Wi-Fi anchor is accepted.
  final double defaultWifiAnchorUncertaintyMeters;

  const ResilienceConfig({
    this.wifiMatchThreshold = 0.70,
    this.minApOverlapCount = 2,
    this.maxAnchorDiscrepancyMeters = 100.0,
    this.gpsLossTimeout = const Duration(seconds: 6),
    this.defaultWifiAnchorUncertaintyMeters = 8.5,
  });

  static const ResilienceConfig standard = ResilienceConfig();
}

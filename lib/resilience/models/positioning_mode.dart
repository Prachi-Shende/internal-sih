/// Operational mode of the Resilience Engine positioning orchestrator.
enum PositioningMode {
  /// GPS is currently available, reliable, and serving as the primary source.
  gps,

  /// GPS is unavailable or unreliable; system is dead reckoning via PDR.
  pdrFallback,

  /// GPS signal has just returned; system is re-anchoring PDR and validating discrepancy.
  recovering,
}

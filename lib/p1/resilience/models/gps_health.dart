/// Explicit health and operational state of the device GPS/GNSS receiver.
enum GpsHealth {
  /// Android/device location service is disabled in system settings or permission is denied.
  disabled(label: 'OFF', isHealthy: false),

  /// GPS service is enabled, waiting for first satellite fix.
  searching(label: 'SEARCHING', isHealthy: false),

  /// Valid GPS fix has been received recently (within stale timeout).
  active(label: 'ACTIVE', isHealthy: true),

  /// No recent GPS update arrived (exceeded stale timeout), but location service is still enabled.
  /// Crucial: This state does NOT declare GPS lost or force PDR fallback.
  stale(label: 'STALE', isHealthy: true),

  /// GPS has been unavailable for a sustained period (> lost timeout) or explicitly failed.
  /// Authorizes PDR fallback handover.
  lost(label: 'LOST', isHealthy: false);

  final String label;
  final bool isHealthy;

  const GpsHealth({required this.label, required this.isHealthy});
}

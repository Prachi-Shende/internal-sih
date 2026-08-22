import 'position_estimate.dart';
import 'positioning_mode.dart';

/// Categories of significant resilience state transitions and positioning events.
enum ResilienceEventType {
  /// First GPS fix successfully acquired.
  gpsAcquired,

  /// GPS satellite fix lost or sensor timeout reached.
  gpsLost,

  /// Positioning seamlessly transitioned to PDR fallback.
  switchedToPdr,

  /// GPS signal regained after a loss period.
  gpsRecovered,

  /// PDR coordinate frame re-anchored to fresh GPS coordinates.
  pdrReanchored,

  /// Positioning confidence dropped below degradation threshold.
  positioningDegraded,

  /// Positioning quality recovered back to nominal confidence.
  positioningRecovered,

  /// Ambient Wi-Fi radio scan initiated.
  wifiScanStarted,

  /// Ambient Wi-Fi radio scan completed.
  wifiScanCompleted,

  /// Wi-Fi fingerprint successfully matched with an offline landmark anchor.
  wifiAnchorMatched,

  /// Wi-Fi fingerprint match rejected (low similarity score or insufficient AP overlap).
  wifiAnchorRejected,

  /// PDR coordinate frame re-anchored and corrected using an accepted Wi-Fi anchor.
  pdrAnchorCorrected,

  /// PDR anchor correction rejected due to large spatial discrepancy (> threshold).
  pdrAnchorCorrectionRejected,

  /// Offline local anchor database successfully utilized without internet connectivity.
  offlineAnchorUsed,

  /// Walking position snapped to offline walkable corridor network.
  mapConstraintApplied,

  /// Map constraint skipped or position outside known walkable graph.
  mapConstraintRejected,

  /// Positioning mode or operational test state changed.
  modeChanged,
}

/// Structured record of a resilience state transition or positioning recovery event.
class ResilienceEvent {
  final DateTime timestamp;
  final ResilienceEventType type;
  final PositioningMode? previousMode;
  final PositioningMode? newMode;
  final PositionEstimate? position;
  final double? confidence;
  final double? discrepancyMeters;
  final String diagnosticInfo;

  const ResilienceEvent({
    required this.timestamp,
    required this.type,
    this.previousMode,
    this.newMode,
    this.position,
    this.confidence,
    this.discrepancyMeters,
    this.diagnosticInfo = '',
  });

  @override
  String toString() {
    return '[RESILIENCE ${timestamp.toIso8601String().substring(11, 19)}] '
        '${type.name.toUpperCase()} '
        '${newMode != null ? "-> Mode: ${newMode!.name} " : ""}'
        '${discrepancyMeters != null ? "Discrepancy: ${discrepancyMeters!.toStringAsFixed(1)}m " : ""}'
        '${diagnosticInfo.isNotEmpty ? "($diagnosticInfo)" : ""}';
  }
}

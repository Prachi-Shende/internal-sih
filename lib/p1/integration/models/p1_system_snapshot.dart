import '../../pdr/models/pdr_state.dart';
import '../../resilience/models/resilience_state.dart';
import 'connectivity_snapshot.dart';
import 'movement_snapshot.dart';
import 'position_snapshot.dart';
import 'resilience_snapshot.dart';

/// Top-level unified integration DTO exposing the entire P1 subsystem state.
///
/// Serves as the single source of truth for:
/// - P2 (Maps & Route Navigation)
/// - P3 (Contextual Safety & Risk Engine)
/// - P4 (Emergency Communication & Blockchain)
/// - P5 (Backend Ingestion & Cloud Telemetry)
/// - P6 (UI Dashboards & Visualization)
class P1SystemSnapshot {
  /// ISO-8601 timestamp of this unified snapshot.
  final DateTime timestamp;

  /// Current best-estimate geographic position and spatial confidence.
  final PositionSnapshot position;

  /// Real-time pedestrian dead reckoning and kinematics metrics.
  final MovementSnapshot movement;

  /// Multi-tier positioning resilience and operational state machine.
  final ResilienceSnapshot resilience;

  /// Real-time hardware radio and internet connectivity status.
  final ConnectivitySnapshot connectivity;

  const P1SystemSnapshot({
    required this.timestamp,
    required this.position,
    required this.movement,
    required this.resilience,
    required this.connectivity,
  });

  /// Factory constructing a complete [P1SystemSnapshot] from internal P1 states.
  factory P1SystemSnapshot.build({
    required ResilienceState resilienceState,
    required PdrState pdrState,
    bool pdrIsRunning = true,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();

    return P1SystemSnapshot(
      timestamp: now,
      position: PositionSnapshot.fromPositionEstimate(
        resilienceState.position,
        fallbackTimestamp: now,
      ),
      movement: MovementSnapshot.fromPdrState(
        pdrState,
        fallbackTimestamp: now,
      ),
      resilience: ResilienceSnapshot.fromResilienceState(
        resilienceState,
        pdrIsRunning: pdrIsRunning,
      ),
      connectivity: ConnectivitySnapshot.fromCapabilities(
        resilienceState.capabilities,
        timestamp: now,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'position': position.toJson(),
      'movement': movement.toJson(),
      'resilience': resilience.toJson(),
      'connectivity': connectivity.toJson(),
    };
  }

  factory P1SystemSnapshot.fromJson(Map<String, dynamic> json) {
    final ts = json['timestamp'] != null
        ? DateTime.parse(json['timestamp'] as String)
        : DateTime.now();

    return P1SystemSnapshot(
      timestamp: ts,
      position: json['position'] != null
          ? PositionSnapshot.fromJson(json['position'] as Map<String, dynamic>)
          : PositionSnapshot(timestamp: ts),
      movement: json['movement'] != null
          ? MovementSnapshot.fromJson(json['movement'] as Map<String, dynamic>)
          : MovementSnapshot.fromPdrState(null, fallbackTimestamp: ts),
      resilience: json['resilience'] != null
          ? ResilienceSnapshot.fromJson(json['resilience'] as Map<String, dynamic>)
          : ResilienceSnapshot.fromResilienceState(ResilienceState.initial()),
      connectivity: json['connectivity'] != null
          ? ConnectivitySnapshot.fromJson(json['connectivity'] as Map<String, dynamic>)
          : ConnectivitySnapshot.fromCapabilities(ResilienceState.initial().capabilities, timestamp: ts),
    );
  }

  @override
  String toString() {
    return 'P1SystemSnapshot(pos: $position, mov: $movement, res: $resilience, con: $connectivity)';
  }
}

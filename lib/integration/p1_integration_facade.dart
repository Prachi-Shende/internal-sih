import 'dart:async';

import '../pdr/core/pdr_engine.dart';
import '../pdr/models/pdr_state.dart';
import '../resilience/core/resilience_engine.dart';
import '../resilience/models/resilience_state.dart';
import '../safety/core/safety_engine.dart';
import 'models/p1_system_snapshot.dart';

/// Clean, high-level facade providing a single entry point for external modules (P2, P3, P4, P5, P6)
/// to consume P1 outputs without accessing or modifying internal algorithms or sensor pipelines.
class P1IntegrationFacade {
  /// The underlying resilience orchestrator.
  final ResilienceEngine resilienceEngine;

  /// The underlying PDR engine.
  final PdrEngine pdrEngine;

  /// Optional safety engine instance.
  final SafetyEngine? safetyEngine;

  StreamController<P1SystemSnapshot>? _snapshotController;
  StreamSubscription<ResilienceState>? _resilienceSub;
  StreamSubscription<PdrState>? _pdrSub;

  P1IntegrationFacade({
    required this.resilienceEngine,
    PdrEngine? pdrEngine,
    this.safetyEngine,
  }) : pdrEngine = pdrEngine ?? resilienceEngine.pdrProvider.pdrEngine;

  /// Returns a point-in-time [P1SystemSnapshot] representing the active system state.
  /// This is completely read-only and will NEVER mutate, reset, or alter internal PDR or GPS state.
  P1SystemSnapshot getCurrentSnapshot() {
    return P1SystemSnapshot.build(
      resilienceState: resilienceEngine.currentState,
      pdrState: pdrEngine.currentState,
      pdrIsRunning: pdrEngine.isRunning || resilienceEngine.pdrProvider.isAvailable,
    );
  }

  /// Reactive stream of [P1SystemSnapshot] updates emitted whenever the user moves,
  /// GPS changes, or the resilience state machine transitions.
  Stream<P1SystemSnapshot> get snapshotStream {
    _snapshotController ??= StreamController<P1SystemSnapshot>.broadcast(
      onListen: _startListening,
      onCancel: _stopListening,
    );
    return _snapshotController!.stream;
  }

  void _startListening() {
    _resilienceSub = resilienceEngine.stateStream.listen((_) => _emitSnapshot());
    _pdrSub = pdrEngine.stateStream.listen((_) => _emitSnapshot());
  }

  void _stopListening() {
    _resilienceSub?.cancel();
    _resilienceSub = null;
    _pdrSub?.cancel();
    _pdrSub = null;
  }

  void _emitSnapshot() {
    if (_snapshotController != null && !_snapshotController!.isClosed && _snapshotController!.hasListener) {
      _snapshotController!.add(getCurrentSnapshot());
    }
  }

  /// Releases stream subscriptions.
  void dispose() {
    _stopListening();
    _snapshotController?.close();
  }
}

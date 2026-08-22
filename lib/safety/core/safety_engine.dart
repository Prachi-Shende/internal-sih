import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../resilience/core/resilience_engine.dart';
import '../../resilience/models/position_estimate.dart';
import '../models/delivery_result.dart';
import '../models/safety_event.dart';
import '../storage/file_safety_event_store.dart';
import '../storage/safety_event_store.dart';
import '../transport/dev_mock_safety_event_transport.dart';
import '../transport/safety_event_transport.dart';
import 'communication_orchestrator.dart';
import 'sync_manager.dart';

/// Offline Safety Engine coordinating resilient positioning snapshots,
/// local persistent event queues, and connectivity-aware delivery.
class SafetyEngine {
  final ResilienceEngine resilienceEngine;
  final SafetyEventStore store;
  final CommunicationOrchestrator orchestrator;
  final SyncManager syncManager;

  static int _idCounter = 1000;

  final StreamController<SafetyEvent> _eventController =
      StreamController<SafetyEvent>.broadcast();
  Stream<SafetyEvent> get eventStream => _eventController.stream;

  factory SafetyEngine({
    required ResilienceEngine resilienceEngine,
    SafetyEventStore? store,
    SafetyEventTransport? transport,
    CommunicationOrchestrator? orchestrator,
    SyncManager? syncManager,
  }) {
    final effectiveStore = store ?? FileSafetyEventStore();
    final effectiveTransport = transport ?? DevMockSafetyEventTransport();
    final effectiveOrchestrator = orchestrator ??
        CommunicationOrchestrator(
          connectivityService: resilienceEngine.connectivityService,
          store: effectiveStore,
          transport: effectiveTransport,
        );
    final effectiveSyncManager = syncManager ??
        SyncManager(
          connectivityService: resilienceEngine.connectivityService,
          store: effectiveStore,
          orchestrator: effectiveOrchestrator,
        );

    return SafetyEngine._internal(
      resilienceEngine: resilienceEngine,
      store: effectiveStore,
      orchestrator: effectiveOrchestrator,
      syncManager: effectiveSyncManager,
    );
  }

  SafetyEngine._internal({
    required this.resilienceEngine,
    required this.store,
    required this.orchestrator,
    required this.syncManager,
  });

  /// Initializes the safety engine, storage, and synchronization subsystem.
  Future<void> start() async {
    await store.init();
    syncManager.start();
  }

  /// Generates a unique, non-colliding event ID.
  String _generateEventId(SafetyEventType type) {
    _idCounter++;
    final prefix = type.label;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$prefix-$timestamp-$_idCounter';
  }

  /// Captures the current resilient positioning snapshot and constructs a [SafetyEvent].
  SafetyEvent _captureSnapshot({
    required SafetyEventType type,
    Map<String, dynamic>? metadata,
  }) {
    final resState = resilienceEngine.currentState;
    final PositionEstimate? pos = resState.position ??
        resilienceEngine.pdrProvider.currentPosition ??
        resilienceEngine.gpsProvider.currentPosition;

    // Data Integrity Rule: Never generate a fake 0,0 location.
    double? lat;
    double? lon;
    if (pos != null && !(pos.latitude == 0.0 && pos.longitude == 0.0)) {
      lat = pos.latitude;
      lon = pos.longitude;
    }

    final now = DateTime.now();
    final eventId = _generateEventId(type);

    return SafetyEvent(
      eventId: eventId,
      eventType: type,
      timestamp: now,
      latitude: lat,
      longitude: lon,
      positionSource: pos?.source,
      confidence: pos?.confidence,
      uncertaintyMeters: pos?.uncertaintyMeters,
      positioningMode: resState.positioningMode,
      gpsHealth: resState.capabilities.gpsHealth,
      internetAvailable: resState.capabilities.internetAvailable,
      eventStatus: EventDeliveryStatus.pending,
      retryCount: 0,
      createdAt: now,
      metadata: metadata,
    );
  }

  /// Triggers an immediate Emergency SOS safety event.
  /// 1. Snapshots current resilient position.
  /// 2. Persists to local storage FIRST.
  /// 3. Dispatches through the Communication Orchestrator.
  Future<SafetyEvent> createSos({Map<String, dynamic>? metadata}) async {
    return _createAndDispatchEvent(
      type: SafetyEventType.sos,
      metadata: metadata,
    );
  }

  /// Creates a manual safety check-in event.
  Future<SafetyEvent> createManualCheckIn({Map<String, dynamic>? metadata}) async {
    return _createAndDispatchEvent(
      type: SafetyEventType.manualCheckIn,
      metadata: metadata,
    );
  }

  /// Creates an arbitrary safety alert event.
  Future<SafetyEvent> createSafetyAlert({
    String? message,
    Map<String, dynamic>? metadata,
  }) async {
    final meta = Map<String, dynamic>.from(metadata ?? {});
    if (message != null) {
      meta['message'] = message;
    }
    return _createAndDispatchEvent(
      type: SafetyEventType.safetyAlert,
      metadata: meta,
    );
  }

  /// Core pipeline: Snapshot -> Persist Locally -> Deliver -> Emit Event.
  Future<SafetyEvent> _createAndDispatchEvent({
    required SafetyEventType type,
    Map<String, dynamic>? metadata,
  }) async {
    // 1. Snapshot position
    final event = _captureSnapshot(type: type, metadata: metadata);
    _log('[SAFETY] ${type.label} CREATED id=${event.eventId}');

    if (event.hasValidLocation) {
      _log('[SAFETY] POSITION source=${event.positionSource?.name ?? "UNKNOWN"} uncertainty=${event.uncertaintyMeters?.toStringAsFixed(1) ?? "N/A"}m');
    } else {
      _log('[SAFETY] POSITION UNAVAILABLE (No valid coordinates)');
    }

    // 2. CRITICAL: Local persistence happens BEFORE network delivery
    await store.saveEvent(event);

    // 3. Emit initial event to UI listeners
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }

    // 4. Attempt delivery via orchestrator
    final DeliveryResult deliveryResult = await orchestrator.deliver(event);

    // 5. Fetch updated state from store
    final updatedEvent = await store.getEventById(event.eventId) ??
        event.copyWith(
          eventStatus: deliveryResult.resultingStatus,
          deliveryChannel: deliveryResult.channelName,
        );

    // 6. Emit updated event
    if (!_eventController.isClosed) {
      _eventController.add(updatedEvent);
    }

    return updatedEvent;
  }

  /// Returns all currently queued / pending safety events waiting for network delivery.
  Future<List<SafetyEvent>> getPendingEvents() {
    return store.getPendingEvents();
  }

  /// Returns full history of recorded safety events.
  Future<List<SafetyEvent>> getAllEvents() {
    return store.getAllEvents();
  }

  /// Triggers immediate synchronization of all queued offline safety events.
  Future<SyncReport> syncNow() {
    return syncManager.syncNow();
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  void dispose() {
    syncManager.dispose();
    _eventController.close();
  }
}

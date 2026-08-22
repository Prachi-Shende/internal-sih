import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../resilience/sensors/connectivity_service.dart';
import '../storage/safety_event_store.dart';
import 'communication_orchestrator.dart';

/// Summary report of a synchronization batch.
class SyncReport {
  final int totalPending;
  final int successfullySent;
  final int failedCount;
  final DateTime timestamp;

  const SyncReport({
    required this.totalPending,
    required this.successfullySent,
    required this.failedCount,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'SyncReport(total=$totalPending, sent=$successfullySent, failed=$failedCount, at=$timestamp)';
  }
}

/// Watches connectivity transitions and automatically synchronizes queued offline safety events.
class SyncManager {
  final ConnectivityService connectivityService;
  final SafetyEventStore store;
  final CommunicationOrchestrator orchestrator;

  StreamSubscription<bool>? _connectivitySubscription;
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  DateTime? _lastSyncTimestamp;
  DateTime? get lastSyncTimestamp => _lastSyncTimestamp;

  final StreamController<SyncReport> _syncReportController =
      StreamController<SyncReport>.broadcast();
  Stream<SyncReport> get syncReportStream => _syncReportController.stream;

  SyncManager({
    required this.connectivityService,
    required this.store,
    required this.orchestrator,
  });

  /// Starts listening to connectivity status changes.
  void start() {
    _connectivitySubscription = connectivityService.statusStream.listen(_handleConnectivityChange);
    // If starting while already online, attempt initial sync
    if (connectivityService.isOnline) {
      syncNow();
    }
  }

  void _handleConnectivityChange(bool isOnline) {
    if (isOnline) {
      _log('[SAFETY] Internet restored (ONLINE). Triggering automatic queue synchronization.');
      syncNow();
    }
  }

  /// Manually or automatically flushes all pending and queued events to the server.
  Future<SyncReport> syncNow({int maxBatchSize = 50}) async {
    if (_isSyncing) {
      return SyncReport(
        totalPending: 0,
        successfullySent: 0,
        failedCount: 0,
        timestamp: DateTime.now(),
      );
    }

    if (!connectivityService.isOnline) {
      _log('[SAFETY] Sync skipped: Device is OFFLINE.');
      return SyncReport(
        totalPending: 0,
        successfullySent: 0,
        failedCount: 0,
        timestamp: DateTime.now(),
      );
    }

    _isSyncing = true;
    int sentCount = 0;
    int failedCount = 0;

    try {
      await store.init();
      final pendingEvents = await store.getPendingEvents();

      _log('[SAFETY] SYNC START queuedStoreCount=${pendingEvents.length}');

      if (pendingEvents.isEmpty) {
        _isSyncing = false;
        return SyncReport(
          totalPending: 0,
          successfullySent: 0,
          failedCount: 0,
          timestamp: DateTime.now(),
        );
      }

      // Process oldest events first (FIFO) up to maxBatchSize
      final batch = pendingEvents.take(maxBatchSize).toList();
      _log('[SAFETY] SYNC BATCH count=${batch.length}');

      for (final event in batch) {
        _log('[SAFETY] SYNC EVENT id=${event.eventId} status=${event.eventStatus.name}');

        // If connection dropped midway, abort remaining in batch
        if (!connectivityService.isOnline) {
          _log('[SAFETY] Sync interrupted: Connection lost during batch.');
          break;
        }

        final result = await orchestrator.deliver(event);
        if (result.success) {
          sentCount++;
        } else {
          failedCount++;
        }
      }

      final remaining = await store.getPendingEvents();
      _lastSyncTimestamp = DateTime.now();

      _log('[SAFETY] SYNC COMPLETE sent=$sentCount remaining=${remaining.length}');

      final report = SyncReport(
        totalPending: pendingEvents.length,
        successfullySent: sentCount,
        failedCount: failedCount,
        timestamp: _lastSyncTimestamp!,
      );

      if (!_syncReportController.isClosed) {
        _syncReportController.add(report);
      }

      return report;
    } finally {
      _isSyncing = false;
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _syncReportController.close();
  }
}

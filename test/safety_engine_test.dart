import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sih/resilience/core/resilience_engine.dart';
import 'package:sih/resilience/models/position_estimate.dart';
import 'package:sih/resilience/models/position_source.dart';
import 'package:sih/resilience/providers/gps_positioning_provider.dart';
import 'package:sih/resilience/providers/pdr_positioning_provider.dart';
import 'package:sih/resilience/sensors/connectivity_service.dart';
import 'package:sih/safety/core/communication_orchestrator.dart';
import 'package:sih/safety/core/safety_engine.dart';
import 'package:sih/safety/core/sync_manager.dart';
import 'package:sih/safety/models/safety_event.dart';
import 'package:sih/safety/storage/file_safety_event_store.dart';
import 'package:sih/safety/storage/safety_event_store.dart';
import 'package:sih/safety/transport/dev_mock_safety_event_transport.dart';
import 'package:sih/screens/resilience_dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GpsPositioningProvider gpsProvider;
  late PdrPositioningProvider pdrProvider;
  late ConnectivityService connectivityService;
  late ResilienceEngine resilienceEngine;
  late DevMockSafetyEventTransport mockTransport;
  late InMemorySafetyEventStore memoryStore;
  late CommunicationOrchestrator orchestrator;
  late SyncManager syncManager;
  late SafetyEngine safetyEngine;

  setUp(() async {
    gpsProvider = GpsPositioningProvider();
    pdrProvider = PdrPositioningProvider();
    connectivityService = ConnectivityService();
    resilienceEngine = ResilienceEngine(
      gpsProvider: gpsProvider,
      pdrProvider: pdrProvider,
      connectivityService: connectivityService,
    );

    mockTransport = DevMockSafetyEventTransport();
    memoryStore = InMemorySafetyEventStore();
    await memoryStore.init();

    orchestrator = CommunicationOrchestrator(
      connectivityService: connectivityService,
      store: memoryStore,
      transport: mockTransport,
    );

    syncManager = SyncManager(
      connectivityService: connectivityService,
      store: memoryStore,
      orchestrator: orchestrator,
    );

    safetyEngine = SafetyEngine(
      resilienceEngine: resilienceEngine,
      store: memoryStore,
      orchestrator: orchestrator,
      syncManager: syncManager,
    );

    await resilienceEngine.start();
    await safetyEngine.start();
  });

  tearDown(() async {
    safetyEngine.syncManager.dispose();
    safetyEngine.dispose();
    await resilienceEngine.stop();
    gpsProvider.dispose();
    pdrProvider.dispose();
    connectivityService.dispose();
    resilienceEngine.dispose();
  });

  group('Step 5: Offline Safety Engine, Local Event Queue & Communication Orchestrator', () {
    // ============================================================
    // TEST 1: SOS with GPS + Internet ON (Case 1)
    // ============================================================
    test('TEST 1 — Create SOS with GPS + Internet: Event persisted, source GPS, delivered successfully', () async {
      connectivityService.setSimulatedStatus(true);
      final gpsPos = PositionEstimate(
        latitude: 19.076090,
        longitude: 72.877710,
        source: PositionSource.gps,
        confidence: 0.95,
        uncertaintyMeters: 3.5,
        timestamp: DateTime.now(),
        isAbsolute: true,
        isDegraded: false,
      );
      gpsProvider.injectSimulatedPosition(gpsPos);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final sos = await safetyEngine.createSos(metadata: {'trigger': 'user_panic'});

      expect(sos.eventType, SafetyEventType.sos);
      expect(sos.positionSource, PositionSource.gps);
      expect(sos.latitude, 19.076090);
      expect(sos.longitude, 72.877710);
      expect(sos.internetAvailable, isTrue);
      expect(sos.eventStatus, EventDeliveryStatus.sent);
      expect(sos.deliveryChannel, contains('INTERNET'));
      expect(mockTransport.transmittedEvents.length, 1);

      // Verify persisted in store
      final inStore = await memoryStore.getEventById(sos.eventId);
      expect(inStore, isNotNull);
      expect(inStore!.eventStatus, EventDeliveryStatus.sent);
    });

    // ============================================================
    // TEST 2: SOS with GPS OFF + PDR ON + Internet ON (Case 2)
    // ============================================================
    test('TEST 2 — Create SOS with GPS unavailable + PDR available + Internet ON: Captures PDR pos, delivered via Internet', () async {
      connectivityService.setSimulatedStatus(true);
      // Anchor PDR first
      pdrProvider.setAnchor(PositionEstimate(
        latitude: 19.076000,
        longitude: 72.877700,
        source: PositionSource.pdr,
        confidence: 0.85,
        uncertaintyMeters: 6.0,
        timestamp: DateTime.now(),
        isAbsolute: false,
        isDegraded: true,
      ));
      gpsProvider.simulateGpsLoss();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final sos = await safetyEngine.createSos();

      expect(sos.eventType, SafetyEventType.sos);
      expect(sos.positionSource, PositionSource.pdr);
      expect(sos.latitude, 19.076000);
      expect(sos.longitude, 72.877700);
      expect(sos.eventStatus, EventDeliveryStatus.sent);
      expect(sos.deliveryChannel, contains('INTERNET'));
    });

    // ============================================================
    // TEST 3: SOS with GPS ON + Internet OFF (Case 3)
    // ============================================================
    test('TEST 3 — Create SOS with GPS ON + Internet OFF: Event persisted, status QUEUED, no crash', () async {
      connectivityService.setSimulatedStatus(false); // OFFLINE
      gpsProvider.injectSimulatedPosition(PositionEstimate(
        latitude: 19.076050,
        longitude: 72.877720,
        source: PositionSource.gps,
        confidence: 0.95,
        uncertaintyMeters: 4.0,
        timestamp: DateTime.now(),
        isAbsolute: true,
        isDegraded: false,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final sos = await safetyEngine.createSos();

      expect(sos.eventType, SafetyEventType.sos);
      expect(sos.positionSource, PositionSource.gps);
      expect(sos.internetAvailable, isFalse);
      expect(sos.eventStatus, EventDeliveryStatus.queued);
      expect(sos.deliveryChannel, 'OFFLINE_QUEUE');
      expect(mockTransport.transmittedEvents.isEmpty, isTrue);

      final pending = await safetyEngine.getPendingEvents();
      expect(pending.length, 1);
      expect(pending.first.eventId, sos.eventId);
    });

    // ============================================================
    // TEST 4: SOS with GPS OFF + Internet OFF (Case 4 - Total Blackout)
    // ============================================================
    test('TEST 4 — Create SOS with GPS OFF + Internet OFF: Persisted locally, valid non-GPS source, no 0,0 coords', () async {
      connectivityService.setSimulatedStatus(false);
      pdrProvider.setAnchor(PositionEstimate(
        latitude: 19.076120,
        longitude: 72.877800,
        source: PositionSource.pdr,
        confidence: 0.70,
        uncertaintyMeters: 14.0,
        timestamp: DateTime.now(),
        isAbsolute: false,
        isDegraded: true,
      ));
      gpsProvider.simulateGpsLoss();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final sos = await safetyEngine.createSos();

      expect(sos.eventType, SafetyEventType.sos);
      expect(sos.positionSource, PositionSource.pdr);
      expect(sos.hasValidLocation, isTrue);
      expect(sos.latitude, 19.076120);
      expect(sos.longitude, 72.877800);
      expect(sos.latitude != 0.0, isTrue);
      expect(sos.longitude != 0.0, isTrue);
      expect(sos.eventStatus, EventDeliveryStatus.queued);
    });

    // ============================================================
    // TEST 5: Multiple Offline Events Queued
    // ============================================================
    test('TEST 5 — Multiple offline events created: All remain in persistent local queue', () async {
      connectivityService.setSimulatedStatus(false);

      final e1 = await safetyEngine.createSos(metadata: {'step': 1});
      final e2 = await safetyEngine.createManualCheckIn(metadata: {'step': 2});
      final e3 = await safetyEngine.createSafetyAlert(message: 'Low battery warning');

      final pending = await safetyEngine.getPendingEvents();
      expect(pending.length, 3);
      expect(pending.map((e) => e.eventId).toList(), [e1.eventId, e2.eventId, e3.eventId]);
    });

    // ============================================================
    // TEST 6: Internet Restoration & FIFO Sync
    // ============================================================
    test('TEST 6 — Restore Internet: SyncManager processes pending events in FIFO order', () async {
      connectivityService.setSimulatedStatus(false);

      final e1 = await safetyEngine.createSos();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final e2 = await safetyEngine.createManualCheckIn();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final e3 = await safetyEngine.createSafetyAlert();

      expect((await safetyEngine.getPendingEvents()).length, 3);

      // Restore Internet
      connectivityService.setSimulatedStatus(true);
      final report = await safetyEngine.syncNow();

      expect(report.totalPending, 3);
      expect(report.successfullySent, 3);
      expect(report.failedCount, 0);

      // Verify FIFO transmission order
      expect(mockTransport.transmittedEvents.length, 3);
      expect(mockTransport.transmittedEvents[0].eventId, e1.eventId);
      expect(mockTransport.transmittedEvents[1].eventId, e2.eventId);
      expect(mockTransport.transmittedEvents[2].eventId, e3.eventId);

      // Queue is now empty
      final remaining = await safetyEngine.getPendingEvents();
      expect(remaining.isEmpty, isTrue);
    });

    // ============================================================
    // TEST 7: Single Transmission Failure Handling
    // ============================================================
    test('TEST 7 — One event transmission fails: Failed event remains queued without losing other events', () async {
      connectivityService.setSimulatedStatus(false);

      await safetyEngine.createSos();
      final e2 = await safetyEngine.createManualCheckIn();
      await safetyEngine.createSafetyAlert();

      // Configure transport to reject only e2
      mockTransport.failedEventIds.add(e2.eventId);

      // Bring online and sync
      connectivityService.setSimulatedStatus(true);
      final report = await safetyEngine.syncNow();

      expect(report.successfullySent, 2);
      expect(report.failedCount, 1);

      final remaining = await safetyEngine.getPendingEvents();
      expect(remaining.length, 1);
      expect(remaining.first.eventId, e2.eventId);
      expect(remaining.first.retryCount, greaterThanOrEqualTo(1));
    });

    // ============================================================
    // TEST 8: File-Based Event Store Persistence Across Restarts
    // ============================================================
    test('TEST 8 — Restart/reinitialize FileSafetyEventStore: Previous pending events remain available', () async {
      final tempDir = Directory.systemTemp.createTempSync('sih_test_store_');
      final filePath = '${tempDir.path}${Platform.pathSeparator}test_events.json';

      final fileStore1 = FileSafetyEventStore(customFilePath: filePath);
      await fileStore1.init();

      final testEvent = SafetyEvent(
        eventId: 'SOS-TEST-8888',
        eventType: SafetyEventType.sos,
        timestamp: DateTime.now(),
        latitude: 19.076000,
        longitude: 72.877700,
        positionSource: PositionSource.gps,
        internetAvailable: false,
        eventStatus: EventDeliveryStatus.queued,
        createdAt: DateTime.now(),
      );

      await fileStore1.saveEvent(testEvent);
      expect((await fileStore1.getPendingEvents()).length, 1);

      // Simulate App Restart with a fresh Store instance pointing to same file
      final fileStore2 = FileSafetyEventStore(customFilePath: filePath);
      await fileStore2.init();

      final pendingAfterRestart = await fileStore2.getPendingEvents();
      expect(pendingAfterRestart.length, 1);
      expect(pendingAfterRestart.first.eventId, 'SOS-TEST-8888');
      expect(pendingAfterRestart.first.latitude, 19.076000);

      // Cleanup
      tempDir.deleteSync(recursive: true);
    });

    // ============================================================
    // TEST 9: Missing / Invalid Position Handled Gracefully
    // ============================================================
    test('TEST 9 — No position estimate available: Event safely created with null coordinates (no 0,0)', () async {
      connectivityService.setSimulatedStatus(false);
      // ResilienceEngine has null position initially

      final event = await safetyEngine.createSos();

      expect(event.latitude, isNull);
      expect(event.longitude, isNull);
      expect(event.hasValidLocation, isFalse);
      expect(event.eventStatus, EventDeliveryStatus.queued);

      // Json serialization preserves nulls cleanly
      final json = event.toJson();
      final reconstructed = SafetyEvent.fromJson(json);
      expect(reconstructed.latitude, isNull);
      expect(reconstructed.longitude, isNull);
    });

    // ============================================================
    // TEST 10: Automatic Sync on OFFLINE -> ONLINE Transition
    // ============================================================
    test('TEST 10 — Automatic sync triggers when connectivity status stream emits ONLINE', () async {
      connectivityService.setSimulatedStatus(false);

      await safetyEngine.createSos();
      expect((await safetyEngine.getPendingEvents()).length, 1);

      // Transition to online
      connectivityService.setSimulatedStatus(true);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect((await safetyEngine.getPendingEvents()).isEmpty, isTrue);
      expect(mockTransport.transmittedEvents.length, 1);
    });

    // ============================================================
    // TEST 11: Unique Event IDs
    // ============================================================
    test('TEST 11 — No duplicate event IDs generated across rapid successive calls', () async {
      connectivityService.setSimulatedStatus(false);

      final ids = <String>{};
      for (int i = 0; i < 20; i++) {
        final event = await safetyEngine.createSos();
        expect(ids.contains(event.eventId), isFalse);
        ids.add(event.eventId);
      }

      expect(ids.length, 20);
    });

    // ============================================================
    // TEST 12: Retry Count Increments on Failed Transmissions
    // ============================================================
    test('TEST 12 — Retry count increments correctly on each failed delivery attempt', () async {
      connectivityService.setSimulatedStatus(false);
      mockTransport.shouldSucceed = false; // Force network failure

      final event = await safetyEngine.createSos();
      expect(event.eventStatus, EventDeliveryStatus.queued);
      expect(event.retryCount, 0);

      // Bring online with failing transport and sync
      connectivityService.setSimulatedStatus(true);
      final report1 = await safetyEngine.syncNow();
      expect(report1.failedCount, 1);

      final updated1 = await memoryStore.getEventById(event.eventId);
      expect(updated1?.retryCount, 1);

      // Trigger another manual sync
      final report2 = await safetyEngine.syncNow();
      expect(report2.failedCount, 1);

      final updated2 = await memoryStore.getEventById(event.eventId);
      expect(updated2?.retryCount, 2);
    });

    // ============================================================
    // TEST 13: Dashboard Widget Test with Safety Card
    // ============================================================
    testWidgets('TEST 13 — Dashboard renders Safety Card without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final gps = GpsPositioningProvider();
      final conn = ConnectivityService();
      final pdr = PdrPositioningProvider();
      final engine = ResilienceEngine(
        gpsProvider: gps,
        connectivityService: conn,
        pdrProvider: pdr,
      );
      final safety = SafetyEngine(
        resilienceEngine: engine,
        store: InMemorySafetyEventStore(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ResilienceDashboardScreen(
            resilienceEngine: engine,
            safetyEngine: safety,
            autoStart: false,
          ),
        ),
      );

      await tester.pump();
      expect(find.text('SAFETY & EMERGENCY ENGINE'), findsOneWidget);
      expect(find.text('TEST SOS'), findsOneWidget);
      expect(tester.takeException(), isNull);

      gps.dispose();
      conn.dispose();
      pdr.dispose();
      engine.dispose();
      safety.dispose();
    });

    // ============================================================
    // TEST 14: Regression Test — Default SafetyEngine Store Sharing & Sync Cycle
    // ============================================================
    test('TEST 14 (Regression) — Offline event in default SafetyEngine is queued, re-read, synced, becomes SENT, and queue drops to 0', () async {
      final tempDir = Directory.systemTemp.createTempSync('sih_regression_test_');
      final filePath = '${tempDir.path}${Platform.pathSeparator}reg_events.json';

      final testTransport = DevMockSafetyEventTransport();
      final testConn = ConnectivityService();
      testConn.setSimulatedStatus(false); // Start OFFLINE

      final testGps = GpsPositioningProvider();
      final testPdr = PdrPositioningProvider();
      final testResilience = ResilienceEngine(
        gpsProvider: testGps,
        pdrProvider: testPdr,
        connectivityService: testConn,
      );

      final fileStore = FileSafetyEventStore(customFilePath: filePath);

      // Create SafetyEngine with custom file store
      final engineUnderTest = SafetyEngine(
        resilienceEngine: testResilience,
        store: fileStore,
        transport: testTransport,
      );
      await testResilience.start();
      await engineUnderTest.start();

      // Verify SafetyEngine, Orchestrator, and SyncManager all share the SAME store instance
      expect(identical(engineUnderTest.store, engineUnderTest.orchestrator.store), isTrue);
      expect(identical(engineUnderTest.store, engineUnderTest.syncManager.store), isTrue);

      // 1. Create offline SOS
      final offlineSos = await engineUnderTest.createSos(metadata: {'case': 'regression_offline'});
      expect(offlineSos.eventStatus, EventDeliveryStatus.queued);

      // Verify queued in store
      final pendingBefore = await engineUnderTest.getPendingEvents();
      expect(pendingBefore.length, 1);
      expect(pendingBefore.first.eventId, offlineSos.eventId);

      // 2. Re-read / reinitialize store from disk to ensure persistence integrity
      await fileStore.reload();
      final pendingAfterReload = await engineUnderTest.getPendingEvents();
      expect(pendingAfterReload.length, 1);
      expect(pendingAfterReload.first.eventId, offlineSos.eventId);

      // 3. Bring device ONLINE
      testConn.setSimulatedStatus(true);

      // 4. Run syncNow()
      final syncReport = await engineUnderTest.syncNow();

      // 5. Verify batch processing & delivery
      expect(syncReport.totalPending, 1);
      expect(syncReport.successfullySent, 1);
      expect(syncReport.failedCount, 0);

      // 6. Verify event becomes SENT and queue becomes 0
      final storedEvent = await engineUnderTest.store.getEventById(offlineSos.eventId);
      expect(storedEvent, isNotNull);
      expect(storedEvent!.eventStatus, EventDeliveryStatus.sent);

      final pendingAfterSync = await engineUnderTest.getPendingEvents();
      expect(pendingAfterSync.isEmpty, isTrue);

      // Cleanup
      engineUnderTest.syncManager.dispose();
      engineUnderTest.dispose();
      await testResilience.stop();
      testGps.dispose();
      testPdr.dispose();
      testConn.dispose();
      testResilience.dispose();
      tempDir.deleteSync(recursive: true);
    });

    // ============================================================
    // TEST 15: UI Flow — Offline Queue (3) -> Network Restored -> Auto-Sync -> UI becomes QUEUE (0)
    // ============================================================
    testWidgets('TEST 15 — UI displays QUEUE (3) when offline, then automatically updates to QUEUE EMPTY / QUEUE (0) on network restore', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final gps = GpsPositioningProvider();
      final conn = ConnectivityService();
      conn.setSimulatedStatus(false); // Start OFFLINE
      final pdr = PdrPositioningProvider();
      final engine = ResilienceEngine(
        gpsProvider: gps,
        connectivityService: conn,
        pdrProvider: pdr,
      );

      final mockTransport = DevMockSafetyEventTransport();
      final memoryStore = InMemorySafetyEventStore();
      final safety = SafetyEngine(
        resilienceEngine: engine,
        store: memoryStore,
        transport: mockTransport,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ResilienceDashboardScreen(
            resilienceEngine: engine,
            safetyEngine: safety,
            autoStart: false,
          ),
        ),
      );

      await safety.start();
      await tester.pump();
      expect(find.text('QUEUE EMPTY'), findsOneWidget);

      // Create 3 offline events
      await safety.createSos();
      await safety.createManualCheckIn();
      await safety.createSafetyAlert();

      await tester.pump();
      // Verify UI shows 3 queued
      expect(find.text('3 QUEUED'), findsOneWidget);
      expect(find.text('QUEUE (3)'), findsOneWidget);
      expect(find.text('3 PENDING'), findsOneWidget);

      // Restore Internet
      conn.setSimulatedStatus(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify UI automatically updated without user interaction
      expect(find.text('QUEUE EMPTY'), findsOneWidget);
      expect(find.text('QUEUE (0)'), findsOneWidget);
      expect(find.text('0 PENDING'), findsOneWidget);

      safety.syncManager.dispose();
      safety.dispose();
      await engine.stop();
      gps.dispose();
      conn.dispose();
      pdr.dispose();
      engine.dispose();
    });

    // ============================================================
    // TEST 16: App Process Restart Flow — Durable Persistence & Launch-time Auto-Sync
    // ============================================================
    test('TEST 16 — App termination with 3 queued events, then fresh launch with Internet ON loads and syncs all 3 events to SENT', () async {
      final tempDir = Directory.systemTemp.createTempSync('sih_app_restart_test_');
      final durableFilePath = '${tempDir.path}${Platform.pathSeparator}sih_safety_events.json';

      // ─── SESSION 1 (OFFLINE) ───────────────────────────
      final conn1 = ConnectivityService();
      conn1.setSimulatedStatus(false); // Offline
      final gps1 = GpsPositioningProvider();
      final pdr1 = PdrPositioningProvider();
      final resilience1 = ResilienceEngine(
        gpsProvider: gps1,
        pdrProvider: pdr1,
        connectivityService: conn1,
      );

      final store1 = FileSafetyEventStore(customFilePath: durableFilePath);
      final transport1 = DevMockSafetyEventTransport();
      final safety1 = SafetyEngine(
        resilienceEngine: resilience1,
        store: store1,
        transport: transport1,
      );

      await resilience1.start();
      await safety1.start();

      // Create 3 offline events
      final e1 = await safety1.createSos(metadata: {'session': 1});
      final e2 = await safety1.createManualCheckIn(metadata: {'session': 1});
      final e3 = await safety1.createSafetyAlert(message: 'Offline alert');

      expect((await safety1.getPendingEvents()).length, 3);

      // Simulate App Process Kill / Termination
      safety1.syncManager.dispose();
      safety1.dispose();
      await resilience1.stop();
      gps1.dispose();
      pdr1.dispose();
      conn1.dispose();
      resilience1.dispose();

      // ─── SESSION 2 (FRESH LAUNCH WITH INTERNET ON) ─────
      final conn2 = ConnectivityService();
      conn2.setSimulatedStatus(true); // Online at boot
      final gps2 = GpsPositioningProvider();
      final pdr2 = PdrPositioningProvider();
      final resilience2 = ResilienceEngine(
        gpsProvider: gps2,
        pdrProvider: pdr2,
        connectivityService: conn2,
      );

      final store2 = FileSafetyEventStore(customFilePath: durableFilePath);
      final transport2 = DevMockSafetyEventTransport();
      final safety2 = SafetyEngine(
        resilienceEngine: resilience2,
        store: store2,
        transport: transport2,
      );

      // Verify before start: store contains the 3 persisted events from Session 1
      final pendingBeforeStart = await store2.getPendingEvents();
      expect(pendingBeforeStart.length, 3);
      expect(pendingBeforeStart.map((e) => e.eventId).toList(), [e1.eventId, e2.eventId, e3.eventId]);

      // Start engine (triggers launch-time sync in SyncManager because internet is online)
      await resilience2.start();
      await safety2.start();

      // Allow sync batch to complete
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Verify all 3 events were transmitted and marked SENT in the durable store
      expect(transport2.transmittedEvents.length, 3);
      expect((await safety2.getPendingEvents()).isEmpty, isTrue);

      final stored1 = await store2.getEventById(e1.eventId);
      final stored2 = await store2.getEventById(e2.eventId);
      final stored3 = await store2.getEventById(e3.eventId);

      expect(stored1?.eventStatus, EventDeliveryStatus.sent);
      expect(stored2?.eventStatus, EventDeliveryStatus.sent);
      expect(stored3?.eventStatus, EventDeliveryStatus.sent);

      // Cleanup
      safety2.syncManager.dispose();
      safety2.dispose();
      await resilience2.stop();
      gps2.dispose();
      pdr2.dispose();
      conn2.dispose();
      resilience2.dispose();
      tempDir.deleteSync(recursive: true);
    });
  });
}

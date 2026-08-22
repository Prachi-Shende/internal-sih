import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sih/resilience/core/resilience_engine.dart';
import 'package:sih/resilience/models/gps_health.dart';
import 'package:sih/resilience/models/position_estimate.dart';
import 'package:sih/resilience/models/position_source.dart';
import 'package:sih/resilience/models/positioning_mode.dart';
import 'package:sih/resilience/providers/gps_positioning_provider.dart';
import 'package:sih/resilience/providers/pdr_positioning_provider.dart';
import 'package:sih/resilience/sensors/connectivity_service.dart';
import 'package:sih/safety/core/communication_orchestrator.dart';
import 'package:sih/safety/core/safety_engine.dart';
import 'package:sih/safety/models/safety_event.dart';
import 'package:sih/safety/storage/safety_event_store.dart';
import 'package:sih/safety/transport/dev_mock_safety_event_transport.dart';
import 'package:sih/safety/transport/real_http_safety_event_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Real HTTP Communication & Safety Transport Tests', () {
    late SafetyEvent sampleEvent;

    setUp(() {
      sampleEvent = SafetyEvent(
        eventId: 'SOS-1724350000000-1001',
        eventType: SafetyEventType.sos,
        timestamp: DateTime(2026, 8, 23, 12, 0, 0),
        latitude: 19.07600,
        longitude: 72.87770,
        positionSource: PositionSource.gps,
        confidence: 0.95,
        uncertaintyMeters: 4.2,
        positioningMode: PositioningMode.gps,
        gpsHealth: GpsHealth.active,
        internetAvailable: true,
        eventStatus: EventDeliveryStatus.pending,
        createdAt: DateTime(2026, 8, 23, 12, 0, 0),
        metadata: {'battery': 85, 'notes': 'Test SOS payload'},
      );
    });

    // ============================================================
    // TEST 1: Successful HTTP Delivery (200 / 201)
    // ============================================================
    test('TEST 1 — Successful HTTP delivery transmits JSON payload to /api/safety-events', () async {
      http.Request? capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'eventId': 'SOS-1724350000000-1001',
            'message': 'Safety event received and acknowledged',
          }),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final transport = RealHttpSafetyEventTransport(
        baseUrl: 'http://192.168.1.50:8080',
        client: mockClient,
      );

      final result = await transport.transmit(sampleEvent);

      expect(result.success, isTrue);
      expect(result.resultingStatus, EventDeliveryStatus.sent);
      expect(result.channelName, 'HTTP');

      // Verify captured request
      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'POST');
      expect(capturedRequest!.url.toString(), 'http://192.168.1.50:8080/api/safety-events');
      expect(capturedRequest!.headers['content-type'], contains('application/json'));

      final decoded = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(decoded['eventId'], 'SOS-1724350000000-1001');
      expect(decoded['eventType'], 'sos');
      expect(decoded['latitude'], 19.07600);
      expect(decoded['longitude'], 72.87770);
      expect(decoded['positionSource'], 'gps');
      expect(decoded['confidence'], 0.95);
      expect(decoded['uncertaintyMeters'], 4.2);
    });

    // ============================================================
    // TEST 2: HTTP 201 Created Response
    // ============================================================
    test('TEST 2 — HTTP 201 response returns success with server acknowledgement', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'eventId': sampleEvent.eventId,
            'message': 'Created in emergency queue',
          }),
          201,
        );
      });

      final transport = RealHttpSafetyEventTransport(
        baseUrl: 'http://10.0.2.2:8080',
        client: mockClient,
      );

      final result = await transport.transmit(sampleEvent);
      expect(result.success, isTrue);
      expect(result.resultingStatus, EventDeliveryStatus.sent);
      expect(result.reason, 'Created in emergency queue');
    });

    // ============================================================
    // TEST 3: HTTP 200 OK Response
    // ============================================================
    test('TEST 3 — HTTP 200 response returns success with delivery status sent', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'eventId': sampleEvent.eventId,
            'message': 'Processed successfully',
          }),
          200,
        );
      });

      final transport = RealHttpSafetyEventTransport(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
      );

      final result = await transport.transmit(sampleEvent);
      expect(result.success, isTrue);
      expect(result.resultingStatus, EventDeliveryStatus.sent);
    });

    // ============================================================
    // TEST 4: HTTP 400 Bad Request Failure
    // ============================================================
    test('TEST 4 — HTTP 400 failure returns failed DeliveryResult without crashing', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'success': false, 'error': 'Missing required fields'}),
          400,
        );
      });

      final transport = RealHttpSafetyEventTransport(client: mockClient);
      final result = await transport.transmit(sampleEvent);

      expect(result.success, isFalse);
      expect(result.reason, contains('HTTP 400'));
    });

    // ============================================================
    // TEST 5: HTTP 500 Internal Server Error Failure
    // ============================================================
    test('TEST 5 — HTTP 500 failure returns failed DeliveryResult and retains event for retry', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'success': false, 'error': 'Database unavailable'}),
          500,
        );
      });

      final transport = RealHttpSafetyEventTransport(client: mockClient);
      final result = await transport.transmit(sampleEvent);

      expect(result.success, isFalse);
      expect(result.reason, contains('HTTP 500'));
    });

    // ============================================================
    // TEST 6: Network Timeout Handling
    // ============================================================
    test('TEST 6 — Request timeout produces failure result and does not hang indefinitely', () async {
      final mockClient = MockClient((request) async {
        // Delay exceeds configured transport timeout
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return http.Response('{"success": true}', 200);
      });

      final transport = RealHttpSafetyEventTransport(
        client: mockClient,
        timeout: const Duration(milliseconds: 20),
      );

      final result = await transport.transmit(sampleEvent);

      expect(result.success, isFalse);
      expect(result.reason?.toLowerCase(), contains('timeout'));
    });

    // ============================================================
    // TEST 7: Connection Failure / Socket Exception
    // ============================================================
    test('TEST 7 — Connection failure returns failure DeliveryResult cleanly', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Connection refused');
      });

      final transport = RealHttpSafetyEventTransport(client: mockClient);
      final result = await transport.transmit(sampleEvent);

      expect(result.success, isFalse);
      expect(result.reason?.toLowerCase(), contains('network connection failed'));
    });

    // ============================================================
    // TEST 8: Duplicate eventId / Idempotency
    // ============================================================
    test('TEST 8 — Duplicate eventId submission receives idempotent ack and succeeds', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          return http.Response(
            jsonEncode({'success': true, 'eventId': sampleEvent.eventId, 'message': 'Safety event received'}),
            201,
          );
        } else {
          return http.Response(
            jsonEncode({'success': true, 'eventId': sampleEvent.eventId, 'message': 'Safety event already received (idempotent ack)', 'duplicate': true}),
            200,
          );
        }
      });

      final transport = RealHttpSafetyEventTransport(client: mockClient);

      final firstResult = await transport.transmit(sampleEvent);
      expect(firstResult.success, isTrue);

      final secondResult = await transport.transmit(sampleEvent);
      expect(secondResult.success, isTrue);
      expect(requestCount, 2);
    });

    // ============================================================
    // TEST 9: Offline Event Remains Queued (No HTTP Attempt)
    // ============================================================
    test('TEST 9 — When offline, event is stored in OFFLINE_QUEUE without HTTP transmission', () async {
      int httpCalls = 0;
      final mockClient = MockClient((request) async {
        httpCalls++;
        return http.Response('{"success": true}', 200);
      });

      final transport = RealHttpSafetyEventTransport(client: mockClient);
      final connService = ConnectivityService();
      connService.setSimulatedStatus(false); // Offline

      final store = InMemorySafetyEventStore();
      final orchestrator = CommunicationOrchestrator(
        connectivityService: connService,
        store: store,
        transport: transport,
      );

      final gps = GpsPositioningProvider();
      final pdr = PdrPositioningProvider();
      final resilience = ResilienceEngine(
        gpsProvider: gps,
        pdrProvider: pdr,
        connectivityService: connService,
      );

      final safetyEngine = SafetyEngine(
        resilienceEngine: resilience,
        store: store,
        transport: transport,
        orchestrator: orchestrator,
      );

      await resilience.start();
      await safetyEngine.start();

      final offlineEvent = await safetyEngine.createSos();

      expect(offlineEvent.eventStatus, EventDeliveryStatus.queued);
      expect(offlineEvent.deliveryChannel, 'OFFLINE_QUEUE');
      expect(httpCalls, 0); // No HTTP requests made while offline

      safetyEngine.syncManager.dispose();
      safetyEngine.dispose();
      await resilience.stop();
      gps.dispose();
      pdr.dispose();
      connService.dispose();
      resilience.dispose();
    });

    // ============================================================
    // TEST 10: Queued Event Syncs via Real HTTP When Connectivity Returns
    // ============================================================
    test('TEST 10 — Queued offline event automatically synchronizes via HTTP when connectivity returns', () async {
      final transmittedEvents = <String>[];
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        transmittedEvents.add(body['eventId'] as String);
        return http.Response(
          jsonEncode({'success': true, 'eventId': body['eventId'], 'message': 'Acknowledged'}),
          201,
        );
      });

      final transport = RealHttpSafetyEventTransport(client: mockClient);
      final connService = ConnectivityService();
      connService.setSimulatedStatus(false); // Start Offline

      final store = InMemorySafetyEventStore();
      final orchestrator = CommunicationOrchestrator(
        connectivityService: connService,
        store: store,
        transport: transport,
      );

      final gps = GpsPositioningProvider();
      final pdr = PdrPositioningProvider();
      final resilience = ResilienceEngine(
        gpsProvider: gps,
        pdrProvider: pdr,
        connectivityService: connService,
      );

      final safetyEngine = SafetyEngine(
        resilienceEngine: resilience,
        store: store,
        transport: transport,
        orchestrator: orchestrator,
      );

      await resilience.start();
      await safetyEngine.start();

      // Create 2 offline events
      final e1 = await safetyEngine.createSos();
      final e2 = await safetyEngine.createManualCheckIn();

      expect((await safetyEngine.getPendingEvents()).length, 2);
      expect(transmittedEvents.isEmpty, isTrue);

      // Restore Internet connectivity
      connService.setSimulatedStatus(true);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify sync occurred via HTTP
      expect(transmittedEvents.length, 2);
      expect(transmittedEvents, contains(e1.eventId));
      expect(transmittedEvents, contains(e2.eventId));

      final pendingAfter = await safetyEngine.getPendingEvents();
      expect(pendingAfter.isEmpty, isTrue);

      final storedE1 = await store.getEventById(e1.eventId);
      expect(storedE1?.eventStatus, EventDeliveryStatus.sent);
      expect(storedE1?.deliveryChannel, 'HTTP');

      safetyEngine.syncManager.dispose();
      safetyEngine.dispose();
      await resilience.stop();
      gps.dispose();
      pdr.dispose();
      connService.dispose();
      resilience.dispose();
    });

    // ============================================================
    // TEST 11: DevMockSafetyEventTransport Remains Fully Operational
    // ============================================================
    test('TEST 11 — DevMockSafetyEventTransport continues to function correctly for isolated tests', () async {
      final mockTransport = DevMockSafetyEventTransport(latency: Duration.zero);

      final result = await mockTransport.transmit(sampleEvent);
      expect(result.success, isTrue);
      expect(mockTransport.transmittedEvents.length, 1);
      expect(mockTransport.transmittedEvents.first.eventId, sampleEvent.eventId);

      mockTransport.shouldSucceed = false;
      final failResult = await mockTransport.transmit(sampleEvent);
      expect(failResult.success, isFalse);
    });

    // ============================================================
    // TEST 12: SafetyEngine End-to-End with Real HTTP Transport
    // ============================================================
    test('TEST 12 — SafetyEngine creates SOS with active fix and sends via RealHttpSafetyEventTransport', () async {
      Map<String, dynamic>? receivedPayload;

      final mockClient = MockClient((request) async {
        receivedPayload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'success': true,
            'eventId': receivedPayload!['eventId'],
            'message': 'SOS Received at Central Dispatch',
          }),
          201,
        );
      });

      final transport = RealHttpSafetyEventTransport(
        baseUrl: 'http://192.168.1.100:8080',
        client: mockClient,
      );

      final connService = ConnectivityService();
      connService.setSimulatedStatus(true); // Online

      final gps = GpsPositioningProvider();
      final pdr = PdrPositioningProvider();
      final resilience = ResilienceEngine(
        gpsProvider: gps,
        pdrProvider: pdr,
        connectivityService: connService,
      );

      final store = InMemorySafetyEventStore();
      final safetyEngine = SafetyEngine(
        resilienceEngine: resilience,
        store: store,
        transport: transport,
      );

      await resilience.start();
      await safetyEngine.start();

      // Inject GPS fix
      gps.injectSimulatedPosition(
        PositionEstimate(
          latitude: 19.07620,
          longitude: 72.87790,
          source: PositionSource.gps,
          confidence: 0.96,
          uncertaintyMeters: 3.8,
          timestamp: DateTime.now(),
          isAbsolute: true,
          isDegraded: false,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final event = await safetyEngine.createSos(metadata: {'tourist_id': 'T-9876'});

      expect(event.eventStatus, EventDeliveryStatus.sent);
      expect(receivedPayload, isNotNull);
      expect(receivedPayload!['eventId'], event.eventId);
      expect(receivedPayload!['latitude'], closeTo(19.07620, 0.00001));
      expect(receivedPayload!['longitude'], closeTo(72.87790, 0.00001));
      expect(receivedPayload!['positionSource'], 'gps');
      expect(receivedPayload!['metadata']['tourist_id'], 'T-9876');

      safetyEngine.syncManager.dispose();
      safetyEngine.dispose();
      await resilience.stop();
      gps.dispose();
      pdr.dispose();
      connService.dispose();
      resilience.dispose();
    });
  });
}

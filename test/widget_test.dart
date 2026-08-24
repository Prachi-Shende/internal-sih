// test/widget_test.dart
// Comprehensive Unit, Model, and P1 Integration Test Suite

import 'package:flutter_test/flutter_test.dart';
import 'package:travara/config.dart';
import 'package:travara/services/api_service.dart';
import 'package:travara/services/mock_data.dart';
import 'package:travara/services/models.dart';

import 'package:travara/p1/integration/p1_integration_facade.dart';
import 'package:travara/p1/pdr/core/pdr_engine.dart';
import 'package:travara/p1/resilience/core/resilience_engine.dart';
import 'package:travara/p1/resilience/models/position_estimate.dart';
import 'package:travara/p1/resilience/models/position_source.dart';
import 'package:travara/p1/resilience/providers/pdr_positioning_provider.dart';
import 'package:travara/p1/safety/core/safety_engine.dart';
import 'package:travara/p1/safety/models/safety_event.dart';
import 'package:travara/p1/safety/storage/safety_event_store.dart';
import 'package:travara/p1/safety/transport/dev_mock_safety_event_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SafeTravel Core Models & Config Verification', () {
    test('AppConfig resolves ADB reverse base URL correctly', () {
      expect(AppConfig.useAdbReverse, isTrue);
      expect(AppConfig.apiBaseUrl, 'http://127.0.0.1:8000');
    });

    test('ApiService correctly parses Confidence and Risk tiers', () {
      expect(ApiService.parseConfidence(0.95), LocationConfidence.high);
      expect(ApiService.parseConfidence(0.55), LocationConfidence.medium);
      expect(ApiService.parseConfidence(0.20), LocationConfidence.low);

      expect(ApiService.parseRiskLevel('LOW'), RiskLevel.low);
      expect(ApiService.parseRiskLevel('MEDIUM'), RiskLevel.medium);
      expect(ApiService.parseRiskLevel('HIGH'), RiskLevel.high);
      expect(ApiService.parseRiskLevel('CRITICAL'), RiskLevel.critical);

      expect(ApiService.riskLevelToString(RiskLevel.low), 'LOW');
      expect(ApiService.riskLevelToString(RiskLevel.critical), 'CRITICAL');
    });

    test('MockData contains valid initial positioning and safe havens', () {
      expect(MockData.initialLocation.lat, isNotNull);
      expect(MockData.initialLocation.lon, isNotNull);
      expect(MockData.initialLocation.source, 'GPS');
      expect(MockData.safeLocations.isNotEmpty, isTrue);
      expect(MockData.popularDestinations.isNotEmpty, isTrue);
    });

    test('PDF Report URL constructor formats correctly', () {
      ApiService.sessionId = 'test-session-123';
      final url = ApiService.getPdfReportUrl(
        userName: 'Test Explorer',
        userEmail: 'explorer@travara.app',
      );
      expect(url, contains('/report/pdf'));
      expect(url, contains('session_id=test-session-123'));
      expect(url, contains('user_name=Test%20Explorer'));
    });
  });

  group('P1 Resilient Engine & 4-Case State Machine Verification', () {
    late PdrEngine pdrEngine;
    late ResilienceEngine resilienceEngine;
    late SafetyEngine safetyEngine;
    late P1IntegrationFacade facade;
    late DevMockSafetyEventTransport mockTransport;

    setUp(() async {
      pdrEngine = PdrEngine();
      final pdrProvider = PdrPositioningProvider(engine: pdrEngine);
      resilienceEngine = ResilienceEngine(pdrProvider: pdrProvider);
      mockTransport = DevMockSafetyEventTransport();
      safetyEngine = SafetyEngine(
        resilienceEngine: resilienceEngine,
        store: InMemorySafetyEventStore(),
        transport: mockTransport,
      );
      facade = P1IntegrationFacade(
        resilienceEngine: resilienceEngine,
        pdrEngine: pdrEngine,
        safetyEngine: safetyEngine,
      );
      await resilienceEngine.start();
      await safetyEngine.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    tearDown(() {
      facade.dispose();
      resilienceEngine.dispose();
      pdrEngine.dispose();
      safetyEngine.dispose();
    });

    test('CASE 1: GPS Active + Internet Online outputs GPS fix with High Confidence', () async {
      resilienceEngine.connectivityService.setSimulatedStatus(true);
      resilienceEngine.setOverrideMode(ResilienceOverrideMode.forceGps);
      resilienceEngine.gpsProvider.injectSimulatedPosition(
        PositionEstimate(
          latitude: 19.0760,
          longitude: 72.8777,
          source: PositionSource.gps,
          confidence: 0.95,
          uncertaintyMeters: 3.5,
          timestamp: DateTime.now(),
          isAbsolute: true,
          isDegraded: false,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final snapshot = facade.getCurrentSnapshot();
      expect(snapshot.connectivity.isOnline, isTrue);
      expect(snapshot.resilience.mode, 'gps');
      expect(snapshot.position.source, 'gps');
      expect(snapshot.position.latitude, 19.0760);
      expect(snapshot.position.longitude, 72.8777);
      expect(snapshot.resilience.infrastructureCase, 'case1');
    });

    test('CASE 2: GPS Degraded transitions autonomously to PDR positioning', () async {
      resilienceEngine.connectivityService.setSimulatedStatus(true);
      resilienceEngine.setOverrideMode(ResilienceOverrideMode.simulateGpsLoss);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final snapshot = facade.getCurrentSnapshot();
      expect(snapshot.connectivity.isOnline, isTrue);
      expect(snapshot.resilience.mode, 'pdrFallback');
      expect(snapshot.resilience.infrastructureCase, 'case2');
    });

    test('CASE 3: GPS Active + Internet Offline preserves positioning & selects Offline Queue', () async {
      resilienceEngine.connectivityService.setSimulatedStatus(false);
      resilienceEngine.setOverrideMode(ResilienceOverrideMode.forceGps);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final snapshot = facade.getCurrentSnapshot();
      expect(snapshot.connectivity.isOnline, isFalse);
      expect(snapshot.connectivity.activeDeliveryChannel, 'OFFLINE_QUEUE');
      expect(snapshot.resilience.infrastructureCase, 'case3');
    });

    test('CASE 4: Total Blackout (GPS Lost + Offline) engages PDR and local storage queue', () async {
      resilienceEngine.setOverrideMode(ResilienceOverrideMode.simulateTotalBlackout);
      resilienceEngine.connectivityService.setSimulatedStatus(false);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final snapshot = facade.getCurrentSnapshot();
      expect(snapshot.connectivity.isOnline, isFalse);
      expect(snapshot.resilience.mode, 'pdrFallback');
      expect(snapshot.connectivity.activeDeliveryChannel, 'OFFLINE_QUEUE');
      expect(snapshot.resilience.infrastructureCase, 'case4');
    });

    test('SafetyEngine creates SOS, snapshots position, and delivers via transport', () async {
      resilienceEngine.connectivityService.setSimulatedStatus(true);
      resilienceEngine.setOverrideMode(ResilienceOverrideMode.forceGps);
      resilienceEngine.gpsProvider.injectSimulatedPosition(
        PositionEstimate(
          latitude: 19.0760,
          longitude: 72.8777,
          source: PositionSource.gps,
          confidence: 0.95,
          uncertaintyMeters: 4.0,
          timestamp: DateTime.now(),
          isAbsolute: true,
          isDegraded: false,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final sosEvent = await safetyEngine.createSos(metadata: {'session_id': 'test-session'});
      expect(sosEvent.eventType, SafetyEventType.sos);
      expect(sosEvent.latitude, 19.0760);
      expect(sosEvent.longitude, 72.8777);
      expect(mockTransport.transmittedEvents.isNotEmpty, isTrue);
    });
  });
}

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

import 'package:sih/integration/models/connectivity_snapshot.dart';
import 'package:sih/integration/models/movement_snapshot.dart';
import 'package:sih/integration/models/p1_system_snapshot.dart';
import 'package:sih/integration/models/position_snapshot.dart';
import 'package:sih/integration/models/resilience_snapshot.dart';
import 'package:sih/integration/p1_integration_facade.dart';
import 'package:sih/pdr/core/pdr_engine.dart';
import 'package:sih/pdr/models/pdr_state.dart';
import 'package:sih/resilience/core/resilience_engine.dart';
import 'package:sih/resilience/models/gps_health.dart';
import 'package:sih/resilience/models/position_estimate.dart';
import 'package:sih/resilience/models/position_source.dart';
import 'package:sih/resilience/models/positioning_mode.dart';
import 'package:sih/resilience/models/resilience_state.dart';
import 'package:sih/resilience/models/system_capabilities.dart';
import 'package:sih/resilience/providers/gps_positioning_provider.dart';
import 'package:sih/resilience/providers/pdr_positioning_provider.dart';
import 'package:sih/resilience/sensors/connectivity_service.dart';
import 'package:sih/safety/models/safety_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P1 Integration Contract & Snapshot Models Tests', () {
    final now = DateTime(2026, 8, 23, 14, 30, 0);

    // ============================================================
    // TEST 1: PositionSnapshot Serialization & Round-Trip
    // ============================================================
    test('TEST 1 — PositionSnapshot.toJson() and fromJson() serialize correctly', () {
      final pos = PositionSnapshot(
        latitude: 19.076000,
        longitude: 72.877700,
        source: PositionSource.gps.name,
        confidence: 0.95,
        uncertaintyMeters: 3.8,
        isDegraded: false,
        isAbsolute: true,
        timestamp: now,
      );

      final json = pos.toJson();
      expect(json['latitude'], 19.076000);
      expect(json['longitude'], 72.877700);
      expect(json['source'], 'gps');
      expect(json['confidence'], 0.95);
      expect(json['uncertaintyMeters'], 3.8);
      expect(json['isDegraded'], isFalse);
      expect(json['isAbsolute'], isTrue);

      final reconstructed = PositionSnapshot.fromJson(json);
      expect(reconstructed.latitude, pos.latitude);
      expect(reconstructed.longitude, pos.longitude);
      expect(reconstructed.source, pos.source);
      expect(reconstructed.confidence, pos.confidence);
      expect(reconstructed.uncertaintyMeters, pos.uncertaintyMeters);
      expect(reconstructed.isDegraded, pos.isDegraded);
      expect(reconstructed.isAbsolute, pos.isAbsolute);
      expect(reconstructed.hasValidFix, isTrue);
    });

    // ============================================================
    // TEST 2: MovementSnapshot & Cardinal Compass Directions
    // ============================================================
    test('TEST 2 — MovementSnapshot correctly formats kinematics and cardinal directions', () {
      expect(MovementSnapshot.computeCardinalDirection(0.0), 'NORTH');
      expect(MovementSnapshot.computeCardinalDirection(45.0), 'NORTH_EAST');
      expect(MovementSnapshot.computeCardinalDirection(90.0), 'EAST');
      expect(MovementSnapshot.computeCardinalDirection(135.0), 'SOUTH_EAST');
      expect(MovementSnapshot.computeCardinalDirection(180.0), 'SOUTH');
      expect(MovementSnapshot.computeCardinalDirection(225.0), 'SOUTH_WEST');
      expect(MovementSnapshot.computeCardinalDirection(270.0), 'WEST');
      expect(MovementSnapshot.computeCardinalDirection(315.0), 'NORTH_WEST');
      expect(MovementSnapshot.computeCardinalDirection(359.0), 'NORTH');

      final mov = MovementSnapshot(
        steps: 1240,
        distanceMeters: 890.5,
        headingDegrees: 48.0,
        direction: 'NORTH_EAST',
        speedMps: 1.35,
        strideLengthMeters: 0.72,
        isStationary: false,
        isWalking: true,
        stepConfidence: 0.92,
        headingConfidence: 0.88,
        overallConfidence: 0.90,
        localX: 25.4,
        localY: 18.2,
        timestamp: now,
      );

      final json = mov.toJson();
      expect(json['steps'], 1240);
      expect(json['distanceMeters'], 890.5);
      expect(json['headingDegrees'], 48.0);
      expect(json['direction'], 'NORTH_EAST');
      expect(json['speedMps'], 1.35);

      final roundTrip = MovementSnapshot.fromJson(json);
      expect(roundTrip.steps, 1240);
      expect(roundTrip.distanceMeters, 890.5);
      expect(roundTrip.direction, 'NORTH_EAST');
      expect(roundTrip.isWalking, isTrue);
    });

    // ============================================================
    // TEST 3: ResilienceSnapshot Serialization & Cases
    // ============================================================
    test('TEST 3 — ResilienceSnapshot preserves state machine modes and capabilities', () {
      final res = ResilienceSnapshot(
        mode: PositioningMode.gps.name,
        infrastructureCase: 'case1',
        systemStatusLabel: 'CASE 1 — FULLY CONNECTED',
        confidenceRating: 'HIGH',
        gpsAvailable: true,
        gpsHealth: GpsHealth.active.name,
        wifiAvailable: true,
        pdrActive: true,
        activePositionSource: PositionSource.gps.name,
        activeConfidence: 0.96,
        activeUncertaintyMeters: 3.5,
        internetAvailable: true,
        pdrDisplacementMeters: 0.0,
        lastAnchorDiscrepancyMeters: null,
        lastMatchedAnchorId: null,
        lastWifiAnchorStatus: null,
        lastWifiSimilarityScore: null,
        anchorCorrectionCount: 0,
        isMapConstrained: false,
        lastMapConstraintStatus: 'NOT APPLIED',
        timestamp: now,
      );

      final json = res.toJson();
      expect(json['mode'], 'gps');
      expect(json['infrastructureCase'], 'case1');
      expect(json['gpsHealth'], 'active');
      expect(json['confidenceRating'], 'HIGH');

      final reconstructed = ResilienceSnapshot.fromJson(json);
      expect(reconstructed.mode, 'gps');
      expect(reconstructed.gpsAvailable, isTrue);
      expect(reconstructed.internetAvailable, isTrue);
    });

    // ============================================================
    // TEST 4: ConnectivitySnapshot Serialization
    // ============================================================
    test('TEST 4 — ConnectivitySnapshot maps online and offline routing channels', () {
      final onlineCon = ConnectivitySnapshot(
        isOnline: true,
        cellularAvailable: true,
        wifiAvailable: true,
        activeDeliveryChannel: 'INTERNET',
        timestamp: now,
      );
      expect(onlineCon.toJson()['activeDeliveryChannel'], 'INTERNET');

      final offlineCon = ConnectivitySnapshot(
        isOnline: false,
        cellularAvailable: false,
        wifiAvailable: false,
        activeDeliveryChannel: 'OFFLINE_QUEUE',
        timestamp: now,
      );
      expect(offlineCon.toJson()['activeDeliveryChannel'], 'OFFLINE_QUEUE');

      final fromJson = ConnectivitySnapshot.fromJson(offlineCon.toJson());
      expect(fromJson.isOnline, isFalse);
      expect(fromJson.activeDeliveryChannel, 'OFFLINE_QUEUE');
    });

    // ============================================================
    // TEST 5: Top-Level P1SystemSnapshot JSON Round-Trip
    // ============================================================
    test('TEST 5 — P1SystemSnapshot.build() produces complete unified snapshot and serializes to valid JSON', () {
      final rState = ResilienceState(
        capabilities: const SystemCapabilities(
          gpsAvailable: true,
          gpsHealth: GpsHealth.active,
          internetAvailable: true,
          wifiAvailable: true,
        ),
        positioningMode: PositioningMode.gps,
        position: PositionEstimate(
          latitude: 19.076000,
          longitude: 72.877700,
          source: PositionSource.gps,
          confidence: 0.95,
          uncertaintyMeters: 4.0,
          timestamp: now,
          isAbsolute: true,
          isDegraded: false,
        ),
        timestamp: now,
      );

      final pState = PdrState.initial(initialHeading: 90.0).copyWith(
        stepCount: 150,
        totalDistance: 105.0,
        velocity: 1.25,
        isStationary: false,
        isWalking: true,
      );

      final snapshot = P1SystemSnapshot.build(
        resilienceState: rState,
        pdrState: pState,
        timestamp: now,
      );

      final jsonMap = snapshot.toJson();
      final jsonString = jsonEncode(jsonMap);

      expect(jsonString, contains('"latitude":19.076'));
      expect(jsonString, contains('"steps":150'));
      expect(jsonString, contains('"distanceMeters":105.0'));
      expect(jsonString, contains('"direction":"EAST"'));
      expect(jsonString, contains('"mode":"gps"'));
      expect(jsonString, contains('"isOnline":true'));

      final reconstructed = P1SystemSnapshot.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
      expect(reconstructed.position.latitude, 19.076000);
      expect(reconstructed.movement.steps, 150);
      expect(reconstructed.movement.direction, 'EAST');
      expect(reconstructed.resilience.mode, 'gps');
      expect(reconstructed.connectivity.isOnline, isTrue);
    });

    // ============================================================
    // TEST 6: Null and Blackout Handling (No Fabricated Values)
    // ============================================================
    test('TEST 6 — Null position state leaves coordinates null without generating fake (0,0) values', () {
      final initialRState = ResilienceState.initial();
      final initialPState = PdrState.initial();

      final snapshot = P1SystemSnapshot.build(
        resilienceState: initialRState,
        pdrState: initialPState,
        timestamp: now,
      );

      expect(snapshot.position.latitude, isNull);
      expect(snapshot.position.longitude, isNull);
      expect(snapshot.position.hasValidFix, isFalse);
      expect(snapshot.position.isDegraded, isTrue);

      final json = snapshot.toJson();
      expect(json['position']['latitude'], isNull);
      expect(json['position']['longitude'], isNull);

      final reconstructed = P1SystemSnapshot.fromJson(json);
      expect(reconstructed.position.latitude, isNull);
      expect(reconstructed.position.longitude, isNull);
      expect(reconstructed.position.hasValidFix, isFalse);
    });

    // ============================================================
    // TEST 7: P1IntegrationFacade One-Shot & Live Stream
    // ============================================================
    test('TEST 7 — P1IntegrationFacade exposes getCurrentSnapshot() and reactive stream without modifying PDR state', () async {
      final pdrEngine = PdrEngine();
      final pdrProvider = PdrPositioningProvider(engine: pdrEngine);
      final gpsProvider = GpsPositioningProvider();
      final connService = ConnectivityService();

      final resilienceEngine = ResilienceEngine(
        gpsProvider: gpsProvider,
        pdrProvider: pdrProvider,
        connectivityService: connService,
      );

      final facade = P1IntegrationFacade(
        resilienceEngine: resilienceEngine,
        pdrEngine: pdrEngine,
      );

      // Verify one-shot read
      final initialSnapshot = facade.getCurrentSnapshot();
      expect(initialSnapshot.movement.steps, 0);
      expect(initialSnapshot.resilience.mode, 'pdrFallback');

      // Verify stream updates
      final streamSnapshots = <P1SystemSnapshot>[];
      final subscription = facade.snapshotStream.listen(streamSnapshots.add);

      await resilienceEngine.start();

      // Inject GPS fix
      gpsProvider.injectSimulatedPosition(
        PositionEstimate(
          latitude: 19.076500,
          longitude: 72.877900,
          source: PositionSource.gps,
          confidence: 0.95,
          uncertaintyMeters: 4.0,
          timestamp: DateTime.now(),
          isAbsolute: true,
          isDegraded: false,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final latest = facade.getCurrentSnapshot();
      expect(latest.position.latitude, closeTo(19.076500, 0.00001));
      expect(latest.position.source, 'gps');
      expect(latest.resilience.mode, 'gps');

      // Stream received updates
      expect(streamSnapshots.isNotEmpty, isTrue);

      await subscription.cancel();
      facade.dispose();
      await resilienceEngine.stop();
      gpsProvider.dispose();
      pdrProvider.dispose();
      pdrEngine.dispose();
      connService.dispose();
      resilienceEngine.dispose();
    });

    // ============================================================
    // TEST 8: SafetyEvent.toJson() Compliance
    // ============================================================
    test('TEST 8 — SafetyEvent.toJson() remains compliant with P1 handover contract', () {
      final event = SafetyEvent(
        eventId: 'SOS-1787430000000-1001',
        eventType: SafetyEventType.sos,
        timestamp: now,
        latitude: 19.07620,
        longitude: 72.87790,
        positionSource: PositionSource.gps,
        confidence: 0.96,
        uncertaintyMeters: 3.8,
        positioningMode: PositioningMode.gps,
        gpsHealth: GpsHealth.active,
        internetAvailable: true,
        eventStatus: EventDeliveryStatus.sent,
        createdAt: now,
        deliveryChannel: 'HTTP',
        metadata: {'notes': 'Handover compliance test'},
      );

      final json = event.toJson();
      expect(json['eventId'], 'SOS-1787430000000-1001');
      expect(json['eventType'], 'sos');
      expect(json['latitude'], 19.07620);
      expect(json['longitude'], 72.87790);
      expect(json['positionSource'], 'gps');
      expect(json['confidence'], 0.96);
      expect(json['uncertaintyMeters'], 3.8);
      expect(json['deliveryChannel'], 'HTTP');

      final roundTrip = SafetyEvent.fromJson(json);
      expect(roundTrip.eventId, event.eventId);
      expect(roundTrip.latitude, event.latitude);
      expect(roundTrip.positionSource, PositionSource.gps);
    });
  });
}

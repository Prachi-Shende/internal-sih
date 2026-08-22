import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

import 'package:sih/pdr/core/pdr_engine.dart';
import 'package:sih/pdr/models/orientation_sample.dart';
import 'package:sih/pdr/models/sensor_sample.dart';
import 'package:sih/resilience/core/resilience_engine.dart';
import 'package:sih/resilience/localization/wifi_fingerprint_matcher.dart';
import 'package:sih/resilience/map/graph_map_matcher.dart';
import 'package:sih/resilience/map/walkable_graph.dart';
import 'package:sih/resilience/models/localization_anchor.dart';
import 'package:sih/resilience/models/position_estimate.dart';
import 'package:sih/resilience/models/position_source.dart';
import 'package:sih/resilience/models/positioning_mode.dart';
import 'package:sih/resilience/models/resilience_event.dart';
import 'package:sih/resilience/models/wifi_fingerprint.dart';
import 'package:sih/resilience/providers/gps_positioning_provider.dart';
import 'package:sih/resilience/providers/pdr_positioning_provider.dart';
import 'package:sih/resilience/repositories/localization_anchor_repository.dart';
import 'package:sih/resilience/sensors/android_wifi_scanner.dart';
import 'package:sih/resilience/sensors/connectivity_service.dart';
import 'package:sih/resilience/sensors/wifi_scanner.dart';

/// Helper to simulate synthetic walking motion through the PDR engine.
double simulateWalkingMotion({
  required PdrEngine engine,
  required int stepsToGenerate,
  required double stepFrequencyHz,
  required double headingDegrees,
  double peakAcceleration = 3.0,
  double sampleRateHz = 50.0,
  double startTime = 1.0,
}) {
  final dt = 1.0 / sampleRateHz;
  final samplesPerStep = (sampleRateHz / stepFrequencyHz).round();
  final totalSamples = stepsToGenerate * samplesPerStep;

  final yaw = (90.0 - headingDegrees) * pi / 180.0;
  final qz = sin(yaw / 2.0);
  final qw = cos(yaw / 2.0);

  double currentT = startTime;

  for (int i = 0; i <= totalSamples; i++) {
    currentT = startTime + (i * dt);
    final gaitWave = peakAcceleration * sin(2.0 * pi * stepFrequencyHz * (i * dt));
    final az = 9.80665 + gaitWave;

    final sample = SensorSample(
      timestamp: currentT,
      dt: dt,
      ax: 0.0,
      ay: 0.0,
      az: az,
      gx: 0.0,
      gy: 0.0,
      gz: 0.0,
    );

    final orientation = OrientationSample.fromQuaternion(
      timestamp: currentT,
      qx: 0.0,
      qy: 0.0,
      qz: qz,
      qw: qw,
    );

    engine.processSensorSample(sample: sample, orientation: orientation);
  }

  return currentT + dt;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PdrEngine pdrEngine;
  late PdrPositioningProvider pdrProvider;
  late GpsPositioningProvider gpsProvider;
  late SimulatedWifiScanner wifiScanner;
  late InMemoryLocalizationAnchorRepository anchorRepo;
  late ConnectivityService connectivityService;
  late WalkableGraph walkableGraph;
  late GraphMapMatcher mapMatcher;
  late ResilienceEngine resilienceEngine;

  setUp(() {
    pdrEngine = PdrEngine();
    pdrProvider = PdrPositioningProvider(engine: pdrEngine);
    gpsProvider = GpsPositioningProvider();
    wifiScanner = SimulatedWifiScanner();
    anchorRepo = InMemoryLocalizationAnchorRepository(populateDemoAnchors: true);
    connectivityService = ConnectivityService();
    walkableGraph = WalkableGraph.demoVenue();
    mapMatcher = GraphMapMatcher(graph: walkableGraph);

    resilienceEngine = ResilienceEngine(
      pdrProvider: pdrProvider,
      gpsProvider: gpsProvider,
      wifiScanner: wifiScanner,
      anchorRepository: anchorRepo,
      connectivityService: connectivityService,
      mapConstraintProvider: mapMatcher,
    );
  });

  tearDown(() {
    resilienceEngine.dispose();
  });

  group('Step 4: Real Device Offline Localization & Map Matching Tests', () {
    test('TEST 1 & 2 — Scanner Abstraction & Simulation Selection', () async {
      // AndroidWifiScanner instance creation and interface validation
      final androidScanner = AndroidWifiScanner();
      expect(androidScanner, isA<WifiScanner>());

      // SimulatedWifiScanner should be fully functional in tests
      expect(wifiScanner.isAvailable, isTrue);
      wifiScanner.setAvailability(false);
      expect(wifiScanner.isAvailable, isFalse);
      wifiScanner.setAvailability(true);
    });

    test('TEST 3 — Empty Wi-Fi Scan Handled Gracefully', () async {
      await resilienceEngine.start();
      wifiScanner.injectScan(WifiFingerprint(
        timestamp: DateTime.now(),
        observations: const [],
      ));

      final result = await resilienceEngine.performWifiLocalizationScan();
      expect(result?.isAccepted ?? false, isFalse);
      expect(resilienceEngine.currentState.positioningMode, equals(PositioningMode.pdrFallback));
    });

    test('TEST 4, 5, 6 — Wi-Fi Unavailable / Disabled / Scan Failure Handled Without Crash', () async {
      await resilienceEngine.start();

      // Scanner marked unavailable
      wifiScanner.setAvailability(false);
      final scan1 = await resilienceEngine.performWifiLocalizationScan();
      expect(scan1, isNull);

      // PDR remains alive and functioning
      pdrProvider.setAnchor(PositionEstimate(
        latitude: 19.076000,
        longitude: 72.877700,
        source: PositionSource.pdr,
        confidence: 0.80,
        uncertaintyMeters: 10.0,
        timestamp: DateTime.now(),
        isAbsolute: true,
        isDegraded: false,
      ));

      simulateWalkingMotion(
        engine: pdrEngine,
        stepsToGenerate: 5,
        stepFrequencyHz: 1.8,
        headingDegrees: 0.0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(resilienceEngine.currentState.position, isNotNull);
      expect(resilienceEngine.currentState.position!.latitude, greaterThan(19.076000));
    });

    test('TEST 7, 8, 9 — Hardware Scan Conversion & Offline Matching / Rejection', () async {
      const matcher = WifiFingerprintMatcher();
      final candidates = await anchorRepo.getAllAnchors();

      // Convert raw-style observations to model
      final validFingerprint = WifiFingerprint(
        timestamp: DateTime.now(),
        observations: const [
          WifiAccessPointObservation(bssid: '00:11:22:33:44:02', ssid: 'Hotel_Admin_Internal', rssi: -47, frequencyMhz: 2437),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:03', ssid: 'Cafe_Express_WiFi', rssi: -50, frequencyMhz: 2462),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:04', ssid: 'Corridor_Repeater_02', rssi: -59, frequencyMhz: 5180),
        ],
      );

      final matchResult = matcher.match(observed: validFingerprint, candidateAnchors: candidates);
      expect(matchResult.isAccepted, isTrue);
      expect(matchResult.matchedAnchor!.id, equals('anchor_corridor_02'));

      // Unknown APs
      final unknownFingerprint = WifiFingerprint(
        timestamp: DateTime.now(),
        observations: const [
          WifiAccessPointObservation(bssid: 'FE:DC:BA:98:76:54', ssid: 'Unknown_AP_1', rssi: -40),
          WifiAccessPointObservation(bssid: 'FE:DC:BA:98:76:55', ssid: 'Unknown_AP_2', rssi: -50),
        ],
      );

      final rejectResult = matcher.match(observed: unknownFingerprint, candidateAnchors: candidates);
      expect(rejectResult.isAccepted, isFalse);
      expect(rejectResult.matchedAnchor, isNull);
    });

    test('TEST 10 & 11 — CASE 4: GPS OFF + Internet OFF + Local Wi-Fi Matching', () async {
      await resilienceEngine.start();

      // Total radio blackout of external services
      connectivityService.setSimulatedStatus(false);
      gpsProvider.simulateGpsLoss();

      // Initial anchor at Lobby
      pdrProvider.setAnchor(PositionEstimate(
        latitude: 19.076000,
        longitude: 72.877700,
        source: PositionSource.pdr,
        confidence: 0.70,
        uncertaintyMeters: 20.0,
        timestamp: DateTime.now(),
        isAbsolute: true,
        isDegraded: false,
      ));

      // Scan matching local corridor anchor (at 19.076060, 72.877710)
      wifiScanner.injectScan(WifiFingerprint(
        timestamp: DateTime.now(),
        observations: const [
          WifiAccessPointObservation(bssid: '00:11:22:33:44:02', ssid: 'Hotel_Admin_Internal', rssi: -48),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:03', ssid: 'Cafe_Express_WiFi', rssi: -50),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:04', ssid: 'Corridor_Repeater_02', rssi: -60),
        ],
      ));

      final match = await resilienceEngine.performWifiLocalizationScan();
      expect(match, isNotNull);
      expect(match!.isAccepted, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = resilienceEngine.currentState;
      expect(state.capabilities.internetAvailable, isFalse);
      expect(state.capabilities.gpsAvailable, isFalse);
      expect(state.position!.source, anyOf(equals(PositionSource.wifiFingerprint), equals(PositionSource.mapMatched)));
      expect(state.lastMatchedAnchor?.id, equals('anchor_corridor_02'));
    });

    test('TEST 13 & 14 — Spatial Plausibility Rejection (> 100m) Prevents Teleportation', () async {
      await resilienceEngine.start();

      gpsProvider.injectSimulatedPosition(PositionEstimate(
        latitude: 19.076000,
        longitude: 72.877700,
        source: PositionSource.gps,
        confidence: 0.95,
        uncertaintyMeters: 4.0,
        timestamp: DateTime.now(),
        isAbsolute: true,
        isDegraded: false,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      gpsProvider.simulateGpsLoss();

      // Add distant anchor (300m away)
      await anchorRepo.addAnchor(LocalizationAnchor(
        id: 'anchor_distant_subway',
        name: 'Distant Subway Station',
        latitude: 19.079000, // ~330m North
        longitude: 72.877700,
        fingerprint: WifiFingerprint(
          timestamp: DateTime.now(),
          observations: const [
            WifiAccessPointObservation(bssid: '88:77:66:55:44:33', ssid: 'Metro_Free_WiFi', rssi: -45),
            WifiAccessPointObservation(bssid: '88:77:66:55:44:34', ssid: 'Subway_Kiosk', rssi: -55),
          ],
        ),
      ));

      wifiScanner.injectScan(WifiFingerprint(
        timestamp: DateTime.now(),
        observations: const [
          WifiAccessPointObservation(bssid: '88:77:66:55:44:33', ssid: 'Metro_Free_WiFi', rssi: -45),
          WifiAccessPointObservation(bssid: '88:77:66:55:44:34', ssid: 'Subway_Kiosk', rssi: -55),
        ],
      ));

      await resilienceEngine.performWifiLocalizationScan();

      // Position should remain near 19.076000 and NOT teleport to 19.079000
      final state = resilienceEngine.currentState;
      expect(state.position!.latitude, closeTo(19.076000, 1e-4));
      expect(
        resilienceEngine.eventHistory.any((e) => e.type == ResilienceEventType.pdrAnchorCorrectionRejected),
        isTrue,
      );
    });

    test('TEST 15 & 16 — Offline Map Matching Snaps Drifting Position to Walkable Corridor', () async {
      // Point drifting 3.3 meters North of East-West hallway (19.076050, 72.877750)
      const driftingLat = 19.076080;
      const driftingLon = 72.877750;

      final rawEstimate = PositionEstimate(
        latitude: driftingLat,
        longitude: driftingLon,
        source: PositionSource.pdr,
        confidence: 0.75,
        uncertaintyMeters: 14.0,
        timestamp: DateTime.now(),
        isAbsolute: true,
        isDegraded: true,
      );

      final result = await mapMatcher.constrain(rawEstimate);
      expect(result.isAccepted, isTrue);
      expect(result.wasSnapped, isTrue);
      expect(result.distanceCorrectionMeters, greaterThan(0.5));
      expect(result.constrainedPosition.source, equals(PositionSource.mapMatched));
      expect(result.constrainedPosition.uncertaintyMeters, lessThan(14.0)); // uncertainty improved

      // Point far outside venue (> 50m) should NOT be forced to snap
      final farEstimate = PositionEstimate(
        latitude: 19.080000, // 400m North
        longitude: 72.877700,
        source: PositionSource.pdr,
        confidence: 0.60,
        uncertaintyMeters: 30.0,
        timestamp: DateTime.now(),
        isAbsolute: true,
        isDegraded: true,
      );

      final farResult = await mapMatcher.constrain(farEstimate);
      expect(farResult.wasSnapped, isFalse);
      expect(farResult.constrainedPosition.latitude, equals(19.080000));
    });

    test('TEST 17 & 18 & 19 — GPS Recovery, No (0,0) Reset, No Teleportation', () async {
      await resilienceEngine.start();

      // 1. Initial GPS Fix
      final initialGps = PositionEstimate(
        latitude: 19.076000,
        longitude: 72.877700,
        source: PositionSource.gps,
        confidence: 0.95,
        uncertaintyMeters: 4.0,
        timestamp: DateTime.now(),
        isAbsolute: true,
        isDegraded: false,
      );
      gpsProvider.injectSimulatedPosition(initialGps);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 2. GPS Lost -> PDR walks
      gpsProvider.simulateGpsLoss();
      simulateWalkingMotion(
        engine: pdrEngine,
        stepsToGenerate: 10,
        stepFrequencyHz: 1.8,
        headingDegrees: 0.0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Assert no (0,0) reset
      expect(resilienceEngine.currentState.position!.latitude, isNot(equals(0.0)));
      expect(resilienceEngine.currentState.position!.longitude, isNot(equals(0.0)));

      // 3. Wi-Fi Anchor Matched
      wifiScanner.injectScan(WifiFingerprint(
        timestamp: DateTime.now(),
        observations: const [
          WifiAccessPointObservation(bssid: '00:11:22:33:44:02', ssid: 'Hotel_Admin_Internal', rssi: -48),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:03', ssid: 'Cafe_Express_WiFi', rssi: -50),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:04', ssid: 'Corridor_Repeater_02', rssi: -60),
        ],
      ));
      await resilienceEngine.performWifiLocalizationScan();

      // 4. GPS Recovers
      final restoredGps = PositionEstimate(
        latitude: 19.076070,
        longitude: 72.877710,
        source: PositionSource.gps,
        confidence: 0.96,
        uncertaintyMeters: 3.0,
        timestamp: DateTime.now(),
        isAbsolute: true,
        isDegraded: false,
      );
      gpsProvider.injectSimulatedPosition(restoredGps);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = resilienceEngine.currentState;
      expect(state.positioningMode, equals(PositioningMode.gps));
      expect(state.position!.source, equals(PositionSource.gps));
      expect(state.pdrAnchor!.latitude, equals(restoredGps.latitude));
      expect(state.lastDiscrepancyMeters, isNotNull);
      expect(state.lastDiscrepancyMeters!, lessThan(10.0));
    });
  });
}

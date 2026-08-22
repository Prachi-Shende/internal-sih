import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

import 'package:sih/pdr/core/pdr_engine.dart';
import 'package:sih/pdr/models/orientation_sample.dart';
import 'package:sih/pdr/models/sensor_sample.dart';
import 'package:sih/resilience/core/resilience_engine.dart';
import 'package:sih/resilience/localization/wifi_fingerprint_matcher.dart';
import 'package:sih/resilience/models/localization_anchor.dart';
import 'package:sih/resilience/models/position_estimate.dart';
import 'package:sih/resilience/models/position_source.dart';
import 'package:sih/resilience/models/positioning_mode.dart';
import 'package:sih/resilience/models/resilience_event.dart';
import 'package:sih/resilience/models/wifi_fingerprint.dart';
import 'package:sih/resilience/providers/gps_positioning_provider.dart';
import 'package:sih/resilience/providers/pdr_positioning_provider.dart';
import 'package:sih/resilience/repositories/localization_anchor_repository.dart';
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
  late ResilienceEngine resilienceEngine;

  setUp(() {
    pdrEngine = PdrEngine();
    pdrProvider = PdrPositioningProvider(engine: pdrEngine);
    gpsProvider = GpsPositioningProvider();
    wifiScanner = SimulatedWifiScanner();
    anchorRepo = InMemoryLocalizationAnchorRepository(populateDemoAnchors: true);
    connectivityService = ConnectivityService();

    resilienceEngine = ResilienceEngine(
      pdrProvider: pdrProvider,
      gpsProvider: gpsProvider,
      wifiScanner: wifiScanner,
      anchorRepository: anchorRepo,
      connectivityService: connectivityService,
    );
  });

  tearDown(() {
    resilienceEngine.dispose();
  });

  group('Step 3: Anchor & Offline Localization Tests', () {
    test('TEST 1 — Anchor Database Loads: Demo landmarks loaded successfully', () async {
      final anchors = await anchorRepo.getAllAnchors();
      expect(anchors.length, greaterThanOrEqualTo(3));

      final lobby = await anchorRepo.getAnchorById('anchor_hotel_lobby_01');
      expect(lobby, isNotNull);
      expect(lobby!.name, contains('Lobby'));
      expect(lobby.fingerprint.observations.length, equals(3));
    });

    test('TEST 2 — Fingerprint Matching Succeeds: Known fingerprint matches correct anchor', () async {
      const matcher = WifiFingerprintMatcher();
      final candidates = await anchorRepo.getAllAnchors();

      // Observation that matches anchor_corridor_02
      final observed = WifiFingerprint(
        timestamp: DateTime.now(),
        observations: const [
          WifiAccessPointObservation(bssid: '00:11:22:33:44:02', ssid: 'Hotel_Admin_Internal', rssi: -49),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:03', ssid: 'Cafe_Express_WiFi', rssi: -51),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:04', ssid: 'Corridor_Repeater_02', rssi: -62),
        ],
      );

      final result = matcher.match(observed: observed, candidateAnchors: candidates);
      expect(result.isAccepted, isTrue);
      expect(result.matchedAnchor, isNotNull);
      expect(result.matchedAnchor!.id, equals('anchor_corridor_02'));
      expect(result.similarityScore, greaterThan(0.80));
      expect(result.confidence, greaterThan(0.70));
      expect(result.uncertaintyMeters, lessThan(12.0));
    });

    test('TEST 3 — Fingerprint Mismatch: Unknown APs rejected safely without crash', () async {
      const matcher = WifiFingerprintMatcher();
      final candidates = await anchorRepo.getAllAnchors();

      // Completely foreign APs not in the database
      final foreignObs = WifiFingerprint(
        timestamp: DateTime.now(),
        observations: const [
          WifiAccessPointObservation(bssid: 'AA:BB:CC:DD:EE:01', ssid: 'Foreign_Network_A', rssi: -40),
          WifiAccessPointObservation(bssid: 'AA:BB:CC:DD:EE:02', ssid: 'Foreign_Network_B', rssi: -50),
        ],
      );

      final result = matcher.match(observed: foreignObs, candidateAnchors: candidates);
      expect(result.isAccepted, isFalse);
      expect(result.matchedAnchor, isNull);
      expect(result.rejectionReason, isNotNull);
    });

    test('TEST 4 — GPS → PDR → Wi-Fi Anchor: PDR is corrected and re-anchored', () async {
      await resilienceEngine.start();

      // 1. Initial GPS Fix at Location A
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

      // 2. GPS Lost
      gpsProvider.simulateGpsLoss();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 3. User walks 10 steps North under PDR
      simulateWalkingMotion(
        engine: pdrEngine,
        stepsToGenerate: 10,
        stepFrequencyHz: 1.8,
        headingDegrees: 0.0,
        startTime: 1.0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 4. Phone observes Wi-Fi matching anchor_corridor_02 (at 19.076060, 72.877710)
      wifiScanner.injectScan(WifiFingerprint(
        timestamp: DateTime.now(),
        observations: const [
          WifiAccessPointObservation(bssid: '00:11:22:33:44:02', ssid: 'Hotel_Admin_Internal', rssi: -48),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:03', ssid: 'Cafe_Express_WiFi', rssi: -50),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:04', ssid: 'Corridor_Repeater_02', rssi: -60),
        ],
      ));

      final matchResult = await resilienceEngine.performWifiLocalizationScan();
      expect(matchResult, isNotNull);
      expect(matchResult!.isAccepted, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = resilienceEngine.currentState;
      expect(state.position, isNotNull);
      expect(state.position!.source, equals(PositionSource.wifiFingerprint));
      expect(state.position!.latitude, closeTo(19.076060, 1e-5));
      expect(state.position!.longitude, closeTo(72.877710, 1e-5));
      expect(state.lastMatchedAnchor?.id, equals('anchor_corridor_02'));
      expect(state.anchorCorrectionCount, equals(1));

      // Check events
      expect(resilienceEngine.eventHistory.any((e) => e.type == ResilienceEventType.wifiAnchorMatched), isTrue);
      expect(resilienceEngine.eventHistory.any((e) => e.type == ResilienceEventType.pdrAnchorCorrected), isTrue);
    });

    test('TEST 5 — Anchor Correction Reduces Uncertainty: Uncertainty drops after anchor match', () async {
      await resilienceEngine.start();

      // Establish a degraded PDR state where uncertainty has grown over time
      gpsProvider.injectSimulatedPosition(PositionEstimate(
        latitude: 19.076000,
        longitude: 72.877700,
        source: PositionSource.gps,
        confidence: 0.70,
        uncertaintyMeters: 25.0,
        timestamp: DateTime.now(),
        isAbsolute: true,
        isDegraded: false,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      gpsProvider.simulateGpsLoss();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Walk 15 steps
      simulateWalkingMotion(
        engine: pdrEngine,
        stepsToGenerate: 15,
        stepFrequencyHz: 1.8,
        headingDegrees: 0.0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final highUncertainty = resilienceEngine.currentState.position!.uncertaintyMeters;

      // Scan and match anchor
      wifiScanner.injectScan(WifiFingerprint(
        timestamp: DateTime.now(),
        observations: const [
          WifiAccessPointObservation(bssid: '00:11:22:33:44:02', ssid: 'Hotel_Admin_Internal', rssi: -48),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:03', ssid: 'Cafe_Express_WiFi', rssi: -50),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:04', ssid: 'Corridor_Repeater_02', rssi: -60),
        ],
      ));
      await resilienceEngine.performWifiLocalizationScan();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final reducedUncertainty = resilienceEngine.currentState.position!.uncertaintyMeters;
      expect(reducedUncertainty, lessThan(highUncertainty));
      expect(reducedUncertainty, lessThanOrEqualTo(12.0));
    });

    test('TEST 6 — Large Discrepancy Rejection: Anchor rejected if > 100m away (anti-teleportation)', () async {
      await resilienceEngine.start();

      // Start at Location A (19.076000, 72.877700)
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
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Add an anchor situated 500m away in database
      await anchorRepo.addAnchor(LocalizationAnchor(
        id: 'anchor_distant_airport',
        name: 'Distant Airport Terminal',
        latitude: 19.080500, // ~500m North
        longitude: 72.877700,
        fingerprint: WifiFingerprint(
          timestamp: DateTime.now(),
          observations: const [
            WifiAccessPointObservation(bssid: '99:88:77:66:55:01', ssid: 'Airport_Free_WiFi', rssi: -42),
            WifiAccessPointObservation(bssid: '99:88:77:66:55:02', ssid: 'Airline_Lounge_5G', rssi: -48),
          ],
        ),
      ));

      // Inject scan matching the distant airport
      wifiScanner.injectScan(WifiFingerprint(
        timestamp: DateTime.now(),
        observations: const [
          WifiAccessPointObservation(bssid: '99:88:77:66:55:01', ssid: 'Airport_Free_WiFi', rssi: -42),
          WifiAccessPointObservation(bssid: '99:88:77:66:55:02', ssid: 'Airline_Lounge_5G', rssi: -48),
        ],
      ));

      await resilienceEngine.performWifiLocalizationScan();

      // Anchor must be rejected due to discrepancy > 100m! Position must NOT teleport to airport!
      final state = resilienceEngine.currentState;
      expect(state.position!.latitude, closeTo(19.076000, 1e-4));
      expect(
        resilienceEngine.eventHistory.any((e) => e.type == ResilienceEventType.pdrAnchorCorrectionRejected),
        isTrue,
      );
    });

    test('TEST 7 — Internet Independence: Wi-Fi anchor matching works completely offline', () async {
      await resilienceEngine.start();

      // Simulate Internet OFF + GPS OFF
      connectivityService.setSimulatedStatus(false);
      gpsProvider.simulateGpsLoss();

      // Anchor initially
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

      // Scan offline
      wifiScanner.injectScan(WifiFingerprint(
        timestamp: DateTime.now(),
        observations: const [
          WifiAccessPointObservation(bssid: '00:11:22:33:44:02', ssid: 'Hotel_Admin_Internal', rssi: -48),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:03', ssid: 'Cafe_Express_WiFi', rssi: -50),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:04', ssid: 'Corridor_Repeater_02', rssi: -60),
        ],
      ));

      final result = await resilienceEngine.performWifiLocalizationScan();
      expect(result, isNotNull);
      expect(result!.isAccepted, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = resilienceEngine.currentState;
      expect(state.capabilities.internetAvailable, isFalse);
      expect(state.position!.source, equals(PositionSource.wifiFingerprint));
      expect(
        resilienceEngine.eventHistory.any((e) => e.type == ResilienceEventType.offlineAnchorUsed),
        isTrue,
      );
    });

    test('TEST 8 — Wi-Fi Unavailable: PDR continues smoothly without crashing', () async {
      await resilienceEngine.start();

      gpsProvider.simulateGpsLoss();
      wifiScanner.setAvailability(false);

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
        stepsToGenerate: 6,
        stepFrequencyHz: 1.8,
        headingDegrees: 0.0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final scanResult = await resilienceEngine.performWifiLocalizationScan();
      expect(scanResult, isNull);

      final state = resilienceEngine.currentState;
      expect(state.positioningMode, equals(PositioningMode.pdrFallback));
      expect(state.position!.latitude, greaterThan(19.076000));
    });

    test('TEST 9 — Empty Anchor Database: PDR continues smoothly', () async {
      await anchorRepo.clear();
      await resilienceEngine.start();

      gpsProvider.simulateGpsLoss();
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

      wifiScanner.injectScan(WifiFingerprint(
        timestamp: DateTime.now(),
        observations: const [
          WifiAccessPointObservation(bssid: '00:11:22:33:44:01', ssid: 'Any_Network', rssi: -50),
        ],
      ));

      final scanResult = await resilienceEngine.performWifiLocalizationScan();
      expect(scanResult, isNotNull);
      expect(scanResult!.isAccepted, isFalse);

      final state = resilienceEngine.currentState;
      expect(state.positioningMode, equals(PositioningMode.pdrFallback));
    });

    test('TEST 10 — GPS Recovery after Wi-Fi Correction: GPS restores authoritative control', () async {
      await resilienceEngine.start();

      // 1. Initial GPS
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

      // 2. GPS Lost -> PDR moves
      gpsProvider.simulateGpsLoss();
      simulateWalkingMotion(
        engine: pdrEngine,
        stepsToGenerate: 8,
        stepFrequencyHz: 1.8,
        headingDegrees: 0.0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 3. Wi-Fi Anchor Matched (at 19.076060, 72.877710)
      wifiScanner.injectScan(WifiFingerprint(
        timestamp: DateTime.now(),
        observations: const [
          WifiAccessPointObservation(bssid: '00:11:22:33:44:02', ssid: 'Hotel_Admin_Internal', rssi: -48),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:03', ssid: 'Cafe_Express_WiFi', rssi: -50),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:04', ssid: 'Corridor_Repeater_02', rssi: -60),
        ],
      ));
      await resilienceEngine.performWifiLocalizationScan();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 4. GPS Fix Restored at Location B
      final restoredGps = PositionEstimate(
        latitude: 19.076080,
        longitude: 72.877720,
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
    });

    test('FOUR-CASE RESILIENCE TEST HARNESS: Verifies infrastructure states Cases 1, 2, 3, 4', () async {
      await resilienceEngine.start();

      // CASE 1: GPS ON + Net ON
      connectivityService.setSimulatedStatus(true);
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

      var state = resilienceEngine.currentState;
      expect(state.capabilities.gpsAvailable, isTrue);
      expect(state.capabilities.internetAvailable, isTrue);
      expect(state.positioningMode, equals(PositioningMode.gps));

      // CASE 2: GPS OFF + Net ON
      gpsProvider.simulateGpsLoss();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      state = resilienceEngine.currentState;
      expect(state.capabilities.gpsAvailable, isFalse);
      expect(state.capabilities.internetAvailable, isTrue);
      expect(state.positioningMode, equals(PositioningMode.pdrFallback));

      // CASE 3: GPS ON + Net OFF
      connectivityService.setSimulatedStatus(false);
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
      state = resilienceEngine.currentState;
      expect(state.capabilities.gpsAvailable, isTrue);
      expect(state.capabilities.internetAvailable, isFalse);
      expect(state.positioningMode, equals(PositioningMode.gps));

      // CASE 4: GPS OFF + Net OFF (Local Wi-Fi Anchor operates completely offline)
      gpsProvider.simulateGpsLoss();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      wifiScanner.injectScan(WifiFingerprint(
        timestamp: DateTime.now(),
        observations: const [
          WifiAccessPointObservation(bssid: '00:11:22:33:44:02', ssid: 'Hotel_Admin_Internal', rssi: -48),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:03', ssid: 'Cafe_Express_WiFi', rssi: -50),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:04', ssid: 'Corridor_Repeater_02', rssi: -60),
        ],
      ));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      state = resilienceEngine.currentState;
      expect(state.capabilities.gpsAvailable, isFalse);
      expect(state.capabilities.internetAvailable, isFalse);
      expect(state.position!.source, equals(PositionSource.wifiFingerprint));
    });
  });
}

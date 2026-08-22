import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sih/pdr/core/pdr_engine.dart';
import 'package:sih/pdr/models/orientation_sample.dart';
import 'package:sih/pdr/models/sensor_sample.dart';
import 'package:sih/resilience/core/resilience_engine.dart';
import 'package:sih/resilience/models/gps_health.dart';
import 'package:sih/resilience/models/infrastructure_case.dart';
import 'package:sih/resilience/models/position_estimate.dart';
import 'package:sih/resilience/models/position_source.dart';
import 'package:sih/resilience/models/positioning_mode.dart';
import 'package:sih/resilience/models/wifi_fingerprint.dart';
import 'package:sih/resilience/providers/gps_positioning_provider.dart';
import 'package:sih/resilience/providers/pdr_positioning_provider.dart';
import 'package:sih/resilience/repositories/localization_anchor_repository.dart';
import 'package:sih/resilience/sensors/connectivity_service.dart';
import 'package:sih/resilience/sensors/wifi_scanner.dart';
import 'package:sih/screens/resilience_dashboard_screen.dart';

/// Helper to simulate synthetic walking motion through the PDR engine.
double simulateWalking({
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
  late ConnectivityService connectivityService;
  late SimulatedWifiScanner wifiScanner;
  late InMemoryLocalizationAnchorRepository anchorRepository;
  late ResilienceEngine resilienceEngine;

  setUp(() {
    pdrEngine = PdrEngine();
    pdrProvider = PdrPositioningProvider(engine: pdrEngine);
    gpsProvider = GpsPositioningProvider(
      staleTimeout: const Duration(seconds: 10),
      lossTimeout: const Duration(seconds: 25),
    );
    connectivityService = ConnectivityService();
    wifiScanner = SimulatedWifiScanner();
    anchorRepository = InMemoryLocalizationAnchorRepository();

    resilienceEngine = ResilienceEngine(
      pdrProvider: pdrProvider,
      gpsProvider: gpsProvider,
      connectivityService: connectivityService,
      wifiScanner: wifiScanner,
      anchorRepository: anchorRepository,
    );
  });

  tearDown(() {
    resilienceEngine.dispose();
  });

  group('Step 4.1: Real-Device State Stability & Telemetry Tests', () {
    test('TEST 1 & 2 — GPS remains active during short gaps and STALE does not trigger PDR fallback', () async {
      await resilienceEngine.start();

      final gpsFix = PositionEstimate(
        latitude: 19.076000,
        longitude: 72.877700,
        source: PositionSource.gps,
        confidence: 0.95,
        uncertaintyMeters: 4.0,
        timestamp: DateTime.now(),
        isAbsolute: true,
        isDegraded: false,
      );

      gpsProvider.injectSimulatedPosition(gpsFix);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(resilienceEngine.currentState.positioningMode, PositioningMode.gps);
      expect(resilienceEngine.currentState.position?.source, PositionSource.gps);
      expect(resilienceEngine.currentState.capabilities.gpsHealth, GpsHealth.active);

      // Simulate a temporary gap (>10s): GPS becomes STALE
      gpsProvider.injectSimulatedHealth(GpsHealth.stale);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Crucial: Mode remains GPS, does NOT flap to PDR fallback
      expect(resilienceEngine.currentState.positioningMode, PositioningMode.gps);
      expect(resilienceEngine.currentState.position?.source, PositionSource.gps);
      expect(resilienceEngine.currentState.capabilities.gpsHealth, GpsHealth.stale);
      expect(resilienceEngine.currentState.capabilities.gpsAvailable, isTrue);
    });

    test('TEST 3 & 4 — Sustained GPS loss enters PDR fallback, fresh fix restores GPS', () async {
      await resilienceEngine.start();

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

      // Sustained GPS loss (>25s)
      gpsProvider.injectSimulatedHealth(GpsHealth.lost);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(resilienceEngine.currentState.positioningMode, PositioningMode.pdrFallback);
      expect(resilienceEngine.currentState.position?.source, PositionSource.pdr);
      expect(resilienceEngine.currentState.capabilities.gpsHealth, GpsHealth.lost);

      // Fresh satellite fix arrives
      final recoveryGps = PositionEstimate(
        latitude: 19.076010,
        longitude: 72.877710,
        source: PositionSource.gps,
        confidence: 0.95,
        uncertaintyMeters: 3.5,
        timestamp: DateTime.now(),
        isAbsolute: true,
        isDegraded: false,
      );

      gpsProvider.injectSimulatedPosition(recoveryGps);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Returns to GPS mode
      expect(resilienceEngine.currentState.positioningMode, PositioningMode.gps);
      expect(resilienceEngine.currentState.position?.source, PositionSource.gps);
      expect(resilienceEngine.currentState.capabilities.gpsHealth, GpsHealth.active);
    });

    test('TEST 5 — Rapid GPS interruptions do not cause mode flapping with stale state', () async {
      await resilienceEngine.start();

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
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Rapidly oscillate between active and stale
      for (int i = 0; i < 5; i++) {
        gpsProvider.injectSimulatedHealth(GpsHealth.stale);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(resilienceEngine.currentState.positioningMode, PositioningMode.gps);

        gpsProvider.injectSimulatedHealth(GpsHealth.active);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(resilienceEngine.currentState.positioningMode, PositioningMode.gps);
      }
    });

    test('TEST 6 & 7 — PDR trajectory and history are preserved across GPS ↔ PDR source handovers', () async {
      await resilienceEngine.start();

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

      // Walk 10 steps
      simulateWalking(
        engine: pdrEngine,
        stepsToGenerate: 10,
        stepFrequencyHz: 1.8,
        headingDegrees: 90.0,
        startTime: 1.0,
      );

      final stepsBeforeHandover = pdrEngine.currentState.stepCount;
      final distanceBeforeHandover = pdrEngine.currentState.totalDistance;
      final trajectoryLengthBefore = pdrEngine.currentState.trajectory.length;

      expect(stepsBeforeHandover, greaterThanOrEqualTo(8));
      expect(distanceBeforeHandover, greaterThan(4.0));
      expect(trajectoryLengthBefore, greaterThan(0));

      // GPS loss handover to PDR
      gpsProvider.injectSimulatedHealth(GpsHealth.lost);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Crucial: Step count and trajectory are NOT wiped out
      expect(pdrEngine.currentState.stepCount, equals(stepsBeforeHandover));
      expect(pdrEngine.currentState.totalDistance, equals(distanceBeforeHandover));
      expect(pdrEngine.currentState.trajectory.length, equals(trajectoryLengthBefore));

      // Walk 5 more steps in PDR mode
      simulateWalking(
        engine: pdrEngine,
        stepsToGenerate: 5,
        stepFrequencyHz: 1.8,
        headingDegrees: 90.0,
        startTime: 10.0,
      );

      final stepsDuringPdr = pdrEngine.currentState.stepCount;
      expect(stepsDuringPdr, greaterThan(stepsBeforeHandover));

      // GPS recovery handover back to GPS
      final recoveryGps = PositionEstimate(
        latitude: 19.076050,
        longitude: 72.877800,
        source: PositionSource.gps,
        confidence: 0.95,
        uncertaintyMeters: 3.5,
        timestamp: DateTime.now(),
        isAbsolute: true,
        isDegraded: false,
      );

      gpsProvider.injectSimulatedPosition(recoveryGps);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Crucial: Continuous PDR trajectory is still intact
      expect(pdrEngine.currentState.stepCount, equals(stepsDuringPdr));
      expect(pdrEngine.currentState.trajectory.length, greaterThan(trajectoryLengthBefore));
    });

    test('TEST 8 — GPS and Internet remain completely independent', () async {
      await resilienceEngine.start();

      // Case 1: GPS ON + Net ON
      gpsProvider.injectSimulatedHealth(GpsHealth.active);
      connectivityService.setSimulatedStatus(true);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(resilienceEngine.currentState.infrastructureCase, InfrastructureCase.case1);

      // Case 2: GPS OFF + Net ON
      gpsProvider.injectSimulatedHealth(GpsHealth.lost);
      connectivityService.setSimulatedStatus(true);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(resilienceEngine.currentState.infrastructureCase, InfrastructureCase.case2);

      // Case 3: GPS ON + Net OFF
      gpsProvider.injectSimulatedHealth(GpsHealth.active);
      connectivityService.setSimulatedStatus(false);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(resilienceEngine.currentState.infrastructureCase, InfrastructureCase.case3);

      // Case 4: GPS OFF + Net OFF
      gpsProvider.injectSimulatedHealth(GpsHealth.lost);
      connectivityService.setSimulatedStatus(false);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(resilienceEngine.currentState.infrastructureCase, InfrastructureCase.case4);
    });

    test('TEST 9 & 10 — Wi-Fi matched fingerprint accepted, unmatched rejected', () async {
      await resilienceEngine.start();

      // Unmatched fingerprint
      final unknownFingerprint = WifiFingerprint(
        timestamp: DateTime.now(),
        observations: const [
          WifiAccessPointObservation(bssid: '99:99:99:99:99:01', ssid: 'Unknown_AP_1', rssi: -75),
          WifiAccessPointObservation(bssid: '99:99:99:99:99:02', ssid: 'Unknown_AP_2', rssi: -80),
        ],
      );

      wifiScanner.injectScan(unknownFingerprint);
      final unmatchResult = await resilienceEngine.performWifiLocalizationScan();
      expect(unmatchResult?.isAccepted, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Matched fingerprint for demo anchor "Grand West Corridor"
      final matchedFingerprint = WifiFingerprint(
        timestamp: DateTime.now(),
        observations: const [
          WifiAccessPointObservation(bssid: '00:11:22:33:44:02', ssid: 'Hotel_Admin_Internal', rssi: -48),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:03', ssid: 'Cafe_Express_WiFi', rssi: -50),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:04', ssid: 'Corridor_Repeater_02', rssi: -57),
        ],
      );

      wifiScanner.injectScan(matchedFingerprint);
      final matchResult = await resilienceEngine.performWifiLocalizationScan();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(matchResult?.isAccepted, isTrue);
      expect(matchResult?.matchedAnchor?.id, 'anchor_corridor_02');
      expect(resilienceEngine.currentState.lastWifiAnchorStatus, 'MATCHED');
      expect(resilienceEngine.currentState.lastWifiCorrectionStatus, 'APPLIED');
    });

    testWidgets('TEST 11 — Dashboard renders without RenderFlex overflow at standard mobile dimensions', (tester) async {
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

      await tester.pumpWidget(
        MaterialApp(
          home: ResilienceDashboardScreen(
            resilienceEngine: engine,
            autoStart: false,
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Resilience Orchestrator'), findsOneWidget);
      expect(find.text('SYSTEM STATUS'), findsOneWidget);
      expect(tester.takeException(), isNull);

      gps.dispose();
      conn.dispose();
      pdr.dispose();
      engine.dispose();
    });
  });
}

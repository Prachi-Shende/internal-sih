import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

import 'package:sih/pdr/core/pdr_engine.dart';
import 'package:sih/pdr/models/orientation_sample.dart';
import 'package:sih/pdr/models/sensor_sample.dart';
import 'package:sih/resilience/core/resilience_engine.dart';
import 'package:sih/resilience/models/position_estimate.dart';
import 'package:sih/resilience/models/position_source.dart';
import 'package:sih/resilience/models/positioning_mode.dart';
import 'package:sih/resilience/models/resilience_event.dart';
import 'package:sih/resilience/providers/gps_positioning_provider.dart';
import 'package:sih/resilience/providers/pdr_positioning_provider.dart';
import 'package:sih/resilience/sensors/connectivity_service.dart';

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
  late ConnectivityService connectivityService;
  late ResilienceEngine resilienceEngine;

  setUp(() {
    pdrEngine = PdrEngine();
    pdrProvider = PdrPositioningProvider(engine: pdrEngine);
    gpsProvider = GpsPositioningProvider();
    connectivityService = ConnectivityService();
    resilienceEngine = ResilienceEngine(
      pdrProvider: pdrProvider,
      gpsProvider: gpsProvider,
      connectivityService: connectivityService,
    );
  });

  tearDown(() {
    resilienceEngine.dispose();
  });

  group('Resilience Engine & Positioning Orchestration Tests', () {
    test('TEST 1 — GPS Available: Primary source is GPS, PDR is anchored', () async {
      await resilienceEngine.start();

      final gpsFix = PositionEstimate(
        latitude: 19.076000,
        longitude: 72.877700,
        source: PositionSource.gps,
        confidence: 0.95,
        uncertaintyMeters: 4.5,
        timestamp: DateTime.now(),
        isAbsolute: true,
        isDegraded: false,
        headingDegrees: 0.0,
      );

      // Inject GPS fix
      gpsProvider.injectSimulatedPosition(gpsFix);

      // Allow event loop to process
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = resilienceEngine.currentState;
      expect(state.positioningMode, equals(PositioningMode.gps));
      expect(state.position, isNotNull);
      expect(state.position!.source, equals(PositionSource.gps));
      expect(state.position!.latitude, closeTo(19.076000, 1e-6));
      expect(state.position!.longitude, closeTo(72.877700, 1e-6));
      expect(state.position!.isAbsolute, isTrue);
      expect(state.position!.isDegraded, isFalse);
      expect(state.position!.confidence, greaterThanOrEqualTo(0.90));

      // PDR must be anchored to this GPS fix
      expect(pdrProvider.anchor, isNotNull);
      expect(pdrProvider.anchor!.latitude, closeTo(19.076000, 1e-6));
      expect(pdrProvider.anchor!.longitude, closeTo(72.877700, 1e-6));
    });

    test('TEST 2 — GPS Lost: Seamless switch to PDR Fallback without location reset', () async {
      await resilienceEngine.start();

      // 1. Establish GPS anchor at Location A
      const initialLat = 19.076000;
      const initialLon = 72.877700;
      final initialGps = PositionEstimate(
        latitude: initialLat,
        longitude: initialLon,
        source: PositionSource.gps,
        confidence: 0.95,
        uncertaintyMeters: 5.0,
        timestamp: DateTime.now(),
        isAbsolute: true,
        isDegraded: false,
      );
      gpsProvider.injectSimulatedPosition(initialGps);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 2. Simulate GPS Loss
      gpsProvider.simulateGpsLoss();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = resilienceEngine.currentState;
      expect(state.capabilities.gpsAvailable, isFalse);
      expect(state.positioningMode, equals(PositioningMode.pdrFallback));
      expect(state.position, isNotNull);

      // Position must NOT jump to (0,0) or an arbitrary location
      expect(state.position!.latitude, closeTo(initialLat, 1e-5));
      expect(state.position!.longitude, closeTo(initialLon, 1e-5));
      expect(state.pdrAnchor, isNotNull);
      expect(state.pdrAnchor!.latitude, closeTo(initialLat, 1e-5));

      // Check event emitted
      expect(
        resilienceEngine.eventHistory.any((e) => e.type == ResilienceEventType.gpsLost),
        isTrue,
      );
      expect(
        resilienceEngine.eventHistory.any((e) => e.type == ResilienceEventType.switchedToPdr),
        isTrue,
      );
    });

    test('TEST 3 — PDR Movement after GPS Loss: Continuous displacement from anchor with increasing uncertainty', () async {
      await resilienceEngine.start();

      // 1. Establish GPS anchor
      const anchorLat = 19.076000;
      const anchorLon = 72.877700;
      gpsProvider.injectSimulatedPosition(PositionEstimate(
        latitude: anchorLat,
        longitude: anchorLon,
        source: PositionSource.gps,
        confidence: 0.95,
        uncertaintyMeters: 5.0,
        timestamp: DateTime.now(),
        isAbsolute: true,
        isDegraded: false,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 2. GPS Lost
      gpsProvider.simulateGpsLoss();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 3. User walks 10 steps North (heading 0°)
      simulateWalkingMotion(
        engine: pdrEngine,
        stepsToGenerate: 10,
        stepFrequencyHz: 1.8,
        headingDegrees: 0.0,
        startTime: 1.0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = resilienceEngine.currentState;
      expect(state.positioningMode, equals(PositioningMode.pdrFallback));
      expect(state.position!.source, equals(PositionSource.pdr));
      expect(state.position!.isDegraded, isTrue);

      // Moved North: Latitude should have increased slightly
      expect(state.position!.latitude, greaterThan(anchorLat));
      // Longitude (East-West) should remain nearly unchanged
      expect(state.position!.longitude, closeTo(anchorLon, 1e-5));

      // Uncertainty should have expanded beyond initial 5.0m
      expect(state.position!.uncertaintyMeters, greaterThan(5.0));

      // PDR displacement recorded
      expect(state.pdrDisplacementMeters, greaterThan(5.0));
    });

    test('TEST 4 — GPS Returns: Discrepancy calculated, PDR re-anchored, Mode returns to GPS', () async {
      await resilienceEngine.start();

      // 1. Initial GPS Fix A
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

      // 3. Walk 8 steps North under PDR
      simulateWalkingMotion(
        engine: pdrEngine,
        stepsToGenerate: 8,
        stepFrequencyHz: 1.8,
        headingDegrees: 0.0,
        startTime: 1.0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final pdrEstimatedLat = resilienceEngine.currentState.position!.latitude;
      expect(pdrEstimatedLat, greaterThan(19.076000));

      // 4. GPS Signal Returns with a fresh fix B
      final returningGps = PositionEstimate(
        latitude: 19.076060, // slightly different from PDR dead-reckoned position
        longitude: 72.877710,
        source: PositionSource.gps,
        confidence: 0.95,
        uncertaintyMeters: 3.5,
        timestamp: DateTime.now(),
        isAbsolute: true,
        isDegraded: false,
      );
      gpsProvider.injectSimulatedPosition(returningGps);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = resilienceEngine.currentState;

      // Mode must return to GPS
      expect(state.positioningMode, equals(PositioningMode.gps));
      expect(state.position!.source, equals(PositionSource.gps));
      expect(state.capabilities.gpsAvailable, isTrue);

      // Discrepancy must be computed and recorded
      expect(state.lastDiscrepancyMeters, isNotNull);
      expect(state.lastDiscrepancyMeters!, greaterThan(0.0));

      // Check recovery events in timeline
      final recoveryEvent = resilienceEngine.eventHistory.firstWhere(
        (e) => e.type == ResilienceEventType.gpsRecovered,
      );
      expect(recoveryEvent.discrepancyMeters, isNotNull);

      // PDR must be re-anchored to new GPS fix
      expect(pdrProvider.anchor!.latitude, equals(returningGps.latitude));
      expect(pdrProvider.anchor!.longitude, equals(returningGps.longitude));
    });

    test('TEST 5 — GPS & Internet Independence: GPS works offline, PDR works online', () async {
      await resilienceEngine.start();

      // Case A: GPS ON + Internet OFF
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

      var state = resilienceEngine.currentState;
      expect(state.capabilities.gpsAvailable, isTrue);
      expect(state.capabilities.internetAvailable, isFalse);
      expect(state.positioningMode, equals(PositioningMode.gps));
      expect(state.position!.source, equals(PositionSource.gps));

      // Case B: GPS OFF + Internet ON
      connectivityService.setSimulatedStatus(true);
      gpsProvider.simulateGpsLoss();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      state = resilienceEngine.currentState;
      expect(state.capabilities.gpsAvailable, isFalse);
      expect(state.capabilities.internetAvailable, isTrue);
      expect(state.positioningMode, equals(PositioningMode.pdrFallback));
      expect(state.position!.source, equals(PositionSource.pdr));
    });
  });
}

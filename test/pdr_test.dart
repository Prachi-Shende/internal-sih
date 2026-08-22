import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

import 'package:sih/pdr/calibration/pdr_calibration.dart';
import 'package:sih/pdr/core/pdr_engine.dart';
import 'package:sih/pdr/models/orientation_sample.dart';
import 'package:sih/pdr/models/pdr_config.dart';
import 'package:sih/pdr/models/sensor_sample.dart';
import 'package:sih/pdr/processing/signal_filter.dart';
import 'package:sih/pdr/step_detection/step_detector.dart';
import 'package:sih/pdr/step_length/step_length_estimator.dart';
import 'package:sih/pdr/utils/geo_utils.dart';
import 'package:sih/pdr/utils/math_utils.dart';

/// Helper to simulate synthetic sinusoidal walking acceleration and feed it through PdrEngine.
double simulateWalkingMotion({
  required PdrEngine engine,
  required int stepsToGenerate,
  required double stepFrequencyHz, // e.g. 1.8 Hz
  required double headingDegrees,
  double peakAcceleration = 3.0, // m/s² amplitude
  double sampleRateHz = 50.0,
  double startTime = 1.0,
}) {
  final dt = 1.0 / sampleRateHz;
  final samplesPerStep = (sampleRateHz / stepFrequencyHz).round();
  final totalSamples = stepsToGenerate * samplesPerStep;

  // Convert heading to quaternion (rotation around Z axis in ENU)
  // Yaw in ENU is counter-clockwise from East: yaw = (90 - heading) * pi / 180
  final yaw = (90.0 - headingDegrees) * pi / 180.0;
  final qz = sin(yaw / 2.0);
  final qw = cos(yaw / 2.0);

  double currentT = startTime;

  for (int i = 0; i <= totalSamples; i++) {
    currentT = startTime + (i * dt);
    // Sinusoidal vertical gait wave + gravity (9.81 m/s²)
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

  group('1. Math & Quaternion Utilities', () {
    test('Quaternion vector rotation aligns Phone frame to World frame', () {
      final vRot = MathUtils.rotateVectorByQuaternion(
        vx: 0.0,
        vy: 0.0,
        vz: 9.81,
        qx: 0.0,
        qy: 0.0,
        qz: 0.0,
        qw: 1.0,
      );
      expect(vRot[0], closeTo(0.0, 1e-5));
      expect(vRot[1], closeTo(0.0, 1e-5));
      expect(vRot[2], closeTo(9.81, 1e-5));
    });

    test('Circular angle smoothing across 359° / 1° boundary converges near 0°', () {
      final smoothed = MathUtils.smoothCircularDegrees(
        currentSmoothedDeg: 359.0,
        newSampleDeg: 1.0,
        alpha: 0.5,
      );
      expect(smoothed < 2.0 || smoothed > 358.0, isTrue);
    });

    test('GeoUtils converts local displacement to Lat/Lng and back', () {
      const originLat = 18.5204;
      const originLon = 73.8567;
      const east = 50.0;
      const north = 75.0;

      final latLng = GeoUtils.localMetersToLatLng(
        originLat: originLat,
        originLon: originLon,
        eastMeters: east,
        northMeters: north,
      );

      final backToLocal = GeoUtils.latLngToLocalMeters(
        originLat: originLat,
        originLon: originLon,
        targetLat: latLng.latitude,
        targetLon: latLng.longitude,
      );

      expect(backToLocal.eastMeters, closeTo(east, 0.01));
      expect(backToLocal.northMeters, closeTo(north, 0.01));
    });
  });

  group('2. Digital Band-pass Filter (0.5 - 3.0 Hz)', () {
    test('Passes walking frequency (1.8 Hz) and attenuates high frequency noise (15 Hz)', () {
      final filter = BandpassWalkingFilter(
        lowCutoffHz: 0.5,
        highCutoffHz: 3.0,
        sampleRateHz: 50.0,
      );

      double maxPassAmp = 0.0;
      for (int i = 0; i < 150; i++) {
        final t = i * 0.02;
        final x = sin(2.0 * pi * 1.8 * t);
        final y = filter.process(x);
        if (i > 75 && y.abs() > maxPassAmp) maxPassAmp = y.abs();
      }
      expect(maxPassAmp, greaterThan(0.65));

      filter.reset();

      double maxRejectAmp = 0.0;
      for (int i = 0; i < 150; i++) {
        final t = i * 0.02;
        final x = sin(2.0 * pi * 15.0 * t);
        final y = filter.process(x);
        if (i > 75 && y.abs() > maxRejectAmp) maxRejectAmp = y.abs();
      }
      expect(maxRejectAmp, lessThan(0.20));
    });
  });

  group('3. Weinberg Step Length Estimation & Calibration', () {
    test('Estimates step length within physiological bounds (0.35m - 1.35m)', () {
      final estimator = StepLengthEstimator(
        config: const PdrConfig(),
        initialWeinbergK: 0.45,
      );

      final breakdown = StepConfidenceBreakdown(
        prominenceConfidence: 0.8,
        intervalConfidence: 0.8,
        amplitudeConfidence: 0.8,
        stabilityConfidence: 0.9,
        totalConfidence: 0.85,
        accepted: true,
      );

      final result = DetectedStepResult(
        timestamp: 1.0,
        stepInterval: 0.55,
        peakAcceleration: 2.8,
        valleyAcceleration: -1.2,
        prominence: 4.0,
        confidence: 0.85,
        breakdown: breakdown,
      );

      final length = estimator.estimateStepLength(stepResult: result);
      expect(length, greaterThanOrEqualTo(0.35));
      expect(length, lessThanOrEqualTo(1.35));
    });

    test('Calibration solves for personalized Weinberg K given 10m walk', () {
      final calManager = PdrCalibrationManager(knownDistanceMeters: 10.0);
      calManager.start(0.0);

      calManager.processStationarySample(timestamp: 3.1, headingDegrees: 45.0);
      expect(calManager.phase, equals(CalibrationPhase.walking));

      for (int i = 0; i < 14; i++) {
        final res = DetectedStepResult(
          timestamp: 3.5 + i * 0.55,
          stepInterval: 0.55,
          peakAcceleration: 2.5,
          valleyAcceleration: -1.0,
          prominence: 3.5,
          confidence: 0.9,
          breakdown: const StepConfidenceBreakdown(
            prominenceConfidence: 0.9,
            intervalConfidence: 0.9,
            amplitudeConfidence: 0.9,
            stabilityConfidence: 0.9,
            totalConfidence: 0.9,
            accepted: true,
          ),
        );
        calManager.registerCalibrationStep(res);
      }

      final result = calManager.finish();
      expect(result, isNotNull);
      expect(result!.stepCount, equals(14));
      expect(result.averageStepLength, closeTo(10.0 / 14.0, 0.01));
      expect(result.calibratedWeinbergK, greaterThan(0.30));
    });
  });

  group('4. Trajectory Simulation & PDR Scenarios', () {
    test('Scenario 1: Walking Straight North (10 steps)', () {
      final engine = PdrEngine();
      engine.start(initialHeading: 0.0);

      simulateWalkingMotion(
        engine: engine,
        stepsToGenerate: 10,
        stepFrequencyHz: 1.8,
        headingDegrees: 0.0,
        startTime: 1.0,
      );

      final state = engine.currentState;
      expect(state.stepCount, equals(10));
      expect(state.x, closeTo(0.0, 0.05));
      expect(state.y, greaterThan(5.0));
      expect(state.totalDistance, greaterThan(5.0));

      final positionError = sqrt(state.x * state.x + pow(state.y - (10 * 0.70), 2));
      expect(positionError, lessThan(2.0));
    });

    test('Scenario 2: Walking with 90° Turn (East then North)', () {
      final engine = PdrEngine();
      engine.start(initialHeading: 90.0);

      // Walk 6 steps East (heading 90°)
      final tEnd1 = simulateWalkingMotion(
        engine: engine,
        stepsToGenerate: 6,
        stepFrequencyHz: 1.8,
        headingDegrees: 90.0,
        startTime: 1.0,
      );

      final eastX = engine.currentState.x;
      expect(eastX, greaterThan(3.0));

      // Turn 90° and walk 6 steps North (heading 0°)
      simulateWalkingMotion(
        engine: engine,
        stepsToGenerate: 6,
        stepFrequencyHz: 1.8,
        headingDegrees: 0.0,
        startTime: tEnd1 + 0.1,
      );

      final state = engine.currentState;
      expect(state.stepCount, equals(12));
      expect(state.x, greaterThan(3.0));
      expect(state.y, greaterThan(3.0));
    });

    test('Scenario 3: Closed Square Path (Loop Closure & RMSE)', () {
      final engine = PdrEngine();
      engine.start(initialHeading: 0.0);

      const stepsPerSide = 8;
      double t = 1.0;

      // Side 1: North (0°)
      t = simulateWalkingMotion(engine: engine, stepsToGenerate: stepsPerSide, stepFrequencyHz: 1.8, headingDegrees: 0.0, startTime: t);
      // Side 2: East (90°)
      t = simulateWalkingMotion(engine: engine, stepsToGenerate: stepsPerSide, stepFrequencyHz: 1.8, headingDegrees: 90.0, startTime: t);
      // Side 3: South (180°)
      t = simulateWalkingMotion(engine: engine, stepsToGenerate: stepsPerSide, stepFrequencyHz: 1.8, headingDegrees: 180.0, startTime: t);
      // Side 4: West (270°)
      t = simulateWalkingMotion(engine: engine, stepsToGenerate: stepsPerSide, stepFrequencyHz: 1.8, headingDegrees: 270.0, startTime: t);

      final state = engine.currentState;
      expect(state.stepCount, equals(32));

      // Loop Closure Error: Distance from (0, 0)
      final loopClosureError = sqrt(state.x * state.x + state.y * state.y);
      expect(loopClosureError, lessThan(1.5));
    });

    test('Scenario 4: Stationary Test (Zero false steps generated)', () {
      final engine = PdrEngine();
      engine.start(initialHeading: 0.0);

      // Feed stationary flat acceleration (9.81 m/s² on Z, no variation)
      for (int i = 0; i < 200; i++) {
        final t = 1.0 + i * 0.02;
        final sample = SensorSample(
          timestamp: t,
          dt: 0.02,
          ax: 0.0,
          ay: 0.0,
          az: 9.80665,
          gx: 0.0,
          gy: 0.0,
          gz: 0.0,
        );
        engine.processSensorSample(sample: sample);
      }

      final state = engine.currentState;
      expect(state.stepCount, equals(0));
      expect(state.totalDistance, equals(0.0));
      expect(state.x, equals(0.0));
      expect(state.y, equals(0.0));
      expect(state.isStationary, isTrue);
    });

    test('Scenario 5: Phone Shaking Rejection (High frequency violent motion rejected)', () {
      final engine = PdrEngine();
      engine.start(initialHeading: 0.0);

      for (int i = 0; i < 150; i++) {
        final t = 1.0 + i * 0.02;
        final shakeAccel = 28.0 * sin(2.0 * pi * 8.0 * t);
        final sample = SensorSample(
          timestamp: t,
          dt: 0.02,
          ax: shakeAccel * 0.5,
          ay: shakeAccel * 0.5,
          az: 9.81 + shakeAccel,
          gx: 8.5 * sin(2.0 * pi * 8.0 * t),
          gy: 8.0 * cos(2.0 * pi * 8.0 * t),
          gz: 5.0,
        );
        engine.processSensorSample(sample: sample);
      }

      final state = engine.currentState;
      expect(state.stepCount, equals(0));
      expect(state.totalDistance, equals(0.0));
    });

    test('Scenario 6: External Position Correction Updates State Correctly', () {
      final engine = PdrEngine();
      engine.start();

      simulateWalkingMotion(
        engine: engine,
        stepsToGenerate: 5,
        stepFrequencyHz: 1.8,
        headingDegrees: 0.0,
        startTime: 1.0,
      );

      engine.correctPosition(correctedX: 2.0, correctedY: 5.0, confidence: 1.0);

      expect(engine.currentState.x, closeTo(2.0, 1e-5));
      expect(engine.currentState.y, closeTo(5.0, 1e-5));
    });
  });
}

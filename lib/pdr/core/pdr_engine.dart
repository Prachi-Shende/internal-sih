import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../calibration/pdr_calibration.dart';
import '../models/orientation_sample.dart';
import '../models/pdr_config.dart';
import '../models/pdr_state.dart';
import '../models/sensor_sample.dart';
import '../models/step_event.dart';
import '../orientation/heading_estimator.dart';
import '../processing/acceleration_processor.dart';
import '../sensors/sensor_manager.dart';
import '../step_detection/step_detector.dart';
import '../step_length/step_length_estimator.dart';
import '../utils/math_utils.dart';

/// Central Pedestrian Dead Reckoning (PDR) Engine.
///
/// Orchestrates the entire classical PDR pipeline from sensor ingestion,
/// orientation tracking, digital filtering, step detection, step length estimation,
/// coordinate updates (East-North-Up), stationary detection, to confidence estimation.
class PdrEngine {
  final PdrConfig config;

  late final SensorManager sensorManager;
  late final AccelerationProcessor _accelerationProcessor;
  late final StepDetector _stepDetector;
  late final HeadingEstimator _headingEstimator;
  late final StepLengthEstimator _stepLengthEstimator;
  late final PdrCalibrationManager _calibrationManager;

  StreamSubscription? _sensorSubscription;

  // State
  PdrState _currentState = PdrState.initial();
  PdrState get currentState => _currentState;

  // Reactive Streams
  final StreamController<PdrState> _stateController = StreamController<PdrState>.broadcast();
  Stream<PdrState> get stateStream => _stateController.stream;

  final StreamController<StepEvent> _stepController = StreamController<StepEvent>.broadcast();
  Stream<StepEvent> get stepStream => _stepController.stream;

  final StreamController<ProcessedAcceleration> _debugAccelController =
      StreamController<ProcessedAcceleration>.broadcast();
  Stream<ProcessedAcceleration> get debugAccelStream => _debugAccelController.stream;

  // Stationary detection state
  double _lastMotionTimestamp = 0.0;
  bool _isStationary = true;
  final MovingStatistics _shortTermSpeed = MovingStatistics(5);

  // Calibration state
  bool _isCalibrating = false;
  bool get isCalibrating => _isCalibrating;
  PdrCalibrationManager get calibrationManager => _calibrationManager;

  // Lifecycle
  bool _isStarted = false;
  bool _isPaused = false;
  bool get isRunning => _isStarted && !_isPaused;

  PdrEngine({PdrConfig? config}) : config = config ?? const PdrConfig() {
    sensorManager = SensorManager(config: this.config);
    _accelerationProcessor = AccelerationProcessor(config: this.config);
    _stepDetector = StepDetector(config: this.config);
    _headingEstimator = HeadingEstimator(config: this.config);
    _stepLengthEstimator = StepLengthEstimator(config: this.config);
    _calibrationManager = PdrCalibrationManager();
  }

  /// Starts the sensor streams and real-time PDR calculation.
  Future<void> start({double initialHeading = 0.0}) async {
    if (_isStarted) return;
    _isStarted = true;
    _isPaused = false;

    _headingEstimator.initialize(initialHeading);

    _sensorSubscription = sensorManager.sensorStream.listen(
      (packet) {
        if (!_isPaused) {
          processSensorSample(
            sample: packet.sample,
            orientation: packet.orientation,
          );
        }
      },
      onError: (dynamic error) {
        debugPrint('PdrEngine: sensor error: $error');
      },
    );

    await sensorManager.start();
  }

  /// Stops sensor acquisition and halts PDR updates.
  void stop() {
    _isStarted = false;
    _isPaused = false;
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    sensorManager.stop();
  }

  /// Pauses PDR calculations without releasing sensor listeners.
  void pause() {
    _isPaused = true;
  }

  /// Resumes PDR calculations.
  void resume() {
    _isPaused = false;
  }

  /// Resets the engine state, path trajectory, and all component filters.
  void reset({
    double initialX = 0.0,
    double initialY = 0.0,
    double initialHeadingDegrees = 0.0,
  }) {
    _accelerationProcessor.reset();
    _stepDetector.reset();
    _headingEstimator.reset(initialHeadingDegrees: initialHeadingDegrees);
    _stepLengthEstimator.reset();
    _calibrationManager.reset();
    _shortTermSpeed.clear();

    _lastMotionTimestamp = 0.0;
    _isStationary = true;
    _isCalibrating = false;

    final rad = initialHeadingDegrees * pi / 180.0;
    _currentState = PdrState(
      x: initialX,
      y: initialY,
      totalDistance: 0.0,
      stepCount: 0,
      currentStepLength: config.defaultStepLength,
      headingDegrees: initialHeadingDegrees,
      headingRadians: rad,
      velocity: 0.0,
      isStationary: true,
      isWalking: false,
      stepConfidence: 0.85,
      headingConfidence: 0.90,
      overallConfidence: 0.88,
      lastStepTimestamp: 0.0,
      timestamp: 0.0,
      trajectory: [Point2D(x: initialX, y: initialY, timestamp: 0.0, headingDegrees: initialHeadingDegrees)],
    );

    _emitState();
  }

  /// Ingests a single synchronized IMU sample through the full PDR pipeline.
  void processSensorSample({
    required SensorSample sample,
    OrientationSample? orientation,
  }) {
    if (!sample.isValid) return;

    final t = sample.timestamp;

    // 1. Orientation & Heading Estimation
    final currentOrientation = _headingEstimator.update(
      sample: sample,
      hardwareOrientation: orientation,
      isStationary: _isStationary,
    );

    // 2. Coordinate Transformation & Acceleration Filtering
    final processedAccel = _accelerationProcessor.process(
      sample: sample,
      orientation: currentOrientation,
    );

    if (!_debugAccelController.isClosed) {
      _debugAccelController.add(processedAccel);
    }

    // 3. Stationary Detection
    // Check if acceleration energy/variance is below stationary threshold
    final hasLowEnergy = processedAccel.accelerationVariance < config.stationaryVarianceThreshold;
    final hasRecentStep = _currentState.lastStepTimestamp > 0.0 &&
        (t - _currentState.lastStepTimestamp) < config.maxStepInterval;

    if (!hasLowEnergy || hasRecentStep) {
      _lastMotionTimestamp = t;
      _isStationary = false;
    } else {
      if (_lastMotionTimestamp == 0.0 || (t - _lastMotionTimestamp) >= config.stationaryDurationSeconds) {
        _isStationary = true;
      }
    }

    // Handle Calibration mode during Stage 1
    if (_isCalibrating && _calibrationManager.phase == CalibrationPhase.standingStill) {
      _calibrationManager.processStationarySample(
        timestamp: t,
        headingDegrees: currentOrientation.headingDegrees,
      );
    }

    // 4. Step Detection & Validation
    final stepResult = _stepDetector.process(
      processedAccel: processedAccel,
      rawSample: sample,
    );

    if (stepResult != null) {
      // Step Accepted!
      _handleAcceptedStep(
        stepResult: stepResult,
        headingDeg: currentOrientation.headingDegrees,
        timestamp: t,
      );
    } else {
      // Periodic state tick (keep heading and stationary status updated in UI)
      final timeSinceLastStep = _currentState.lastStepTimestamp > 0.0
          ? (t - _currentState.lastStepTimestamp)
          : 100.0;

      _currentState = _currentState.copyWith(
        headingDegrees: currentOrientation.headingDegrees,
        headingRadians: currentOrientation.headingRadians,
        isStationary: _isStationary,
        isWalking: !_isStationary && timeSinceLastStep < 1.5,
        velocity: _isStationary ? 0.0 : _shortTermSpeed.mean,
        timestamp: t,
        headingConfidence: _headingEstimator.confidence,
        overallConfidence: _calculateOverallConfidence(
          stepConf: _currentState.stepConfidence,
          headingConf: _headingEstimator.confidence,
        ),
      );
      _emitState();
    }
  }

  void _handleAcceptedStep({
    required DetectedStepResult stepResult,
    required double headingDeg,
    required double timestamp,
  }) {
    // 5. Step Length Estimation
    final stepLength = _stepLengthEstimator.estimateStepLength(stepResult: stepResult);

    // Register with calibration if active
    if (_isCalibrating && _calibrationManager.phase == CalibrationPhase.walking) {
      _calibrationManager.registerCalibrationStep(stepResult);
    }

    // 6. Navigation Coordinate Update (East-North-Up)
    // Convention:
    // x = East, y = North
    // heading = 0° (North), 90° (East), 180° (South), 270° (West)
    // dx = L * sin(heading)
    // dy = L * cos(heading)
    final headingRad = headingDeg * pi / 180.0;
    final dx = stepLength * sin(headingRad);
    final dy = stepLength * cos(headingRad);

    final newX = _currentState.x + dx;
    final newY = _currentState.y + dy;
    final newDist = _currentState.totalDistance + stepLength;
    final newCount = _currentState.stepCount + 1;

    // Instantaneous walking velocity (m/s)
    final instSpeed = stepResult.stepInterval > 0.05
        ? (stepLength / stepResult.stepInterval).clamp(0.2, 3.5)
        : 1.2;
    _shortTermSpeed.add(instSpeed);

    // Append to historical trajectory
    final newPoint = Point2D(
      x: newX,
      y: newY,
      timestamp: timestamp,
      headingDegrees: headingDeg,
    );
    final updatedTrajectory = List<Point2D>.from(_currentState.trajectory)..add(newPoint);

    final stepConfidence = stepResult.confidence;
    final overallConf = _calculateOverallConfidence(
      stepConf: stepConfidence,
      headingConf: _headingEstimator.confidence,
    );

    final stepEvent = StepEvent(
      stepIndex: newCount,
      timestamp: timestamp,
      stepLength: stepLength,
      headingDegrees: headingDeg,
      headingRadians: headingRad,
      dx: dx,
      dy: dy,
      x: newX,
      y: newY,
      confidence: stepConfidence,
      peakAcceleration: stepResult.peakAcceleration,
      valleyAcceleration: stepResult.valleyAcceleration,
      prominence: stepResult.prominence,
      stepDuration: stepResult.stepInterval,
    );

    _currentState = _currentState.copyWith(
      x: newX,
      y: newY,
      totalDistance: newDist,
      stepCount: newCount,
      currentStepLength: stepLength,
      headingDegrees: headingDeg,
      headingRadians: headingRad,
      velocity: _shortTermSpeed.mean,
      isStationary: false,
      isWalking: true,
      stepConfidence: stepConfidence,
      headingConfidence: _headingEstimator.confidence,
      overallConfidence: overallConf,
      lastStepTimestamp: timestamp,
      timestamp: timestamp,
      trajectory: updatedTrajectory,
    );

    if (!_stepController.isClosed) {
      _stepController.add(stepEvent);
    }
    _emitState();
  }

  /// External position correction injection (e.g. from GPS, Wi-Fi fingerprint, BLE beacon, Map match).
  void correctPosition({
    required double correctedX,
    required double correctedY,
    double confidence = 1.0,
  }) {
    final c = confidence.clamp(0.0, 1.0);
    final blendX = (1.0 - c) * _currentState.x + c * correctedX;
    final blendY = (1.0 - c) * _currentState.y + c * correctedY;

    final updatedTrajectory = List<Point2D>.from(_currentState.trajectory)
      ..add(Point2D(x: blendX, y: blendY, timestamp: _currentState.timestamp, headingDegrees: _currentState.headingDegrees));

    _currentState = _currentState.copyWith(
      x: blendX,
      y: blendY,
      overallConfidence: min(1.0, _currentState.overallConfidence + 0.15 * c),
      trajectory: updatedTrajectory,
    );
    _emitState();
  }

  /// Calibrates step length using a known walked distance and detected step count.
  void calibrateStepLength({required double knownDistance, required int steps}) {
    if (steps <= 0) return;
    final avgLength = knownDistance / steps;
    _stepLengthEstimator.setCalibratedStepLength(calibratedAverageLength: avgLength);
    _currentState = _currentState.copyWith(currentStepLength: _stepLengthEstimator.currentStepLength);
    _emitState();
  }

  /// Starts the guided calibration workflow.
  void startCalibrationFlow({double knownDistanceMeters = 10.0}) {
    _isCalibrating = true;
    _calibrationManager.start(_currentState.timestamp > 0.0 ? _currentState.timestamp : (DateTime.now().millisecondsSinceEpoch / 1000.0));
  }

  /// Concludes calibration and applies the newly calibrated Weinberg factor K.
  CalibrationResult? finishCalibrationFlow() {
    final result = _calibrationManager.finish();
    if (result != null) {
      _stepLengthEstimator.setWeinbergK(result.calibratedWeinbergK);
      _stepLengthEstimator.setCalibratedStepLength(calibratedAverageLength: result.averageStepLength);
      _currentState = _currentState.copyWith(currentStepLength: result.averageStepLength);
      _emitState();
    }
    _isCalibrating = false;
    return result;
  }

  double _calculateOverallConfidence({
    required double stepConf,
    required double headingConf,
  }) {
    // Distance-based drift decay (0.2% per 100m without correction)
    final distanceDecay = (1.0 - 0.002 * (_currentState.totalDistance / 100.0)).clamp(0.50, 1.0);
    return (0.45 * stepConf + 0.45 * headingConf + 0.10) * distanceDecay;
  }

  void _emitState() {
    if (!_stateController.isClosed) {
      _stateController.add(_currentState);
    }
  }

  void dispose() {
    stop();
    sensorManager.dispose();
    _stateController.close();
    _stepController.close();
    _debugAccelController.close();
  }
}

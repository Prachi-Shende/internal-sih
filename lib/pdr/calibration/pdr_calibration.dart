import 'dart:math';

import '../step_detection/step_detector.dart';

enum CalibrationPhase {
  idle,
  standingStill,
  walking,
  completed,
  failed,
}

/// Result payload upon completing the user calibration workflow.
class CalibrationResult {
  final double knownDistanceMeters;
  final int stepCount;
  final double averageStepLength;
  final double calibratedWeinbergK;
  final double averageCadenceHz;
  final double baselineHeadingDegrees;
  final double confidence;

  const CalibrationResult({
    required this.knownDistanceMeters,
    required this.stepCount,
    required this.averageStepLength,
    required this.calibratedWeinbergK,
    required this.averageCadenceHz,
    required this.baselineHeadingDegrees,
    required this.confidence,
  });

  @override
  String toString() {
    return 'CalibrationResult(distance=${knownDistanceMeters.toStringAsFixed(1)}m, '
        'steps=$stepCount, avgStep=${averageStepLength.toStringAsFixed(2)}m, '
        'K=${calibratedWeinbergK.toStringAsFixed(3)}, heading=${baselineHeadingDegrees.toStringAsFixed(1)}°)';
  }
}

/// Manages the guided 3-stage user calibration workflow for personalized stride length & heading.
class PdrCalibrationManager {
  final double knownDistanceMeters;

  CalibrationPhase _phase = CalibrationPhase.idle;
  CalibrationPhase get phase => _phase;

  int _calibrationSteps = 0;
  int get stepCount => _calibrationSteps;

  final List<double> _stepProminences = [];
  final List<double> _stepIntervals = [];
  final List<double> _stationaryHeadings = [];

  double _stationaryStartTime = 0.0;
  static const double requiredStationaryDurationSeconds = 3.0;

  CalibrationResult? _latestResult;
  CalibrationResult? get latestResult => _latestResult;

  PdrCalibrationManager({this.knownDistanceMeters = 10.0});

  /// Starts the calibration process with Stage 1 (Stand still).
  void start(double currentTimestamp) {
    _phase = CalibrationPhase.standingStill;
    _stationaryStartTime = currentTimestamp;
    _calibrationSteps = 0;
    _stepProminences.clear();
    _stepIntervals.clear();
    _stationaryHeadings.clear();
    _latestResult = null;
  }

  /// Processes stationary alignment samples during Stage 1.
  /// Returns `true` when Stage 1 completes and the user can start walking.
  bool processStationarySample({
    required double timestamp,
    required double headingDegrees,
  }) {
    if (_phase != CalibrationPhase.standingStill) return false;

    _stationaryHeadings.add(headingDegrees);

    final duration = timestamp - _stationaryStartTime;
    if (duration >= requiredStationaryDurationSeconds) {
      _phase = CalibrationPhase.walking;
      return true;
    }
    return false;
  }

  /// Registers a detected step during Stage 2 (Walking).
  void registerCalibrationStep(DetectedStepResult stepResult) {
    if (_phase != CalibrationPhase.walking) return;

    _calibrationSteps++;
    _stepProminences.add(stepResult.prominence);
    _stepIntervals.add(stepResult.stepInterval);
  }

  /// Concludes calibration after the user walks the specified distance.
  CalibrationResult? finish() {
    if (_calibrationSteps < 3) {
      _phase = CalibrationPhase.failed;
      return null;
    }

    final avgStepLength = (knownDistanceMeters / _calibrationSteps).clamp(0.35, 1.40);

    // Calculate average fourth root of prominence
    double sumPromFactor = 0.0;
    for (final p in _stepProminences) {
      sumPromFactor += pow(max(0.1, p), 0.25);
    }
    final avgPromFactor = _stepProminences.isNotEmpty
        ? sumPromFactor / _stepProminences.length
        : pow(2.0, 0.25).toDouble();

    final calibratedK = (avgStepLength / avgPromFactor).clamp(0.25, 0.85);

    // Calculate average cadence
    double avgInterval = 0.60;
    if (_stepIntervals.isNotEmpty) {
      final sumInt = _stepIntervals.reduce((a, b) => a + b);
      avgInterval = sumInt / _stepIntervals.length;
    }
    final avgCadenceHz = avgInterval > 0.05 ? 1.0 / avgInterval : 1.7;

    // Calculate baseline heading
    double baseHeading = 0.0;
    if (_stationaryHeadings.isNotEmpty) {
      double sSum = 0.0;
      double cSum = 0.0;
      for (final h in _stationaryHeadings) {
        final rad = h * pi / 180.0;
        sSum += sin(rad);
        cSum += cos(rad);
      }
      final meanRad = atan2(sSum, cSum);
      baseHeading = (meanRad * 180.0 / pi) % 360.0;
      if (baseHeading < 0) baseHeading += 360.0;
    }

    final result = CalibrationResult(
      knownDistanceMeters: knownDistanceMeters,
      stepCount: _calibrationSteps,
      averageStepLength: avgStepLength,
      calibratedWeinbergK: calibratedK,
      averageCadenceHz: avgCadenceHz,
      baselineHeadingDegrees: baseHeading,
      confidence: 0.95,
    );

    _latestResult = result;
    _phase = CalibrationPhase.completed;
    return result;
  }

  void reset() {
    _phase = CalibrationPhase.idle;
    _calibrationSteps = 0;
    _stepProminences.clear();
    _stepIntervals.clear();
    _stationaryHeadings.clear();
    _latestResult = null;
  }
}

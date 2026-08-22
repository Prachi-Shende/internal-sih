import 'dart:math';
import 'package:flutter/foundation.dart';

import 'pdr_path.dart';

class PdrEngine {
  // ============================================================
  // CONFIG
  // ============================================================

  double strideLength;

  final PdrPath path = PdrPath();

  static const double minStrideLength = 0.45;
  static const double maxStrideLength = 1.20;

  static const double minStepInterval = 0.25;
  static const double maxStepInterval = 2.00;

  // ============================================================
  // INTERNAL STATE
  // ============================================================

  int? _previousStepCount;

  DateTime? _lastStepTime;

  double _x = 0.0;
  double _y = 0.0;

  double _totalDistance = 0.0;
  int _totalSteps = 0;

  double? _lastHeading;

  double _headingSin = 0.0;
  double _headingCos = 1.0;

  double _confidence = 0.80;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  PdrEngine({this.strideLength = 0.70}) {
    _validateStrideLength();

    path.addPoint(0, 0);
  }

  // ============================================================
  // GETTERS
  // ============================================================

  double get x => _x;

  double get y => _y;

  double get totalDistance => _totalDistance;

  int get totalSteps => _totalSteps;

  double get confidence => _confidence;

  double? get lastHeading => _lastHeading;

  bool get isInitialized => _previousStepCount != null;

  // ============================================================
  // UPDATE
  // ============================================================

  int update({required int stepCount, required double headingDegrees}) {
    if (stepCount < 0) {
      return 0;
    }

    if (!headingDegrees.isFinite) {
      _confidence *= 0.98;
      return 0;
    }

    final heading = _normalizeHeading(headingDegrees);

    _updateHeading(heading);

    if (_previousStepCount == null) {
      _previousStepCount = stepCount;
      return 0;
    }

    final newSteps = stepCount - _previousStepCount!;

    if (newSteps < 0) {
      _previousStepCount = stepCount;
      return 0;
    }

    if (newSteps == 0) {
      return 0;
    }

    _previousStepCount = stepCount;

    for (int i = 0; i < newSteps; i++) {
      _acceptStep();
    }

    return newSteps;
  }

  // ============================================================
  // ACCEPT STEP
  // ============================================================

  void _acceptStep() {
    final now = DateTime.now();

    double stepConfidence = 1.0;

    if (_lastStepTime != null) {
      final interval = now.difference(_lastStepTime!).inMilliseconds / 1000.0;

      if (interval < minStepInterval) {
        stepConfidence *= 0.20;
      } else if (interval > maxStepInterval) {
        stepConfidence *= 0.50;
      } else {
        stepConfidence *= 1.0;
      }
    }

    _lastStepTime = now;

    _totalSteps++;

    final distance = strideLength;

    _totalDistance += distance;

    final headingRadians = (_lastHeading ?? 0.0) * pi / 180.0;

    final east = distance * sin(headingRadians);

    final north = distance * cos(headingRadians);

    _x += east;
    _y += north;

    path.addPoint(_x, _y);

    _confidence = (_confidence * 0.90) + (stepConfidence * 0.10);

    _confidence = _confidence.clamp(0.0, 1.0);

    debugPrint(
      'PDR STEP -> '
      'steps=$_totalSteps '
      'x=${_x.toStringAsFixed(2)} '
      'y=${_y.toStringAsFixed(2)} '
      'conf=${(_confidence * 100).toStringAsFixed(0)}%',
    );
  }

  // ============================================================
  // HEADING SMOOTHING
  // ============================================================

  void _updateHeading(double headingDegrees) {
    final radians = headingDegrees * pi / 180.0;

    const alpha = 0.20;

    _headingSin = _headingSin * (1 - alpha) + sin(radians) * alpha;

    _headingCos = _headingCos * (1 - alpha) + cos(radians) * alpha;

    final smoothed = atan2(_headingSin, _headingCos);

    double degrees = smoothed * 180.0 / pi;

    if (degrees < 0) {
      degrees += 360;
    }

    _lastHeading = degrees;
  }

  // ============================================================
  // CALIBRATION
  // ============================================================

  double calibrateStepLength({
    required double knownDistance,
    required int steps,
  }) {
    if (steps <= 0) {
      return strideLength;
    }

    final estimate = knownDistance / steps;

    final bounded = estimate.clamp(minStrideLength, maxStrideLength);

    strideLength = strideLength * 0.30 + bounded * 0.70;

    return strideLength;
  }

  // ============================================================
  // POSITION CORRECTION
  // ============================================================

  void correctPosition({
    required double correctedX,
    required double correctedY,
    double confidence = 1.0,
  }) {
    final c = confidence.clamp(0.0, 1.0);

    _x = _x * (1 - c) + correctedX * c;

    _y = _y * (1 - c) + correctedY * c;

    path.addPoint(_x, _y);
  }

  // ============================================================
  // RESET
  // ============================================================

  void reset() {
    _previousStepCount = null;

    _lastStepTime = null;

    _x = 0;
    _y = 0;

    _totalDistance = 0;

    _totalSteps = 0;

    _lastHeading = null;

    _headingSin = 0;
    _headingCos = 1;

    _confidence = 0.80;

    path.clear();

    path.addPoint(0, 0);
  }

  // ============================================================
  // HELPERS
  // ============================================================

  double _normalizeHeading(double heading) {
    double value = heading % 360;

    if (value < 0) {
      value += 360;
    }

    return value;
  }

  void _validateStrideLength() {
    if (strideLength < minStrideLength || strideLength > maxStrideLength) {
      throw ArgumentError('Invalid stride length');
    }
  }

  // ============================================================
  // DEBUG
  // ============================================================

  Map<String, dynamic> get debugState {
    return {
      'steps': _totalSteps,
      'distance': _totalDistance,
      'x': _x,
      'y': _y,
      'heading': _lastHeading,
      'confidence': _confidence,
      'pathPoints': path.points.length,
    };
  }
}

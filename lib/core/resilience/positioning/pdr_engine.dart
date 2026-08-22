import 'dart:math';
import 'pdr_path.dart';

class PdrEngine {
  // ============================================================
  // CONFIGURATION
  // ============================================================

  double strideLength;

  final PdrPath path = PdrPath();

  static const double minHeading = 0.0;
  static const double maxHeading = 360.0;

  // ============================================================
  // INTERNAL STATE
  // ============================================================

  int? _previousStepCount;

  double _x = 0.0;
  double _y = 0.0;

  double _totalDistance = 0.0;

  int _totalSteps = 0;

  double? _lastHeading;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  PdrEngine({this.strideLength = 0.70}) {
    if (strideLength <= 0) {
      throw ArgumentError('strideLength must be greater than zero.');
    }

    // Starting position
    path.addPoint(0, 0);
  }

  // ============================================================
  // GETTERS
  // ============================================================

  double get x => _x;

  double get y => _y;

  double get totalDistance => _totalDistance;

  int get totalSteps => _totalSteps;

  double? get lastHeading => _lastHeading;

  bool get isInitialized => _previousStepCount != null;

  // ============================================================
  // STEP UPDATE
  // ============================================================

  int update({required int stepCount, required double headingDegrees}) {
    if (stepCount < 0) {
      return 0;
    }

    final heading = _normalizeHeading(headingDegrees);

    _lastHeading = heading;

    if (_previousStepCount == null) {
      _previousStepCount = stepCount;
      return 0;
    }

    int newSteps = stepCount - _previousStepCount!;

    if (newSteps < 0) {
      _previousStepCount = stepCount;
      return 0;
    }

    if (newSteps == 0) {
      return 0;
    }

    _previousStepCount = stepCount;

    _totalSteps += newSteps;

    final distance = newSteps * strideLength;

    _totalDistance += distance;

    _updatePosition(distance: distance, headingDegrees: heading);

    return newSteps;
  }

  // ============================================================
  // POSITION UPDATE
  // ============================================================

  void _updatePosition({
    required double distance,
    required double headingDegrees,
  }) {
    final headingRadians = headingDegrees * pi / 180.0;

    final eastDisplacement = distance * sin(headingRadians);

    final northDisplacement = distance * cos(headingRadians);

    _x += eastDisplacement;
    _y += northDisplacement;

    // ----------------------------------------------------------
    // STORE PATH POINT
    // ----------------------------------------------------------

    path.addPoint(_x, _y);
  }

  // ============================================================
  // HEADING NORMALIZATION
  // ============================================================

  double _normalizeHeading(double heading) {
    var normalized = heading % 360.0;

    if (normalized < 0) {
      normalized += 360.0;
    }

    return normalized;
  }

  // ============================================================
  // RESET
  // ============================================================

  void reset() {
    _previousStepCount = null;

    _x = 0.0;
    _y = 0.0;

    _totalDistance = 0.0;

    _totalSteps = 0;

    _lastHeading = null;

    path.clear();

    path.addPoint(0, 0);
  }

  // ============================================================
  // STRIDE UPDATE
  // ============================================================

  void setStrideLength(double newStrideLength) {
    if (newStrideLength <= 0) {
      throw ArgumentError('strideLength must be greater than zero.');
    }

    strideLength = newStrideLength;
  }

  // ============================================================
  // DEBUG SUMMARY
  // ============================================================

  Map<String, dynamic> get debugState {
    return {
      'initialized': isInitialized,
      'steps': _totalSteps,
      'distanceMeters': _totalDistance,
      'xEastMeters': _x,
      'yNorthMeters': _y,
      'headingDegrees': _lastHeading,
      'strideLengthMeters': strideLength,
      'pathPoints': path.points.length,
    };
  }
}

import 'dart:math';

import '../models/orientation_sample.dart';
import '../models/pdr_config.dart';
import '../models/sensor_sample.dart';
import '../utils/math_utils.dart';
import 'ahrs_fusion.dart';

/// Estimates and smooths the device's navigation heading in the world frame.
///
/// Coordinate Convention:
/// - 0°   = True North
/// - 90°  = East
/// - 180° = South
/// - 270° = West
/// Heading increases clockwise in degrees [0, 360).
class HeadingEstimator {
  final PdrConfig config;
  final AhrsFusion _fallbackAhrs = AhrsFusion();

  double _currentHeadingDegrees = 0.0;
  double _headingConfidence = 0.90;
  bool _isInitialized = false;

  // Circular smoothing filter state
  double _sinSmoothed = 0.0;
  double _cosSmoothed = 1.0;

  // Offset angle (to calibrate or align with known initial map heading)
  double _headingOffsetDegrees = 0.0;

  HeadingEstimator({required this.config, double initialHeadingDegrees = 0.0}) {
    initialize(initialHeadingDegrees);
  }

  /// Explicit initialization of heading state.
  void initialize(double initialHeadingDegrees) {
    _headingOffsetDegrees = 0.0;
    _currentHeadingDegrees = MathUtils.normalizeDegrees(initialHeadingDegrees);
    final rad = _currentHeadingDegrees * pi / 180.0;
    _sinSmoothed = sin(rad);
    _cosSmoothed = cos(rad);
    _isInitialized = true;
    _fallbackAhrs.reset(initialHeadingDeg: _currentHeadingDegrees);
  }

  /// Sets an explicit heading offset (e.g. from user alignment or compass benchmark).
  void setHeadingOffset(double offsetDegrees) {
    _headingOffsetDegrees = offsetDegrees;
  }

  /// Returns the current smoothed heading in degrees [0, 360).
  double get currentHeadingDegrees => _currentHeadingDegrees;

  /// Returns the current smoothed heading in radians [0, 2π).
  double get currentHeadingRadians => _currentHeadingDegrees * pi / 180.0;

  /// Returns the heading confidence score [0.0, 1.0].
  double get confidence => _headingConfidence;

  bool get isInitialized => _isInitialized;

  /// Updates the heading estimation given raw IMU sample and optional rotation vector sample.
  OrientationSample update({
    required SensorSample sample,
    OrientationSample? hardwareOrientation,
    bool isStationary = false,
  }) {
    OrientationSample effectiveOrientation;

    if (hardwareOrientation != null && hardwareOrientation.confidence > 0.3) {
      effectiveOrientation = hardwareOrientation;
      _headingConfidence = hardwareOrientation.confidence;
    } else {
      // Use internal AHRS fallback
      effectiveOrientation = _fallbackAhrs.update(sample);
      _headingConfidence = 0.75; // slightly lower confidence without hardware fusion
    }

    if (!_isInitialized) {
      initialize(effectiveOrientation.headingDegrees);
    }

    // If device is strictly stationary, freeze heading updates to eliminate gyro integration drift
    if (isStationary) {
      return OrientationSample(
        timestamp: sample.timestamp,
        qx: effectiveOrientation.qx,
        qy: effectiveOrientation.qy,
        qz: effectiveOrientation.qz,
        qw: effectiveOrientation.qw,
        headingRadians: currentHeadingRadians,
        headingDegrees: currentHeadingDegrees,
        pitch: effectiveOrientation.pitch,
        roll: effectiveOrientation.roll,
        isGameRotation: effectiveOrientation.isGameRotation,
        confidence: _headingConfidence,
      );
    }

    // Apply offset
    final rawTargetDeg = MathUtils.normalizeDegrees(
      effectiveOrientation.headingDegrees + _headingOffsetDegrees,
    );

    // Circular exponential smoothing using sin and cos components
    final targetRad = rawTargetDeg * pi / 180.0;
    final targetSin = sin(targetRad);
    final targetCos = cos(targetRad);

    final alpha = config.headingSmoothingAlpha.clamp(0.05, 0.95);

    _sinSmoothed = (1.0 - alpha) * _sinSmoothed + alpha * targetSin;
    _cosSmoothed = (1.0 - alpha) * _cosSmoothed + alpha * targetCos;

    final smoothedRad = atan2(_sinSmoothed, _cosSmoothed);
    _currentHeadingDegrees = MathUtils.normalizeDegrees(smoothedRad * 180.0 / pi);

    return OrientationSample(
      timestamp: sample.timestamp,
      qx: effectiveOrientation.qx,
      qy: effectiveOrientation.qy,
      qz: effectiveOrientation.qz,
      qw: effectiveOrientation.qw,
      headingRadians: currentHeadingRadians,
      headingDegrees: _currentHeadingDegrees,
      pitch: effectiveOrientation.pitch,
      roll: effectiveOrientation.roll,
      isGameRotation: effectiveOrientation.isGameRotation,
      confidence: _headingConfidence,
    );
  }

  void reset({double initialHeadingDegrees = 0.0}) {
    initialize(initialHeadingDegrees);
  }
}

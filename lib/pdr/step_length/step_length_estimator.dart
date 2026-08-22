import 'dart:math';

import '../models/pdr_config.dart';
import '../step_detection/step_detector.dart';
import '../utils/math_utils.dart';

/// Estimates dynamic step length based on the empirical Weinberg biomechanical model
/// with personalized calibration factors and smoothing.
class StepLengthEstimator {
  final PdrConfig config;

  /// User calibration factor K in: L = K * (Amax - Amin)^0.25.
  double weinbergFactorK;

  /// Running estimated step length in meters.
  double _currentStepLength;

  /// History of recent step lengths.
  final MovingStatistics _recentLengths = MovingStatistics(10);

  StepLengthEstimator({
    required this.config,
    double? initialWeinbergK,
    double? initialStepLength,
  })  : weinbergFactorK = initialWeinbergK ?? config.weinbergFactorK,
        _currentStepLength = initialStepLength ?? config.defaultStepLength;

  double get currentStepLength => _currentStepLength;

  /// Computes the step length for a validated detected step using the Weinberg empirical model.
  double estimateStepLength({
    required DetectedStepResult stepResult,
  }) {
    // 1. Weinberg model: L = K * (Amax - Amin)^0.25
    final deltaAccel = max(0.01, stepResult.prominence);
    final rawWeinbergLength = weinbergFactorK * pow(deltaAccel, 0.25);

    // 2. Frequency / cadence adjustment factor
    // Faster cadence (> 2 Hz, interval < 0.5s) tends to yield slightly longer strides
    double cadenceFactor = 1.0;
    if (stepResult.stepInterval > 0.1 && stepResult.stepInterval < 2.0) {
      final cadenceHz = 1.0 / stepResult.stepInterval;
      cadenceFactor = (0.85 + 0.10 * cadenceHz).clamp(0.85, 1.25);
    }

    final rawEstimate = rawWeinbergLength * cadenceFactor;

    // 3. Enforce physiological bounds
    final boundedEstimate = rawEstimate.clamp(
      config.minStepLength,
      config.maxStepLength,
    );

    // 4. Exponential Moving Average Smoothing
    final alpha = config.stepLengthSmoothingAlpha.clamp(0.05, 1.0);
    _currentStepLength = alpha * boundedEstimate + (1.0 - alpha) * _currentStepLength;
    _currentStepLength = _currentStepLength.clamp(config.minStepLength, config.maxStepLength);

    _recentLengths.add(_currentStepLength);

    return _currentStepLength;
  }

  /// Sets a personalized calibrated step length and solves for the corresponding Weinberg factor K.
  void setCalibratedStepLength({
    required double calibratedAverageLength,
    double typicalStepProminence = 2.0,
  }) {
    final clampedLength = calibratedAverageLength.clamp(
      config.minStepLength,
      config.maxStepLength,
    );
    _currentStepLength = clampedLength;

    // Solve for K: K = L / (prominence)^0.25
    final pFactor = pow(max(0.1, typicalStepProminence), 0.25);
    weinbergFactorK = (clampedLength / pFactor).clamp(0.20, 0.90);
  }

  /// Sets a personalized Weinberg calibration factor K directly.
  void setWeinbergK(double k) {
    weinbergFactorK = k.clamp(0.20, 0.90);
  }

  void reset() {
    _currentStepLength = config.defaultStepLength;
    _recentLengths.clear();
  }
}

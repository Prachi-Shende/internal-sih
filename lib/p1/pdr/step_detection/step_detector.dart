import '../models/pdr_config.dart';
import '../models/sensor_sample.dart';
import '../processing/acceleration_processor.dart';
import '../utils/math_utils.dart';
import 'peak_candidate.dart';

/// Detailed breakdown of confidence metrics for an evaluated candidate step.
class StepConfidenceBreakdown {
  final double prominenceConfidence;
  final double intervalConfidence;
  final double amplitudeConfidence;
  final double stabilityConfidence;
  final double totalConfidence;
  final bool accepted;
  final String rejectionReason;

  const StepConfidenceBreakdown({
    required this.prominenceConfidence,
    required this.intervalConfidence,
    required this.amplitudeConfidence,
    required this.stabilityConfidence,
    required this.totalConfidence,
    required this.accepted,
    this.rejectionReason = '',
  });

  @override
  String toString() {
    return 'Confidence(total=${(totalConfidence * 100).toStringAsFixed(0)}%, '
        'prom=${(prominenceConfidence * 100).toStringAsFixed(0)}%, '
        'int=${(intervalConfidence * 100).toStringAsFixed(0)}%, '
        'amp=${(amplitudeConfidence * 100).toStringAsFixed(0)}%, '
        'stab=${(stabilityConfidence * 100).toStringAsFixed(0)}%, '
        'accepted=$accepted${rejectionReason.isNotEmpty ? ", reason: $rejectionReason" : ""})';
  }
}

/// Output payload from the StepDetector upon detecting a candidate/accepted step.
class DetectedStepResult {
  final double timestamp;
  final double stepInterval;
  final double peakAcceleration;
  final double valleyAcceleration;
  final double prominence;
  final double confidence;
  final StepConfidenceBreakdown breakdown;

  const DetectedStepResult({
    required this.timestamp,
    required this.stepInterval,
    required this.peakAcceleration,
    required this.valleyAcceleration,
    required this.prominence,
    required this.confidence,
    required this.breakdown,
  });
}

/// Classical robust peak-valley step detector with adaptive thresholding,
/// refractory period lockout, rhythm validation, and false-motion rejection.
class StepDetector {
  final PdrConfig config;

  // Signal state tracking (3-point sliding window for peak/valley detection)
  double _xPrev2 = 0.0;
  double _xPrev1 = 0.0;
  double _tPrev1 = 0.0;

  // Track the most recent valley (trough)
  double _currentValleyValue = 0.0;
  double _currentValleyTime = 0.0;
  bool _seekingPeak = true;

  // Timing
  double? _lastAcceptedStepTimestamp;
  final MovingStatistics _recentIntervals = MovingStatistics(8);
  final MovingStatistics _signalEnergy = MovingStatistics(50); // ~1s window

  // Dynamic adaptive threshold
  double _adaptiveThreshold = 1.0;

  // Total accepted steps
  int stepCount = 0;

  // Last evaluated breakdown (for debug inspection)
  StepConfidenceBreakdown? latestBreakdown;

  StepDetector({required this.config}) {
    _adaptiveThreshold = config.minPeakThreshold;
  }

  /// Processes a single acceleration sample and checks for step occurrence.
  /// Returns [DetectedStepResult] if a validated step is accepted, otherwise `null`.
  DetectedStepResult? process({
    required ProcessedAcceleration processedAccel,
    required SensorSample rawSample,
  }) {
    final t = processedAccel.timestamp;
    // Prefer filtered vertical acceleration; fallback to filtered magnitude
    final signal = processedAccel.filteredVerticalAcceleration.abs() > 0.05
        ? processedAccel.filteredVerticalAcceleration
        : processedAccel.filteredMagnitude;

    _signalEnergy.add(signal);

    // Dynamic threshold estimation based on recent signal standard deviation
    final signalStd = _signalEnergy.standardDeviation;
    final targetThreshold = (config.minPeakThreshold + 0.8 * signalStd).clamp(
      config.minPeakThreshold,
      config.maxPeakThreshold,
    );
    _adaptiveThreshold = (1.0 - config.adaptiveThresholdAlpha) * _adaptiveThreshold +
        config.adaptiveThresholdAlpha * targetThreshold;

    DetectedStepResult? result;

    // Check for local extremum in sliding 3-sample window: (xPrev2, xPrev1, signal)
    if (_tPrev1 > 0.0) {
      final isLocalPeak = (_xPrev1 > _xPrev2) && (_xPrev1 >= signal);
      final isLocalValley = (_xPrev1 < _xPrev2) && (_xPrev1 <= signal);

      if (isLocalValley) {
        _currentValleyValue = _xPrev1;
        _currentValleyTime = _tPrev1;
        _seekingPeak = true;
      }

      if (isLocalPeak && _seekingPeak) {
        final peakValue = _xPrev1;
        final peakTime = _tPrev1;

        final candidate = PeakCandidate(
          timestamp: peakTime,
          peakValue: peakValue,
          precedingValleyValue: _currentValleyValue,
          precedingValleyTime: _currentValleyTime,
        );

        // Evaluate candidate peak
        result = _evaluateCandidatePeak(
          candidate: candidate,
          rawSample: rawSample,
          processedAccel: processedAccel,
        );

        if (result != null) {
          _seekingPeak = false; // Require a new valley before next peak
        }
      }
    }

    // Shift window
    _xPrev2 = _xPrev1;
    _xPrev1 = signal;
    _tPrev1 = t;

    return result;
  }

  DetectedStepResult? _evaluateCandidatePeak({
    required PeakCandidate candidate,
    required SensorSample rawSample,
    required ProcessedAcceleration processedAccel,
  }) {
    final t = candidate.timestamp;
    final peakVal = candidate.peakValue;
    final valleyVal = candidate.precedingValleyValue;
    final prominence = candidate.prominence;

    // 1. Refractory Period Check
    if (_lastAcceptedStepTimestamp != null) {
      final dtSinceLast = t - _lastAcceptedStepTimestamp!;
      if (dtSinceLast < config.refractoryPeriodSeconds) {
        latestBreakdown = StepConfidenceBreakdown(
          prominenceConfidence: 0.0,
          intervalConfidence: 0.0,
          amplitudeConfidence: 0.0,
          stabilityConfidence: 0.0,
          totalConfidence: 0.0,
          accepted: false,
          rejectionReason: 'Refractory lockout (${dtSinceLast.toStringAsFixed(2)}s < ${config.refractoryPeriodSeconds}s)',
        );
        return null;
      }
    }

    // 2. Shaking / High Violence Rejection
    if (rawSample.accelerationMagnitude > config.shakingAccelerationThreshold ||
        rawSample.gyroMagnitude > config.shakingGyroThreshold) {
      latestBreakdown = StepConfidenceBreakdown(
        prominenceConfidence: 0.0,
        intervalConfidence: 0.0,
        amplitudeConfidence: 0.0,
        stabilityConfidence: 0.0,
        totalConfidence: 0.0,
        accepted: false,
        rejectionReason: 'Severe shaking detected (acc=${rawSample.accelerationMagnitude.toStringAsFixed(1)}, gyro=${rawSample.gyroMagnitude.toStringAsFixed(1)})',
      );
      return null;
    }

    // 3. Minimum Amplitude & Prominence Checks
    if (peakVal < _adaptiveThreshold) {
      latestBreakdown = StepConfidenceBreakdown(
        prominenceConfidence: 0.1,
        intervalConfidence: 0.5,
        amplitudeConfidence: 0.1,
        stabilityConfidence: 0.8,
        totalConfidence: 0.2,
        accepted: false,
        rejectionReason: 'Peak amplitude below adaptive threshold (${peakVal.toStringAsFixed(2)} < ${_adaptiveThreshold.toStringAsFixed(2)})',
      );
      return null;
    }

    if (prominence < config.minPeakProminence) {
      latestBreakdown = StepConfidenceBreakdown(
        prominenceConfidence: 0.2,
        intervalConfidence: 0.5,
        amplitudeConfidence: 0.3,
        stabilityConfidence: 0.8,
        totalConfidence: 0.3,
        accepted: false,
        rejectionReason: 'Peak prominence too low (${prominence.toStringAsFixed(2)} < ${config.minPeakProminence} m/s²)',
      );
      return null;
    }

    // 4. Time Interval & Gait Consistency
    double stepInterval = 0.60; // default for first step
    double intervalConfidence = 0.85;

    if (_lastAcceptedStepTimestamp != null) {
      stepInterval = t - _lastAcceptedStepTimestamp!;

      if (stepInterval < config.minStepInterval) {
        latestBreakdown = StepConfidenceBreakdown(
          prominenceConfidence: 0.5,
          intervalConfidence: 0.1,
          amplitudeConfidence: 0.5,
          stabilityConfidence: 0.5,
          totalConfidence: 0.2,
          accepted: false,
          rejectionReason: 'Step interval too fast (${stepInterval.toStringAsFixed(2)}s < ${config.minStepInterval}s)',
        );
        return null;
      }

      if (stepInterval > config.maxStepInterval) {
        // Long gap - treat as isolated new step after pause
        intervalConfidence = 0.60;
      } else {
        // Compare with recent walking rhythm
        if (_recentIntervals.length >= 2) {
          final avgInterval = _recentIntervals.mean;
          final intervalRatio = (stepInterval / avgInterval - 1.0).abs();
          intervalConfidence = (1.0 - intervalRatio).clamp(0.2, 1.0);
        } else {
          intervalConfidence = 0.90;
        }
      }
    }

    // 5. Confidence Score Synthesis
    // Prominence factor: normalized between minProminence and ~3.5 m/s²
    final promConf = ((prominence - config.minPeakProminence) / 2.0).clamp(0.0, 1.0);

    // Amplitude factor: penalize very tiny or excessively violent peaks
    final ampConf = (1.0 - (peakVal - 2.0).abs() / 4.0).clamp(0.3, 1.0);

    // Angular stability factor: penalize violent rotational swings
    final stabConf = (1.0 - (rawSample.gyroMagnitude / config.shakingGyroThreshold)).clamp(0.1, 1.0);

    // Weighted composite confidence
    final totalConfidence = (0.35 * promConf +
            0.30 * intervalConfidence +
            0.20 * ampConf +
            0.15 * stabConf)
        .clamp(0.0, 1.0);

    final accepted = totalConfidence >= config.stepAcceptanceConfidenceThreshold;

    final breakdown = StepConfidenceBreakdown(
      prominenceConfidence: promConf,
      intervalConfidence: intervalConfidence,
      amplitudeConfidence: ampConf,
      stabilityConfidence: stabConf,
      totalConfidence: totalConfidence,
      accepted: accepted,
      rejectionReason: accepted ? '' : 'Confidence below threshold (${totalConfidence.toStringAsFixed(2)} < ${config.stepAcceptanceConfidenceThreshold})',
    );

    latestBreakdown = breakdown;

    if (!accepted) return null;

    // Accept step!
    stepCount++;
    _lastAcceptedStepTimestamp = t;
    _recentIntervals.add(stepInterval);

    return DetectedStepResult(
      timestamp: t,
      stepInterval: stepInterval,
      peakAcceleration: peakVal,
      valleyAcceleration: valleyVal,
      prominence: prominence,
      confidence: totalConfidence,
      breakdown: breakdown,
    );
  }

  void reset() {
    _xPrev2 = 0.0;
    _xPrev1 = 0.0;
    _tPrev1 = 0.0;
    _currentValleyValue = 0.0;
    _currentValleyTime = 0.0;
    _seekingPeak = true;
    _lastAcceptedStepTimestamp = null;
    _recentIntervals.clear();
    _signalEnergy.clear();
    _adaptiveThreshold = config.minPeakThreshold;
    stepCount = 0;
    latestBreakdown = null;
  }
}

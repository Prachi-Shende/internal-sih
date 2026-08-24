/// Master configuration model for all components of the classical PDR engine.
class PdrConfig {
  /// Target sensor sampling frequency in Hz (typically 50-100 Hz).
  final double samplingRateHz;

  // --- Filtering Parameters ---
  /// Bandpass lower cutoff frequency in Hz for human gait isolation.
  final double filterLowCutoffHz;

  /// Bandpass upper cutoff frequency in Hz for human gait isolation.
  final double filterHighCutoffHz;

  // --- Step Detection Parameters ---
  /// Minimum time interval in seconds between consecutive valid steps (~3.5 Hz max cadence).
  final double minStepInterval;

  /// Maximum time interval in seconds before considering the user stationary (~0.45 Hz min cadence).
  final double maxStepInterval;

  /// Minimum vertical/magnitude acceleration peak threshold (m/s²).
  final double minPeakThreshold;

  /// Maximum acceleration peak threshold (m/s²); peaks above this are likely drops/shakes.
  final double maxPeakThreshold;

  /// Minimum peak-to-valley prominence required to qualify as a valid step (m/s²).
  final double minPeakProminence;

  /// Adaptation rate for dynamic peak threshold (0.0 to 1.0).
  final double adaptiveThresholdAlpha;

  /// Refractory lockout period in seconds after an accepted step before new peak searching.
  final double refractoryPeriodSeconds;

  // --- Step Length Parameters ---
  /// Baseline Weinberg model calibration factor (L = K * (Amax - Amin)^0.25).
  final double weinbergFactorK;

  /// Minimum physiological step length boundary (meters).
  final double minStepLength;

  /// Maximum physiological step length boundary (meters).
  final double maxStepLength;

  /// Fallback baseline step length in meters.
  final double defaultStepLength;

  /// Exponential moving average smoothing factor for step length estimation.
  final double stepLengthSmoothingAlpha;

  // --- Heading Parameters ---
  /// Circular exponential smoothing factor for heading angle (0.05 to 0.40).
  final double headingSmoothingAlpha;

  /// Gyroscope fusion weight when blending gyro integration with rotation vector.
  final double gyroFusionWeight;

  // --- Stationary & Shaking Rejection ---
  /// Acceleration variance threshold (m²/s⁴) below which the phone is classified as stationary.
  final double stationaryVarianceThreshold;

  /// Time in seconds of low movement energy required to enter stationary state.
  final double stationaryDurationSeconds;

  /// Maximum acceleration magnitude threshold (m/s²) indicating severe phone shaking / drops.
  final double shakingAccelerationThreshold;

  /// Maximum angular velocity magnitude threshold (rad/s) indicating shaking / violent rotation.
  final double shakingGyroThreshold;

  // --- Validation Thresholds ---
  /// Minimum composite step confidence [0.0, 1.0] required to accept a step.
  final double stepAcceptanceConfidenceThreshold;

  const PdrConfig({
    this.samplingRateHz = 50.0,
    this.filterLowCutoffHz = 0.5,
    this.filterHighCutoffHz = 3.0,
    this.minStepInterval = 0.28,
    this.maxStepInterval = 2.20,
    this.minPeakThreshold = 0.70,
    this.maxPeakThreshold = 4.50,
    this.minPeakProminence = 0.85,
    this.adaptiveThresholdAlpha = 0.15,
    this.refractoryPeriodSeconds = 0.25,
    this.weinbergFactorK = 0.45,
    this.minStepLength = 0.35,
    this.maxStepLength = 1.35,
    this.defaultStepLength = 0.70,
    this.stepLengthSmoothingAlpha = 0.30,
    this.headingSmoothingAlpha = 0.25,
    this.gyroFusionWeight = 0.05,
    this.stationaryVarianceThreshold = 0.20,
    this.stationaryDurationSeconds = 1.2,
    this.shakingAccelerationThreshold = 25.0,
    this.shakingGyroThreshold = 7.0,
    this.stepAcceptanceConfidenceThreshold = 0.45,
  });

  PdrConfig copyWith({
    double? samplingRateHz,
    double? filterLowCutoffHz,
    double? filterHighCutoffHz,
    double? minStepInterval,
    double? maxStepInterval,
    double? minPeakThreshold,
    double? maxPeakThreshold,
    double? minPeakProminence,
    double? adaptiveThresholdAlpha,
    double? refractoryPeriodSeconds,
    double? weinbergFactorK,
    double? minStepLength,
    double? maxStepLength,
    double? defaultStepLength,
    double? stepLengthSmoothingAlpha,
    double? headingSmoothingAlpha,
    double? gyroFusionWeight,
    double? stationaryVarianceThreshold,
    double? stationaryDurationSeconds,
    double? shakingAccelerationThreshold,
    double? shakingGyroThreshold,
    double? stepAcceptanceConfidenceThreshold,
  }) {
    return PdrConfig(
      samplingRateHz: samplingRateHz ?? this.samplingRateHz,
      filterLowCutoffHz: filterLowCutoffHz ?? this.filterLowCutoffHz,
      filterHighCutoffHz: filterHighCutoffHz ?? this.filterHighCutoffHz,
      minStepInterval: minStepInterval ?? this.minStepInterval,
      maxStepInterval: maxStepInterval ?? this.maxStepInterval,
      minPeakThreshold: minPeakThreshold ?? this.minPeakThreshold,
      maxPeakThreshold: maxPeakThreshold ?? this.maxPeakThreshold,
      minPeakProminence: minPeakProminence ?? this.minPeakProminence,
      adaptiveThresholdAlpha: adaptiveThresholdAlpha ?? this.adaptiveThresholdAlpha,
      refractoryPeriodSeconds: refractoryPeriodSeconds ?? this.refractoryPeriodSeconds,
      weinbergFactorK: weinbergFactorK ?? this.weinbergFactorK,
      minStepLength: minStepLength ?? this.minStepLength,
      maxStepLength: maxStepLength ?? this.maxStepLength,
      defaultStepLength: defaultStepLength ?? this.defaultStepLength,
      stepLengthSmoothingAlpha: stepLengthSmoothingAlpha ?? this.stepLengthSmoothingAlpha,
      headingSmoothingAlpha: headingSmoothingAlpha ?? this.headingSmoothingAlpha,
      gyroFusionWeight: gyroFusionWeight ?? this.gyroFusionWeight,
      stationaryVarianceThreshold: stationaryVarianceThreshold ?? this.stationaryVarianceThreshold,
      stationaryDurationSeconds: stationaryDurationSeconds ?? this.stationaryDurationSeconds,
      shakingAccelerationThreshold: shakingAccelerationThreshold ?? this.shakingAccelerationThreshold,
      shakingGyroThreshold: shakingGyroThreshold ?? this.shakingGyroThreshold,
      stepAcceptanceConfidenceThreshold: stepAcceptanceConfidenceThreshold ?? this.stepAcceptanceConfidenceThreshold,
    );
  }
}

import 'dart:math';

/// A stateful 2nd-order IIR Biquad Filter implemented in Direct Form II Transposed structure.
class BiquadFilter {
  // Filter coefficients
  double b0 = 1.0;
  double b1 = 0.0;
  double b2 = 0.0;
  double a1 = 0.0;
  double a2 = 0.0;

  // State variables for Direct Form II Transposed
  double _s1 = 0.0;
  double _s2 = 0.0;

  BiquadFilter();

  /// Configures this biquad as a 2nd-order Butterworth Low-Pass Filter.
  void setLowPass({required double sampleRate, required double cutoffHz, double q = 0.7071}) {
    if (cutoffHz <= 0.0 || sampleRate <= 0.0 || cutoffHz >= sampleRate / 2.0) return;

    final omega = 2.0 * pi * cutoffHz / sampleRate;
    final alpha = sin(omega) / (2.0 * q);
    final cosw = cos(omega);

    final a0 = 1.0 + alpha;
    b0 = ((1.0 - cosw) / 2.0) / a0;
    b1 = (1.0 - cosw) / a0;
    b2 = ((1.0 - cosw) / 2.0) / a0;
    a1 = (-2.0 * cosw) / a0;
    a2 = (1.0 - alpha) / a0;
  }

  /// Configures this biquad as a 2nd-order Butterworth High-Pass Filter.
  void setHighPass({required double sampleRate, required double cutoffHz, double q = 0.7071}) {
    if (cutoffHz <= 0.0 || sampleRate <= 0.0 || cutoffHz >= sampleRate / 2.0) return;

    final omega = 2.0 * pi * cutoffHz / sampleRate;
    final alpha = sin(omega) / (2.0 * q);
    final cosw = cos(omega);

    final a0 = 1.0 + alpha;
    b0 = ((1.0 + cosw) / 2.0) / a0;
    b1 = -(1.0 + cosw) / a0;
    b2 = ((1.0 + cosw) / 2.0) / a0;
    a1 = (-2.0 * cosw) / a0;
    a2 = (1.0 - alpha) / a0;
  }

  /// Configures this biquad as a Band-Pass Filter.
  void setBandPass({required double sampleRate, required double centerHz, required double bandwidthHz}) {
    if (centerHz <= 0.0 || sampleRate <= 0.0 || centerHz >= sampleRate / 2.0) return;

    final omega = 2.0 * pi * centerHz / sampleRate;
    final q = centerHz / max(0.1, bandwidthHz);
    final alpha = sin(omega) / (2.0 * q);
    final cosw = cos(omega);

    final a0 = 1.0 + alpha;
    b0 = alpha / a0;
    b1 = 0.0;
    b2 = -alpha / a0;
    a1 = (-2.0 * cosw) / a0;
    a2 = (1.0 - alpha) / a0;
  }

  /// Processes a single input sample through the filter.
  double process(double x) {
    // Direct Form II Transposed:
    // y[n] = b0 * x[n] + s1[n-1]
    // s1[n] = b1 * x[n] - a1 * y[n] + s2[n-1]
    // s2[n] = b2 * x[n] - a2 * y[n]
    final y = b0 * x + _s1;
    _s1 = b1 * x - a1 * y + _s2;
    _s2 = b2 * x - a2 * y;
    return y;
  }

  /// Resets internal filter delay states.
  void reset() {
    _s1 = 0.0;
    _s2 = 0.0;
  }
}

/// A composite stateful digital Bandpass filter cascading High-pass (0.5 Hz) and Low-pass (3.0 Hz)
/// 2nd-order Butterworth stages, specifically designed for isolating human gait motion.
class BandpassWalkingFilter {
  final double lowCutoffHz;
  final double highCutoffHz;
  double sampleRateHz;

  final BiquadFilter _highPassStage = BiquadFilter();
  final BiquadFilter _lowPassStage = BiquadFilter();

  bool _isInitialized = false;

  BandpassWalkingFilter({
    this.lowCutoffHz = 0.5,
    this.highCutoffHz = 3.0,
    this.sampleRateHz = 50.0,
  }) {
    _recomputeCoefficients();
  }

  void _recomputeCoefficients() {
    _highPassStage.setHighPass(sampleRate: sampleRateHz, cutoffHz: lowCutoffHz);
    _lowPassStage.setLowPass(sampleRate: sampleRateHz, cutoffHz: highCutoffHz);
    _isInitialized = true;
  }

  /// Updates the current sampling rate if the interval dt has shifted significantly.
  void updateSampleRate(double newSampleRateHz) {
    if (newSampleRateHz > 5.0 && (newSampleRateHz - sampleRateHz).abs() > 2.0) {
      sampleRateHz = newSampleRateHz;
      _recomputeCoefficients();
    }
  }

  /// Filters a raw acceleration sample (e.g. magnitude or vertical acceleration).
  double process(double rawSample) {
    if (!_isInitialized) _recomputeCoefficients();

    // Stage 1: High-pass to remove static gravity / low frequency drift (< 0.5 Hz)
    final hpOut = _highPassStage.process(rawSample);

    // Stage 2: Low-pass to remove high-frequency hand tremors / engine vibrations (> 3.0 Hz)
    final bpOut = _lowPassStage.process(hpOut);

    return bpOut;
  }

  /// Resets the filter states to zero.
  void reset() {
    _highPassStage.reset();
    _lowPassStage.reset();
  }
}

/// A stateful Low-pass filter for estimating the gravity vector when no orientation sensor is active.
class GravityEstimatorFilter {
  final double cutoffHz;
  double sampleRateHz;
  final BiquadFilter _filterX = BiquadFilter();
  final BiquadFilter _filterY = BiquadFilter();
  final BiquadFilter _filterZ = BiquadFilter();

  GravityEstimatorFilter({
    this.cutoffHz = 0.3,
    this.sampleRateHz = 50.0,
  }) {
    _recompute();
  }

  void _recompute() {
    _filterX.setLowPass(sampleRate: sampleRateHz, cutoffHz: cutoffHz);
    _filterY.setLowPass(sampleRate: sampleRateHz, cutoffHz: cutoffHz);
    _filterZ.setLowPass(sampleRate: sampleRateHz, cutoffHz: cutoffHz);
  }

  void updateSampleRate(double newRateHz) {
    if (newRateHz > 5.0 && (newRateHz - sampleRateHz).abs() > 2.0) {
      sampleRateHz = newRateHz;
      _recompute();
    }
  }

  List<double> process(double ax, double ay, double az) {
    final gx = _filterX.process(ax);
    final gy = _filterY.process(ay);
    final gz = _filterZ.process(az);
    return [gx, gy, gz];
  }

  void reset() {
    _filterX.reset();
    _filterY.reset();
    _filterZ.reset();
  }
}

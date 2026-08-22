import 'dart:math';

class StepDetector {
  double _previousMagnitude = 0.0;
  double _filteredMagnitude = 0.0;

  DateTime? _lastStepTime;

  int stepCount = 0;

  // Minimum time between two steps.
  static const Duration minStepInterval = Duration(milliseconds: 350);

  // Low-pass filter strength.
  static const double alpha = 0.15;

  // Step detection threshold.
  static const double threshold = 1.5;

  bool processAcceleration(double x, double y, double z) {
    // --------------------------------------------------
    // 1. Calculate acceleration magnitude
    // --------------------------------------------------

    final magnitude = sqrt(x * x + y * y + z * z);

    // --------------------------------------------------
    // 2. Smooth the signal
    // --------------------------------------------------

    _filteredMagnitude = alpha * magnitude + (1 - alpha) * _filteredMagnitude;

    // --------------------------------------------------
    // 3. Calculate change from previous sample
    // --------------------------------------------------

    final difference = _filteredMagnitude - _previousMagnitude;

    final now = DateTime.now();

    final enoughTimePassed =
        _lastStepTime == null ||
        now.difference(_lastStepTime!) >= minStepInterval;

    // --------------------------------------------------
    // 4. Detect significant upward movement
    // --------------------------------------------------

    final potentialStep = difference > threshold;

    bool stepDetected = false;

    if (potentialStep && enoughTimePassed) {
      stepCount++;
      _lastStepTime = now;
      stepDetected = true;
    }

    _previousMagnitude = _filteredMagnitude;

    return stepDetected;
  }

  void reset() {
    _previousMagnitude = 0.0;
    _filteredMagnitude = 0.0;
    _lastStepTime = null;
    stepCount = 0;
  }
}

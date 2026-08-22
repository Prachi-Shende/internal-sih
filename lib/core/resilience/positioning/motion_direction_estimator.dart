import 'dart:math';

/// Estimates whether the user is actually walking and
/// estimates the horizontal movement direction.
///
/// Important:
/// - Heading = direction the PHONE is pointing.
/// - Movement heading = estimated direction the PERSON is moving.
///
/// This class is intentionally kept separate from HeadingSensor.
class MotionDirectionEstimator {
  // ============================================================
  // CONFIGURATION
  // ============================================================

  /// Minimum acceleration variation required before we
  /// consider the phone to be experiencing walking motion.
  static const double movementThreshold = 0.8;

  /// Smoothing factor for acceleration magnitude.
  static const double alpha = 0.15;

  // ============================================================
  // INTERNAL STATE
  // ============================================================

  double _filteredMagnitude = 0.0;
  double _previousMagnitude = 0.0;

  double? _movementHeading;

  bool _isWalking = false;

  // ============================================================
  // GETTERS
  // ============================================================

  /// Estimated direction of movement.
  ///
  /// 0   = North
  /// 90  = East
  /// 180 = South
  /// 270 = West
  double? get movementHeading => _movementHeading;

  /// Whether the recent sensor data looks like walking motion.
  bool get isWalking => _isWalking;

  // ============================================================
  // UPDATE
  // ============================================================

  void update({
    required double accelX,
    required double accelY,
    required double accelZ,
    required double headingDegrees,
  }) {
    // ----------------------------------------------------------
    // 1. Calculate acceleration magnitude
    // ----------------------------------------------------------

    final magnitude = sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ);

    // ----------------------------------------------------------
    // 2. Smooth acceleration
    // ----------------------------------------------------------

    _filteredMagnitude = alpha * magnitude + (1 - alpha) * _filteredMagnitude;

    // ----------------------------------------------------------
    // 3. Calculate acceleration change
    // ----------------------------------------------------------

    final delta = (_filteredMagnitude - _previousMagnitude).abs();

    _previousMagnitude = _filteredMagnitude;

    // ----------------------------------------------------------
    // 4. Determine whether there is meaningful motion
    // ----------------------------------------------------------

    _isWalking = delta > movementThreshold;

    if (!_isWalking) {
      return;
    }

    // ----------------------------------------------------------
    // 5. Temporary movement-direction estimate
    // ----------------------------------------------------------
    //
    // IMPORTANT:
    //
    // For this first implementation we use the phone heading
    // as the movement heading.
    //
    // This is NOT the final solution.
    //
    // We are first separating "walking detected" from
    // "phone is stationary".
    //
    // Later we will replace this with actual orientation-
    // compensated acceleration analysis.
    //

    _movementHeading = _normalizeHeading(headingDegrees);
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
    _filteredMagnitude = 0.0;
    _previousMagnitude = 0.0;

    _movementHeading = null;
    _isWalking = false;
  }
}

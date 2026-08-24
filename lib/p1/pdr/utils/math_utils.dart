import 'dart:math';

/// Mathematical utilities for quaternion kinematics, 3D coordinate transformations,
/// circular statistics, and moving window calculations.
class MathUtils {
  /// Transforms a 3D vector [vx, vy, vz] in phone frame into world frame (ENU)
  /// using unit quaternion [qx, qy, qz, qw].
  ///
  /// Uses the direct Rodrigues-style vector formula:
  /// v' = v + 2 * q_vec x (q_vec x v + qw * v)
  /// which is faster and numerically stable without full matrix instantiation.
  static List<double> rotateVectorByQuaternion({
    required double vx,
    required double vy,
    required double vz,
    required double qx,
    required double qy,
    required double qz,
    required double qw,
  }) {
    // Cross product: t = 2 * (q_vec x v)
    final tx = 2.0 * (qy * vz - qz * vy);
    final ty = 2.0 * (qz * vx - qx * vz);
    final tz = 2.0 * (qx * vy - qy * vx);

    // v' = v + qw * t + (q_vec x t)
    final vPrimeX = vx + qw * tx + (qy * tz - qz * ty);
    final vPrimeY = vy + qw * ty + (qz * tx - qx * tz);
    final vPrimeZ = vz + qw * tz + (qx * ty - qy * tx);

    return [vPrimeX, vPrimeY, vPrimeZ];
  }

  /// Calculates the norm of a 3D vector.
  static double vectorNorm(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }

  /// Normalizes an angle in degrees into [0.0, 360.0).
  static double normalizeDegrees(double degrees) {
    var d = degrees % 360.0;
    if (d < 0.0) {
      d += 360.0;
    }
    return d;
  }

  /// Normalizes an angle in radians into [0.0, 2π).
  static double normalizeRadians(double radians) {
    const twoPi = 2.0 * pi;
    var r = radians % twoPi;
    if (r < 0.0) {
      r += twoPi;
    }
    return r;
  }

  /// Calculates the shortest angular difference (target - source) in radians in range [-π, π].
  static double angularDifferenceRadians(double targetRad, double sourceRad) {
    var diff = (targetRad - sourceRad) % (2.0 * pi);
    if (diff > pi) {
      diff -= 2.0 * pi;
    } else if (diff < -pi) {
      diff += 2.0 * pi;
    }
    return diff;
  }

  /// Calculates the shortest angular difference (target - source) in degrees in range [-180, 180].
  static double angularDifferenceDegrees(double targetDeg, double sourceDeg) {
    var diff = (targetDeg - sourceDeg) % 360.0;
    if (diff > 180.0) {
      diff -= 360.0;
    } else if (diff < -180.0) {
      diff += 360.0;
    }
    return diff;
  }

  /// Performs circular exponential moving average smoothing for an angle in degrees.
  ///
  /// Correctly handles the 0° / 360° discontinuity using vector components:
  /// sin_smooth = (1 - alpha) * sin_prev + alpha * sin(new)
  /// cos_smooth = (1 - alpha) * cos_prev + alpha * cos(new)
  static double smoothCircularDegrees({
    required double currentSmoothedDeg,
    required double newSampleDeg,
    required double alpha,
  }) {
    final curRad = currentSmoothedDeg * pi / 180.0;
    final newRad = newSampleDeg * pi / 180.0;

    final curSin = sin(curRad);
    final curCos = cos(curRad);

    final newSin = sin(newRad);
    final newCos = cos(newRad);

    final smoothedSin = (1.0 - alpha) * curSin + alpha * newSin;
    final smoothedCos = (1.0 - alpha) * curCos + alpha * newCos;

    final smoothedRad = atan2(smoothedSin, smoothedCos);
    return normalizeDegrees(smoothedRad * 180.0 / pi);
  }

  /// Computes the circular mean of a list of angles in degrees.
  static double circularMeanDegrees(List<double> anglesInDegrees) {
    if (anglesInDegrees.isEmpty) return 0.0;

    double sumSin = 0.0;
    double sumCos = 0.0;

    for (final deg in anglesInDegrees) {
      final rad = deg * pi / 180.0;
      sumSin += sin(rad);
      sumCos += cos(rad);
    }

    final meanRad = atan2(sumSin, sumCos);
    return normalizeDegrees(meanRad * 180.0 / pi);
  }
}

/// Fixed-capacity ring buffer for calculating online running mean, variance, and standard deviation.
class MovingStatistics {
  final int capacity;
  final List<double> _buffer;
  int _count = 0;
  int _insertIndex = 0;

  MovingStatistics(this.capacity) : _buffer = List<double>.filled(capacity, 0.0);

  int get length => _count;
  bool get isFull => _count == capacity;

  void add(double value) {
    _buffer[_insertIndex] = value;
    _insertIndex = (_insertIndex + 1) % capacity;
    if (_count < capacity) {
      _count++;
    }
  }

  double get mean {
    if (_count == 0) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < _count; i++) {
      sum += _buffer[i];
    }
    return sum / _count;
  }

  double get variance {
    if (_count < 2) return 0.0;
    final m = mean;
    double sumSq = 0.0;
    for (int i = 0; i < _count; i++) {
      final diff = _buffer[i] - m;
      sumSq += diff * diff;
    }
    return sumSq / (_count - 1);
  }

  double get standardDeviation => sqrt(variance);

  double get min {
    if (_count == 0) return 0.0;
    double minVal = _buffer[0];
    for (int i = 1; i < _count; i++) {
      if (_buffer[i] < minVal) minVal = _buffer[i];
    }
    return minVal;
  }

  double get max {
    if (_count == 0) return 0.0;
    double maxVal = _buffer[0];
    for (int i = 1; i < _count; i++) {
      if (_buffer[i] > maxVal) maxVal = _buffer[i];
    }
    return maxVal;
  }

  void clear() {
    _count = 0;
    _insertIndex = 0;
    _buffer.fillRange(0, capacity, 0.0);
  }
}

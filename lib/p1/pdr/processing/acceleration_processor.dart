import 'dart:math';

import '../models/orientation_sample.dart';
import '../models/pdr_config.dart';
import '../models/sensor_sample.dart';
import '../utils/math_utils.dart';
import 'signal_filter.dart';

/// Container for processed 3D and filtered acceleration metrics.
class ProcessedAcceleration {
  final double timestamp;

  /// Raw phone-frame acceleration magnitude (m/s²).
  final double rawMagnitude;

  /// World frame dynamic linear acceleration: [East, North, Up] (m/s²).
  final double worldLinAx; // East
  final double worldLinAy; // North
  final double worldLinAz; // Up (vertical dynamic)

  /// Magnitude of horizontal dynamic acceleration in world plane: sqrt(ax² + ay²).
  final double horizontalMagnitude;

  /// Bandpass filtered vertical acceleration (primary gait signal).
  final double filteredVerticalAcceleration;

  /// Bandpass filtered total magnitude acceleration (fallback / composite gait signal).
  final double filteredMagnitude;

  /// Moving variance of acceleration (energy indicator for stationary detection).
  final double accelerationVariance;

  const ProcessedAcceleration({
    required this.timestamp,
    required this.rawMagnitude,
    required this.worldLinAx,
    required this.worldLinAy,
    required this.worldLinAz,
    required this.horizontalMagnitude,
    required this.filteredVerticalAcceleration,
    required this.filteredMagnitude,
    required this.accelerationVariance,
  });

  @override
  String toString() {
    return 'ProcessedAccel(t=${timestamp.toStringAsFixed(3)}, raw=${rawMagnitude.toStringAsFixed(2)}, '
        'vertFilt=${filteredVerticalAcceleration.toStringAsFixed(2)}, magFilt=${filteredMagnitude.toStringAsFixed(2)}, '
        'var=${accelerationVariance.toStringAsFixed(3)})';
  }
}

/// Transforms raw phone-frame acceleration to world ENU frame, compensates for gravity,
/// applies bandpass filtering, and computes gait dynamics.
class AccelerationProcessor {
  final PdrConfig config;

  late final BandpassWalkingFilter _verticalFilter;
  late final BandpassWalkingFilter _magnitudeFilter;
  late final GravityEstimatorFilter _fallbackGravityFilter;
  final MovingStatistics _varianceBuffer = MovingStatistics(25); // ~0.5s window at 50Hz

  static const double standardGravity = 9.80665;

  AccelerationProcessor({required this.config}) {
    _verticalFilter = BandpassWalkingFilter(
      lowCutoffHz: config.filterLowCutoffHz,
      highCutoffHz: config.filterHighCutoffHz,
      sampleRateHz: config.samplingRateHz,
    );
    _magnitudeFilter = BandpassWalkingFilter(
      lowCutoffHz: config.filterLowCutoffHz,
      highCutoffHz: config.filterHighCutoffHz,
      sampleRateHz: config.samplingRateHz,
    );
    _fallbackGravityFilter = GravityEstimatorFilter(
      cutoffHz: 0.3,
      sampleRateHz: config.samplingRateHz,
    );
  }

  /// Processes a single sensor sample with the current orientation sample.
  ProcessedAcceleration process({
    required SensorSample sample,
    OrientationSample? orientation,
  }) {
    // Dynamic sample rate adaptation if dt varies
    if (sample.dt > 0.005 && sample.dt < 0.2) {
      final instantaneousRate = 1.0 / sample.dt;
      _verticalFilter.updateSampleRate(instantaneousRate);
      _magnitudeFilter.updateSampleRate(instantaneousRate);
      _fallbackGravityFilter.updateSampleRate(instantaneousRate);
    }

    final rawMag = sample.accelerationMagnitude;
    _varianceBuffer.add(rawMag);

    double worldX = 0.0;
    double worldY = 0.0;
    double worldZ = 0.0;

    if (orientation != null) {
      // 1. Transform phone frame acceleration into World ENU Frame
      final worldAcc = MathUtils.rotateVectorByQuaternion(
        vx: sample.ax,
        vy: sample.ay,
        vz: sample.az,
        qx: orientation.qx,
        qy: orientation.qy,
        qz: orientation.qz,
        qw: orientation.qw,
      );

      worldX = worldAcc[0];
      worldY = worldAcc[1];
      // In ENU frame with raw accelerometer readings, gravity is +9.81 along +Z (Up)
      worldZ = worldAcc[2] - standardGravity;
    } else {
      // Fallback: estimate gravity vector via low-pass filter
      final gVec = _fallbackGravityFilter.process(sample.ax, sample.ay, sample.az);
      final gNorm = MathUtils.vectorNorm(gVec[0], gVec[1], gVec[2]);
      if (gNorm > 0.1) {
        final gx = gVec[0] / gNorm;
        final gy = gVec[1] / gNorm;
        final gz = gVec[2] / gNorm;
        // Projection along estimated gravity axis
        final dot = sample.ax * gx + sample.ay * gy + sample.az * gz;
        worldZ = dot - standardGravity;
      } else {
        worldZ = rawMag - standardGravity;
      }
    }

    final horizMag = sqrt(worldX * worldX + worldY * worldY);

    // 2. Bandpass filter the vertical acceleration and total magnitude
    final filteredVert = _verticalFilter.process(worldZ);
    final filteredMag = _magnitudeFilter.process(rawMag - standardGravity);

    return ProcessedAcceleration(
      timestamp: sample.timestamp,
      rawMagnitude: rawMag,
      worldLinAx: worldX,
      worldLinAy: worldY,
      worldLinAz: worldZ,
      horizontalMagnitude: horizMag,
      filteredVerticalAcceleration: filteredVert,
      filteredMagnitude: filteredMag,
      accelerationVariance: _varianceBuffer.variance,
    );
  }

  void reset() {
    _verticalFilter.reset();
    _magnitudeFilter.reset();
    _fallbackGravityFilter.reset();
    _varianceBuffer.clear();
  }
}

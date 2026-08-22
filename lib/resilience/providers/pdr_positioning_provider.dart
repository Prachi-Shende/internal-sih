import 'dart:async';
import 'dart:math';

import '../../pdr/core/pdr_engine.dart';
import '../../pdr/models/pdr_state.dart';
import '../../pdr/utils/geo_utils.dart';
import '../models/position_estimate.dart';
import '../models/position_source.dart';
import 'positioning_provider.dart';

/// Wraps the classical PDR engine into the unified PositioningProvider architecture,
/// anchoring relative inertial displacement onto the last reliable absolute geodetic fix
/// WITHOUT resetting internal PDR trajectory history or step counters.
class PdrPositioningProvider implements PositioningProvider {
  final PdrEngine pdrEngine;

  @override
  PositionSource get source => PositionSource.pdr;

  @override
  bool get isAvailable => _anchor != null && pdrEngine.isRunning;

  PositionEstimate? _currentPosition;
  @override
  PositionEstimate? get currentPosition => _currentPosition;

  final StreamController<PositionEstimate> _positionController =
      StreamController<PositionEstimate>.broadcast();
  @override
  Stream<PositionEstimate> get positionStream => _positionController.stream;

  StreamSubscription<PdrState>? _pdrSubscription;

  PositionEstimate? _anchor;
  PositionEstimate? get anchor => _anchor;

  double _anchorOffsetEast = 0.0;
  double _anchorOffsetNorth = 0.0;

  double _displacementFromAnchorMeters = 0.0;
  double get displacementFromAnchorMeters => _displacementFromAnchorMeters;

  PdrPositioningProvider({PdrEngine? engine})
      : pdrEngine = engine ?? PdrEngine();

  @override
  Future<void> start() async {
    if (_pdrSubscription != null) return;

    if (!pdrEngine.isRunning) {
      await pdrEngine.start();
    }

    _pdrSubscription = pdrEngine.stateStream.listen(_handlePdrStateUpdate);
  }

  /// Sets or updates the geodetic anchor point from which PDR displacement is calculated.
  /// Crucial: Does NOT reset the PDR step count, trajectory history, or filter buffers.
  void setAnchor(PositionEstimate newAnchor) {
    _anchor = newAnchor;
    // Capture the PDR coordinate position at the moment the anchor was established
    _anchorOffsetEast = pdrEngine.currentState.x;
    _anchorOffsetNorth = pdrEngine.currentState.y;
    _displacementFromAnchorMeters = 0.0;

    _currentPosition = newAnchor.copyWith(
      source: PositionSource.pdr,
      isAbsolute: false,
      isDegraded: false,
    );
  }

  void _handlePdrStateUpdate(PdrState state) {
    if (_anchor == null) {
      // Unanchored PDR (relative only)
      return;
    }

    final dx = state.x - _anchorOffsetEast;
    final dy = state.y - _anchorOffsetNorth;
    _displacementFromAnchorMeters = sqrt(dx * dx + dy * dy);

    // Convert relative offset (dx, dy) from anchor into WGS-84 (Lat, Lon)
    final latLng = GeoUtils.localMetersToLatLng(
      originLat: _anchor!.latitude,
      originLon: _anchor!.longitude,
      eastMeters: dx,
      northMeters: dy,
    );

    // Calculate time elapsed since the anchor was established
    final elapsedSeconds = DateTime.now()
        .difference(_anchor!.timestamp)
        .inMilliseconds /
        1000.0;

    // Uncertainty increases with both distance walked and time elapsed
    final uncertainty = _anchor!.uncertaintyMeters +
        (0.05 * _displacementFromAnchorMeters) +
        (0.02 * elapsedSeconds);

    // Confidence decays gradually over unanchored time and distance
    final timeDecay = (1.0 - 0.001 * elapsedSeconds - 0.0015 * _displacementFromAnchorMeters)
        .clamp(0.25, 1.0);

    final compositeConfidence = (_anchor!.confidence * state.overallConfidence * timeDecay)
        .clamp(0.10, 0.85);

    final estimate = PositionEstimate(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
      source: PositionSource.pdr,
      confidence: compositeConfidence,
      uncertaintyMeters: uncertainty,
      timestamp: DateTime.now(),
      isAbsolute: false,
      isDegraded: true,
      headingDegrees: state.headingDegrees,
      speedMps: state.velocity > 0 ? state.velocity : null,
    );

    _currentPosition = estimate;

    if (!_positionController.isClosed) {
      _positionController.add(estimate);
    }
  }

  @override
  Future<void> stop() async {
    await _pdrSubscription?.cancel();
    _pdrSubscription = null;
    pdrEngine.stop();
  }

  void dispose() {
    stop();
    _positionController.close();
  }
}

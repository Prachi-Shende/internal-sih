import 'models/location_estimate.dart';
import 'models/resilience_state.dart';
import 'models/positioning_source.dart';
import 'sensors/connectivity_sensor.dart';
import 'sensors/gps_sensor.dart';
import 'sensors/imu_sensor.dart';

class ResilienceEngine {
  final GpsSensor gpsSensor;
  final ImuSensor imuSensor;
  final ConnectivitySensor connectivitySensor;

  ResilienceEngine({
    GpsSensor? gpsSensor,
    ImuSensor? imuSensor,
    ConnectivitySensor? connectivitySensor,
  }) : gpsSensor = gpsSensor ?? GpsSensor(),
       imuSensor = imuSensor ?? ImuSensor(),
       connectivitySensor = connectivitySensor ?? ConnectivitySensor();

  Future<ResilienceState> getCurrentState() async {
    final gps = await gpsSensor.getCurrentPosition();

    final connectivity = await connectivitySensor.getStatus();

    final gpsAvailable = gps != null;
    final internetAvailable = connectivity == ConnectivityStatus.online;

    // --------------------------------------------------
    // CASE 1: GPS + Internet
    // --------------------------------------------------
    if (gpsAvailable && internetAvailable) {
      final location = LocationEstimate(
        latitude: gps.latitude,
        longitude: gps.longitude,
        accuracy: gps.accuracy,
        uncertaintyRadius: gps.accuracy,
        timestamp: gps.timestamp,
        source: PositioningSource.gps,
      );

      return ResilienceState(
        location: location,
        positioningSource: PositioningSource.gps,
        connectivityStatus: connectivity,
        mode: ResilienceMode.normal,
        gpsAvailable: true,
        internetAvailable: true,
        confidence: _calculateGpsConfidence(gps.accuracy),
        timestamp: DateTime.now(),
      );
    }

    // --------------------------------------------------
    // CASE 2: GPS available + Internet unavailable
    // --------------------------------------------------
    if (gpsAvailable && !internetAvailable) {
      final location = LocationEstimate(
        latitude: gps.latitude,
        longitude: gps.longitude,
        accuracy: gps.accuracy,
        uncertaintyRadius: gps.accuracy,
        timestamp: gps.timestamp,
        source: PositioningSource.gps,
      );

      return ResilienceState(
        location: location,
        positioningSource: PositioningSource.gps,
        connectivityStatus: connectivity,
        mode: ResilienceMode.offline,
        gpsAvailable: true,
        internetAvailable: false,
        confidence: _calculateGpsConfidence(gps.accuracy),
        timestamp: DateTime.now(),
      );
    }

    // --------------------------------------------------
    // CASE 3 & 4: GPS unavailable
    // --------------------------------------------------
    return ResilienceState(
      location: null,
      positioningSource: PositioningSource.unknown,
      connectivityStatus: connectivity,
      mode: internetAvailable
          ? ResilienceMode.gpsFallback
          : ResilienceMode.gpsAndInternetFallback,
      gpsAvailable: false,
      internetAvailable: internetAvailable,
      confidence: 0.0,
      timestamp: DateTime.now(),
    );
  }

  double _calculateGpsConfidence(double accuracy) {
    if (accuracy <= 5) return 1.0;
    if (accuracy <= 10) return 0.9;
    if (accuracy <= 20) return 0.75;
    if (accuracy <= 50) return 0.5;
    if (accuracy <= 100) return 0.3;

    return 0.1;
  }
}

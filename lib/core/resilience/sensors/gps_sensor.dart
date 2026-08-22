import 'package:geolocator/geolocator.dart';

class GpsSensor {
  Future<GpsReading?> getCurrentPosition() async {
    // 1. Check whether location services are enabled.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return null;
    }

    // 2. Check location permission.
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    // 3. Get current GPS position.
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    // 4. Convert it into our own GPS reading model.
    return GpsReading(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
    );
  }
}

class GpsReading {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  const GpsReading({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'GPS: '
        '${latitude.toStringAsFixed(6)}, '
        '${longitude.toStringAsFixed(6)} '
        '(±${accuracy.toStringAsFixed(1)}m)';
  }
}

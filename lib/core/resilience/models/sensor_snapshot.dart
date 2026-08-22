class SensorSnapshot {
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracy;

  final double? accelerationMagnitude;

  final int steps;

  final String movementStatus;

  final bool gpsAvailable;
  final bool stepSensorAvailable;

  final DateTime timestamp;

  const SensorSnapshot({
    this.latitude,
    this.longitude,
    this.gpsAccuracy,
    this.accelerationMagnitude,
    required this.steps,
    required this.movementStatus,
    required this.gpsAvailable,
    required this.stepSensorAvailable,
    required this.timestamp,
  });

  @override
  String toString() {
    return '''
SensorSnapshot(
  GPS: ${gpsAvailable ? "$latitude, $longitude" : "UNAVAILABLE"}
  GPS Accuracy: ${gpsAccuracy?.toStringAsFixed(2) ?? "N/A"} m
  Acceleration: ${accelerationMagnitude?.toStringAsFixed(3) ?? "N/A"} m/s²
  Steps: $steps
  Movement: $movementStatus
  Step Sensor: ${stepSensorAvailable ? "AVAILABLE" : "UNAVAILABLE"}
  Time: $timestamp
)
''';
  }
}

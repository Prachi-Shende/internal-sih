import 'dart:math';

class HeadingSensor {
  double? _headingDegrees;

  double? get headingDegrees => _headingDegrees;

  void update({
    required double accelX,
    required double accelY,
    required double accelZ,
    required double magX,
    required double magY,
    required double magZ,
  }) {
    final gravityMagnitude = sqrt(
      accelX * accelX + accelY * accelY + accelZ * accelZ,
    );

    if (gravityMagnitude < 0.1) {
      return;
    }

    final gx = accelX / gravityMagnitude;
    final gy = accelY / gravityMagnitude;
    final gz = accelZ / gravityMagnitude;

    final eastX = magY * gz - magZ * gy;
    final eastY = magZ * gx - magX * gz;
    final eastZ = magX * gy - magY * gx;

    final eastMagnitude = sqrt(eastX * eastX + eastY * eastY + eastZ * eastZ);

    if (eastMagnitude < 0.1) {
      return;
    }

    final ex = eastX / eastMagnitude;
    final ey = eastY / eastMagnitude;

    double heading = atan2(ey, ex) * 180 / pi;

    if (heading < 0) {
      heading += 360;
    }

    _headingDegrees = heading;
  }
}

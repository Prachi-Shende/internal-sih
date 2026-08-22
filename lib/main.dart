import 'dart:math';

import 'package:flutter/material.dart';

import 'core/resilience/resilience_engine.dart';
import 'core/resilience/sensors/imu_sensor.dart';
import 'core/resilience/sensors/step_sensor.dart';
import 'core/resilience/positioning/pdr_engine.dart';
import 'core/resilience/positioning/heading_sensor.dart';
import 'core/resilience/positioning/motion_direction_estimator.dart';

void main() {
  runApp(const SIHApp());
}

class SIHApp extends StatelessWidget {
  const SIHApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SIH Resilience Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ResilienceTestPage(),
    );
  }
}

class ResilienceTestPage extends StatefulWidget {
  const ResilienceTestPage({super.key});

  @override
  State<ResilienceTestPage> createState() => _ResilienceTestPageState();
}

class PdrPathPainter extends CustomPainter {
  final List<dynamic> points;

  PdrPathPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();

    if (points.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < points.length; i++) {
      final point = points[i];

      final x = center.dx + point.x;
      final y = center.dy - point.y;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    final start = Offset(
      center.dx + points.first.x,
      center.dy - points.first.y,
    );

    canvas.drawCircle(start, 7, Paint());
  }

  @override
  bool shouldRepaint(covariant PdrPathPainter oldDelegate) {
    return true;
  }
}

class _ResilienceTestPageState extends State<ResilienceTestPage> {
  // ============================================================
  // SERVICES
  // ============================================================

  final ResilienceEngine engine = ResilienceEngine();
  final ImuSensor imuSensor = ImuSensor();
  final StepSensor stepSensor = StepSensor();
  final PdrEngine pdrEngine = PdrEngine();
  final HeadingSensor headingSensor = HeadingSensor();
  final MotionDirectionEstimator motionDirectionEstimator =
      MotionDirectionEstimator();
  // ============================================================
  // PDR UI STATE
  // ============================================================

  double pdrX = 0;
  double pdrY = 0;

  double pdrDistance = 0;

  int pdrSteps = 0;
  double headingDegrees = 0;
  double? movementHeadingDegrees;
  bool isWalking = false;

  // ============================================================
  // GPS / RESILIENCE STATE
  // ============================================================

  String gpsStatus = 'Press the button to read GPS';
  bool gpsLoading = false;

  // ============================================================
  // IMU STATE
  // ============================================================

  String imuStatus = 'Starting sensors...';

  double accelerationMagnitude = 0.0;

  // ============================================================
  // NATIVE STEP SENSOR STATE
  // ============================================================

  int nativeSteps = 0;

  String pedestrianStatus = 'unknown';

  String stepSensorStatus = 'Initializing...';

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    _startImuSensor();
    _startStepSensor();
  }

  // ============================================================
  // START IMU
  // ============================================================

  void _startImuSensor() {
    imuSensor.onSensorUpdate = () {
      if (!mounted) return;

      final accel = imuSensor.latestAccelerometer;

      double magnitude = 0.0;

      if (accel != null) {
        magnitude = sqrt(
          accel.x * accel.x + accel.y * accel.y + accel.z * accel.z,
        );
      }

      final mag = imuSensor.latestMagnetometer;

      if (accel != null && mag != null) {
        headingSensor.update(
          accelX: accel.x,
          accelY: accel.y,
          accelZ: accel.z,
          magX: mag.x,
          magY: mag.y,
          magZ: mag.z,
        );
      }
      final heading = headingSensor.headingDegrees ?? headingDegrees;

      if (accel != null) {
        motionDirectionEstimator.update(
          accelX: accel.x,
          accelY: accel.y,
          accelZ: accel.z,
          headingDegrees: heading,
        );
      }

      setState(() {
        accelerationMagnitude = magnitude;
        headingDegrees = heading;

        movementHeadingDegrees = motionDirectionEstimator.movementHeading;

        isWalking = motionDirectionEstimator.isWalking;

        imuStatus =
            '''
ACCELEROMETER

X: ${_format(accel?.x)}
Y: ${_format(accel?.y)}
Z: ${_format(accel?.z)}

MAGNITUDE: ${magnitude.toStringAsFixed(3)} m/s²


GYROSCOPE

X: ${_format(imuSensor.latestGyroscope?.x)}
Y: ${_format(imuSensor.latestGyroscope?.y)}
Z: ${_format(imuSensor.latestGyroscope?.z)}


MAGNETOMETER

X: ${_format(imuSensor.latestMagnetometer?.x)}
Y: ${_format(imuSensor.latestMagnetometer?.y)}
Z: ${_format(imuSensor.latestMagnetometer?.z)}
HEADING

${headingDegrees.toStringAsFixed(1)}°
''';
      });
    };

    imuSensor.start();
  }

  // ============================================================
  // START NATIVE STEP SENSOR
  // ============================================================

  void _startStepSensor() {
    stepSensor.start(
      onStepUpdate: (steps) {
        if (!mounted) return;

        final added = pdrEngine.update(
          stepCount: steps,
          headingDegrees: headingDegrees,
        );

        debugPrint(
          'PDR UPDATE: sensor=$steps added=$added '
          'total=${pdrEngine.totalSteps} '
          'x=${pdrEngine.x.toStringAsFixed(2)} '
          'y=${pdrEngine.y.toStringAsFixed(2)} '
          'points=${pdrEngine.path.points.length}',
        );

        setState(() {
          nativeSteps = steps;
          pdrSteps = pdrEngine.totalSteps;
          pdrDistance = pdrEngine.totalDistance;
          pdrX = pdrEngine.x;
          pdrY = pdrEngine.y;
        });
      },

      onStatusUpdate: (status) {
        if (!mounted) return;

        setState(() {
          stepSensorStatus = status;
        });
      },

      onError: (error) {
        if (!mounted) return;

        setState(() {
          stepSensorStatus = 'ERROR: $error';
          pedestrianStatus = 'unknown';
        });
      },
    );
  }
  // ============================================================
  // GPS
  // ============================================================

  Future<void> readGps() async {
    setState(() {
      gpsLoading = true;
      gpsStatus = 'Reading GPS...';
    });

    try {
      final state = await engine.getCurrentState();

      if (!mounted) return;

      setState(() {
        if (state.location == null) {
          gpsStatus =
              '''
GPS UNAVAILABLE

Mode:
${state.mode}

GPS:
OFF

Internet:
${state.internetAvailable ? "ONLINE" : "OFFLINE"}

Confidence:
${(state.confidence * 100).toStringAsFixed(1)}%
''';
        } else {
          gpsStatus =
              '''
GPS AVAILABLE

Latitude:
${state.location!.latitude.toStringAsFixed(6)}

Longitude:
${state.location!.longitude.toStringAsFixed(6)}

Accuracy:
${state.location!.accuracy.toStringAsFixed(2)} m

Confidence:
${(state.confidence * 100).toStringAsFixed(1)}%

Source:
${state.positioningSource}

Mode:
${state.mode}

GPS:
${state.gpsAvailable ? "ON" : "OFF"}

Internet:
${state.internetAvailable ? "ONLINE" : "OFFLINE"}
''';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        gpsStatus = 'Error reading GPS:\n$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          gpsLoading = false;
        });
      }
    }
  }

  // ============================================================
  // HELPER
  // ============================================================

  String _format(double? value) {
    if (value == null) {
      return 'N/A';
    }

    return value.toStringAsFixed(3);
  }

  String _directionName(double heading) {
    if (heading >= 337.5 || heading < 22.5) {
      return 'North';
    }

    if (heading < 67.5) {
      return 'North-East';
    }

    if (heading < 112.5) {
      return 'East';
    }

    if (heading < 157.5) {
      return 'South-East';
    }

    if (heading < 202.5) {
      return 'South';
    }

    if (heading < 247.5) {
      return 'South-West';
    }

    if (heading < 292.5) {
      return 'West';
    }

    return 'North-West';
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  @override
  void dispose() {
    imuSensor.dispose();
    stepSensor.dispose();

    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================
  Widget _buildPdrCanvas() {
    return Card(
      child: SizedBox(
        height: 350,
        child: CustomPaint(
          painter: PdrPathPainter(points: pdrEngine.path.points),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SIH Resilience Test')),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              // ==================================================
              // HEADER
              // ==================================================
              const Icon(Icons.shield_outlined, size: 60),

              const SizedBox(height: 8),

              const Text(
                'Resilience Engine',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // GPS SECTION
              // ==================================================
              _sectionTitle('GPS / LOCATION', Icons.location_on),

              _infoCard(gpsStatus),

              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: gpsLoading ? null : readGps,

                icon: const Icon(Icons.gps_fixed),

                label: Text(gpsLoading ? 'Reading GPS...' : 'Get Current GPS'),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // NATIVE STEP SENSOR
              // ==================================================
              _sectionTitle('NATIVE STEP SENSOR', Icons.directions_walk),

              _infoCard('''
Status:
$stepSensorStatus

Steps this session:
$nativeSteps

Movement:
$pedestrianStatus
'''),

              const SizedBox(height: 24),

              _sectionTitle('PDR ENGINE', Icons.explore),

              _infoCard('''
PDR Steps:
$pdrSteps

Distance:
${pdrDistance.toStringAsFixed(2)} m

Phone Heading:
${headingDegrees.toStringAsFixed(1)}°

Phone Direction:
${_directionName(headingDegrees)}

Movement Status:
${isWalking ? 'WALKING' : 'STATIONARY'}

Movement Heading:
${movementHeadingDegrees == null ? 'N/A' : '${movementHeadingDegrees!.toStringAsFixed(1)}°'}

Movement Direction:
${movementHeadingDegrees == null ? 'N/A' : _directionName(movementHeadingDegrees!)}

East-West:
${pdrX.toStringAsFixed(2)} m

North-South:
${pdrY.toStringAsFixed(2)} m

Path Points:
${pdrEngine.path.points.length}
'''),
              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: () {
                  setState(() {});
                },
                icon: const Icon(Icons.show_chart),
                label: const Text('Plot Path'),
              ),

              const SizedBox(height: 12),
              SizedBox(
                height: 350,
                child: CustomPaint(
                  painter: PdrPainter(points: pdrEngine.path.points),
                ),
              ),

              // ==================================================
              // IMU
              // ==================================================
              _sectionTitle('IMU SENSORS', Icons.sensors),

              _infoCard(imuStatus),

              const SizedBox(height: 20),

              // ==================================================
              // DEBUG INFO
              // ==================================================
              _infoCard('''
CURRENT SENSOR SUMMARY

Step Sensor:
$stepSensorStatus

Steps:
$nativeSteps

Movement:
$pedestrianStatus

Acceleration Magnitude:
${accelerationMagnitude.toStringAsFixed(3)} m/s²

Heading:
${headingDegrees.toStringAsFixed(1)}°

Direction:
${_directionName(headingDegrees)}
'''),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),

      child: Row(
        children: [
          Icon(icon),

          const SizedBox(width: 8),

          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Text(text, style: const TextStyle(fontSize: 15, height: 1.4)),
      ),
    );
  }
}

class PdrPainter extends CustomPainter {
  final List<dynamic> points;

  PdrPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    if (points.length < 2) return;

    final path = Path();

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];

      final x = centerX + point.x * 40;
      final y = centerY - point.y * 40;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant PdrPainter oldDelegate) {
    return true;
  }
}

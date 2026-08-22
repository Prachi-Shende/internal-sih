import 'dart:math';
import 'package:flutter/material.dart';

import '../pdr/core/pdr_engine.dart';
import '../pdr/models/pdr_state.dart';
import 'pdr_calibration_screen.dart';
import 'pdr_debug_screen.dart';

class PdrDashboardScreen extends StatefulWidget {
  final PdrEngine pdrEngine;

  const PdrDashboardScreen({super.key, required this.pdrEngine});

  @override
  State<PdrDashboardScreen> createState() => _PdrDashboardScreenState();
}

class _PdrDashboardScreenState extends State<PdrDashboardScreen> {
  PdrEngine get engine => widget.pdrEngine;

  // Canvas viewport controls
  double _zoomScale = 1.0;
  Offset _panOffset = Offset.zero;
  bool _autoCenter = true;

  @override
  void initState() {
    super.initState();
    if (!engine.isRunning) {
      engine.start();
    }
  }

  String _getCardinalDirection(double degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees + 22.5) % 360 / 45).floor();
    return directions[index];
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.75) return Colors.tealAccent;
    if (confidence >= 0.50) return Colors.amberAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PdrState>(
      stream: engine.stateStream,
      initialData: engine.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? engine.currentState;

        return Scaffold(
          backgroundColor: const Color(0xFF0D1117),
          appBar: AppBar(
            backgroundColor: const Color(0xFF161B22),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.explore, color: Colors.blueAccent, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Classical PDR Engine',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.cyanAccent),
                tooltip: 'Stride Calibration',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PdrCalibrationScreen(pdrEngine: engine),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.bug_report_outlined, color: Colors.orangeAccent),
                tooltip: 'Debug Monitor',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PdrDebugScreen(pdrEngine: engine),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // 1. Status Bar Banner
              _buildTopStatusBanner(state),

              // 2. Interactive Trajectory Canvas
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    GestureDetector(
                      onScaleUpdate: (details) {
                        setState(() {
                          _autoCenter = false;
                          _zoomScale = (_zoomScale * details.scale).clamp(0.2, 5.0);
                          _panOffset += details.focalPointDelta;
                        });
                      },
                      child: ClipRect(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: TrajectoryCanvasPainter(
                            state: state,
                            zoomScale: _zoomScale,
                            panOffset: _panOffset,
                            autoCenter: _autoCenter,
                          ),
                        ),
                      ),
                    ),

                    // Canvas overlay controls
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Column(
                        children: [
                          _buildCanvasButton(
                            icon: Icons.my_location,
                            tooltip: 'Center on User',
                            onPressed: () {
                              setState(() {
                                _autoCenter = true;
                                _panOffset = Offset.zero;
                                _zoomScale = 1.0;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildCanvasButton(
                            icon: Icons.zoom_in,
                            tooltip: 'Zoom In',
                            onPressed: () {
                              setState(() {
                                _zoomScale = (_zoomScale * 1.25).clamp(0.2, 5.0);
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildCanvasButton(
                            icon: Icons.zoom_out,
                            tooltip: 'Zoom Out',
                            onPressed: () {
                              setState(() {
                                _zoomScale = (_zoomScale / 1.25).clamp(0.2, 5.0);
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    // Coordinates Overlay
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B22).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'East (X): ${state.x >= 0 ? "+" : ""}${state.x.toStringAsFixed(2)} m',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.lightGreenAccent,
                              ),
                            ),
                            Text(
                              'North (Y): ${state.y >= 0 ? "+" : ""}${state.y.toStringAsFixed(2)} m',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.cyanAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Metric Dashboard Cards
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF161B22),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, -3)),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Metric Grid
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 3,
                          childAspectRatio: 1.45,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildMetricTile(
                              label: 'STEPS',
                              value: '${state.stepCount}',
                              unit: 'steps',
                              icon: Icons.directions_walk,
                              color: Colors.tealAccent,
                            ),
                            _buildMetricTile(
                              label: 'DISTANCE',
                              value: state.totalDistance.toStringAsFixed(1),
                              unit: 'meters',
                              icon: Icons.straighten,
                              color: Colors.blueAccent,
                            ),
                            _buildMetricTile(
                              label: 'HEADING',
                              value: '${state.headingDegrees.toStringAsFixed(0)}°',
                              unit: _getCardinalDirection(state.headingDegrees),
                              icon: Icons.navigation_rounded,
                              color: Colors.amberAccent,
                              rotationDeg: state.headingDegrees,
                            ),
                            _buildMetricTile(
                              label: 'STRIDE',
                              value: state.currentStepLength.toStringAsFixed(2),
                              unit: 'm / step',
                              icon: Icons.nordic_walking,
                              color: Colors.purpleAccent,
                            ),
                            _buildMetricTile(
                              label: 'SPEED',
                              value: state.velocity.toStringAsFixed(2),
                              unit: 'm / s',
                              icon: Icons.speed,
                              color: Colors.orangeAccent,
                            ),
                            _buildMetricTile(
                              label: 'CONFIDENCE',
                              value: '${(state.overallConfidence * 100).toStringAsFixed(0)}%',
                              unit: state.isStationary ? 'Stationary' : 'Walking',
                              icon: Icons.verified_user_outlined,
                              color: _getConfidenceColor(state.overallConfidence),
                            ),
                          ],
                        ),
                      ),

                      // Engine Controls
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: engine.isRunning ? Colors.red.shade800 : Colors.teal.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (engine.isRunning) {
                                      engine.stop();
                                    } else {
                                      engine.start();
                                    }
                                  });
                                },
                                icon: Icon(engine.isRunning ? Icons.stop : Icons.play_arrow),
                                label: Text(engine.isRunning ? 'Stop PDR' : 'Start PDR'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                setState(() {
                                  engine.reset();
                                  _panOffset = Offset.zero;
                                  _zoomScale = 1.0;
                                  _autoCenter = true;
                                });
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reset'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopStatusBanner(PdrState state) {
    final statusText = state.isStationary ? 'STATIONARY (Zero-Motion Lock)' : 'WALKING DETECTED';
    final statusColor = state.isStationary ? Colors.amberAccent : Colors.lightGreenAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF0F141C),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.6), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Text(
            'Points: ${state.trajectory.length}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22).withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    double? rotationDeg,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              rotationDeg != null
                  ? Transform.rotate(
                      angle: rotationDeg * pi / 180.0,
                      child: Icon(icon, color: color, size: 14),
                    )
                  : Icon(icon, color: color, size: 14),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  unit,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom painter for rendering real-time 2D Cartesian PDR trajectories, grid lines, and orientation.
class TrajectoryCanvasPainter extends CustomPainter {
  final PdrState state;
  final double zoomScale;
  final Offset panOffset;
  final bool autoCenter;

  TrajectoryCanvasPainter({
    required this.state,
    required this.zoomScale,
    required this.panOffset,
    required this.autoCenter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final points = state.trajectory;

    // 1. Grid Background
    _drawGrid(canvas, size);

    if (points.isEmpty) return;

    // Center offset
    final currentPos = points.last;
    final center = Offset(size.width / 2, size.height / 2);

    // Scale factor: 30 pixels per meter scaled by zoomScale
    final pixelsPerMeter = 35.0 * zoomScale;

    final targetOffset = autoCenter
        ? Offset(
            center.dx - currentPos.x * pixelsPerMeter,
            center.dy + currentPos.y * pixelsPerMeter,
          )
        : center + panOffset;

    // 2. Draw Trajectory Path
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      // World ENU: East is +X (right), North is +Y (up => screen -Y)
      final px = targetOffset.dx + (p.x * pixelsPerMeter);
      final py = targetOffset.dy - (p.y * pixelsPerMeter);

      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }

    // Path Glow
    final glowPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.3)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glowPaint);

    // Main Path Line
    final pathPaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, pathPaint);

    // 3. Draw Step Nodes
    final stepPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.fill;
    for (int i = 1; i < points.length - 1; i++) {
      final p = points[i];
      final px = targetOffset.dx + (p.x * pixelsPerMeter);
      final py = targetOffset.dy - (p.y * pixelsPerMeter);
      canvas.drawCircle(Offset(px, py), 2.5, stepPaint);
    }

    // 4. Start Point (Green Marker)
    final startPt = points.first;
    final sx = targetOffset.dx + (startPt.x * pixelsPerMeter);
    final sy = targetOffset.dy - (startPt.y * pixelsPerMeter);
    canvas.drawCircle(Offset(sx, sy), 8.0, Paint()..color = Colors.greenAccent);
    canvas.drawCircle(Offset(sx, sy), 3.0, Paint()..color = Colors.black);

    // 5. Current Position with Orientation Heading Arrow (Red/Orange Marker)
    final endPt = points.last;
    final ex = targetOffset.dx + (endPt.x * pixelsPerMeter);
    final ey = targetOffset.dy - (endPt.y * pixelsPerMeter);

    // Pulse Ring around current position
    canvas.drawCircle(
      Offset(ex, ey),
      12.0,
      Paint()
        ..color = Colors.orangeAccent.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill,
    );

    // Current point dot
    canvas.drawCircle(Offset(ex, ey), 6.5, Paint()..color = Colors.orangeAccent);
    canvas.drawCircle(Offset(ex, ey), 2.5, Paint()..color = Colors.white);

    // Heading Pointer
    final headingRad = state.headingDegrees * pi / 180.0;
    const arrowLength = 22.0;
    // Heading 0° is North (screen -Y), 90° is East (screen +X)
    final tipX = ex + arrowLength * sin(headingRad);
    final tipY = ey - arrowLength * cos(headingRad);

    final arrowPaint = Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(ex, ey), Offset(tipX, tipY), arrowPaint);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    const step = 35.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TrajectoryCanvasPainter oldDelegate) => true;
}

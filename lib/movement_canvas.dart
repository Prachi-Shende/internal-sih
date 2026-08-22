import 'dart:math';
import 'package:flutter/material.dart';

class MovementCanvas extends StatefulWidget {
  final int steps;
  final double heading;

  const MovementCanvas({super.key, required this.steps, required this.heading});

  @override
  State<MovementCanvas> createState() => _MovementCanvasState();
}

class _MovementCanvasState extends State<MovementCanvas> {
  final List<Offset> path = [];
  int lastStep = 0;

  @override
  void didUpdateWidget(covariant MovementCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.steps > lastStep) {
      final angle = widget.heading * pi / 180;

      final previous = path.isEmpty ? const Offset(200, 300) : path.last;

      const stepLength = 20.0;

      path.add(
        Offset(
          previous.dx + sin(angle) * stepLength,
          previous.dy - cos(angle) * stepLength,
        ),
      );

      lastStep = widget.steps;
    }

    if (widget.steps == 0) {
      path.clear();
      lastStep = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PathPainter(path),
      child: const SizedBox.expand(),
    );
  }
}

class _PathPainter extends CustomPainter {
  final List<Offset> path;

  _PathPainter(this.path);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    if (path.isEmpty) return;

    final line = Path()..moveTo(path.first.dx, path.first.dy);

    for (final point in path.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(line, paint);

    final dotPaint = Paint()..style = PaintingStyle.fill;

    canvas.drawCircle(path.last, 8, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) => true;
}

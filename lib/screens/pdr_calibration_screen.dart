import 'package:flutter/material.dart';

import '../pdr/calibration/pdr_calibration.dart';
import '../pdr/core/pdr_engine.dart';
import '../pdr/models/pdr_state.dart';

class PdrCalibrationScreen extends StatefulWidget {
  final PdrEngine pdrEngine;

  const PdrCalibrationScreen({super.key, required this.pdrEngine});

  @override
  State<PdrCalibrationScreen> createState() => _PdrCalibrationScreenState();
}

class _PdrCalibrationScreenState extends State<PdrCalibrationScreen> {
  PdrEngine get engine => widget.pdrEngine;

  double _selectedDistance = 10.0;
  CalibrationResult? _result;

  @override
  Widget build(BuildContext context) {
    final cal = engine.calibrationManager;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Personal Calibration', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<PdrState>(
        stream: engine.stateStream,
        initialData: engine.currentState,
        builder: (context, snapshot) {
          final state = snapshot.data ?? engine.currentState;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header card
                _buildHeaderCard(),
                const SizedBox(height: 20),

                // Distance Selector
                if (cal.phase == CalibrationPhase.idle) ...[
                  _buildDistanceSelector(),
                  const SizedBox(height: 24),
                ],

                // Active Phase Progress Card
                _buildPhaseCard(cal, state),
                const SizedBox(height: 24),

                // Action Buttons
                _buildActionButtons(cal),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.straighten, color: Colors.tealAccent, size: 24),
              const SizedBox(width: 10),
              const Text(
                'Personalized Stride Model',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Calibrates your unique biomechanical Weinberg factor (K) and baseline step length by measuring steps over a known walking distance.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SELECT CALIBRATION DISTANCE',
            style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [5.0, 10.0, 15.0, 20.0].map((dist) {
              final isSelected = _selectedDistance == dist;
              return ChoiceChip(
                label: Text('${dist.toInt()} m'),
                selected: isSelected,
                selectedColor: Colors.tealAccent.shade700,
                backgroundColor: const Color(0xFF0D1117),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedDistance = dist);
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseCard(PdrCalibrationManager cal, PdrState state) {
    switch (cal.phase) {
      case CalibrationPhase.idle:
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              const Icon(Icons.touch_app_outlined, color: Colors.tealAccent, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Ready to Begin',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Mark out $_selectedDistance meters on a flat surface. Tap Start Calibration when ready.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        );

      case CalibrationPhase.standingStill:
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(color: Colors.amberAccent, strokeWidth: 4),
              ),
              const SizedBox(height: 16),
              const Text(
                'Step 1: Stand Still (3s)',
                style: TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hold the phone naturally and remain completely stationary to establish orientation baseline.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        );

      case CalibrationPhase.walking:
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.lightGreenAccent.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              const Icon(Icons.directions_walk, color: Colors.lightGreenAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                'Step 2: Walk Exactly $_selectedDistance Meters',
                style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                '${cal.stepCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const Text('VALID STEPS RECORDED', style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 12),
              const Text(
                'Walk at your natural pace in a straight line. Tap Finish when you reach the line.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        );

      case CalibrationPhase.completed:
        final res = _result ?? cal.latestResult;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.tealAccent),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.tealAccent, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Calibration Successful!',
                style: TextStyle(color: Colors.tealAccent, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (res != null) ...[
                _buildResultRow('Walked Distance:', '${res.knownDistanceMeters.toStringAsFixed(1)} m'),
                _buildResultRow('Detected Steps:', '${res.stepCount} steps'),
                _buildResultRow('Average Step Length:', '${res.averageStepLength.toStringAsFixed(2)} m'),
                _buildResultRow('Calibrated Weinberg K:', res.calibratedWeinbergK.toStringAsFixed(3)),
                _buildResultRow('Average Cadence:', '${(res.averageCadenceHz * 60).toStringAsFixed(0)} steps/min'),
                _buildResultRow('Baseline Heading:', '${res.baselineHeadingDegrees.toStringAsFixed(1)}°'),
              ],
            ],
          ),
        );

      case CalibrationPhase.failed:
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.redAccent),
          ),
          child: const Column(
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              SizedBox(height: 12),
              Text(
                'Calibration Incomplete',
                style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Not enough steps recorded (< 3 steps). Please ensure you walk the entire marked distance.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(PdrCalibrationManager cal) {
    if (cal.phase == CalibrationPhase.idle || cal.phase == CalibrationPhase.failed) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () {
          setState(() {
            _result = null;
            engine.startCalibrationFlow(knownDistanceMeters: _selectedDistance);
          });
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Calibration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );
    }

    if (cal.phase == CalibrationPhase.walking) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.lightGreen.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () {
          final res = engine.finishCalibrationFlow();
          setState(() {
            _result = res;
          });
        },
        icon: const Icon(Icons.done_all),
        label: const Text('Finish Walking & Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );
    }

    if (cal.phase == CalibrationPhase.completed) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                setState(() {
                  cal.reset();
                  _result = null;
                });
              },
              child: const Text('Recalibrate'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

import 'dart:async';
import 'package:flutter/material.dart';

import '../pdr/core/pdr_engine.dart';
import '../pdr/models/pdr_state.dart';
import '../pdr/models/step_event.dart';
import '../pdr/processing/acceleration_processor.dart';

class PdrDebugScreen extends StatefulWidget {
  final PdrEngine pdrEngine;

  const PdrDebugScreen({super.key, required this.pdrEngine});

  @override
  State<PdrDebugScreen> createState() => _PdrDebugScreenState();
}

class _PdrDebugScreenState extends State<PdrDebugScreen> {
  PdrEngine get engine => widget.pdrEngine;

  final List<StepEvent> _recentStepEvents = [];
  StreamSubscription<StepEvent>? _stepSub;
  StreamSubscription<ProcessedAcceleration>? _accelSub;

  ProcessedAcceleration? _latestAccel;

  @override
  void initState() {
    super.initState();
    _stepSub = engine.stepStream.listen((event) {
      if (!mounted) return;
      setState(() {
        _recentStepEvents.insert(0, event);
        if (_recentStepEvents.length > 20) {
          _recentStepEvents.removeLast();
        }
      });
    });

    _accelSub = engine.debugAccelStream.listen((accel) {
      if (!mounted) return;
      setState(() {
        _latestAccel = accel;
      });
    });
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    _accelSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('PDR Diagnostics Monitor', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            tooltip: 'Clear Logs',
            onPressed: () => setState(() => _recentStepEvents.clear()),
          ),
        ],
      ),
      body: StreamBuilder<PdrState>(
        stream: engine.stateStream,
        initialData: engine.currentState,
        builder: (context, snapshot) {
          final state = snapshot.data ?? engine.currentState;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Sensor Pipeline Source & Status
              _buildSectionTitle('SENSOR PIPELINE SOURCE'),
              _buildSensorSourceCard(),
              const SizedBox(height: 16),

              // 2. Real-Time Signal Processing
              _buildSectionTitle('REAL-TIME GAIT SIGNALS (50-100 Hz)'),
              _buildLiveSignalsCard(),
              const SizedBox(height: 16),

              // 3. Step Validation Breakdown
              _buildSectionTitle('STEP DETECTOR CONFIDENCE BREAKDOWN'),
              _buildStepValidationCard(state),
              const SizedBox(height: 16),

              // 4. Recent Step Event Log
              _buildSectionTitle('RECENT ACCEPTED STEPS (${_recentStepEvents.length})'),
              _buildStepLogList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6),
      ),
    );
  }

  Widget _buildSensorSourceCard() {
    final isNative = engine.sensorManager.isUsingNative;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          _buildDebugRow(
            'Sensor Ingestion Mode:',
            isNative ? 'Native Android (Game Rotation Vector / 50-100Hz)' : 'Fallback (sensors_plus + AHRS)',
            valueColor: isNative ? Colors.lightGreenAccent : Colors.amberAccent,
          ),
          const Divider(color: Colors.white10),
          _buildDebugRow('Target Sampling Frequency:', '${engine.config.samplingRateHz.toStringAsFixed(0)} Hz'),
          _buildDebugRow('Bandpass Gait Filter:', '${engine.config.filterLowCutoffHz} Hz - ${engine.config.filterHighCutoffHz} Hz'),
          _buildDebugRow('Weinberg Calibration Factor (K):', engine.config.weinbergFactorK.toStringAsFixed(3)),
        ],
      ),
    );
  }

  Widget _buildLiveSignalsCard() {
    final accel = _latestAccel;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          _buildDebugRow(
            'Raw Magnitude:',
            accel != null ? '${accel.rawMagnitude.toStringAsFixed(2)} m/s²' : 'Waiting...',
          ),
          _buildDebugRow(
            'Filtered Vertical Accel:',
            accel != null ? '${accel.filteredVerticalAcceleration.toStringAsFixed(2)} m/s²' : 'Waiting...',
            valueColor: Colors.tealAccent,
          ),
          _buildDebugRow(
            'Filtered Magnitude Accel:',
            accel != null ? '${accel.filteredMagnitude.toStringAsFixed(2)} m/s²' : 'Waiting...',
          ),
          _buildDebugRow(
            'World Linear (East, North, Up):',
            accel != null
                ? '[${accel.worldLinAx.toStringAsFixed(2)}, ${accel.worldLinAy.toStringAsFixed(2)}, ${accel.worldLinAz.toStringAsFixed(2)}] m/s²'
                : 'Waiting...',
          ),
          _buildDebugRow(
            'Acceleration Variance (Energy):',
            accel != null ? '${accel.accelerationVariance.toStringAsFixed(4)} m²/s⁴' : 'Waiting...',
            valueColor: (accel != null && accel.accelerationVariance < engine.config.stationaryVarianceThreshold)
                ? Colors.amberAccent
                : Colors.lightGreenAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildStepValidationCard(PdrState state) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          _buildDebugRow('Step Confidence:', '${(state.stepConfidence * 100).toStringAsFixed(0)}%'),
          _buildDebugRow('Heading Confidence:', '${(state.headingConfidence * 100).toStringAsFixed(0)}%'),
          _buildDebugRow('Composite Confidence:', '${(state.overallConfidence * 100).toStringAsFixed(0)}%', valueColor: Colors.cyanAccent),
          _buildDebugRow('Refractory Lockout Period:', '${(engine.config.refractoryPeriodSeconds * 1000).toInt()} ms'),
          _buildDebugRow('Min Peak Prominence Threshold:', '${engine.config.minPeakProminence} m/s²'),
        ],
      ),
    );
  }

  Widget _buildStepLogList() {
    if (_recentStepEvents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: const Center(
          child: Text('No steps detected yet. Walk with the phone to generate events.', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentStepEvents.length,
      itemBuilder: (context, index) {
        final step = _recentStepEvents[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.tealAccent.withValues(alpha: 0.2),
                    child: Text(
                      '#${step.stepIndex}',
                      style: const TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'L: ${step.stepLength.toStringAsFixed(2)}m  •  ${step.headingDegrees.toStringAsFixed(0)}°  •  Δt: ${step.stepDuration.toStringAsFixed(2)}s',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Peak: ${step.peakAcceleration.toStringAsFixed(2)}  •  Prom: ${step.prominence.toStringAsFixed(2)} m/s²',
                        style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(step.confidence * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDebugRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

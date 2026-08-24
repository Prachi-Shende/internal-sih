import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../services/app_state.dart';
import '../../p1/resilience/models/gps_health.dart';
import '../../p1/resilience/models/positioning_mode.dart';

/// Developer & Judge Diagnostic Dashboard.
/// Provides a raw, high-fidelity real-time telemetry inspection of the P1 Resilient Positioning Subsystem.
class ResilienceDiagnosticScreen extends StatelessWidget {
  const ResilienceDiagnosticScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final snapshot = appState.p1Facade.getCurrentSnapshot();
    final res = snapshot.resilience;
    final mov = snapshot.movement;
    final pos = snapshot.position;
    final conn = snapshot.connectivity;
    final engine = appState.resilienceEngine;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate developer theme
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'P1 RESILIENCE DIAGNOSTICS',
          style: TextStyle(
            color: Colors.tealAccent,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.tealAccent),
            onPressed: () => engine.resetTestSession(),
            tooltip: 'Reset Session Telemetry',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Simulation Active Warning
            if (appState.isSimulationActive)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.science, color: Colors.amber),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'SIMULATION MODE ACTIVE — Inputs driven by Developer Sandbox',
                        style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () => appState.resetSimulation(),
                      child: const Text('RESET', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),

            // Section 1: System Core & Infrastructure Case
            _buildSectionHeader('1. INFRASTRUCTURE & POSITIONING MODE'),
            _buildCard([
              _buildMetricRow('Infrastructure Case', res.infrastructureCase.toUpperCase(), _getCaseColor(res.infrastructureCase)),
              _buildMetricRow('Operating Mode', res.mode.toUpperCase(), Colors.white),
              _buildMetricRow('System Health', res.systemStatusLabel, _getHealthColor(res.systemStatusLabel)),
              _buildMetricRow('Active Source', (pos.source ?? 'GPS').toUpperCase(), Colors.tealAccent),
              _buildMetricRow('Internet Connectivity', conn.isOnline ? 'ONLINE' : 'OFFLINE', conn.isOnline ? Colors.greenAccent : Colors.redAccent),
              _buildMetricRow('Active Comm Channel', conn.activeDeliveryChannel, Colors.cyanAccent),
            ]),

            const SizedBox(height: 16),

            // Section 2: Spatial Telemetry & Accuracy
            _buildSectionHeader('2. SPATIAL POSITION & ESTIMATE QUALITY'),
            _buildCard([
              _buildMetricRow('Latitude', pos.latitude?.toStringAsFixed(6) ?? 'N/A', Colors.white),
              _buildMetricRow('Longitude', pos.longitude?.toStringAsFixed(6) ?? 'N/A', Colors.white),
              _buildMetricRow('Uncertainty (Radius)', '${pos.uncertaintyMeters?.toStringAsFixed(1) ?? "N/A"} meters', Colors.amberAccent),
              _buildMetricRow('Confidence Rating', res.confidenceRating.toUpperCase(), _getConfidenceColor(res.confidenceRating)),
              _buildMetricRow('Absolute Fix?', pos.isAbsolute ? 'YES (GNSS/Anchor)' : 'NO (Dead Reckoning)', pos.isAbsolute ? Colors.greenAccent : Colors.orangeAccent),
              _buildMetricRow('Degraded Flag?', pos.isDegraded ? 'YES (Degraded)' : 'NO (Normal)', pos.isDegraded ? Colors.redAccent : Colors.greenAccent),
            ]),

            const SizedBox(height: 16),

            // Section 3: PDR Kinematics & IMU Sensors
            _buildSectionHeader('3. PEDESTRIAN DEAD RECKONING (PDR)'),
            _buildCard([
              _buildMetricRow('Motion State', mov.isStationary ? 'STATIONARY' : 'WALKING', mov.isStationary ? Colors.orangeAccent : Colors.greenAccent),
              _buildMetricRow('Step Count', '${mov.steps} steps', Colors.white),
              _buildMetricRow('Heading / Orientation', '${mov.headingDegrees.toStringAsFixed(1)}° (${mov.direction})', Colors.cyanAccent),
              _buildMetricRow('Cumulative Distance', '${mov.distanceMeters.toStringAsFixed(1)} m', Colors.white),
              _buildMetricRow('Walking Speed', '${mov.speedMps.toStringAsFixed(2)} m/s', Colors.white),
              _buildMetricRow('Estimated Stride Length', '${mov.strideLengthMeters.toStringAsFixed(2)} m', Colors.white),
              _buildMetricRow('Local Displacement (X, Y)', '(${mov.localX.toStringAsFixed(1)}m, ${mov.localY.toStringAsFixed(1)}m)', Colors.white70),
            ]),

            const SizedBox(height: 16),

            // Section 4: Wi-Fi WKNN Localization & Anchoring
            _buildSectionHeader('4. WI-FI WKNN & MAP ANCHORING'),
            _buildCard([
              _buildMetricRow('Wi-Fi Scanner Status', res.wifiAvailable ? 'SCANNING ACTIVE' : 'UNAVAILABLE', res.wifiAvailable ? Colors.greenAccent : Colors.redAccent),
              _buildMetricRow('Wi-Fi WKNN Localization', res.lastWifiAnchorStatus ?? 'INSUFFICIENT FINGERPRINT DATA', Colors.amberAccent),
              _buildMetricRow('Last Matched Anchor', res.lastMatchedAnchorId ?? 'NONE', Colors.white),
              _buildMetricRow('Map Constraint Snapping', res.isMapConstrained ? 'ACTIVE (Constrained to Walkable Graph)' : 'PASS-THROUGH', Colors.cyanAccent),
            ]),

            const SizedBox(height: 16),

            // Section 5: Offline Safety Queue & SyncManager
            _buildSectionHeader('5. SAFETY ENGINE & OFFLINE QUEUE'),
            _buildCard([
              _buildMetricRow('Pending Offline Queue', '${appState.pendingOfflineEventsCount} events', appState.pendingOfflineEventsCount > 0 ? Colors.amberAccent : Colors.greenAccent),
              _buildMetricRow('Durable Storage Backend', 'FileSafetyEventStore (Flash)', Colors.tealAccent),
              _buildMetricRow('Auto Sync Engine', conn.isOnline ? 'IDLE / READY' : 'QUEUED (Waiting for network)', conn.isOnline ? Colors.greenAccent : Colors.orangeAccent),
              _buildMetricRow('Emergency SOS State', appState.isEmergencyActive ? 'ACTIVE EMERGENCY' : 'NORMAL / STANDBY', appState.isEmergencyActive ? Colors.redAccent : Colors.greenAccent),
            ]),

            const SizedBox(height: 16),

            // Section 6: Recent Resilience State Events Log
            _buildSectionHeader('6. AUDIT LOG: RECENT RESILIENCE TRANSITIONS'),
            Container(
              height: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: engine.eventHistory.isEmpty
                  ? const Center(child: Text('No transition events recorded yet.', style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      itemCount: engine.eventHistory.length,
                      itemBuilder: (context, index) {
                        final evt = engine.eventHistory[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            '[${evt.timestamp.hour.toString().padLeft(2, '0')}:${evt.timestamp.minute.toString().padLeft(2, '0')}:${evt.timestamp.second.toString().padLeft(2, '0')}] ${evt.type.name.toUpperCase()} — ${evt.diagnosticInfo ?? ""}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.tealAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMetricRow(String label, String value, Color valColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: valColor, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCaseColor(String c) {
    if (c.contains('1')) return Colors.greenAccent;
    if (c.contains('2')) return Colors.yellowAccent;
    if (c.contains('3')) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Color _getHealthColor(String h) {
    if (h.toUpperCase().contains('FULL')) return Colors.greenAccent;
    if (h.toUpperCase().contains('DEGRADED')) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Color _getConfidenceColor(String c) {
    if (c.toUpperCase() == 'HIGH') return Colors.greenAccent;
    if (c.toUpperCase() == 'MEDIUM') return Colors.yellowAccent;
    return Colors.redAccent;
  }
}

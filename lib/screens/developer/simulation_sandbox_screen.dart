import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../../p1/resilience/models/gps_health.dart';
import '../../p1/resilience/models/positioning_mode.dart';

/// Developer Simulation Sandbox.
/// Allows deterministic testing of all combinations of GPS, Internet, PDR, and Wi-Fi
/// by directly feeding inputs into the live ResilienceEngine.
class SimulationSandboxScreen extends StatefulWidget {
  const SimulationSandboxScreen({Key? key}) : super(key: key);

  @override
  State<SimulationSandboxScreen> createState() => _SimulationSandboxScreenState();
}

class _SimulationSandboxScreenState extends State<SimulationSandboxScreen> {
  GpsHealth _selectedGps = GpsHealth.active;
  bool _isInternetOnline = true;
  bool _isPdrEnabled = true;
  bool _isWifiAvailable = true;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final snapshot = appState.p1Facade.getCurrentSnapshot();
    final res = snapshot.resilience;
    final conn = snapshot.connectivity;
    final pos = snapshot.position;

    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'SIMULATION SANDBOX',
          style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedGps = GpsHealth.active;
                _isInternetOnline = true;
                _isPdrEnabled = true;
                _isWifiAvailable = true;
              });
              appState.resetSimulation();
            },
            child: const Text('AUTO LIVE', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Simulation Active Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amberAccent),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science, color: Colors.amberAccent),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SIMULATION MODE', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Directly drives the underlying P1 Resilience State Machine.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Live Output Indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ACTIVE ENGINE STATE', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(res.infrastructureCase.toUpperCase(), style: const TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.teal.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: Text('SOURCE: ${(pos.source ?? "GPS").toUpperCase()}', style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Mode: ${res.mode.toUpperCase()}  |  Internet: ${conn.isOnline ? "ONLINE" : "OFFLINE"}  |  Channel: ${conn.activeDeliveryChannel}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // GPS Signal Toggle
            _buildControlSection(
              title: '1. GPS SATELLITE SIGNAL',
              child: Row(
                children: [
                  _buildOptionButton('ACTIVE', _selectedGps == GpsHealth.active, () {
                    setState(() => _selectedGps = GpsHealth.active);
                    appState.simulateGpsState(GpsHealth.active);
                  }),
                  const SizedBox(width: 8),
                  _buildOptionButton('DEGRADED', _selectedGps == GpsHealth.stale, () {
                    setState(() => _selectedGps = GpsHealth.stale);
                    appState.simulateGpsState(GpsHealth.stale);
                  }),
                  const SizedBox(width: 8),
                  _buildOptionButton('LOST', _selectedGps == GpsHealth.lost, () {
                    setState(() => _selectedGps = GpsHealth.lost);
                    appState.simulateGpsState(GpsHealth.lost);
                  }),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Internet Connectivity Toggle
            _buildControlSection(
              title: '2. INTERNET & CELLULAR CONNECTION',
              child: Row(
                children: [
                  _buildOptionButton('ONLINE', _isInternetOnline, () {
                    setState(() => _isInternetOnline = true);
                    appState.simulateInternetState(true);
                  }),
                  const SizedBox(width: 8),
                  _buildOptionButton('OFFLINE', !_isInternetOnline, () {
                    setState(() => _isInternetOnline = false);
                    appState.simulateInternetState(false);
                  }),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // PDR Sensor Kinematics
            _buildControlSection(
              title: '3. PDR INERTIAL SENSORS (IMU)',
              child: Row(
                children: [
                  _buildOptionButton('ENABLED', _isPdrEnabled, () {
                    setState(() => _isPdrEnabled = true);
                  }),
                  const SizedBox(width: 8),
                  _buildOptionButton('DISABLED', !_isPdrEnabled, () {
                    setState(() => _isPdrEnabled = false);
                  }),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Wi-Fi Scanner Availability
            _buildControlSection(
              title: '4. WI-FI LOCALIZATION / BEACONS',
              child: Row(
                children: [
                  _buildOptionButton('AVAILABLE', _isWifiAvailable, () {
                    setState(() => _isWifiAvailable = true);
                  }),
                  const SizedBox(width: 8),
                  _buildOptionButton('UNAVAILABLE', !_isWifiAvailable, () {
                    setState(() => _isWifiAvailable = false);
                  }),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Preset Buttons
            const Text('QUICK COMBINATION PRESETS', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedGps = GpsHealth.lost;
                        _isInternetOnline = true;
                      });
                      appState.simulateFourCase(2);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF374151), padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('Indoor Tunnel\n(GPS Lost, Net ON)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedGps = GpsHealth.active;
                        _isInternetOnline = false;
                      });
                      appState.simulateFourCase(3);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF374151), padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('Remote Mountain\n(GPS ON, Net OFF)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedGps = GpsHealth.lost;
                        _isInternetOnline = false;
                      });
                      appState.simulateFourCase(4);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF374151), padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('Total Blackout\n(GPS OFF, Net OFF)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.white)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildControlSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildOptionButton(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.amberAccent : const Color(0xFF111827),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? Colors.amberAccent : Colors.white24),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

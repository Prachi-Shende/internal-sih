import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';

/// Judge-friendly 4-Case Resilience Demonstration & Verification Screen.
/// Evaluates and demonstrates each resilience scenario against the live state machine.
class ResilienceDemoScreen extends StatelessWidget {
  const ResilienceDemoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final snapshot = appState.p1Facade.getCurrentSnapshot();
    final res = snapshot.resilience;
    final conn = snapshot.connectivity;
    final pos = snapshot.position;
    final queueCount = appState.pendingOfflineEventsCount;

    // Evaluate live cases based on current engine state
    final bool isCase1 = conn.isOnline && !pos.isDegraded && res.mode == 'gps';
    final bool isCase2 = conn.isOnline && (pos.isDegraded || res.mode == 'pdrFallback');
    final bool isCase3 = !conn.isOnline && !pos.isDegraded && res.mode == 'gps';
    final bool isCase4 = !conn.isOnline && (pos.isDegraded || res.mode == 'pdrFallback');

    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2541),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'RESILIENCE ENGINE DEMO',
          style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore, color: Colors.cyanAccent),
            tooltip: 'Reset to Live Auto State',
            onPressed: () => appState.resetSimulation(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Judge Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1C2541), Color(0xFF3A506B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TRAVARA RESILIENCE ENGINE', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        conn.isOnline ? (pos.isDegraded ? 'DEGRADED' : 'CONNECTED') : 'OFFLINE',
                        style: TextStyle(
                          color: conn.isOnline ? (pos.isDegraded ? Colors.amberAccent : Colors.tealAccent) : Colors.redAccent,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          res.infrastructureCase.toUpperCase(),
                          style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Colors.white24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildQuickBadge('Positioning', (pos.source ?? "GPS").toUpperCase(), Colors.white),
                      _buildQuickBadge('Communication', conn.isOnline ? 'ONLINE' : 'LOCAL QUEUE', conn.isOnline ? Colors.greenAccent : Colors.amberAccent),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildQuickBadge('GPS', res.gpsHealth.toUpperCase(), res.gpsHealth == 'active' ? Colors.greenAccent : Colors.redAccent),
                      _buildQuickBadge('PDR', res.pdrActive ? 'ACTIVE' : 'INACTIVE', res.pdrActive ? Colors.greenAccent : Colors.grey),
                      _buildQuickBadge('Wi-Fi', res.wifiAvailable ? 'AVAILABLE' : 'UNAVAILABLE', res.wifiAvailable ? Colors.greenAccent : Colors.grey),
                      _buildQuickBadge('Pending Events', '$queueCount', queueCount > 0 ? Colors.amberAccent : Colors.tealAccent),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'FOUR INFRASTRUCTURE CASES',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),

            // Case 1 Card
            _buildCaseCard(
              context: context,
              caseNumber: 1,
              title: 'CASE 1: GPS ACTIVE + INTERNET ONLINE',
              subtitle: 'Optimal Infrastructure (Primary GPS + Direct HTTP Ingestion)',
              isActive: isCase1,
              source: 'GPS (Accuracy ~3.8m)',
              channel: 'HTTP API (/location, /incident)',
              queueStatus: queueCount == 0 ? 'Drained (0 pending)' : '$queueCount queued',
              onSimulate: () => appState.simulateFourCase(1),
            ),

            // Case 2 Card
            _buildCaseCard(
              context: context,
              caseNumber: 2,
              title: 'CASE 2: GPS DEGRADED + INTERNET ONLINE',
              subtitle: 'Indoor / Tunnel (IMU PDR Dead Reckoning + Direct HTTP)',
              isActive: isCase2,
              source: 'PDR Kinematics / Wi-Fi WKNN',
              channel: 'HTTP API (/location, /incident)',
              queueStatus: queueCount == 0 ? 'Drained (0 pending)' : '$queueCount queued',
              onSimulate: () => appState.simulateFourCase(2),
            ),

            // Case 3 Card
            _buildCaseCard(
              context: context,
              caseNumber: 3,
              title: 'CASE 3: GPS ACTIVE + INTERNET OFFLINE',
              subtitle: 'Remote Area (GPS Active + Local Durable Queue on Flash)',
              isActive: isCase3,
              source: 'GPS Active',
              channel: 'OFFLINE_QUEUE (FileSafetyEventStore)',
              queueStatus: '$queueCount pending (Stored to disk)',
              onSimulate: () => appState.simulateFourCase(3),
            ),

            // Case 4 Card
            _buildCaseCard(
              context: context,
              caseNumber: 4,
              title: 'CASE 4: GPS LOST + INTERNET OFFLINE',
              subtitle: 'Total Blackout (PDR Dead Reckoning + Local Offline Queue)',
              isActive: isCase4,
              source: 'PDR Dead Reckoning / Wi-Fi',
              channel: 'OFFLINE_QUEUE (FileSafetyEventStore)',
              queueStatus: '$queueCount pending (Auto-syncs on reconnect)',
              onSimulate: () => appState.simulateFourCase(4),
            ),

            const SizedBox(height: 24),

            // State Transition Diagram
            const Text(
              'RESILIENCE STATE TRANSITION FLOWCHART',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2541),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  _buildFlowStep('GPS Active + Internet Online', 'Optimal Case 1', isCase1),
                  _buildFlowArrow('GPS Signal Drops (Indoor / Tunnel)'),
                  _buildFlowStep('PDR / Wi-Fi + Internet Online', 'Autonomous Case 2', isCase2),
                  _buildFlowArrow('Cellular / Wi-Fi Connectivity Lost'),
                  _buildFlowStep('PDR / Wi-Fi + Local Durable Store', 'Blackout Case 4', isCase4),
                  _buildFlowArrow('GPS Signal Recovered'),
                  _buildFlowStep('GPS Active + Local Queue', 'Anchored Case 3', isCase3),
                  _buildFlowArrow('Internet Restored → SyncManager Triggers'),
                  _buildFlowStep('GPS + Internet + Auto-Sync Complete', 'Restoration / Normal', isCase1 && queueCount == 0),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCaseCard({
    required BuildContext context,
    required int caseNumber,
    required String title,
    required String subtitle,
    required bool isActive,
    required String source,
    required String channel,
    required String queueStatus,
    required VoidCallback onSimulate,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? Colors.cyanAccent : Colors.white12,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isActive ? Colors.cyanAccent : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive ? Colors.greenAccent.withOpacity(0.2) : Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isActive ? Colors.greenAccent : Colors.white24),
                ),
                child: Text(
                  isActive ? 'ACTIVE' : 'STANDBY',
                  style: TextStyle(
                    color: isActive ? Colors.greenAccent : Colors.white60,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const Divider(color: Colors.white12, height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Source: $source', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text('Channel: $channel', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text('Queue: $queueStatus', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: onSimulate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? Colors.cyan : const Color(0xFF3A506B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                child: Text(isActive ? 'VERIFIED' : 'TEST CASE $caseNumber'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlowStep(String title, String tag, bool isHighlighted) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isHighlighted ? Colors.cyanAccent.withOpacity(0.15) : const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isHighlighted ? Colors.cyanAccent : Colors.white24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: isHighlighted ? Colors.cyanAccent : Colors.white, fontSize: 12, fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal)),
          Text(tag, style: TextStyle(color: isHighlighted ? Colors.cyanAccent : Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildFlowArrow(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        children: [
          const Icon(Icons.arrow_downward, color: Colors.cyanAccent, size: 14),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildQuickBadge(String title, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

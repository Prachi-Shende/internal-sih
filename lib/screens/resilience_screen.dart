import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../services/app_state.dart';
import '../services/models.dart';
import 'developer/resilience_demo_screen.dart';
import 'developer/resilience_diagnostic_screen.dart';

class ResilienceScreen extends StatelessWidget {
  const ResilienceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'System Resilience',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: appState.systemState == SystemState.normal ? AppColors.sage.withOpacity(0.1) : AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: appState.systemState == SystemState.normal ? AppColors.sage : AppColors.warning,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    appState.systemState == SystemState.normal ? Icons.check_circle : Icons.error_outline,
                    color: appState.systemState == SystemState.normal ? AppColors.primary : AppColors.warning,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    appState.systemState == SystemState.normal ? 'FULL RESILIENCE' : 'DEGRADED OPERATION',
                    style: TextStyle(
                      color: appState.systemState == SystemState.normal ? AppColors.primary : AppColors.warning,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            const Text(
              'LOCATION SENSORS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.2),
            ),
            const SizedBox(height: 16),
            _buildStatusRow('GPS', appState.systemState != SystemState.gpsDegraded && appState.systemState != SystemState.offline, Icons.satellite),
            _buildStatusRow('PDR (Pedestrian Dead Reckoning)', true, Icons.directions_walk),
            
            const SizedBox(height: 32),
            const Text(
              'COMMUNICATION',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.2),
            ),
            const SizedBox(height: 16),
            _buildStatusRow('Internet (4G/5G)', appState.communicationStatus.internet, Icons.wifi),
            _buildStatusRow('SMS Fallback', appState.communicationStatus.sms, Icons.message),
            _buildStatusRow('Peer Relay (BLE/Wi-Fi)', appState.communicationStatus.relay, Icons.radio),
            _buildStatusRow('Offline Queue', appState.communicationStatus.offlineQueue, Icons.storage),

            const SizedBox(height: 32),
            const Text(
              'ACTIVE CHANNEL',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.2),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flash_on, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    appState.communicationStatus.selectedChannel,
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Text(
              'GEO-FENCE STATUS (P2)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.2),
            ),
            const SizedBox(height: 16),
            _buildGeofenceBadge(appState.geofenceState),

            const SizedBox(height: 32),
            const Text(
              'ENGINE & JUDGE TOOLS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.2),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ResilienceDemoScreen()));
                    },
                    icon: const Icon(Icons.verified_user, size: 16, color: AppColors.primary),
                    label: const Text('4-Case Demo', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ResilienceDiagnosticScreen()));
                    },
                    icon: const Icon(Icons.developer_mode, size: 16, color: Colors.white),
                    label: const Text('Diagnostics', style: TextStyle(fontSize: 12, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
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

  Widget _buildStatusRow(String name, bool isOnline, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider),
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isOnline ? AppColors.sage.withOpacity(0.2) : AppColors.warning.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isOnline ? 'ONLINE' : 'OFFLINE',
              style: TextStyle(
                color: isOnline ? AppColors.sage : AppColors.warning,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGeofenceBadge(String state) {
    Color color;
    IconData icon;
    switch (state) {
      case 'INSIDE':
        color = AppColors.emergency;
        icon = Icons.warning_amber_rounded;
        break;
      case 'APPROACHING':
        color = AppColors.warning;
        icon = Icons.radar;
        break;
      default: // OUTSIDE
        color = AppColors.sage;
        icon = Icons.check_circle_outline;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('P2 Geospatial', style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
              Text(state, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}

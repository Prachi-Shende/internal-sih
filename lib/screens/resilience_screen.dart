import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../services/app_state.dart';
import '../services/models.dart';

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
}

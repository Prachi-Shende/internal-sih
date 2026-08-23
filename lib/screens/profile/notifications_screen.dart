import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../services/app_state.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Notifications', style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          _buildSwitchTile(
            'Risk Alerts', 
            'Push notifications when approaching high-risk areas', 
            appState.notifyRiskAlerts, 
            (val) => appState.updateNotificationPreferences(riskAlerts: val),
          ),
          _buildSwitchTile(
            'System Status', 
            'Alerts about internet connectivity and GPS precision', 
            appState.notifySystemStatus, 
            (val) => appState.updateNotificationPreferences(systemStatus: val),
          ),
          _buildSwitchTile(
            'Travel Tips', 
            'Occasional safety and cultural tips for your current region', 
            appState.notifyTravelTips, 
            (val) => appState.updateNotificationPreferences(travelTips: val),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5)),
        value: value,
        activeColor: AppColors.primary,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}


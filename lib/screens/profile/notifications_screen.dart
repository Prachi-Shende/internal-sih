import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _riskAlerts = true;
  bool _systemStatus = true;
  bool _travelTips = false;

  @override
  Widget build(BuildContext context) {
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
          _buildSwitchTile('Risk Alerts', 'Push notifications when approaching high-risk areas', _riskAlerts, (val) => setState(() => _riskAlerts = val)),
          _buildSwitchTile('System Status', 'Alerts about internet connectivity and GPS precision', _systemStatus, (val) => setState(() => _systemStatus = val)),
          _buildSwitchTile('Travel Tips', 'Occasional safety and cultural tips for your current region', _travelTips, (val) => setState(() => _travelTips = val)),
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

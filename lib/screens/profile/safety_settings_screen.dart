import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class SafetySettingsScreen extends StatefulWidget {
  const SafetySettingsScreen({Key? key}) : super(key: key);

  @override
  State<SafetySettingsScreen> createState() => _SafetySettingsScreenState();
}

class _SafetySettingsScreenState extends State<SafetySettingsScreen> {
  bool _autoSos = false;
  bool _loudAlarm = true;
  bool _hardwareTrigger = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Safety Assistance', style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('EMERGENCY TRIGGERS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            _buildSwitchTile(
              title: 'Auto-SOS on Disconnect',
              subtitle: 'Send SOS to contacts if device loses connection for more than 30 minutes in a high-risk area.',
              value: _autoSos,
              onChanged: (val) => setState(() => _autoSos = val),
            ),
            _buildSwitchTile(
              title: 'Hardware Button SOS',
              subtitle: 'Press the power button rapidly 5 times to trigger a silent SOS.',
              value: _hardwareTrigger,
              onChanged: (val) => setState(() => _hardwareTrigger = val),
            ),
            const SizedBox(height: 32),
            const Text('INCIDENT BEHAVIOR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            _buildSwitchTile(
              title: 'Loud Alarm',
              subtitle: 'Play a maximum volume alarm when you press "I FEEL UNSAFE".',
              value: _loudAlarm,
              onChanged: (val) => setState(() => _loudAlarm = val),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test SOS triggered')));
                },
                icon: const Icon(Icons.campaign, color: Colors.white),
                label: const Text('Test SOS Workflow', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({required String title, required String subtitle, required bool value, required Function(bool) onChanged}) {
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

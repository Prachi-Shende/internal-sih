import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class TrustedCompanionScreen extends StatefulWidget {
  const TrustedCompanionScreen({Key? key}) : super(key: key);

  @override
  State<TrustedCompanionScreen> createState() => _TrustedCompanionScreenState();
}

class _TrustedCompanionScreenState extends State<TrustedCompanionScreen> {
  bool _shareLocation = true;
  bool _shareStatus = true;
  bool _shareBattery = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Trusted Companion', style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield, color: AppColors.primary, size: 32),
                  SizedBox(height: 12),
                  Text(
                    'What is a Trusted Companion?',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'A trusted companion can monitor your safety status and location when you are traveling in high-risk areas. You are currently sharing data with 1 companion.',
                    style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('ACTIVE COMPANIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            _buildCompanionCard(),
            const SizedBox(height: 32),
            const Text('SHARING SETTINGS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            _buildSwitchTile('Live Location', 'Share real-time GPS coordinates', _shareLocation, (val) => setState(() => _shareLocation = val)),
            _buildSwitchTile('Safety Status', 'Share your current system state (Safe/Caution)', _shareStatus, (val) => setState(() => _shareStatus = val)),
            _buildSwitchTile('Battery Level', 'Alert companion if battery drops below 15%', _shareBattery, (val) => setState(() => _shareBattery = val)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundImage: NetworkImage('https://picsum.photos/seed/companion/100/100'),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Michael Traveler', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text('Active now', style: TextStyle(color: AppColors.sage, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined, color: AppColors.emergency),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sharing stopped')));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      value: value,
      activeColor: AppColors.primary,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}

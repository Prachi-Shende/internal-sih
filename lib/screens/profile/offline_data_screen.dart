import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class OfflineDataScreen extends StatelessWidget {
  const OfflineDataScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Offline Safety Data', style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Container(
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
                const Icon(Icons.cloud_done, color: AppColors.sage, size: 32),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('All systems synced', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      Text('Last synced 2 hours ago', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Syncing...')));
                  },
                  child: const Text('SYNC NOW', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('OFFLINE CACHE SETTINGS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          _buildDataCard(title: 'Hospitals & Police Stations', subtitle: '3,402 locations cached', icon: Icons.local_hospital),
          _buildDataCard(title: 'High-Risk Zones', subtitle: '12 active zones cached', icon: Icons.warning),
          _buildDataCard(title: 'Offline Translation Dictionary', subtitle: 'English, Indonesian, Japanese', icon: Icons.translate),
        ],
      ),
    );
  }

  Widget _buildDataCard({required String title, required String subtitle, required IconData icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          trailing: const Icon(Icons.check_circle, color: AppColors.sage, size: 20),
        ),
      ),
    );
  }
}


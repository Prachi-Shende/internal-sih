import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'profile/personal_info_screen.dart';
import 'profile/emergency_contacts_screen.dart';
import 'profile/trusted_companion_screen.dart';
import 'profile/safety_settings_screen.dart';
import 'profile/notifications_screen.dart';
import 'profile/location_permissions_screen.dart';
import 'profile/offline_maps_screen.dart';
import 'profile/offline_data_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Alex Traveler',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'alex.traveler@example.com',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            
            _buildSectionHeader('ACCOUNT'),
            _buildListTile(context, Icons.person, 'Personal Information', const PersonalInfoScreen()),
            _buildListTile(context, Icons.favorite, 'Emergency Contacts', const EmergencyContactsScreen()),
            _buildListTile(context, Icons.people, 'Trusted Companion', const TrustedCompanionScreen()),
            
            const SizedBox(height: 24),
            _buildSectionHeader('SAFETY'),
            _buildListTile(context, Icons.security, 'Safety Assistance', const SafetySettingsScreen()),
            _buildListTile(context, Icons.notifications, 'Notifications', const NotificationsScreen()),
            _buildListTile(context, Icons.location_on, 'Location Permissions', const LocationPermissionsScreen()),
            
            const SizedBox(height: 24),
            _buildSectionHeader('OFFLINE'),
            _buildListTile(context, Icons.map, 'Offline Maps', const OfflineMapsScreen()),
            _buildListTile(context, Icons.storage, 'Offline Safety Data', const OfflineDataScreen()),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, IconData icon, String title, Widget destination) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          );
        },
      ),
    );
  }
}

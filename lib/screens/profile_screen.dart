import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import 'profile/personal_info_screen.dart';
import 'profile/emergency_contacts_screen.dart';
import 'profile/trusted_companion_screen.dart';
import 'profile/safety_settings_screen.dart';
import 'profile/notifications_screen.dart';
import 'profile/location_permissions_screen.dart';
import 'profile/offline_maps_screen.dart';
import 'profile/offline_data_screen.dart';
import 'profile/incident_history_screen.dart';
import 'travel_history_screen.dart';
import 'developer/resilience_diagnostic_screen.dart';
import 'developer/resilience_demo_screen.dart';
import 'developer/simulation_sandbox_screen.dart';


class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    
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
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primary.withOpacity(0.2),
              child: Text(
                appState.userName.isNotEmpty ? appState.userName[0].toUpperCase() : 'E',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 48,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              appState.userName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              appState.userEmail.isNotEmpty ? appState.userEmail : 'Explorer Account',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
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
            _buildSectionHeader('HISTORY & REPORTS'),
            _buildListTile(context, Icons.route, 'Travel & Safety History', const TravelHistoryScreen()),
            _buildListTile(context, Icons.history, 'Incident History', const IncidentHistoryScreen()),
            _buildActionTile(
              context,
              Icons.picture_as_pdf,
              'Export Safety Passport (PDF)',
              () async {
                final url = Uri.parse(ApiService.getPdfReportUrl(
                  userName: appState.userName.isNotEmpty ? appState.userName : 'Explorer',
                  userEmail: appState.userEmail.isNotEmpty ? appState.userEmail : 'explorer@travara.app',
                ));
                try {
                  final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
                  if (!launched) {
                    await launchUrl(url, mode: LaunchMode.inAppBrowserView);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not open PDF: $e')),
                    );
                  }
                }
              },
            ),

            const SizedBox(height: 24),
            _buildSectionHeader('OFFLINE'),
            _buildListTile(context, Icons.map, 'Offline Maps', const OfflineMapsScreen()),
            _buildListTile(context, Icons.storage, 'Offline Safety Data', const OfflineDataScreen()),

            const SizedBox(height: 24),
            _buildSectionHeader('DEVELOPER & JUDGE LAB'),
            _buildListTile(context, Icons.verified_user, 'Resilience 4-Case Demo', const ResilienceDemoScreen()),
            _buildListTile(context, Icons.developer_mode, 'P1 Sensor Diagnostics & Telemetry', const ResilienceDiagnosticScreen()),
            _buildListTile(context, Icons.science, 'Developer Simulation Sandbox', const SimulationSandboxScreen()),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout, color: AppColors.emergency),
                label: const Text('Sign Out', style: TextStyle(color: AppColors.emergency, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.emergency),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
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
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('PDF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}


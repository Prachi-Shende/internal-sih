import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_colors.dart';

class LocationPermissionsScreen extends StatefulWidget {
  const LocationPermissionsScreen({Key? key}) : super(key: key);

  @override
  State<LocationPermissionsScreen> createState() => _LocationPermissionsScreenState();
}

class _LocationPermissionsScreenState extends State<LocationPermissionsScreen> {
  String _gpsStatus = 'Checking...';
  Color _gpsColor = AppColors.textSecondary;

  @override
  void initState() {
    super.initState();
    _checkLivePermissions();
  }

  Future<void> _checkLivePermissions() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _gpsStatus = 'Service Disabled';
          _gpsColor = AppColors.emergency;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      setState(() {
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          _gpsStatus = 'Granted (Live)';
          _gpsColor = AppColors.primary;
        } else if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          _gpsStatus = 'Denied (Live)';
          _gpsColor = AppColors.emergency;
        } else {
          _gpsStatus = 'Unknown';
          _gpsColor = AppColors.warning;
        }
      });
    } catch (e) {
      setState(() {
        _gpsStatus = 'Unavailable';
        _gpsColor = AppColors.warning;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Location Permissions', style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          const Text('SYSTEM PERMISSIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          _buildPermissionCard(
            title: 'Precise Location (GPS)',
            status: _gpsStatus,
            icon: Icons.gps_fixed,
            color: _gpsColor,
          ),
          _buildPermissionCard(
            title: 'Background Location',
            status: 'System Managed',
            icon: Icons.location_on,
            color: AppColors.primary,
          ),
          _buildPermissionCard(
            title: 'Bluetooth Scanning',
            status: 'Denied (Mock)',
            icon: Icons.bluetooth,
            color: AppColors.emergency,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your GPS status is now dynamically fetched live from your device. Background and Bluetooth are currently mock fields for the prototype.',
                    style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({required String title, required String status, required IconData icon, required Color color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          Icon(icon, color: AppColors.textSecondary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

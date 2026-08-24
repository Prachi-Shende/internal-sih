import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../services/app_state.dart';
import '../services/mock_data.dart';
import '../services/models.dart';
import 'incident_timeline_screen.dart';

class SafetyAssistScreen extends StatefulWidget {
  const SafetyAssistScreen({Key? key}) : super(key: key);

  @override
  State<SafetyAssistScreen> createState() => _SafetyAssistScreenState();
}

class _SafetyAssistScreenState extends State<SafetyAssistScreen> {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().activateSafetyAssist();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final locations = MockData.safeLocations;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: () {
            // Keep emergency active so other screens/tabs show CRITICAL until explicitly resolved!
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'SAFETY ASSIST',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        actions: [
          if (appState.isEmergencyActive)
            TextButton.icon(
              onPressed: () {
                context.read<AppState>().resolveIncident();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Safety alert resolved. Status returned to normal.')),
                );
              },
              icon: const Icon(Icons.check_circle_outline, color: AppColors.sage, size: 18),
              label: const Text(
                'I AM SAFE NOW',
                style: TextStyle(color: AppColors.sage, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "You don't have to explain anything. Let's get you somewhere safer.",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 24),
              
              // Live position & system telemetry banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.emergency.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: AppColors.emergency, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('EMERGENCY SOS ACTIVE', style: TextStyle(fontSize: 11, color: AppColors.emergency, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const SizedBox(height: 2),
                          Text(
                            '${appState.currentLocation.source} fix (${appState.currentLocation.confidence.name} confidence)',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'RANKED SAFE HAVENS (SAFEST CHOICE FIRST)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Render Safe Locations ranked dynamically by P3 SafeHavenEngine
              for (int i = 0; i < locations.length; i++)
                _buildSafeLocationCard(context, locations[i], isBest: i == 0),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => IncidentTimelineScreen(
                          safeLocation: locations.isNotEmpty ? locations.first : null,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emergency,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('TRIGGER EMERGENCY SOS'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafeLocationCard(BuildContext context, SafeLocation location, {required bool isBest}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: isBest ? Border.all(color: AppColors.sage, width: 2.5) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isBest)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.sage.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '⭐ BEST OPTION (SAFEST)',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  )
                else
                  Text(
                    location.type.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                
                // Safe Arrival Score Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (location.score >= 80 ? AppColors.sage : AppColors.warning).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'SCORE: ${location.score} / 100',
                    style: TextStyle(
                      color: location.score >= 80 ? AppColors.primary : AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    location.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${location.distance.toInt()} m',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, size: 14, color: AppColors.sage),
                const SizedBox(width: 4),
                Text(location.type, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(width: 12),
                if (location.isOpen) ...[
                  const Icon(Icons.access_time, size: 14, color: AppColors.sage),
                  const SizedBox(width: 4),
                  const Text('Open 24/7', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ]
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${location.lat},${location.lon}&travelmode=walking');
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    debugPrint('Could not launch map: $e');
                  }
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => IncidentTimelineScreen(safeLocation: location),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isBest ? AppColors.primary : AppColors.sage,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'START NAVIGATION (${location.distance.toInt()}m)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

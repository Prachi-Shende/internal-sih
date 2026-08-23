import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../components/buttons.dart';
import '../components/cards.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: () {
            context.read<AppState>().resolveIncident();
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
              
              // Current state context (StatusCard)
              StatusCard(
                state: context.watch<AppState>().systemState,
                risk: context.watch<AppState>().currentRisk,
              ),

              const SizedBox(height: 32),
              
              const Text(
                'SAFER PLACES NEARBY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Safe places list
              ...MockData.safeLocations.map((location) => _buildSafeLocationCard(context, location)).toList(),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                     Navigator.of(context).push(MaterialPageRoute(builder: (_) => IncidentTimelineScreen(safeLocation: MockData.safeLocations.isNotEmpty ? MockData.safeLocations.first : null)));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emergency,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('EMERGENCY SOS'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafeLocationCard(BuildContext context, SafeLocation location) {
    bool isBest = location.score >= 90;
    
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
        border: isBest ? Border.all(color: AppColors.sage, width: 2) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isBest)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.sage.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'BEST OPTION',
                  style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    location.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
                Text(
                  '${location.distance.toInt()} m',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, size: 14, color: AppColors.sage),
                const SizedBox(width: 4),
                Text(location.type, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(width: 12),
                if (location.isOpen) ...[
                  const Icon(Icons.access_time, size: 14, color: AppColors.sage),
                  const SizedBox(width: 4),
                  const Text('Open now', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
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
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => IncidentTimelineScreen(safeLocation: location)));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('START NAVIGATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

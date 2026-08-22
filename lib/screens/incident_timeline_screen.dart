import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../services/app_state.dart';
import '../services/mock_data.dart';

class IncidentTimelineScreen extends StatelessWidget {
  const IncidentTimelineScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'INCIDENT TIMELINE',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.emergency.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.emergency.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.radio, color: AppColors.emergency, size: 32),
                  const SizedBox(height: 12),
                  const Text(
                    'ACTIVE EMERGENCY',
                    style: TextStyle(
                      color: AppColors.emergency,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Communicating via Relay',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Timeline
            ...MockData.mockTimeline.map((event) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: event.state == 'emergency' ? AppColors.emergency : AppColors.sage,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getIconData(event.icon),
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        Container(
                          height: 40,
                          width: 2,
                          color: AppColors.divider,
                          margin: const EdgeInsets.only(top: 8),
                        )
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${event.time.hour}:${event.time.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            event.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: event.state == 'emergency' ? AppColors.emergency : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            event.description,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  context.read<AppState>().resolveIncident();
                  // Pop back twice to get out of Safety Assist
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.sage, width: 2),
                ),
                child: const Text('RESOLVE INCIDENT', style: TextStyle(color: AppColors.sage)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'map_pin_off':
        return Icons.location_off;
      case 'navigation':
        return Icons.navigation;
      case 'alert_circle':
        return Icons.error_outline;
      default:
        return Icons.circle;
    }
  }
}

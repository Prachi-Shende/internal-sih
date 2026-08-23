import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../services/app_state.dart';
import '../services/models.dart';
import '../services/mock_data.dart';
import 'safety_assist_screen.dart';

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Your Safety',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Risk Level Radial Visual
            Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: appState.currentRisk == RiskLevel.low 
                      ? AppColors.sage.withOpacity(0.1) 
                      : AppColors.warning.withOpacity(0.1),
                  border: Border.all(
                    color: appState.currentRisk == RiskLevel.low 
                        ? AppColors.sage 
                        : AppColors.warning,
                    width: 4,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'CURRENT RISK',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _riskLabel(appState.riskAssessment.risk),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: appState.currentRisk == RiskLevel.low ? AppColors.primary : AppColors.warning,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Score: ${appState.riskAssessment.score}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            const Text(
              'Why this assessment?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            
            ...appState.riskAssessment.reasons.map(
              (reason) => _buildReasonRow(
                _iconForReason(reason),
                reason,
                appState.currentRisk == RiskLevel.low,
              ),
            ),

            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield, color: AppColors.sage),
                      const SizedBox(width: 8),
                      const Text('Nearest Safe Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(MockData.safeLocations.first.name, style: const TextStyle(fontSize: 18, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('${MockData.safeLocations.first.distance.toInt()} m away • ${MockData.safeLocations.first.type}', style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),

            const SizedBox(height: 32),
            
            // Floating Safety Assist action
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SafetyAssistScreen()));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.security, color: AppColors.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('FEELING UNSAFE?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textSecondary, letterSpacing: 1)),
                          SizedBox(height: 4),
                          Text('Let us help you reach a safer place.', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.primary),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  String _riskLabel(RiskLevel risk) {
    switch (risk) {
      case RiskLevel.critical:
        return 'CRITICAL';
      case RiskLevel.high:
        return 'HIGH';
      case RiskLevel.medium:
        return 'MEDIUM';
      case RiskLevel.low:
        return 'LOW';
      case RiskLevel.unknown:
        return 'UNKNOWN';
    }
  }

  IconData _iconForReason(String reason) {
    final lower = reason.toLowerCase();
    if (lower.contains('incident')) return Icons.people;
    if (lower.contains('night') || lower.contains('time')) return Icons.nightlight_round;
    if (lower.contains('isolat')) return Icons.person_off;
    if (lower.contains('route') || lower.contains('deviat')) return Icons.alt_route;
    if (lower.contains('unsafe') || lower.contains('user')) return Icons.warning;
    return Icons.check_circle;
  }

  Widget _buildReasonRow(IconData icon, String reason, bool isPositive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPositive ? AppColors.sage.withOpacity(0.1) : AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isPositive ? AppColors.sage : AppColors.warning, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              reason,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
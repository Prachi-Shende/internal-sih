import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../services/app_state.dart';
import '../services/models.dart';
import '../services/mock_data.dart';
import 'safety_assist_screen.dart';

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({Key? key}) : super(key: key);

  String _getRiskText(RiskLevel risk) {
    switch (risk) {
      case RiskLevel.low: return 'LOW';
      case RiskLevel.medium: return 'MEDIUM';
      case RiskLevel.high: return 'HIGH';
      case RiskLevel.critical: return 'CRITICAL';
      default: return 'UNKNOWN';
    }
  }

  Color _getRiskColor(RiskLevel risk) {
    switch (risk) {
      case RiskLevel.low: return AppColors.primary;
      case RiskLevel.medium: return AppColors.warning;
      case RiskLevel.high: return Colors.orange; // High risk color
      case RiskLevel.critical: return AppColors.emergency;
      default: return AppColors.textSecondary;
    }
  }

  Color _getRiskBgColor(RiskLevel risk) {
    switch (risk) {
      case RiskLevel.low: return AppColors.sage;
      case RiskLevel.medium: return AppColors.warning;
      case RiskLevel.high: return Colors.orange;
      case RiskLevel.critical: return AppColors.emergency;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    
    final riskText = _getRiskText(appState.currentRisk);
    final riskColor = _getRiskColor(appState.currentRisk);
    final riskBgColor = _getRiskBgColor(appState.currentRisk).withOpacity(0.1);

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
                  color: riskBgColor,
                  border: Border.all(
                    color: _getRiskBgColor(appState.currentRisk),
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
                      riskText,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: riskColor,
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
            
            _buildReasonRow(Icons.location_on, 'Location Confidence', 'High', true),
            _buildReasonRow(Icons.people, 'Reported Incidents', 'Very low in this area', true),
            _buildReasonRow(Icons.wb_sunny, 'Time of Day', 'Daylight hours', true),
            if (appState.currentRisk != RiskLevel.low)
               _buildReasonRow(Icons.warning, 'Risk Factor', 'Proximity to hotspot', false),

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

  Widget _buildReasonRow(IconData icon, String title, String value, bool isPositive) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(value, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

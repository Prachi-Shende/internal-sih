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
      case RiskLevel.low: return 'NORMAL';
      case RiskLevel.medium: return 'CAUTION';
      case RiskLevel.high: return 'SAFETY CONCERN';
      case RiskLevel.critical: return 'CRITICAL';
      default: return 'NORMAL';
    }
  }

  Color _getRiskColor(RiskLevel risk) {
    switch (risk) {
      case RiskLevel.low: return AppColors.primary;
      case RiskLevel.medium: return AppColors.warning;
      case RiskLevel.high: return Colors.orange;
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

  IconData _getIconForReason(String reason) {
    final lower = reason.toLowerCase();
    if (lower.contains('hotspot') || lower.contains('crime') || lower.contains('incident')) {
      return Icons.warning_amber_rounded;
    }
    if (lower.contains('degraded') || lower.contains('pdr') || lower.contains('gps') || lower.contains('confidence')) {
      return Icons.gps_off;
    }
    if (lower.contains('night') || lower.contains('period') || lower.contains('hours')) {
      return Icons.nights_stay;
    }
    if (lower.contains('deviated') || lower.contains('route') || lower.contains('pause')) {
      return Icons.alt_route;
    }
    if (lower.contains('unsafe') || lower.contains('sos')) {
      return Icons.contact_support;
    }
    return Icons.shield;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final assessment = appState.riskAssessment;
    
    final riskText = _getRiskText(assessment.risk);
    final riskColor = _getRiskColor(assessment.risk);
    final riskBgColor = _getRiskBgColor(assessment.risk).withOpacity(0.1);

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
                'RESOLVE',
                style: TextStyle(color: AppColors.sage, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (appState.isEmergencyActive)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.emergency.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.emergency.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.emergency),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'EMERGENCY SOS IS ACTIVE',
                        style: TextStyle(color: AppColors.emergency, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.8),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.read<AppState>().resolveIncident(),
                      child: const Text('I AM SAFE NOW', style: TextStyle(color: AppColors.sage, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
              ),

            // Risk Level & Numeric Score Radial Visual
            Center(
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: riskBgColor,
                  border: Border.all(
                    color: _getRiskBgColor(assessment.risk),
                    width: 4,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'SYSTEM STATE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      riskText,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: riskColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: riskColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'SCORE: ${assessment.score} / 100',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: riskColor,
                          letterSpacing: 0.8,
                        ),
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
            
            // Dynamic reason list generated from live P1 & P2 telemetry signals
            ...assessment.reasons.map((reason) {
              final isWarning = assessment.risk != RiskLevel.low;
              final icon = _getIconForReason(reason);
              return _buildReasonRow(icon, 'Active Signal Factor', reason, !isWarning);
            }).toList(),

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
                    children: const [
                      Icon(Icons.shield, color: AppColors.sage),
                      SizedBox(width: 8),
                      Text('Nearest Safe Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(MockData.safeLocations.first.name, style: const TextStyle(fontSize: 18, color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
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
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

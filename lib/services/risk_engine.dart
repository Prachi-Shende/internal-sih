import 'models.dart';

/// Deterministic, explainable risk scoring.
///
/// Risk = Crime Hotspot + Time + Isolation + Route Deviation + User Signal
///
/// Design note: route deviation is intentionally NEVER scored on its own.
/// It only contributes when paired with another live risk factor (an
/// active hotspot, night-time hours, or isolation). A tourist wandering
/// off-route in a safe, busy area at 2pm should not be flagged as risky.
class RiskEngine {
  RiskEngine._();

  // Point budgets per factor, out of a 100-point total.
  static const int _maxHotspotScore = 45;
  static const int _maxTimeScore = 15;
  static const int _maxIsolationScore = 15;
  static const int _maxRouteDeviationScore = 10;
  static const int _maxUserSignalScore = 40;

  /// Route deviation only "counts" past this distance.
  static const double _routeDeviationThresholdMeters = 200;

  /// Hours considered low-activity / night-time.
  static const int _nightStartHour = 22; // 10 PM
  static const int _nightEndHour = 5; // 5 AM

  static RiskAssessment assess({
    Hotspot? nearbyHotspot,
    required DateTime currentTime,
    bool isIsolated = false,
    double? routeDeviationMeters,
    bool userReportedUnsafe = false,
  }) {
    int score = 0;
    final List<String> reasons = [];

    // 1. Crime hotspot contribution
    final hotspotPoints = nearbyHotspot != null ? _hotspotScore(nearbyHotspot) : 0;
    if (hotspotPoints > 0) {
      score += hotspotPoints;
      reasons.add(
        '${nearbyHotspot!.reportedIncidents} reported incidents nearby '
        '(${nearbyHotspot.recentIncidents} recent)',
      );
    }

    // 2. Time of day contribution
    final isNight = _isNightTime(currentTime);
    if (isNight) {
      score += _maxTimeScore;
      reasons.add('Low activity period (night hours)');
    }

    // 3. Isolation contribution
    if (isIsolated) {
      score += _maxIsolationScore;
      reasons.add('Isolated area with low foot traffic');
    }

    // 4. Route deviation — only counts alongside another active risk factor
    final hasOtherRiskFactor = hotspotPoints > 0 || isNight || isIsolated;
    if (routeDeviationMeters != null &&
        routeDeviationMeters > _routeDeviationThresholdMeters &&
        hasOtherRiskFactor) {
      score += _maxRouteDeviationScore;
      reasons.add('Deviated ${routeDeviationMeters.toInt()}m from planned route');
    }

    // 5. Explicit user signal (e.g. "I Feel Unsafe" button)
    if (userReportedUnsafe) {
      score += _maxUserSignalScore;
      reasons.add('User indicated feeling unsafe');
    }

    score = score.clamp(0, 100);

    return RiskAssessment(
      risk: _levelForScore(score),
      score: score,
      reasons: reasons.isEmpty ? ['No significant risk factors detected'] : reasons,
    );
  }

  static int _hotspotScore(Hotspot h) {
    int base;
    switch (h.risk) {
      case RiskLevel.critical:
        base = _maxHotspotScore;
        break;
      case RiskLevel.high:
        base = (_maxHotspotScore * 0.75).round();
        break;
      case RiskLevel.medium:
        base = (_maxHotspotScore * 0.45).round();
        break;
      case RiskLevel.low:
        base = (_maxHotspotScore * 0.15).round();
        break;
      case RiskLevel.unknown:
        base = 0;
        break;
    }

    // Recency weighting: a cluster of *recent* incidents matters more
    // than the same count spread out over a long historical period.
    if (h.recentIncidents >= 3) {
      base = (base * 1.1).round().clamp(0, _maxHotspotScore);
    }

    return base;
  }

  static bool _isNightTime(DateTime t) {
    return t.hour >= _nightStartHour || t.hour < _nightEndHour;
  }

  static RiskLevel _levelForScore(int score) {
    if (score >= 75) return RiskLevel.critical;
    if (score >= 50) return RiskLevel.high;
    if (score >= 25) return RiskLevel.medium;
    return RiskLevel.low;
  }
}
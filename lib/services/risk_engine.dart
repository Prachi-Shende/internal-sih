import 'models.dart';

/// Refined 5-Factor Risk Scoring Architecture grounded in live P1 & P2 telemetry signals.
/// 
/// Evaluates:
/// 1. Crime & Geofence Threat (P2 Input — Max 45 pts)
/// 2. Position Uncertainty & Sensor Degradation (P1 Input — Max 15 pts)
/// 3. Time of Day & Environmental Context (System Input — Max 15 pts)
/// 4. Kinematic & Route Anomaly (P1 Route Input — Max 10 pts)
/// 5. Explicit User SOS Signal (UI Event — Max 40 pts)
class RiskEngine {
  RiskEngine._();

  static const int _maxGeofenceScore = 45;
  static const int _maxUncertaintyScore = 15;
  static const int _maxTimeScore = 15;
  static const int _maxAnomalyScore = 10;
  static const int _maxUserSignalScore = 40;

  static const double _routeDeviationThresholdMeters = 150.0;
  static const int _nightStartHour = 22; // 10 PM
  static const int _nightEndHour = 5;    // 5 AM

  static RiskAssessment assess(TelemetryData telemetry) {
    int score = 0;
    final List<String> reasons = [];

    // 1. Crime & Geofence Threat (P2 Input — Max 45 pts)
    int geofencePts = 0;
    if (telemetry.geofenceState == 'INSIDE') {
      geofencePts = _maxGeofenceScore;
      final hotspotName = telemetry.nearbyHotspot?.name ?? 'reported crime hotspot';
      final incCount = telemetry.reportedIncidents > 0 ? telemetry.reportedIncidents : 5;
      reasons.add('Inside $hotspotName ($incCount reported incidents)');
    } else if (telemetry.geofenceState == 'APPROACHING') {
      final dist = telemetry.hotspotDistanceMeters.clamp(150.0, 300.0);
      final factor = (300.0 - dist) / 150.0; // 1.0 at 150m, 0.0 at 300m
      geofencePts = (25 + (20 * factor)).round().clamp(15, 35);
      reasons.add('Approaching crime hotspot (${telemetry.hotspotDistanceMeters.round()}m away)');
    } else if (telemetry.nearbyHotspot != null && telemetry.hotspotDistanceMeters > 0 && telemetry.hotspotDistanceMeters < 500) {
      final dist = telemetry.hotspotDistanceMeters;
      if (dist < 300) {
        geofencePts = 15;
        reasons.add('In proximity of active hotspot zone (${dist.round()}m)');
      }
    }
    score += geofencePts;

    // 2. Positioning Uncertainty & Sensor Degradation (P1 Input — Max 15 pts)
    int uncertaintyPts = 0;
    if (telemetry.isDegraded || telemetry.locationSource.toUpperCase() == 'PDR') {
      if (telemetry.uncertaintyMeters > 50) {
        uncertaintyPts = _maxUncertaintyScore;
        reasons.add('Location fix degraded (GPS lost, ±${telemetry.uncertaintyMeters.round()}m uncertainty)');
      } else if (telemetry.uncertaintyMeters > 20 || telemetry.locationConfidence == LocationConfidence.low) {
        uncertaintyPts = (_maxUncertaintyScore * 0.6).round();
        reasons.add('Low location confidence from PDR sensor fusion');
      } else {
        uncertaintyPts = 5;
        reasons.add('Operating on dead-reckoning (PDR) fallback');
      }
    }
    score += uncertaintyPts;

    // 3. Time of Day & Environmental Context (System Input — Max 15 pts)
    final isNight = _isNightTime(telemetry.currentTime);
    if (isNight) {
      score += _maxTimeScore;
      reasons.add('Low-activity period (Night hours: 10 PM - 5 AM)');
    }

    // 4. Kinematic & Route Anomaly (P1 Input — Max 10 pts)
    final hasActiveThreat = geofencePts > 0 || isNight || uncertaintyPts > 0;
    int anomalyPts = 0;
    if (telemetry.routeDeviationMeters != null &&
        telemetry.routeDeviationMeters! > _routeDeviationThresholdMeters &&
        hasActiveThreat) {
      anomalyPts = _maxAnomalyScore;
      reasons.add('Deviated ${telemetry.routeDeviationMeters!.round()}m from safe navigation route');
    } else if (telemetry.isStationary && geofencePts > 0) {
      anomalyPts = 5;
      reasons.add('Stationary pause detected near high-risk zone');
    }
    score += anomalyPts;

    // 5. Explicit User Signal (UI Event — Max 40 pts)
    if (telemetry.userReportedUnsafe) {
      score += _maxUserSignalScore;
      reasons.add('User manually triggered "I Feel Unsafe" / Emergency SOS');
    }

    score = score.clamp(0, 100);

    return RiskAssessment(
      risk: _levelForScore(score),
      score: score,
      reasons: reasons.isEmpty ? ['No active risk factors detected'] : reasons,
    );
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

import 'dart:math';

import '../../pdr/utils/geo_utils.dart';
import '../models/localization_anchor.dart';
import '../models/position_source.dart';
import '../models/wifi_fingerprint.dart';

/// Result of evaluating an observed Wi-Fi fingerprint against candidate anchors.
class AnchorMatchResult {
  /// The closest matching localization landmark (or synthesized WKNN anchor).
  final LocalizationAnchor? matchedAnchor;

  /// Estimated WGS-84 Latitude (from best anchor or WKNN centroid).
  final double? estimatedLatitude;

  /// Estimated WGS-84 Longitude (from best anchor or WKNN centroid).
  final double? estimatedLongitude;

  /// Normalized similarity score [0.0 to 1.0].
  final double similarityScore;

  /// Calibrated confidence of this match [0.0 to 1.0].
  final double confidence;

  /// Estimated horizontal uncertainty in meters.
  final double uncertaintyMeters;

  /// Whether the match satisfied all threshold constraints and is accepted.
  final bool isAccepted;

  /// Number of common Access Point BSSIDs between observation and anchor(s).
  final int apOverlapCount;

  /// Number of qualifying candidate anchors considered.
  final int matchedCandidatesCount;

  /// Diagnostic explanation if the match was rejected or degraded.
  final String? rejectionReason;

  const AnchorMatchResult({
    this.matchedAnchor,
    this.estimatedLatitude,
    this.estimatedLongitude,
    required this.similarityScore,
    required this.confidence,
    required this.uncertaintyMeters,
    required this.isAccepted,
    required this.apOverlapCount,
    this.matchedCandidatesCount = 1,
    this.rejectionReason,
  });

  /// Factory for a rejected match attempt.
  factory AnchorMatchResult.rejected({
    LocalizationAnchor? candidate,
    double similarityScore = 0.0,
    int apOverlapCount = 0,
    int matchedCandidatesCount = 0,
    required String reason,
  }) {
    return AnchorMatchResult(
      matchedAnchor: candidate,
      estimatedLatitude: candidate?.latitude,
      estimatedLongitude: candidate?.longitude,
      similarityScore: similarityScore,
      confidence: 0.0,
      uncertaintyMeters: 50.0,
      isAccepted: false,
      apOverlapCount: apOverlapCount,
      matchedCandidatesCount: matchedCandidatesCount,
      rejectionReason: reason,
    );
  }

  @override
  String toString() {
    if (isAccepted && (matchedAnchor != null || estimatedLatitude != null)) {
      final latStr = (estimatedLatitude ?? matchedAnchor?.latitude)?.toStringAsFixed(6);
      final lonStr = (estimatedLongitude ?? matchedAnchor?.longitude)?.toStringAsFixed(6);
      return 'AnchorMatchResult(ACCEPTED @ $latStr, $lonStr, Score: ${(similarityScore * 100).toStringAsFixed(1)}%, Conf: ${(confidence * 100).toStringAsFixed(0)}%, ±${uncertaintyMeters.toStringAsFixed(1)}m, APs: $apOverlapCount, K: $matchedCandidatesCount)';
    }
    return 'AnchorMatchResult(REJECTED: $rejectionReason, Score: ${(similarityScore * 100).toStringAsFixed(1)}%, APs: $apOverlapCount)';
  }
}

/// Internal helper for candidate scoring in WKNN.
class _CandidateScore {
  final LocalizationAnchor anchor;
  final double score;
  final int commonAps;

  _CandidateScore({
    required this.anchor,
    required this.score,
    required this.commonAps,
  });
}

/// Explainable, deterministic Wi-Fi fingerprint matching engine using Jaccard AP overlap & RSSI distance
/// with Weighted K-Nearest Neighbor (WKNN) spatial centroid estimation.
class WifiFingerprintMatcher {
  /// Minimum normalized similarity score required to accept an anchor match.
  final double matchThreshold;

  /// Minimum number of identical BSSIDs that must be shared between observation and anchor.
  final int minApOverlapCount;

  /// Maximum RSSI delta (dBm) beyond which two signals are considered completely uncorrelated.
  final double maxRssiDeltaDbm;

  const WifiFingerprintMatcher({
    this.matchThreshold = 0.70,
    this.minApOverlapCount = 2,
    this.maxRssiDeltaDbm = 35.0,
  });

  /// Evaluates an observed fingerprint against a list of candidate anchors (1-Nearest Neighbor).
  AnchorMatchResult match({
    required WifiFingerprint observed,
    required List<LocalizationAnchor> candidateAnchors,
  }) {
    return matchKnn(
      observed: observed,
      candidateAnchors: candidateAnchors,
      k: 1,
    );
  }

  /// Evaluates an observed fingerprint against candidate anchors using Weighted K-Nearest Neighbors (WKNN).
  AnchorMatchResult matchKnn({
    required WifiFingerprint observed,
    required List<LocalizationAnchor> candidateAnchors,
    int k = 3,
  }) {
    if (observed.observations.isEmpty) {
      return AnchorMatchResult.rejected(reason: 'Empty Wi-Fi fingerprint observation');
    }

    if (candidateAnchors.isEmpty) {
      return AnchorMatchResult.rejected(reason: 'No candidate anchors in repository');
    }

    final obsMap = observed.bssidMap;
    final obsBssids = observed.bssids;

    final scoredCandidates = <_CandidateScore>[];
    int maxOverlapFound = 0;
    double highestIndividualScore = 0.0;

    for (final anchor in candidateAnchors) {
      final anchorMap = anchor.fingerprint.bssidMap;
      final anchorBssids = anchor.fingerprint.bssids;

      final commonBssids = obsBssids.intersection(anchorBssids);
      if (commonBssids.length > maxOverlapFound) {
        maxOverlapFound = commonBssids.length;
      }

      if (commonBssids.length < minApOverlapCount) {
        continue;
      }

      // 1. AP Overlap (Jaccard Index)
      final allBssids = obsBssids.union(anchorBssids);
      final overlapScore = commonBssids.length / allBssids.length;

      // 2. RSSI Signal Distance on Common APs
      double totalRssiScore = 0.0;
      for (final bssid in commonBssids) {
        final obsRssi = obsMap[bssid]!;
        final anchorRssi = anchorMap[bssid]!;
        final delta = (obsRssi - anchorRssi).abs().toDouble();

        // Linear decay: 0 delta -> 1.0 score, >= 35dBm delta -> 0.0 score
        final apScore = max(0.0, 1.0 - (delta / maxRssiDeltaDbm));
        totalRssiScore += apScore;
      }
      final meanRssiScore = totalRssiScore / commonBssids.length;

      // 3. Composite Weighted Similarity Score (35% Overlap, 65% Signal Strength)
      final compositeScore = (0.35 * overlapScore) + (0.65 * meanRssiScore);
      if (compositeScore > highestIndividualScore) {
        highestIndividualScore = compositeScore;
      }

      if (compositeScore >= matchThreshold) {
        scoredCandidates.add(
          _CandidateScore(
            anchor: anchor,
            score: compositeScore,
            commonAps: commonBssids.length,
          ),
        );
      }
    }

    // Check rejection criteria
    if (scoredCandidates.isEmpty) {
      if (maxOverlapFound < minApOverlapCount) {
        return AnchorMatchResult.rejected(
          similarityScore: highestIndividualScore,
          apOverlapCount: maxOverlapFound,
          reason: 'No candidate anchor satisfied minimum common AP requirement ($minApOverlapCount APs)',
        );
      }
      return AnchorMatchResult.rejected(
        similarityScore: highestIndividualScore,
        apOverlapCount: maxOverlapFound,
        reason: 'Score ${(highestIndividualScore * 100).toStringAsFixed(1)}% below threshold ${(matchThreshold * 100).toStringAsFixed(0)}%',
      );
    }

    // Sort descending by similarity score
    scoredCandidates.sort((a, b) => b.score.compareTo(a.score));

    // Take top K
    final topK = scoredCandidates.take(k).toList();

    // If K = 1, return single anchor result directly
    if (topK.length == 1) {
      final best = topK.first;
      final confidence = (best.score * best.anchor.confidence).clamp(0.10, 0.95);
      final uncertainty = best.anchor.uncertaintyMeters + ((1.0 - best.score) * 12.0);

      return AnchorMatchResult(
        matchedAnchor: best.anchor,
        estimatedLatitude: best.anchor.latitude,
        estimatedLongitude: best.anchor.longitude,
        similarityScore: best.score,
        confidence: confidence,
        uncertaintyMeters: uncertainty,
        isAccepted: true,
        apOverlapCount: best.commonAps,
        matchedCandidatesCount: 1,
      );
    }

    // Multiple candidates (WKNN): Compute weights and geographic centroid
    // Weight wi = score_i^2 / sum(score_j^2)
    final squaredScores = topK.map((c) => pow(c.score, 2).toDouble()).toList();
    final sumSquared = squaredScores.reduce((a, b) => a + b);

    double weightedLat = 0.0;
    double weightedLon = 0.0;
    double weightedConf = 0.0;
    double weightedUnc = 0.0;
    double meanScore = 0.0;
    int maxOverlap = 0;

    for (int i = 0; i < topK.length; i++) {
      final cand = topK[i];
      final w = squaredScores[i] / sumSquared;

      weightedLat += w * cand.anchor.latitude;
      weightedLon += w * cand.anchor.longitude;
      weightedConf += w * (cand.score * cand.anchor.confidence);
      weightedUnc += w * cand.anchor.uncertaintyMeters;
      meanScore += w * cand.score;
      if (cand.commonAps > maxOverlap) {
        maxOverlap = cand.commonAps;
      }
    }

    // Calculate spatial dispersion (spread between top candidates)
    double maxPairwiseDist = 0.0;
    for (int i = 0; i < topK.length; i++) {
      for (int j = i + 1; j < topK.length; j++) {
        final dist = GeoUtils.haversineDistance(
          lat1: topK[i].anchor.latitude,
          lon1: topK[i].anchor.longitude,
          lat2: topK[j].anchor.latitude,
          lon2: topK[j].anchor.longitude,
        );
        if (dist > maxPairwiseDist) {
          maxPairwiseDist = dist;
        }
      }
    }

    // Spatial agreement penalty: If candidate anchors are far apart, degrade confidence and increase uncertainty
    final agreementFactor = max(0.60, 1.0 - (maxPairwiseDist / 40.0));
    final finalConfidence = (weightedConf * agreementFactor).clamp(0.10, 0.95);
    final finalUncertainty = weightedUnc + ((1.0 - meanScore) * 10.0) + (maxPairwiseDist * 0.25);

    // Synthesize a representative anchor for the weighted centroid
    final synthesizedAnchor = LocalizationAnchor(
      id: 'wknn_fused_${topK.map((e) => e.anchor.id).join("_")}',
      name: 'WKNN Fused Anchor (${topK.length} landmarks)',
      latitude: weightedLat,
      longitude: weightedLon,
      fingerprint: observed,
      confidence: finalConfidence,
      uncertaintyMeters: finalUncertainty,
      source: PositionSource.wifiFingerprint,
      metadata: {
        'topK': topK.map((e) => e.anchor.id).toList(),
        'pairwiseSpreadMeters': maxPairwiseDist,
      },
    );

    return AnchorMatchResult(
      matchedAnchor: synthesizedAnchor,
      estimatedLatitude: weightedLat,
      estimatedLongitude: weightedLon,
      similarityScore: meanScore,
      confidence: finalConfidence,
      uncertaintyMeters: finalUncertainty,
      isAccepted: true,
      apOverlapCount: maxOverlap,
      matchedCandidatesCount: topK.length,
    );
  }
}

import 'dart:math';

import '../models/localization_anchor.dart';
import '../models/wifi_fingerprint.dart';

/// Result of evaluating an observed Wi-Fi fingerprint against candidate anchors.
class AnchorMatchResult {
  /// The closest matching localization landmark (if any evaluated).
  final LocalizationAnchor? matchedAnchor;

  /// Normalized similarity score [0.0 to 1.0].
  final double similarityScore;

  /// Calibrated confidence of this match [0.0 to 1.0].
  final double confidence;

  /// Estimated horizontal uncertainty in meters.
  final double uncertaintyMeters;

  /// Whether the match satisfied all threshold constraints and is accepted for PDR correction.
  final bool isAccepted;

  /// Number of common Access Point BSSIDs between observation and anchor.
  final int apOverlapCount;

  /// Diagnostic explanation if the match was rejected or degraded.
  final String? rejectionReason;

  const AnchorMatchResult({
    this.matchedAnchor,
    required this.similarityScore,
    required this.confidence,
    required this.uncertaintyMeters,
    required this.isAccepted,
    required this.apOverlapCount,
    this.rejectionReason,
  });

  /// Factory for a rejected match attempt.
  factory AnchorMatchResult.rejected({
    LocalizationAnchor? candidate,
    double similarityScore = 0.0,
    int apOverlapCount = 0,
    required String reason,
  }) {
    return AnchorMatchResult(
      matchedAnchor: candidate,
      similarityScore: similarityScore,
      confidence: 0.0,
      uncertaintyMeters: 50.0,
      isAccepted: false,
      apOverlapCount: apOverlapCount,
      rejectionReason: reason,
    );
  }

  @override
  String toString() {
    if (isAccepted && matchedAnchor != null) {
      return 'AnchorMatchResult(ACCEPTED "${matchedAnchor!.name}", Score: ${(similarityScore * 100).toStringAsFixed(1)}%, Conf: ${(confidence * 100).toStringAsFixed(0)}%, ±${uncertaintyMeters.toStringAsFixed(1)}m, APs: $apOverlapCount)';
    }
    return 'AnchorMatchResult(REJECTED: $rejectionReason, Score: ${(similarityScore * 100).toStringAsFixed(1)}%, APs: $apOverlapCount)';
  }
}

/// Explainable, deterministic Wi-Fi fingerprint matching engine using Jaccard AP overlap & RSSI distance.
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

  /// Matches an observed fingerprint against a list of known localization anchors.
  AnchorMatchResult match({
    required WifiFingerprint observed,
    required List<LocalizationAnchor> candidateAnchors,
  }) {
    if (observed.observations.isEmpty) {
      return AnchorMatchResult.rejected(reason: 'Empty Wi-Fi fingerprint observation');
    }

    if (candidateAnchors.isEmpty) {
      return AnchorMatchResult.rejected(reason: 'No candidate anchors in repository');
    }

    AnchorMatchResult? bestResult;
    double highestScore = -1.0;

    final obsMap = observed.bssidMap;
    final obsBssids = observed.bssids;

    for (final anchor in candidateAnchors) {
      final anchorMap = anchor.fingerprint.bssidMap;
      final anchorBssids = anchor.fingerprint.bssids;

      final commonBssids = obsBssids.intersection(anchorBssids);

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

      if (compositeScore > highestScore) {
        highestScore = compositeScore;

        final isAccepted = compositeScore >= matchThreshold;
        final confidence = compositeScore * anchor.confidence;
        final uncertainty = anchor.uncertaintyMeters + ((1.0 - compositeScore) * 12.0);

        bestResult = AnchorMatchResult(
          matchedAnchor: anchor,
          similarityScore: compositeScore,
          confidence: confidence.clamp(0.10, 0.95),
          uncertaintyMeters: uncertainty,
          isAccepted: isAccepted,
          apOverlapCount: commonBssids.length,
          rejectionReason: isAccepted
              ? null
              : 'Score ${(compositeScore * 100).toStringAsFixed(1)}% below threshold ${(matchThreshold * 100).toStringAsFixed(0)}%',
        );
      }
    }

    if (bestResult != null) {
      return bestResult;
    }

    return AnchorMatchResult.rejected(
      reason: 'No candidate anchor satisfied minimum common AP requirement ($minApOverlapCount APs)',
    );
  }
}

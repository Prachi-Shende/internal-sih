/// Holds temporary candidate peak and valley information during step detection.
class PeakCandidate {
  final double timestamp;
  final double peakValue;
  final double precedingValleyValue;
  final double precedingValleyTime;

  const PeakCandidate({
    required this.timestamp,
    required this.peakValue,
    required this.precedingValleyValue,
    required this.precedingValleyTime,
  });

  double get prominence => peakValue - precedingValleyValue;
  double get duration => timestamp - precedingValleyTime;

  @override
  String toString() =>
      'Peak(t=${timestamp.toStringAsFixed(3)}, peak=${peakValue.toStringAsFixed(2)}, '
      'valley=${precedingValleyValue.toStringAsFixed(2)}, prom=${prominence.toStringAsFixed(2)})';
}

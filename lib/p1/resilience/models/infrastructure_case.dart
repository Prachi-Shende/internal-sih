/// The four foundational infrastructure resilience states supported by the Tourist Safety System.
enum InfrastructureCase {
  case1(
    caseNumber: 1,
    title: 'CASE 1 — FULLY CONNECTED',
    shortTitle: 'CASE 1',
    subtitle: 'GPS + Internet Available',
    statusLabel: 'FULLY OPERATIONAL',
    positioningStrategy: 'GPS Satellite Fix',
    communicationStrategy: 'Internet Online',
    gpsRequired: true,
    internetRequired: true,
  ),
  case2(
    caseNumber: 2,
    title: 'CASE 2 — GPS DENIED',
    shortTitle: 'CASE 2',
    subtitle: 'GPS Lost / Internet Online',
    statusLabel: 'DEGRADED — POSITIONING FALLBACK',
    positioningStrategy: 'PDR + Wi-Fi Anchors',
    communicationStrategy: 'Internet Online',
    gpsRequired: false,
    internetRequired: true,
  ),
  case3(
    caseNumber: 3,
    title: 'CASE 3 — INTERNET OFFLINE',
    shortTitle: 'CASE 3',
    subtitle: 'GPS Fix / Internet Offline',
    statusLabel: 'DEGRADED — OFFLINE',
    positioningStrategy: 'GPS (Local Autonomous)',
    communicationStrategy: 'Offline / Local Processing',
    gpsRequired: true,
    internetRequired: false,
  ),
  case4(
    caseNumber: 4,
    title: 'CASE 4 — FULL BLACKOUT',
    shortTitle: 'CASE 4',
    subtitle: 'GPS & Internet Unavailable',
    statusLabel: 'FULL OFFLINE OPERATION',
    positioningStrategy: 'PDR + Offline Wi-Fi Anchors + Map Constraints',
    communicationStrategy: 'Offline Local Queue',
    gpsRequired: false,
    internetRequired: false,
  );

  final int caseNumber;
  final String title;
  final String shortTitle;
  final String subtitle;
  final String statusLabel;
  final String positioningStrategy;
  final String communicationStrategy;
  final bool gpsRequired;
  final bool internetRequired;

  const InfrastructureCase({
    required this.caseNumber,
    required this.title,
    required this.shortTitle,
    required this.subtitle,
    required this.statusLabel,
    required this.positioningStrategy,
    required this.communicationStrategy,
    required this.gpsRequired,
    required this.internetRequired,
  });

  /// Automatically derives the active infrastructure case from real device capability state.
  static InfrastructureCase fromCapabilities({
    required bool gpsAvailable,
    required bool internetAvailable,
  }) {
    if (gpsAvailable && internetAvailable) {
      return InfrastructureCase.case1;
    } else if (!gpsAvailable && internetAvailable) {
      return InfrastructureCase.case2;
    } else if (gpsAvailable && !internetAvailable) {
      return InfrastructureCase.case3;
    } else {
      return InfrastructureCase.case4;
    }
  }
}

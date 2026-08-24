/// Single 802.11 Access Point observation within a radio scan.
class WifiAccessPointObservation {
  /// Basic Service Set Identifier (MAC address of the access point).
  final String bssid;

  /// Service Set Identifier (Human-readable Wi-Fi network name).
  final String ssid;

  /// Received Signal Strength Indicator in decibels relative to one milliwatt (dBm).
  /// Typical values range from -30 dBm (strongest) to -95 dBm (weakest).
  final int rssi;

  /// Carrier frequency in Megahertz (e.g. 2412 for 2.4GHz Ch 1, 5180 for 5GHz Ch 36).
  final int? frequencyMhz;

  /// Primary channel number (e.g. 1, 6, 11, 36, 149).
  final int? channel;

  const WifiAccessPointObservation({
    required this.bssid,
    required this.ssid,
    required this.rssi,
    this.frequencyMhz,
    this.channel,
  });

  Map<String, dynamic> toJson() => {
        'bssid': bssid,
        'ssid': ssid,
        'rssi': rssi,
        if (frequencyMhz != null) 'frequencyMhz': frequencyMhz,
        if (channel != null) 'channel': channel,
      };

  factory WifiAccessPointObservation.fromJson(Map<String, dynamic> json) {
    return WifiAccessPointObservation(
      bssid: json['bssid'] as String,
      ssid: json['ssid'] as String? ?? '',
      rssi: json['rssi'] as int,
      frequencyMhz: json['frequencyMhz'] as int?,
      channel: json['channel'] as int?,
    );
  }

  @override
  String toString() => '$ssid ($bssid): ${rssi}dBm';
}

/// Represents an instantaneous snapshot of the ambient Wi-Fi radio environment.
class WifiFingerprint {
  final DateTime timestamp;
  final List<WifiAccessPointObservation> observations;

  const WifiFingerprint({
    required this.timestamp,
    required this.observations,
  });

  /// Map representation of BSSID -> RSSI (in dBm) for fast lookup.
  Map<String, int> get bssidMap => {
        for (final ap in observations) ap.bssid.toLowerCase(): ap.rssi,
      };

  /// Set of all observed BSSIDs (in lowercase).
  Set<String> get bssids => {
        for (final ap in observations) ap.bssid.toLowerCase(),
      };

  /// Number of unique access points observed in this fingerprint.
  int get count => observations.length;

  /// Returns observation for a specific BSSID, if present.
  WifiAccessPointObservation? getObservation(String bssid) {
    final lower = bssid.toLowerCase();
    for (final ap in observations) {
      if (ap.bssid.toLowerCase() == lower) return ap;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'observations': observations.map((e) => e.toJson()).toList(),
      };

  factory WifiFingerprint.fromJson(Map<String, dynamic> json) {
    return WifiFingerprint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      observations: (json['observations'] as List<dynamic>)
          .map((e) => WifiAccessPointObservation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  String toString() {
    return 'WifiFingerprint(${observations.length} APs at ${timestamp.toIso8601String().substring(11, 19)})';
  }
}

/// Represents all potential positioning sources in the multi-tier navigation architecture.
///
/// Designed to be extensible for future positioning technologies (Wi-Fi, RTT, BLE, Map matching).
enum PositionSource {
  /// Global Positioning System (High-accuracy outdoor satellite fix).
  gps,

  /// Pedestrian Dead Reckoning (Relative inertial dead reckoning from IMU sensors).
  pdr,

  /// Fused sensor estimation (e.g. Kalman Filter / Complementary fusion).
  fused,

  /// Wi-Fi RSSI fingerprint matching against radio map (Future milestone).
  wifiFingerprint,

  /// Wi-Fi 802.11mc Round-Trip Time multi-lateration (Future milestone).
  wifiRtt,

  /// Position snapped / matched to building floor plan or road network (Future milestone).
  mapMatched,

  /// Last known valid position retained during total signal blackout.
  lastKnown,
}

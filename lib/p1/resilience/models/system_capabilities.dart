import 'gps_health.dart';

/// Represents the current physical and infrastructure hardware capabilities of the device.
class SystemCapabilities {
  /// Global Positioning System receiver status (has fix and permission).
  final bool gpsAvailable;

  /// Granular health state of the GPS/GNSS receiver (disabled, searching, active, stale, lost).
  final GpsHealth gpsHealth;

  /// Internet connectivity status (Wi-Fi, cellular data, or ethernet).
  final bool internetAvailable;

  /// Cellular network radio connectivity (voice/SMS/data).
  final bool cellularAvailable;

  /// Wi-Fi network adapter enabled and capable of scanning.
  final bool wifiAvailable;

  /// Bluetooth Low Energy adapter enabled and capable of scanning/advertising.
  final bool bleAvailable;

  const SystemCapabilities({
    required this.gpsAvailable,
    this.gpsHealth = GpsHealth.disabled,
    required this.internetAvailable,
    this.cellularAvailable = false,
    this.wifiAvailable = false,
    this.bleAvailable = false,
  });

  /// Default baseline capabilities before sensor checks complete.
  static const SystemCapabilities initial = SystemCapabilities(
    gpsAvailable: false,
    gpsHealth: GpsHealth.disabled,
    internetAvailable: false,
    cellularAvailable: false,
    wifiAvailable: false,
    bleAvailable: false,
  );

  SystemCapabilities copyWith({
    bool? gpsAvailable,
    GpsHealth? gpsHealth,
    bool? internetAvailable,
    bool? cellularAvailable,
    bool? wifiAvailable,
    bool? bleAvailable,
  }) {
    return SystemCapabilities(
      gpsAvailable: gpsAvailable ?? this.gpsAvailable,
      gpsHealth: gpsHealth ?? this.gpsHealth,
      internetAvailable: internetAvailable ?? this.internetAvailable,
      cellularAvailable: cellularAvailable ?? this.cellularAvailable,
      wifiAvailable: wifiAvailable ?? this.wifiAvailable,
      bleAvailable: bleAvailable ?? this.bleAvailable,
    );
  }

  @override
  String toString() {
    return 'SystemCapabilities(GPS: ${gpsHealth.label}, '
        'Internet: ${internetAvailable ? "ONLINE" : "OFFLINE"}, '
        'Cellular: ${cellularAvailable ? "ON" : "OFF"}, '
        'WiFi: ${wifiAvailable ? "ON" : "OFF"}, '
        'BLE: ${bleAvailable ? "ON" : "OFF"})';
  }
}

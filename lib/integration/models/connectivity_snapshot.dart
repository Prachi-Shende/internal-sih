import '../../resilience/models/system_capabilities.dart';

/// Clean application-level DTO representing network connectivity and communication routing state.
/// Consumed by P3 (Safety Risk), P4 (Communication Orchestrator), P5 (Backend Sync), and P6 (UI).
class ConnectivitySnapshot {
  /// True if internet is currently accessible.
  final bool isOnline;

  /// True if cellular modem is active.
  final bool cellularAvailable;

  /// True if Wi-Fi network interface is enabled.
  final bool wifiAvailable;

  /// Active delivery channel currently used ('INTERNET' or 'OFFLINE_QUEUE').
  final String activeDeliveryChannel;

  /// Timestamp when connectivity was sampled.
  final DateTime timestamp;

  const ConnectivitySnapshot({
    required this.isOnline,
    required this.cellularAvailable,
    required this.wifiAvailable,
    required this.activeDeliveryChannel,
    required this.timestamp,
  });

  /// Factory constructing [ConnectivitySnapshot] from [SystemCapabilities].
  factory ConnectivitySnapshot.fromCapabilities(
    SystemCapabilities capabilities, {
    DateTime? timestamp,
  }) {
    return ConnectivitySnapshot(
      isOnline: capabilities.internetAvailable,
      cellularAvailable: capabilities.cellularAvailable,
      wifiAvailable: capabilities.wifiAvailable,
      activeDeliveryChannel: capabilities.internetAvailable ? 'INTERNET' : 'OFFLINE_QUEUE',
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isOnline': isOnline,
      'cellularAvailable': cellularAvailable,
      'wifiAvailable': wifiAvailable,
      'activeDeliveryChannel': activeDeliveryChannel,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ConnectivitySnapshot.fromJson(Map<String, dynamic> json) {
    return ConnectivitySnapshot(
      isOnline: (json['isOnline'] as bool?) ?? false,
      cellularAvailable: (json['cellularAvailable'] as bool?) ?? false,
      wifiAvailable: (json['wifiAvailable'] as bool?) ?? false,
      activeDeliveryChannel: json['activeDeliveryChannel'] as String? ??
          ((json['isOnline'] == true) ? 'INTERNET' : 'OFFLINE_QUEUE'),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'ConnectivitySnapshot(online: $isOnline, channel: $activeDeliveryChannel, '
        'cell: $cellularAvailable, wifi: $wifiAvailable)';
  }
}

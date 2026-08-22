class CommunicationStatus {
  final bool internet;
  final bool sms;
  final bool relay;
  final String selectedChannel; // 'INTERNET' | 'SMS' | 'RELAY' | 'OFFLINE_QUEUE'
  final int queuedEventsCount;
  final DateTime lastSyncTimestamp;

  CommunicationStatus({
    required this.internet,
    required this.sms,
    required this.relay,
    required this.selectedChannel,
    required this.queuedEventsCount,
    required this.lastSyncTimestamp,
  });

  Map<String, dynamic> toJson() => {
        'internet': internet,
        'sms': sms,
        'relay': relay,
        'selected_channel': selectedChannel,
        'queued_events_count': queuedEventsCount,
        'last_sync_timestamp': lastSyncTimestamp.toIso8601String(),
      };

  factory CommunicationStatus.fromJson(Map<String, dynamic> json) {
    return CommunicationStatus(
      internet: json['internet'] ?? false,
      sms: json['sms'] ?? false,
      relay: json['relay'] ?? false,
      selectedChannel: json['selected_channel'] ?? 'OFFLINE_QUEUE',
      queuedEventsCount: json['queued_events_count'] ?? 0,
      lastSyncTimestamp: DateTime.parse(json['last_sync_timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}

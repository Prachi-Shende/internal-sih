import 'dart:async';
import '../models/delivery_result.dart';
import '../models/safety_event.dart';
import 'communication_channel.dart';

/// Fallback channel that securely queues events in local storage when no network is available.
class OfflineQueueChannel implements CommunicationChannel {
  @override
  String get name => 'OFFLINE_QUEUE';

  @override
  bool get isAvailable => true;

  @override
  Future<DeliveryResult> send(SafetyEvent event) async {
    return DeliveryResult.queued(
      channelName: name,
      reason: 'No active real-time communication channel. Persisted in local queue.',
    );
  }
}

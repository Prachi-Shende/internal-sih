import 'dart:async';
import '../../resilience/sensors/connectivity_service.dart';
import '../models/delivery_result.dart';
import '../models/safety_event.dart';
import '../transport/safety_event_transport.dart';
import 'communication_channel.dart';

/// Communication channel delivering safety events over the Internet (HTTPS/WebSocket).
class InternetCommunicationChannel implements CommunicationChannel {
  final ConnectivityService connectivityService;
  final SafetyEventTransport transport;

  InternetCommunicationChannel({
    required this.connectivityService,
    required this.transport,
  });

  @override
  String get name => 'INTERNET';

  @override
  bool get isAvailable => connectivityService.isOnline;

  @override
  Future<DeliveryResult> send(SafetyEvent event) async {
    if (!isAvailable) {
      return DeliveryResult.queued(
        channelName: name,
        reason: 'Internet is currently offline. Queued locally for synchronization.',
      );
    }

    try {
      return await transport.transmit(event);
    } catch (e) {
      return DeliveryResult.failure(
        channelName: name,
        reason: 'Network transmission exception: $e',
      );
    }
  }
}

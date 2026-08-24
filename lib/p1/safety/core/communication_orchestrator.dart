import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../resilience/sensors/connectivity_service.dart';
import '../channels/internet_communication_channel.dart';
import '../channels/offline_queue_channel.dart';
import '../channels/sms_communication_channel.dart';
import '../models/delivery_result.dart';
import '../models/safety_event.dart';
import '../storage/safety_event_store.dart';
import '../transport/safety_event_transport.dart';

/// Routes safety event delivery across communication channels (Internet, SMS, Offline Queue)
/// based on active connectivity state and updates the local store lifecycle.
class CommunicationOrchestrator {
  final ConnectivityService connectivityService;
  final SafetyEventStore store;
  final InternetCommunicationChannel internetChannel;
  final OfflineQueueChannel offlineQueueChannel;
  final SmsCommunicationChannel smsChannel;

  CommunicationOrchestrator({
    required this.connectivityService,
    required this.store,
    required SafetyEventTransport transport,
    SmsCommunicationChannel? smsChannel,
  })  : internetChannel = InternetCommunicationChannel(
          connectivityService: connectivityService,
          transport: transport,
        ),
        offlineQueueChannel = OfflineQueueChannel(),
        smsChannel = smsChannel ?? SmsCommunicationChannel(isConfigured: false);

  /// Dispatches a safety event through the best available communication channel.
  /// Note: Local persistence MUST be performed BEFORE calling this method.
  Future<DeliveryResult> deliver(SafetyEvent event) async {
    _log('[SAFETY] DELIVERY ATTEMPT channel=${connectivityService.isOnline ? "INTERNET" : "OFFLINE_QUEUE"} id=${event.eventId}');

    // 1. If Internet is available, attempt network delivery
    if (internetChannel.isAvailable) {
      await store.updateEventStatus(
        event.eventId,
        EventDeliveryStatus.sending,
        deliveryChannel: internetChannel.name,
      );

      final result = await internetChannel.send(event);

      if (result.success) {
        await store.updateEventStatus(
          event.eventId,
          result.resultingStatus,
          deliveryChannel: result.channelName,
        );
        _log('[SAFETY] DELIVERY SUCCESS id=${event.eventId} channel=${result.channelName}');
        return result;
      } else {
        await store.incrementRetryCount(event.eventId);
        await store.updateEventStatus(
          event.eventId,
          EventDeliveryStatus.queued,
          failureReason: result.reason,
          deliveryChannel: result.channelName,
        );
        _log('[SAFETY] DELIVERY FAILED id=${event.eventId} reason=${result.reason}');
        return result;
      }
    }

    // 2. Check SMS Fallback if configured
    if (smsChannel.isAvailable) {
      final smsResult = await smsChannel.send(event);
      if (smsResult.success) {
        await store.updateEventStatus(
          event.eventId,
          smsResult.resultingStatus,
          deliveryChannel: smsResult.channelName,
        );
        _log('[SAFETY] DELIVERY SUCCESS via SMS id=${event.eventId}');
        return smsResult;
      }
    }

    // 3. Fallback to Local Offline Queue
    final queueResult = await offlineQueueChannel.send(event);
    await store.updateEventStatus(
      event.eventId,
      EventDeliveryStatus.queued,
      failureReason: 'Internet offline. Stored in local sync queue.',
      deliveryChannel: offlineQueueChannel.name,
    );
    _log('[SAFETY] EVENT QUEUED reason=OFFLINE id=${event.eventId}');
    return queueResult;
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}

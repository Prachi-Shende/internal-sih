import 'dart:async';
import '../models/delivery_result.dart';
import '../models/safety_event.dart';
import 'safety_event_transport.dart';

/// Development and testing simulated transport.
/// Explicitly labeled: DEV / SIMULATED TRANSPORT.
class DevMockSafetyEventTransport implements SafetyEventTransport {
  bool shouldSucceed;
  Duration latency;
  final Set<String> failedEventIds = {};

  final List<SafetyEvent> _transmittedEvents = [];
  List<SafetyEvent> get transmittedEvents => List.unmodifiable(_transmittedEvents);

  DevMockSafetyEventTransport({
    this.shouldSucceed = true,
    this.latency = const Duration(milliseconds: 10),
  });

  @override
  Future<DeliveryResult> transmit(SafetyEvent event) async {
    if (latency.inMilliseconds > 0) {
      await Future<void>.delayed(latency);
    }

    if (failedEventIds.contains(event.eventId) || !shouldSucceed) {
      return DeliveryResult.failure(
        channelName: 'INTERNET (DEV / SIMULATED TRANSPORT)',
        reason: 'Simulated backend transmission error',
      );
    }

    _transmittedEvents.add(event);

    return DeliveryResult.success(
      channelName: 'INTERNET (DEV / SIMULATED TRANSPORT)',
      reason: 'Accepted by simulated backend server',
    );
  }

  void clear() {
    _transmittedEvents.clear();
    failedEventIds.clear();
  }
}

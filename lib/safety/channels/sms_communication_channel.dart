import 'dart:async';
import '../models/delivery_result.dart';
import '../models/safety_event.dart';
import 'communication_channel.dart';

/// Communication channel abstraction for SMS / Cellular Emergency Broadcast fallback.
/// Explicitly labeled: SMS NOT CONFIGURED (Placeholder for future native integration).
class SmsCommunicationChannel implements CommunicationChannel {
  final bool isConfigured;

  SmsCommunicationChannel({this.isConfigured = false});

  @override
  String get name => 'SMS';

  @override
  bool get isAvailable => isConfigured;

  @override
  Future<DeliveryResult> send(SafetyEvent event) async {
    if (!isConfigured) {
      return DeliveryResult.failure(
        channelName: name,
        reason: 'SMS gateway not configured in current build. Use Internet or Offline Queue.',
      );
    }

    // Future implementation: integrate with native TelephonyManager / SMSManager
    return DeliveryResult.failure(
      channelName: name,
      reason: 'SMS delivery not yet implemented.',
    );
  }
}

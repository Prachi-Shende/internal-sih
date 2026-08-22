import 'safety_event.dart';

/// Result of a communication channel delivery attempt.
class DeliveryResult {
  /// True if delivery was successfully transmitted/sent or acknowledged by the channel.
  final bool success;

  /// Name of the communication channel (e.g. "INTERNET", "OFFLINE_QUEUE", "SMS").
  final String channelName;

  /// Resulting status assigned to the event.
  final EventDeliveryStatus resultingStatus;

  /// Optional failure or diagnostic reason.
  final String? reason;

  /// Timestamp of the delivery result.
  final DateTime timestamp;

  const DeliveryResult({
    required this.success,
    required this.channelName,
    required this.resultingStatus,
    this.reason,
    required this.timestamp,
  });

  factory DeliveryResult.success({
    required String channelName,
    EventDeliveryStatus resultingStatus = EventDeliveryStatus.sent,
    String? reason,
  }) {
    return DeliveryResult(
      success: true,
      channelName: channelName,
      resultingStatus: resultingStatus,
      reason: reason,
      timestamp: DateTime.now(),
    );
  }

  factory DeliveryResult.queued({
    required String channelName,
    required String reason,
  }) {
    return DeliveryResult(
      success: false,
      channelName: channelName,
      resultingStatus: EventDeliveryStatus.queued,
      reason: reason,
      timestamp: DateTime.now(),
    );
  }

  factory DeliveryResult.failure({
    required String channelName,
    required String reason,
  }) {
    return DeliveryResult(
      success: false,
      channelName: channelName,
      resultingStatus: EventDeliveryStatus.failed,
      reason: reason,
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'DeliveryResult(success=$success, channel=$channelName, status=$resultingStatus, reason=$reason)';
  }
}

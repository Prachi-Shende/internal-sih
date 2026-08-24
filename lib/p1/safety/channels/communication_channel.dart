import 'dart:async';
import '../models/delivery_result.dart';
import '../models/safety_event.dart';

/// Abstract communication channel for safety event delivery.
abstract class CommunicationChannel {
  /// Friendly name of this delivery channel.
  String get name;

  /// Whether this channel is currently usable/available.
  bool get isAvailable;

  /// Attempts delivery of the safety event over this channel.
  Future<DeliveryResult> send(SafetyEvent event);
}

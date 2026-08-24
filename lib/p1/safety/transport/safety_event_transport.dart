import 'dart:async';
import '../models/delivery_result.dart';
import '../models/safety_event.dart';

/// Abstract network transport layer for transmitting safety events to a server or cloud backend.
abstract class SafetyEventTransport {
  /// Transmits the given safety event across the network.
  /// Returns a [DeliveryResult] indicating success or failure.
  Future<DeliveryResult> transmit(SafetyEvent event);
}

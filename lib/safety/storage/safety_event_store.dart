import 'dart:async';
import '../models/safety_event.dart';

/// Abstract contract for local persistent storage of safety events.
abstract class SafetyEventStore {
  /// Initializes the storage mechanism (e.g. loads from disk or creates database).
  Future<void> init();

  /// Forces a reload of events from persistent storage.
  Future<void> reload();

  /// Persists a new safety event locally.
  Future<void> saveEvent(SafetyEvent event);

  /// Retrieves all pending, queued, or failed events waiting for network delivery (oldest first).
  Future<List<SafetyEvent>> getPendingEvents();

  /// Retrieves all recorded safety events (newest first).
  Future<List<SafetyEvent>> getAllEvents();

  /// Retrieves a specific event by its unique ID.
  Future<SafetyEvent?> getEventById(String id);

  /// Updates an existing safety event in place.
  Future<void> updateEvent(SafetyEvent event);

  /// Updates the delivery status, failure reason, and channel of a specific event.
  Future<void> updateEventStatus(
    String id,
    EventDeliveryStatus status, {
    String? failureReason,
    String? deliveryChannel,
  });

  /// Increments the retry count and records the last attempt timestamp for an event.
  Future<void> incrementRetryCount(String id);

  /// Deletes a specific event from storage.
  Future<void> deleteEvent(String id);

  /// Clears all events from storage.
  Future<void> clear();
}

/// In-memory implementation of [SafetyEventStore] for fast unit testing.
class InMemorySafetyEventStore implements SafetyEventStore {
  final Map<String, SafetyEvent> _events = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> reload() async {}

  @override
  Future<void> saveEvent(SafetyEvent event) async {
    _events[event.eventId] = event;
  }

  @override
  Future<List<SafetyEvent>> getPendingEvents() async {
    final pending = _events.values.where((e) => e.eventStatus.isPendingOrQueued).toList();
    pending.sort((a, b) => a.createdAt.compareTo(b.createdAt)); // FIFO: oldest first
    return pending;
  }

  @override
  Future<List<SafetyEvent>> getAllEvents() async {
    final list = _events.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first
    return list;
  }

  @override
  Future<SafetyEvent?> getEventById(String id) async {
    return _events[id];
  }

  @override
  Future<void> updateEvent(SafetyEvent event) async {
    _events[event.eventId] = event;
  }

  @override
  Future<void> updateEventStatus(
    String id,
    EventDeliveryStatus status, {
    String? failureReason,
    String? deliveryChannel,
  }) async {
    final existing = _events[id];
    if (existing != null) {
      _events[id] = existing.copyWith(
        eventStatus: status,
        failureReason: failureReason,
        deliveryChannel: deliveryChannel ?? existing.deliveryChannel,
        lastAttemptAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> incrementRetryCount(String id) async {
    final existing = _events[id];
    if (existing != null) {
      _events[id] = existing.copyWith(
        retryCount: existing.retryCount + 1,
        lastAttemptAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> deleteEvent(String id) async {
    _events.remove(id);
  }

  @override
  Future<void> clear() async {
    _events.clear();
  }
}

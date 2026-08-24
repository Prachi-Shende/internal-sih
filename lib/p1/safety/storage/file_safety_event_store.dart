import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../models/safety_event.dart';
import 'safety_event_store.dart';

/// Persistent JSON file-based implementation of [SafetyEventStore].
/// Safely stores and retrieves safety events from the local filesystem.
class FileSafetyEventStore implements SafetyEventStore {
  final String? customFilePath;
  final Map<String, SafetyEvent> _cache = {};
  bool _initialized = false;
  File? _file;

  FileSafetyEventStore({this.customFilePath});

  Future<File> _resolveFile() async {
    if (_file != null) return _file!;

    if (customFilePath != null) {
      _file = File(customFilePath!);
    } else {
      try {
        // Durable, permanent Android/iOS application documents directory
        final docDir = await getApplicationDocumentsDirectory();
        _file = File('${docDir.path}${Platform.pathSeparator}sih_safety_events.json');
      } catch (_) {
        // Fallback for non-Flutter test environments
        final dir = Directory.systemTemp;
        _file = File('${dir.path}${Platform.pathSeparator}sih_safety_events.json');
      }
    }

    if (!await _file!.exists()) {
      await _file!.create(recursive: true);
      await _file!.writeAsString('[]', flush: true);
    }

    return _file!;
  }

  @override
  Future<void> init({bool forceReload = false}) async {
    if (_initialized && !forceReload) return;

    try {
      final file = await _resolveFile();
      if (!await file.exists()) {
        await file.create(recursive: true);
        await file.writeAsString('[]', flush: true);
        _cache.clear();
        _initialized = true;
        return;
      }

      final content = await file.readAsString();
      if (content.trim().isNotEmpty) {
        final dynamic decoded = jsonDecode(content);
        if (decoded is List) {
          _cache.clear();
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final event = SafetyEvent.fromJson(item);
              _cache[event.eventId] = event;
            }
          }
        }
      }
    } catch (e) {
      // Fallback if file corrupt or unreadable
      _cache.clear();
    }

    _initialized = true;
  }

  @override
  Future<void> reload() async {
    await init(forceReload: true);
  }

  Future<void> _flushToDisk() async {
    try {
      final file = await _resolveFile();
      final list = _cache.values.map((e) => e.toJson()).toList();
      final jsonStr = jsonEncode(list);
      await file.writeAsString(jsonStr, flush: true);
    } catch (e) {
      // Disk write error handled gracefully
    }
  }

  @override
  Future<void> saveEvent(SafetyEvent event) async {
    if (!_initialized) await init();
    _cache[event.eventId] = event;
    await _flushToDisk();
  }

  @override
  Future<List<SafetyEvent>> getPendingEvents() async {
    if (!_initialized) await init();
    final pending = _cache.values.where((e) => e.eventStatus.isPendingOrQueued).toList();
    pending.sort((a, b) => a.createdAt.compareTo(b.createdAt)); // FIFO: oldest first
    return pending;
  }

  @override
  Future<List<SafetyEvent>> getAllEvents() async {
    if (!_initialized) await init();
    final list = _cache.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first
    return list;
  }

  @override
  Future<SafetyEvent?> getEventById(String id) async {
    if (!_initialized) await init();
    return _cache[id];
  }

  @override
  Future<void> updateEvent(SafetyEvent event) async {
    if (!_initialized) await init();
    _cache[event.eventId] = event;
    await _flushToDisk();
  }

  @override
  Future<void> updateEventStatus(
    String id,
    EventDeliveryStatus status, {
    String? failureReason,
    String? deliveryChannel,
  }) async {
    if (!_initialized) await init();
    final existing = _cache[id];
    if (existing != null) {
      _cache[id] = existing.copyWith(
        eventStatus: status,
        failureReason: failureReason,
        deliveryChannel: deliveryChannel ?? existing.deliveryChannel,
        lastAttemptAt: DateTime.now(),
      );
      await _flushToDisk();
    }
  }

  @override
  Future<void> incrementRetryCount(String id) async {
    if (!_initialized) await init();
    final existing = _cache[id];
    if (existing != null) {
      _cache[id] = existing.copyWith(
        retryCount: existing.retryCount + 1,
        lastAttemptAt: DateTime.now(),
      );
      await _flushToDisk();
    }
  }

  @override
  Future<void> deleteEvent(String id) async {
    if (!_initialized) await init();
    _cache.remove(id);
    await _flushToDisk();
  }

  @override
  Future<void> clear() async {
    if (!_initialized) await init();
    _cache.clear();
    await _flushToDisk();
  }
}

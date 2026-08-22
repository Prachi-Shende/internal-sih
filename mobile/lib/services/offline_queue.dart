import 'dart:convert';
import 'package:encrypt/encrypt.dart' as enc;
import '../models/incident_payload.dart';

class OfflineQueueRepository {
  final List<String> _encryptedStorage = [];
  final enc.Key _key = enc.Key.fromUtf8('32-Character-Key-For-AES-256!!');
  final enc.IV _iv = enc.IV.fromLength(16);

  OfflineQueueRepository();

  Future<void> enqueueIncident(IncidentPayload payload) async {
    final rawJson = jsonEncode(payload.toJson());
    final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encrypt(rawJson, iv: _iv);
    _encryptedStorage.add(encrypted.base64);
  }

  Future<List<IncidentPayload>> peekAllQueuedIncidents() async {
    final List<IncidentPayload> payloads = [];
    final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.gcm));

    for (var encStr in _encryptedStorage) {
      try {
        final decryptedStr = encrypter.decrypt(enc.Encrypted.fromBase64(encStr), iv: _iv);
        final map = jsonDecode(decryptedStr) as Map<String, dynamic>;
        payloads.add(IncidentPayload.fromJson(map));
      } catch (e) {
        // Fallback for demo unencrypted strings
        try {
          final map = jsonDecode(encStr) as Map<String, dynamic>;
          payloads.add(IncidentPayload.fromJson(map));
        } catch (_) {}
      }
    }
    return payloads;
  }

  Future<void> clearSyncedIncidents(List<String> syncedIds) async {
    final List<IncidentPayload> remaining = [];
    final all = await peekAllQueuedIncidents();

    for (var item in all) {
      if (!syncedIds.contains(item.incidentId)) {
        remaining.add(item);
      }
    }

    _encryptedStorage.clear();
    for (var item in remaining) {
      await enqueueIncident(item);
    }
  }

  int get queueCount => _encryptedStorage.length;
}

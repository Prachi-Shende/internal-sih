import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/incident_payload.dart';
import '../models/blockchain_record.dart';

class BlockchainService {
  BlockchainService();

  String generateLocationHash(double lat, double lon, DateTime timestamp) {
    final rawStr = 'LOC:${lat.toStringAsFixed(6)}:${lon.toStringAsFixed(6)}:${timestamp.toIso8601String()}';
    final bytes = utf8.encode(rawStr);
    return '0x${sha256.convert(bytes)}';
  }

  String generatePayloadHash(IncidentPayload payload) {
    final rawStr = jsonEncode(payload.toJson());
    final bytes = utf8.encode(rawStr);
    return '0x${sha256.convert(bytes)}';
  }

  Future<BlockchainRecord> recordIncidentOnChain(IncidentPayload payload) async {
    final locHash = generateLocationHash(
      payload.location['lat'] ?? 0.0,
      payload.location['lon'] ?? 0.0,
      payload.timestamp,
    );
    final payHash = generatePayloadHash(payload);

    // Simulate Blockchain transaction signing and mining
    final mockTxBytes = utf8.encode('${payload.incidentId}:${payload.timestamp.millisecondsSinceEpoch}');
    final txHash = '0x${sha256.convert(mockTxBytes)}';

    return BlockchainRecord(
      incidentId: payload.incidentId,
      eventType: payload.eventType,
      timestamp: payload.timestamp,
      locationHash: locHash,
      payloadHash: payHash,
      txHash: txHash,
      blockNumber: 142857 + (DateTime.now().second),
      status: "VERIFIED_ON_CHAIN",
    );
  }
}

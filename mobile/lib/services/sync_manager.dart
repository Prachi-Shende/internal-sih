import 'package:dio/dio.dart';
import '../models/incident_payload.dart';
import 'offline_queue.dart';
import 'communication_manager.dart';

class SyncManager {
  final Dio _dio;
  final OfflineQueueRepository _queueRepo;
  final CommunicationManagerService _commManager;
  final String backendBaseUrl;

  SyncManager({
    required OfflineQueueRepository queueRepo,
    required CommunicationManagerService commManager,
    this.backendBaseUrl = 'http://localhost:8000',
  })  : _queueRepo = queueRepo,
        _commManager = commManager,
        _dio = Dio(BaseOptions(baseUrl: backendBaseUrl, connectTimeout: const Duration(seconds: 5)));

  Future<bool> attemptSync() async {
    final queuedIncidents = await _queueRepo.peekAllQueuedIncidents();
    if (queuedIncidents.isEmpty) {
      _commManager.recordSyncCompleted(0);
      return true;
    }

    try {
      final payloadData = {
        'device_id': 'FLUTTER_DEVICE_MOBILE_001',
        'queued_incidents': queuedIncidents.map((e) => e.toJson()).toList(),
      };

      final response = await _dio.post('/api/v1/sync', data: payloadData);

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = response.data;
        final List<dynamic> processedIds = body['processed_incident_ids'] ?? [];
        final List<String> syncedIds = processedIds.map((e) => e.toString()).toList();

        await _queueRepo.clearSyncedIncidents(syncedIds);
        _commManager.recordSyncCompleted(_queueRepo.queueCount);
        return true;
      }
    } catch (e) {
      print('[SyncManager] Sync failed (Backend offline or unreachable): $e');
    }
    return false;
  }
}

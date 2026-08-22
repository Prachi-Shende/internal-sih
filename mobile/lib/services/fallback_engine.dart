import '../models/incident_payload.dart';
import 'communication_manager.dart';
import 'offline_queue.dart';
import 'sync_manager.dart';
import 'blockchain_service.dart';

class ChannelFallbackEngine {
  final CommunicationManagerService _commManager;
  final OfflineQueueRepository _queueRepo;
  final SyncManager _syncManager;
  final BlockchainService _blockchainService;

  ChannelFallbackEngine({
    required CommunicationManagerService commManager,
    required OfflineQueueRepository queueRepo,
    required SyncManager syncManager,
    required BlockchainService blockchainService,
  })  : _commManager = commManager,
        _queueRepo = queueRepo,
        _syncManager = syncManager,
        _blockchainService = blockchainService;

  Future<IncidentPayload> processIncident(IncidentPayload rawPayload) async {
    // Step 1: Attach Blockchain Record to payload
    final bcRecord = await _blockchainService.recordIncidentOnChain(rawPayload);
    final payloadWithBc = IncidentPayload(
      incidentId: rawPayload.incidentId,
      userId: rawPayload.userId,
      timestamp: rawPayload.timestamp,
      eventType: rawPayload.eventType,
      location: rawPayload.location,
      riskAssessment: rawPayload.riskAssessment,
      safeHaven: rawPayload.safeHaven,
      channelUsed: _commManager.getSelectedChannelString(),
      blockchainTxHash: bcRecord.txHash,
    );

    // Step 2: Route through active communication channel cascade
    final channel = _commManager.selectOptimalChannel();

    switch (channel) {
      case ConnectionChannel.internet:
        await _queueRepo.enqueueIncident(payloadWithBc);
        _commManager.setNetworkState(queuedCount: _queueRepo.queueCount);
        final synced = await _syncManager.attemptSync();
        print('[FallbackEngine] Dispatched via INTERNET (Synced: $synced)');
        break;

      case ConnectionChannel.sms:
        print('[FallbackEngine] Dispatched via SMS Gateway Fallback (Simulated)');
        await _queueRepo.enqueueIncident(payloadWithBc);
        _commManager.recordSyncCompleted(_queueRepo.queueCount);
        break;

      case ConnectionChannel.peerRelay:
        print('[FallbackEngine] Dispatched via PEER RELAY Store-and-Forward (Simulated)');
        await _queueRepo.enqueueIncident(payloadWithBc);
        _commManager.setNetworkState(queuedCount: _queueRepo.queueCount);
        break;

      case ConnectionChannel.offlineQueue:
        print('[FallbackEngine] Completely Offline. Encrypting & Enqueuing to Hive storage');
        await _queueRepo.enqueueIncident(payloadWithBc);
        _commManager.setNetworkState(queuedCount: _queueRepo.queueCount);
        break;
    }

    return payloadWithBc;
  }
}

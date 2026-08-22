import 'models/communication_status.dart';
import 'models/incident_payload.dart';
import 'models/blockchain_record.dart';
import 'services/communication_manager.dart';
import 'services/offline_queue.dart';
import 'services/sync_manager.dart';
import 'services/blockchain_service.dart';
import 'services/fallback_engine.dart';

class P4ServiceFacade {
  final CommunicationManagerService commManager;
  final OfflineQueueRepository queueRepo;
  final SyncManager syncManager;
  final BlockchainService blockchainService;
  final ChannelFallbackEngine fallbackEngine;

  P4ServiceFacade({String backendUrl = 'http://localhost:8000'})
      : commManager = CommunicationManagerService(),
        queueRepo = OfflineQueueRepository(),
        blockchainService = BlockchainService(),
        syncManager = SyncManager(
          queueRepo: OfflineQueueRepository(),
          commManager: CommunicationManagerService(),
          backendBaseUrl: backendUrl,
        ),
        fallbackEngine = ChannelFallbackEngine(
          commManager: CommunicationManagerService(),
          queueRepo: OfflineQueueRepository(),
          syncManager: SyncManager(
            queueRepo: OfflineQueueRepository(),
            commManager: CommunicationManagerService(),
            backendBaseUrl: backendUrl,
          ),
          blockchainService: BlockchainService(),
        );

  Stream<CommunicationStatus> get statusStream => commManager.statusStream;

  Future<IncidentPayload> triggerIncident({
    required String eventType,
    required Map<String, dynamic> locationEstimate,
    required Map<String, dynamic> riskAssessment,
    Map<String, dynamic>? safeHaven,
    String userId = 'DEMO_TOURIST_99',
  }) async {
    final rawPayload = IncidentPayload(
      incidentId: 'INC-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      timestamp: DateTime.now(),
      eventType: eventType,
      location: locationEstimate,
      riskAssessment: riskAssessment,
      safeHaven: safeHaven,
      channelUsed: commManager.getSelectedChannelString(),
    );

    return await fallbackEngine.processIncident(rawPayload);
  }

  Future<BlockchainRecord> recordBlockchainHash(IncidentPayload payload) async {
    return await blockchainService.recordIncidentOnChain(payload);
  }

  Future<bool> forceSyncQueue() async {
    return await syncManager.attemptSync();
  }

  void setNetworkSimulation({bool? internet, bool? sms, bool? relay}) {
    commManager.setNetworkState(
      internet: internet,
      sms: sms,
      relay: relay,
      queuedCount: queueRepo.queueCount,
    );
  }
}

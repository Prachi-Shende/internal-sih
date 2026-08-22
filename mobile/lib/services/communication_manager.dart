import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/communication_status.dart';

enum ConnectionChannel { internet, sms, peerRelay, offlineQueue }

class CommunicationManagerService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<CommunicationStatus> _statusController = StreamController<CommunicationStatus>.broadcast();

  bool _isInternetAvailable = true;
  bool _isSmsAvailable = false;
  bool _isRelayAvailable = false;
  int _queuedEventsCount = 0;
  DateTime _lastSyncTimestamp = DateTime.now();

  Stream<CommunicationStatus> get statusStream => _statusController.stream;

  CommunicationManagerService() {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      bool hasNet = results.any((r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet);
      setNetworkState(internet: hasNet);
    });
  }

  void setNetworkState({bool? internet, bool? sms, bool? relay, int? queuedCount}) {
    if (internet != null) _isInternetAvailable = internet;
    if (sms != null) _isSmsAvailable = sms;
    if (relay != null) _isRelayAvailable = relay;
    if (queuedCount != null) _queuedEventsCount = queuedCount;

    _broadcastStatus();
  }

  ConnectionChannel selectOptimalChannel() {
    if (_isInternetAvailable) return ConnectionChannel.internet;
    if (_isSmsAvailable) return ConnectionChannel.sms;
    if (_isRelayAvailable) return ConnectionChannel.peerRelay;
    return ConnectionChannel.offlineQueue;
  }

  String getSelectedChannelString() {
    switch (selectOptimalChannel()) {
      case ConnectionChannel.internet:
        return 'INTERNET';
      case ConnectionChannel.sms:
        return 'SMS';
      case ConnectionChannel.peerRelay:
        return 'PEER_RELAY';
      case ConnectionChannel.offlineQueue:
        return 'OFFLINE_QUEUE';
    }
  }

  void recordSyncCompleted(int remainingQueueCount) {
    _queuedEventsCount = remainingQueueCount;
    _lastSyncTimestamp = DateTime.now();
    _broadcastStatus();
  }

  void _broadcastStatus() {
    final status = CommunicationStatus(
      internet: _isInternetAvailable,
      sms: _isSmsAvailable,
      relay: _isRelayAvailable,
      selectedChannel: getSelectedChannelString(),
      queuedEventsCount: _queuedEventsCount,
      lastSyncTimestamp: _lastSyncTimestamp,
    );
    _statusController.add(status);
  }

  void dispose() {
    _statusController.close();
  }
}

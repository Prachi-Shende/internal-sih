import 'dart:async';
import 'package:flutter/material.dart';

import '../resilience/core/resilience_engine.dart';
import '../resilience/models/gps_health.dart';
import '../resilience/models/infrastructure_case.dart';
import '../resilience/models/position_source.dart';
import '../resilience/models/positioning_mode.dart';
import '../resilience/models/resilience_event.dart';
import '../resilience/models/resilience_state.dart';
import '../resilience/models/wifi_fingerprint.dart';
import '../resilience/sensors/wifi_scanner.dart';
import '../safety/core/safety_engine.dart';
import '../safety/core/sync_manager.dart';
import '../safety/models/safety_event.dart';
import 'wifi_fingerprint_lab_screen.dart';

/// High-observability testing console for real Android phone resilience validation.
class ResilienceDashboardScreen extends StatefulWidget {
  final ResilienceEngine resilienceEngine;
  final SafetyEngine? safetyEngine;
  final bool autoStart;

  const ResilienceDashboardScreen({
    super.key,
    required this.resilienceEngine,
    this.safetyEngine,
    this.autoStart = true,
  });

  @override
  State<ResilienceDashboardScreen> createState() => _ResilienceDashboardScreenState();
}

class _ResilienceDashboardScreenState extends State<ResilienceDashboardScreen> {
  ResilienceEngine get engine => widget.resilienceEngine;
  late final SafetyEngine _safetyEngine;
  bool _isScanningWifi = false;
  bool _isSyncingSafety = false;
  SafetyEvent? _lastSafetyEvent;
  int _pendingEventsCount = 0;

  StreamSubscription<SafetyEvent>? _safetyEventSub;
  StreamSubscription<SyncReport>? _syncReportSub;
  StreamSubscription<ResilienceState>? _resilienceStateSub;

  @override
  void initState() {
    super.initState();
    _safetyEngine = widget.safetyEngine ?? SafetyEngine(resilienceEngine: engine);

    if (widget.autoStart) {
      if (!engine.isRunning) {
        engine.start();
      }
      _safetyEngine.start();
    }

    _safetyEventSub = _safetyEngine.eventStream.listen((event) {
      if (mounted) {
        setState(() {
          _lastSafetyEvent = event;
        });
        _refreshQueueCount();
      }
    });

    _syncReportSub = _safetyEngine.syncManager.syncReportStream.listen((report) {
      if (mounted) {
        _refreshQueueCount();
      }
    });

    _resilienceStateSub = engine.stateStream.listen((_) {
      if (mounted) {
        _refreshQueueCount();
      }
    });

    _refreshQueueCount();
  }

  @override
  void dispose() {
    _safetyEventSub?.cancel();
    _syncReportSub?.cancel();
    _resilienceStateSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshQueueCount() async {
    final pending = await _safetyEngine.getPendingEvents();
    if (mounted) {
      setState(() {
        _pendingEventsCount = pending.length;
      });
    }
  }

  Color _getCaseColor(InfrastructureCase infraCase) {
    switch (infraCase) {
      case InfrastructureCase.case1:
        return const Color(0xFF3FB950); // Emerald Green
      case InfrastructureCase.case2:
        return const Color(0xFFE3B341); // Amber Yellow
      case InfrastructureCase.case3:
        return const Color(0xFF58A6FF); // Cyan Blue
      case InfrastructureCase.case4:
        return const Color(0xFFF85149); // Crimson Red
    }
  }

  Color _getGpsHealthColor(GpsHealth health) {
    switch (health) {
      case GpsHealth.active:
        return const Color(0xFF3FB950);
      case GpsHealth.stale:
        return const Color(0xFFE3B341);
      case GpsHealth.searching:
        return const Color(0xFF58A6FF);
      case GpsHealth.lost:
      case GpsHealth.disabled:
        return const Color(0xFFF85149);
    }
  }

  Color _getModeColor(PositioningMode mode) {
    switch (mode) {
      case PositioningMode.gps:
        return const Color(0xFF3FB950);
      case PositioningMode.pdrFallback:
        return const Color(0xFFE3B341);
      case PositioningMode.recovering:
        return const Color(0xFF58A6FF);
    }
  }

  Color _getSourceColor(PositionSource? source) {
    switch (source) {
      case PositionSource.gps:
        return const Color(0xFF3FB950);
      case PositionSource.pdr:
        return const Color(0xFFE3B341);
      case PositionSource.fused:
        return const Color(0xFF58A6FF);
      case PositionSource.wifiFingerprint:
        return const Color(0xFFBC8CFF);
      case PositionSource.wifiRtt:
        return const Color(0xFFD2A8FF);
      case PositionSource.mapMatched:
        return const Color(0xFF39D353);
      case PositionSource.lastKnown:
      case null:
        return const Color(0xFFF85149);
    }
  }

  String _formatTimeAgo(DateTime? timestamp) {
    if (timestamp == null) return 'Never';
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 5) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  Future<void> _triggerWifiScan() async {
    setState(() => _isScanningWifi = true);

    if (engine.wifiScanner is SimulatedWifiScanner) {
      final simScanner = engine.wifiScanner as SimulatedWifiScanner;
      if (simScanner.lastScan == null) {
        simScanner.injectScan(
          WifiFingerprint(
            timestamp: DateTime.now(),
            observations: const [
              WifiAccessPointObservation(bssid: '00:11:22:33:44:02', ssid: 'Hotel_Admin_Internal', rssi: -49, channel: 6),
              WifiAccessPointObservation(bssid: '00:11:22:33:44:03', ssid: 'Cafe_Express_WiFi', rssi: -52, channel: 11),
              WifiAccessPointObservation(bssid: '00:11:22:33:44:04', ssid: 'Corridor_Repeater_02', rssi: -58, channel: 36),
            ],
          ),
        );
      }
    }

    final result = await engine.performWifiLocalizationScan();
    if (mounted) {
      setState(() => _isScanningWifi = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF161B22),
          content: Text(
            result != null && result.isAccepted
                ? 'Matched Anchor: ${result.matchedAnchor?.name} (Score: ${(result.similarityScore * 100).toStringAsFixed(0)}%)'
                : 'No Anchor Match: ${result?.rejectionReason ?? "Scan completed (0 APs)"}',
            style: TextStyle(
              color: result != null && result.isAccepted ? const Color(0xFF3FB950) : const Color(0xFFE3B341),
              fontWeight: FontWeight.bold,
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _confirmResetTestSession() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Reset Test Session?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will clear recent event logs, transition history, and test counters without modifying the anchor database or PDR algorithm.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF85149)),
            onPressed: () {
              Navigator.of(ctx).pop();
              engine.resetTestSession();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Test session telemetry reset.'),
                  backgroundColor: Color(0xFF161B22),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ResilienceState>(
      stream: engine.stateStream,
      initialData: engine.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? engine.currentState;
        final infraCase = state.infrastructureCase;
        final caseColor = _getCaseColor(infraCase);

        return Scaffold(
          backgroundColor: const Color(0xFF0D1117),
          appBar: AppBar(
            backgroundColor: const Color(0xFF161B22),
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: caseColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: caseColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.shield_outlined, color: caseColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resilience Orchestrator',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        state.systemStatusLabel,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: caseColor, letterSpacing: 0.4),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.science_outlined, color: Color(0xFFBC8CFF)),
                tooltip: 'Wi-Fi Fingerprint Lab',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => WifiFingerprintLabScreen(resilienceEngine: engine),
                    ),
                  );
                },
              ),
              IconButton(
                icon: _isScanningWifi
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFBC8CFF)),
                      )
                    : const Icon(Icons.wifi_find, color: Color(0xFF58A6FF)),
                tooltip: 'Scan Wi-Fi Anchors',
                onPressed: _isScanningWifi ? null : _triggerWifiScan,
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white60),
                tooltip: 'Reset Test Session',
                onPressed: _confirmResetTestSession,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              // PART 3 & PART 4: Automatic Four-Case & Active Strategy Card (Overflow-proof)
              _buildInfrastructureCaseCard(state, infraCase, caseColor),
              const SizedBox(height: 12),

              // PART 8: Primary High-Observability System Status Card
              _buildSystemStatusCard(state),
              const SizedBox(height: 12),

              // STEP 5: Safety & Emergency Communication Card
              _buildSafetyEngineCard(state),
              const SizedBox(height: 12),

              // PART 6: Wi-Fi Localization Status Card
              _buildWifiLocalizationCard(state),
              const SizedBox(height: 12),

              // PART 7: Offline Map Constraint Card
              _buildMapConstraintCard(state),
              const SizedBox(height: 12),

              // PART 9: Resilience Event Log
              _buildEventLogCard(),
              const SizedBox(height: 12),

              // PART 11 & 12: Developer Simulation Controls Sandbox
              _buildSimulationSandboxCard(),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // CARD 1: INFRASTRUCTURE CASE & STRATEGY (PART 3 & 4)
  // ============================================================

  Widget _buildInfrastructureCaseCard(
    ResilienceState state,
    InfrastructureCase infraCase,
    Color caseColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: caseColor.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: caseColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar (Overflow-Protected)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: caseColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: caseColor,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: caseColor, blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    infraCase.title,
                    style: TextStyle(
                      color: caseColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: caseColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    infraCase.shortTitle,
                    style: TextStyle(color: caseColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Infrastructure Badges Row
                Row(
                  children: [
                    Expanded(
                      child: _buildInfraBadge(
                        'GPS SATELLITE',
                        state.capabilities.gpsHealth.isHealthy,
                        state.capabilities.gpsHealth.label,
                        _getGpsHealthColor(state.capabilities.gpsHealth),
                        Icons.satellite_alt,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfraBadge(
                        'INTERNET DATA',
                        state.capabilities.internetAvailable,
                        state.capabilities.internetAvailable ? 'ONLINE' : 'OFFLINE',
                        state.capabilities.internetAvailable ? const Color(0xFF3FB950) : const Color(0xFFF85149),
                        Icons.language,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 10),

                // Active Strategy Summary
                _buildStrategyRow(
                  icon: Icons.explore_outlined,
                  label: 'Positioning',
                  value: infraCase.positioningStrategy,
                  accentColor: const Color(0xFF58A6FF),
                ),
                const SizedBox(height: 6),
                _buildStrategyRow(
                  icon: Icons.cloud_sync_outlined,
                  label: 'Communication',
                  value: infraCase.communicationStrategy,
                  accentColor: const Color(0xFFBC8CFF),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfraBadge(String label, bool isAvailable, String statusText, Color color, IconData icon) {
    final iconSign = isAvailable ? '✓' : '✗';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Text(
                  '$iconSign $statusText',
                  style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyRow({
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: accentColor, size: 14),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(color: Colors.white60, fontSize: 10.5)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(color: accentColor, fontSize: 10.5, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CARD 2: SYSTEM STATUS (PART 8 REQUIREMENTS)
  // ============================================================

  Widget _buildSystemStatusCard(ResilienceState state) {
    final pos = state.position;
    final modeColor = _getModeColor(state.positioningMode);
    final sourceColor = _getSourceColor(pos?.source);
    final gpsHealth = state.capabilities.gpsHealth;
    final gpsColor = _getGpsHealthColor(gpsHealth);
    final isPdrActive = state.positioningMode == PositioningMode.pdrFallback ||
        state.position?.source == PositionSource.pdr;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'SYSTEM STATUS',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getCaseColor(state.infrastructureCase).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    state.systemStatusLabel,
                    style: TextStyle(
                      color: _getCaseColor(state.infrastructureCase),
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 16),

          // 2x2 Key Metric Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'GPS HEALTH',
                  value: gpsHealth.label,
                  valueColor: gpsColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  title: 'INTERNET',
                  value: state.capabilities.internetAvailable ? 'ONLINE' : 'OFFLINE',
                  valueColor: state.capabilities.internetAvailable ? const Color(0xFF3FB950) : const Color(0xFFF85149),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'POSITIONING MODE',
                  value: state.positioningMode.name.toUpperCase(),
                  valueColor: modeColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  title: 'POSITION SOURCE',
                  value: pos?.source.name.toUpperCase() ?? 'NONE',
                  valueColor: sourceColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Primary Numerical Telemetry
          _buildDetailRow('LATITUDE', pos != null ? '${pos.latitude.toStringAsFixed(6)}°' : 'Acquiring...'),
          _buildDetailRow('LONGITUDE', pos != null ? '${pos.longitude.toStringAsFixed(6)}°' : 'Acquiring...'),
          _buildDetailRow(
            'CONFIDENCE',
            pos != null ? '${(pos.confidence * 100).toStringAsFixed(0)}% (${state.confidenceLabel})' : 'N/A',
            valueColor: pos != null && pos.confidence >= 0.80 ? const Color(0xFF3FB950) : const Color(0xFFE3B341),
          ),
          _buildDetailRow(
            'UNCERTAINTY',
            pos != null ? '±${pos.uncertaintyMeters.toStringAsFixed(1)} m' : 'N/A',
            valueColor: pos != null && pos.uncertaintyMeters <= 10.0 ? const Color(0xFF3FB950) : const Color(0xFFE3B341),
          ),
          _buildDetailRow('LAST GPS FIX', _formatTimeAgo(engine.gpsProvider.lastFixTimestamp)),
          _buildDetailRow('LAST WIFI SCAN', _formatTimeAgo(state.lastWifiScanTimestamp)),
          _buildDetailRow(
            'PDR STATUS',
            isPdrActive ? 'ACTIVE (${state.pdrDisplacementMeters.toStringAsFixed(1)}m)' : 'STANDBY (Anchored to GPS)',
            valueColor: isPdrActive ? const Color(0xFFE3B341) : Colors.white60,
          ),
          _buildDetailRow(
            'ANCHOR',
            state.lastMatchedAnchor != null ? state.lastMatchedAnchor!.id : 'NONE',
            valueColor: state.lastMatchedAnchor != null ? const Color(0xFFBC8CFF) : Colors.white60,
          ),
          _buildDetailRow(
            'MAP CONSTRAINT',
            state.isMapConstrained ? 'MAP MATCHED' : 'UNCONSTRAINED',
            valueColor: state.isMapConstrained ? const Color(0xFF39D353) : Colors.white60,
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyEngineCard(ResilienceState state) {
    const safetyColor = Color(0xFFF85149); // Emergency Crimson Red
    final lastEvent = _lastSafetyEvent;
    final isOnline = state.capabilities.internetAvailable;

    Color deliveryColor = Colors.white60;
    if (lastEvent != null) {
      if (lastEvent.eventStatus == EventDeliveryStatus.sent || lastEvent.eventStatus == EventDeliveryStatus.acknowledged) {
        deliveryColor = const Color(0xFF3FB950); // Green
      } else if (lastEvent.eventStatus == EventDeliveryStatus.queued || lastEvent.eventStatus == EventDeliveryStatus.pending) {
        deliveryColor = const Color(0xFFE3B341); // Amber
      } else {
        deliveryColor = const Color(0xFFF85149); // Red
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: safetyColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: safetyColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: safetyColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emergency, color: safetyColor, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'SAFETY & EMERGENCY ENGINE',
                    style: TextStyle(
                      color: safetyColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (_pendingEventsCount > 0 ? const Color(0xFFE3B341) : const Color(0xFF3FB950)).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _pendingEventsCount > 0 ? '$_pendingEventsCount QUEUED' : 'QUEUE EMPTY',
                    style: TextStyle(
                      color: _pendingEventsCount > 0 ? const Color(0xFFE3B341) : const Color(0xFF3FB950),
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2x2 Metric Summary Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        title: 'SOS ENGINE',
                        value: lastEvent != null ? lastEvent.eventType.label : 'READY',
                        valueColor: lastEvent != null ? safetyColor : const Color(0xFF3FB950),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        title: 'DELIVERY CHANNEL',
                        value: isOnline ? 'INTERNET' : 'OFFLINE QUEUE',
                        valueColor: isOnline ? const Color(0xFF58A6FF) : const Color(0xFFE3B341),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        title: 'LOCAL QUEUE',
                        value: '$_pendingEventsCount PENDING',
                        valueColor: _pendingEventsCount > 0 ? const Color(0xFFE3B341) : const Color(0xFF3FB950),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        title: 'DELIVERY STATUS',
                        value: lastEvent?.eventStatus.label ?? 'IDLE',
                        valueColor: deliveryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Numerical Telemetry Rows
                _buildDetailRow(
                  'CURRENT POSITION',
                  lastEvent != null
                      ? (lastEvent.hasValidLocation
                          ? '${lastEvent.positionSource?.name.toUpperCase() ?? "UNKNOWN"} (${lastEvent.latitude!.toStringAsFixed(5)}°, ${lastEvent.longitude!.toStringAsFixed(5)}°)'
                          : 'UNAVAILABLE (No valid fix)')
                      : (state.position != null
                          ? '${state.position!.source.name.toUpperCase()} (${state.position!.latitude.toStringAsFixed(5)}°, ${state.position!.longitude.toStringAsFixed(5)}°)'
                          : 'UNAVAILABLE'),
                  valueColor: (lastEvent?.hasValidLocation ?? (state.position != null)) ? const Color(0xFF3FB950) : const Color(0xFFF85149),
                ),
                _buildDetailRow(
                  'CONFIDENCE',
                  lastEvent?.confidence != null
                      ? '${(lastEvent!.confidence! * 100).toStringAsFixed(0)}% (±${lastEvent.uncertaintyMeters?.toStringAsFixed(1) ?? "?"}m)'
                      : (state.position != null
                          ? '${(state.position!.confidence * 100).toStringAsFixed(0)}% (±${state.position!.uncertaintyMeters.toStringAsFixed(1)}m)'
                          : 'N/A'),
                ),
                _buildDetailRow(
                  'LAST EVENT ID',
                  lastEvent?.eventId ?? 'NONE',
                  valueColor: lastEvent != null ? const Color(0xFFBC8CFF) : Colors.white60,
                ),
                _buildDetailRow(
                  'LAST SYNC',
                  _formatTimeAgo(_safetyEngine.syncManager.lastSyncTimestamp),
                ),

                const SizedBox(height: 12),

                // Interactive Action Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF85149),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.emergency_share, size: 16),
                        label: const Text(
                          'TEST SOS',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        onPressed: _triggerTestSos,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 3,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF58A6FF)),
                        label: Text(
                          'QUEUE ($_pendingEventsCount)',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: _showEventQueueDialog,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF21262D),
                          foregroundColor: const Color(0xFF58A6FF),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _isSyncingSafety
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF58A6FF)),
                              )
                            : const Icon(Icons.sync, size: 14),
                        label: const Text('SYNC', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        onPressed: _isSyncingSafety ? null : _triggerSafetySync,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerTestSos() async {
    final event = await _safetyEngine.createSos(metadata: {'source': 'ResilienceDashboard_TestButton'});
    _refreshQueueCount();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF161B22),
          content: Row(
            children: [
              const Icon(Icons.emergency, color: Color(0xFFF85149), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SOS Generated: ${event.eventId} [${event.eventStatus.label}]',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _triggerSafetySync() async {
    setState(() => _isSyncingSafety = true);
    final report = await _safetyEngine.syncNow();
    await _refreshQueueCount();
    if (mounted) {
      setState(() => _isSyncingSafety = false);

      final String syncMessage;
      if (report.totalPending == 0) {
        syncMessage = 'Sync Complete: All events already up to date (Queue empty).';
      } else if (report.failedCount == 0) {
        syncMessage = 'Sync Complete: ${report.successfullySent} event(s) sent successfully.';
      } else {
        syncMessage = 'Sync Report: ${report.successfullySent} sent, ${report.failedCount} failed (${report.totalPending} in batch)';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF161B22),
          content: Text(
            syncMessage,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showEventQueueDialog() async {
    final events = await _safetyEngine.getAllEvents();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: Color(0xFF58A6FF), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Local Safety Event Store',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text('${events.length} total', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 12),
            if (events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No safety events in local store.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: events.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (ctx, index) {
                    final item = events[index];
                    final isSent = item.eventStatus == EventDeliveryStatus.sent || item.eventStatus == EventDeliveryStatus.acknowledged;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            item.eventType == SafetyEventType.sos ? Icons.emergency : Icons.info_outline,
                            color: item.eventType == SafetyEventType.sos ? const Color(0xFFF85149) : const Color(0xFF58A6FF),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.eventId,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.hasValidLocation
                                      ? '${item.positionSource?.name.toUpperCase()} • ${item.latitude!.toStringAsFixed(5)}°, ${item.longitude!.toStringAsFixed(5)}° (±${item.uncertaintyMeters?.toStringAsFixed(1) ?? "?"}m)'
                                      : 'No position fix • ${item.positionSource?.name.toUpperCase() ?? "NONE"}',
                                  style: const TextStyle(color: Colors.white60, fontSize: 10.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isSent ? const Color(0xFF3FB950) : const Color(0xFFE3B341)).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.eventStatus.label,
                                  style: TextStyle(
                                    color: isSent ? const Color(0xFF3FB950) : const Color(0xFFE3B341),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.deliveryChannel ?? 'OFFLINE',
                                style: const TextStyle(color: Colors.white38, fontSize: 9),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: valueColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: valueColor, fontSize: 12, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARD 3: WI-FI LOCALIZATION STATUS (PART 6)
  // ============================================================

  Widget _buildWifiLocalizationCard(ResilienceState state) {
    final matched = state.lastMatchedAnchor;
    final status = state.lastWifiAnchorStatus ?? 'IDLE';
    final isMatched = status == 'MATCHED';
    final isRejected = status.contains('REJECTED');
    final statusColor = isMatched
        ? const Color(0xFF3FB950)
        : (isRejected ? const Color(0xFFF85149) : const Color(0xFFE3B341));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBC8CFF).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.wifi, color: Color(0xFFBC8CFF), size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'WI-FI LOCALIZATION',
                        style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: statusColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 16),
          _buildDetailRow(
            'SCANNER',
            state.capabilities.wifiAvailable ? '● ACTIVE (Hardware)' : '● UNAVAILABLE',
            valueColor: state.capabilities.wifiAvailable ? const Color(0xFF3FB950) : const Color(0xFFF85149),
          ),
          _buildDetailRow('LAST SCAN', _formatTimeAgo(state.lastWifiScanTimestamp)),
          _buildDetailRow('APS DETECTED', '${state.wifiScanApsCount} nearby APs'),
          _buildDetailRow(
            'BEST ANCHOR',
            matched != null ? '${matched.name} (${matched.id})' : 'None',
            valueColor: matched != null ? const Color(0xFFBC8CFF) : Colors.white60,
          ),
          if (state.lastWifiSimilarityScore != null)
            _buildDetailRow(
              'SIMILARITY',
              '${(state.lastWifiSimilarityScore! * 100).toStringAsFixed(1)}%',
              valueColor: const Color(0xFFBC8CFF),
            ),
          _buildDetailRow(
            'CORRECTION',
            state.lastWifiCorrectionStatus ?? 'NONE',
            valueColor: state.lastWifiCorrectionStatus == 'APPLIED'
                ? const Color(0xFF3FB950)
                : Colors.white60,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARD 4: MAP CONSTRAINT STATUS (PART 7)
  // ============================================================

  Widget _buildMapConstraintCard(ResilienceState state) {
    final isConstrained = state.isMapConstrained;
    final color = isConstrained ? const Color(0xFF39D353) : Colors.white60;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF39D353).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.alt_route, color: Color(0xFF39D353), size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'OFFLINE MAP CONSTRAINT',
                        style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  isConstrained ? 'MATCHED' : 'NOT APPLIED',
                  style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 16),
          _buildDetailRow(
            'STATUS',
            state.lastMapConstraintStatus ?? (isConstrained ? 'MATCHED' : 'NOT APPLIED'),
            valueColor: color,
          ),
          if (state.lastMapConstraintDistanceMeters != null)
            _buildDetailRow(
              'DISTANCE TO CORRIDOR',
              '${state.lastMapConstraintDistanceMeters!.toStringAsFixed(1)} m to centerline',
              valueColor: const Color(0xFF39D353),
            ),
          _buildDetailRow(
            'CONSTRAINT',
            isConstrained ? 'WALKABLE CORRIDOR' : 'None (<15m radius filter)',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARD 5: RESILIENCE EVENT LOG (PART 9)
  // ============================================================

  Widget _buildEventLogCard() {
    final events = engine.eventHistory;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history, color: Colors.cyanAccent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'RESILIENCE EVENT LOG (${events.length})',
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (events.isNotEmpty)
                GestureDetector(
                  onTap: _confirmResetTestSession,
                  child: const Text('Clear', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ),
            ],
          ),
          const Divider(color: Colors.white10, height: 16),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text('No resilience events recorded yet.', style: TextStyle(color: Colors.white38, fontSize: 11.5)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: events.length > 8 ? 8 : events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                final timeStr = event.timestamp.toIso8601String().substring(11, 19);

                Color eventColor = const Color(0xFF58A6FF);
                if (event.type == ResilienceEventType.gpsLost ||
                    event.type == ResilienceEventType.pdrAnchorCorrectionRejected) {
                  eventColor = const Color(0xFFF85149);
                } else if (event.type == ResilienceEventType.gpsRecovered ||
                    event.type == ResilienceEventType.wifiAnchorMatched) {
                  eventColor = const Color(0xFF3FB950);
                } else if (event.type == ResilienceEventType.mapConstraintApplied) {
                  eventColor = const Color(0xFF39D353);
                } else if (event.type.name.contains('wifi') || event.type.name.contains('Anchor')) {
                  eventColor = const Color(0xFFBC8CFF);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeStr,
                        style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatEventTitle(event.type),
                              style: TextStyle(color: eventColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (event.diagnosticInfo.isNotEmpty)
                              Text(
                                event.diagnosticInfo,
                                style: const TextStyle(color: Colors.white70, fontSize: 9.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatEventTitle(ResilienceEventType type) {
    switch (type) {
      case ResilienceEventType.gpsAcquired:
        return 'GPS ACQUIRED';
      case ResilienceEventType.gpsLost:
        return 'GPS LOST';
      case ResilienceEventType.gpsRecovered:
        return 'GPS RECOVERED';
      case ResilienceEventType.switchedToPdr:
        return 'MODE → PDR FALLBACK';
      case ResilienceEventType.pdrReanchored:
        return 'PDR RE-ANCHORED (GPS)';
      case ResilienceEventType.pdrAnchorCorrected:
        return 'PDR RE-ANCHORED (WI-FI)';
      case ResilienceEventType.positioningDegraded:
        return 'POSITIONING DEGRADED';
      case ResilienceEventType.positioningRecovered:
        return 'POSITIONING RECOVERED';
      case ResilienceEventType.wifiAnchorMatched:
        return 'WIFI ANCHOR MATCHED';
      case ResilienceEventType.wifiAnchorRejected:
        return 'WIFI ANCHOR REJECTED';
      case ResilienceEventType.pdrAnchorCorrectionRejected:
        return 'ANCHOR REJECTED (TOO FAR)';
      case ResilienceEventType.mapConstraintApplied:
        return 'MAP CONSTRAINT APPLIED';
      case ResilienceEventType.mapConstraintRejected:
        return 'MAP CONSTRAINT SKIPPED';
      case ResilienceEventType.offlineAnchorUsed:
        return 'OFFLINE ANCHOR USED';
      case ResilienceEventType.wifiScanStarted:
        return 'WI-FI SCAN STARTED';
      case ResilienceEventType.wifiScanCompleted:
        return 'WI-FI SCAN COMPLETED';
      case ResilienceEventType.modeChanged:
        return 'MODE CHANGED';
    }
  }

  // ============================================================
  // CARD 6: DEVELOPER SIMULATION SANDBOX (PART 11 & 12)
  // ============================================================

  Widget _buildSimulationSandboxCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.developer_mode, color: Colors.amberAccent, size: 16),
              SizedBox(width: 6),
              Text(
                'DEVELOPER SIMULATION SANDBOX',
                style: TextStyle(color: Colors.amberAccent, fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Hardware state is authoritative on real devices. Use these controls to force-simulate blackout scenarios.',
            style: TextStyle(color: Colors.white54, fontSize: 10.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildOverrideChip(ResilienceOverrideMode.auto, '● AUTO (Hardware)'),
              _buildOverrideChip(ResilienceOverrideMode.forceGps, 'CASE 1: GPS+Net ON'),
              _buildOverrideChip(ResilienceOverrideMode.simulateGpsLoss, 'CASE 2: GPS OFF / Net ON'),
              _buildOverrideChip(ResilienceOverrideMode.simulateOffline, 'CASE 3: GPS ON / Net OFF'),
              _buildOverrideChip(ResilienceOverrideMode.forcePdr, 'CASE 4: GPS+Net OFF'),
              _buildOverrideChip(ResilienceOverrideMode.simulateTotalBlackout, 'TOTAL BLACKOUT'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8957E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.wifi_find, size: 16),
                  label: const Text('SCAN WI-FI NOW', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: _isScanningWifi ? null : _triggerWifiScan,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF21262D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.science, size: 16, color: Color(0xFFBC8CFF)),
                label: const Text('WI-FI LAB', style: TextStyle(fontSize: 11.5)),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => WifiFingerprintLabScreen(resilienceEngine: engine),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverrideChip(ResilienceOverrideMode mode, String label) {
    final isSelected = engine.overrideMode == mode;

    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      selected: isSelected,
      selectedColor: const Color(0xFF1F6FEB),
      backgroundColor: const Color(0xFF0D1117),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            engine.setOverrideMode(mode);
          });
        }
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'models/communication_status.dart';
import 'models/incident_payload.dart';
import 'models/blockchain_record.dart';
import 'p4_service_facade.dart';

void main() {
  runApp(const TouristSafetyApp());
}

class TouristSafetyApp extends StatelessWidget {
  const TouristSafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tourist Safety Engine — P4 Resilience Module',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepOrange,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
      ),
      home: const ResilienceDashboardScreen(),
    );
  }
}

class ResilienceDashboardScreen extends StatefulWidget {
  const ResilienceDashboardScreen({super.key});

  @override
  State<ResilienceDashboardScreen> createState() => _ResilienceDashboardScreenState();
}

class _ResilienceDashboardScreenState extends State<ResilienceDashboardScreen> {
  late final P4ServiceFacade _p4Facade;
  bool _internetOn = true;
  bool _smsOn = false;
  bool _relayOn = false;
  
  final List<IncidentPayload> _processedIncidents = [];
  final List<BlockchainRecord> _blockchainAuditLogs = [];

  @override
  void initState() {
    super.initState();
    _p4Facade = P4ServiceFacade();
    _p4Facade.setNetworkSimulation(internet: _internetOn, sms: _smsOn, relay: _relayOn);
  }

  void _toggleNetwork(String channel, bool val) {
    setState(() {
      if (channel == 'INTERNET') _internetOn = val;
      if (channel == 'SMS') _smsOn = val;
      if (channel == 'RELAY') _relayOn = val;
    });
    _p4Facade.setNetworkSimulation(internet: _internetOn, sms: _smsOn, relay: _relayOn);
  }

  Future<void> _simulateTriggerSOS() async {
    final locationP1 = {
      'lat': 19.0760,
      'lon': 72.8777,
      'source': 'PDR',
      'confidence': 0.63,
    };

    final riskP3 = {
      'risk': 'HIGH',
      'score': 78,
      'reasons': ['High reported-crime concentration', 'Low activity period'],
    };

    final safeHavenP3 = {
      'name': 'Hotel ABC Lobby',
      'distance_m': 280.0,
    };

    final incident = await _p4Facade.triggerIncident(
      eventType: 'SOS_TRIGGERED',
      locationEstimate: locationP1,
      riskAssessment: riskP3,
      safeHaven: safeHavenP3,
    );

    final bcRecord = await _p4Facade.recordBlockchainHash(incident);

    setState(() {
      _processedIncidents.insert(0, incident);
      _blockchainAuditLogs.insert(0, bcRecord);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('P4: Communication Resilience & Blockchain'),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAlignment.start,
          children: [
            // Section 1: Live Resilience Panel (P6 Visual Interface)
            _buildLiveResiliencePanel(),
            const SizedBox(height: 20),

            // Section 2: Network Simulation Toggles
            _buildNetworkSimulationControls(),
            const SizedBox(height: 20),

            // Section 3: User Trigger Simulation ("I FEEL UNSAFE" / "SOS")
            _buildTriggerControls(),
            const SizedBox(height: 20),

            // Section 4: Incident Timeline & Blockchain Verification Log
            _buildIncidentAuditTimeline(),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveResiliencePanel() {
    return StreamBuilder<CommunicationStatus>(
      stream: _p4Facade.statusStream,
      builder: (context, snapshot) {
        final status = snapshot.data;
        final channel = status?.selectedChannel ?? 'UNKNOWN';
        final queueCount = status?.queuedEventsCount ?? 0;

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('SYSTEM RESILIENCE STATUS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(20)),
                      child: Text('CHANNEL: $channel', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    )
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statusIndicator('Internet', status?.internet ?? false),
                    _statusIndicator('SMS', status?.sms ?? false),
                    _statusIndicator('Peer Relay', status?.relay ?? false),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Encrypted Offline Queue: $queueCount packet(s)', style: TextStyle(color: queueCount > 0 ? Colors.amber : Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusIndicator(String label, bool active) {
    return Column(
      children: [
        Icon(active ? Icons.check_circle : Icons.cancel, color: active ? Colors.green : Colors.red, size: 28),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildNetworkSimulationControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAlignment.start,
          children: [
            const Text('SIMULATION HARDWARE CONTROLS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
            SwitchListTile(
              title: const Text('Internet Radio (4G/5G/Wi-Fi)'),
              value: _internetOn,
              onChanged: (val) => _toggleNetwork('INTERNET', val),
            ),
            SwitchListTile(
              title: const Text('Cellular SMS Gateway'),
              value: _smsOn,
              onChanged: (val) => _toggleNetwork('SMS', val),
            ),
            SwitchListTile(
              title: const Text('Peer-to-Peer Relay Mesh (BLE/Wi-Fi Direct)'),
              value: _relayOn,
              onChanged: (val) => _toggleNetwork('RELAY', val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTriggerControls() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _simulateTriggerSOS,
            icon: const Icon(Icons.warning_amber_rounded, size: 28),
            label: const Text('TRIGGER EMERGENCY SOS (P3 Signal)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () async {
            final ok = await _p4Facade.forceSyncQueue();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Sync completed successfully!' : 'Sync failed. Server unreachable.')));
          },
          icon: const Icon(Icons.sync),
          label: const Text('FORCE BACKEND SYNC (FastAPI /api/v1/sync)'),
        )
      ],
    );
  }

  Widget _buildIncidentAuditTimeline() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAlignment.start,
          children: [
            const Text('TAMPER-EVIDENT BLOCKCHAIN AUDIT TIMELINE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.lightGreenAccent)),
            const SizedBox(height: 10),
            _blockchainAuditLogs.isEmpty
                ? const Text('No incidents recorded yet. Press Emergency SOS above.', style: TextStyle(color: Colors.grey))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _blockchainAuditLogs.length,
                    itemBuilder: (context, idx) {
                      final item = _blockchainAuditLogs[idx];
                      return ListTile(
                        leading: const Icon(Icons.verified, color: Colors.green),
                        title: Text('${item.eventType} (Block #${item.blockNumber})'),
                        subtitle: Text('TX: ${item.txHash.substring(0, 20)}...\nLoc Hash: ${item.locationHash.substring(0, 20)}...'),
                        isThreeLine: true,
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

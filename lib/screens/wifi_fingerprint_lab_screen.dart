import 'package:flutter/material.dart';

import '../resilience/core/resilience_engine.dart';
import '../resilience/models/localization_anchor.dart';
import '../resilience/models/wifi_fingerprint.dart';
import '../resilience/sensors/android_wifi_scanner.dart';

class WifiFingerprintLabScreen extends StatefulWidget {
  final ResilienceEngine resilienceEngine;

  const WifiFingerprintLabScreen({super.key, required this.resilienceEngine});

  @override
  State<WifiFingerprintLabScreen> createState() => _WifiFingerprintLabScreenState();
}

class _WifiFingerprintLabScreenState extends State<WifiFingerprintLabScreen> {
  ResilienceEngine get engine => widget.resilienceEngine;

  bool _isScanning = false;
  WifiFingerprint? _currentScan;
  String _scanStatusMessage = 'Ready to scan ambient Wi-Fi environment.';

  @override
  void initState() {
    super.initState();
    _checkScannerStatus();
  }

  Future<void> _checkScannerStatus() async {
    final scanner = engine.wifiScanner;
    if (scanner is AndroidWifiScanner) {
      final isEnabled = await scanner.isWifiEnabled();
      final hasPerms = await scanner.checkPermissions();

      if (!mounted) return;
      setState(() {
        if (!hasPerms) {
          _scanStatusMessage = 'Location & Wi-Fi permissions required for scanning.';
        } else if (!isEnabled) {
          _scanStatusMessage = 'Wi-Fi radio is disabled on device.';
        } else {
          _scanStatusMessage = 'Hardware Wi-Fi scanner ready.';
        }
      });
    }
  }

  Future<void> _performScan() async {
    setState(() {
      _isScanning = true;
      _scanStatusMessage = 'Scanning ambient 2.4GHz & 5GHz Wi-Fi channels...';
    });

    try {
      final scanResult = await engine.wifiScanner.scan();
      if (!mounted) return;

      setState(() {
        _isScanning = false;
        _currentScan = scanResult;
        if (scanResult == null || scanResult.count == 0) {
          _scanStatusMessage = 'No access points detected or scan throttled by OS.';
        } else {
          _scanStatusMessage = 'Successfully observed ${scanResult.count} access points.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _scanStatusMessage = 'Scan failed: $e';
      });
    }
  }

  void _showSaveAnchorDialog() {
    if (_currentScan == null || _currentScan!.count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please perform a scan before saving an anchor.')),
      );
      return;
    }

    final currentPos = engine.currentState.position;
    final idController = TextEditingController(
      text: 'anchor_lab_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
    );
    final nameController = TextEditingController(text: 'Lab Captured Landmark');
    final latController = TextEditingController(
      text: (currentPos?.latitude ?? 19.076050).toStringAsFixed(6),
    );
    final lonController = TextEditingController(
      text: (currentPos?.longitude ?? 72.877700).toStringAsFixed(6),
    );
    final floorController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: const Row(
            children: [
              Icon(Icons.bookmark_add, color: Colors.purpleAccent, size: 22),
              SizedBox(width: 8),
              Text(
                'Save Offline Anchor',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Associating ${_currentScan!.count} scanned APs with geodetic coordinates on-device.',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                _buildDialogField('Anchor Identifier', idController),
                _buildDialogField('Landmark Name', nameController),
                _buildDialogField('Latitude (°)', latController, isNumber: true),
                _buildDialogField('Longitude (°)', lonController, isNumber: true),
                _buildDialogField('Floor Level', floorController, isNumber: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent.shade700),
              onPressed: () async {
                final lat = double.tryParse(latController.text) ?? 19.076050;
                final lon = double.tryParse(lonController.text) ?? 72.877700;
                final floor = int.tryParse(floorController.text) ?? 0;

                final newAnchor = LocalizationAnchor(
                  id: idController.text.trim(),
                  name: nameController.text.trim(),
                  latitude: lat,
                  longitude: lon,
                  floor: floor,
                  fingerprint: _currentScan!,
                  uncertaintyMeters: 8.5,
                  confidence: 0.90,
                );

                await engine.anchorRepository.addAnchor(newAnchor);
                if (ctx.mounted) Navigator.of(ctx).pop();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF161B22),
                      content: Text(
                        'Saved anchor "${newAnchor.name}" (${newAnchor.id}) to offline repository!',
                        style: const TextStyle(color: Colors.lightGreenAccent),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Save Locally', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogField(String label, TextEditingController controller, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
          filled: true,
          fillColor: const Color(0xFF0D1117),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
    );
  }

  Color _getRssiColor(int rssi) {
    if (rssi >= -55) return Colors.lightGreenAccent;
    if (rssi >= -70) return Colors.cyanAccent;
    if (rssi >= -82) return Colors.amberAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final observations = _currentScan?.observations ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text(
          'Wi-Fi Fingerprint Lab',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add, color: Colors.purpleAccent),
            tooltip: 'Save Scanned Fingerprint as Anchor',
            onPressed: observations.isNotEmpty ? _showSaveAnchorDialog : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Status & Controls Banner
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'AMBIENT RADIO ENVIRONMENT',
                      style: TextStyle(
                        color: Colors.purpleAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${observations.length} APs',
                        style: const TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _scanStatusMessage,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purpleAccent.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _isScanning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.wifi_find, size: 18),
                        label: Text(_isScanning ? 'SCANNING...' : 'SCAN WI-FI NOW'),
                        onPressed: _isScanning ? null : _performScan,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF21262D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.bookmark_add, size: 18, color: Colors.purpleAccent),
                      label: const Text('CAPTURE'),
                      onPressed: observations.isNotEmpty ? _showSaveAnchorDialog : null,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // AP Observations List
          Expanded(
            child: observations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, size: 48, color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(height: 12),
                        const Text(
                          'No Wi-Fi scan results available.',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap "SCAN WI-FI NOW" to query local radio signals.',
                          style: TextStyle(color: Colors.white30, fontSize: 11),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: observations.length,
                    itemBuilder: (context, index) {
                      final ap = observations[index];
                      final rssiColor = _getRssiColor(ap.rssi);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B22),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: rssiColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.wifi, color: rssiColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ap.ssid.isNotEmpty ? ap.ssid : '<Hidden SSID>',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'BSSID: ${ap.bssid}',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  if (ap.frequencyMhz != null)
                                    Text(
                                      'Freq: ${ap.frequencyMhz} MHz (${ap.frequencyMhz! > 4000 ? "5GHz" : "2.4GHz"})',
                                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${ap.rssi} dBm',
                                  style: TextStyle(
                                    color: rssiColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ap.rssi >= -65 ? 'STRONG' : (ap.rssi >= -80 ? 'MODERATE' : 'WEAK'),
                                  style: TextStyle(color: rssiColor, fontSize: 9, fontWeight: FontWeight.bold),
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
    );
  }
}

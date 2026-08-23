import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../theme/app_colors.dart';
import '../services/app_state.dart';
import '../services/mock_data.dart';
import '../services/models.dart';
import 'safety_assist_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  bool _hasCenteredOnRealLocation = false;

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return AppColors.sage;
      case RiskLevel.medium:
      case RiskLevel.high:
        return AppColors.warning; // Amber
      case RiskLevel.critical:
        return AppColors.emergency; // Muted Coral
      case RiskLevel.unknown:
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _fetchRoute(double startLat, double startLon, double destLat, double destLon) async {
    try {
      final url = 'http://router.project-osrm.org/route/v1/foot/$startLon,$startLat;$destLon,$destLat?geometries=geojson';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords = data['routes'][0]['geometry']['coordinates'] as List;
        setState(() {
          _routePoints = coords.map((c) => LatLng(c[1], c[0])).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
    }
  }

  void _showSafeLocationDetails(BuildContext context, SafeLocation location, LocationEstimate currentLoc) {
    _fetchRoute(currentLoc.lat, currentLoc.lon, location.lat, location.lon);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield, color: AppColors.sage, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    location.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
                Text(
                  '${location.distance.toInt()} m',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.check_circle, size: 16, color: AppColors.sage),
                const SizedBox(width: 8),
                Text(location.type, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            if (location.isOpen)
              Row(
                children: const [
                  Icon(Icons.access_time, size: 16, color: AppColors.sage),
                  SizedBox(width: 8),
                  Text('Open now', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                ],
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${location.lat},${location.lon}&travelmode=walking');
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    debugPrint('Could not launch map: $e');
                  }
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('START NAVIGATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHotspotDetails(BuildContext context, Hotspot hotspot) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: _getRiskColor(hotspot.risk), size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Reported area nearby',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'This area has been flagged due to recent incident reports. Proceed with caution.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16, height: 1.5),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getRiskColor(hotspot.risk).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'High reported-crime concentration — Stay Alert.',
                    style: TextStyle(
                      color: _getRiskColor(hotspot.risk),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Danger Score', style: TextStyle(fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getRiskColor(hotspot.risk).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${hotspot.score.toInt()}/100', style: TextStyle(fontWeight: FontWeight.bold, color: _getRiskColor(hotspot.risk))),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Reported Incidents', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${hotspot.reportedIncidents}', style: TextStyle(fontWeight: FontWeight.bold, color: _getRiskColor(hotspot.risk))),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Incidents', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${hotspot.recentIncidents}', style: TextStyle(fontWeight: FontWeight.bold, color: _getRiskColor(hotspot.risk))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sage,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SafetyAssistScreen()));
                },
                child: const Text('VIEW SAFER PLACES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    final Distance distance = const Distance();
    
    // Check if a hotspot was tapped (within its radius)
    for (final hotspot in MockData.hotspots) {
      final center = LatLng(hotspot.centerLat, hotspot.centerLon);
      final m = distance.as(LengthUnit.Meter, point, center);
      if (m <= hotspot.radius) {
        _showHotspotDetails(context, hotspot);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentLocation = appState.currentLocation;
    final riskLevel = appState.currentRisk;
    final hotspots = MockData.hotspots;
    final safeLocations = MockData.safeLocations;

    // Auto-center map when we get the first real GPS fix (not the Mock Bali location)
    if (!_hasCenteredOnRealLocation && currentLocation.source == 'GPS' && currentLocation.lat != -8.7941) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(LatLng(currentLocation.lat, currentLocation.lon), 16.0);
        _hasCenteredOnRealLocation = true;
      });
    }

    bool insideHotspot = false;
    final Distance distance = const Distance();
    for (final h in hotspots) {
      if (distance.as(LengthUnit.Meter, LatLng(currentLocation.lat, currentLocation.lon), LatLng(h.centerLat, h.centerLon)) <= h.radius) {
        insideHotspot = true;
        break;
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          // The Interactive Map
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(currentLocation.lat, currentLocation.lon),
                initialZoom: 15.0,
                onTap: _handleMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.travara',
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: AppColors.primary,
                        strokeWidth: 4.0,
                      ),
                    ],
                  ),
                CircleLayer(
                  circles: hotspots.map((h) => CircleMarker(
                    point: LatLng(h.centerLat, h.centerLon),
                    color: _getRiskColor(h.risk).withOpacity(0.3),
                    borderColor: _getRiskColor(h.risk),
                    borderStrokeWidth: 2,
                    radius: h.radius,
                    useRadiusInMeter: true,
                  )).toList(),
                ),
                MarkerLayer(
                  markers: [
                    // Safe Locations
                    ...safeLocations.map((s) => Marker(
                      point: LatLng(s.lat, s.lon),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _showSafeLocationDetails(context, s, currentLocation),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                            ],
                          ),
                          child: const Icon(Icons.shield, color: AppColors.sage, size: 24),
                        ),
                      ),
                    )),
                    // Current Location
                    Marker(
                      point: LatLng(currentLocation.lat, currentLocation.lon),
                      width: 100,
                      height: 100,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)
                              ],
                            ),
                            child: Text(
                              currentLocation.confidence == LocationConfidence.high 
                                  ? 'HIGH CONFIDENCE' 
                                  : (currentLocation.confidence == LocationConfidence.low ? 'PDR ACTIVE' : 'MEDIUM CONFIDENCE'),
                              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Safety Gradient overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: _getRiskColor(riskLevel).withOpacity(0.05),
              ),
            ),
          ),

          // Bottom Navigation Card ("I FEEL UNSAFE")
          Positioned(
            bottom: 120, // Above floating bottom nav
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SafetyAssistScreen()));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emergency.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.security, color: AppColors.emergency, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'I FEEL UNSAFE',
                          style: TextStyle(
                            color: AppColors.emergency,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (insideHotspot)
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.emergency,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'WARNING: You have entered a high-risk zone. Stay alert.',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

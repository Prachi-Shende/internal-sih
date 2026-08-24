import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../services/app_state.dart';

/// Travel & Safety History Screen.
/// Visualizes recorded journeys with reconstructed route polylines distinguishing
/// high-confidence GPS points from PDR-estimated movement segments.
class TravelHistoryScreen extends StatefulWidget {
  const TravelHistoryScreen({Key? key}) : super(key: key);

  @override
  State<TravelHistoryScreen> createState() => _TravelHistoryScreenState();
}

class _TravelHistoryScreenState extends State<TravelHistoryScreen> {
  int _selectedJourneyIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final journeys = appState.savedJourneys;

    if (journeys.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Travel History', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        ),
        body: const Center(
          child: Text('No recorded journeys yet. Start traveling to record your route!', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final selectedJourney = journeys[_selectedJourneyIndex];
    final routePoints = selectedJourney.routePoints;

    // Build map center
    final centerLat = routePoints.isNotEmpty ? routePoints.first.lat : 18.9220;
    final centerLon = routePoints.isNotEmpty ? routePoints.first.lon : 72.8347;

    // Distinguish GPS polylines vs PDR polylines
    final List<LatLng> gpsPolyline = [];
    final List<LatLng> pdrPolyline = [];

    for (var pt in routePoints) {
      if (pt.isEstimated) {
        pdrPolyline.add(LatLng(pt.lat, pt.lon));
      } else {
        gpsPolyline.add(LatLng(pt.lat, pt.lon));
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Travel & Safety History', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Journey Selector Chips
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: journeys.length,
              itemBuilder: (context, idx) {
                final j = journeys[idx];
                final isSelected = idx == _selectedJourneyIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(j.title, style: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedJourneyIndex = idx);
                    },
                  ),
                );
              },
            ),
          ),

          // Interactive Map with Reconstructed Route
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(centerLat, centerLon),
                      initialZoom: 14.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.travara.app',
                      ),
                      // Route Polylines
                      PolylineLayer(
                        polylines: [
                          // Full trajectory
                          Polyline(
                            points: routePoints.map((p) => LatLng(p.lat, p.lon)).toList(),
                            color: AppColors.primary,
                            strokeWidth: 4.0,
                          ),
                          // PDR-estimated segments highlighted in dashed/amber
                          if (pdrPolyline.isNotEmpty)
                            Polyline(
                              points: pdrPolyline,
                              color: Colors.amber,
                              strokeWidth: 5.0,
                            ),
                        ],
                      ),
                      // Marker Layer (Start & End)
                      MarkerLayer(
                        markers: [
                          if (routePoints.isNotEmpty)
                            Marker(
                              point: LatLng(routePoints.first.lat, routePoints.first.lon),
                              width: 36,
                              height: 36,
                              child: const Icon(Icons.trip_origin, color: Colors.green, size: 28),
                            ),
                          if (routePoints.length > 1)
                            Marker(
                              point: LatLng(routePoints.last.lat, routePoints.last.lon),
                              width: 36,
                              height: 36,
                              child: const Icon(Icons.location_on, color: AppColors.emergency, size: 32),
                            ),
                        ],
                      ),
                    ],
                  ),
                  // Route Source Legend Overlay
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(width: 12, height: 3, color: AppColors.primary),
                              const SizedBox(width: 6),
                              const Text('GPS Route', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(width: 12, height: 3, color: Colors.amber),
                              const SizedBox(width: 6),
                              const Text('PDR Estimated', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Journey Metrics & Safety Card
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(selectedJourney.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatBox('Distance', '${(selectedJourney.distanceMeters / 1000).toStringAsFixed(2)} km', Icons.route),
                        _buildStatBox('Steps', '${selectedJourney.stepCount}', Icons.directions_walk),
                        _buildStatBox('Duration', '${selectedJourney.duration.inMinutes} min', Icons.timer),
                        _buildStatBox('Alerts', '${selectedJourney.safetyEventsCount}', Icons.shield_outlined),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.sage, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Route protected by P1 Resilient Positioning (${routePoints.where((p) => p.isEstimated).length} PDR dead-reckoning points fused).',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

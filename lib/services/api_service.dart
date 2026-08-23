import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'models.dart';
import 'mock_data.dart';
import 'session_service.dart';
import 'dart:math' as math;

class ApiService {
  static String get baseUrl => AppConfig.apiBaseUrl;
  
  static late String sessionId;

  static Future<void> init() async {
    sessionId = await SessionService.getOrCreateSessionId();
  }

  // Adapter for Location Confidence
  static LocationConfidence parseConfidence(double confidenceValue) {
    if (confidenceValue >= 0.7) return LocationConfidence.high;
    if (confidenceValue >= 0.4) return LocationConfidence.medium;
    return LocationConfidence.low;
  }

  // Adapter for Risk Level
  static RiskLevel parseRiskLevel(String riskStr) {
    switch (riskStr.toUpperCase()) {
      case 'LOW': return RiskLevel.low;
      case 'MEDIUM': return RiskLevel.medium;
      case 'HIGH': return RiskLevel.high;
      case 'CRITICAL': return RiskLevel.critical;
      default: return RiskLevel.unknown;
    }
  }

  // Calculate distance between two coordinates in meters
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = math.cos;
    var a = 0.5 - c((lat2 - lat1) * p) / 2 + c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)) * 1000;
  }

  static Future<LocationEstimate> getCurrentLocation() async {
    if (AppConfig.MOCK_MODE) return MockData.initialLocation;

    try {
      final response = await http.get(Uri.parse('$baseUrl/location/latest?session_id=$sessionId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return LocationEstimate(
          lat: data['lat'],
          lon: data['lon'],
          source: data['source'],
          confidence: parseConfidence(data['confidence'].toDouble()),
        );
      }
    } catch (e) {
      print('API Error (location): $e');
    }
    return MockData.initialLocation;
  }
  
  // Method to POST location updates to the backend
  static Future<void> postLocation(double lat, double lon, String source, double confidence) async {
    if (AppConfig.MOCK_MODE) return;
    try {
      await http.post(
        Uri.parse('$baseUrl/location'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'session_id': sessionId,
          'lat': lat,
          'lon': lon,
          'source': source,
          'confidence': confidence,
        }),
      );
    } catch (e) {
      print('API Error (post location): $e');
    }
  }

  static Future<List<Hotspot>> getHotspots() async {
    if (AppConfig.MOCK_MODE) return [MockData.mockHotspot];

    try {
      final response = await http.get(Uri.parse('$baseUrl/hotspots'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> hotspotsData = data['hotspots'];
        return hotspotsData.map((h) {
          return Hotspot(
            id: h['id'].toString(),
            name: 'Crime Hotspot',
            risk: parseRiskLevel(h['risk_level']),
            reportedIncidents: h['reported_incidents'] ?? 0,
            recentIncidents: h['recent_incidents'] ?? 0,
            score: (h['hotspot_score'] ?? 0).toDouble(),
            radius: (h['radius_m'] ?? 100).toDouble(),
            centerLat: h['center_lat'].toDouble(),
            centerLon: h['center_lon'].toDouble(),
          );
        }).toList();
      }
    } catch (e) {
      print('API Error (get hotspots): $e');
    }
    return [];
  }

  // Fetch incident history
  static Future<List<dynamic>> getIncidents() async {
    if (AppConfig.MOCK_MODE) return [];
    try {
      final response = await http.get(Uri.parse('$baseUrl/incident?session_id=$sessionId'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('API Error (get incidents): $e');
    }
    return [];
  }

  static Future<List<SafeLocation>> getSafeLocations(double currentLat, double currentLon) async {
    if (AppConfig.MOCK_MODE) return MockData.safeLocations;

    try {
      final response = await http.get(Uri.parse('$baseUrl/safe-locations'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        List<SafeLocation> locations = data.map((s) {
          double dist = _calculateDistance(currentLat, currentLon, s['latitude'], s['longitude']);
          bool isOpen = s['availability'] == 'open';
          bool isStaffed = s['availability'] == 'open' || s['availability'] == 'staffed';
          
          // Calculate client-side score
          int distanceScore = (50 - (dist / 10)).clamp(0, 50).toInt();
          int openScore = isOpen ? 30 : 0;
          int staffedScore = isStaffed ? 20 : 0;
          int score = distanceScore + openScore + staffedScore;

          return SafeLocation(
            id: s['id'].toString(),
            name: s['name'],
            distance: dist,
            type: s['type'],
            isOpen: isOpen,
            isStaffed: isStaffed,
            score: score,
            lat: s['latitude'].toDouble(),
            lon: s['longitude'].toDouble(),
          );
        }).toList();

        locations.sort((a, b) => b.score.compareTo(a.score));
        return locations;
      }
    } catch (e) {
      print('API Error (safe locations): $e');
    }
    return MockData.safeLocations;
  }

  static Future<RiskLevel> getRiskAssessment() async {
    if (AppConfig.MOCK_MODE) return MockData.mockHotspot.risk;

    try {
      final response = await http.get(Uri.parse('$baseUrl/risk/latest?session_id=$sessionId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return parseRiskLevel(data['risk_level']);
      }
    } catch (e) {
      print('API Error (risk): $e');
    }
    return RiskLevel.unknown;
  }

  static Future<Map<String, dynamic>?> getUnifiedState() async {
    if (AppConfig.MOCK_MODE) return null;
    
    try {
      final response = await http.get(Uri.parse('$baseUrl/unified-state?session_id=$sessionId'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('API Error (unified state): $e');
    }
    return null;
  }

  static Future<void> createIncident(double lat, double lon, String source, double confidence) async {
    if (AppConfig.MOCK_MODE) return;
    
    try {
      await http.post(
        Uri.parse('$baseUrl/incident'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'session_id': sessionId,
          'risk_level': 'HIGH',
          'lat': lat,
          'lon': lon,
          'location_source': source,
          'location_confidence': confidence,
        }),
      );
    } catch (e) {
      print('API Error (create incident): $e');
    }
  }

  static Future<List<TimelineEvent>> getIncidentTimeline(String incidentId) async {
    if (AppConfig.MOCK_MODE) return MockData.mockTimeline;
    
    try {
      final response = await http.get(Uri.parse('$baseUrl/incident/$incidentId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> events = data['events'] ?? [];
        return events.map((e) => TimelineEvent(
          time: DateTime.tryParse(e['timestamp'] ?? '') ?? DateTime.now(),
          title: e['event_type'],
          description: e['description'],
          state: 'completed',
          icon: 'alert_circle',
        )).toList();
      }
    } catch (e) {
      print('API Error (incident timeline): $e');
    }
    return MockData.mockTimeline;
  }
}

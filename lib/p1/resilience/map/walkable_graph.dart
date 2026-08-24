import 'dart:math';
import '../../pdr/utils/geo_utils.dart';

/// A point or intersection in the offline walkable corridor graph.
class WalkableNode {
  final String id;
  final double latitude;
  final double longitude;
  final int floor;
  final String label;

  const WalkableNode({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.floor = 0,
    this.label = '',
  });

  @override
  String toString() => 'WalkableNode($id: $label at $latitude, $longitude)';
}

/// A walkable hallway, path, or corridor connecting two nodes.
class WalkableEdge {
  final String id;
  final String fromNodeId;
  final String toNodeId;
  final double lengthMeters;
  final bool isAccessible;

  const WalkableEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.lengthMeters,
    this.isAccessible = true,
  });

  @override
  String toString() => 'WalkableEdge($id: $fromNodeId <-> $toNodeId, ${lengthMeters.toStringAsFixed(1)}m)';
}

/// Result of projecting a point onto a walkable hallway segment.
class SnappedPointResult {
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final WalkableEdge edge;
  final double projectionFraction; // 0.0 at fromNode, 1.0 at toNode

  const SnappedPointResult({
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.edge,
    required this.projectionFraction,
  });
}

/// Local on-device walkable graph representation for indoor/dense corridor environments.
class WalkableGraph {
  final Map<String, WalkableNode> _nodes = {};
  final List<WalkableEdge> _edges = [];

  WalkableGraph({
    List<WalkableNode> nodes = const [],
    List<WalkableEdge> edges = const [],
  }) {
    for (final node in nodes) {
      _nodes[node.id] = node;
    }
    _edges.addAll(edges);
  }

  Map<String, WalkableNode> get nodes => Map.unmodifiable(_nodes);
  List<WalkableEdge> get edges => List.unmodifiable(_edges);
  bool get isEmpty => _nodes.isEmpty || _edges.isEmpty;

  void addNode(WalkableNode node) {
    _nodes[node.id] = node;
  }

  void addEdge(WalkableEdge edge) {
    _edges.add(edge);
  }

  WalkableNode? getNode(String id) => _nodes[id];

  /// Finds the closest walkable graph node to the given coordinates.
  WalkableNode? findNearestNode(double lat, double lon) {
    if (_nodes.isEmpty) return null;

    WalkableNode? closest;
    double minDistance = double.infinity;

    for (final node in _nodes.values) {
      final d = GeoUtils.haversineDistance(
        lat1: lat,
        lon1: lon,
        lat2: node.latitude,
        lon2: node.longitude,
      );
      if (d < minDistance) {
        minDistance = d;
        closest = node;
      }
    }

    return closest;
  }

  /// Projects a geocoordinate onto all walkable edges and returns the closest perpendicular segment point.
  SnappedPointResult? snapToNearestEdge(double lat, double lon, {int? targetFloor}) {
    if (_edges.isEmpty) return null;

    SnappedPointResult? bestResult;
    double minDistance = double.infinity;

    for (final edge in _edges) {
      final from = _nodes[edge.fromNodeId];
      final to = _nodes[edge.toNodeId];
      if (from == null || to == null) continue;
      if (targetFloor != null && (from.floor != targetFloor || to.floor != targetFloor)) {
        continue;
      }

      final snapped = _projectOntoSegment(lat, lon, from, to, edge);
      if (snapped.distanceMeters < minDistance) {
        minDistance = snapped.distanceMeters;
        bestResult = snapped;
      }
    }

    return bestResult;
  }

  /// Calculates perpendicular point-to-segment projection in local metric coordinates.
  SnappedPointResult _projectOntoSegment(
    double pLat,
    double pLon,
    WalkableNode from,
    WalkableNode to,
    WalkableEdge edge,
  ) {
    final refLat = from.latitude;
    final refLon = from.longitude;

    // Convert from geodetic degrees to local East/North meters
    final pP = GeoUtils.latLngToLocalMeters(
      originLat: refLat,
      originLon: refLon,
      targetLat: pLat,
      targetLon: pLon,
    );
    final pTo = GeoUtils.latLngToLocalMeters(
      originLat: refLat,
      originLon: refLon,
      targetLat: to.latitude,
      targetLon: to.longitude,
    );

    final pX = pP.eastMeters;
    final pY = pP.northMeters;
    final segDx = pTo.eastMeters; // from is (0,0)
    final segDy = pTo.northMeters;

    final segLengthSquared = segDx * segDx + segDy * segDy;

    double t;
    if (segLengthSquared <= 1e-6) {
      t = 0.0;
    } else {
      // Dot product projection
      t = (pX * segDx + pY * segDy) / segLengthSquared;
      t = t.clamp(0.0, 1.0);
    }

    final projX = t * segDx;
    final projY = t * segDy;

    // Distance in local metric frame
    final dist = sqrt((pX - projX) * (pX - projX) + (pY - projY) * (pY - projY));

    // Convert projected point back to geodetic coordinates
    final snappedGeo = GeoUtils.localMetersToLatLng(
      originLat: refLat,
      originLon: refLon,
      eastMeters: projX,
      northMeters: projY,
    );

    return SnappedPointResult(
      latitude: snappedGeo.latitude,
      longitude: snappedGeo.longitude,
      distanceMeters: dist,
      edge: edge,
      projectionFraction: t,
    );
  }

  /// Creates a realistic default offline walkable corridor graph for demo venue and testing.
  factory WalkableGraph.demoVenue() {
    // Hotel & Tourist Safe-Haven Corridor Network
    // Node A (Lobby Entrance): 19.076000, 72.877700
    // Node B (Central Hallway Junction): 19.076050, 72.877700 (5.5m North)
    // Node C (West Safe-Haven / Security Post): 19.076050, 72.877600 (10.5m West)
    // Node D (North Courtyard Exit): 19.076120, 72.877700 (7.8m North)
    // Node E (East Medical Assistance Kiosk): 19.076050, 72.877800 (10.5m East)

    final nodes = [
      const WalkableNode(
        id: 'node_lobby_entrance',
        latitude: 19.076000,
        longitude: 72.877700,
        label: 'Main Lobby Entrance',
      ),
      const WalkableNode(
        id: 'node_central_junction',
        latitude: 19.076050,
        longitude: 72.877700,
        label: 'Central Corridor Junction',
      ),
      const WalkableNode(
        id: 'node_west_security',
        latitude: 19.076050,
        longitude: 72.877600,
        label: 'West Tourist Security Post',
      ),
      const WalkableNode(
        id: 'node_north_exit',
        latitude: 19.076120,
        longitude: 72.877700,
        label: 'North Courtyard Exit',
      ),
      const WalkableNode(
        id: 'node_east_medical',
        latitude: 19.076050,
        longitude: 72.877800,
        label: 'East Medical Aid Station',
      ),
    ];

    final edges = [
      const WalkableEdge(
        id: 'edge_lobby_to_junction',
        fromNodeId: 'node_lobby_entrance',
        toNodeId: 'node_central_junction',
        lengthMeters: 5.5,
      ),
      const WalkableEdge(
        id: 'edge_junction_to_west',
        fromNodeId: 'node_central_junction',
        toNodeId: 'node_west_security',
        lengthMeters: 10.5,
      ),
      const WalkableEdge(
        id: 'edge_junction_to_north',
        fromNodeId: 'node_central_junction',
        toNodeId: 'node_north_exit',
        lengthMeters: 7.8,
      ),
      const WalkableEdge(
        id: 'edge_junction_to_east',
        fromNodeId: 'node_central_junction',
        toNodeId: 'node_east_medical',
        lengthMeters: 10.5,
      ),
    ];

    return WalkableGraph(nodes: nodes, edges: edges);
  }
}

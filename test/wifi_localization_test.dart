import 'package:flutter_test/flutter_test.dart';

import 'package:sih/resilience/core/resilience_engine.dart';
import 'package:sih/resilience/localization/wifi_fingerprint_matcher.dart';
import 'package:sih/resilience/models/gps_health.dart';
import 'package:sih/resilience/models/localization_anchor.dart';
import 'package:sih/resilience/models/position_estimate.dart';
import 'package:sih/resilience/models/position_source.dart';
import 'package:sih/resilience/models/positioning_mode.dart';
import 'package:sih/resilience/models/wifi_fingerprint.dart';
import 'package:sih/resilience/providers/gps_positioning_provider.dart';
import 'package:sih/resilience/providers/pdr_positioning_provider.dart';
import 'package:sih/resilience/providers/wifi_positioning_provider.dart';
import 'package:sih/resilience/repositories/localization_anchor_repository.dart';
import 'package:sih/resilience/sensors/connectivity_service.dart';
import 'package:sih/resilience/sensors/wifi_scanner.dart';
import 'package:sih/safety/core/safety_engine.dart';
import 'package:sih/safety/models/safety_event.dart';
import 'package:sih/safety/storage/safety_event_store.dart';
import 'package:sih/safety/transport/dev_mock_safety_event_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Wi-Fi Fingerprint Localization & WKNN Matching Tests', () {
    late InMemoryLocalizationAnchorRepository repository;
    late WifiFingerprintMatcher matcher;
    late SimulatedWifiScanner wifiScanner;
    late WifiPositioningProvider wifiProvider;

    final now = DateTime(2026, 1, 1, 12, 0, 0);

    setUp(() {
      repository = InMemoryLocalizationAnchorRepository(populateDemoAnchors: true);
      matcher = const WifiFingerprintMatcher();
      wifiScanner = SimulatedWifiScanner();
      wifiProvider = WifiPositioningProvider(
        scanner: wifiScanner,
        repository: repository,
        matcher: matcher,
        kNearestNeighbors: 3,
      );
    });

    tearDown(() {
      wifiProvider.dispose();
    });

    // ============================================================
    // TEST 1: Exact Fingerprint Match -> Correct Position
    // ============================================================
    test('TEST 1 — Exact fingerprint match against known anchor produces accurate coordinates and high confidence', () async {
      final exactScan = WifiFingerprint(
        timestamp: now,
        observations: const [
          WifiAccessPointObservation(bssid: '00:11:22:33:44:01', ssid: 'Hotel_Guest_Lobby', rssi: -45),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:02', ssid: 'Hotel_Admin_Internal', rssi: -52),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:03', ssid: 'Cafe_Express_WiFi', rssi: -68),
        ],
      );

      final anchors = await repository.getAllAnchors();
      final result = matcher.match(observed: exactScan, candidateAnchors: anchors);

      expect(result.isAccepted, isTrue);
      expect(result.matchedAnchor?.id, 'anchor_hotel_lobby_01');
      expect(result.estimatedLatitude, closeTo(19.076000, 0.000001));
      expect(result.estimatedLongitude, closeTo(72.877700, 0.000001));
      expect(result.similarityScore, greaterThan(0.95));
      expect(result.confidence, greaterThan(0.80));
      expect(result.apOverlapCount, 3);
      expect(result.uncertaintyMeters, lessThan(8.0));
    });

    // ============================================================
    // TEST 2: Strong Partial Match -> Reasonable Position
    // ============================================================
    test('TEST 2 — Strong partial match with minor RSSI variance is accepted with calibrated confidence', () async {
      // 2 out of 3 APs present with small ±3dBm fluctuations
      final partialScan = WifiFingerprint(
        timestamp: now,
        observations: const [
          WifiAccessPointObservation(bssid: '00:11:22:33:44:01', ssid: 'Hotel_Guest_Lobby', rssi: -48),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:02', ssid: 'Hotel_Admin_Internal', rssi: -55),
          WifiAccessPointObservation(bssid: '00:99:99:99:99:99', ssid: 'Unknown_Hotspot', rssi: -80),
        ],
      );

      final anchors = await repository.getAllAnchors();
      final result = matcher.match(observed: partialScan, candidateAnchors: anchors);

      expect(result.isAccepted, isTrue);
      expect(result.matchedAnchor?.id, 'anchor_hotel_lobby_01');
      expect(result.similarityScore, greaterThan(0.70));
      expect(result.apOverlapCount, 2);
    });

    // ============================================================
    // TEST 3: Multiple Nearby Fingerprints -> WKNN Weighted Centroid
    // ============================================================
    test('TEST 3 — Multiple matching fingerprints compute a WKNN weighted centroid between landmarks', () async {
      // Clear repo and add two specific reference landmarks
      await repository.clear();
      final anchorA = LocalizationAnchor(
        id: 'anchor_point_A',
        name: 'Point A',
        latitude: 19.076000,
        longitude: 72.877700,
        confidence: 0.90,
        uncertaintyMeters: 6.0,
        fingerprint: WifiFingerprint(
          timestamp: now,
          observations: const [
            WifiAccessPointObservation(bssid: 'aa:aa:aa:aa:aa:01', ssid: 'Mesh_1', rssi: -45),
            WifiAccessPointObservation(bssid: 'aa:aa:aa:aa:aa:02', ssid: 'Mesh_2', rssi: -50),
          ],
        ),
      );

      final anchorB = LocalizationAnchor(
        id: 'anchor_point_B',
        name: 'Point B',
        latitude: 19.076100,
        longitude: 72.877800,
        confidence: 0.90,
        uncertaintyMeters: 6.0,
        fingerprint: WifiFingerprint(
          timestamp: now,
          observations: const [
            WifiAccessPointObservation(bssid: 'aa:aa:aa:aa:aa:02', ssid: 'Mesh_2', rssi: -50),
            WifiAccessPointObservation(bssid: 'aa:aa:aa:aa:aa:03', ssid: 'Mesh_3', rssi: -45),
          ],
        ),
      );

      await repository.addAnchor(anchorA);
      await repository.addAnchor(anchorB);

      // User is located halfway between A and B, observing all 3 APs equally
      final intermediateScan = WifiFingerprint(
        timestamp: now,
        observations: const [
          WifiAccessPointObservation(bssid: 'aa:aa:aa:aa:aa:01', ssid: 'Mesh_1', rssi: -48),
          WifiAccessPointObservation(bssid: 'aa:aa:aa:aa:aa:02', ssid: 'Mesh_2', rssi: -48),
          WifiAccessPointObservation(bssid: 'aa:aa:aa:aa:aa:03', ssid: 'Mesh_3', rssi: -48),
        ],
      );

      final candidates = await repository.getAllAnchors();
      final result = matcher.matchKnn(observed: intermediateScan, candidateAnchors: candidates, k: 2);

      expect(result.isAccepted, isTrue);
      expect(result.matchedCandidatesCount, 2);
      // Centroid should lie between 19.076000 and 19.076100
      expect(result.estimatedLatitude, greaterThan(19.076000));
      expect(result.estimatedLatitude, lessThan(19.076100));
      // Centroid should lie between 72.877700 and 72.877800
      expect(result.estimatedLongitude, greaterThan(72.877700));
      expect(result.estimatedLongitude, lessThan(72.877800));
    });

    // ============================================================
    // TEST 4: Insufficient Common BSSIDs -> Reject
    // ============================================================
    test('TEST 4 — Insufficient common APs (< 2) is rejected without manufacturing a position', () async {
      final disjointScan = WifiFingerprint(
        timestamp: now,
        observations: const [
          WifiAccessPointObservation(bssid: 'ff:ee:dd:cc:bb:aa', ssid: 'Random_AP_1', rssi: -50),
          WifiAccessPointObservation(bssid: 'ff:ee:dd:cc:bb:bb', ssid: 'Random_AP_2', rssi: -60),
        ],
      );

      final anchors = await repository.getAllAnchors();
      final result = matcher.match(observed: disjointScan, candidateAnchors: anchors);

      expect(result.isAccepted, isFalse);
      expect(result.rejectionReason, contains('minimum common AP'));
      expect(result.confidence, 0.0);
    });

    // ============================================================
    // TEST 5: Very Poor RSSI Similarity -> Reject
    // ============================================================
    test('TEST 5 — Huge RSSI discrepancies (> 35dBm) cause candidate match rejection', () async {
      // Common BSSIDs present, but signal strength is completely inconsistent (-45 vs -90 dBm)
      final degradedScan = WifiFingerprint(
        timestamp: now,
        observations: const [
          WifiAccessPointObservation(bssid: '00:11:22:33:44:01', ssid: 'Hotel_Guest_Lobby', rssi: -90),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:02', ssid: 'Hotel_Admin_Internal', rssi: -92),
        ],
      );

      final anchors = await repository.getAllAnchors();
      final result = matcher.match(observed: degradedScan, candidateAnchors: anchors);

      expect(result.isAccepted, isFalse);
      expect(result.rejectionReason, contains('below threshold'));
    });

    // ============================================================
    // TEST 6: No Wi-Fi Observations -> No Wi-Fi Position
    // ============================================================
    test('TEST 6 — Empty Wi-Fi scan results return null and keep provider unavailable', () async {
      final emptyScan = WifiFingerprint(timestamp: now, observations: const []);
      wifiScanner.injectScan(emptyScan);

      final pos = await wifiProvider.scanAndLocalize();
      expect(pos, isNull);
      expect(wifiProvider.isAvailable, isFalse);
      expect(wifiProvider.currentPosition, isNull);
    });

    // ============================================================
    // TEST 7: GPS Unavailable + Valid Wi-Fi Fingerprint -> Resilience Uses Wi-Fi
    // ============================================================
    test('TEST 7 — GPS unavailable + valid Wi-Fi fingerprint establishes PDR anchor from Wi-Fi', () async {
      final gpsProvider = GpsPositioningProvider();
      final pdrProvider = PdrPositioningProvider();
      final connService = ConnectivityService();

      final engine = ResilienceEngine(
        gpsProvider: gpsProvider,
        pdrProvider: pdrProvider,
        wifiProvider: wifiProvider,
        wifiScanner: wifiScanner,
        anchorRepository: repository,
        fingerprintMatcher: matcher,
        connectivityService: connService,
      );

      await engine.start();

      // GPS is disabled / lost
      gpsProvider.injectSimulatedHealth(GpsHealth.lost);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(engine.currentState.positioningMode, PositioningMode.pdrFallback);

      // Inject valid lobby Wi-Fi scan
      final lobbyScan = WifiFingerprint(
        timestamp: now,
        observations: const [
          WifiAccessPointObservation(bssid: '00:11:22:33:44:01', ssid: 'Hotel_Guest_Lobby', rssi: -45),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:02', ssid: 'Hotel_Admin_Internal', rssi: -52),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:03', ssid: 'Cafe_Express_WiFi', rssi: -68),
        ],
      );

      wifiScanner.injectScan(lobbyScan);
      await engine.performWifiLocalizationScan();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Engine accepts Wi-Fi anchor and anchors PDR
      expect(engine.currentState.position?.source, PositionSource.wifiFingerprint);
      expect(engine.currentState.position?.latitude, closeTo(19.076000, 0.0001));
      expect(engine.currentState.position?.longitude, closeTo(72.877700, 0.0001));
      expect(engine.currentState.pdrAnchor?.source, PositionSource.wifiFingerprint);

      await engine.stop();
      gpsProvider.dispose();
      pdrProvider.dispose();
      connService.dispose();
      engine.dispose();
    });

    // ============================================================
    // TEST 8: GPS Available -> GPS Remains Authoritative
    // ============================================================
    test('TEST 8 — When GPS is active, GPS maintains authoritative control over active position', () async {
      final gpsProvider = GpsPositioningProvider();
      final pdrProvider = PdrPositioningProvider();
      final connService = ConnectivityService();

      final engine = ResilienceEngine(
        gpsProvider: gpsProvider,
        pdrProvider: pdrProvider,
        wifiScanner: wifiScanner,
        anchorRepository: repository,
        fingerprintMatcher: matcher,
        connectivityService: connService,
      );

      await engine.start();

      // Inject GPS fix
      gpsProvider.injectSimulatedPosition(
        PositionEstimate(
          latitude: 19.075500,
          longitude: 72.877200,
          source: PositionSource.gps,
          confidence: 0.95,
          uncertaintyMeters: 4.0,
          timestamp: now,
          isAbsolute: true,
          isDegraded: false,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(engine.currentState.positioningMode, PositioningMode.gps);
      expect(engine.currentState.position?.source, PositionSource.gps);
      expect(engine.currentState.position?.latitude, closeTo(19.075500, 0.00001));

      // Inject Wi-Fi scan while GPS is active
      final lobbyScan = WifiFingerprint(
        timestamp: now,
        observations: const [
          WifiAccessPointObservation(bssid: '00:11:22:33:44:01', ssid: 'Hotel_Guest_Lobby', rssi: -45),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:02', ssid: 'Hotel_Admin_Internal', rssi: -52),
          WifiAccessPointObservation(bssid: '00:11:22:33:44:03', ssid: 'Cafe_Express_WiFi', rssi: -68),
        ],
      );
      wifiScanner.injectScan(lobbyScan);
      await engine.performWifiLocalizationScan();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // GPS fix remains the active position
      expect(engine.currentState.positioningMode, PositioningMode.gps);
      expect(engine.currentState.position?.source, PositionSource.gps);
      expect(engine.currentState.position?.latitude, closeTo(19.075500, 0.00001));

      await engine.stop();
      gpsProvider.dispose();
      pdrProvider.dispose();
      connService.dispose();
      engine.dispose();
    });

    // ============================================================
    // TEST 9: Wi-Fi Unavailable -> PDR Continues Smoothly
    // ============================================================
    test('TEST 9 — When Wi-Fi scan produces no match, PDR dead reckoning continues without interruption', () async {
      final gpsProvider = GpsPositioningProvider();
      final pdrProvider = PdrPositioningProvider();
      final connService = ConnectivityService();

      final engine = ResilienceEngine(
        gpsProvider: gpsProvider,
        pdrProvider: pdrProvider,
        wifiScanner: wifiScanner,
        anchorRepository: repository,
        fingerprintMatcher: matcher,
        connectivityService: connService,
      );

      await engine.start();

      // Establish initial position before GPS loss
      gpsProvider.injectSimulatedPosition(
        PositionEstimate(
          latitude: 19.076000,
          longitude: 72.877700,
          source: PositionSource.gps,
          confidence: 0.95,
          uncertaintyMeters: 4.0,
          timestamp: now,
          isAbsolute: true,
          isDegraded: false,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      gpsProvider.injectSimulatedHealth(GpsHealth.lost);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(engine.currentState.positioningMode, PositioningMode.pdrFallback);

      // Inject unmatchable Wi-Fi scan
      wifiScanner.injectScan(
        WifiFingerprint(
          timestamp: now,
          observations: const [
            WifiAccessPointObservation(bssid: '99:99:99:99:99:99', ssid: 'Unknown_AP', rssi: -85),
          ],
        ),
      );

      await engine.performWifiLocalizationScan();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // PDR remains active and uncorrupted
      expect(engine.currentState.positioningMode, PositioningMode.pdrFallback);
      expect(engine.currentState.position?.latitude, closeTo(19.076000, 0.0001));

      await engine.stop();
      gpsProvider.dispose();
      pdrProvider.dispose();
      connService.dispose();
      engine.dispose();
    });

    // ============================================================
    // TEST 10: Safety Engine Integration & Offline Queue Preserved
    // ============================================================
    test('TEST 10 — SafetyEngine uses Wi-Fi position snapshots when creating offline safety events', () async {
      final gpsProvider = GpsPositioningProvider();
      final pdrProvider = PdrPositioningProvider();
      final connService = ConnectivityService();
      connService.setSimulatedStatus(false); // Offline

      final engine = ResilienceEngine(
        gpsProvider: gpsProvider,
        pdrProvider: pdrProvider,
        wifiScanner: wifiScanner,
        anchorRepository: repository,
        fingerprintMatcher: matcher,
        connectivityService: connService,
      );

      final store = InMemorySafetyEventStore();
      final transport = DevMockSafetyEventTransport();
      final safetyEngine = SafetyEngine(
        resilienceEngine: engine,
        store: store,
        transport: transport,
      );

      await engine.start();
      await safetyEngine.start();

      gpsProvider.injectSimulatedHealth(GpsHealth.lost);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Provide Wi-Fi anchor
      wifiScanner.injectScan(
        WifiFingerprint(
          timestamp: now,
          observations: const [
            WifiAccessPointObservation(bssid: '00:11:22:33:44:01', ssid: 'Hotel_Guest_Lobby', rssi: -45),
            WifiAccessPointObservation(bssid: '00:11:22:33:44:02', ssid: 'Hotel_Admin_Internal', rssi: -52),
            WifiAccessPointObservation(bssid: '00:11:22:33:44:03', ssid: 'Cafe_Express_WiFi', rssi: -68),
          ],
        ),
      );
      await engine.performWifiLocalizationScan();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Create offline SOS
      final event = await safetyEngine.createSos();

      expect(event.latitude, closeTo(19.076000, 0.0001));
      expect(event.longitude, closeTo(72.877700, 0.0001));
      expect(event.positionSource, PositionSource.wifiFingerprint);
      expect(event.eventStatus, EventDeliveryStatus.queued);

      // Reconnect and verify sync
      connService.setSimulatedStatus(true);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final pending = await safetyEngine.getPendingEvents();
      expect(pending.isEmpty, isTrue);
      expect(transport.transmittedEvents.length, 1);
      expect(transport.transmittedEvents.first.positionSource, PositionSource.wifiFingerprint);

      safetyEngine.syncManager.dispose();
      safetyEngine.dispose();
      await engine.stop();
      gpsProvider.dispose();
      pdrProvider.dispose();
      connService.dispose();
      engine.dispose();
    });
  });
}

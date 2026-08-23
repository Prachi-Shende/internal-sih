# P1 Integration Contract & Subsystem Handover Specification

**Subsystem**: P1 — Resilient Localization, Pedestrian Dead Reckoning (PDR), Sensor Fusion & Safety Communication  
**Target Consumers**: P2 (Maps & Routing), P3 (Contextual Safety & Risk Intelligence), P4 (Communication Resilience & Blockchain), P5 (Backend Ingestion & Cloud APIs), P6 (UI Dashboards & Mobile Screens)  
**Status**: Complete, Verified on Physical Hardware & Automated Test Suite (82/82 Passing, 0 Errors, 0 Warnings)

---

## 1. Subsystem Responsibilities

P1 serves as the foundational localization and telemetry engine of the Tourist Safety System. It is strictly responsible for answering:

1. **Where is the user located?** (`latitude`, `longitude`, `uncertaintyMeters`)
2. **How reliable is the current position fix?** (`confidence`, `isDegraded`, `isAbsolute`, `source`)
3. **How is the user physically moving?** (`steps`, `distanceMeters`, `headingDegrees`, `direction`, `speedMps`, `strideLengthMeters`, `isStationary`, `isWalking`)
4. **What infrastructure/resilience state is active?** (`mode`, `infrastructureCase`, `gpsHealth`, `wifiAvailable`, `pdrActive`)
5. **What network & communication state exists?** (`isOnline`, `activeDeliveryChannel`, `retryCount`)
6. **How are safety incidents dispatched & preserved?** (`SafetyEvent`, local durable offline queue, automatic synchronization, HTTP transport)

> **Important Boundary Rule**: P1 provides raw and calibrated positioning, kinematics, and communication reliability metrics. It **does NOT** compute crime scores, rank safe havens, render maps, or dictate incident responses. Those belong to P2, P3, P4, P5, and P6.

---

## 2. Integration Architecture

```
                    ┌──────────────────────────────────────────────┐
                    │                      P1                      │
                    │   (GPS + IMU PDR + WKNN Wi-Fi + Resilience)   │
                    └──────────────────────┬───────────────────────┘
                                           │
                                           ▼
                    ┌──────────────────────────────────────────────┐
                    │              P1SystemSnapshot                │
                    │  (Typed Dart Models + JSON Serialization)    │
                    └──────────────┬────────────────┬──────────────┘
                                   │                │
            In-App Typed Dart      │                │  Serialized JSON
            Stream / Method Calls  │                │  API / Remote Export
                                   ▼                ▼
                    ┌────────────────────────┐    ┌─────────────────┐
                    │      P2, P3, P4, P6    │    │   P5 Backend    │
                    │ (Maps, Risk, Comms, UI)│    │  (Cloud Storage)│
                    └────────────────────────┘    └─────────────────┘

            Emergency Incidents Pipeline (Separate High-Priority Path):
            SafetyEngine ──► SafetyEventStore ──► CommunicationOrchestrator
                                                           │
                                            ONLINE         │         OFFLINE
                                    ┌──────────────────────┴──────────────────────┐
                                    ▼                                             ▼
                        RealHttpTransport                                 OFFLINE_QUEUE
                     POST /api/safety-events                                      │
                                    │                                 (Internet returns)
                                    ▼                                             ▼
                                P5 Backend ◄────────────────────────────── SyncManager
```

---

## 3. P1 Output Models & Field Specification

### 3.1 `PositionSnapshot`
Exposes the best-estimate geodetic coordinate fix selected by the `ResilienceEngine`.

| Field | Type | Meaning | Possible Values | Nullable? | Producer | Consumer |
|:---|:---|:---|:---|:---|:---|:---|
| `latitude` | `double?` | WGS-84 Latitude in decimal degrees | `-90.0` to `+90.0` | **Yes** (if no initial fix) | P1 | P2, P3, P5, P6 |
| `longitude` | `double?` | WGS-84 Longitude in decimal degrees | `-180.0` to `+180.0` | **Yes** (if no initial fix) | P1 | P2, P3, P5, P6 |
| `source` | `String?` | Active positioning provider | `gps`, `pdr`, `wifiFingerprint`, `fused`, `mapMatched`, `lastKnown` | **Yes** | P1 | P2, P3, P5, P6 |
| `confidence` | `double?` | Spatial fix confidence | `0.0` to `1.0` (e.g. `0.96` = 96%) | **Yes** | P1 | P2, P3, P5, P6 |
| `uncertaintyMeters` | `double?` | Horizontal circular error radius | e.g. `3.8` (±3.8 meters) | **Yes** | P1 | P2, P3, P5, P6 |
| `isDegraded` | `bool` | True if operating without fresh absolute anchor | `true`, `false` | **No** | P1 | P2, P3, P6 |
| `isAbsolute` | `bool` | True if derived from absolute fix (GPS/Wi-Fi anchor) | `true`, `false` | **No** | P1 | P2, P3, P6 |
| `timestamp` | `DateTime` | Timestamp of position fix | ISO-8601 string | **No** | P1 | P2, P3, P5, P6 |

### 3.2 `MovementSnapshot`
Exposes pedestrian dead reckoning (PDR) metrics computed from physical device IMU sensors.

| Field | Type | Meaning | Possible Values | Nullable? | Producer | Consumer |
|:---|:---|:---|:---|:---|:---|:---|
| `steps` | `int` | Cumulative validated step count | $\ge 0$ | **No** | P1 | P2, P3, P6 |
| `distanceMeters` | `double` | Total walking distance accumulated | $\ge 0.0$ | **No** | P1 | P2, P3, P6 |
| `headingDegrees` | `double` | Walking azimuth clockwise from North | `0.0` to `359.9` | **No** | P1 | P2, P6 |
| `direction` | `String` | Cardinal direction | `NORTH`, `NORTH_EAST`, `EAST`, `SOUTH_EAST`, `SOUTH`, `SOUTH_WEST`, `WEST`, `NORTH_WEST` | **No** | P1 | P2, P6 |
| `speedMps` | `double` | Estimated walking velocity | $\ge 0.0$ m/s | **No** | P1 | P3, P6 |
| `strideLengthMeters` | `double` | Estimated user step length | e.g. `0.72` m | **No** | P1 | P3, P6 |
| `isStationary` | `bool` | True if user is stopped / at rest | `true`, `false` | **No** | P1 | P3, P6 |
| `isWalking` | `bool` | True if actively taking strides | `true`, `false` | **No** | P1 | P3, P6 |
| `stepConfidence` | `double` | Step detector confidence | `0.0` to `1.0` | **No** | P1 | P3, P6 |
| `headingConfidence` | `double` | Orientation filter confidence | `0.0` to `1.0` | **No** | P1 | P2, P6 |
| `overallConfidence` | `double` | Composite PDR kinematics confidence | `0.0` to `1.0` | **No** | P1 | P3, P6 |
| `localX` | `double` | Relative East Cartesian displacement | meters (e.g. `+12.4`) | **No** | P1 | P2, P6 |
| `localY` | `double` | Relative North Cartesian displacement | meters (e.g. `-8.1`) | **No** | P1 | P2, P6 |
| `timestamp` | `DateTime` | Kinematics sample timestamp | ISO-8601 string | **No** | P1 | P2, P6 |

### 3.3 `ResilienceSnapshot`
Exposes the multi-tier positioning state machine, sensor health, and infrastructure case.

| Field | Type | Meaning | Possible Values | Nullable? | Producer | Consumer |
|:---|:---|:---|:---|:---|:---|:---|
| `mode` | `String` | Active positioning mode | `gps`, `pdrFallback`, `recovering` | **No** | P1 | P2, P3, P6 |
| `infrastructureCase` | `String` | Active four-case scenario | `case1`, `case2`, `case3`, `case4` | **No** | P1 | P3, P4, P6 |
| `systemStatusLabel` | `String` | Human-readable system state banner | e.g. `CASE 1 — FULLY CONNECTED` | **No** | P1 | P6 |
| `confidenceRating` | `String` | Qualitative confidence tier | `HIGH` ($\ge 80\%$), `MEDIUM` ($\ge 50\%$), `LOW`, `UNKNOWN` | **No** | P1 | P3, P6 |
| `gpsAvailable` | `bool` | True if GPS has valid fix | `true`, `false` | **No** | P1 | P2, P3, P6 |
| `gpsHealth` | `String` | Granular GPS receiver state | `disabled`, `searching`, `active`, `stale`, `lost` | **No** | P1 | P2, P6 |
| `wifiAvailable` | `bool` | True if Wi-Fi scanning is enabled | `true`, `false` | **No** | P1 | P2, P6 |
| `pdrActive` | `bool` | True if PDR engine is running | `true`, `false` | **No** | P1 | P2, P6 |
| `activePositionSource` | `String?` | Selected position provider | `gps`, `pdr`, `wifiFingerprint`, etc. | **Yes** | P1 | P2, P3, P6 |
| `activeConfidence` | `double?` | Point-in-time position confidence | `0.0` to `1.0` | **Yes** | P1 | P3, P6 |
| `activeUncertaintyMeters`| `double?` | Point-in-time error radius | meters (e.g. `4.0`) | **Yes** | P1 | P2, P3, P6 |
| `internetAvailable` | `bool` | True if device has data connectivity | `true`, `false` | **No** | P1 | P3, P4, P6 |
| `pdrDisplacementMeters` | `double` | Distance walked under PDR since anchor | $\ge 0.0$ | **No** | P1 | P2, P6 |
| `lastAnchorDiscrepancyMeters` | `double?` | Re-anchoring discrepancy distance | meters | **Yes** | P1 | P2, P6 |
| `lastMatchedAnchorId` | `String?` | ID of matched Wi-Fi landmark | e.g. `anchor_hotel_lobby_01` | **Yes** | P1 | P2, P6 |
| `lastWifiAnchorStatus` | `String?` | Status of Wi-Fi matching | `MATCHED`, `NO MATCH`, `REJECTED` | **Yes** | P1 | P6 |
| `lastWifiSimilarityScore` | `double?` | Fingerprint match similarity | `0.0` to `1.0` | **Yes** | P1 | P6 |
| `anchorCorrectionCount` | `int` | Total anchor corrections applied | $\ge 0$ | **No** | P1 | P6 |
| `isMapConstrained` | `bool` | True if snapped to walkable corridor | `true`, `false` | **No** | P1 | P2, P6 |
| `lastMapConstraintStatus` | `String?` | Map snapping status | `MATCHED (WALKABLE CORRIDOR)`, etc. | **Yes** | P1 | P2, P6 |
| `timestamp` | `DateTime` | Resilience state timestamp | ISO-8601 string | **No** | P1 | P6 |

### 3.4 `ConnectivitySnapshot`
Exposes network connectivity and message delivery routing.

| Field | Type | Meaning | Possible Values | Nullable? | Producer | Consumer |
|:---|:---|:---|:---|:---|:---|:---|
| `isOnline` | `bool` | True if internet is reachable | `true`, `false` | **No** | P1 | P3, P4, P5, P6 |
| `cellularAvailable` | `bool` | Cellular radio status | `true`, `false` | **No** | P1 | P4, P6 |
| `wifiAvailable` | `bool` | Wi-Fi adapter status | `true`, `false` | **No** | P1 | P4, P6 |
| `activeDeliveryChannel` | `String` | Communication route used | `INTERNET`, `OFFLINE_QUEUE` | **No** | P1 | P4, P5, P6 |
| `timestamp` | `DateTime` | Sample timestamp | ISO-8601 string | **No** | P1 | P6 |

### 3.5 `P1SystemSnapshot`
Top-level object uniting all four snapshot domains.

```dart
class P1SystemSnapshot {
  final DateTime timestamp;
  final PositionSnapshot position;
  final MovementSnapshot movement;
  final ResilienceSnapshot resilience;
  final ConnectivitySnapshot connectivity;
  
  Map<String, dynamic> toJson();
  factory P1SystemSnapshot.fromJson(Map<String, dynamic> json);
}
```

---

## 4. Positioning Source Semantics & Hierarchy

The `ResilienceEngine` maintains authoritative control over source selection. **Consumers (P2/P3/P6) must NOT manually pick or swap positioning sources.**

```
                               ┌───────────────────────────┐
                               │   GPS Satellite Signal    │
                               └─────────────┬─────────────┘
                                             │
                                   HEALTHY   │   LOST / UNRELIABLE
                                             ▼
                             ┌──────────────────────────────┐
                             │     GPS Mode (Authoritative) │
                             │     Source: PositionSource.gps│
                             └───────────────┬──────────────┘
                                             │
                                      (Signal drops)
                                             ▼
                             ┌──────────────────────────────┐
                             │  PDR Fallback Mode           │
                             │  Source: PositionSource.pdr  │
                             │  (Relative Inertial Steps)   │
                             └───────────────┬──────────────┘
                                             │
                                    Wi-Fi Fingerprint Match
                                    (Within Plausibility Limit)
                                             ▼
                             ┌──────────────────────────────┐
                             │  PDR Re-Anchored             │
                             │  Source: PositionSource.wifi │
                             │  Uncertainty Reduced         │
                             └──────────────────────────────┘
```

1. **GPS (`PositionSource.gps`)**: Authoritative when healthy. Direct geodetic coordinates ($< 5\text{m}$ accuracy).
2. **PDR (`PositionSource.pdr`)**: Dead reckoning via step detection, heading estimator, and Weinberg stride model when GPS is lost. Uncertainty increases proportionally with distance walked ($\approx 5\% \text{ of displacement}$).
3. **Wi-Fi Fingerprint (`PositionSource.wifiFingerprint`)**: Opportunistic indoor/re-anchoring fix derived from ambient AP RSSI fingerprints using Weighted K-Nearest Neighbors (WKNN). Re-anchors PDR and resets uncertainty without perturbing step history.
4. **Map Snapping (`PositionSource.mapMatched` / `isMapConstrained`)**: Snaps position to walkable graph segments when within 15 meters of known corridors.

---

## 5. Confidence vs. Uncertainty Semantics

### Confidence (`confidence` $\in [0.0, 1.0]$)
- **Definition**: P1's internal mathematical estimate of **position fix reliability**.
- **Scale**:
  - `0.80 - 1.00`: High confidence (Active GPS 3D fix or perfect Wi-Fi landmark match).
  - `0.50 - 0.79`: Medium confidence (PDR dead reckoning within $< 100\text{m}$ of anchor, or partial Wi-Fi match).
  - `< 0.50`: Low confidence (Long PDR dead reckoning without anchor, or GPS lost $> 60\text{s}$).
- **Consumer Guideline**: **Do NOT interpret this as safety risk or crime probability.** Safety risk belongs to P3.

### Horizontal Uncertainty (`uncertaintyMeters` $\in \mathbb{R}^+$)
- **Definition**: Estimated 1-sigma circular error probability radius in meters.
- **Consumer Guideline**: P2 should render this as the semi-transparent location accuracy circle around the user's map marker.

---

## 6. Four Infrastructure Scenarios (Four-Case Matrix)

| Case | GPS | Internet | Intended Mode | P1 Active Source | Behavior |
|:---:|:---:|:---:|:---|:---|:---|
| **Case 1** | **ON** | **ON** | `PositioningMode.gps` | `gps` | Full outdoor GPS positioning, real-time HTTP delivery, map snapping. |
| **Case 2** | **OFF** | **ON** | `PositioningMode.pdrFallback` | `pdr` / `wifiFingerprint` | Dead reckoning + Wi-Fi landmark anchoring. Events sent immediately via HTTP. |
| **Case 3** | **ON** | **OFF** | `PositioningMode.gps` | `gps` | Full outdoor GPS navigation. Safety events stored in offline queue. |
| **Case 4** | **OFF** | **OFF** | `PositioningMode.pdrFallback` | `pdr` / `wifiFingerprint` | Total infrastructure blackout. Dead reckoning + local queue persistence. |

---

## 7. Emergency Communication Contract (`SafetyEvent`)

When an incident (SOS, check-in, alert) occurs, P1 creates and persists a `SafetyEvent`.

### Endpoint: `POST /api/safety-events`

#### SafetyEvent Fields
```json
{
  "eventId": "SOS-1787436570471-1004",
  "eventType": "sos",
  "timestamp": "2026-08-23T12:00:00.000Z",
  "latitude": 19.07620,
  "longitude": 72.87790,
  "positionSource": "gps",
  "confidence": 0.96,
  "uncertaintyMeters": 3.8,
  "positioningMode": "gps",
  "gpsHealth": "active",
  "internetAvailable": true,
  "eventStatus": "sent",
  "retryCount": 0,
  "createdAt": "2026-08-23T12:00:00.000Z",
  "lastAttemptAt": "2026-08-23T12:00:00.050Z",
  "deliveryChannel": "HTTP",
  "failureReason": null,
  "metadata": {
    "battery": 85
  }
}
```

#### Delivery Lifecycle
```
                 ┌──────────────────┐
                 │ createSos(...)   │
                 └────────┬─────────┘
                          │
                          ▼
                 ┌──────────────────┐
                 │ Local Store Init │
                 │ (Durable File)   │
                 └────────┬─────────┘
                          │
               ONLINE ────┴──── OFFLINE
                 │                 │
                 ▼                 ▼
        ┌─────────────────┐ ┌──────────────┐
        │ HTTP Transport  │ │ OFFLINE_QUEUE│
        │ POST /api/...   │ └──────┬───────┘
        └────────┬────────┘        │ (Internet restored)
                 │                 ▼
        HTTP 200/201 ACK    ┌──────────────┐
                 │          │ SyncManager  │
                 ▼          └──────┬───────┘
        ┌─────────────────┐        │
        │ Status = SENT   │ ◄──────┘
        └─────────────────┘
```

- **Idempotency**: Repeated transmissions with the same `eventId` return `HTTP 200` with `duplicate: true`.
- **Durability**: Events are written to the app documents directory (`/data/user/0/.../sih_safety_events.json`) and survive app process restarts and device reboots.

---

## 8. How Each Module Consumes P1

### P2 — Maps & Routing
- **Consume**: `snapshot.position.latitude`, `snapshot.position.longitude`, `snapshot.position.uncertaintyMeters`, `snapshot.movement.headingDegrees`.
- **Usage**: Update user map marker, accuracy circle radius, route progress, and snapping onto roads/walkable paths.

### P3 — Contextual Safety & Risk Intelligence
- **Consume**: `snapshot.position`, `snapshot.movement.speedMps`, `snapshot.movement.isStationary`, `snapshot.resilience.infrastructureCase`.
- **Usage**: Check location against crime polygons; detect abnormal pauses; evaluate connectivity context for safety recommendations.

### P4 — Communication Resilience & Blockchain Incident Log
- **Consume**: `SafetyEvent` stream from `SafetyEngine.eventStream`, `snapshot.connectivity.activeDeliveryChannel`.
- **Usage**: If HTTP transmission is unavailable, trigger SMS/satellite/relay fallback; record immutable incident hash to blockchain ledger.

### P5 — Backend Server & Ingestion APIs
- **Consume**: `P1SystemSnapshot.toJson()`, `POST /api/safety-events` JSON payload.
- **Usage**: Real-time cloud telemetry dashboard, incident dispatcher alert portal, emergency operator console.

### P6 — UI & Mobile Dashboards
- **Consume**: `P1IntegrationFacade.snapshotStream` or `P1IntegrationFacade.getCurrentSnapshot()`.
- **Usage**: Live step counters, compass rose, resilience case badge (Case 1/2/3/4), GPS satellite health indicators, queue badge (`QUEUE (N)`).

---

## 9. Example Code: How to Access P1 in Dart

```dart
import 'package:sih/integration/models/p1_system_snapshot.dart';
import 'package:sih/integration/p1_integration_facade.dart';

void exampleModuleConsumption(P1IntegrationFacade p1) {
  // 1. One-shot point-in-time snapshot
  final P1SystemSnapshot snapshot = p1.getCurrentSnapshot();

  print('Location: ${snapshot.position.latitude}, ${snapshot.position.longitude}');
  print('Source: ${snapshot.position.source} (±${snapshot.position.uncertaintyMeters}m)');
  print('Steps: ${snapshot.movement.steps} (${snapshot.movement.distanceMeters}m walked)');
  print('Heading: ${snapshot.movement.headingDegrees}° ${snapshot.movement.direction}');
  print('Case: ${snapshot.resilience.infrastructureCase} (${snapshot.resilience.systemStatusLabel})');
  print('Online: ${snapshot.connectivity.isOnline}');

  // 2. Continuous real-time stream subscription (for Map / UI / Risk engine)
  p1.snapshotStream.listen((P1SystemSnapshot liveSnapshot) {
    if (liveSnapshot.position.hasValidFix) {
      // Update map marker
    }
  });
}
```

---

## 10. Team Boundaries & Responsibility Matrix

| Feature / Capability | P1 (Localization) | P2 (Maps) | P3 (Risk) | P4 (Fallback) | P5 (Backend) | P6 (UI) |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|
| GPS satellite fix & health | **OWNS** | Consumes | Consumes | — | — | Consumes |
| Inertial PDR & Step detection | **OWNS** | Consumes | Consumes | — | — | Consumes |
| Wi-Fi WKNN Fingerprinting | **OWNS** | Consumes | — | — | — | Consumes |
| Resilience State Machine | **OWNS** | Consumes | Consumes | Consumes | — | Consumes |
| Offline Safety Event Queue | **OWNS** | — | — | Consumes | Consumes | Consumes |
| HTTP Transport to Server | **OWNS** | — | — | — | Consumes | — |
| Google Maps & Path Rendering | — | **OWNS** | — | — | — | Consumes |
| Safe Haven Ranking & Risk Math| — | — | **OWNS** | — | — | Consumes |
| SMS / BLE Relay / Blockchain | — | — | — | **OWNS** | Consumes | — |
| Central Cloud Dispatch API | — | — | — | — | **OWNS** | — |
| App Dashboards & Widgets | — | — | — | — | — | **OWNS** |

---

## 11. Fields NOT Currently Exposed by P1

For complete transparency and zero ambiguity across teams:
- ❌ **Barometric Altitude / Floor Level**: Not calculated (requires calibrated barometer hardware pipeline).
- ❌ **Cellular Tower Triangulation (Cell ID / LAC)**: Not exposed directly; P1 relies on GPS + Wi-Fi + PDR.
- ❌ **Battery Level in Snapshot**: Exposed only in SafetyEvent metadata if passed by caller.
- ❌ **Crime / Danger Scores**: Excluded by design (owned by P3).
- ❌ **Turn-by-turn Navigation Prompts**: Excluded by design (owned by P2).

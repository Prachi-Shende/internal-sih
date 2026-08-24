# Physical Device Test Plan: SafeTravel / Travara on Vivo V2303

---

## 1. Hardware & Test Setup

- **Target Device:** Vivo V2303 (Android 14)
- **Device Serial:** `10BDA62262000KF`
- **Host Machine:** Windows PC
- **Connectivity:** USB Debugging + ADB Reverse Tunnel
- **Backend URL:** `http://127.0.0.1:8000` (Forwarded via ADB Reverse)

### Prerequisites Check:
1. **Start FastAPI Backend:**
   ```powershell
   cd "c:\testing\Backend and Frontend Integration and Testing\internal-sih-main\internal-sih-main\Ayaansh\safetravel_backend"
   py -3.12 -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```
2. **Enable ADB Reverse Port Forwarding:**
   ```powershell
   adb reverse tcp:8000 tcp:8000
   ```
   *Verify with `adb reverse --list` (must output `UsbFfs tcp:8000 tcp:8000`)*.
3. **Launch Flutter App on Phone:**
   ```powershell
   cd "c:\testing\Backend and Frontend Integration and Testing\internal-sih-main\internal-sih-main"
   flutter run -d 10BDA62262000KF
   ```

---

## 2. Test Execution: Four Resilience Cases

### CASE 1: GPS ACTIVE + INTERNET ONLINE
- **Action on Phone:** Keep Location ON and Wi-Fi / Mobile Data ON. Walk outdoors or near a window.
- **Expected Observations:**
  - `AppState.systemState` shows **FULL RESILIENCE** (`SystemState.normal`).
  - Active Positioning Source displays **GPS** with `HIGH` confidence.
  - Telemetry posted automatically to `POST /location`.
  - Open Profile -> **Resilience 4-Case Demo** -> Case 1 is highlighted **ACTIVE / VERIFIED**.
  - Open Profile -> **P1 Sensor Diagnostics** -> Lat/Lon updates, Uncertainty ~3-5m, Comm Channel: `HTTP`.

---

### CASE 2: GPS DEGRADED / LOST + INTERNET ONLINE
- **Action on Phone:** Walk indoors into a basement/tunnel, OR open Profile -> **Developer Simulation Sandbox** and select `GPS: [ LOST ]`.
- **Expected Observations:**
  - System resilience transitions to **DEGRADED OPERATION** (`SystemState.gpsDegraded`).
  - Positioning source switches automatically to **PDR (Pedestrian Dead Reckoning)**.
  - Step counter increments in real-time as you walk with the phone.
  - Gyroscope/Compass heading adjusts dynamically as you rotate the device.
  - Communication remains active via `HTTP`.
  - Open Profile -> **Resilience 4-Case Demo** -> Case 2 is highlighted **ACTIVE / VERIFIED**.

---

### CASE 3: GPS ACTIVE + INTERNET OFFLINE
- **Action on Phone:** Keep Location ON. Turn OFF Wi-Fi and Mobile Data (or Airplane Mode with Location ON).
- **Expected Observations:**
  - System resilience transitions to **OFFLINE** (`SystemState.offline`).
  - GPS positioning continues updating coordinates.
  - Communication status shows `OFFLINE` / `OFFLINE_QUEUE`.
  - Tap **I Feel Unsafe** (SOS) on the Safety screen:
    - Screen displays banner: `"Saved offline — will sync when connection returns."`
    - `FileSafetyEventStore` writes `SOS-{timestamp}` JSON directly to app flash storage.
    - Pending Offline Queue badge increments to `1`.
  - Open Profile -> **Resilience 4-Case Demo** -> Case 3 is highlighted **ACTIVE / VERIFIED**.

---

### CASE 4: GPS LOST + INTERNET OFFLINE (TOTAL BLACKOUT)
- **Action on Phone:** In Airplane Mode / Offline, open **Developer Simulation Sandbox** and select `GPS: [ LOST ]` and `Internet: [ OFFLINE ]` (or Quick Preset: *Total Blackout*).
- **Expected Observations:**
  - System resilience shows **TOTAL BLACKOUT (Case 4)**.
  - PDR engine maintains movement dead-reckoning from IMU sensors.
  - Trigger SOS: Event is safely written to `FileSafetyEventStore` with PDR estimated coordinates.
  - Offline queue increments to `2 pending`.
  - Zero crashes, zero unhandled network exceptions.

---

## 3. Verifying Local Queue & App Restart Persistence

1. **Trigger an Offline Event:**
   - Put phone in Airplane mode and tap **I Feel Unsafe**.
   - Note that `Queue: 1 pending` appears on the diagnostic screen.
2. **Force Kill the Application:**
   - Swipe away Travara from Android recent apps switcher.
   - Run `adb shell am force-stop com.travara.app` (or close from phone).
3. **Re-launch While Still Offline:**
   - Open Travara.
   - Navigate to Profile -> **P1 Sensor Diagnostics**.
   - **Verify:** `Pending Offline Queue` immediately reads `1 events` (retrieved from `FileSafetyEventStore` on disk).

---

## 4. Verifying Automatic Reconnection & SyncManager

1. **Restore Internet Connection:**
   - Turn Wi-Fi / Mobile Data back ON (disable Airplane Mode).
2. **Observe Automatic Sync:**
   - `ConnectivityService` detects network restoration within 1–2 seconds.
   - `SyncManager.syncNow()` triggers automatically in background.
   - Diagnostic log outputs: `[SAFETY] Internet restored (ONLINE). Triggering automatic queue synchronization.`
   - Queued events are posted to `POST /api/safety-events` on backend.
   - Pending queue drops from `1` to `0` (`QUEUE DRAINED`).
3. **Verify on FastAPI Backend:**
   - Query `http://127.0.0.1:8000/incident` in browser or curl.
   - Verify that the incident contains the exact event ID, timestamps, GPS/PDR coordinates, and immutable SHA-256 blockchain hash (`0x...`).

---

## 5. Verifying Travel History

1. Open Profile -> **Travel & Safety History**.
2. Select **South Mumbai Heritage Walk** or active recorded journey.
3. Verify that the interactive map renders:
   - Green route polyline for GPS points.
   - Amber highlighted segments for PDR dead-reckoning intervals.
   - Start origin marker and destination marker.
   - Statistics: Distance (km), Steps, Duration, and Safety Alerts.

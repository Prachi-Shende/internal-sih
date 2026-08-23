<div align="center">
  <h1>🛡️ Travara (SafeTravel)</h1>
  <p><b>An Offline-First Tourist Safety & Navigation Ecosystem</b></p>
</div>

---

## 📖 Overview
Travara is an advanced, offline-capable tourist safety application designed to protect travelers in unfamiliar environments. It ensures graceful degradation of services—meaning that even when you lose internet connection, cellular service, or GPS, the app continues to protect you and coordinate help.

## ✨ Key Features
* **Real-time Geo-fencing & Alarms:** Continuously monitors your live GPS coordinates against the radius of known crime hotspots, triggering instant on-screen warnings if you enter a dangerous area.
* **Offline Maps & Routing:** Powered by OpenStreetMap and OSRM, generating real-time pedestrian walking routes directly on the map without needing constant internet.
* **Pedestrian Dead Reckoning (PDR):** If GPS satellites are obstructed (e.g. in a tunnel or dense city), the app uses the device's accelerometer, gyroscope, and compass to estimate your movement locally.
* **Local Offline Data Queue:** If you trigger an `EMERGENCY SOS` without internet, the request is encrypted and queued locally, automatically transmitting to responders the microsecond a network connection or SMS relay is detected.
* **Dynamic Risk Theming:** The app's entire UI shifts colors (tinting red and pulsing) based on the live threat assessment of your immediate area.
* **Immutable Evidence Logging (Blockchain):** To prevent corruption or tampering, every emergency incident logged is cryptographically hashed and recorded on a smart-contract blockchain, creating an undeniable chain of custody.

## 🏗️ Architecture & Workflow
The system utilizes a heavily resilient client-server architecture:
1. **Live State Sync:** The Flutter client maintains a live socket/polling connection with the backend, continually updating your safety state based on Firebase Authentication.
2. **Risk Assessment Engine:** The Python backend continuously ingests crime data, clustering it into Hotspots and calculating dynamic "Danger Scores" out of 100 for any given coordinate.
3. **Emergency Trigger Workflow:** 
   - User triggers SOS → App attempts API call.
   - If offline → App queues locally and attempts SMS relay.
   - Backend receives SOS → Logs to Postgres → Writes hash to Blockchain → Updates Global UI Theme for the user's session.

## 🛠️ Tech Stack
**Frontend (Mobile)**
* Flutter & Dart (Cross-platform iOS/Android)
* `flutter_map` (OSM rendering) & `geolocator`
* Firebase Authentication

**Backend (Server & Processing)**
* FastAPI (Python 3.10+)
* PostgreSQL & SQLite
* SQLAlchemy ORM
* OSRM (Open Source Routing Machine) APIs
* Web3 / Blockchain Smart Contracts (for Incident Hashing)

## 🚀 How to Run the App

### 1. Start the Backend
```bash
cd Ayaansh/safetravel_backend
pip install -r requirements.txt
# Run on 0.0.0.0 so physical devices on Wi-Fi can connect
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 2. Configure the Frontend
Update `lib/config.dart` to point to your computer's local Wi-Fi IP address (e.g. `http://192.168.x.x:8000`) instead of localhost, so physical devices can communicate with the backend wirelessly.

### 3. Run the Flutter App
```bash
flutter pub get
# A full run is required (no hot restart) due to heavy native plugins
flutter run
```

## 🔮 Future Scope
* **Wearable Integration:** Triggering SOS directly from smartwatches without pulling out the phone.
* **Predictive AI Risk Modeling:** Using historical data to predict which streets will become dangerous at specific times of night.
* **Mesh Networking:** Allowing tourists' phones to communicate via Bluetooth/Wi-Fi Direct to form an offline emergency relay network in remote locations.

## 👥 Team
- Diksha Thongire
- Ayaansh Churi
- Sourish Phate
- Prachi Shende
- Krish Shah
- Shipra Singh
Built for **Smart India Hackathon (SIH)**.

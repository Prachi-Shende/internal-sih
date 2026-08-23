# TRAVARA: Offline-First Tourist Safety App 🛡️🧭

TRAVARA is an advanced, offline-capable tourist safety and navigation application. Designed to protect tourists in unfamiliar environments, it ensures graceful degradation of services—meaning that even when you lose internet connection, cellular service, or GPS, the app continues to protect you and coordinate help.

## Core Architecture 🏗️

The system is broken down into 5 heavily resilient modules:

### P1: Core Services & Live State
- **Live Authentication Sync**: Seamlessly integrates with Firebase Authentication. Your unique `uid` serves as your session identifier, ensuring your Incident History and GPS track follows you across any device.
- **Dynamic Risk Theming**: The app's UI is globally tied to a live risk state. If an emergency is active, the app automatically transitions into an **Emergency Theme**—tinting the `Scaffold` red, pulsating the navigation bar, and locking a high-priority warning banner to the top of your screen.

### P2: Mapping, Geo-fencing, & Navigation
- **Offline Maps**: Powered by `flutter_map`, rendering lightweight OpenStreetMap tiles. 
- **Real-time Geo-fencing Alarms**: The map continuously monitors your real GPS coordinates against the radius of known crime hotspots. If you walk into a dangerous area, an immediate on-screen alarm is triggered.
- **In-App Routing**: Uses OSRM (Open Source Routing Machine) to generate real-time pedestrian walking routes directly on the map.
- **Deep-linking Fallback**: One-tap deep links out to the native Google Maps app for driving directions and mass-transit routes to safe locations (Hospitals, Police stations).

### P3: Risk Assessment Engine
- Calculates live "Danger Scores" for locations. When tapping on a crime hotspot, tourists can instantly see a detailed breakdown of Total Reported Incidents, Recent Incidents, and a composite Danger Score out of 100.

### P4: Offline Sync, Reliability & Immutable Evidence (Blockchain)
- **Pedestrian Dead Reckoning (PDR)**: If GPS satellites are obstructed (e.g., in a tunnel or dense city), the app uses the device's accelerometer, gyroscope, and compass to estimate movement locally.
- **Local Offline Queue**: If you trigger an `EMERGENCY SOS` without internet, the request is not dropped. It is encrypted and queued locally, automatically blasting off to the servers the microsecond a network connection is detected.
- **Blockchain Verification**: Corrupt entities cannot erase evidence of an emergency. When an incident is logged, a cryptographic hash is taken and recorded on a smart-contract blockchain. Your profile's "Incident History" will permanently display this exact `blockchain_hash`, creating an undeniable chain of custody for your emergency.

### P5: Communication & Fallbacks
- Designed to fallback to SMS-based relay networks when standard 4G/5G data is entirely unavailable, ensuring your encrypted GPS coordinates always reach responders.

---

## Getting Started (Development)

### Prerequisites
- Flutter SDK (latest stable)
- Firebase CLI (for auth setup)
- Python 3.10+ (for the FastAPI backend)

### Running the App
1. Ensure the Python backend is running locally on `http://localhost:8000`.
2. Connect a physical Android/iOS device or an emulator.
3. Run the following:
```bash
flutter pub get
flutter run
```

> **Note**: Because this app utilizes heavy native plugins (`geolocator`, `url_launcher`), a full `flutter run` is required instead of Hot Restart if you are pulling the code for the first time or updating dependencies.

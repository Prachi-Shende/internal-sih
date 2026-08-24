import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  // Toggle to true to use local mock data (no backend needed)
  static const bool MOCK_MODE = false;

  // Toggle to true when testing on physical Android device connected via USB with ADB reverse active
  // (e.g. `adb reverse tcp:8000 tcp:8000`). With ADB reverse active, localhost/127.0.0.1 on the phone
  // is forwarded directly to the PC backend on port 8000.
  static const bool useAdbReverse = true;

  // Set your Windows PC LAN IP address here if testing on physical device over Wi-Fi without ADB reverse
  static const String pcLanIp = '192.168.1.9';

  // Toggle to true if running on Android Emulator (10.0.2.2) instead of physical device
  static const bool isEmulator = false;

  static String get apiBaseUrl {
    if (kIsWeb) {
      // Running in browser — backend is on same machine
      return 'http://localhost:8000';
    }
    if (isEmulator) {
      // Android Emulator maps 10.0.2.2 to the host machine's localhost
      return 'http://10.0.2.2:8000';
    }
    if (useAdbReverse) {
      // Physical Android Device with ADB reverse (`adb reverse tcp:8000 tcp:8000`)
      return 'http://127.0.0.1:8000';
    }
    // Physical Android Device on same Wi-Fi network as PC
    return 'http://$pcLanIp:8000';
  }

  // P2 Geospatial — currently called via P5 proxy, kept here for direct access if needed
  static String get p2BaseUrl {
    if (kIsWeb) return 'http://localhost:8001';
    if (isEmulator) return 'http://10.0.2.2:8001';
    if (useAdbReverse) return 'http://127.0.0.1:8001';
    return 'http://$pcLanIp:8001';
  }
}



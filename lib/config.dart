import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  // Toggle this to true to fall back to the local mock data
  static const bool MOCK_MODE = false;

  static String get apiBaseUrl {
    // Because you removed the USB, adb reverse is broken.
    // Use your laptop's actual Wi-Fi IP address instead!
    return 'http://192.168.29.39:8000';
  }
}

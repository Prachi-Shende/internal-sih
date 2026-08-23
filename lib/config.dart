import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  // Toggle this to true to fall back to the local mock data
  static const bool MOCK_MODE = false;

  static String get apiBaseUrl {
    // Because we are running 'adb reverse tcp:8000 tcp:8000', 
    // the phone will successfully route localhost to your laptop!
    return 'http://localhost:8000';
  }
}

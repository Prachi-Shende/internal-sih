import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SessionService {
  static String? _cachedId;

  static Future<String> getOrCreateSessionId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _cachedId = user.uid;
      return user.uid;
    }

    if (_cachedId != null) return _cachedId!;
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('session_id');
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString('session_id', id);
    }
    _cachedId = id;
    return id;
  }
}

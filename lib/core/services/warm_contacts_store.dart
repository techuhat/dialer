import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences helper for persisting a lightweight contacts snapshot
/// so the Contacts tab can render immediately on cold start.
class WarmContactsStore {
  static const String _key = 'contacts_warm_snapshot_v1';

  static Future<Map<String, dynamic>> read() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{_key: raw};
  }

  static Future<void> write(Map<String, dynamic> data) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Object? value = data['snapshot'];
    if (value is String) {
      await prefs.setString(_key, value);
    }
  }
}

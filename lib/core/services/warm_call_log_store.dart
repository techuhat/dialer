import 'package:shared_preferences/shared_preferences.dart';

/// Tiny helper around SharedPreferences for persisting a warm snapshot
/// of the call log cache so that history can render instantly on launch.
class WarmCallLogStore {
  static const String _key = 'call_logs_warm_snapshot_v1';

  static Future<Map<String, dynamic>> read() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null) {
      return <String, dynamic>{};
    }
    // Same key CallLogService.loadWarmSnapshot reads (and saveWarmSnapshot writes).
    return <String, dynamic>{'snapshot': raw};
  }

  static Future<void> write(Map<String, dynamic> data) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // CallLogService.saveWarmSnapshot sends the data under the key 'snapshot'
    final Object? value = data['snapshot'];
    if (value is String) {
      await prefs.setString(_key, value);
    }
  }
}

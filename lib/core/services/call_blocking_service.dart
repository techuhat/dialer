import 'package:shared_preferences/shared_preferences.dart';

import '../call_service.dart';
import 'platform_channel.dart';

/// The system block list: blocked numbers are rejected by the phone itself before they ring,
/// even while this app is closed.
class CallBlockingService {
  const CallBlockingService._();

  static const String _legacyKey = 'blocked_numbers';
  static bool _migrated = false;

  /// Only the default dialer may edit the system list.
  static Future<bool> canBlock() async => await invokeSafe<bool>(CallService.channel, 'canBlockNumbers') ?? false;

  static Future<List<String>> getBlockedNumbers() async {
    await _migrateLegacyList();
    final List<Object?>? numbers = await invokeSafe<List<Object?>>(CallService.channel, 'getBlockedNumbers');
    return numbers?.whereType<String>().toList() ?? <String>[];
  }

  static Future<bool> blockNumber(String number) async =>
      await invokeSafe<bool>(CallService.channel, 'blockNumber', <String, Object?>{'number': number.trim()}) ??
      false;

  static Future<bool> unblockNumber(String number) async =>
      await invokeSafe<bool>(CallService.channel, 'unblockNumber', <String, Object?>{'number': number}) ?? false;

  /// Earlier versions kept their own list, which only worked while the app was open.
  static Future<void> _migrateLegacyList() async {
    if (_migrated) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> legacy = prefs.getStringList(_legacyKey) ?? const <String>[];
    if (legacy.isEmpty) {
      _migrated = true;
      return;
    }
    if (!await canBlock()) return; // try again once the app is the default dialer
    for (final String number in legacy) {
      await blockNumber(number);
    }
    await prefs.remove(_legacyKey);
    _migrated = true;
  }
}

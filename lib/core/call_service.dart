import 'package:flutter/services.dart';

import 'services/platform_channel.dart';

/// Flutter → native call commands. Every method resolves to false/null instead of throwing.
class CallService {
  const CallService._();

  /// Shared with the native → Flutter events (see `CallRouter`).
  static const MethodChannel channel = MethodChannel('app.call_manager/call');

  /// `*` and `#` carry MMI codes, `,` is a pause and `;` a wait: they must survive sanitising.
  static final RegExp _illegalDialChars = RegExp(r'[^\d+*#,;]');

  static String sanitizeDialString(String number) => number.replaceAll(_illegalDialChars, '').trim();

  static Future<bool> _command(String method, [Map<String, Object?>? arguments]) async =>
      await invokeSafe<bool>(channel, method, arguments) ?? false;

  /// Tells native that Dart can receive events; it then replays what it queued.
  static Future<void> listen() => invokeSafe<void>(channel, 'listen');

  static Future<Map<Object?, Object?>?> getCalls() => invokeSafe<Map<Object?, Object?>>(channel, 'getCalls');

  static Future<int?> getActiveSimCount() => invokeSafe<int>(channel, 'getSimCount');

  static Future<bool> makeCall(String number, {int? simSlot}) {
    final String dialString = sanitizeDialString(number);
    if (dialString.isEmpty) return Future<bool>.value(false);
    return _command('placeCall', <String, Object?>{'number': dialString, 'simSlot': simSlot});
  }

  /// Service codes are run by the platform, which shows its own result; no call screen.
  static Future<bool> sendMmi(String code, {int? simSlot}) {
    final String dialString = sanitizeDialString(code);
    if (dialString.isEmpty) return Future<bool>.value(false);
    return _command('runMmi', <String, Object?>{'number': dialString, 'simSlot': simSlot});
  }

  static Future<bool> answer() => _command('answer');

  /// Declines the ringing call only; never the one in progress. [message] is texted by Telecom.
  static Future<bool> reject({String? message}) => _command('reject', <String, Object?>{'message': message});

  static Future<bool> end() => _command('end');
  static Future<bool> hold(bool on) => _command('hold', <String, Object?>{'on': on});
  static Future<bool> swap() => _command('swap');
  static Future<bool> merge() => _command('merge');
  static Future<bool> holdAndAnswer() => _command('holdAndAnswer');
  static Future<bool> endAndAnswer() => _command('endAndAnswer');
  static Future<bool> mute(bool on) => _command('mute', <String, Object?>{'on': on});
  static Future<bool> route(String route) => _command('route', <String, Object?>{'route': route});
  static Future<bool> dtmf(String digit) => _command('dtmf', <String, Object?>{'digit': digit});
  static Future<bool> selectSim(int slot) => _command('selectSim', <String, Object?>{'simSlot': slot});

  static Future<bool> composeSms(String number, {String? body}) =>
      _command('composeSms', <String, Object?>{'number': number, 'body': body});
}

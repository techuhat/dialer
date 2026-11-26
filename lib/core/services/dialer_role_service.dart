import 'package:flutter/services.dart';

import 'platform_channel.dart';

/// Default-dialer role and the permissions that are requested through the Activity.
class DialerRoleService {
  const DialerRoleService._();

  static const MethodChannel _channel = MethodChannel('app.call_manager/role');

  static Future<bool> _ask(String method) async => await invokeSafe<bool>(_channel, method) ?? false;

  static Future<bool> isDefaultDialer() => _ask('isDefaultDialer');
  static Future<bool> requestDefaultDialer() => _ask('requestDefaultDialer');
  static Future<bool> openDefaultDialerSettings() => _ask('openDefaultDialerSettings');
  static Future<bool> hasNotificationPermission() => _ask('hasNotificationPermission');
  static Future<bool> requestNotificationPermission() => _ask('requestNotificationPermission');
  static Future<bool> hasFullScreenIntentPermission() => _ask('hasFullScreenIntentPermission');
  static Future<bool> requestFullScreenIntentPermission() => _ask('requestFullScreenIntentPermission');
}

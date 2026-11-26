import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Invokes [method] and returns null instead of throwing when the platform side fails.
Future<T?> invokeSafe<T>(MethodChannel channel, String method, [Object? arguments]) async {
  try {
    return await channel.invokeMethod<T>(method, arguments);
  } on PlatformException catch (error) {
    debugPrint('${channel.name}.$method failed: ${error.message}');
  } on MissingPluginException {
    debugPrint('${channel.name}.$method is not available on this platform');
  }
  return null;
}

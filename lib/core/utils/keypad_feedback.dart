import 'package:flutter/services.dart';

/// Key press feedback. [SystemSound] follows the device "touch sounds" setting.
class KeypadFeedback {
  const KeypadFeedback._();

  static void key({bool sound = true}) {
    HapticFeedback.selectionClick();
    if (sound) SystemSound.play(SystemSoundType.click);
  }

  static void alternateKey({bool sound = true}) {
    HapticFeedback.mediumImpact();
    if (sound) SystemSound.play(SystemSoundType.click);
  }

  static void backspace() => HapticFeedback.lightImpact();

  static void clear() => HapticFeedback.mediumImpact();

  static void rejected() => HapticFeedback.lightImpact();
}

import 'package:flutter/foundation.dart';

/// A number from an inbound `tel:` / ACTION_DIAL intent, waiting to be pre-filled (never dialled).
/// HomePage switches to the dialpad tab; DialpadPage [consume]s it so it is applied once.
class DialIntentService {
  DialIntentService._();

  static final ValueNotifier<String?> pendingNumber = ValueNotifier<String?>(null);

  static void request(String number) {
    final String trimmed = number.trim();
    if (trimmed.isEmpty) {
      return;
    }
    debugPrint('☎️ [DialIntentService] Pre-fill requested: $trimmed');
    pendingNumber.value = trimmed;
  }

  static String? consume() {
    final String? value = pendingNumber.value;
    if (value != null) {
      pendingNumber.value = null;
    }
    return value;
  }

  static void clear() => pendingNumber.value = null;
}

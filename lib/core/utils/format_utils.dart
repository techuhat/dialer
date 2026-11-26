import 'package:intl/intl.dart';

class TimeUtils {
  const TimeUtils._();

  static String formatCallTimestamp(DateTime timestamp) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime day = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final String time = DateFormat('hh:mm a').format(timestamp);

    if (day == today) return 'Today · $time';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday · $time';
    if (now.difference(timestamp).inDays < 7) return '${DateFormat('EEE').format(timestamp)} · $time';
    if (timestamp.year == now.year) return DateFormat('MMM d · hh:mm a').format(timestamp);
    return DateFormat('MMM d, yyyy · hh:mm a').format(timestamp);
  }

  /// Compact talk time for lists: `45s`, `3m 12s`, `1h 5m`.
  static String formatDuration(int seconds) {
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    final int rest = seconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${rest}s';
    return '${rest}s';
  }

  /// Running call clock: `04:09`, or `1:04:09` past the hour.
  static String formatClock(Duration duration) {
    final Duration safe = duration.isNegative ? Duration.zero : duration;
    final String minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
    final String seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
    return safe.inHours > 0 ? '${safe.inHours}:$minutes:$seconds' : '$minutes:$seconds';
  }

  static String formatRelativeTime(DateTime timestamp) {
    final Duration difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d').format(timestamp);
  }
}

class NameUtils {
  const NameUtils._();

  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _startsWithLetter = RegExp(r'^\p{L}', unicode: true);

  /// First letters of the first and last word (`John Ronald Doe` → `JD`); empty for numbers.
  static String initials(String name) {
    final List<String> words = name
        .trim()
        .split(_whitespace)
        .where(_startsWithLetter.hasMatch)
        .toList(growable: false);
    if (words.isEmpty) return '';
    final String first = words.first[0];
    final String last = words.length > 1 ? words.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  /// Java's `String.hashCode`, so Flutter and the native notification pick the same avatar colour.
  static int stableHash(String value) {
    int hash = 0;
    for (final int unit in value.codeUnits) {
      hash = (31 * hash + unit).toSigned(32);
    }
    return hash;
  }
}

class PhoneUtils {
  const PhoneUtils._();

  static final RegExp _nonDigitPlus = RegExp(r'[^\d+]');
  static final RegExp _leadingPlus = RegExp(r'^\+');
  static final RegExp _nonDigit = RegExp(r'\D');
  static final RegExp _whitespace = RegExp(r'\s');

  /// MMI / USSD service codes (`*#06#`, `*123#`, `*21*123456#`): run, never dialled as calls.
  static final RegExp _mmi = RegExp(r'^[*#][*#\d+]*#$');

  /// Emergency numbers skip the SIM picker and every other prompt.
  static const Set<String> _emergencyNumbers = <String>{
    '112', '100', '101', '102', '108', '1091', '1098', // India
    '911', '999', '000', // North America, UK, Australia
  };

  static bool isMmiCode(String input) {
    final String trimmed = input.replaceAll(_whitespace, '');
    return trimmed.length >= 3 && !isEmergencyNumber(trimmed) && _mmi.hasMatch(trimmed);
  }

  static bool isEmergencyNumber(String input) => _emergencyNumbers.contains(input.replaceAll(_nonDigit, ''));

  /// Last ten digits: `+91 98…`, `098…` and `98…` give the same key. Use it to match calls.
  static String matchKey(String number) {
    final String digits = number.replaceAll(_nonDigit, '');
    if (digits.isEmpty) return number.trim().toLowerCase();
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  static bool isSameNumber(String a, String b) => matchKey(a) == matchKey(b);

  static String formatPhoneNumber(String number) {
    final String cleaned = cleanPhoneNumber(number);
    if (cleaned.isEmpty) return number.trim();

    if (_isLikelyIndianNumber(cleaned)) {
      final String national = _extractIndianNationalNumber(cleaned);
      if (national.length == 10) {
        final bool withCode = _hasIndianCountryCode(cleaned) || _looksLikeIndianMobile(national);
        final String grouped = '${national.substring(0, 5)} ${national.substring(5)}';
        return withCode ? '+91 $grouped' : grouped;
      }
      return national;
    }

    if (cleaned.startsWith('+')) {
      if (cleaned.startsWith('+1') && cleaned.length >= 12) {
        return '+1 (${cleaned.substring(2, 5)}) ${cleaned.substring(5, 8)}-${cleaned.substring(8)}';
      }
      return _formatInternational(cleaned);
    }
    if (cleaned.length == 10) {
      return '${cleaned.substring(0, 3)} ${cleaned.substring(3, 6)} ${cleaned.substring(6)}';
    }
    if (cleaned.length > 7) {
      final int split = cleaned.length - 4;
      return '${cleaned.substring(0, split)} ${cleaned.substring(split)}';
    }
    return cleaned;
  }

  static String cleanPhoneNumber(String number) {
    String cleaned = number.replaceAll(_nonDigitPlus, '');
    if (cleaned.startsWith('00') && cleaned.length > 2) cleaned = '+${cleaned.substring(2)}';
    return cleaned;
  }

  /// National form used as a lookup key for contacts, blocking and notes.
  static String normalizePhoneNumber(String number) {
    String cleaned = cleanPhoneNumber(number);
    if (cleaned.startsWith('+')) cleaned = cleaned.substring(1);
    if (cleaned.startsWith('91') && cleaned.length > 10) cleaned = cleaned.substring(cleaned.length - 10);
    if (cleaned.startsWith('0') && cleaned.length > 10) cleaned = cleaned.substring(cleaned.length - 10);
    if (cleaned.startsWith('1') && cleaned.length == 11) cleaned = cleaned.substring(1);
    return cleaned;
  }

  static bool arePhoneNumbersEqual(String number1, String number2) {
    final String normalized1 = normalizePhoneNumber(number1);
    final String normalized2 = normalizePhoneNumber(number2);
    if (normalized1.isNotEmpty && normalized1 == normalized2) return true;

    final String clean1 = cleanPhoneNumber(number1).replaceFirst(_leadingPlus, '');
    final String clean2 = cleanPhoneNumber(number2).replaceFirst(_leadingPlus, '');
    if (clean1 == clean2) return true;

    // Suffix matching needs 7+ digits, or short codes would match unrelated numbers.
    const int minSuffix = 7;
    return normalized1.length >= minSuffix &&
        normalized2.length >= minSuffix &&
        (clean2.endsWith(normalized1) || clean1.endsWith(normalized2));
  }

  static bool _isLikelyIndianNumber(String cleaned) {
    final String digits = cleaned.replaceAll('+', '');
    if (digits.startsWith('91') && digits.length >= 12) return true;
    if (digits.startsWith('0') && digits.length == 11) return _looksLikeIndianMobile(digits.substring(1));
    if (digits.length == 10) return _looksLikeIndianMobile(digits);
    return cleaned.startsWith('+91');
  }

  static bool _hasIndianCountryCode(String cleaned) =>
      cleaned.startsWith('+91') || cleaned.startsWith('0091') || (cleaned.startsWith('91') && cleaned.length > 10);

  static String _extractIndianNationalNumber(String cleaned) {
    String digits = cleaned.replaceAll('+', '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.startsWith('91') && digits.length > 10) digits = digits.substring(digits.length - 10);
    if (digits.startsWith('0') && digits.length == 11) digits = digits.substring(1);
    return digits;
  }

  static String _formatInternational(String cleaned) {
    if (cleaned.length <= 3) return cleaned;
    final StringBuffer buffer = StringBuffer(cleaned.substring(0, 3));
    for (int index = 3; index < cleaned.length; index += 4) {
      final int end = index + 4 <= cleaned.length ? index + 4 : cleaned.length;
      buffer
        ..write(' ')
        ..write(cleaned.substring(index, end));
    }
    return buffer.toString();
  }

  static bool _looksLikeIndianMobile(String digits) => digits.isNotEmpty && '6789'.contains(digits[0]);
}

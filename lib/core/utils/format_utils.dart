import 'package:intl/intl.dart';

class TimeUtils {
  static String formatCallTimestamp(DateTime timestamp) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    final DateTime callDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (callDate == today) {
      return 'Today · ${DateFormat('hh:mm a').format(timestamp)}';
    } else if (callDate == yesterday) {
      return 'Yesterday · ${DateFormat('hh:mm a').format(timestamp)}';
    } else if (now.difference(timestamp).inDays < 7) {
      return '${DateFormat('EEE').format(timestamp)} · ${DateFormat('hh:mm a').format(timestamp)}';
    } else if (timestamp.year == now.year) {
      return DateFormat('MMM d · hh:mm a').format(timestamp);
    } else {
      return DateFormat('MMM d, yyyy · hh:mm a').format(timestamp);
    }
  }

  static String formatDuration(int seconds) {
    if (seconds == 0) return '0s';
    
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    final int remainingSeconds = seconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${remainingSeconds}s';
    } else {
      return '${remainingSeconds}s';
    }
  }

  static String formatRelativeTime(DateTime timestamp) {
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  static String getTimeOfDay(DateTime timestamp) {
    final int hour = timestamp.hour;
    
    if (hour >= 5 && hour < 12) {
      return 'Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Evening';
    } else {
      return 'Night';
    }
  }
}

class PhoneUtils {
  static String formatPhoneNumber(String number) {
    final String cleaned = cleanPhoneNumber(number);

    if (cleaned.isEmpty) {
      return number.trim();
    }

    if (_isLikelyIndianNumber(cleaned)) {
      final String nationalNumber = _extractIndianNationalNumber(cleaned);
      if (nationalNumber.length == 10) {
        final bool includeCountryCode = _hasIndianCountryCode(cleaned) || _looksLikeIndianMobile(nationalNumber);
        final String formattedNational = '${nationalNumber.substring(0, 5)} ${nationalNumber.substring(5)}';
        return includeCountryCode ? '+91 $formattedNational' : formattedNational;
      }
      return nationalNumber;
    }

    if (cleaned.startsWith('+')) {
      if (cleaned.startsWith('+1') && cleaned.length == 12) {
        return '+1 (${cleaned.substring(2, 5)}) ${cleaned.substring(5, 8)}-${cleaned.substring(8)}';
      }
      return _formatInternational(cleaned);
    }

    if (cleaned.length == 10) {
      return '${cleaned.substring(0, 3)} ${cleaned.substring(3, 6)} ${cleaned.substring(6)}';
    }

    if (cleaned.length > 7) {
      final int splitIndex = cleaned.length - 4;
      return '${cleaned.substring(0, splitIndex)} ${cleaned.substring(splitIndex)}';
    }

    return cleaned;
  }

  static String cleanPhoneNumber(String number) {
    if (number.isEmpty) return number;

    String cleaned = number.replaceAll(RegExp(r'[^\d\+]'), '');

    if (cleaned.startsWith('00') && cleaned.length > 2) {
      cleaned = '+${cleaned.substring(2)}';
    }

    return cleaned;
  }

  static String normalizePhoneNumber(String number) {
    String cleaned = cleanPhoneNumber(number);

    if (cleaned.isEmpty) {
      return cleaned;
    }

    if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    }

    if (cleaned.startsWith('00')) {
      cleaned = cleaned.substring(2);
    }

    if (cleaned.startsWith('91') && cleaned.length > 10) {
      cleaned = cleaned.substring(cleaned.length - 10);
    }

    if (cleaned.startsWith('0') && cleaned.length > 10) {
      cleaned = cleaned.substring(cleaned.length - 10);
    }

    if (cleaned.startsWith('1') && cleaned.length == 11) {
      cleaned = cleaned.substring(1);
    }

    return cleaned;
  }

  static bool arePhoneNumbersEqual(String number1, String number2) {
    final String normalized1 = normalizePhoneNumber(number1);
    final String normalized2 = normalizePhoneNumber(number2);

    if (normalized1.isNotEmpty && normalized2.isNotEmpty && normalized1 == normalized2) {
      return true;
    }

    final String clean1 = cleanPhoneNumber(number1).replaceFirst(RegExp(r'^\+'), '');
    final String clean2 = cleanPhoneNumber(number2).replaceFirst(RegExp(r'^\+'), '');

    if (clean1 == clean2) {
      return true;
    }

    if (normalized1.isNotEmpty && clean2.endsWith(normalized1)) {
      return true;
    }

    if (normalized2.isNotEmpty && clean1.endsWith(normalized2)) {
      return true;
    }

    return false;
  }

  static String getCountryFromNumber(String number) {
    final String cleaned = cleanPhoneNumber(number);
    final String digits = cleaned.startsWith('+') ? cleaned.substring(1) : cleaned;

    if (digits.startsWith('1') && (digits.length == 10 || digits.length == 11)) {
      return 'US/CA';
    } else if (digits.startsWith('44')) {
      return 'UK';
    } else if (digits.startsWith('91')) {
      return 'IN';
    } else if (digits.startsWith('49')) {
      return 'DE';
    } else if (digits.startsWith('33')) {
      return 'FR';
    } else if (digits.startsWith('86')) {
      return 'CN';
    } else if (digits.startsWith('81')) {
      return 'JP';
    } else if (digits.startsWith('82')) {
      return 'KR';
    } else if (digits.startsWith('92')) {
      return 'PK';
    }
    
    return 'Unknown';
  }

  static bool _isLikelyIndianNumber(String cleaned) {
    final String digits = cleaned.replaceAll('+', '');

    if (digits.startsWith('91') && digits.length >= 12) {
      return true;
    }

    if (digits.startsWith('0') && digits.length == 11) {
      return _looksLikeIndianMobile(digits.substring(1));
    }

    if (digits.length == 10) {
      return _looksLikeIndianMobile(digits);
    }

    return cleaned.startsWith('+91');
  }

  static bool _hasIndianCountryCode(String cleaned) {
    return cleaned.startsWith('+91') || cleaned.startsWith('0091') ||
        (cleaned.startsWith('91') && cleaned.length > 10);
  }

  static String _extractIndianNationalNumber(String cleaned) {
    String digits = cleaned.replaceAll('+', '');

    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }

    if (digits.startsWith('91') && digits.length > 10) {
      digits = digits.substring(digits.length - 10);
    }

    if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }

    return digits;
  }

  static String _formatInternational(String cleaned) {
    if (cleaned.length <= 3) {
      return cleaned;
    }

    final StringBuffer buffer = StringBuffer();
    buffer.write(cleaned.substring(0, 3));

    int index = 3;
    while (index < cleaned.length) {
      final int nextIndex = (index + 4 <= cleaned.length) ? index + 4 : cleaned.length;
      buffer.write(' ');
      buffer.write(cleaned.substring(index, nextIndex));
      index = nextIndex;
    }

    return buffer.toString();
  }

  static bool _looksLikeIndianMobile(String digits) {
    if (digits.isEmpty) {
      return false;
    }

    final String leading = digits.substring(0, 1);
    return leading == '6' || leading == '7' || leading == '8' || leading == '9';
  }
}
import 'package:flutter_test/flutter_test.dart';
import 'package:umar_dailer/core/utils/format_utils.dart';

void main() {
  group('PhoneUtils.matchKey', () {
    test('treats +91, trunk 0 and bare formats as one number', () {
      const String key = '9876543210';
      expect(PhoneUtils.matchKey('+91 98765 43210'), key);
      expect(PhoneUtils.matchKey('098765-43210'), key);
      expect(PhoneUtils.matchKey('9876543210'), key);
    });

    test('keeps short codes whole and tells different numbers apart', () {
      expect(PhoneUtils.matchKey('121'), '121');
      expect(PhoneUtils.isSameNumber('121', '198'), isFalse);
      expect(PhoneUtils.isSameNumber('+44 20 7946 0958', '020 7946 0958'), isTrue);
    });
  });

  group('NameUtils', () {
    test('initials use the first and last word', () {
      expect(NameUtils.initials('john ronald doe'), 'JD');
      expect(NameUtils.initials('Asha'), 'A');
      expect(NameUtils.initials('  '), '');
    });

    test('numbers get no initials so the avatar shows a person glyph', () {
      expect(NameUtils.initials('+91 98765 43210'), '');
    });

    test('non-Latin names still get initials', () {
      expect(NameUtils.initials('राम कुमार'), 'रक');
    });

    test('stableHash matches Java String.hashCode, including 32-bit overflow', () {
      expect(NameUtils.stableHash('John'), 2314539);
      expect(NameUtils.stableHash('polygenelubricants'), -2147483648);
      expect(NameUtils.stableHash(''), 0);
    });
  });

  group('TimeUtils.formatClock', () {
    test('shows minutes and seconds, adding hours only when needed', () {
      expect(TimeUtils.formatClock(const Duration(seconds: 7)), '00:07');
      expect(TimeUtils.formatClock(const Duration(minutes: 4, seconds: 9)), '04:09');
      expect(TimeUtils.formatClock(const Duration(hours: 1, minutes: 5, seconds: 2)), '1:05:02');
    });

    test('never shows a negative duration', () {
      expect(TimeUtils.formatClock(const Duration(seconds: -3)), '00:00');
    });
  });
}

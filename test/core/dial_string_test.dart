import 'package:flutter_test/flutter_test.dart';
import 'package:umar_dailer/core/call_service.dart';
import 'package:umar_dailer/core/utils/format_utils.dart';

/// Guards the dial-string rules that decide whether input is dialled as a call,
/// executed as a service code, or treated as an emergency number.
///
/// These are easy to break with a well-meaning "clean up the number" change — an
/// earlier `[^\d+]` filter silently turned `*123#` into `123`.
void main() {
  group('sanitizeDialString', () {
    test('keeps MMI and pause characters', () {
      expect(CallService.sanitizeDialString('*123#'), '*123#');
      expect(CallService.sanitizeDialString('*#06#'), '*#06#');
      expect(CallService.sanitizeDialString('1800123456,,101'), '1800123456,,101');
      expect(CallService.sanitizeDialString('1800123456;101'), '1800123456;101');
    });

    test('strips formatting but keeps the leading plus', () {
      expect(CallService.sanitizeDialString('+91 98765 43210'), '+919876543210');
      expect(CallService.sanitizeDialString('(022) 2758-1234'), '02227581234');
      expect(CallService.sanitizeDialString('  98765-43210  '), '9876543210');
    });

    test('drops letters and stray symbols', () {
      expect(CallService.sanitizeDialString('call 9876543210 now'), '9876543210');
      expect(CallService.sanitizeDialString(''), '');
    });
  });

  group('isMmiCode', () {
    test('recognises service codes', () {
      expect(PhoneUtils.isMmiCode('*#06#'), isTrue); // IMEI
      expect(PhoneUtils.isMmiCode('*123#'), isTrue); // balance enquiry
      expect(PhoneUtils.isMmiCode('##002#'), isTrue); // cancel all forwarding
      expect(PhoneUtils.isMmiCode('*21*9876543210#'), isTrue); // forward all
    });

    test('leaves ordinary numbers alone', () {
      expect(PhoneUtils.isMmiCode('9876543210'), isFalse);
      expect(PhoneUtils.isMmiCode('+919876543210'), isFalse);
      expect(PhoneUtils.isMmiCode('1800-123-4567'), isFalse);
      // Caller-ID prefix followed by a number is a call, not an MMI code.
      expect(PhoneUtils.isMmiCode('#31#9876543210'), isFalse);
    });

    test('is not fooled by fragments', () {
      expect(PhoneUtils.isMmiCode('*'), isFalse);
      expect(PhoneUtils.isMmiCode('#'), isFalse);
      expect(PhoneUtils.isMmiCode('**'), isFalse);
    });

    test('never classifies an emergency number as MMI', () {
      expect(PhoneUtils.isMmiCode('112'), isFalse);
      expect(PhoneUtils.isMmiCode('100'), isFalse);
    });
  });

  group('isEmergencyNumber', () {
    test('matches Indian and international emergency numbers', () {
      for (final String number in <String>['112', '100', '101', '102', '108', '911']) {
        expect(PhoneUtils.isEmergencyNumber(number), isTrue, reason: number);
      }
    });

    test('ignores ordinary numbers that merely start the same way', () {
      expect(PhoneUtils.isEmergencyNumber('1122334455'), isFalse);
      expect(PhoneUtils.isEmergencyNumber('9876543210'), isFalse);
      expect(PhoneUtils.isEmergencyNumber(''), isFalse);
    });
  });
}

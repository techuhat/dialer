import 'package:flutter_test/flutter_test.dart';
import 'package:umar_dailer/core/models/call_log_entry.dart';
import 'package:umar_dailer/core/models/call_stats.dart';

CallLogEntry _call(
  String id,
  String number,
  CallType type,
  DateTime at, {
  int duration = 0,
  String? name,
}) =>
    CallLogEntry(id: id, number: number, type: type, timestamp: at, duration: duration, name: name);

void main() {
  group('CallLogEntry.fromNative', () {
    test('maps the system call log row', () {
      final CallLogEntry entry = CallLogEntry.fromNative(<String, Object?>{
        'id': '42',
        'number': '+919876543210',
        'name': 'Ravi Kumar',
        'nameSource': 'network',
        'type': 'missed',
        'date': 1700000000000,
        'duration': 0,
        'isRead': false,
        'simSlot': 1,
        'location': 'India',
        'hd': true,
      });

      expect(entry.id, '42');
      expect(entry.type, CallType.missed);
      expect(entry.isNetworkName, isTrue);
      expect(entry.isUnreadMissed, isTrue);
      expect(entry.simSlot, 1);
      expect(entry.timestamp, DateTime.fromMillisecondsSinceEpoch(1700000000000));
      expect(entry.isHd, isTrue);
    });

    test('falls back to the number and safe defaults', () {
      final CallLogEntry entry = CallLogEntry.fromNative(<String, Object?>{'id': '1', 'number': '121', 'type': 'weird'});

      expect(entry.displayName, '121');
      expect(entry.type, CallType.incoming);
      expect(entry.isRead, isTrue);
      expect(entry.isNetworkName, isFalse);
    });

    test('survives the warm snapshot round trip', () {
      final CallLogEntry original = _call('7', '9876543210', CallType.rejected, DateTime(2026, 11, 2, 9, 30), name: 'Asha');
      final CallLogEntry copy = CallLogEntry.fromMap(original.toMap());

      expect(copy.type, CallType.rejected);
      expect(copy.timestamp, original.timestamp);
      expect(copy.name, 'Asha');
    });
  });

  group('CallStats', () {
    final DateTime now = DateTime(2026, 11, 26, 18);

    test('counts types, talk time and the busiest caller', () {
      final CallStats stats = CallStats.from(
        <CallLogEntry>[
          _call('1', '+919876543210', CallType.incoming, now.subtract(const Duration(hours: 1)), duration: 600, name: 'Asha'),
          _call('2', '9876543210', CallType.outgoing, now.subtract(const Duration(days: 1)), duration: 300, name: 'Asha'),
          _call('3', '9123456780', CallType.missed, now.subtract(const Duration(days: 2))),
          _call('4', '9123456780', CallType.blocked, now.subtract(const Duration(days: 3))),
          _call('5', '9000000000', CallType.incoming, now.subtract(const Duration(days: 40)), duration: 9999),
        ],
        since: now.subtract(const Duration(days: 7)),
        now: now,
      );

      expect(stats.total, 4);
      expect(stats.incoming, 1);
      expect(stats.outgoing, 1);
      expect(stats.missed, 1);
      expect(stats.declined, 1);
      expect(stats.talkTime, const Duration(seconds: 900));
      expect(stats.answeredRate, 50);
      expect(stats.topCallers.first.name, 'Asha');
      expect(stats.topCallers.first.calls, 2);
      expect(stats.longest?.id, '1');
    });

    test('places calls on the right day, today last', () {
      final CallStats stats = CallStats.from(
        <CallLogEntry>[
          _call('1', '1', CallType.incoming, now),
          _call('2', '1', CallType.incoming, now.subtract(const Duration(hours: 2))),
          _call('3', '1', CallType.outgoing, now.subtract(const Duration(days: 6))),
        ],
        since: now.subtract(const Duration(days: 30)),
        now: now,
      );

      expect(stats.perDay, <int>[1, 0, 0, 0, 0, 0, 2]);
    });

    test('an empty log is all zeros, never a division by zero', () {
      final CallStats stats = CallStats.from(const <CallLogEntry>[], since: now, now: now);

      expect(stats.total, 0);
      expect(stats.averageCall, Duration.zero);
      expect(stats.answeredRate, 100);
      expect(stats.longest, isNull);
    });
  });
}

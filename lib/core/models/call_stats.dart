import '../utils/format_utils.dart';
import 'call_log_entry.dart';

class TopCaller {
  const TopCaller({required this.number, required this.name, required this.calls, required this.talkTime});

  final String number;
  final String name;
  final int calls;
  final Duration talkTime;
}

/// Call log figures for one period, computed from [CallLogEntry] rows.
class CallStats {
  const CallStats({
    required this.total,
    required this.incoming,
    required this.outgoing,
    required this.missed,
    required this.declined,
    required this.talkTime,
    required this.perDay,
    required this.topCallers,
    this.longest,
  });

  factory CallStats.from(Iterable<CallLogEntry> entries, {required DateTime since, required DateTime now, int days = 7}) {
    int incoming = 0, outgoing = 0, missed = 0, declined = 0, total = 0, seconds = 0;
    CallLogEntry? longest;
    final Map<String, _Tally> byCaller = <String, _Tally>{};
    final DateTime today = DateTime(now.year, now.month, now.day);
    final List<int> perDay = List<int>.filled(days, 0);

    for (final CallLogEntry entry in entries) {
      if (entry.timestamp.isBefore(since)) continue;
      total++;
      seconds += entry.duration;
      switch (entry.type) {
        case CallType.incoming:
          incoming++;
        case CallType.outgoing:
          outgoing++;
        case CallType.missed:
        case CallType.voicemail:
          missed++;
        case CallType.rejected:
        case CallType.blocked:
          declined++;
      }
      if (longest == null || entry.duration > longest.duration) longest = entry;
      if (entry.number.isNotEmpty) {
        byCaller.putIfAbsent(PhoneUtils.matchKey(entry.number), () => _Tally(entry)).add(entry);
      }
      final DateTime day = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      final int daysAgo = today.difference(day).inDays;
      if (daysAgo >= 0 && daysAgo < days) perDay[days - 1 - daysAgo]++;
    }

    final List<TopCaller> top = byCaller.values.map((_Tally t) => t.toTopCaller()).toList()
      ..sort((TopCaller a, TopCaller b) {
        final int byTime = b.talkTime.compareTo(a.talkTime);
        return byTime != 0 ? byTime : b.calls.compareTo(a.calls);
      });

    return CallStats(
      total: total,
      incoming: incoming,
      outgoing: outgoing,
      missed: missed,
      declined: declined,
      talkTime: Duration(seconds: seconds),
      perDay: perDay,
      topCallers: top.take(5).toList(growable: false),
      longest: longest != null && longest.duration > 0 ? longest : null,
    );
  }

  final int total;
  final int incoming;
  final int outgoing;
  final int missed;
  final int declined;
  final Duration talkTime;

  /// Calls per day, oldest first; the last element is today.
  final List<int> perDay;
  final List<TopCaller> topCallers;
  final CallLogEntry? longest;

  int get answeredRate => incoming + missed == 0 ? 100 : (incoming * 100 / (incoming + missed)).round();

  Duration get averageCall {
    final int connected = incoming + outgoing;
    return connected == 0 ? Duration.zero : Duration(seconds: talkTime.inSeconds ~/ connected);
  }
}

class _Tally {
  _Tally(this.latest);

  final CallLogEntry latest;
  int calls = 0;
  int seconds = 0;

  void add(CallLogEntry entry) {
    calls++;
    seconds += entry.duration;
  }

  TopCaller toTopCaller() =>
      TopCaller(number: latest.number, name: latest.displayName, calls: calls, talkTime: Duration(seconds: seconds));
}

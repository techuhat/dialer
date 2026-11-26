import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:umar_dailer/core/call_service.dart';
import 'package:umar_dailer/core/models/call_log_entry.dart';
import 'package:umar_dailer/core/services/call_log_service.dart';
import 'package:umar_dailer/core/services/warm_call_log_store.dart';
import 'package:umar_dailer/core/utils/format_utils.dart';

/// The system call log as CallHistory.page serves it: newest first, keyset pages, number filter.
class _FakeLog {
  _FakeLog(int count, {DateTime? newest}) {
    final DateTime start = newest ?? DateTime(2026, 11, 26, 20);
    for (int i = 0; i < count; i++) {
      rows.add(<String, Object?>{
        'id': '${count - i}',
        'number': i % 3 == 0 ? '+919876543210' : '98000${i.toString().padLeft(5, '0')}',
        'type': 'incoming',
        'date': start.subtract(Duration(hours: i)).millisecondsSinceEpoch,
      });
    }
  }

  final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
  final List<Map<Object?, Object?>> requests = <Map<Object?, Object?>>[];

  void addNewest(String id, String number) => rows.insert(0, <String, Object?>{
        'id': id,
        'number': number,
        'type': 'missed',
        'date': (rows.first['date']! as int) + 60000,
      });

  Map<String, Object?> page(Map<Object?, Object?> args) {
    requests.add(args);
    final int limit = args['limit']! as int;
    final int? beforeDate = args['beforeDate'] as int?;
    final int? beforeId = args['beforeId'] as int?;
    final String? number = args['number'] as String?;
    final Iterable<Map<String, Object?>> older = rows.where((Map<String, Object?> row) {
      if (beforeDate == null) return true;
      final int date = row['date']! as int;
      return date < beforeDate || (date == beforeDate && int.parse(row['id']! as String) < beforeId!);
    });
    final List<Map<String, Object?>> matching = older
        .where((Map<String, Object?> row) => number == null || PhoneUtils.isSameNumber(row['number']! as String, number))
        .toList();
    return <String, Object?>{'rows': matching.take(limit).toList(), 'more': matching.length > limit};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeLog log;

  void serve(_FakeLog fake) {
    log = fake;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      CallService.channel,
      (MethodCall call) async => call.method == 'getCallLog' ? log.page(call.arguments as Map<Object?, Object?>) : null,
    );
  }

  setUp(() => CallLogService.resetForTest());

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(CallService.channel, null);
  });

  test('loads the newest page first and says older calls are left', () async {
    serve(_FakeLog(250));
    await CallLogService.refresh();

    expect(CallLogService.entries, hasLength(CallLogService.pageSize));
    expect(CallLogService.entries.first.id, '250');
    expect(CallLogService.hasMore, isTrue);
  });

  test('loadMore appends older pages until the log runs out', () async {
    serve(_FakeLog(250));
    await CallLogService.refresh();

    expect(await CallLogService.loadMore(), isTrue);
    expect(CallLogService.entries, hasLength(200));
    expect(await CallLogService.loadMore(), isTrue);
    expect(CallLogService.entries, hasLength(250));
    expect(CallLogService.hasMore, isFalse);
    expect(await CallLogService.loadMore(), isFalse);
    expect(CallLogService.entries.map((CallLogEntry e) => e.id).toSet(), hasLength(250));
  });

  test('two loadMore calls at once fetch one page, not two copies of it', () async {
    serve(_FakeLog(250));
    await CallLogService.refresh();

    await Future.wait(<Future<bool>>[CallLogService.loadMore(), CallLogService.loadMore()]);
    expect(CallLogService.entries, hasLength(200));
    expect(CallLogService.entries.map((CallLogEntry e) => e.id).toSet(), hasLength(200));
  });

  test('a refresh re-reads everything loaded, so a new call shows at the top', () async {
    serve(_FakeLog(250));
    await CallLogService.refresh();
    await CallLogService.loadMore();

    log.addNewest('999', '9123456780');
    await CallLogService.refresh();

    expect(CallLogService.entries.first.id, '999');
    expect(CallLogService.entries, hasLength(200));
    expect(log.requests.last['limit'], 200);
    expect(CallLogService.hasMore, isTrue);
  });

  test('loadSince pages back far enough to cover a period', () async {
    serve(_FakeLog(250, newest: DateTime(2026, 11, 26, 20)));
    await CallLogService.refresh();

    await CallLogService.loadSince(DateTime(2026, 11, 26, 20).subtract(const Duration(hours: 150)));
    expect(CallLogService.entries.last.timestamp.isBefore(DateTime(2026, 11, 26, 20).subtract(const Duration(hours: 150))), isTrue);
    expect(CallLogService.entries.length, lessThan(250));
  });

  test('the warm snapshot written at the end of a session is read at the next start', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    serve(_FakeLog(30));
    await CallLogService.refresh();
    await CallLogService.saveWarmSnapshot(WarmCallLogStore.write);

    CallLogService.resetForTest();
    await CallLogService.loadWarmSnapshot(WarmCallLogStore.read);
    expect(CallLogService.entries, hasLength(30));
    expect(CallLogService.entries.first.id, '30');
  });

  test("historyFor reads one number's calls, matching every way it was written", () async {
    serve(_FakeLog(250));
    final List<CallLogEntry>? calls = await CallLogService.historyFor('09876543210');

    expect(calls, isNotNull);
    expect(calls, hasLength(84));
    expect(calls!.every((CallLogEntry e) => e.number == '+919876543210'), isTrue);
    expect(log.requests.single['number'], '09876543210');
  });
}

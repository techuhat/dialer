import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../call_service.dart';
import '../models/call_log_entry.dart';
import '../models/call_stats.dart';
import '../models/contact.dart';
import '../utils/format_utils.dart';
import 'contacts_service.dart';
import 'platform_channel.dart';
import 'warm_call_log_store.dart';

/// Recents, read from the system call log (Telecom logs every call, even when this app is closed)
/// a page at a time, newest first. Names are refreshed from contacts; a warm snapshot gives the
/// first frame something to show.
class CallLogService {
  const CallLogService._();

  /// Calls read per page.
  static const int pageSize = 100;

  /// The most calls of one number the details page reads, more than a call log keeps.
  static const int _historyLimit = 1000;
  static const int _snapshotSize = 100;

  static List<CallLogEntry> _entries = const <CallLogEntry>[];
  static bool _hasMore = true;
  static final StreamController<List<CallLogEntry>> _controller =
      StreamController<List<CallLogEntry>>.broadcast();
  static Future<void>? _refreshing;
  static Future<bool>? _loadingMore;

  /// Reads run one after another, so a page never lands on top of a refresh it raced.
  static Future<void> _queue = Future<void>.value();
  static StreamSubscription<List<Contact>>? _contactChanges;
  static bool _loaded = false;
  static Timer? _snapshotTimer;

  /// The loaded calls, newest first.
  static List<CallLogEntry> get entries => _entries;

  /// Older calls are left to load after [entries].
  static bool get hasMore => _hasMore;

  static int get unreadMissedCount => _entries.where((CallLogEntry e) => e.isUnreadMissed).length;

  /// Current entries first, then every change.
  static Stream<List<CallLogEntry>> watch() async* {
    if (!_loaded) unawaited(refresh());
    yield _entries;
    yield* _controller.stream;
  }

  /// Every change to the loaded calls, without the current ones first.
  static Stream<List<CallLogEntry>> get changes => _controller.stream;

  static Future<void> refresh() => _refreshing ??= _serial(_reload).whenComplete(() => _refreshing = null);

  /// Re-reads the newest calls, as many as are loaded (a page at least), so a change anywhere in
  /// them shows.
  static Future<void> _reload() async {
    final _Page? page = await _fetch(limit: math.max(pageSize, _entries.length));
    if (page == null) return;
    if (!_loaded) {
      unawaited(_dropLegacyDatabase());
      _contactChanges ??= ContactsService.contactsStream.listen((_) => refreshNames());
    }
    _loaded = true;
    _hasMore = page.more;
    _publish(page.entries);
  }

  /// Appends the next page of older calls; false when none are left or the log can't be read.
  static Future<bool> loadMore() => _loadingMore ??= _serial(_appendPage).whenComplete(() => _loadingMore = null);

  static Future<bool> _appendPage() async {
    if (!_loaded) {
      await _reload();
      return _loaded && _entries.isNotEmpty;
    }
    if (!_hasMore) return false;
    final _Page? page = await _fetch(limit: pageSize, before: _entries.isEmpty ? null : _entries.last);
    if (page == null) return false;
    _hasMore = page.more;
    if (page.entries.isEmpty) return false;
    _publish(<CallLogEntry>[..._entries, ...page.entries]);
    return true;
  }

  /// Loads pages until every call since [since] is in, e.g. for statistics over a period.
  static Future<void> loadSince(DateTime since) async {
    if (!_loaded) await refresh();
    while (_hasMore && (_entries.isEmpty || !_entries.last.timestamp.isBefore(since))) {
      if (!await loadMore()) return;
    }
  }

  /// Every logged call with [number], newest first, matched natively by the last ten digits so
  /// `+91…` and `0…` forms count as one number. Null when the log can't be read.
  static Future<List<CallLogEntry>?> historyFor(String number) async {
    if (number.isEmpty) return const <CallLogEntry>[];
    return (await _fetch(limit: _historyLimit, number: number))?.entries;
  }

  static Future<_Page?> _fetch({required int limit, CallLogEntry? before, String? number}) async {
    final Map<Object?, Object?>? reply = await invokeSafe<Map<Object?, Object?>>(
      CallService.channel,
      'getCallLog',
      <String, Object?>{
        'limit': limit,
        if (before != null) 'beforeDate': before.timestamp.millisecondsSinceEpoch,
        if (before != null) 'beforeId': int.tryParse(before.id),
        'number': ?number,
      },
    );
    if (reply == null) return null;
    final Object? rows = reply['rows'];
    return _Page(
      <CallLogEntry>[
        if (rows is List<Object?>)
          for (final Object? row in rows)
            if (row is Map<Object?, Object?>) _withContactName(CallLogEntry.fromNative(row)),
      ],
      more: reply['more'] == true,
    );
  }

  static Future<T> _serial<T>(Future<T> Function() job) {
    final Future<T> result = _queue.then((_) => job());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Names from current contacts win over the log's cached name, which goes stale on renames.
  static CallLogEntry _withContactName(CallLogEntry entry) {
    final Contact? contact = ContactsService.cachedContactFor(entry.number);
    if (contact == null) return entry;
    String? label;
    for (final PhoneNumber phone in contact.phones) {
      if (PhoneUtils.isSameNumber(phone.number, entry.number)) label = phone.label;
    }
    return entry.copyWith(name: contact.displayName, isNetworkName: false, label: label ?? entry.label);
  }

  /// Re-applies contact names after the contact list changes.
  static void refreshNames() {
    if (_entries.isNotEmpty) _publish(_entries.map(_withContactName).toList());
  }

  static Future<bool> delete(Iterable<String> ids) async {
    final Set<String> doomed = ids.toSet();
    if (doomed.isEmpty) return true;
    final int? removed =
        await invokeSafe<int>(CallService.channel, 'deleteCallLog', <String, Object?>{'ids': doomed.toList()});
    if (removed == null || removed == 0) return false;
    _publish(_entries.where((CallLogEntry e) => !doomed.contains(e.id)).toList());
    return true;
  }

  static Future<bool> clearAll() async {
    final int? removed = await invokeSafe<int>(CallService.channel, 'clearCallLog');
    if (removed == null) return false;
    _hasMore = false;
    _publish(const <CallLogEntry>[]);
    return true;
  }

  /// Marks missed calls seen and clears the missed-call notification.
  static Future<void> markMissedRead() async {
    if (unreadMissedCount == 0) return;
    await invokeSafe<void>(CallService.channel, 'markMissedRead');
    _publish(_entries.map((CallLogEntry e) => e.isUnreadMissed ? e.copyWith(isRead: true) : e).toList());
  }

  static CallStats statistics({required Duration period, DateTime? now}) {
    final DateTime at = now ?? DateTime.now();
    return CallStats.from(_entries, since: at.subtract(period), now: at);
  }

  static Future<void> loadWarmSnapshot(Future<Map<String, dynamic>> Function() readStore) async {
    if (_loaded) return;
    try {
      final Object? raw = (await readStore())['snapshot'];
      if (raw is! String || raw.isEmpty) return;
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List || _loaded) return;
      _entries = decoded.whereType<Map<String, dynamic>>().map(CallLogEntry.fromMap).toList(growable: false);
    } catch (error) {
      debugPrint('Recents snapshot unreadable: $error');
    }
  }

  static Future<void> saveWarmSnapshot(Future<void> Function(Map<String, dynamic> data) writeStore) async {
    if (_entries.isEmpty) return;
    final String raw = jsonEncode(_entries.take(_snapshotSize).map((CallLogEntry e) => e.toMap()).toList());
    await writeStore(<String, dynamic>{'snapshot': raw});
  }

  static void _publish(List<CallLogEntry> entries) {
    _entries = List<CallLogEntry>.unmodifiable(entries);
    if (!_controller.isClosed) _controller.add(_entries);
    _snapshotTimer?.cancel();
    _snapshotTimer = Timer(const Duration(seconds: 1), () => saveWarmSnapshot(WarmCallLogStore.write));
  }

  /// Earlier versions kept their own copy of the history; the system log replaces it.
  static Future<void> _dropLegacyDatabase() async {
    try {
      await deleteDatabase(p.join(await getDatabasesPath(), 'call_logs.db'));
    } catch (_) {
      // Already gone, or the database plugin is unavailable (tests).
    }
  }

  @visibleForTesting
  static void setEntriesForTest(List<CallLogEntry> entries, {bool hasMore = false}) {
    _loaded = true;
    _hasMore = hasMore;
    _entries = List<CallLogEntry>.unmodifiable(entries);
  }

  @visibleForTesting
  static void resetForTest() {
    _loaded = false;
    _hasMore = true;
    _entries = const <CallLogEntry>[];
    _refreshing = null;
    _loadingMore = null;
    _queue = Future<void>.value();
  }
}

class _Page {
  const _Page(this.entries, {required this.more});

  final List<CallLogEntry> entries;
  final bool more;
}

import 'dart:async';
import 'dart:convert';

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

/// Recents, read from the system call log (Telecom logs every call, even when this app is closed).
/// Names are refreshed from contacts; a warm snapshot gives the first frame something to show.
class CallLogService {
  const CallLogService._();

  static const int _snapshotSize = 100;

  static List<CallLogEntry> _entries = const <CallLogEntry>[];
  static final StreamController<List<CallLogEntry>> _controller =
      StreamController<List<CallLogEntry>>.broadcast();
  static Future<void>? _inFlight;
  static StreamSubscription<List<Contact>>? _contactChanges;
  static bool _loaded = false;
  static Timer? _snapshotTimer;

  static List<CallLogEntry> get entries => _entries;

  static int get unreadMissedCount => _entries.where((CallLogEntry e) => e.isUnreadMissed).length;

  /// Current entries first, then every change.
  static Stream<List<CallLogEntry>> watch() async* {
    if (!_loaded) unawaited(refresh());
    yield _entries;
    yield* _controller.stream;
  }

  static Future<void> refresh() => _inFlight ??= _load().whenComplete(() => _inFlight = null);

  static Future<void> _load() async {
    final List<Object?>? rows = await invokeSafe<List<Object?>>(CallService.channel, 'getCallLog');
    if (rows == null) return;
    if (!_loaded) {
      unawaited(_dropLegacyDatabase());
      _contactChanges ??= ContactsService.contactsStream.listen((_) => refreshNames());
    }
    _loaded = true;
    _publish(rows.whereType<Map<Object?, Object?>>().map(CallLogEntry.fromNative).map(_withContactName).toList());
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
  static void setEntriesForTest(List<CallLogEntry> entries) {
    _loaded = true;
    _entries = List<CallLogEntry>.unmodifiable(entries);
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/call_note.dart';
import '../utils/format_utils.dart';

class CallNotesService {
  CallNotesService._();

  static SharedPreferences? _prefs;
  static const String _storageKey = 'call_notes_v1';
  static List<CallNote> _cache = <CallNote>[];

  static Future<void> init() async {
    if (_prefs != null) {
      return;
    }
    _prefs = await SharedPreferences.getInstance();
    await _hydrateCache();
  }

  static Future<List<CallNote>> getAllNotes() async {
    await init();
    return List<CallNote>.unmodifiable(_cache);
  }

  static Future<List<CallNote>> getNotesForNumber(String number) async {
    await init();
    final String normalized = _normalize(number);
    return _cache
        .where((CallNote note) => _normalize(note.number) == normalized)
        .toList(growable: false);
  }

  static Future<CallNote> addNote({
    required String number,
    required String content,
  }) async {
    await init();
    final String normalized = _normalize(number);
    final CallNote note = CallNote(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      number: number,
      normalizedNumber: normalized,
      content: content,
      createdAt: DateTime.now(),
    );
    _cache = <CallNote>[note, ..._cache];
    await _persist();
    return note;
  }

  static Future<void> deleteNote(String id) async {
    await init();
    _cache = _cache.where((CallNote n) => n.id != id).toList();
    await _persist();
  }

  static Future<List<CallNote>> search(String query) async {
    await init();
    if (query.trim().isEmpty) {
      return List<CallNote>.unmodifiable(_cache);
    }
    final String lower = query.toLowerCase();
    return _cache
        .where(
          (CallNote note) =>
              note.content.toLowerCase().contains(lower) ||
              note.number.toLowerCase().contains(lower),
        )
        .toList(growable: false);
  }

  static Future<void> _hydrateCache() async {
    final String raw = _prefs?.getString(_storageKey) ?? '[]';
    try {
      final List<dynamic> data = jsonDecode(raw) as List<dynamic>;
      _cache = data
          .map((dynamic e) => CallNote.fromMap(e as Map<String, dynamic>))
          .toList();
      _cache.sort((CallNote a, CallNote b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      _cache = <CallNote>[];
    }
  }

  static Future<void> _persist() async {
    _cache.sort((CallNote a, CallNote b) => b.createdAt.compareTo(a.createdAt));
    await _prefs?.setString(
      _storageKey,
      jsonEncode(_cache.map((CallNote note) => note.toMap()).toList()),
    );
  }

  static String _normalize(String value) => PhoneUtils.normalizePhoneNumber(value);
}

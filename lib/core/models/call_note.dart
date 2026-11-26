import 'dart:convert';

class CallNote {
  const CallNote({
    required this.id,
    required this.number,
    required this.normalizedNumber,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String number;
  final String normalizedNumber;
  final String content;
  final DateTime createdAt;

  factory CallNote.fromMap(Map<String, dynamic> map) {
    return CallNote(
      id: map['id'] as String? ?? '',
      number: map['number'] as String? ?? '',
      normalizedNumber: map['normalizedNumber'] as String? ?? '',
      content: map['content'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'number': number,
      'normalizedNumber': normalizedNumber,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static List<CallNote> decodeList(String raw) {
    if (raw.isEmpty) {
      return <CallNote>[];
    }
    try {
      final List<dynamic> data = jsonDecode(raw) as List<dynamic>;
      return data
          .map((dynamic e) => CallNote.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Return empty list on malformed JSON instead of crashing
      return <CallNote>[];
    }
  }

  static String encodeList(List<CallNote> notes) {
    final List<Map<String, dynamic>> data = notes.map((CallNote note) => note.toMap()).toList();
    return jsonEncode(data);
  }
}

import 'package:flutter/foundation.dart';

import '../utils/format_utils.dart';

enum CallType { incoming, outgoing, missed, rejected, blocked, voicemail }

/// One row of the system call log.
@immutable
class CallLogEntry {
  const CallLogEntry({
    required this.id,
    required this.number,
    required this.type,
    required this.timestamp,
    this.name,
    this.isNetworkName = false,
    this.duration = 0,
    this.isRead = true,
    this.simSlot,
    this.label,
    this.location,
    this.isHd = false,
    this.isWifi = false,
  });

  factory CallLogEntry.fromNative(Map<Object?, Object?> map) => CallLogEntry(
        id: map['id'] as String? ?? '',
        number: map['number'] as String? ?? '',
        name: (map['name'] as String?)?.trim(),
        isNetworkName: map['nameSource'] == 'network',
        type: CallType.values.asNameMap()[map['type']] ?? CallType.incoming,
        timestamp: DateTime.fromMillisecondsSinceEpoch((map['date'] as num?)?.toInt() ?? 0),
        duration: (map['duration'] as num?)?.toInt() ?? 0,
        isRead: map['isRead'] != false,
        simSlot: (map['simSlot'] as num?)?.toInt(),
        label: map['label'] as String?,
        location: map['location'] as String?,
        isHd: map['hd'] == true,
        isWifi: map['wifi'] == true,
      );

  /// Warm snapshot format: the native map with `date` kept as epoch millis.
  factory CallLogEntry.fromMap(Map<String, dynamic> map) => CallLogEntry.fromNative(map);

  final String id;
  final String number;
  final String? name;

  /// The name came from the network (CNAP), not from contacts.
  final bool isNetworkName;
  final CallType type;
  final DateTime timestamp;

  /// Talk time in seconds.
  final int duration;
  final bool isRead;
  final int? simSlot;

  /// The contact's label for this number, e.g. "Mobile".
  final String? label;

  /// Network-derived place for unsaved numbers, e.g. "Maharashtra, India".
  final String? location;
  final bool isHd;
  final bool isWifi;

  String get displayName {
    final String? trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return number.isEmpty ? 'Unknown' : PhoneUtils.formatPhoneNumber(number);
  }

  bool get isUnreadMissed => type == CallType.missed && !isRead;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'number': number,
        'name': name,
        'nameSource': isNetworkName ? 'network' : null,
        'type': type.name,
        'date': timestamp.millisecondsSinceEpoch,
        'duration': duration,
        'isRead': isRead,
        'simSlot': simSlot,
        'label': label,
        'location': location,
        'hd': isHd,
        'wifi': isWifi,
      };

  CallLogEntry copyWith({String? name, bool? isNetworkName, String? label, bool? isRead}) => CallLogEntry(
        id: id,
        number: number,
        name: name ?? this.name,
        isNetworkName: isNetworkName ?? this.isNetworkName,
        type: type,
        timestamp: timestamp,
        duration: duration,
        isRead: isRead ?? this.isRead,
        simSlot: simSlot,
        label: label ?? this.label,
        location: location,
        isHd: isHd,
        isWifi: isWifi,
      );

  @override
  bool operator ==(Object other) =>
      other is CallLogEntry &&
      other.id == id &&
      other.name == name &&
      other.isRead == isRead &&
      other.isNetworkName == isNetworkName &&
      other.label == label;

  @override
  int get hashCode => Object.hash(id, name, isRead, isNetworkName, label);
}

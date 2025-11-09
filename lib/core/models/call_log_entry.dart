class CallLogEntry {
  final String id;
  final String number;
  final String? name;
  final CallType type;
  final DateTime timestamp;
  final int duration; // in seconds
  final bool isRead;

  const CallLogEntry({
    required this.id,
    required this.number,
    this.name,
    required this.type,
    required this.timestamp,
    required this.duration,
    this.isRead = true,
  });

  String get displayName => name ?? number;
  
  String get formattedDuration {
    if (duration == 0) return '0s';
    
    final int hours = duration ~/ 3600;
    final int minutes = (duration % 3600) ~/ 60;
    final int seconds = duration % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'number': number,
      'name': name,
      'type': type.index,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'duration': duration,
      'isRead': isRead ? 1 : 0,
    };
  }

  factory CallLogEntry.fromMap(Map<String, dynamic> map) {
    return CallLogEntry(
      id: map['id'] ?? '',
      number: map['number'] ?? '',
      name: map['name'],
      type: CallType.values[map['type'] ?? 0],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      duration: map['duration'] ?? 0,
      isRead: (map['isRead'] ?? 1) == 1,
    );
  }

  CallLogEntry copyWith({
    String? id,
    String? number,
    String? name,
    CallType? type,
    DateTime? timestamp,
    int? duration,
    bool? isRead,
  }) {
    return CallLogEntry(
      id: id ?? this.id,
      number: number ?? this.number,
      name: name ?? this.name,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      isRead: isRead ?? this.isRead,
    );
  }
}

enum CallType {
  incoming,
  outgoing,
  missed,
}
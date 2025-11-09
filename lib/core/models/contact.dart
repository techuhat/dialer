class Contact {
  final String id;
  final String name;
  final List<PhoneNumber> phones;
  final List<Email> emails;
  final String? photoUrl;
  final bool isFavorite;

  const Contact({
    required this.id,
    required this.name,
    required this.phones,
    this.emails = const [],
    this.photoUrl,
    this.isFavorite = false,
  });

  String get displayName => name.trim().isEmpty ? 'Unknown' : name;
  
  String get initials {
    final List<String> chunks = displayName.trim().split(RegExp(r'\s+'));
    if (chunks.length == 1) {
      return chunks.first.substring(0, 1).toUpperCase();
    }
    return (chunks.first.substring(0, 1) + chunks.last.substring(0, 1)).toUpperCase();
  }

  PhoneNumber? get primaryPhone => phones.isNotEmpty ? phones.first : null;
  String get primaryPhoneNumber => primaryPhone?.number ?? '';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phones': phones.map((e) => e.toMap()).toList(),
      'emails': emails.map((e) => e.toMap()).toList(),
      'photoUrl': photoUrl,
      'isFavorite': isFavorite ? 1 : 0,
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phones: (map['phones'] as List<dynamic>?)
          ?.map((e) => PhoneNumber.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      emails: (map['emails'] as List<dynamic>?)
          ?.map((e) => Email.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      photoUrl: map['photoUrl'],
      isFavorite: (map['isFavorite'] ?? 0) == 1,
    );
  }

  Contact copyWith({
    String? id,
    String? name,
    List<PhoneNumber>? phones,
    List<Email>? emails,
    String? photoUrl,
    bool? isFavorite,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      phones: phones ?? this.phones,
      emails: emails ?? this.emails,
      photoUrl: photoUrl ?? this.photoUrl,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class PhoneNumber {
  final String number;
  final String label;

  const PhoneNumber({
    required this.number,
    required this.label,
  });

  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'label': label,
    };
  }

  factory PhoneNumber.fromMap(Map<String, dynamic> map) {
    return PhoneNumber(
      number: map['number'] ?? '',
      label: map['label'] ?? 'Mobile',
    );
  }
}

class Email {
  final String address;
  final String label;

  const Email({
    required this.address,
    required this.label,
  });

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'label': label,
    };
  }

  factory Email.fromMap(Map<String, dynamic> map) {
    return Email(
      address: map['address'] ?? '',
      label: map['label'] ?? 'Personal',
    );
  }
}
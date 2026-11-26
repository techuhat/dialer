import 'dart:convert';
import 'dart:typed_data';

import '../utils/format_utils.dart';

class Contact {
  final String id;
  final String name;
  final List<PhoneNumber> phones;
  final List<Email> emails;
  final Uint8List? photoBytes;
  final Uint8List? thumbnailBytes;
  final bool isFavorite;

  const Contact({
    required this.id,
    required this.name,
    required this.phones,
    this.emails = const [],
    this.photoBytes,
    this.thumbnailBytes,
    this.isFavorite = false,
  });

  /// Best available image: full-res photo first, thumbnail as fallback.
  Uint8List? get bestPhoto => photoBytes ?? thumbnailBytes;
  
  /// Returns true if full-resolution photo is available (not just thumbnail).
  bool get hasFullPhoto => photoBytes != null;

  String get displayName => name.trim().isEmpty ? 'Unknown' : name;
  
  String get initials => NameUtils.initials(displayName);

  PhoneNumber? get primaryPhone => phones.isNotEmpty ? phones.first : null;
  String get primaryPhoneNumber => primaryPhone?.number ?? '';

  static final RegExp _nonDigit = RegExp(r'\D');

  /// Search match: the name contains [query], or a number contains its digits. [query] is
  /// expected trimmed and in lower case.
  bool matches(String query) {
    if (query.isEmpty || displayName.toLowerCase().contains(query)) return true;
    final String digits = query.replaceAll(_nonDigit, '');
    return digits.isNotEmpty && phones.any((PhoneNumber phone) => phone.number.replaceAll(_nonDigit, '').contains(digits));
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phones': phones.map((e) => e.toMap()).toList(),
      'emails': emails.map((e) => e.toMap()).toList(),
      'photoBytes': photoBytes != null ? base64Encode(photoBytes!) : null,
      'thumbnailBytes': thumbnailBytes != null ? base64Encode(thumbnailBytes!) : null,
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
      photoBytes: map['photoBytes'] != null
          ? base64Decode(map['photoBytes'] as String)
          : null,
      thumbnailBytes: map['thumbnailBytes'] != null
          ? base64Decode(map['thumbnailBytes'] as String)
          : null,
      isFavorite: (map['isFavorite'] ?? 0) == 1,
    );
  }

  Contact copyWith({
    String? id,
    String? name,
    List<PhoneNumber>? phones,
    List<Email>? emails,
    Uint8List? photoBytes,
    Uint8List? thumbnailBytes,
    bool? isFavorite,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      phones: phones ?? this.phones,
      emails: emails ?? this.emails,
      photoBytes: photoBytes ?? this.photoBytes,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
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

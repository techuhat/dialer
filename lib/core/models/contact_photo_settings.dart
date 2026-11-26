/// Per-contact photo display settings for call screens.
///
/// Controls how a contact's photo appears as the backdrop during calls —
/// overlay opacity, rotation angle, and fit mode.
class PhotoFitMode {
  static const String cover = 'cover';
  static const String contain = 'contain';
  static const String fill = 'fill';
  static const String fitWidth = 'fitWidth';
  static const String fitHeight = 'fitHeight';

  static const List<String> all = <String>[
    cover,
    contain,
    fill,
    fitWidth,
    fitHeight,
  ];

  static String label(String mode) {
    switch (mode) {
      case cover:
        return 'Cover';
      case contain:
        return 'Contain';
      case fill:
        return 'Fill';
      case fitWidth:
        return 'Width';
      case fitHeight:
        return 'Height';
      default:
        return 'Cover';
    }
  }
}

class ContactPhotoSettings {
  /// Maps to [Contact.id].
  final String contactId;

  /// Dark overlay opacity on the call-screen photo backdrop (0.0 = fully
  /// visible, 1.0 = fully dark).  Default 0.35.
  final double overlayOpacity;

  /// Rotation in degrees.  Only 0 / 90 / 180 / 270 are supported.
  final double rotation;

  /// One of [PhotoFitMode] constants.
  final String fitMode;

  const ContactPhotoSettings({
    required this.contactId,
    this.overlayOpacity = 0.35,
    this.rotation = 0,
    this.fitMode = PhotoFitMode.cover,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'contactId': contactId,
      'overlayOpacity': overlayOpacity,
      'rotation': rotation,
      'fitMode': fitMode,
    };
  }

  factory ContactPhotoSettings.fromMap(Map<String, dynamic> map) {
    return ContactPhotoSettings(
      contactId: map['contactId'] as String? ?? '',
      overlayOpacity: (map['overlayOpacity'] as num?)?.toDouble() ?? 0.35,
      rotation: (map['rotation'] as num?)?.toDouble() ?? 0,
      fitMode: map['fitMode'] as String? ?? PhotoFitMode.cover,
    );
  }

  ContactPhotoSettings copyWith({
    String? contactId,
    double? overlayOpacity,
    double? rotation,
    String? fitMode,
  }) {
    return ContactPhotoSettings(
      contactId: contactId ?? this.contactId,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      rotation: rotation ?? this.rotation,
      fitMode: fitMode ?? this.fitMode,
    );
  }
}

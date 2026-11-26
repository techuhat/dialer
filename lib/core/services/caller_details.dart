import 'dart:typed_data';

import '../models/contact.dart';
import '../models/contact_photo_settings.dart';
import '../utils/format_utils.dart';
import 'contact_photo_settings_service.dart';
import 'contacts_service.dart';

/// Contact extras for a call screen: photo, phone label and photo display settings.
class CallerDetails {
  const CallerDetails({this.contact, this.photoSettings, this.number = ''});

  final Contact? contact;
  final ContactPhotoSettings? photoSettings;
  final String number;

  static final Map<String, CallerDetails> _cache = <String, CallerDetails>{};

  Uint8List? get photo => contact?.bestPhoto;

  /// The label of the dialled number on the contact, e.g. "Mobile" or "Work".
  String? get phoneLabel {
    for (final PhoneNumber phone in contact?.phones ?? const <PhoneNumber>[]) {
      if (PhoneUtils.isSameNumber(phone.number, number)) return phone.label;
    }
    return null;
  }

  static CallerDetails? cached(String number) => _cache[PhoneUtils.matchKey(number)];

  static Future<CallerDetails> load(String number) async {
    final String key = PhoneUtils.matchKey(number);
    final CallerDetails? hit = _cache[key];
    if (hit != null) return hit;
    Contact? contact;
    ContactPhotoSettings? settings;
    try {
      contact = await ContactsService.getContactByNumber(number, withPhoto: true);
      if (contact != null && contact.id.isNotEmpty) {
        settings = await ContactPhotoSettingsService.getSettings(contact.id);
      }
    } catch (_) {
      // No contacts permission: the call screens fall back to the number and initials.
    }
    return _cache[key] = CallerDetails(contact: contact, photoSettings: settings, number: number);
  }

  static void clearCache() => _cache.clear();
}

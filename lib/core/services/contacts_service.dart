import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/contact.dart';
import '../utils/format_utils.dart';
import 'warm_contacts_store.dart';

class ContactsService {
  static final StreamController<List<Contact>> _contactsController = 
      StreamController<List<Contact>>.broadcast();
  
  static Stream<List<Contact>> get contactsStream => _contactsController.stream;

  static List<Contact> _cachedContacts = [];
  static Set<String> _favoriteIds = {};
  static bool _favoritesInitialized = false;
  static DateTime? _lastFetch;
  static bool _cacheIncludesPhotos = false;
  static const Duration _cacheTimeout = Duration(hours: 12);

  // Coalesce concurrent fetches so we do not hammer the Contacts provider on tab switches/resumes.
  static Future<List<Contact>>? _inFlightFetch;

  // Fast number -> name index built from the most recent contact sync.
  // Keys should use PhoneUtils.normalizePhone for consistent matching.
  static final Map<String, String> _numberNameIndex = <String, String>{};

  // Fast number -> Contact index for O(1) lookup.
  static final Map<String, Contact> _numberContactIndex = <String, Contact>{};
  static final Set<String> _photoChecked = <String>{};

  static Future<void> _initFavorites() async {
    if (_favoritesInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    final List<String>? favorites = prefs.getStringList('favorite_contacts');
    if (favorites != null) {
      _favoriteIds = favorites.toSet();
    }
    _favoritesInitialized = true;
  }

  static Future<bool> requestPermission() async {
    final status = await Permission.contacts.request();
    return status == PermissionStatus.granted;
  }

  static Future<bool> hasPermission() async {
    final status = await Permission.contacts.status;
    return status == PermissionStatus.granted;
  }

  static List<Contact> getCachedContacts() {
    return List<Contact>.unmodifiable(_cachedContacts);
  }

  static Future<void> loadWarmSnapshot(Future<Map<String, dynamic>> Function() readStore) async {
    try {
      final Map<String, dynamic> data = await readStore();
      String? raw;
      for (final Object? value in data.values) {
        if (value is String && value.isNotEmpty) {
          raw = value;
          break;
        }
      }
      if (raw == null || raw.isEmpty) {
        return;
      }

      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }

      final List<Contact> contacts = decoded
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> map) => Contact.fromMap(map))
          .toList(growable: false);

      _cachedContacts = contacts;
      _lastFetch = DateTime.now();
      _cacheIncludesPhotos = false;
      _favoriteIds = contacts.where((Contact c) => c.isFavorite).map((Contact c) => c.id).toSet();
      _favoritesInitialized = true;
      _rebuildNumberIndex();
      _contactsController.add(contacts);
    } catch (e, stack) {
      developer.log('Failed to load warm contacts snapshot: $e',
          name: 'ContactsService', stackTrace: stack);
    }
  }

  static Future<void> saveWarmSnapshot(
    Future<void> Function(Map<String, dynamic> data) writeStore, {
    int limit = 400,
  }) async {
    if (_cachedContacts.isEmpty) {
      return;
    }
    try {
      final List<Map<String, dynamic>> payload = _cachedContacts
          .take(limit)
          .map((Contact contact) => Contact(
                id: contact.id,
                name: contact.name,
                phones: contact.phones,
                emails: contact.emails,
                isFavorite: contact.isFavorite,
              ).toMap())
          .toList(growable: false);
      final String raw = jsonEncode(payload);
      await writeStore(<String, dynamic>{'snapshot': raw});
    } catch (e, stack) {
      developer.log('Failed to save warm contacts snapshot: $e',
          name: 'ContactsService', stackTrace: stack);
    }
  }

  static Future<List<Contact>> getAllContacts({
    bool forceRefresh = false,
    bool withPhoto = true,
  }) async {
    if (!await hasPermission()) {
      throw Exception('Contacts permission not granted');
    }

    await _initFavorites();

    final bool hasCache = _cachedContacts.isNotEmpty;
    final bool cacheFresh = _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheTimeout;
    final bool cacheMeetsPhotoNeed = withPhoto ? _cacheIncludesPhotos : true;

    if (!forceRefresh && hasCache && cacheFresh && cacheMeetsPhotoNeed) {
      return _cachedContacts;
    }

    // Serve stale cache immediately to avoid UI spinner, and refresh in background.
    if (!forceRefresh && hasCache && cacheMeetsPhotoNeed) {
      _maybeRefreshInBackground(withPhoto: withPhoto);
      return _cachedContacts;
    }

    return _fetchAndCache(withPhoto: withPhoto);
  }

  static Future<List<Contact>> _fetchAndCache({required bool withPhoto}) {
    if (_inFlightFetch != null) {
      return _inFlightFetch!;
    }

    _inFlightFetch = _doFetchAndCache(withPhoto: withPhoto);
    return _inFlightFetch!;
  }

  static Future<List<Contact>> _doFetchAndCache({required bool withPhoto}) async {
    try {
      final List<fc.Contact> fcContacts = await fc.FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: withPhoto,
        withThumbnail: withPhoto,
      );

      final List<Contact> contacts = fcContacts
          .where((contact) => contact.phones.isNotEmpty)
          .map((fcContact) => _convertFromFlutterContact(fcContact))
          .toList();

      contacts.sort(
        (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );

      _cachedContacts = contacts;
      _lastFetch = DateTime.now();
      _cacheIncludesPhotos = withPhoto;
      _photoChecked.clear();
      _rebuildNumberIndex();
      _contactsController.add(contacts);
      unawaited(saveWarmSnapshot(WarmContactsStore.write));

      return contacts;
    } catch (e) {
      throw Exception('Failed to fetch contacts: $e');
    } finally {
      _inFlightFetch = null;
    }
  }

  static void _maybeRefreshInBackground({required bool withPhoto}) {
    if (_inFlightFetch != null) return;
    // Fire and forget; UI keeps using cached data.
    _inFlightFetch = _doFetchAndCache(withPhoto: withPhoto);
    unawaited(_inFlightFetch);
  }

  static void _rebuildNumberIndex() {
    _numberNameIndex.clear();
    _numberContactIndex.clear();
    for (final Contact contact in _cachedContacts) {
      if (contact.displayName.isEmpty) {
        continue;
      }
      for (final PhoneNumber phone in contact.phones) {
        final String normalized = PhoneUtils.normalizePhoneNumber(phone.number);
        if (normalized.isEmpty) {
          continue;
        }
        // Do not overwrite an existing mapping to keep the first seen entry.
        _numberNameIndex.putIfAbsent(normalized, () => contact.displayName);
        _numberContactIndex.putIfAbsent(normalized, () => contact);
      }
    }
  }

  /// Synchronous lookup in the already-loaded contacts; no platform call. For lists.
  static Contact? cachedContactFor(String number) =>
      _numberContactIndex[PhoneUtils.normalizePhoneNumber(number)];

  static Future<Contact?> getContactByNumber(
    String number, {
    bool withPhoto = true,
  }) async {
    final String normalized = PhoneUtils.normalizePhoneNumber(number);
    Contact? match = _numberContactIndex[normalized];
    if (match == null) {
      // Index miss: one scan with looser matching. Never refetch every contact just for photos.
      final List<Contact> allContacts;
      try {
        allContacts = await getAllContacts(withPhoto: false);
      } catch (_) {
        return null;
      }
      for (final Contact contact in allContacts) {
        if (contact.phones.any((PhoneNumber phone) => PhoneUtils.arePhoneNumbersEqual(phone.number, number))) {
          match = contact;
          break;
        }
      }
      if (match == null) return null;
      _numberContactIndex[normalized] = match;
      _numberNameIndex.putIfAbsent(normalized, () => match!.displayName);
    }
    // Hydrate a contact's full photo once; contacts without a photo are not asked again.
    if (withPhoto && match.photoBytes == null && _photoChecked.add(match.id)) {
      match = await _hydratePhoto(match);
      _numberContactIndex[normalized] = match;
    }
    return match;
  }

  static Future<Contact?> getContactById(String id, {bool withPhoto = false}) async {
    try {
      final fc.Contact? fcContact = await fc.FlutterContacts.getContact(
        id,
        withProperties: true,
        withPhoto: withPhoto,
      );
      if (fcContact == null) {
        return null;
      }
      return _convertFromFlutterContact(fcContact);
    } catch (e) {
      developer.log('getContactById failed for $id: $e', name: 'ContactsService');
      return null;
    }
  }

  static Contact _convertFromFlutterContact(fc.Contact fcContact) {
    return Contact(
      id: fcContact.id,
      name: fcContact.displayName,
      phones: fcContact.phones.map((phone) => PhoneNumber(
        number: phone.number,
        label: _mapPhoneLabelToString(phone.label),
      )).toList(),
      emails: fcContact.emails.map((email) => Email(
        address: email.address,
        label: _mapEmailLabelToString(email.label),
      )).toList(),
      photoBytes: fcContact.photo,
      thumbnailBytes: fcContact.thumbnail,
      isFavorite: _favoriteIds.contains(fcContact.id),
    );
  }

  static String _mapPhoneLabelToString(fc.PhoneLabel label) {
    switch (label) {
      case fc.PhoneLabel.home: return 'Home';
      case fc.PhoneLabel.work: return 'Work';
      case fc.PhoneLabel.mobile: return 'Mobile';
      case fc.PhoneLabel.main: return 'Main';
      case fc.PhoneLabel.school: return 'School';
      case fc.PhoneLabel.other: return 'Other';
      default: return 'Custom';
    }
  }

  static String _mapEmailLabelToString(fc.EmailLabel label) {
    switch (label) {
      case fc.EmailLabel.home: return 'Home';
      case fc.EmailLabel.work: return 'Work';
      case fc.EmailLabel.mobile: return 'Mobile';
      case fc.EmailLabel.school: return 'School';
      case fc.EmailLabel.other: return 'Other';
      default: return 'Custom';
    }
  }

  static fc.PhoneLabel _mapStringToPhoneLabel(String label) {
    switch (label.toLowerCase()) {
      case 'home': return fc.PhoneLabel.home;
      case 'work': return fc.PhoneLabel.work;
      case 'mobile': return fc.PhoneLabel.mobile;
      case 'main': return fc.PhoneLabel.main;
      case 'school': return fc.PhoneLabel.school;
      case 'other': return fc.PhoneLabel.other;
      default: return fc.PhoneLabel.custom;
    }
  }

  static fc.EmailLabel _mapStringToEmailLabel(String label) {
    switch (label.toLowerCase()) {
      case 'home': return fc.EmailLabel.home;
      case 'work': return fc.EmailLabel.work;
      case 'mobile': return fc.EmailLabel.mobile;
      case 'school': return fc.EmailLabel.school;
      case 'other': return fc.EmailLabel.other;
      default: return fc.EmailLabel.custom;
    }
  }

  /// Returns the new contact's ID after insertion.
  static Future<String?> addContact(Contact contact) async {
    if (!await hasPermission()) {
      throw Exception('Contacts permission not granted');
    }

    final newContact = fc.Contact()
      ..displayName = contact.name
      ..phones = contact.phones.map((p) => fc.Phone(p.number, label: _mapStringToPhoneLabel(p.label))).toList()
      ..emails = contact.emails.map((e) => fc.Email(e.address, label: _mapStringToEmailLabel(e.label))).toList();
    
    if (contact.photoBytes != null) {
      newContact.photo = contact.photoBytes;
    }

    final nameParts = contact.name.split(' ');
    if (nameParts.isNotEmpty) {
      newContact.name.first = nameParts.first;
      if (nameParts.length > 1) {
        newContact.name.last = nameParts.sublist(1).join(' ');
      }
    }

    final fc.Contact inserted = await newContact.insert();
    await refreshContacts();
    return inserted.id;
  }

  static Future<void> updateContact(Contact contact) async {
     if (!await hasPermission()) {
      throw Exception('Contacts permission not granted');
    }
    
    // Must fetch with accounts to allow updates on Android
    // Also fetch photo so we can detect if it needs to be removed (by setting it to null)
    final fcContact = await fc.FlutterContacts.getContact(
      contact.id, 
      withAccounts: true, 
      withProperties: true,
      withPhoto: true,
    );
    if (fcContact == null) return;

    fcContact.displayName = contact.name;
    fcContact.phones = contact.phones.map((p) => fc.Phone(p.number, label: _mapStringToPhoneLabel(p.label))).toList();
    fcContact.emails = contact.emails.map((e) => fc.Email(e.address, label: _mapStringToEmailLabel(e.label))).toList();
    
    // Update photo (null means remove)
    fcContact.photo = contact.photoBytes;
    if (contact.photoBytes == null) {
      fcContact.thumbnail = null;
    }

    final nameParts = contact.name.split(' ');
    if (nameParts.isNotEmpty) {
      fcContact.name.first = nameParts.first;
      if (nameParts.length > 1) {
        fcContact.name.last = nameParts.sublist(1).join(' ');
      } else {
        fcContact.name.last = '';
      }
    }

    await fcContact.update();
    await refreshContacts();
  }

  static Future<void> deleteContact(String id) async {
     if (!await hasPermission()) {
      throw Exception('Contacts permission not granted');
    }
    final fcContact = await fc.FlutterContacts.getContact(id);
    if (fcContact != null) {
      await fcContact.delete();
      await refreshContacts();
    }
  }

  static Future<void> toggleFavorite(Contact contact) async {
    await _initFavorites();
    if (_favoriteIds.contains(contact.id)) {
      _favoriteIds.remove(contact.id);
    } else {
      _favoriteIds.add(contact.id);
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_contacts', _favoriteIds.toList());
    
    if (_cachedContacts.isNotEmpty) {
      final index = _cachedContacts.indexWhere((c) => c.id == contact.id);
      if (index != -1) {
        _cachedContacts[index] = contact.copyWith(isFavorite: _favoriteIds.contains(contact.id));
        _contactsController.add(List.from(_cachedContacts));
      }
    }
  }

  static Future<Contact> _hydratePhoto(Contact base) async {
    try {
      final fc.Contact? detailed = await fc.FlutterContacts.getContact(
        base.id,
        withProperties: true,
        withPhoto: true,
        withThumbnail: true,
      );
      if (detailed == null) return base;
      // Prefer full photo, fall back to thumbnail
      final photoBytes = detailed.photo;
      final thumbnailBytes = detailed.thumbnail;
      if (photoBytes == null && thumbnailBytes == null) return base;
      return base.copyWith(
        photoBytes: photoBytes ?? base.photoBytes,
        thumbnailBytes: thumbnailBytes ?? base.thumbnailBytes,
      );
    } catch (e) {
      developer.log('Failed to hydrate photo for ${base.id}: $e', name: 'ContactsService');
      return base;
    }
  }

  static Future<void> refreshContacts() async {
    await getAllContacts(forceRefresh: true);
  }

  static Future<void> warmCache({bool withPhoto = false}) async {
    try {
      if (!await hasPermission()) {
        return;
      }
      await getAllContacts(withPhoto: withPhoto);
    } catch (e) {
      developer.log('warmCache failed: $e', name: 'ContactsService');
    }
  }

  static void dispose() {
    _contactsController.close();
  }
}

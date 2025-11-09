import 'dart:async';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';
import '../models/contact.dart';
import '../utils/format_utils.dart';

class ContactsService {
  static final StreamController<List<Contact>> _contactsController = 
      StreamController<List<Contact>>.broadcast();
  
  static Stream<List<Contact>> get contactsStream => _contactsController.stream;
  
  static List<Contact> _cachedContacts = [];
  static DateTime? _lastFetch;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  static Future<bool> requestPermission() async {
    final status = await Permission.contacts.request();
    return status == PermissionStatus.granted;
  }

  static Future<bool> hasPermission() async {
    final status = await Permission.contacts.status;
    return status == PermissionStatus.granted;
  }

  static Future<List<Contact>> getAllContacts({bool forceRefresh = false}) async {
    if (!await hasPermission()) {
      throw Exception('Contacts permission not granted');
    }

    // Return cached contacts if still valid
    if (!forceRefresh && 
        _cachedContacts.isNotEmpty && 
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheTimeout) {
      return _cachedContacts;
    }

    try {
      final List<fc.Contact> fcContacts = await fc.FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false, // We can enable this if needed
      );

      final List<Contact> contacts = fcContacts
          .where((contact) => contact.phones.isNotEmpty)
          .map((fcContact) => _convertFromFlutterContact(fcContact))
          .toList();

      // Sort contacts alphabetically
      contacts.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

      _cachedContacts = contacts;
      _lastFetch = DateTime.now();
      _contactsController.add(contacts);

      return contacts;
    } catch (e) {
      throw Exception('Failed to fetch contacts: $e');
    }
  }

  static Future<List<Contact>> searchContacts(String query) async {
    final allContacts = await getAllContacts();
    
    if (query.trim().isEmpty) return allContacts;
    
    final String lowerQuery = query.toLowerCase();
    
    return allContacts.where((contact) {
      // Search in name
      if (contact.displayName.toLowerCase().contains(lowerQuery)) return true;
      
      // Search in phone numbers
      for (final phone in contact.phones) {
        if (phone.number.replaceAll(RegExp(r'[\s\-\(\)]'), '').contains(lowerQuery.replaceAll(RegExp(r'[\s\-\(\)]'), ''))) {
          return true;
        }
      }
      
      return false;
    }).toList();
  }

  static Future<List<Contact>> getFavoriteContacts() async {
    final allContacts = await getAllContacts();
    return allContacts.where((contact) => contact.isFavorite).toList();
  }

  static Future<Contact?> getContactByNumber(String number) async {
    final allContacts = await getAllContacts();
    
    for (final contact in allContacts) {
      for (final phone in contact.phones) {
        if (PhoneUtils.arePhoneNumbersEqual(phone.number, number)) {
          return contact;
        }
      }
    }
    
    return null;
  }

  static Future<List<Contact>> getFrequentContacts({int limit = 10}) async {
    // This would require call log integration to determine frequency
    // For now, return first 10 contacts as placeholder
    final allContacts = await getAllContacts();
    return allContacts.take(limit).toList();
  }

  static Contact _convertFromFlutterContact(fc.Contact fcContact) {
    return Contact(
      id: fcContact.id,
      name: fcContact.displayName,
      phones: fcContact.phones.map((phone) => PhoneNumber(
        number: phone.number,
        label: phone.label.name,
      )).toList(),
      emails: fcContact.emails.map((email) => Email(
        address: email.address,
        label: email.label.name,
      )).toList(),
      photoUrl: null, // We can add photo support later
      isFavorite: false, // We can add favorite support later
    );
  }

  static Future<void> refreshContacts() async {
    await getAllContacts(forceRefresh: true);
  }

  static void dispose() {
    _contactsController.close();
  }
}
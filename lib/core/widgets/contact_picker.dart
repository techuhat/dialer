import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../services/contacts_service.dart';
import '../theme.dart';
import '../utils/format_utils.dart';
import 'app_sheet.dart';
import 'contact_avatar.dart';

/// Lets the user pick one of their contacts, searchable by name or number. Null when dismissed.
Future<Contact?> pickContact(BuildContext context, {required String title}) =>
    showAppSheet<Contact>(context, fullHeight: true, builder: (_) => _ContactPicker(title: title));

class _ContactPicker extends StatefulWidget {
  const _ContactPicker({required this.title});

  final String title;

  @override
  State<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends State<_ContactPicker> {
  final TextEditingController _search = TextEditingController();
  List<Contact> _contacts = ContactsService.getCachedContacts();

  @override
  void initState() {
    super.initState();
    if (_contacts.isEmpty) {
      ContactsService.getAllContacts(withPhoto: false).then((List<Contact> contacts) {
        if (mounted) setState(() => _contacts = contacts);
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final String query = _search.text.trim().toLowerCase();
    final List<Contact> shown = <Contact>[
      for (final Contact contact in _contacts)
        if (contact.matches(query)) contact,
    ];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              widget.title,
              style: TextStyle(color: palette.text, fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search contacts',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Text(
                      _contacts.isEmpty ? 'No contacts yet' : 'No contact matches “${_search.text.trim()}”',
                      style: TextStyle(color: palette.muted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: shown.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Contact contact = shown[index];
                      final String number = contact.primaryPhoneNumber;
                      return ListTile(
                        leading: ContactAvatar(name: contact.displayName, photo: contact.thumbnailBytes, size: 40),
                        title: Text(contact.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: number.isEmpty ? null : Text(PhoneUtils.formatPhoneNumber(number)),
                        onTap: () => Navigator.pop(context, contact),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

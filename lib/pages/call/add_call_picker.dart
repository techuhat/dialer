import 'package:flutter/material.dart';

import '../../core/models/contact.dart';
import '../../core/services/contacts_service.dart';
import '../../core/widgets/contact_avatar.dart';
import 'call_widgets.dart';

/// Picks the number for "Add call"; pops with the number or null.
class AddCallPicker extends StatefulWidget {
  const AddCallPicker({super.key});

  @override
  State<AddCallPicker> createState() => _AddCallPickerState();
}

class _AddCallPickerState extends State<AddCallPicker> {
  static final RegExp _dialable = RegExp(r'^[\d+*#\s\-().]+$');
  static final RegExp _formatting = RegExp(r'[\s\-().]');

  List<Contact> _contacts = const <Contact>[];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<Contact> contacts = const <Contact>[];
    try {
      contacts = await ContactsService.getAllContacts(withPhoto: false);
    } catch (_) {
      // Without contacts permission only typed numbers can be added.
    }
    if (mounted) {
      setState(() {
        _contacts = contacts.where((Contact c) => c.phones.isNotEmpty).toList(growable: false);
        _loading = false;
      });
    }
  }

  List<Contact> get _matches {
    if (_query.isEmpty) return _contacts;
    final String lower = _query.toLowerCase();
    final String digits = _query.replaceAll(_formatting, '');
    return _contacts
        .where((Contact c) =>
            c.displayName.toLowerCase().contains(lower) ||
            (digits.isNotEmpty && c.phones.any((PhoneNumber p) => p.number.replaceAll(_formatting, '').contains(digits))))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final List<Contact> matches = _matches;
    final bool typedNumber = _query.isNotEmpty && _dialable.hasMatch(_query);
    return Scaffold(
      backgroundColor: CallColors.top,
      appBar: AppBar(
        backgroundColor: CallColors.top,
        foregroundColor: Colors.white,
        title: const Text('Add call'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              autofocus: true,
              keyboardType: TextInputType.phone,
              onChanged: (String value) => setState(() => _query = value.trim()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Name or number',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CallColors.accent))
          : ListView.builder(
              itemCount: matches.length + (typedNumber ? 1 : 0),
              itemBuilder: (BuildContext context, int index) {
                if (typedNumber && index == 0) {
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: CallColors.accept,
                      child: Icon(Icons.call, color: Colors.white),
                    ),
                    title: Text('Call $_query', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    onTap: () => Navigator.pop(context, _query.replaceAll(_formatting, '')),
                  );
                }
                return _ContactTile(contact: matches[index - (typedNumber ? 1 : 0)]);
              },
            ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final Widget avatar = ContactAvatar(name: contact.displayName, size: 40);
    final Text title = Text(contact.displayName, style: const TextStyle(color: Colors.white));
    if (contact.phones.length == 1) {
      final PhoneNumber phone = contact.phones.first;
      return ListTile(
        leading: avatar,
        title: title,
        subtitle: Text(phone.number, style: const TextStyle(color: Colors.white54)),
        onTap: () => Navigator.pop(context, phone.number),
      );
    }
    return ExpansionTile(
      leading: avatar,
      title: title,
      subtitle: Text('${contact.phones.length} numbers', style: const TextStyle(color: Colors.white54)),
      iconColor: Colors.white54,
      collapsedIconColor: Colors.white54,
      children: <Widget>[
        for (final PhoneNumber phone in contact.phones)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 72, right: 16),
            title: Text(phone.number, style: const TextStyle(color: Colors.white)),
            subtitle: Text(phone.label, style: const TextStyle(color: Colors.white38)),
            trailing: const Icon(Icons.call, color: CallColors.accent, size: 20),
            onTap: () => Navigator.pop(context, phone.number),
          ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/call_launcher.dart';
import '../core/models/contact.dart';
import '../core/services/contacts_service.dart';
import '../core/theme.dart';
import '../core/utils/format_utils.dart';
import '../core/widgets/app_sheet.dart';
import '../core/widgets/contact_avatar.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/feedback.dart';
import '../core/widgets/page_header.dart';
import 'contact_details_page.dart';
import 'contact_editor_page.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> with AutomaticKeepAliveClientMixin {
  static final RegExp _nonDigit = RegExp(r'\D');
  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);

  final TextEditingController _search = TextEditingController();
  StreamSubscription<List<Contact>>? _subscription;
  List<Contact> _contacts = ContactsService.getCachedContacts();
  List<Object> _rows = const <Object>[];
  bool _favouritesOnly = false;
  bool _searching = false;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _rows = _buildRows();
    _loading = _contacts.isEmpty;
    _subscription = ContactsService.contactsStream.listen((List<Contact> contacts) {
      if (mounted) _update(() => _contacts = contacts);
    });
    _load();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    try {
      final List<Contact> contacts = await ContactsService.getAllContacts(forceRefresh: force, withPhoto: true);
      if (mounted) _update(() => _contacts = contacts);
    } catch (error) {
      if (mounted) showToast(context, "Couldn't load contacts");
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  void _update(VoidCallback change) => setState(() {
        change();
        _loading = false;
        _rows = _buildRows();
      });

  /// Letter headers (String) followed by their contacts.
  List<Object> _buildRows() {
    final String query = _search.text.trim().toLowerCase();
    final String digits = query.replaceAll(_nonDigit, '');
    final List<Object> rows = <Object>[];
    String? letter;
    for (final Contact contact in _contacts) {
      if (_favouritesOnly && !contact.isFavorite) continue;
      if (query.isNotEmpty &&
          !contact.displayName.toLowerCase().contains(query) &&
          !(digits.isNotEmpty && contact.phones.any((PhoneNumber p) => p.number.replaceAll(_nonDigit, '').contains(digits)))) {
        continue;
      }
      final String first = contact.displayName.isEmpty ? '#' : contact.displayName[0].toUpperCase();
      final String section = _letter.hasMatch(first) ? first : '#';
      if (section != letter) rows.add(letter = section);
      rows.add(contact);
    }
    return rows;
  }

  Future<void> _actions(Contact contact) async {
    final String? number = contact.primaryPhone?.number;
    final String? choice = await showAppSheet<String>(
      context,
      builder: (BuildContext sheetContext) {
        Widget tile(String id, IconData icon, String label, {Color? color}) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Icon(icon, color: color),
              title: Text(label, style: color == null ? null : TextStyle(color: color)),
              onTap: () => Navigator.pop(sheetContext, id),
            );
        return ListView(
          shrinkWrap: true,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(contact.displayName, style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            if (number != null) ...<Widget>[
              tile('call', Icons.call_outlined, 'Call'),
              tile('message', Icons.chat_bubble_outline, 'Send message'),
            ],
            tile('favourite', contact.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                contact.isFavorite ? 'Remove from favourites' : 'Add to favourites'),
            tile('share', Icons.share_outlined, 'Share'),
            tile('edit', Icons.edit_outlined, 'Edit'),
            tile('delete', Icons.delete_outline_rounded, 'Delete', color: AppPalette.of(sheetContext).missed),
            const SizedBox(height: 8),
          ],
        );
      },
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'call':
        await CallLauncher.dial(context, number!);
      case 'message':
        await CallLauncher.message(context, number!);
      case 'favourite':
        await ContactsService.toggleFavorite(contact);
      case 'share':
        final String numbers = contact.phones.map((PhoneNumber p) => PhoneUtils.formatPhoneNumber(p.number)).join('\n');
        await Share.share('${contact.displayName}\n$numbers', subject: contact.displayName);
      case 'edit':
        await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ContactEditorPage(contact: contact)));
      case 'delete':
        final bool delete = await confirmAction(
          context,
          title: 'Delete ${contact.displayName}?',
          message: 'The contact is removed from this phone and its synced accounts.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!delete || !mounted) return;
        try {
          await ContactsService.deleteContact(contact.id);
        } catch (_) {
          if (mounted) showToast(context, "Couldn't delete the contact");
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final AppPalette palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 92),
        child: FloatingActionButton(
          tooltip: 'New contact',
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ContactEditorPage())),
          child: const Icon(Icons.person_add_alt_1_rounded),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _searching ? _searchBar(palette) : _header(),
            ),
            Expanded(child: _list(palette)),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return PageHeader(
      key: const ValueKey<String>('header'),
      title: _favouritesOnly ? 'Favourites' : 'Contacts',
      subtitle: _contacts.isEmpty ? null : '${_contacts.length} people',
      actions: <Widget>[
        HeaderAction(icon: Icons.search_rounded, tooltip: 'Search', onPressed: () => setState(() => _searching = true)),
        HeaderAction(
          icon: _favouritesOnly ? Icons.star_rounded : Icons.star_outline_rounded,
          tooltip: _favouritesOnly ? 'Show everyone' : 'Show favourites',
          onPressed: () => _update(() => _favouritesOnly = !_favouritesOnly),
        ),
      ],
    );
  }

  Widget _searchBar(AppPalette palette) {
    return Padding(
      key: const ValueKey<String>('search'),
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: <Widget>[
          HeaderAction(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Close search',
            onPressed: () => _update(() {
              _searching = false;
              _search.clear();
            }),
          ),
          Expanded(
            child: TextField(
              controller: _search,
              autofocus: true,
              onChanged: (_) => _update(() {}),
              style: TextStyle(color: palette.text, fontSize: 17),
              decoration: InputDecoration(
                hintText: 'Search name or number',
                hintStyle: TextStyle(color: palette.muted),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(AppPalette palette) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_rows.isEmpty) {
      if (_search.text.trim().isNotEmpty) {
        return const EmptyState(emoji: '🔍', title: 'Nobody by that name', message: 'Not even a distant cousin. Try another spelling?');
      }
      if (_favouritesOnly) {
        return const EmptyState(
          emoji: '⭐',
          title: 'No favourites yet',
          message: 'Long-press a contact to star the special ones. We won’t tell the others.',
        );
      }
      return const EmptyState(
        emoji: '📇',
        title: 'No contacts yet',
        message: 'Your phonebook is as empty as a Monday inbox. Tap + to add someone.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 160),
        itemCount: _rows.length,
        itemBuilder: (BuildContext context, int index) {
          final Object row = _rows[index];
          if (row is String) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 20, 2),
              child: Text(row, style: TextStyle(color: palette.accent, fontSize: 14, fontWeight: FontWeight.w700)),
            );
          }
          final Contact contact = row as Contact;
          return _ContactTile(contact: contact, onLongPress: () => _actions(contact));
        },
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onLongPress});

  final Contact contact;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final String? number = contact.primaryPhone?.number;
    final int extra = contact.phones.length - 1;
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ContactDetailsPage(contact: contact))),
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
        child: Row(
          children: <Widget>[
            Badge(
              isLabelVisible: contact.isFavorite,
              alignment: AlignmentDirectional.bottomEnd,
              backgroundColor: const Color(0xFFFFB300),
              smallSize: 12,
              child: ContactAvatar(name: contact.displayName, photo: contact.bestPhoto, size: 44),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    contact.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.text, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  if (number != null)
                    Text(
                      extra > 0 ? '${PhoneUtils.formatPhoneNumber(number)}  +$extra' : PhoneUtils.formatPhoneNumber(number),
                      maxLines: 1,
                      style: TextStyle(color: palette.muted, fontSize: 13.5),
                    ),
                ],
              ),
            ),
            if (number != null)
              IconButton(
                tooltip: 'Call ${contact.displayName}',
                onPressed: () => CallLauncher.dial(context, number),
                icon: Icon(Icons.call_outlined, color: palette.accent),
              ),
          ],
        ),
      ),
    );
  }
}

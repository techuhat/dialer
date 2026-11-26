import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/models/contact.dart';
import '../core/models/contact_photo_settings.dart';
import '../core/services/contact_photo_settings_service.dart';
import '../core/services/contacts_service.dart';
import '../core/services/theme_service.dart';
import '../core/call_launcher.dart';
import '../core/utils/format_utils.dart';
import '../core/widgets/contact_avatar.dart';
import '../core/widgets/photo_backdrop.dart';
import 'contact_editor_page.dart';

class ContactDetailsPage extends StatefulWidget {
  final Contact contact;

  const ContactDetailsPage({super.key, required this.contact});

  @override
  State<ContactDetailsPage> createState() => _ContactDetailsPageState();
}

class _ContactDetailsPageState extends State<ContactDetailsPage> {
  late Contact _contact;
  ContactPhotoSettings? _photoSettings;

  /// Null until measured; the header waits for it so a sharp photo does not flash as a circle first.
  Size? _photoSize;
  bool _photoMeasured = false;

  @override
  void initState() {
    super.initState();
    _contact = widget.contact;
    _loadPhotoSettings();
    _measurePhoto();
  }

  Future<void> _measurePhoto() async {
    final Uint8List? photo = _contact.bestPhoto;
    final Size? size = photo == null ? null : await PhotoStyle.measure(photo);
    if (!mounted) return;
    setState(() {
      _photoSize = size;
      _photoMeasured = true;
    });
  }

  Future<void> _loadPhotoSettings() async {
    if (_contact.id.isNotEmpty) {
      final settings = await ContactPhotoSettingsService.getSettings(_contact.id);
      if (mounted) {
        setState(() {
          _photoSettings = settings;
        });
      }
    }
  }

  /// A sharp photo fills the header; a small one sits in a circle over a wash of its colours.
  Widget _buildPhotoBackground(Uint8List photo, bool isDarkMode) {
    if (!_photoMeasured) return const SizedBox.expand();
    // Behind the app bar icons, in the colour that keeps them legible over any photo.
    final Color shade = isDarkMode ? Colors.black : Colors.white;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (PhotoStyle.of(photo, _photoSize) == PhotoStyle.poster)
          PhotoBackdrop(photo: photo, settings: _photoSettings, defaultOverlay: 0.2, topShade: 0.3)
        else ...<Widget>[
          PhotoBackdrop(photo: photo, settings: _photoSettings, defaultOverlay: 0.45, topShade: 1, wash: true),
          Center(child: ContactAvatar(name: _contact.displayName, photo: photo, size: 132)),
        ],
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const <double>[0, 0.45],
              colors: <Color>[shade.withValues(alpha: 0.5), shade.withValues(alpha: 0)],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = context.watch<ThemeService>().isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: isDarkMode ? const Color(0xFF1C3A5E) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _contact.isFavorite ? Icons.star : Icons.star_border,
                  color: _contact.isFavorite ? const Color(0xFFFFB300) : (isDarkMode ? Colors.white : Colors.black),
                ),
                onPressed: () async {
                  await ContactsService.toggleFavorite(_contact);
                  setState(() {
                    _contact = _contact.copyWith(isFavorite: !_contact.isFavorite);
                  });
                },
              ),
              IconButton(
                icon: Icon(Icons.edit, color: isDarkMode ? Colors.white : Colors.black),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ContactEditorPage(contact: _contact),
                    ),
                  );
                  final Contact? updated = await ContactsService.getContactById(_contact.id, withPhoto: true);
                  if (!context.mounted) return;
                  if (updated == null) {
                    Navigator.pop(context); // deleted in the editor
                  } else {
                    setState(() => _contact = updated);
                    _measurePhoto();
                  }
                },
              ),
              IconButton(
                icon: Icon(Icons.more_vert, color: isDarkMode ? Colors.white : Colors.black),
                onPressed: () {
                  _showMoreOptions(context);
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _contact.bestPhoto != null
                  ? _buildPhotoBackground(_contact.bestPhoto!, isDarkMode)
                  : Container(
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.3),
                      child: Center(
                        child: Text(
                          _contact.initials.isEmpty ? '#' : _contact.initials,
                          style: TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF42A5F5),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _contact.displayName,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildActionButtons(context),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Contact info'),
                  const SizedBox(height: 16),
                  ..._contact.phones.map((phone) => _buildPhoneItem(context, phone)),
                  if (_contact.emails.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    ..._contact.emails.map((email) => _buildEmailItem(context, email)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          context,
          icon: Icons.call,
          label: 'Call',
          onTap: () {
            if (_contact.phones.isNotEmpty) {
              CallLauncher.dial(context, _contact.phones.first.number);
            }
          },
        ),
        _buildActionButton(
          context,
          icon: Icons.message,
          label: 'Text',
          onTap: () {
            if (_contact.phones.isNotEmpty) CallLauncher.message(context, _contact.phones.first.number);
          },
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    final isDarkMode = context.watch<ThemeService>().isDarkMode;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1C3A5E) : const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF42A5F5)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF42A5F5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final isDarkMode = context.watch<ThemeService>().isDarkMode;
    return Text(
      title,
      style: TextStyle(
        color: isDarkMode ? Colors.white70 : Colors.black54,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildPhoneItem(BuildContext context, PhoneNumber phone) {
    final isDarkMode = context.watch<ThemeService>().isDarkMode;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => CallLauncher.dial(context, phone.number),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.phone_outlined, color: isDarkMode ? Colors.white70 : Colors.black54),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            PhoneUtils.formatPhoneNumber(phone.number),
                            style: TextStyle(
                              fontSize: 16,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          if (phone.label.isNotEmpty)
                            Text(
                              phone.label,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode ? Colors.white60 : Colors.black54,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.message_outlined, color: isDarkMode ? Colors.white70 : Colors.black54),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Messaging feature coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmailItem(BuildContext context, Email email) {
    final isDarkMode = context.watch<ThemeService>().isDarkMode;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(Icons.email_outlined, color: isDarkMode ? Colors.white70 : Colors.black54),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email.address,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                if (email.label.isNotEmpty)
                  Text(
                    email.label,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white60 : Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete Contact'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Contact?'),
                  content: const Text('This contact will be permanently deleted.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await ContactsService.deleteContact(_contact.id);
                if (context.mounted) {
                  Navigator.pop(context); // Close bottom sheet
                  Navigator.pop(context); // Close details page
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

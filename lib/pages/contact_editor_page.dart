import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/models/contact.dart';
import '../core/models/contact_photo_settings.dart';
import '../core/services/contact_photo_settings_service.dart';
import '../core/services/contacts_service.dart';
import '../core/services/theme_service.dart';
import 'contact_photo_preview_page.dart';

class ContactEditorPage extends StatefulWidget {
  final Contact? contact;
  final String? initialNumber;

  const ContactEditorPage({super.key, this.contact, this.initialNumber});

  @override
  State<ContactEditorPage> createState() => _ContactEditorPageState();
}

class _ContactEditorPageState extends State<ContactEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  List<PhoneNumberController> _phoneControllers = [];
  List<EmailController> _emailControllers = [];
  Uint8List? _photoBytes;
  ContactPhotoSettings? _photoSettings;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact?.name ?? '');
    _photoBytes = widget.contact?.bestPhoto;
    _loadPhotoSettings();

    if (widget.contact != null) {
      _phoneControllers = widget.contact!.phones
          .map((p) => PhoneNumberController(p))
          .toList();
      _emailControllers = widget.contact!.emails
          .map((e) => EmailController(e))
          .toList();
    } else {
      if (widget.initialNumber != null) {
        _phoneControllers.add(PhoneNumberController(PhoneNumber(number: widget.initialNumber!, label: 'Mobile')));
      } else {
        _phoneControllers.add(PhoneNumberController(const PhoneNumber(number: '', label: 'Mobile')));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (var c in _phoneControllers) {
      c.dispose();
    }
    for (var c in _emailControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPhotoSettings() async {
    if (widget.contact == null || widget.contact!.id.isEmpty) return;
    final settings = await ContactPhotoSettingsService.getSettings(widget.contact!.id);
    if (mounted && settings != null) {
      setState(() => _photoSettings = settings);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;

    final ContactPhotoSettings? settings = await Navigator.push(
      context,
      MaterialPageRoute<ContactPhotoSettings>(
        builder: (_) => ContactPhotoPreviewPage(
          photoBytes: bytes,
          contactId: widget.contact?.id ?? '',
          initialSettings: _photoSettings,
          contactName: _nameController.text.isNotEmpty
              ? _nameController.text
              : widget.contact?.displayName,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {
      _photoBytes = bytes;
      if (settings != null) _photoSettings = settings;
    });
  }

  Future<void> _editPhotoSettings() async {
    if (_photoBytes == null) return;
    final ContactPhotoSettings? settings = await Navigator.push(
      context,
      MaterialPageRoute<ContactPhotoSettings>(
        builder: (_) => ContactPhotoPreviewPage(
          photoBytes: _photoBytes!,
          contactId: widget.contact?.id ?? '',
          initialSettings: _photoSettings,
          contactName: _nameController.text.isNotEmpty
              ? _nameController.text
              : widget.contact?.displayName,
        ),
      ),
    );
    if (!mounted || settings == null) return;
    setState(() => _photoSettings = settings);
  }

  void _removeImage() {
    setState(() {
      _photoBytes = null;
    });
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final phones = _phoneControllers
          .where((c) => c.numberController.text.isNotEmpty)
          .map((c) => PhoneNumber(
                number: c.numberController.text,
                label: c.label,
              ))
          .toList();

      final emails = _emailControllers
          .where((c) => c.addressController.text.isNotEmpty)
          .map((c) => Email(
                address: c.addressController.text,
                label: c.label,
              ))
          .toList();

      final contact = Contact(
        id: widget.contact?.id ?? '',
        name: _nameController.text,
        phones: phones,
        emails: emails,
        photoBytes: _photoBytes,
        isFavorite: widget.contact?.isFavorite ?? false,
      );

      if (widget.contact == null) {
        final newId = await ContactsService.addContact(contact);
        // Save photo settings if we have them and got a valid new contact ID
        if (_photoSettings != null && newId != null && newId.isNotEmpty) {
          await ContactPhotoSettingsService.saveSettings(
            _photoSettings!.copyWith(contactId: newId),
          );
        }
      } else {
        await ContactsService.updateContact(contact);
        // Save photo settings for existing contact
        if (_photoSettings != null && widget.contact!.id.isNotEmpty) {
          await ContactPhotoSettingsService.saveSettings(
            _photoSettings!.copyWith(contactId: widget.contact!.id),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving contact: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeService>().isDarkMode;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contact == null ? 'Create Contact' : 'Edit Contact'),
        actions: [
          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ))
          else
            TextButton(
              onPressed: _saveContact,
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                        image: _photoBytes != null
                            ? DecorationImage(
                                image: MemoryImage(_photoBytes!),
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                              )
                            : null,
                      ),
                      child: _photoBytes == null
                          ? Icon(
                              Icons.add_a_photo_outlined,
                              size: 40,
                              color: theme.colorScheme.onPrimaryContainer,
                            )
                          : null,
                    ),
                  ),
                  if (_photoBytes != null) ...<Widget>[
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _removeImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _editPhotoSettings,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                          ),
                          child: const Icon(
                            Icons.tune,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_photoBytes == null)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            TextFormField(
              controller: _nameController,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                labelText: 'First name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05),
              ),
              validator: (value) => value?.trim().isEmpty ?? true ? 'Name is required' : null,
            ),
            
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            _buildSectionHeader('Phone numbers', Icons.phone_outlined, () {
              setState(() {
                _phoneControllers.add(PhoneNumberController(const PhoneNumber(number: '', label: 'Mobile')));
              });
            }),
            const SizedBox(height: 16),
            ..._phoneControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: controller.numberController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: controller.label,
                          hintText: 'Phone number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: theme.colorScheme.error,
                      onPressed: () {
                        setState(() {
                          _phoneControllers.removeAt(index);
                        });
                      },
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 16),

            _buildSectionHeader('Emails', Icons.email_outlined, () {
              setState(() {
                _emailControllers.add(EmailController(const Email(address: '', label: 'Home')));
              });
            }),
            const SizedBox(height: 16),
            ..._emailControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: controller.addressController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: controller.label,
                          hintText: 'Email address',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: theme.colorScheme.error,
                      onPressed: () {
                        setState(() {
                          _emailControllers.removeAt(index);
                        });
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, VoidCallback onAdd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }
}

class PhoneNumberController {
  final TextEditingController numberController;
  String label;

  PhoneNumberController(PhoneNumber phone)
      : numberController = TextEditingController(text: phone.number),
        label = phone.label;

  void dispose() => numberController.dispose();
}

class EmailController {
  final TextEditingController addressController;
  String label;

  EmailController(Email email)
      : addressController = TextEditingController(text: email.address),
        label = email.label;

  void dispose() => addressController.dispose();
}

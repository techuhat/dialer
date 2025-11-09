import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models/contact.dart' as contact_model;
import '../core/services/contacts_service.dart';
import '../core/services/call_service.dart';
import '../core/utils/format_utils.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  static const LinearGradient _backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A1929), Color(0xFF1C3A5E)],
  );

  List<contact_model.Contact> _contacts = [];
  List<contact_model.Contact> _filteredContacts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      setState(() => _isLoading = true);
      final contacts = await ContactsService.getAllContacts();
      setState(() {
        _contacts = contacts;
        _filteredContacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading contacts: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        _filteredContacts = _contacts.where((contact) {
          return contact.displayName.toLowerCase().contains(query) ||
                 contact.phones.any((phone) => phone.number.contains(query));
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: _backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              // Search bar
              _buildSearchBar(),
              // Content
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _buildContactsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contacts',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Quick access to your contacts',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF90B0CB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF42A5F5).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: const Color(0xFF42A5F5),
        decoration: InputDecoration(
          hintText: 'Search contacts...',
          hintStyle: TextStyle(
            color: Colors.black.withOpacity(0.4),
            fontSize: 16,
          ),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF42A5F5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                  },
                  icon: const Icon(Icons.clear, color: Color(0xFF42A5F5)),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF42A5F5)),
      ),
    );
  }

  Widget _buildContactsList() {
    if (_filteredContacts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadContacts,
      backgroundColor: const Color(0xFF1C3A5E),
      color: const Color(0xFF42A5F5),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
        itemCount: _filteredContacts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) => _buildContactItem(_filteredContacts[index]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.contacts_outlined,
              size: 48,
              color: Color(0xFF90B0CB),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No contacts found' : 'No contacts available',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty 
                ? 'Try a different search term'
                : 'Contacts will appear here when available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF90B0CB),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(contact_model.Contact contact) {
    final primaryPhone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showContactDetails(contact),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                // Avatar
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withOpacity(0.22),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(contact.displayName),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Contact info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.displayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (primaryPhone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          PhoneUtils.formatPhoneNumber(primaryPhone),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFB0BEC5),
                          ),
                        ),
                      ],
                      if (contact.phones.length > 1) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${contact.phones.length} numbers',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF90B0CB),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Call button
                if (primaryPhone.isNotEmpty)
                  InkWell(
                    onTap: () => _makeCall(primaryPhone),
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF42A5F5),
                      ),
                      child: const Icon(Icons.call, color: Colors.white, size: 22),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final chunks = name.trim().split(RegExp(r'\s+'));
    if (chunks.isEmpty) return '';
    if (chunks.length == 1) {
      return chunks.first.isNotEmpty ? chunks.first.substring(0, 1).toUpperCase() : '';
    }
    return (chunks.first.substring(0, 1) + chunks.last.substring(0, 1)).toUpperCase();
  }

  void _showContactDetails(contact_model.Contact contact) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ContactDetailsBottomSheet(contact: contact),
    );
  }

  Future<void> _makeCall(String number) async {
    HapticFeedback.selectionClick();
    try {
      final success = await CallService.makeCall(number);
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to make call'),
              backgroundColor: Color(0xFFE53935),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }
}

// Contact Details Bottom Sheet
class _ContactDetailsBottomSheet extends StatelessWidget {
  final contact_model.Contact contact;

  const _ContactDetailsBottomSheet({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C3A5E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Contact info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF42A5F5).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.person,
                  color: const Color(0xFF42A5F5),
                  size: 40,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.displayName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${contact.phones.length} phone numbers',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFB0BEC5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Phone numbers
          if (contact.phones.isNotEmpty) ...[
            Text(
              'Phone Numbers',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...contact.phones.take(3).map((phone) => _buildPhoneItem(context, phone)),
            if (contact.phones.length > 3) ...[
              const SizedBox(height: 8),
              Text(
                '+${contact.phones.length - 3} more numbers',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF90B0CB),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPhoneItem(BuildContext context, contact_model.PhoneNumber phone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PhoneUtils.formatPhoneNumber(phone.number),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (phone.label.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    phone.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF90B0CB),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          InkWell(
            onTap: () {
              Navigator.pop(context);
              _makeCall(phone.number, context);
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF42A5F5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.call, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Call',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _makeCall(String number, BuildContext context) async {
    HapticFeedback.selectionClick();
    try {
      final success = await CallService.makeCall(number);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to make call'),
            backgroundColor: Color(0xFFE53935),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }
}
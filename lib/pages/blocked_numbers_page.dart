import 'package:flutter/material.dart';

import '../core/services/call_blocking_service.dart';
import '../core/services/contacts_service.dart';
import '../core/theme.dart';
import '../core/utils/format_utils.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/feedback.dart';
import '../core/widgets/page_header.dart';
import 'recents/recent_widgets.dart';

/// The phone's own block list: these numbers are rejected before they ring.
class BlockedNumbersPage extends StatefulWidget {
  const BlockedNumbersPage({super.key});

  @override
  State<BlockedNumbersPage> createState() => _BlockedNumbersPageState();
}

class _BlockedNumbersPageState extends State<BlockedNumbersPage> {
  List<String> _numbers = const <String>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<String> numbers = await CallBlockingService.getBlockedNumbers();
    if (mounted) {
      setState(() {
        _numbers = numbers;
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final TextEditingController controller = TextEditingController();
    final String? number = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Block a number'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: 'Phone number'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Block')),
        ],
      ),
    );
    controller.dispose();
    if (number == null || number.isEmpty) return;
    if (!await CallBlockingService.blockNumber(number)) {
      if (mounted) showToast(context, 'Set Umar Dialer as the default phone app to block numbers');
      return;
    }
    await _load();
  }

  Future<void> _unblock(String number) async {
    if (await CallBlockingService.unblockNumber(number)) {
      await _load();
      if (mounted) showToast(context, '${PhoneUtils.formatPhoneNumber(number)} can call you again');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.block_rounded),
        label: const Text('Block number'),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            PageHeader(
              title: 'Blocked numbers',
              subtitle: 'Rejected before they ring, even when the app is closed',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _numbers.isEmpty
                      ? const EmptyState(
                          emoji: '🛡️',
                          title: 'Nobody is blocked',
                          message: 'Everyone is behaving. For now.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: _numbers.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String number = _numbers[index];
                            final String name =
                                ContactsService.cachedContactFor(number)?.displayName ?? PhoneUtils.formatPhoneNumber(number);
                            return ListTile(
                              contentPadding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
                              leading: NumberAvatar(number: number, name: name, size: 40),
                              title: Text(name, style: TextStyle(color: palette.text)),
                              subtitle: name == PhoneUtils.formatPhoneNumber(number)
                                  ? null
                                  : Text(PhoneUtils.formatPhoneNumber(number), style: TextStyle(color: palette.muted)),
                              trailing: TextButton(onPressed: () => _unblock(number), child: const Text('Unblock')),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

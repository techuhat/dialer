import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/call_launcher.dart';
import '../../core/models/call_log_entry.dart';
import '../../core/models/contact.dart';
import '../../core/services/call_log_service.dart';
import '../../core/services/contacts_service.dart';
import '../../core/theme.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/page_header.dart';
import '../contact_details_page.dart';
import '../contact_editor_page.dart';
import 'recent_widgets.dart';

/// Every logged call with one number, plus the actions for it.
class CallDetailsPage extends StatefulWidget {
  const CallDetailsPage({required this.number, required this.name, super.key});

  final String number;
  final String name;

  @override
  State<CallDetailsPage> createState() => _CallDetailsPageState();
}

class _CallDetailsPageState extends State<CallDetailsPage> {
  StreamSubscription<List<CallLogEntry>>? _subscription;
  List<CallLogEntry> _calls = const <CallLogEntry>[];

  @override
  void initState() {
    super.initState();
    _calls = _forNumber(CallLogService.entries);
    _subscription = CallLogService.watch().listen((List<CallLogEntry> entries) {
      if (mounted) setState(() => _calls = _forNumber(entries));
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  List<CallLogEntry> _forNumber(List<CallLogEntry> entries) => widget.number.isEmpty
      ? const <CallLogEntry>[]
      : entries.where((CallLogEntry e) => PhoneUtils.isSameNumber(e.number, widget.number)).toList();

  Future<void> _deleteAll() async {
    final bool sure = await confirmAction(
      context,
      title: 'Delete this history?',
      message: 'All ${_calls.length} calls with ${widget.name} are removed from the call log.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!sure) return;
    if (await CallLogService.delete(_calls.map((CallLogEntry e) => e.id))) {
      if (mounted) Navigator.pop(context);
    } else if (mounted) {
      showToast(context, "Couldn't delete. Is this the default phone app?");
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Contact? contact = widget.number.isEmpty ? null : ContactsService.cachedContactFor(widget.number);
    final CallLogEntry? latest = _calls.isEmpty ? null : _calls.first;
    final String name = contact?.displayName ?? widget.name;
    final String formatted = PhoneUtils.formatPhoneNumber(widget.number);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: <Widget>[
            PageHeader(
              title: '',
              onBack: () => Navigator.pop(context),
              actions: <Widget>[
                if (_calls.isNotEmpty)
                  HeaderAction(icon: Icons.delete_outline_rounded, tooltip: 'Delete history', onPressed: _deleteAll),
                HeaderAction(
                  icon: Icons.more_vert_rounded,
                  tooltip: 'More',
                  onPressed: () => showNumberActions(context, number: widget.number, name: name),
                ),
              ],
            ),
            Center(child: NumberAvatar(number: widget.number, name: name, size: 96)),
            const SizedBox(height: 16),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.text, fontSize: 26, fontWeight: FontWeight.w600),
            ),
            if (latest?.isNetworkName ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.cell_tower_rounded, size: 15, color: palette.muted),
                    const SizedBox(width: 6),
                    Text('Caller ID from your network', style: TextStyle(color: palette.muted, fontSize: 13)),
                  ],
                ),
              ),
            if (widget.number.isNotEmpty && name != formatted)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  <String>[formatted, ?(latest?.label ?? latest?.location)].join(' · '),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.muted, fontSize: 15),
                ),
              ),
            const SizedBox(height: 24),
            if (widget.number.isNotEmpty) _actions(context, contact, palette),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                'Call history',
                style: TextStyle(color: palette.muted, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.4),
              ),
            ),
            if (_calls.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('No calls in the log.', style: TextStyle(color: palette.muted)),
              ),
            for (final CallLogEntry call in _calls) _CallRow(call: call),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, Contact? contact, AppPalette palette) {
    Widget action(IconData icon, String label, VoidCallback onPressed, {bool primary = false}) => Column(
          children: <Widget>[
            IconButton.filled(
              onPressed: onPressed,
              iconSize: 24,
              style: IconButton.styleFrom(
                backgroundColor: primary ? palette.accent : palette.card,
                foregroundColor: primary ? Colors.white : palette.text,
                side: primary ? null : BorderSide(color: palette.border),
                fixedSize: const Size.square(56),
              ),
              icon: Icon(icon),
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: palette.text, fontSize: 12.5)),
          ],
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        action(Icons.call_rounded, 'Call', () => CallLauncher.dial(context, widget.number), primary: true),
        action(Icons.chat_bubble_outline_rounded, 'Message', () => CallLauncher.message(context, widget.number)),
        if (contact != null)
          action(Icons.person_outline_rounded, 'Contact', () {
            Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ContactDetailsPage(contact: contact)));
          })
        else
          action(Icons.person_add_alt_1_outlined, 'Add', () {
            Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ContactEditorPage(initialNumber: widget.number)));
          }),
        action(Icons.copy_rounded, 'Copy', () => CallLauncher.copyNumber(context, widget.number)),
      ],
    );
  }
}

class _CallRow extends StatelessWidget {
  const _CallRow({required this.call});

  final CallLogEntry call;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final CallTypeVisual visual = CallTypeVisual.of(call.type);
    final List<String> details = <String>[
      DateFormat('EEE d MMM, h:mm a').format(call.timestamp),
      if (call.simSlot != null) 'SIM ${call.simSlot! + 1}',
      if (call.isHd) 'HD',
      if (call.isWifi) 'Wi-Fi',
    ];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(visual.icon, color: CallTypeVisual.colorOf(call.type, palette)),
      title: Text(visual.label, style: TextStyle(color: palette.text, fontWeight: FontWeight.w600)),
      subtitle: Text(details.join(' · '), style: TextStyle(color: palette.muted)),
      trailing: call.duration > 0
          ? Text(TimeUtils.formatDuration(call.duration), style: TextStyle(color: palette.muted))
          : null,
    );
  }
}

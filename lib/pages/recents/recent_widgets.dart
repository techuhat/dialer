import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/call_launcher.dart';
import '../../core/models/call_log_entry.dart';
import '../../core/models/contact.dart';
import '../../core/services/call_blocking_service.dart';
import '../../core/services/call_log_service.dart';
import '../../core/services/contacts_service.dart';
import '../../core/theme.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/contact_avatar.dart';
import '../../core/widgets/feedback.dart';
import '../contact_details_page.dart';
import '../contact_editor_page.dart';

/// Consecutive calls with one number on one day, shown as a single recents row.
class RecentGroup {
  RecentGroup(CallLogEntry first) : entries = <CallLogEntry>[first];

  final List<CallLogEntry> entries;

  CallLogEntry get latest => entries.first;
  String get number => latest.number;
  bool get hasUnreadMissed => entries.any((CallLogEntry e) => e.isUnreadMissed);
}

/// Groups newest-first entries the way the stock dialer does: only adjacent rows merge.
List<RecentGroup> groupRecents(Iterable<CallLogEntry> entries) {
  final List<RecentGroup> groups = <RecentGroup>[];
  for (final CallLogEntry entry in entries) {
    final RecentGroup? last = groups.isEmpty ? null : groups.last;
    final CallLogEntry? previous = last?.entries.last;
    if (last != null &&
        previous != null &&
        entry.number.isNotEmpty &&
        PhoneUtils.isSameNumber(previous.number, entry.number) &&
        DateUtils.isSameDay(previous.timestamp, entry.timestamp)) {
      last.entries.add(entry);
    } else {
      groups.add(RecentGroup(entry));
    }
  }
  return groups;
}

enum RecentsFilter {
  all('All'),
  missed('Missed'),
  incoming('Incoming'),
  outgoing('Outgoing'),
  blocked('Blocked');

  const RecentsFilter(this.label);
  final String label;

  bool accepts(CallLogEntry entry) => switch (this) {
        RecentsFilter.all => true,
        RecentsFilter.missed => entry.type == CallType.missed || entry.type == CallType.voicemail,
        RecentsFilter.incoming => entry.type == CallType.incoming || entry.type == CallType.rejected,
        RecentsFilter.outgoing => entry.type == CallType.outgoing,
        RecentsFilter.blocked => entry.type == CallType.blocked,
      };
}

class CallTypeVisual {
  const CallTypeVisual._(this.icon, this.label);

  final IconData icon;
  final String label;

  static CallTypeVisual of(CallType type) => switch (type) {
        CallType.incoming => const CallTypeVisual._(Icons.call_received_rounded, 'Incoming'),
        CallType.outgoing => const CallTypeVisual._(Icons.call_made_rounded, 'Outgoing'),
        CallType.missed => const CallTypeVisual._(Icons.call_missed_rounded, 'Missed'),
        CallType.rejected => const CallTypeVisual._(Icons.phone_disabled_rounded, 'Declined'),
        CallType.blocked => const CallTypeVisual._(Icons.block_rounded, 'Blocked'),
        CallType.voicemail => const CallTypeVisual._(Icons.voicemail_rounded, 'Voicemail'),
      };

  static Color colorOf(CallType type, AppPalette palette) => switch (type) {
        CallType.missed => palette.missed,
        CallType.outgoing => palette.outgoing,
        CallType.incoming || CallType.voicemail => palette.incoming,
        CallType.rejected || CallType.blocked => palette.declined,
      };
}

/// "2:15 pm" for the last two days, "Mon 12 Nov" this year, "12 Nov 2024" before that.
String recentTimeLabel(DateTime time, {DateTime? now}) {
  final DateTime today = DateUtils.dateOnly(now ?? DateTime.now());
  final int daysAgo = today.difference(DateUtils.dateOnly(time)).inDays;
  if (daysAgo <= 1) return DateFormat('h:mm a').format(time).toLowerCase();
  if (time.year == today.year) return DateFormat('EEE d MMM').format(time);
  return DateFormat('d MMM y').format(time);
}

/// Contact photo when the number is saved, coloured initials otherwise. No platform call.
class NumberAvatar extends StatelessWidget {
  const NumberAvatar({required this.number, required this.name, this.size = 44, super.key});

  final String number;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Contact? contact = number.isEmpty ? null : ContactsService.cachedContactFor(number);
    return ContactAvatar(name: name, photo: contact?.thumbnailBytes ?? contact?.photoBytes, size: size);
  }
}

/// Call, message, copy, contact, block and delete for one number.
Future<void> showNumberActions(BuildContext context, {required String number, required String name, List<String> entryIds = const <String>[]}) async {
  if (number.isEmpty) return;
  final Contact? contact = ContactsService.cachedContactFor(number);
  final bool blocked = (await CallBlockingService.getBlockedNumbers()).any((String b) => PhoneUtils.isSameNumber(b, number));
  if (!context.mounted) return;

  final String? choice = await showAppSheet<String>(
    context,
    builder: (BuildContext sheetContext) {
      Widget tile(String id, IconData icon, String label, {Color? color}) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Icon(icon, color: color),
            title: Text(label, style: color == null ? null : TextStyle(color: color)),
            onTap: () => Navigator.pop(sheetContext, id),
          );
      final Color danger = AppPalette.of(sheetContext).missed;
      return ListView(
        shrinkWrap: true,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(sheetContext).textTheme.titleMedium),
          ),
          tile('call', Icons.call_outlined, 'Call'),
          tile('message', Icons.chat_bubble_outline, 'Send message'),
          tile('copy', Icons.copy_rounded, 'Copy number'),
          if (contact != null)
            tile('contact', Icons.person_outline, 'View contact')
          else
            tile('add', Icons.person_add_alt_1_outlined, 'Add to contacts'),
          tile(blocked ? 'unblock' : 'block', Icons.block_rounded, blocked ? 'Unblock number' : 'Block number', color: blocked ? null : danger),
          if (entryIds.isNotEmpty) tile('delete', Icons.delete_outline_rounded, 'Delete from history', color: danger),
          const SizedBox(height: 8),
        ],
      );
    },
  );
  if (choice == null || !context.mounted) return;

  switch (choice) {
    case 'call':
      await CallLauncher.dial(context, number);
    case 'message':
      await CallLauncher.message(context, number);
    case 'copy':
      await CallLauncher.copyNumber(context, number);
    case 'contact':
      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ContactDetailsPage(contact: contact!)));
    case 'add':
      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ContactEditorPage(initialNumber: number)));
    case 'block':
      final bool block = await confirmAction(
        context,
        title: 'Block $name?',
        message: "Calls from this number won't ring, not even when this app is closed.",
        confirmLabel: 'Block',
        destructive: true,
      );
      if (!block) return;
      final bool blockedNow = await CallBlockingService.blockNumber(number);
      if (context.mounted) {
        showToast(context, blockedNow ? 'Blocked. Peace restored.' : 'Set this app as the default phone app to block numbers');
      }
    case 'unblock':
      if (await CallBlockingService.unblockNumber(number) && context.mounted) showToast(context, 'Unblocked');
    case 'delete':
      final bool delete = await confirmAction(
        context,
        title: 'Delete from history?',
        message: 'Removes ${entryIds.length == 1 ? 'this call' : 'these ${entryIds.length} calls'} from your call log.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (delete && !await CallLogService.delete(entryIds) && context.mounted) {
        showToast(context, "Couldn't delete. Is this the default phone app?");
      }
  }
}

import 'dart:async';
import 'dart:math' as math;

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

/// One number: who it is, the actions for it, a summary of its calls and then the calls by day.
class CallDetailsPage extends StatefulWidget {
  const CallDetailsPage({required this.number, required this.name, super.key});

  final String number;
  final String name;

  @override
  State<CallDetailsPage> createState() => _CallDetailsPageState();
}

class _CallDetailsPageState extends State<CallDetailsPage> {
  /// Calls listed at first, and how many each "Show more" adds; the summary covers the rest.
  static const int _firstCalls = 15;
  static const int _moreCalls = 30;

  StreamSubscription<List<CallLogEntry>>? _changes;
  List<CallLogEntry> _calls = const <CallLogEntry>[];
  int _shown = _firstCalls;

  @override
  void initState() {
    super.initState();
    // The pages already loaded draw at once; the whole history replaces them when it arrives.
    _calls = _forNumber(CallLogService.entries);
    _load();
    _changes = CallLogService.changes.listen((_) => _load());
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final List<CallLogEntry>? calls = await CallLogService.historyFor(widget.number);
    if (mounted && calls != null) setState(() => _calls = calls);
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

    final List<Widget> top = <Widget>[
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
            if (_calls.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('No calls in the log.', style: TextStyle(color: palette.muted)),
              )
            else
              _HistorySummary(calls: _calls),
    ];
    final List<Object> history = _historyRows();
    final int hidden = _calls.length - math.min(_shown, _calls.length);

    return Scaffold(
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 32),
          itemCount: top.length + history.length + (hidden > 0 ? 1 : 0),
          itemBuilder: (BuildContext context, int index) {
            if (index < top.length) return top[index];
            final int at = index - top.length;
            if (at == history.length) return _showMore(hidden);
            final Object row = history[at];
            return row is String ? DayHeading(row) : _CallRow(call: row as CallLogEntry);
          },
        ),
      ),
    );
  }

  /// Day headings (String) and calls, as far as "Show more" has opened the history.
  List<Object> _historyRows() {
    final DateTime now = DateTime.now();
    final List<Object> rows = <Object>[];
    String? day;
    for (final CallLogEntry call in _calls.take(_shown)) {
      final String label = recentDayLabel(call.timestamp, now: now);
      if (label != day) rows.add(day = label);
      rows.add(call);
    }
    return rows;
  }

  Widget _showMore(int hidden) {
    final int next = math.min(hidden, _moreCalls);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Center(
        child: TextButton.icon(
          onPressed: () => setState(() => _shown += _moreCalls),
          icon: const Icon(Icons.expand_more_rounded),
          label: Text('Show $next more ${next == 1 ? 'call' : 'calls'}'),
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
          action(Icons.person_add_alt_1_outlined, 'Add', () => ContactEditorPage.saveNumber(context, widget.number)),
        action(Icons.copy_rounded, 'Copy', () => CallLauncher.copyNumber(context, widget.number)),
      ],
    );
  }
}

/// What one number's history adds up to: calls, talk time, the first call and each kind's count.
class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.calls});

  final List<CallLogEntry> calls;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Map<CallType, int> counts = <CallType, int>{};
    int talk = 0;
    for (final CallLogEntry call in calls) {
      counts.update(call.type, (int count) => count + 1, ifAbsent: () => 1);
      talk += call.duration;
    }
    final DateTime first = calls.last.timestamp;
    Widget figure(String value, String label) => Expanded(
          child: Column(
            children: <Widget>[
              Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: palette.muted, fontSize: 12.5)),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              figure('${calls.length}', calls.length == 1 ? 'call' : 'calls'),
              figure(talk == 0 ? '0s' : TimeUtils.formatDuration(talk), 'talk time'),
              figure(DateFormat(first.year == DateTime.now().year ? 'd MMM' : 'MMM y').format(first), 'first call'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 6,
            children: <Widget>[
              for (final CallType type in CallType.values)
                if (counts[type] case final int count)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(CallTypeVisual.of(type).icon, size: 16, color: CallTypeVisual.colorOf(type, palette)),
                      const SizedBox(width: 4),
                      Text(
                        '$count ${CallTypeVisual.of(type).label.toLowerCase()}',
                        style: TextStyle(color: palette.muted, fontSize: 13),
                      ),
                    ],
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One call on one line: the kind, the time, the SIM and network extras, and how long it lasted.
class _CallRow extends StatelessWidget {
  const _CallRow({required this.call});

  final CallLogEntry call;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final CallTypeVisual visual = CallTypeVisual.of(call.type);
    const List<FontFeature> figures = <FontFeature>[FontFeature.tabularFigures()];
    final String extras = <String>[
      visual.label,
      if (call.simSlot != null) 'SIM ${call.simSlot! + 1}',
      if (call.isHd) 'HD',
      if (call.isWifi) 'Wi-Fi',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: <Widget>[
          Icon(visual.icon, size: 18, color: CallTypeVisual.colorOf(call.type, palette)),
          const SizedBox(width: 14),
          Text(
            recentTimeLabel(call.timestamp),
            style: TextStyle(color: palette.text, fontSize: 15, fontWeight: FontWeight.w600, fontFeatures: figures),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              extras,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.muted, fontSize: 13.5),
            ),
          ),
          if (call.duration > 0)
            Text(
              TimeUtils.formatDuration(call.duration),
              style: TextStyle(color: palette.muted, fontSize: 13.5, fontFeatures: figures),
            ),
        ],
      ),
    );
  }
}

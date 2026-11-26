import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/call_launcher.dart';
import '../../core/models/call_log_entry.dart';
import '../../core/services/call_log_service.dart';
import '../../core/theme.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/page_header.dart';
import '../blocked_numbers_page.dart';
import 'call_details_page.dart';
import 'recent_widgets.dart';
import 'stats_page.dart';

class RecentsPage extends StatefulWidget {
  const RecentsPage({super.key});

  @override
  State<RecentsPage> createState() => _RecentsPageState();
}

class _RecentsPageState extends State<RecentsPage> with AutomaticKeepAliveClientMixin {
  final TextEditingController _search = TextEditingController();
  StreamSubscription<List<CallLogEntry>>? _subscription;
  List<CallLogEntry> _entries = CallLogService.entries;
  List<Object> _rows = const <Object>[];
  RecentsFilter _filter = RecentsFilter.all;
  bool _searching = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _rows = _buildRows();
    _subscription = CallLogService.watch().listen((List<CallLogEntry> entries) {
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _rows = _buildRows();
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _update(VoidCallback change) => setState(() {
        change();
        _rows = _buildRows();
      });

  /// Section titles (String) and rows (RecentGroup) in display order.
  List<Object> _buildRows() {
    final String query = _search.text.trim().toLowerCase();
    final String digits = query.replaceAll(RegExp(r'\D'), '');
    final Iterable<CallLogEntry> visible = _entries.where((CallLogEntry entry) {
      if (!_filter.accepts(entry)) return false;
      if (query.isEmpty) return true;
      return entry.displayName.toLowerCase().contains(query) ||
          (digits.isNotEmpty && entry.number.replaceAll(RegExp(r'\D'), '').contains(digits));
    });

    final DateTime today = DateUtils.dateOnly(DateTime.now());
    final List<Object> rows = <Object>[];
    String? section;
    for (final RecentGroup group in groupRecents(visible)) {
      final int daysAgo = today.difference(DateUtils.dateOnly(group.latest.timestamp)).inDays;
      final String title = daysAgo <= 0 ? 'Today' : (daysAgo == 1 ? 'Yesterday' : 'Older');
      if (title != section) rows.add(section = title);
      rows.add(group);
    }
    return rows;
  }

  Future<void> _clearHistory() async {
    final bool sure = await confirmAction(
      context,
      title: 'Clear call history?',
      message: 'Every call is removed from this phone’s call log. This cannot be undone.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (sure && !await CallLogService.clearAll() && mounted) showToast(context, "Couldn't clear the call log");
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final AppPalette palette = AppPalette.of(context);
    final bool hasBlocked = _entries.any((CallLogEntry e) => e.type == CallType.blocked);
    final int unread = CallLogService.unreadMissedCount;
    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _searching ? _searchBar(palette) : _header(unread),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: <Widget>[
                for (final RecentsFilter filter in RecentsFilter.values)
                  if (filter != RecentsFilter.blocked || hasBlocked || _filter == RecentsFilter.blocked)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filter == RecentsFilter.missed && unread > 0 ? '${filter.label} · $unread' : filter.label),
                        selected: _filter == filter,
                        showCheckmark: false,
                        onSelected: (_) => _update(() => _filter = filter),
                      ),
                    ),
              ],
            ),
          ),
          Expanded(child: _list(palette)),
        ],
      ),
    );
  }

  Widget _header(int unread) {
    return PageHeader(
      key: const ValueKey<String>('header'),
      title: 'Recents',
      actions: <Widget>[
        HeaderAction(icon: Icons.search_rounded, tooltip: 'Search', onPressed: () => setState(() => _searching = true)),
        HeaderAction(
          icon: Icons.insights_rounded,
          tooltip: 'Call stats',
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const StatsPage())),
        ),
        PopupMenuButton<String>(
          tooltip: 'More',
          icon: Icon(Icons.more_vert_rounded, color: AppPalette.of(context).text),
          onSelected: (String value) {
            switch (value) {
              case 'read':
                CallLogService.markMissedRead();
              case 'blocked':
                Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const BlockedNumbersPage()));
              case 'clear':
                _clearHistory();
            }
          },
          itemBuilder: (_) => <PopupMenuEntry<String>>[
            if (unread > 0) const PopupMenuItem<String>(value: 'read', child: Text('Mark missed calls as seen')),
            const PopupMenuItem<String>(value: 'blocked', child: Text('Blocked numbers')),
            const PopupMenuItem<String>(value: 'clear', child: Text('Clear call history')),
          ],
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
          if (_search.text.isNotEmpty)
            HeaderAction(icon: Icons.close_rounded, tooltip: 'Clear', onPressed: () => _update(_search.clear)),
        ],
      ),
    );
  }

  Widget _list(AppPalette palette) {
    if (_rows.isEmpty) return _empty();
    return RefreshIndicator(
      onRefresh: CallLogService.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: _rows.length,
        itemBuilder: (BuildContext context, int index) {
          final Object row = _rows[index];
          if (row is String) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(row, style: TextStyle(color: palette.muted, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
            );
          }
          final RecentGroup group = row as RecentGroup;
          return _RecentTile(key: ValueKey<String>(group.latest.id), group: group);
        },
      ),
    );
  }

  Widget _empty() {
    if (_search.text.trim().isNotEmpty) {
      return EmptyState(emoji: '🔍', title: 'No match for “${_search.text.trim()}”', message: 'Not a single soul. Check the spelling?');
    }
    return switch (_filter) {
      RecentsFilter.all => const EmptyState(
          emoji: '📭',
          title: 'No calls yet',
          message: 'Your phone is enjoying the peace and quiet. Enjoy it while it lasts.',
        ),
      RecentsFilter.missed => const EmptyState(emoji: '🏆', title: 'No missed calls', message: 'Fastest thumb in town.'),
      RecentsFilter.incoming => const EmptyState(emoji: '🦗', title: 'Nobody called', message: 'Crickets… maybe call someone first?'),
      RecentsFilter.outgoing => const EmptyState(emoji: '☎️', title: 'No outgoing calls', message: 'The keypad is feeling a little lonely.'),
      RecentsFilter.blocked => const EmptyState(emoji: '🛡️', title: 'Nothing blocked', message: 'No pests got through. Nice.'),
    };
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.group, super.key});

  final RecentGroup group;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final CallLogEntry latest = group.latest;
    final bool missed = latest.type == CallType.missed;
    final String name = latest.displayName;
    final String? detail = latest.label ??
        (latest.name != null && latest.number.isNotEmpty ? PhoneUtils.formatPhoneNumber(latest.number) : latest.location);
    final Set<CallType> types = group.entries.map((CallLogEntry e) => e.type).toSet();

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => CallDetailsPage(number: latest.number, name: name)),
      ),
      onLongPress: () => showNumberActions(
        context,
        number: latest.number,
        name: name,
        entryIds: group.entries.map((CallLogEntry e) => e.id).toList(),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
        child: Row(
          children: <Widget>[
            NumberAvatar(number: latest.number, name: name),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          group.entries.length > 1 ? '$name (${group.entries.length})' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: missed ? palette.missed : palette.text,
                            fontSize: 16,
                            fontWeight: group.hasUnreadMissed ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (latest.isNetworkName) ...<Widget>[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Name shown by your network (caller ID)',
                          child: Icon(Icons.cell_tower_rounded, size: 15, color: palette.muted),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: <Widget>[
                      for (final CallType type in types.take(3))
                        Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Icon(CallTypeVisual.of(type).icon, size: 15, color: CallTypeVisual.colorOf(type, palette)),
                        ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          <String>[?detail, recentTimeLabel(latest.timestamp)].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.muted, fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (latest.number.isNotEmpty)
              IconButton(
                tooltip: 'Call $name',
                onPressed: () => CallLauncher.dial(context, latest.number),
                icon: Icon(Icons.call_outlined, color: palette.accent),
              ),
          ],
        ),
      ),
    );
  }
}

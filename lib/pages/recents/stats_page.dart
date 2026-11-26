import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/call_log_entry.dart';
import '../../core/models/call_stats.dart';
import '../../core/services/call_log_service.dart';
import '../../core/theme.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/page_header.dart';
import 'call_details_page.dart';
import 'recent_widgets.dart';

enum _Period {
  week('7 days', Duration(days: 7)),
  month('30 days', Duration(days: 30)),
  all('All time', Duration(days: 36500));

  const _Period(this.label, this.length);
  final String label;
  final Duration length;
}

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  _Period _period = _Period.week;
  late CallStats _stats = CallLogService.statistics(period: _period.length);
  StreamSubscription<List<CallLogEntry>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = CallLogService.watch().listen((_) {
      if (mounted) setState(() => _stats = CallLogService.statistics(period: _period.length));
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _setPeriod(_Period period) => setState(() {
        _period = period;
        _stats = CallLogService.statistics(period: period.length);
      });

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: <Widget>[
            PageHeader(title: 'Call stats', onBack: () => Navigator.pop(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: SegmentedButton<_Period>(
                segments: <ButtonSegment<_Period>>[
                  for (final _Period p in _Period.values) ButtonSegment<_Period>(value: p, label: Text(p.label)),
                ],
                selected: <_Period>{_period},
                showSelectedIcon: false,
                onSelectionChanged: (Set<_Period> selection) => _setPeriod(selection.first),
              ),
            ),
            _Section(child: _Hero(stats: _stats)),
            if (_stats.total > 0) ...<Widget>[
              _Section(title: 'Breakdown', child: _Breakdown(stats: _stats)),
              _Section(title: 'Last 7 days', child: _DayBars(counts: _stats.perDay, color: palette.incoming)),
              if (_stats.topCallers.isNotEmpty)
                _Section(title: 'Top callers', padding: EdgeInsets.zero, child: _TopCallers(callers: _stats.topCallers)),
              if (_stats.longest != null) _Section(title: 'Longest call', child: _Longest(call: _stats.longest!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child, this.title, this.padding = const EdgeInsets.all(16)});

  final String? title;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Text(title!, style: TextStyle(color: palette.muted, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.border),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ],
      ),
    );
  }
}

/// Talk time as the headline, plus a line with some personality.
class _Hero extends StatelessWidget {
  const _Hero({required this.stats});

  final CallStats stats;

  String get _quip {
    final Duration talk = stats.talkTime;
    if (stats.total == 0) return 'Quiet times. Your phone is basically a paperweight. 🪨';
    if (talk.inHours >= 10) return 'That’s a part-time job. Are they paying you? 😅';
    if (stats.missed == 0) return 'Zero missed calls. Absolute legend. 🏆';
    if (stats.answeredRate < 50) return 'Half the world is waiting for a call back. 👀';
    if (talk.inHours >= 2) return 'Chatty! Your ears deserve a holiday. 🎧';
    return 'Nicely balanced, as all things should be. ⚖️';
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Talk time', style: TextStyle(color: palette.muted, fontSize: 13)),
        const SizedBox(height: 2),
        Text(
          _talkLabel(stats.talkTime),
          style: TextStyle(color: palette.text, fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.8),
        ),
        Text(
          '${stats.total} ${stats.total == 1 ? 'call' : 'calls'} · ${stats.answeredRate}% answered · '
          'avg ${TimeUtils.formatDuration(stats.averageCall.inSeconds)}',
          style: TextStyle(color: palette.muted, fontSize: 13.5),
        ),
        const SizedBox(height: 12),
        Text(_quip, style: TextStyle(color: palette.text, fontSize: 14.5)),
      ],
    );
  }

  static String _talkLabel(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }
}

/// Part-to-whole bar with gaps between segments and a labelled legend (identity is never colour alone).
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.stats});

  final CallStats stats;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final List<(CallType, String, int, Color)> parts = <(CallType, String, int, Color)>[
      (CallType.incoming, 'Incoming', stats.incoming, palette.incoming),
      (CallType.missed, 'Missed', stats.missed, palette.missed),
      (CallType.outgoing, 'Outgoing', stats.outgoing, palette.outgoing),
      (CallType.rejected, 'Declined & blocked', stats.declined, palette.declined),
    ];
    final List<(CallType, String, int, Color)> shown = parts.where((p) => p.$3 > 0).toList();
    return Column(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < shown.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(flex: shown[i].$3, child: ColoredBox(color: shown[i].$4)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final (CallType type, String label, int count, Color color) in parts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: <Widget>[
                Icon(CallTypeVisual.of(type).icon, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(child: Text(label, style: TextStyle(color: palette.text, fontSize: 14.5))),
                Text(
                  '$count · ${stats.total == 0 ? 0 : (count * 100 / stats.total).round()}%',
                  style: TextStyle(color: palette.muted, fontSize: 14, fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Calls per day; tap a bar for its count. Today and the busiest day are labelled.
class _DayBars extends StatefulWidget {
  const _DayBars({required this.counts, required this.color});

  final List<int> counts;
  final Color color;

  @override
  State<_DayBars> createState() => _DayBarsState();
}

class _DayBarsState extends State<_DayBars> {
  static const double _plotHeight = 110;
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final List<int> counts = widget.counts;
    final int max = counts.fold(0, (int a, int b) => a > b ? a : b);
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    return SizedBox(
      height: _plotHeight + 45,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int i = 0; i < counts.length; i++)
            Expanded(
              child: Builder(builder: (BuildContext context) {
                final DateTime day = today.subtract(Duration(days: counts.length - 1 - i));
                final bool labelled =
                    _selected == i || (_selected == null && (i == counts.length - 1 || (counts[i] == max && max > 0)));
                void select() => setState(() => _selected = _selected == i ? null : i);
                return Semantics(
                  label: '${DateFormat('EEEE').format(day)}: ${counts[i]} calls',
                  button: true,
                  onTap: select,
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: select,
                    child: Column(
                      children: <Widget>[
                        SizedBox(
                          height: 20,
                          child: AnimatedOpacity(
                            opacity: labelled ? 1 : 0,
                            duration: const Duration(milliseconds: 150),
                            child: FittedBox(
                              child: Text('${counts[i]}', style: TextStyle(color: palette.text, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (BuildContext context, BoxConstraints box) => Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                width: 16,
                                height: max == 0 || counts[i] == 0 ? 2 : 4 + (box.maxHeight - 4) * counts[i] / max,
                                decoration: BoxDecoration(
                                  color: counts[i] == 0
                                      ? palette.border
                                      : widget.color.withValues(alpha: _selected == null || _selected == i ? 1 : 0.45),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(height: 1, color: palette.border),
                        SizedBox(
                          height: 24,
                          child: Center(
                            child: FittedBox(
                              child: Text(
                                i == counts.length - 1 ? 'Today' : DateFormat('E').format(day),
                                style: TextStyle(color: palette.muted, fontSize: 11.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _TopCallers extends StatelessWidget {
  const _TopCallers({required this.callers});

  final List<TopCaller> callers;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Column(
      children: <Widget>[
        for (final TopCaller caller in callers)
          ListTile(
            leading: NumberAvatar(number: caller.number, name: caller.name, size: 40),
            title: Text(caller.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.text)),
            subtitle: Text(
              '${caller.calls} ${caller.calls == 1 ? 'call' : 'calls'} · ${TimeUtils.formatDuration(caller.talkTime.inSeconds)}',
              style: TextStyle(color: palette.muted),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => CallDetailsPage(number: caller.number, name: caller.name)),
            ),
          ),
      ],
    );
  }
}

class _Longest extends StatelessWidget {
  const _Longest({required this.call});

  final CallLogEntry call;

  String get _quip {
    if (call.duration >= 3600) return 'That’s a whole movie. 🎬';
    if (call.duration >= 1200) return 'Long enough to brew chai twice. ☕';
    return 'Short and sweet. ✂️';
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Row(
      children: <Widget>[
        NumberAvatar(number: call.number, name: call.displayName, size: 44),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${TimeUtils.formatClock(Duration(seconds: call.duration))} with ${call.displayName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.text, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              Text(
                '${DateFormat('EEE d MMM').format(call.timestamp)} · $_quip',
                style: TextStyle(color: palette.muted, fontSize: 13.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

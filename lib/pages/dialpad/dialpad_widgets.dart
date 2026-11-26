import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/smart_dial.dart';
import '../../core/widgets/add_contact_icon.dart';
import '../../core/widgets/contact_avatar.dart';
import 'dial_input.dart';

/// The typed number, large and grouped, with what it is above it (a contact's name or the kind of
/// number) and a signal line under it that pulses with each key.
class NumberReadout extends StatefulWidget {
  const NumberReadout({required this.controller, required this.caption, required this.compact, super.key});

  final DialInputController controller;
  final String? caption;
  final bool compact;

  @override
  State<NumberReadout> createState() => _NumberReadoutState();
}

class _NumberReadoutState extends State<NumberReadout> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    value: 1,
  );
  late int _length = widget.controller.text.length;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _pulse.dispose();
    super.dispose();
  }

  void _changed() {
    final int length = widget.controller.text.length;
    if (length != _length && !_still) _pulse.forward(from: 0);
    _length = length;
  }

  /// Shrinks long numbers so they stay on screen, like the stock dialer.
  double _fontSize(int length) {
    final double size = length <= 11 ? 38 : (length <= 14 ? 32 : (length <= 17 ? 27 : 23));
    return widget.compact ? size - 4 : size;
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final String? caption = widget.caption;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: 22,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: caption == null
                  ? const SizedBox.shrink()
                  : Text(
                      caption,
                      key: ValueKey<String>(caption),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.accent, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          SizedBox(
            height: widget.compact ? 46 : 56,
            child: Center(
              child: TextField(
                controller: widget.controller,
                keyboardType: TextInputType.none,
                // An empty field shows only the hint; a centred cursor would cut through it.
                showCursor: widget.controller.text.isNotEmpty,
                autofocus: true,
                textAlign: TextAlign.center,
                inputFormatters: <TextInputFormatter>[DialInputController.formatter],
                cursorColor: palette.accent,
                style: TextStyle(
                  color: palette.text,
                  fontSize: _fontSize(widget.controller.text.length),
                  fontWeight: FontWeight.w300,
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration.collapsed(
                  hintText: 'Type a number',
                  hintStyle: TextStyle(
                    color: palette.muted,
                    fontSize: widget.compact ? 22 : 26,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 10,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (BuildContext context, _) => CustomPaint(
                painter: _SignalLinePainter(progress: _pulse.value, base: palette.border, glow: palette.signal),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A hairline that lights up from the middle outwards and fades.
class _SignalLinePainter extends CustomPainter {
  _SignalLinePainter({required this.progress, required this.base, required this.glow});

  final double progress;
  final Color base;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final double y = size.height / 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()..color = base);
    if (progress >= 1) return;
    final double reach = size.width / 2 * Curves.easeOutCubic.transform(progress);
    final double fade = 1 - Curves.easeIn.transform(progress);
    final Rect lit = Rect.fromLTRB(size.width / 2 - reach, y - 1, size.width / 2 + reach, y + 1);
    canvas.drawRect(
      lit,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            glow.withValues(alpha: 0),
            glow.withValues(alpha: fade),
            glow.withValues(alpha: 0),
          ],
        ).createShader(lit),
    );
  }

  @override
  bool shouldRepaint(_SignalLinePainter old) => old.progress != progress || old.base != base || old.glow != glow;
}

/// The strip under the number: tips while it is empty, matching contacts while typing, or a note
/// that the number is new. Fixed height, so the keypad never jumps.
class SuggestionStrip extends StatelessWidget {
  const SuggestionStrip({
    required this.number,
    required this.matches,
    required this.unknown,
    required this.onPick,
    required this.compact,
    super.key,
  });

  final String number;
  final List<DialMatch> matches;

  /// A complete-looking number that is not a contact.
  final bool unknown;
  final ValueChanged<DialMatch> onPick;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextStyle note = TextStyle(color: palette.muted, fontSize: 13);
    final Widget child;
    if (number.isEmpty) {
      child = Text('Hold 0 for +. Hold * for a pause.', key: const ValueKey<String>('tip'), style: note);
    } else if (matches.isNotEmpty) {
      child = ListView.separated(
        key: const ValueKey<String>('matches'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: matches.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) => Center(
          child: _SuggestionChip(match: matches[index], onTap: () => onPick(matches[index])),
        ),
      );
    } else if (unknown) {
      child = Text('Not in your contacts', key: const ValueKey<String>('unknown'), style: note);
    } else {
      child = const SizedBox.shrink();
    }
    return SizedBox(
      height: compact ? 54 : 64,
      width: double.infinity,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        layoutBuilder: (Widget? current, List<Widget> previous) =>
            Stack(alignment: Alignment.center, children: <Widget>[...previous, ?current]),
        child: child,
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.match, required this.onTap});

  final DialMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final String name = match.contact.displayName;
    final String number = PhoneUtils.formatPhoneNumber(match.number);
    return Semantics(
      button: true,
      label: '$name, $number',
      hint: 'Fills in this number',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: palette.card,
        shape: StadiumBorder(side: BorderSide(color: palette.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(5, 5, 16, 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ContactAvatar(name: name, photo: match.contact.thumbnailBytes, size: 38),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Marked(
                        text: name,
                        range: match.nameRange,
                        style: TextStyle(color: palette.text, fontSize: 14, fontWeight: FontWeight.w600),
                        mark: palette.accent,
                      ),
                      _Marked(
                        text: number,
                        range: match.numberRange,
                        style: TextStyle(color: palette.muted, fontSize: 12.5),
                        mark: palette.accent,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One line of text with the matched part in the accent colour.
class _Marked extends StatelessWidget {
  const _Marked({required this.text, required this.range, required this.style, required this.mark});

  final String text;
  final ({int start, int end})? range;
  final TextStyle style;
  final Color mark;

  @override
  Widget build(BuildContext context) {
    final ({int start, int end})? at = range;
    final TextSpan span = at == null || at.end > text.length
        ? TextSpan(text: text)
        : TextSpan(
            children: <TextSpan>[
              TextSpan(text: text.substring(0, at.start)),
              TextSpan(
                text: text.substring(at.start, at.end),
                style: TextStyle(color: mark, fontWeight: FontWeight.w700),
              ),
              TextSpan(text: text.substring(at.end)),
            ],
          );
    return Text.rich(span, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}

/// Save, call and delete, side by side in the thumb's reach.
class DialActions extends StatelessWidget {
  const DialActions({
    required this.canSave,
    required this.canCall,
    required this.onSave,
    required this.onCall,
    required this.onBackspace,
    required this.onClear,
    required this.compact,
    super.key,
  });

  final bool canSave;

  /// Also enables delete: both need something typed.
  final bool canCall;
  final VoidCallback onSave;
  final VoidCallback onCall;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SizedBox(
      height: compact ? 72 : 84,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _RoundAction(
            label: 'Save as contact',
            enabled: canSave,
            onTap: onSave,
            child: AddContactIcon(active: canSave),
          ),
          const SizedBox(width: 28),
          _CallButton(enabled: canCall, onTap: onCall, size: compact ? 64 : 72),
          const SizedBox(width: 28),
          _RoundAction(
            label: 'Delete',
            hint: 'Hold to clear the number',
            enabled: canCall,
            onTap: onBackspace,
            onLongPress: onClear,
            child: Icon(
              Icons.backspace_outlined,
              size: 26,
              color: canCall ? palette.text : palette.muted.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      hint: hint,
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 56,
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            onLongPress: enabled ? onLongPress : null,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({required this.enabled, required this.onTap, required this.size});

  static const LinearGradient _green = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF34C26B), AppPalette.callGreen],
  );

  final bool enabled;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Call',
      onTap: enabled ? onTap : null,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled ? _green : null,
          color: enabled ? null : palette.card,
          border: enabled ? null : Border.all(color: palette.border),
          boxShadow: enabled
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppPalette.callGreen.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Icon(Icons.call_rounded, size: size * 0.44, color: enabled ? Colors.white : palette.muted),
          ),
        ),
      ),
    );
  }
}

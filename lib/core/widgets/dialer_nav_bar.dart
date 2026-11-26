import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'feedback.dart';
import 'nav_parts.dart';

/// Bottom bar with a raised rotary-dial keypad button in a cradle, and a hand-drawn squiggle
/// under the selected tab. The middle destination is the dial.
class DialerNavBar extends StatelessWidget {
  const DialerNavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.badges = const <int, int>{},
    super.key,
  }) : assert(destinations.length == 5);

  static const double barHeight = 66;
  static const double _lift = 26;
  static const double _dialSize = 62;

  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Destination index → count shown as a red badge (e.g. unread missed calls).
  final Map<int, int> badges;

  void _select(int index) {
    if (index == selectedIndex) return;
    HapticFeedback.selectionClick();
    onSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final double inset = MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: _lift + barHeight + inset,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            top: _lift,
            child: CustomPaint(
              painter: _CradlePainter(color: palette.bar, edge: palette.border),
              child: Padding(
                padding: EdgeInsets.only(bottom: inset),
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < destinations.length; i++)
                      Expanded(
                        child: i == 2
                            ? _DialLabel(label: destinations[i].label, selected: selectedIndex == i, onTap: () => _select(i))
                            : _NavTab(
                                destination: destinations[i],
                                selected: selectedIndex == i,
                                badge: badges[i] ?? 0,
                                onTap: () => _select(i),
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: _lift - _dialSize / 2 + 6,
            left: 0,
            right: 0,
            child: Center(
              child: _RotaryDialButton(
                size: _dialSize,
                selected: selectedIndex == 2,
                label: destinations[2].label,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onSelected(2);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({required this.destination, required this.selected, required this.badge, required this.onTap});

  final NavDestination destination;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Color color = selected ? palette.accent : palette.muted;
    return Semantics(
      selected: selected,
      button: true,
      label: badge > 0 ? '${destination.label}, $badge new' : destination.label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedScale(
              scale: selected ? 1.12 : 1,
              duration: const Duration(milliseconds: 650),
              curve: selected ? Curves.elasticOut : Curves.easeOut,
              child: Badge(
                isLabelVisible: badge > 0,
                label: Text(badge > 99 ? '99+' : '$badge'),
                backgroundColor: palette.missed,
                child: Icon(selected ? destination.selectedIcon : destination.icon, color: color, size: 25),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              maxLines: 1,
              style: TextStyle(color: color, fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
            ),
            _Squiggle(visible: selected, color: palette.accent),
          ],
        ),
      ),
    );
  }
}

class _DialLabel extends StatelessWidget {
  const _DialLabel({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Color color = selected ? palette.accent : palette.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
            ),
            _Squiggle(visible: selected, color: palette.accent),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// A hand-drawn wavy underline that draws itself in from the left.
class _Squiggle extends StatelessWidget {
  const _Squiggle({required this.visible, required this.color});

  final bool visible;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: visible ? 1 : 0),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double progress, _) => CustomPaint(
        size: const Size(30, 7),
        painter: _SquigglePainter(progress: progress, color: color),
      ),
    );
  }
}

class _SquigglePainter extends CustomPainter {
  _SquigglePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final double mid = size.height / 2;
    const double wave = 7.5;
    final Path path = Path()..moveTo(0, mid);
    for (double x = 0; x < size.width; x += wave) {
      final bool up = (x / wave).round().isEven;
      path.quadraticBezierTo(x + wave / 2, up ? mid - 3 : mid + 3, x + wave, mid);
    }
    final Path drawn = Path();
    for (final PathMetric metric in path.computeMetrics()) {
      drawn.addPath(metric.extractPath(0, metric.length * progress), Offset.zero);
    }
    canvas.drawPath(
      drawn,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SquigglePainter old) => old.progress != progress || old.color != color;
}

/// Keypad button drawn as an old rotary dial; it winds like one when tapped.
class _RotaryDialButton extends StatefulWidget {
  const _RotaryDialButton({required this.size, required this.selected, required this.label, required this.onTap});

  final double size;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  State<_RotaryDialButton> createState() => _RotaryDialButtonState();
}

class _RotaryDialButtonState extends State<_RotaryDialButton> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  Animation<double> _turn = const AlwaysStoppedAnimation<double>(0);

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _wind(double turns) {
    _turn = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(tween: Tween<double>(begin: 0, end: turns).chain(CurveTween(curve: Curves.easeOut)), weight: 45),
      TweenSequenceItem<double>(tween: Tween<double>(begin: turns, end: 0).chain(CurveTween(curve: Curves.elasticOut)), weight: 55),
    ]).animate(_spin);
    _spin.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: GestureDetector(
        onTap: () {
          _wind(0.16);
          widget.onTap();
        },
        onLongPress: () {
          HapticFeedback.heavyImpact();
          _wind(1);
          showToast(context, 'Wheee! Want more of this? Settings → Navigation style → Dial menu.');
        },
        child: AnimatedBuilder(
          animation: _spin,
          builder: (BuildContext context, _) =>
              RotaryDialFace(size: widget.size, turns: _turn.value, glow: widget.selected),
        ),
      ),
    );
  }
}

/// The bar shape: rounded top corners and a soft cradle under the dial.
class _CradlePainter extends CustomPainter {
  _CradlePainter({required this.color, required this.edge});

  final Color color;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    const double corner = 26;
    const double half = 46;
    const double depth = 22;
    final double cx = size.width / 2;
    final Path top = Path()
      ..moveTo(0, corner)
      ..quadraticBezierTo(0, 0, corner, 0)
      ..lineTo(cx - half - 14, 0)
      ..cubicTo(cx - half + 6, 0, cx - half + 4, depth, cx, depth)
      ..cubicTo(cx + half - 4, depth, cx + half - 6, 0, cx + half + 14, 0)
      ..lineTo(size.width - corner, 0)
      ..quadraticBezierTo(size.width, 0, size.width, corner);
    final Path shape = Path.from(top)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawShadow(shape, Colors.black, 8, false);
    canvas.drawPath(shape, Paint()..color = color);
    canvas.drawPath(
      top,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_CradlePainter old) => old.color != color || old.edge != edge;
}

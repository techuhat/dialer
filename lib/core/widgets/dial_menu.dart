import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'nav_parts.dart';

/// Navigation as a single rotary dial. Tap it to fan the pages out around it, then tap one; or
/// hold (or drag) it, slide onto a page and let go. Letting go anywhere else closes the menu.
class DialMenu extends StatefulWidget {
  const DialMenu({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.badges = const <int, int>{},
    super.key,
  });

  static const double dialSize = 64;
  static const double _gap = 14;

  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Destination index → count shown as a red badge (e.g. unread missed calls).
  final Map<int, int> badges;

  /// Height the dial needs at the bottom of the screen, gesture inset included.
  static double clearance(BuildContext context) => dialSize + _gap * 2 + MediaQuery.paddingOf(context).bottom;

  @override
  State<DialMenu> createState() => _DialMenuState();
}

class _DialMenuState extends State<DialMenu> with TickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final DialWinder _winder = DialWinder(vsync: this);
  bool _open = false;
  bool _holding = false;
  bool _still = false;

  /// The page under the finger, and the tick lit toward it (or toward the finger between pages).
  int? _lit;
  double? _glow;

  /// The tick the ring carries while it dials a pick; [_spins] tells the newest spin apart.
  double? _dialling;
  int _spins = 0;

  @override
  void initState() {
    super.initState();
    RotaryDial.spins.addListener(_spinRound);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    RotaryDial.spins.removeListener(_spinRound);
    _winder.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _setOpen(bool open) {
    if (open == _open) return;
    if (open) {
      HapticFeedback.mediumImpact();
      _reveal.forward();
    } else {
      _holding = false;
      _reveal.reverse();
    }
    setState(() {
      _open = open;
      _lit = null;
      _glow = null;
    });
  }

  /// Dials [tick]: the ring carries it [turns] round to the finger stop and runs back, lit all
  /// the way.
  void _dial(double tick, double turns) {
    final int spin = ++_spins;
    setState(() => _dialling = tick);
    _winder.wind(turns, still: _still).whenCompleteOrCancel(() {
      if (mounted && spin == _spins) setState(() => _dialling = null);
    });
  }

  void _spinRound() => _dial(RotaryDial.tickToward(const Offset(0, -1)), 1);

  void _choose(int index) {
    HapticFeedback.lightImpact();
    final double tick = _glow ?? RotaryDial.tickToward(_Ring.directionOf(index, widget.destinations.length));
    _setOpen(false);
    _dial(tick, RotaryDial.turnsToStop(tick));
    if (index != widget.selectedIndex) widget.onSelected(index);
  }

  /// Lights a page (or none) and the ticks facing it, or facing [finger] between pages.
  void _light(int? index, {Offset? finger}) {
    final double? glow = index != null
        ? RotaryDial.tickToward(_Ring.directionOf(index, widget.destinations.length))
        : finger == null
        ? null
        : RotaryDial.tickToward(finger);
    if (index == _lit && glow == _glow) return;
    if (index != null && index != _lit) HapticFeedback.selectionClick();
    setState(() {
      _lit = index;
      _glow = glow;
    });
  }

  void _holdStart(Offset global) {
    _setOpen(true);
    setState(() => _holding = true);
    _holdMove(global);
  }

  void _holdMove(Offset global) {
    if (!_holding) return;
    final RenderBox box = context.findRenderObject()! as RenderBox;
    final _Ring ring = _Ring(box.size, MediaQuery.paddingOf(context).bottom, widget.destinations.length);
    final Offset local = box.globalToLocal(global);
    final int? page = ring.pick(local);
    final Offset fromDial = local - ring.center;
    // Between pages the light follows the finger itself, once it is off the dial.
    _light(page, finger: page == null && fromDial.distance > DialMenu.dialSize / 2 ? fromDial : null);
  }

  void _holdEnd() {
    if (!_holding) return;
    final int? target = _lit;
    if (target == null) {
      _setOpen(false);
    } else {
      _choose(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final double inset = MediaQuery.paddingOf(context).bottom;
    final NavDestination current = widget.destinations[widget.selectedIndex];
    final bool unread = widget.badges.values.any((int count) => count > 0);

    final Widget dial = Semantics(
      button: true,
      expanded: _open,
      label: 'Page menu',
      value: current.label,
      onTap: () => _setOpen(!_open),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _setOpen(!_open),
        onLongPressStart: (LongPressStartDetails details) => _holdStart(details.globalPosition),
        onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) => _holdMove(details.globalPosition),
        onLongPressEnd: (_) => _holdEnd(),
        onPanStart: (DragStartDetails details) => _holdStart(details.globalPosition),
        onPanUpdate: (DragUpdateDetails details) => _holdMove(details.globalPosition),
        onPanEnd: (_) => _holdEnd(),
        child: AnimatedBuilder(
          animation: _winder.listenable,
          builder: (BuildContext context, _) => RotaryDialFace(
            size: DialMenu.dialSize,
            turns: _winder.turns,
            glow: _open,
            dot: unread && !_open,
            light: _dialling ?? _glow,
          ),
        ),
      ),
    );

    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _setOpen(false);
      },
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final _Ring ring = _Ring(constraints.biggest, inset, widget.destinations.length);
          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _reveal,
                  builder: (BuildContext context, _) =>
                      _reveal.isDismissed ? const SizedBox.shrink() : _menu(ring, palette),
                ),
              ),
              Positioned(
                left: ring.center.dx - DialMenu.dialSize / 2,
                top: ring.center.dy - DialMenu.dialSize / 2,
                child: dial,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _menu(_Ring ring, AppPalette palette) {
    final double progress = _reveal.value;
    final String caption = _lit != null
        ? widget.destinations[_lit!].label
        : _holding
        ? 'Slide to a page'
        : 'Where to?';
    return IgnorePointer(
      ignoring: !_open,
      // Hides the page underneath from TalkBack while the menu is up.
      child: BlockSemantics(
        // The menu sits outside the page's Scaffold; this gives its text the app's style.
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTap: () => _setOpen(false),
                  child: CustomPaint(
                    painter: _WheelPainter(
                      ring: ring,
                      progress: progress,
                      disc: palette.bar,
                      edge: palette.border,
                      scrim: Theme.of(context).brightness == Brightness.dark ? 0.55 : 0.4,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: ring.center.dy - DialMenu.dialSize / 2 - 44,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Opacity(
                      opacity: const Interval(0.4, 1).transform(progress),
                      child: Text(
                        caption,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _lit != null ? palette.text : palette.muted,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              for (int i = 0; i < ring.count; i++) _hole(ring, i, progress),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hole(_Ring ring, int index, double progress) {
    final NavDestination destination = widget.destinations[index];
    final double wind = 1 - const Interval(0, 0.8, curve: Curves.easeOutCubic).transform(progress);
    final Offset slot = ring.at(ring.angle(index) + 0.6 * wind);
    final int badge = widget.badges[index] ?? 0;
    final bool current = index == widget.selectedIndex;
    // Holes pop in left to right as the wheel turns, and leave the other way.
    final double start = 0.45 * index / math.max(1, ring.count - 1);
    final double pop = Interval(start, math.min(1, start + 0.55), curve: Curves.easeOutBack).transform(progress);
    return Positioned(
      left: slot.dx - _Ring.hole / 2,
      top: slot.dy - _Ring.hole / 2,
      width: _Ring.hole,
      height: _Ring.hole,
      child: Transform.scale(
        scale: pop,
        child: Semantics(
          button: true,
          selected: current,
          label: badge > 0 ? '${destination.label}, $badge new' : destination.label,
          onTap: () => _choose(index),
          excludeSemantics: true,
          child: GestureDetector(
            onTapDown: (_) => _light(index),
            onTapCancel: () => _light(null),
            onTap: () => _choose(index),
            child: _Hole(destination: destination, current: current, lit: _lit == index, badge: badge),
          ),
        ),
      ),
    );
  }
}

/// A page in the big finger wheel; lit while a finger is on it.
class _Hole extends StatelessWidget {
  const _Hole({required this.destination, required this.current, required this.lit, required this.badge});

  final NavDestination destination;
  final bool current;
  final bool lit;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Color ink = lit
        ? Colors.white
        : current
        ? palette.accent
        : palette.text;
    return AnimatedScale(
      scale: lit ? 1.12 : 1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: lit ? null : Color.alphaBlend(palette.text.withValues(alpha: 0.07), palette.bar),
          gradient: lit ? RotaryDialFace.gradient : null,
          border: current && !lit ? Border.all(color: palette.accent, width: 2) : null,
          boxShadow: lit ? <BoxShadow>[BoxShadow(color: palette.accent.withValues(alpha: 0.5), blurRadius: 14)] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Badge(
              isLabelVisible: badge > 0,
              label: Text(badge > 99 ? '99+' : '$badge'),
              backgroundColor: palette.missed,
              child: Icon(current ? destination.selectedIcon : destination.icon, color: ink, size: 22),
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              maxLines: 1,
              softWrap: false,
              textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15),
              style: TextStyle(
                color: lit || current ? ink : palette.muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the dial and the pages sit: an even fan over the top half of the dial.
class _Ring {
  _Ring(Size size, double inset, this.count)
    : center = Offset(size.width / 2, size.height - inset - DialMenu._gap - DialMenu.dialSize / 2),
      radius = math.min(_maxRadius, (size.width / 2 - hole / 2 - _margin) / math.cos(math.pi / (2 * count)));

  static const double hole = 64;

  /// Wheel edge beyond the holes' centres.
  static const double rim = hole / 2 + 10;
  static const double _maxRadius = 136;
  static const double _margin = 14;
  static const double _deadZone = 44;

  final int count;
  final Offset center;
  final double radius;

  /// Direction of page [index] of [count], counter-clockwise from 3 o'clock.
  static double angleOf(int index, int count) => math.pi * (1 - (index + 0.5) / count);

  /// The same direction as a screen vector of length 1.
  static Offset directionOf(int index, int count) {
    final double angle = angleOf(index, count);
    return Offset(math.cos(angle), -math.sin(angle));
  }

  double angle(int index) => angleOf(index, count);

  Offset at(double angle) => center + Offset(math.cos(angle), -math.sin(angle)) * radius;

  Offset slot(int index) => at(angle(index));

  /// The page a finger at [point] points at once it has left the dial: the nearest by angle,
  /// so a slide only has to head the right way.
  int? pick(Offset point) {
    final Offset delta = point - center;
    if (delta.distance < _deadZone) return null;
    final double direction = math.atan2(-delta.dy, delta.dx);
    if (direction < -math.pi / 6 && direction > -5 * math.pi / 6) return null;
    int? best;
    double bestGap = double.infinity;
    for (int i = 0; i < count; i++) {
      final double diff = direction - angle(i);
      final double gap = math.atan2(math.sin(diff), math.cos(diff)).abs();
      if (gap < bestGap) {
        bestGap = gap;
        best = i;
      }
    }
    return best;
  }
}

/// The scrim and the big finger wheel the pages sit in, growing out of the dial.
class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.ring,
    required this.progress,
    required this.disc,
    required this.edge,
    required this.scrim,
  });

  final _Ring ring;
  final double progress;
  final Color disc;
  final Color edge;
  final double scrim;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(Colors.black.withValues(alpha: scrim * Curves.easeOut.transform(progress)), BlendMode.srcOver);
    final double grow = const Interval(0, 0.6, curve: Curves.easeOutCubic).transform(progress);
    if (grow <= 0) return;
    final double from = DialMenu.dialSize / 2;
    final double radius = from + (ring.radius + _Ring.rim - from) * grow;
    canvas.drawCircle(ring.center, radius + 1, Paint()..color = edge);
    canvas.drawCircle(ring.center, radius, Paint()..color = disc);
    // Inner edge of the finger wheel, around the dial.
    final double inner = ring.radius - _Ring.rim;
    if (radius > inner) {
      canvas.drawCircle(
        ring.center,
        inner,
        Paint()
          ..color = edge
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.progress != progress ||
      old.disc != disc ||
      old.edge != edge ||
      old.scrim != scrim ||
      old.ring.center != ring.center ||
      old.ring.radius != ring.radius;
}

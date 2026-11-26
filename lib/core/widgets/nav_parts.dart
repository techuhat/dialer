import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

class NavDestination {
  const NavDestination({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The rotary dial both navigation styles are built on, and the app's mark: a bold U in a ring
/// of tick marks. The ticks light toward the finger, and after a pick the ring runs back like an
/// old phone's finger wheel, with a haptic tick per mark.
abstract final class RotaryDial {
  /// Tick marks round the dial, like the hours on a clock.
  static const int ticks = 12;

  /// Canvas angle (clockwise from 3 o'clock) where an old dial's finger stop sat; a pick winds
  /// the lit tick round to it and back.
  static const double stopAngle = 0.55;
  static const double _step = 2 * math.pi / ticks;

  /// Ring turns from one tick to the next.
  static const double tickTurns = 1 / ticks;

  /// Bumped to spin the dial on screen once all the way round, e.g. for the 1985 easter egg.
  static final ValueNotifier<int> spins = ValueNotifier<int>(0);

  /// Resting angle of tick [index] (fractional between neighbours), clockwise from 3 o'clock;
  /// tick 0 points up.
  static double angleOf(double index) => -math.pi / 2 + _step * index;

  /// The tick, fractional between neighbours (0 up to [ticks]), facing [direction], a screen
  /// vector from the centre.
  static double tickToward(Offset direction) =>
      (math.atan2(direction.dy, direction.dx) + math.pi / 2) % (2 * math.pi) / _step;

  /// Ring turns that carry tick [index] clockwise to the finger stop, as dialling it would.
  static double turnsToStop(double index) => (stopAngle - angleOf(index)) % (2 * math.pi) / (2 * math.pi);
}

/// Winds a dial's ring and lets it run back, the way an old phone's finger wheel returns after a
/// digit, with a light haptic tick each time a tick mark goes by.
class DialWinder {
  DialWinder({required TickerProvider vsync}) : _controller = AnimationController(vsync: vsync) {
    _controller.addListener(_onFrame);
  }

  /// A finger pulls a full turn in this long; the ring runs back one tick in [_runPerTick].
  static const double _pullPerTurn = 700;
  static const double _runPerTick = 95;

  final AnimationController _controller;
  Animation<double> _turns = const AlwaysStoppedAnimation<double>(0);

  /// Controller value where the run back starts; haptic ticks only play after it.
  double _runFrom = 1;
  int _ticksLeft = 0;

  Listenable get listenable => _controller;

  /// Ring rotation now, in full turns clockwise.
  double get turns => _turns.value;

  /// Winds [turns] and runs back. With [still] (reduced motion) the ring does not move and only
  /// the haptic tick plays.
  TickerFuture wind(double turns, {required bool still}) {
    if (still || turns <= 0) {
      HapticFeedback.selectionClick();
      return TickerFuture.complete();
    }
    final double pull = math.max(140, turns * _pullPerTurn);
    final double run = math.max(220, turns / RotaryDial.tickTurns * _runPerTick);
    _runFrom = pull / (pull + run);
    _ticksLeft = (turns / RotaryDial.tickTurns).floor();
    _controller.duration = Duration(milliseconds: (pull + run).round());
    _turns = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0, end: turns).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: pull,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: turns, end: 0).chain(CurveTween(curve: Curves.easeOutSine)),
        weight: run,
      ),
    ]).animate(_controller);
    return _controller.forward(from: 0);
  }

  void _onFrame() {
    if (_controller.value < _runFrom) return;
    final int left = (_turns.value / RotaryDial.tickTurns).floor();
    if (left >= _ticksLeft) return;
    _ticksLeft = left;
    HapticFeedback.selectionClick();
  }

  void dispose() => _controller.dispose();
}

/// The rotary dial button: [DialMarkPainter]'s mark on a glowing disc. [light] is the lit tick
/// (fractional between neighbours), [turns] the ring's rotation.
class RotaryDialFace extends StatelessWidget {
  const RotaryDialFace({
    required this.size,
    this.turns = 0,
    this.glow = false,
    this.dot = false,
    this.light,
    super.key,
  });

  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF4FA8F5), Color(0xFF1E6FD9)],
  );

  final double size;

  /// Ring rotation in full turns, clockwise (the way you dial).
  final double turns;
  final bool glow;

  /// Small red dot, e.g. for unread missed calls.
  final bool dot;

  /// The lit tick, null for the resting pointer at the top. It turns with the ring.
  final double? light;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.accent.withValues(alpha: glow ? 0.55 : 0.3),
            blurRadius: glow ? 18 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(child: CustomPaint(painter: DialMarkPainter(turns: turns, light: light))),
          if (dot)
            Positioned(
              top: size * 0.04,
              right: size * 0.04,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: palette.missed,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The dial's mark, which is the app icon too: a bold U inside a ring of tick marks, on the blue
/// disc when [disc] is set. The lit tick glows and reaches further in; with no [light] the top
/// tick does, as the resting pointer.
class DialMarkPainter extends CustomPainter {
  const DialMarkPainter({this.turns = 0, this.light, this.disc = true, this.monochrome = false});

  final double turns;
  final double? light;
  final bool disc;

  /// Plain white without glow, for Android's themed (tinted) icon.
  final bool monochrome;

  /// How many ticks either side of the lit one catch some of its light.
  static const double _spread = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;
    if (disc) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..shader = RotaryDialFace.gradient.createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
    _ticks(canvas, center, radius);
    _letter(canvas, center, radius);
  }

  void _ticks(Canvas canvas, Offset center, double radius) {
    final double width = radius * 0.07;
    final double? lit = light;
    // While a tick is lit the others dim, so the pointer reads at a glance even on a small dial.
    final double rest = monochrome ? 1 : (lit == null ? 0.55 : 0.32);
    for (int i = 0; i < RotaryDial.ticks; i++) {
      final double glow;
      if (lit == null) {
        glow = i == 0 ? 1 : 0;
      } else {
        final double gap = (i - lit).abs() % RotaryDial.ticks;
        final double near = math.max(0, 1 - math.min(gap, RotaryDial.ticks - gap) / _spread);
        glow = near * near;
      }
      final double angle = RotaryDial.angleOf(i.toDouble()) + turns * 2 * math.pi;
      final Offset direction = Offset(math.cos(angle), math.sin(angle));
      final Offset outer = center + direction * radius * 0.88;
      final Offset inner = center + direction * radius * (0.73 - 0.09 * glow);
      if (glow > 0 && !monochrome) {
        canvas.drawLine(
          inner,
          outer,
          Paint()
            ..color = AppPalette.dark.signal.withValues(alpha: 0.9 * glow)
            ..strokeWidth = width * 2.6
            ..strokeCap = StrokeCap.round
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.07),
        );
      }
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = Colors.white.withValues(alpha: rest + (1 - rest) * glow)
          ..strokeWidth = width * (1 + 0.25 * glow)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// A geometric U: two straight arms and a round bowl, drawn as one thick stroke.
  void _letter(Canvas canvas, Offset center, double radius) {
    final double stroke = radius * 0.17;
    final double half = radius * 0.27 - stroke / 2;
    final double top = center.dy - radius * 0.32;
    final double bend = center.dy + radius * 0.04;
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - half, top)
        ..lineTo(center.dx - half, bend)
        ..arcToPoint(Offset(center.dx + half, bend), radius: Radius.circular(half), clockwise: false)
        ..lineTo(center.dx + half, top),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(DialMarkPainter old) =>
      old.turns != turns || old.light != light || old.disc != disc || old.monochrome != monochrome;
}

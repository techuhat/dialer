import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../theme.dart';

/// "Add contact" glyph: a person and a plus drawn as a glowing cyan-to-blue outline. When [active]
/// turns on it draws itself in behind a scan line, like a hologram; inactive it rests dimmed.
class AddContactIcon extends StatefulWidget {
  const AddContactIcon({this.size = 28, this.active = true, super.key});

  final double size;
  final bool active;

  @override
  State<AddContactIcon> createState() => _AddContactIconState();
}

class _AddContactIconState extends State<AddContactIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
    value: 1,
  );
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(AddContactIcon old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !_still) _draw.forward(from: 0);
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _draw,
        builder: (BuildContext context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _AddContactPainter(
            progress: _draw.value,
            from: palette.signal,
            to: palette.accent,
            opacity: widget.active ? 1 : 0.38,
          ),
        ),
      ),
    );
  }
}

class _AddContactPainter extends CustomPainter {
  _AddContactPainter({required this.progress, required this.from, required this.to, required this.opacity});

  final double progress;
  final Color from;
  final Color to;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final Path person = Path()
      ..addOval(Rect.fromCircle(center: Offset(s * 0.36, s * 0.32), radius: s * 0.15))
      ..addArc(Rect.fromLTRB(s * 0.08, s * 0.6, s * 0.64, s * 1.14), math.pi, math.pi);
    final double reveal = Curves.easeInOut.transform(const Interval(0, 0.8).transform(progress));
    final Path drawn = reveal >= 1 ? person : _partial(person, reveal);

    final Paint glow = Paint()
      ..color = from.withValues(alpha: 0.45 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.11
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.06);
    final Paint line = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          from.withValues(alpha: opacity),
          to.withValues(alpha: opacity),
        ],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.075
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(drawn, glow)
      ..drawPath(drawn, line);

    // The plus pops in once the outline is nearly done.
    final double pop = const Interval(0.55, 1, curve: Curves.easeOutBack).transform(progress);
    if (pop > 0) {
      final Offset plus = Offset(s * 0.81, s * 0.42);
      final double arm = s * 0.13 * pop;
      final Path cross = Path()
        ..moveTo(plus.dx - arm, plus.dy)
        ..lineTo(plus.dx + arm, plus.dy)
        ..moveTo(plus.dx, plus.dy - arm)
        ..lineTo(plus.dx, plus.dy + arm);
      canvas
        ..drawPath(cross, glow)
        ..drawPath(cross, line);
    }

    // The scan line sweeping down while it materialises.
    if (progress < 1) {
      final double y = s * (0.04 + 0.92 * progress);
      canvas.drawLine(
        Offset(0, y),
        Offset(s, y),
        Paint()
          ..color = from.withValues(alpha: 0.7 * (1 - progress) * opacity)
          ..strokeWidth = s * 0.035,
      );
    }
  }

  static Path _partial(Path path, double fraction) {
    final Path part = Path();
    for (final PathMetric metric in path.computeMetrics()) {
      part.addPath(metric.extractPath(0, metric.length * fraction), Offset.zero);
    }
    return part;
  }

  @override
  bool shouldRepaint(_AddContactPainter old) =>
      old.progress != progress || old.from != from || old.to != to || old.opacity != opacity;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class NavDestination {
  const NavDestination({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// An old rotary phone dial, used by both navigation styles. As on the real thing only the
/// finger wheel turns; the finger stop and the centre card stay put.
class RotaryDialFace extends StatelessWidget {
  const RotaryDialFace({
    required this.size,
    this.turns = 0,
    this.glow = false,
    this.dot = false,
    this.center,
    super.key,
  });

  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF4FA8F5), Color(0xFF1E6FD9)],
  );

  final double size;

  /// Finger wheel rotation in full turns, clockwise (the way you dial).
  final double turns;
  final bool glow;

  /// Small red dot, e.g. for unread missed calls.
  final bool dot;

  /// Shown on the centre card, e.g. the current page's icon.
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
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
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _DialFacePainter(turns: turns, card: center != null),
            ),
          ),
          if (center != null)
            Container(
              width: size * 0.44,
              height: size * 0.44,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.22)),
              child: center,
            ),
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

class _DialFacePainter extends CustomPainter {
  _DialFacePainter({required this.turns, required this.card});

  static const int _holes = 10;
  static const double _sweep = 1.65 * math.pi;
  static const double _stopAngle = 0.55;

  final double turns;
  final bool card;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.width / 2;
    final Paint white = Paint()..color = Colors.white;
    final Paint hole = Paint()..color = Colors.white.withValues(alpha: 0.9);
    // The gap without holes sits around the finger stop.
    final double first = _stopAngle + (2 * math.pi - _sweep) / 2 + turns * 2 * math.pi;
    for (int i = 0; i < _holes; i++) {
      final double angle = first + _sweep * i / (_holes - 1);
      canvas.drawCircle(center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.64, radius * 0.115, hole);
    }
    if (!card) {
      canvas.drawCircle(center, radius * 0.26, Paint()..color = Colors.white.withValues(alpha: 0.22));
      canvas.drawCircle(center, radius * 0.09, white);
    }
    final Offset stop = Offset(math.cos(_stopAngle), math.sin(_stopAngle));
    canvas.drawLine(
      center + stop * radius * 0.82,
      center + stop * radius * 0.98,
      white
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DialFacePainter old) => old.turns != turns || old.card != card;
}

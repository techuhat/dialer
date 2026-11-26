import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/contact_photo_settings.dart';
import '../../core/services/caller_details.dart';
import '../../core/theme.dart';
import '../../core/widgets/photo_backdrop.dart';
import 'call_widgets.dart';

/// Call screen scaffold over [CallerBackdrop].
class CallBackground extends StatelessWidget {
  const CallBackground({required this.details, required this.child, this.reveal = false, super.key});

  final CallerDetails details;
  final Widget child;

  /// See [CallerBackdrop.reveal].
  final bool reveal;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: CallColors.bottom,
      ),
      child: Scaffold(
        backgroundColor: CallColors.top,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CallerBackdrop(details: details, reveal: reveal),
            SafeArea(child: child),
          ],
        ),
      ),
    );
  }
}

/// The caller's photo staged by [PhotoStyle]: a sharp photo fills the screen as a poster, a small one
/// becomes a wash of its colours behind its circle, and without one the brand gradient shows. The
/// contact photo preview uses it too, so what is set there is what a call shows.
class CallerBackdrop extends StatelessWidget {
  const CallerBackdrop({required this.details, this.reveal = false, super.key});

  final CallerDetails details;

  /// Scan the poster in when it first shows: for a call that is ringing or being placed.
  final bool reveal;

  /// Overlay for contacts without saved photo settings; the scrim keeps text legible on its own.
  static const double defaultOverlay = 0.2;

  /// Dark behind the name at the top and behind the controls at the bottom, which have the same
  /// height on every phone, and clear over the face in between.
  static LinearGradient _scrim(double height) {
    final double h = math.max(height, 1);
    final List<double> stops = <double>[0, 140, 250, h - 400, h - 330, h - 240, h]
        .map((double dp) => (dp / h).clamp(0.0, 1.0))
        .toList();
    for (int i = 1; i < stops.length; i++) {
      stops[i] = math.max(stops[i], stops[i - 1]);
    }
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: stops,
      colors: const <Color>[
        Color(0xB3000000),
        Color(0x80000000),
        Color(0x00000000),
        Color(0x00000000),
        Color(0x73000000),
        Color(0xC7000000),
        Color(0xEB000000),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Uint8List? photo = details.photo;
    if (photo == null) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[CallColors.top, CallColors.bottom],
          ),
        ),
      );
    }
    final bool poster = details.photoStyle == PhotoStyle.poster;
    return _ScanReveal(
      play: reveal && poster,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          PhotoBackdrop(
            photo: photo,
            settings: details.photoSettings,
            defaultOverlay: defaultOverlay,
            topShade: 1,
            wash: !poster,
            backgroundColor: CallColors.top,
          ),
          // The wash sits behind the centred name, where the scrim is clear.
          if (!poster) const ColoredBox(color: Color(0x73000000)),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) =>
                DecoratedBox(decoration: BoxDecoration(gradient: _scrim(constraints.maxHeight))),
          ),
        ],
      ),
    );
  }
}

/// Shows [child] top to bottom behind a glowing scan line, once, if [play] is set when it first
/// builds; with reduced motion it shows at once.
class _ScanReveal extends StatefulWidget {
  const _ScanReveal({required this.play, required this.child});

  final bool play;
  final Widget child;

  @override
  State<_ScanReveal> createState() => _ScanRevealState();
}

class _ScanRevealState extends State<_ScanReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _scan =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700), value: 1);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.play && !MediaQuery.disableAnimationsOf(context)) _scan.forward(from: 0);
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scan,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final bool done = _scan.value >= 1;
        final double edge = Curves.easeOutCubic.transform(_scan.value);
        return CustomPaint(
          foregroundPainter: done ? null : _ScanLinePainter(edge),
          child: ClipRect(
            clipper: _RevealClipper(edge),
            clipBehavior: done ? Clip.none : Clip.hardEdge,
            child: child,
          ),
        );
      },
    );
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  const _RevealClipper(this.edge);

  final double edge;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, 0, size.width, size.height * edge);

  @override
  bool shouldReclip(_RevealClipper oldClipper) => oldClipper.edge != edge;
}

/// The scan line at the reveal edge: a trail of signal light over a bright core, fading at the end.
class _ScanLinePainter extends CustomPainter {
  _ScanLinePainter(this.edge);

  final double edge;
  static const double _trail = 96;

  @override
  void paint(Canvas canvas, Size size) {
    final Color signal = AppPalette.dark.signal;
    final double y = size.height * edge;
    final double fade = edge > 0.85 ? (1 - edge) / 0.15 : 1;
    final Rect trail = Rect.fromLTRB(0, y - _trail, size.width, y);
    canvas.drawRect(
      trail,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[signal.withValues(alpha: 0), signal.withValues(alpha: 0.22 * fade)],
        ).createShader(trail),
    );
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = signal.withValues(alpha: 0.85 * fade)
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = Colors.white.withValues(alpha: fade)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_ScanLinePainter oldDelegate) => oldDelegate.edge != edge;
}

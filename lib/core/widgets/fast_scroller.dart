import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// A thumb on the right edge of a long list to drag through it quickly, with a bubble naming
/// where you are (a day in Recents, a letter in Contacts). It shows while the list moves and
/// fades once it rests. Only the thumb takes touches, so the rows under it stay usable.
class FastScroller extends StatefulWidget {
  const FastScroller({required this.controller, required this.child, this.labelAt, super.key});

  final ScrollController controller;

  /// The scroll view [controller] drives.
  final Widget child;

  /// Names the part of the list at [fraction] (0 is the top, 1 the end), for the bubble.
  final String? Function(double fraction)? labelAt;

  @visibleForTesting
  static const Key thumbKey = ValueKey<String>('fastScrollerThumb');

  /// For lists of rows under String headings: the heading over the row at [fraction].
  static String? headingAt(List<Object> rows, double fraction) {
    if (rows.isEmpty) return null;
    for (int i = (fraction.clamp(0.0, 1.0) * (rows.length - 1)).round(); i >= 0; i--) {
      final Object row = rows[i];
      if (row is String) return row;
    }
    return null;
  }

  @override
  State<FastScroller> createState() => _FastScrollerState();
}

class _FastScrollerState extends State<FastScroller> with SingleTickerProviderStateMixin {
  static const double _thumbHeight = 52;

  /// The touch area round the thumb, bigger than the thumb itself.
  static const double _touchWidth = 44;
  static const double _touchSlack = 12;

  /// Lists shorter than this many screens scroll well enough by hand and get no thumb.
  static const double _minScreens = 3;

  // Created up front: a short list never shows the thumb, and dispose still needs a controller.
  late final AnimationController _fade;
  Timer? _hide;
  bool _dragging = false;

  /// Where on the thumb the finger took hold, so the thumb does not jump under it.
  double _grab = 0;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 400),
    );
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(FastScroller old) {
    super.didUpdateWidget(old);
    if (old.controller == widget.controller) return;
    old.controller.removeListener(_onScroll);
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    _hide?.cancel();
    _fade.dispose();
    super.dispose();
  }

  ScrollPosition? get _long {
    if (!widget.controller.hasClients) return null;
    final ScrollPosition position = widget.controller.position;
    if (!position.hasContentDimensions) return null;
    return position.maxScrollExtent > position.viewportDimension * (_minScreens - 1) ? position : null;
  }

  double _fractionOf(ScrollPosition position) =>
      position.maxScrollExtent <= 0 ? 0 : (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0);

  void _onScroll() {
    if (_long == null) return;
    setState(() {});
    _show();
  }

  void _show() {
    _fade.forward();
    _hide?.cancel();
    if (_dragging) return;
    _hide = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) _fade.reverse();
    });
  }

  double _localY(Offset global) => (context.findRenderObject()! as RenderBox).globalToLocal(global).dy;

  void _start(DragStartDetails details, double thumbTop) {
    HapticFeedback.selectionClick();
    _grab = _localY(details.globalPosition) - thumbTop;
    setState(() => _dragging = true);
    _show();
  }

  void _move(DragUpdateDetails details, double track) {
    final ScrollPosition? position = _long;
    if (position == null) return;
    final double top = _localY(details.globalPosition) - _grab;
    position.jumpTo((top / (track - _thumbHeight)).clamp(0.0, 1.0) * position.maxScrollExtent);
  }

  void _end() {
    setState(() => _dragging = false);
    _show();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double track = constraints.maxHeight;
        final ScrollPosition? position = track > _thumbHeight * 2 ? _long : null;
        final double fraction = position == null ? 0 : _fractionOf(position);
        final double top = fraction * (track - _thumbHeight);
        final String? label = _dragging ? widget.labelAt?.call(fraction) : null;
        return Stack(
          children: <Widget>[
            widget.child,
            if (position != null)
              Positioned(
                key: FastScroller.thumbKey,
                right: 0,
                top: top - _touchSlack,
                width: _touchWidth,
                height: _thumbHeight + _touchSlack * 2,
                child: ExcludeSemantics(
                  child: FadeTransition(
                    opacity: _fade,
                    // A hidden thumb lets taps through to the row under it.
                    child: AnimatedBuilder(
                      animation: _fade,
                      builder: (BuildContext context, Widget? child) =>
                          IgnorePointer(ignoring: _fade.isDismissed, child: child),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragStart: (DragStartDetails details) => _start(details, top),
                        onVerticalDragUpdate: (DragUpdateDetails details) => _move(details, track),
                        onVerticalDragEnd: (_) => _end(),
                        onVerticalDragCancel: _end,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 3),
                            width: _dragging ? 8 : 5,
                            height: _thumbHeight,
                            decoration: BoxDecoration(
                              color: _dragging ? palette.accent : palette.muted.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (label != null)
              Positioned(
                right: _touchWidth + 4,
                top: (top + _thumbHeight / 2 - 22).clamp(0.0, track - 44),
                child: ExcludeSemantics(child: _Bubble(label: label)),
              ),
          ],
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.of(context).accent,
      borderRadius: BorderRadius.circular(22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

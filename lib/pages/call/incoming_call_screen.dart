import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../core/call_manager.dart';
import '../../core/call_router.dart';
import '../../core/call_service.dart';
import '../../core/models/live_call.dart';
import '../../core/services/caller_details.dart';
import '../../core/widgets/app_sheet.dart';
import 'call_widgets.dart';

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  static const List<String> _quickReplies = <String>[
    "Can't talk now. What's up?",
    "I'll call you right back.",
    "I'll call you later.",
    "Can't talk now. Call me later?",
  ];

  LiveCall? _call;
  bool _busy = false;

  Future<void> _answer() async {
    if (_busy) return;
    setState(() => _busy = true);
    if (await CallService.answer()) {
      CallRouter.instance.showInCall();
      return;
    }
    _fail("Couldn't answer the call");
  }

  Future<void> _decline({String? message}) async {
    if (_busy) return;
    setState(() => _busy = true);
    if (await CallService.reject(message: message)) {
      CallRouter.instance.goHome();
      return;
    }
    _fail("Couldn't decline the call");
  }

  Future<void> _reply() async {
    final LiveCall? call = _call;
    if (call == null || call.number.isEmpty) return;
    final String? choice = await showAppSheet<String>(
      context,
      background: CallColors.sheet,
      builder: (BuildContext context) => ListView(
        shrinkWrap: true,
        children: <Widget>[
          const CallSheetTitle('Reply with a message'),
          for (final String reply in _quickReplies) _replyTile(context, reply, reply),
          _replyTile(context, 'Write your own…', '', icon: Icons.edit_outlined),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice.isEmpty) {
      await _decline();
      await CallService.composeSms(call.number);
    } else {
      await _decline(message: choice);
    }
  }

  Widget _replyTile(BuildContext context, String title, String value, {IconData icon = Icons.chat_bubble_outline}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, color: CallColors.subtle),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      onTap: () => Navigator.of(context).pop(value),
    );
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: ListenableBuilder(
        listenable: CallManager.instance,
        builder: (BuildContext context, _) {
          final LiveCall? call = CallManager.instance.ringing ?? _call;
          _call = call;
          if (call == null) return const ColoredBox(color: CallColors.top);
          return CallerDetailsBuilder(
            number: call.number,
            builder: (BuildContext context, CallerDetails details) => CallBackground(
              details: details,
              child: _layout(call, details),
            ),
          );
        },
      ),
    );
  }

  Widget _layout(LiveCall call, CallerDetails details) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: <Widget>[
          Text(
            <String>['Incoming call', ?call.simLabel].join(' · '),
            style: const TextStyle(color: CallColors.subtle, fontSize: 15, letterSpacing: 0.4),
          ),
          // Shrinks the caller block on short screens instead of overflowing.
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) => FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: CallerHeader(
                    name: call.displayName,
                    details: details,
                    subtitle: CallerHeader.subtitleFor(call, details),
                    avatarSize: 104,
                    halo: true,
                  ),
                ),
              ),
            ),
          ),
          AnswerSwipe(enabled: !_busy, onAnswer: _answer, onDecline: _decline),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              RoundCallButton(
                icon: Icons.call_end_rounded,
                color: CallColors.decline,
                label: 'Decline',
                size: 60,
                onPressed: _busy ? null : _decline,
              ),
              RoundCallButton(
                icon: Icons.chat_bubble_outline_rounded,
                color: Colors.white.withValues(alpha: 0.16),
                label: 'Message',
                size: 60,
                onPressed: _busy || call.number.isEmpty ? null : _reply,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pixel-style answer handle: swipe up to answer, down to decline, tap for a hint.
class AnswerSwipe extends StatefulWidget {
  const AnswerSwipe({required this.onAnswer, required this.onDecline, this.enabled = true, super.key});

  final VoidCallback onAnswer;
  final VoidCallback onDecline;
  final bool enabled;

  @override
  State<AnswerSwipe> createState() => _AnswerSwipeState();
}

class _AnswerSwipeState extends State<AnswerSwipe> with TickerProviderStateMixin {
  static const double _handle = 76;
  static const double _upRange = 110;
  static const double _downRange = 80;
  static const double _commit = 0.6;
  static const double _flingVelocity = 900;

  late final AnimationController _idle =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  late final AnimationController _settle =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  Animation<double>? _settleTween;
  double _offset = 0;
  bool _hinting = false;

  @override
  void initState() {
    super.initState();
    _settle.addListener(() {
      final Animation<double>? tween = _settleTween;
      if (tween != null) setState(() => _offset = tween.value);
    });
  }

  @override
  void dispose() {
    _idle.dispose();
    _settle.dispose();
    super.dispose();
  }

  void _animateTo(double target, {VoidCallback? then, Curve curve = Curves.easeOutCubic}) {
    _settleTween = Tween<double>(begin: _offset, end: target).animate(CurvedAnimation(parent: _settle, curve: curve));
    _settle.forward(from: 0).whenComplete(() => then?.call());
  }

  void _onDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    if (_offset <= -_upRange * _commit || velocity < -_flingVelocity) {
      HapticFeedback.mediumImpact();
      _animateTo(-_upRange, then: widget.onAnswer);
    } else if (_offset >= _downRange * _commit || velocity > _flingVelocity) {
      HapticFeedback.mediumImpact();
      _animateTo(_downRange, then: widget.onDecline);
    } else {
      _animateTo(0, curve: Curves.easeOutBack);
    }
  }

  void _nudge() {
    HapticFeedback.selectionClick();
    setState(() => _hinting = true);
    _animateTo(-28, then: () => _animateTo(0, curve: Curves.easeOutBack));
  }

  @override
  Widget build(BuildContext context) {
    final double up = (-_offset / _upRange).clamp(0.0, 1.0);
    final double down = (_offset / _downRange).clamp(0.0, 1.0);
    final Color color = Color.lerp(CallColors.accept, CallColors.decline, down)!;
    final String hint = down > _commit
        ? 'Release to decline'
        : up > _commit
            ? 'Release to answer'
            : _hinting
                ? 'Swipe up to answer · down to decline'
                : 'Swipe up to answer';

    return Semantics(
      button: true,
      label: 'Answer call',
      hint: 'Swipe up to answer, swipe down to decline',
      onTap: widget.enabled ? widget.onAnswer : null,
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        const CustomSemanticsAction(label: 'Decline'): widget.onDecline,
      },
      excludeSemantics: true,
      child: SizedBox(
        height: _upRange + _handle + 36,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              bottom: _handle + 8,
              child: Opacity(opacity: (1 - up * 2 - down * 2).clamp(0.0, 1.0), child: _Chevrons(animation: _idle)),
            ),
            Positioned(
              bottom: -2,
              child: Text(hint, style: const TextStyle(color: CallColors.subtle, fontSize: 13)),
            ),
            Positioned(
              bottom: 22 - _offset,
              child: GestureDetector(
                onTap: widget.enabled ? _nudge : null,
                onVerticalDragStart: widget.enabled ? (_) => _settle.stop() : null,
                onVerticalDragUpdate: widget.enabled
                    ? (DragUpdateDetails d) =>
                        setState(() => _offset = (_offset + d.delta.dy).clamp(-_upRange, _downRange))
                    : null,
                onVerticalDragEnd: widget.enabled ? _onDragEnd : null,
                child: AnimatedBuilder(
                  animation: _idle,
                  builder: (BuildContext context, Widget? child) {
                    final double pulse = _offset == 0 ? Curves.easeOut.transform(_idle.value) : 0;
                    return Container(
                      width: _handle,
                      height: _handle,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: color.withValues(alpha: 0.45 * (1 - pulse)),
                            blurRadius: 4,
                            spreadRadius: 18 * pulse,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Transform.rotate(
                    angle: down * 2.36,
                    child: const Icon(Icons.call_rounded, color: Colors.white, size: 34),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chevrons extends StatelessWidget {
  const _Chevrons({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 2; i >= 0; i--)
            Opacity(
              opacity: 0.2 + 0.8 * (1 - ((animation.value * 3 - i) % 3 / 3)).clamp(0.0, 1.0),
              child: const Align(
                heightFactor: 0.6,
                child: Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 28),
              ),
            ),
        ],
      ),
    );
  }
}

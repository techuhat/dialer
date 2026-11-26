import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/live_call.dart';
import '../../core/services/caller_details.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/contact_avatar.dart';
import '../../core/widgets/photo_backdrop.dart';

abstract final class CallColors {
  static const Color top = Color(0xFF0A1929);
  static const Color bottom = Color(0xFF15324F);
  static const Color sheet = Color(0xFF112840);
  static const Color accept = Color(0xFF1E8E3E);
  static const Color decline = Color(0xFFD93025);
  static const Color accent = Color(0xFF8AB4F8);
  static const Color hold = Color(0xFFFDD663);
  static const Color subtle = Color(0xB3FFFFFF);
}

/// Loads [CallerDetails] for [number] and rebuilds when it arrives or the number changes.
class CallerDetailsBuilder extends StatefulWidget {
  const CallerDetailsBuilder({required this.number, required this.builder, super.key});

  final String number;
  final Widget Function(BuildContext context, CallerDetails details) builder;

  @override
  State<CallerDetailsBuilder> createState() => _CallerDetailsBuilderState();
}

class _CallerDetailsBuilderState extends State<CallerDetailsBuilder> {
  late CallerDetails _details;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(CallerDetailsBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!PhoneUtils.isSameNumber(oldWidget.number, widget.number)) _resolve();
  }

  void _resolve() {
    final String number = widget.number;
    _details = CallerDetails.cached(number) ?? CallerDetails(number: number);
    if (number.isEmpty || CallerDetails.cached(number) != null) return;
    CallerDetails.load(number).then((CallerDetails details) {
      if (mounted && widget.number == number) setState(() => _details = details);
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _details);
}

/// Dark call backdrop: the contact photo when there is one, the brand gradient otherwise.
class CallBackground extends StatelessWidget {
  const CallBackground({required this.details, required this.child, super.key});

  final CallerDetails details;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Uint8List? photo = details.photo;
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
            if (photo == null)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[CallColors.top, CallColors.bottom],
                  ),
                ),
              )
            else
              PhotoBackdrop(photo: photo, settings: details.photoSettings, defaultOverlay: 0.55),
            SafeArea(child: child),
          ],
        ),
      ),
    );
  }
}

/// Avatar, name and the line under it.
class CallerHeader extends StatelessWidget {
  const CallerHeader({
    required this.name,
    required this.details,
    this.subtitle,
    this.status,
    this.avatarSize = 112,
    this.halo = false,
    super.key,
  });

  final String name;
  final CallerDetails details;
  final String? subtitle;
  final Widget? status;
  final double avatarSize;

  /// Pulsing rings around the avatar while a call rings.
  final bool halo;

  @override
  Widget build(BuildContext context) {
    final Widget avatar = ContactAvatar(name: name, photo: details.photo, size: avatarSize);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (halo) _Halo(size: avatarSize, child: avatar) else avatar,
        const SizedBox(height: 20),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w500, height: 1.15),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: CallColors.subtle, fontSize: 16, letterSpacing: 0.2),
          ),
        ],
        if (status != null) ...<Widget>[const SizedBox(height: 12), status!],
      ],
    );
  }

  /// "Mobile · +91 98765 43210" for contacts, the formatted number for everyone else.
  static String? subtitleFor(LiveCall call, CallerDetails details) {
    if (call.number.isEmpty || call.isConference) return null;
    final String formatted = PhoneUtils.formatPhoneNumber(call.number);
    if (call.displayName == formatted) return null;
    if (call.isNetworkName) return '$formatted · Caller ID by network';
    final String? label = details.phoneLabel;
    return label == null || label.isEmpty ? formatted : '$label · $formatted';
  }
}

class _Halo extends StatefulWidget {
  const _Halo({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  State<_Halo> createState() => _HaloState();
}

class _HaloState extends State<_Halo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double extent = widget.size * 1.5;
    return SizedBox.square(
      dimension: extent,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          for (final double offset in const <double>[0, 0.5])
            AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? child) {
                final double t = (_controller.value + offset) % 1;
                return Container(
                  width: widget.size * (1 + 0.5 * t),
                  height: widget.size * (1 + 0.5 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.14 * (1 - t)),
                  ),
                );
              },
            ),
          widget.child,
        ],
      ),
    );
  }
}

/// Status under the caller name; only the timer text rebuilds every second.
class CallStatusLine extends StatelessWidget {
  const CallStatusLine({this.call, this.ended, super.key});

  final LiveCall? call;
  final EndedCall? ended;

  @override
  Widget build(BuildContext context) {
    final EndedCall? endedCall = ended;
    if (endedCall != null) {
      final Duration? duration = endedCall.duration;
      return _text(duration == null ? 'Call ended' : 'Call ended · ${TimeUtils.formatClock(duration)}', CallColors.decline);
    }
    final LiveCall? current = call;
    if (current == null) return _text('Connecting…');
    return switch (current.phase) {
      CallPhase.active when current.connectedAt != null => CallTimer(since: current.connectedAt!),
      CallPhase.active => _text('Connected'),
      CallPhase.ringing => _text('Connecting…'),
      CallPhase.dialing => _text('Calling…'),
      CallPhase.selectSim => _text('Choose a SIM'),
      CallPhase.holding => _text('On hold', CallColors.hold),
      CallPhase.disconnecting || CallPhase.disconnected => _text('Hanging up…'),
    };
  }

  static Widget _text(String value, [Color color = CallColors.subtle]) => Text(
        value,
        style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.3),
      );
}

class CallTimer extends StatefulWidget {
  const CallTimer({required this.since, super.key});

  final DateTime since;

  @override
  State<CallTimer> createState() => _CallTimerState();
}

class _CallTimerState extends State<CallTimer> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
        TimeUtils.formatClock(DateTime.now().difference(widget.since)),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w500,
          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        ),
      );
}

/// Small pills: SIM, HD voice, Wi-Fi calling.
class CallBadges extends StatelessWidget {
  const CallBadges({required this.call, super.key});

  final LiveCall call;

  @override
  Widget build(BuildContext context) {
    final List<(IconData, String)> badges = <(IconData, String)>[
      if (call.simLabel != null) (Icons.sim_card_outlined, call.simLabel!),
      if (call.isHd) (Icons.hd_outlined, 'HD voice'),
      if (call.isWifi) (Icons.wifi_calling_3_rounded, 'Wi-Fi call'),
    ];
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final (IconData icon, String label) in badges)
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 14, color: CallColors.subtle),
                  const SizedBox(width: 6),
                  Text(label, style: const TextStyle(color: CallColors.subtle, fontSize: 12.5)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Round toggle with a caption, the building block of the in-call control grid.
class CallControlButton extends StatelessWidget {
  const CallControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.badge = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? press = onPressed;
    final VoidCallback? tap = press == null
        ? null
        : () {
            HapticFeedback.selectionClick();
            press();
          };
    return Semantics(
      button: true,
      toggled: active,
      enabled: tap != null,
      label: label,
      onTap: tap,
      excludeSemantics: true,
      child: Opacity(
        opacity: tap != null ? 1 : 0.38,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: tap,
          child: SizedBox(
            width: 84,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Badge(
                    isLabelVisible: badge,
                    smallSize: 10,
                    backgroundColor: CallColors.accent,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active ? Colors.white : Colors.white.withValues(alpha: 0.12),
                      ),
                      child: Icon(icon, size: 28, color: active ? CallColors.top : Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Large coloured action: end call, answer, decline.
class RoundCallButton extends StatelessWidget {
  const RoundCallButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    this.label,
    this.semanticLabel,
    this.size = 72,
    super.key,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  /// Caption shown under the button.
  final String? label;

  /// What TalkBack says when there is no caption.
  final String? semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget button = Material(
      color: onPressed == null ? color.withValues(alpha: 0.4) : color,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox.square(dimension: size, child: Icon(icon, color: Colors.white, size: size * 0.42)),
      ),
    );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label ?? semanticLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: label == null
          ? button
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                button,
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPressed,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Text(
                      label!,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Section heading used inside the dark call sheets.
class CallSheetTitle extends StatelessWidget {
  const CallSheetTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
      );
}

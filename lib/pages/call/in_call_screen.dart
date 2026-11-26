import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/call_manager.dart';
import '../../core/call_service.dart';
import '../../core/models/call_note.dart';
import '../../core/models/contact_photo_settings.dart';
import '../../core/models/live_call.dart';
import '../../core/services/caller_details.dart';
import '../../core/services/call_notes_service.dart';
import '../../core/services/sim_service.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/keypad.dart';
import 'add_call_picker.dart';
import 'call_widgets.dart';
import 'caller_backdrop.dart';

/// Outgoing, active, held and conference calls: a view over [CallManager].
class InCallScreen extends StatefulWidget {
  const InCallScreen({super.key});

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  final CallManager _manager = CallManager.instance;

  /// Kept so the header stays up while "Call ended" shows.
  LiveCall? _shown;
  bool _keypadOpen = false;
  String _dtmf = '';
  String? _simPromptedFor;
  String? _notesFor;
  List<CallNote> _notes = const <CallNote>[];

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onCallsChanged);
    _onCallsChanged();
  }

  @override
  void dispose() {
    _manager.removeListener(_onCallsChanged);
    super.dispose();
  }

  void _onCallsChanged() {
    final LiveCall? call = _manager.foreground ?? _manager.ringing;
    if (call == null) return;
    _shown = call;
    if (_notesFor != call.number) _loadNotes(call.number);
    if (call.phase == CallPhase.selectSim && _simPromptedFor != call.id) {
      _simPromptedFor = call.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => _chooseSim(call));
    }
    if (call.phase != CallPhase.active && _keypadOpen) setState(() => _keypadOpen = false);
  }

  Future<void> _loadNotes(String number) async {
    _notesFor = number;
    final List<CallNote> notes = await CallNotesService.getNotesForNumber(number);
    if (mounted && _notesFor == number) setState(() => _notes = notes);
  }


  Future<void> _run(Future<bool> Function() action, String failure) async {
    if (!await action()) _toast(failure);
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleMute() async {
    final CallAudio audio = _manager.audio;
    _manager.setAudio(audio.copyWith(isMuted: !audio.isMuted));
    if (!await CallService.mute(!audio.isMuted)) {
      _manager.setAudio(audio);
      _toast("Couldn't change mute");
    }
  }

  Future<void> _setRoute(String route) async {
    final CallAudio audio = _manager.audio;
    _manager.setAudio(audio.copyWith(route: route));
    if (!await CallService.route(route)) {
      _manager.setAudio(audio);
      _toast("Couldn't switch audio");
    }
  }

  void _onAudioPressed() {
    final CallAudio audio = _manager.audio;
    if (audio.hasRouteChoice) {
      _pickRoute(audio);
    } else {
      _setRoute(audio.isSpeaker ? CallAudio.earpiece : CallAudio.speaker);
    }
  }

  Future<void> _endCall() async {
    HapticFeedback.heavyImpact();
    await _run(CallService.end, "Couldn't end the call");
  }

  Future<void> _addCall(LiveCall call) async {
    final bool held = call.isActive && call.canHold && await CallService.hold(true);
    if (!mounted) return;
    final String? number = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const AddCallPicker()),
    );
    if (!mounted) return;
    final int? simSlot = number == null ? null : await SimService.pickSimForCall(context, number: number);
    if (number == null || simSlot == null) {
      if (held) await CallService.hold(false);
      return;
    }
    await _run(() => CallService.makeCall(number, simSlot: simSlot), "Couldn't place the call");
  }

  Future<void> _chooseSim(LiveCall call) async {
    if (!mounted) return;
    final int? slot = await SimService.pickSimForCall(context, number: call.number);
    if (slot == null) {
      await CallService.end();
    } else {
      await _run(() => CallService.selectSim(slot), "Couldn't use that SIM");
    }
  }

  void _sendDtmf(String digit) {
    CallService.dtmf(digit);
    setState(() => _dtmf = (_dtmf + digit).length > 24 ? (_dtmf + digit).substring(1) : _dtmf + digit);
  }


  Future<void> _pickRoute(CallAudio audio) async {
    final String? route = await showAppSheet<String>(
      context,
      background: CallColors.sheet,
      builder: (BuildContext context) => ListView(
        shrinkWrap: true,
        children: <Widget>[
          const CallSheetTitle('Audio'),
          for (final String route in _routeOrder.where(audio.routes.contains))
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Icon(_routeIcon(route), color: Colors.white),
              title: Text(_routeLabel(route, audio), style: const TextStyle(color: Colors.white)),
              trailing: route == audio.route ? const Icon(Icons.check_rounded, color: CallColors.accent) : null,
              onTap: () => Navigator.of(context).pop(route),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (route != null && route != audio.route) await _setRoute(route);
  }

  Future<void> _editNotes(String number) async {
    final TextEditingController controller = TextEditingController();
    final String? text = await showAppSheet<String>(
      context,
      background: CallColors.sheet,
      fullHeight: true,
      builder: (BuildContext context) => _NotesSheet(controller: controller, notes: _notes),
    );
    controller.dispose();
    final String content = text?.trim() ?? '';
    if (content.isEmpty) return;
    final CallNote note = await CallNotesService.addNote(number: number, content: content);
    if (mounted) setState(() => _notes = <CallNote>[note, ..._notes]);
  }


  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _manager,
      builder: (BuildContext context, _) {
        final LiveCall? call = _manager.foreground ?? _manager.ringing ?? _shown;
        if (call == null) return const ColoredBox(color: CallColors.top);
        final EndedCall? ended = _manager.hasCalls ? null : _manager.ended;
        return CallerDetailsBuilder(
          number: call.number,
          builder: (BuildContext context, CallerDetails details) => CallBackground(
            details: details,
            reveal: call.isConnecting,
            child: Stack(
              children: <Widget>[
                _layout(call, details, ended),
                if (_keypadOpen) _keypad(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _layout(LiveCall call, CallerDetails details, EndedCall? ended) {
    final LiveCall? waiting = _manager.waiting;
    final LiveCall? other = _manager.background;
    final bool poster = details.photoStyle == PhotoStyle.poster;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: <Widget>[
          if (waiting != null) _WaitingCallCard(call: waiting, run: _run),
          if (other != null && waiting == null) _HeldCallBar(call: other, onSwap: () => _run(CallService.swap, "Couldn't swap calls")),
          Expanded(
            // A poster's name sits at the top, leaving the face clear.
            child: Align(
              alignment: poster ? Alignment.topCenter : Alignment.center,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(top: poster ? 12 : 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CallerHeader(
                      name: call.displayName,
                      details: details,
                      subtitle: CallerHeader.subtitleFor(call, details),
                      status: CallStatusLine(call: ended == null ? call : null, ended: ended),
                      avatarSize: 104,
                    ),
                    const SizedBox(height: 14),
                    CallBadges(call: call),
                  ],
                ),
              ),
            ),
          ),
          IgnorePointer(
            ignoring: ended != null,
            child: AnimatedOpacity(
              opacity: ended == null ? 1 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: _controls(call, other),
            ),
          ),
          const SizedBox(height: 28),
          RoundCallButton(
            icon: Icons.call_end_rounded,
            color: CallColors.decline,
            semanticLabel: 'End call',
            onPressed: ended == null ? _endCall : null,
          ),
        ],
      ),
    );
  }

  Widget _controls(LiveCall call, LiveCall? other) {
    final CallAudio audio = _manager.audio;
    final bool active = call.isActive;
    final bool twoCalls = other != null;
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            CallControlButton(
              icon: audio.isMuted ? Icons.mic_off_rounded : Icons.mic_none_rounded,
              label: audio.isMuted ? 'Unmute' : 'Mute',
              active: audio.isMuted,
              onPressed: _toggleMute,
            ),
            CallControlButton(
              icon: Icons.dialpad_rounded,
              label: 'Keypad',
              onPressed: active ? () => setState(() => _keypadOpen = true) : null,
            ),
            CallControlButton(
              icon: _routeIcon(audio.route),
              label: audio.hasRouteChoice ? _routeLabel(audio.route, audio) : 'Speaker',
              active: audio.route != CallAudio.earpiece,
              onPressed: _onAudioPressed,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            if (twoCalls)
              CallControlButton(
                icon: Icons.call_merge_rounded,
                label: 'Merge',
                onPressed: call.canMerge || other.canMerge
                    ? () => _run(CallService.merge, "Your network didn't allow merging")
                    : null,
              )
            else
              CallControlButton(
                icon: Icons.add_call,
                label: 'Add call',
                onPressed: active ? () => _addCall(call) : null,
              ),
            if (twoCalls)
              CallControlButton(
                icon: Icons.swap_calls_rounded,
                label: 'Swap',
                onPressed: () => _run(CallService.swap, "Couldn't swap calls"),
              )
            else
              CallControlButton(
                icon: call.isHeld ? Icons.play_arrow_rounded : Icons.pause_rounded,
                label: call.isHeld ? 'Resume' : 'Hold',
                active: call.isHeld,
                onPressed: call.isHeld || (active && call.canHold)
                    ? () => _run(() => CallService.hold(!call.isHeld), "Couldn't change hold")
                    : null,
              ),
            CallControlButton(
              icon: Icons.sticky_note_2_outlined,
              label: 'Notes',
              badge: _notes.isNotEmpty,
              onPressed: call.number.isEmpty ? null : () => _editNotes(call.number),
            ),
          ],
        ),
      ],
    );
  }

  Widget _keypad() {
    return Positioned.fill(
      child: ColoredBox(
        color: CallColors.top.withValues(alpha: 0.96),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 48,
                child: Text(
                  _dtmf,
                  maxLines: 1,
                  style: const TextStyle(color: Colors.white, fontSize: 30, letterSpacing: 3),
                ),
              ),
              const Spacer(),
              Keypad(
                style: KeypadStyle(
                  digit: Colors.white,
                  letters: CallColors.subtle,
                  fill: Colors.white.withValues(alpha: 0.1),
                ),
                onKey: _sendDtmf,
                clicks: false,
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _keypadOpen = false),
                style: TextButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(120, 48)),
                child: const Text('Hide keypad', style: TextStyle(fontSize: 15)),
              ),
              const SizedBox(height: 12),
              RoundCallButton(
                icon: Icons.call_end_rounded,
                color: CallColors.decline,
                semanticLabel: 'End call',
                onPressed: _endCall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const List<String> _routeOrder = <String>[
    CallAudio.bluetooth,
    CallAudio.wired,
    CallAudio.earpiece,
    CallAudio.speaker,
  ];

  static IconData _routeIcon(String route) => switch (route) {
        CallAudio.bluetooth => Icons.bluetooth_audio_rounded,
        CallAudio.wired => Icons.headset_mic_outlined,
        CallAudio.speaker => Icons.volume_up_rounded,
        _ => Icons.phone_in_talk_outlined,
      };

  static String _routeLabel(String route, CallAudio audio) => switch (route) {
        CallAudio.bluetooth => audio.bluetoothName ?? 'Bluetooth',
        CallAudio.wired => 'Headset',
        CallAudio.speaker => 'Speaker',
        _ => 'Phone',
      };
}

/// A second caller ringing over the current call.
class _WaitingCallCard extends StatelessWidget {
  const _WaitingCallCard({required this.call, required this.run});

  final LiveCall call;
  final Future<void> Function(Future<bool> Function() action, String failure) run;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.12),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              <String>['Incoming call', ?call.simLabel].join(' · '),
              style: const TextStyle(color: CallColors.subtle, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              call.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                _action(Icons.call_end_rounded, 'Decline', CallColors.decline,
                    () => run(CallService.reject, "Couldn't decline")),
                const SizedBox(width: 8),
                _action(Icons.call_end_outlined, 'End & answer', Colors.white.withValues(alpha: 0.16),
                    () => run(CallService.endAndAnswer, "Couldn't answer")),
                const SizedBox(width: 8),
                _action(Icons.phone_paused_rounded, 'Hold & answer', CallColors.accept,
                    () => run(CallService.holdAndAnswer, "Couldn't answer")),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, Color color, VoidCallback onPressed) {
    return Expanded(
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// The call waiting in the background while two calls are up; tap to swap.
class _HeldCallBar extends StatelessWidget {
  const _HeldCallBar({required this.call, required this.onSwap});

  final LiveCall call;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onSwap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              const Icon(Icons.pause_circle_outline_rounded, color: CallColors.hold, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${call.isHeld ? 'On hold' : 'Connecting'} · ${call.displayName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
              const Icon(Icons.swap_vert_rounded, color: CallColors.subtle),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotesSheet extends StatelessWidget {
  const _NotesSheet({required this.controller, required this.notes});

  final TextEditingController controller;
  final List<CallNote> notes;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const CallSheetTitle('Call note'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Write a note while you talk…',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              style: FilledButton.styleFrom(
                backgroundColor: CallColors.accent,
                foregroundColor: CallColors.top,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Save note'),
            ),
          ),
          if (notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            const CallSheetTitle('Earlier notes'),
            for (final CallNote note in notes.take(5))
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text(note.content, style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  TimeUtils.formatRelativeTime(note.createdAt),
                  style: const TextStyle(color: CallColors.subtle, fontSize: 12),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

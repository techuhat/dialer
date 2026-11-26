import 'package:flutter/foundation.dart';

import 'models/live_call.dart';

/// Live call state mirrored from native. Call screens are pure views over this.
class CallManager extends ChangeNotifier {
  CallManager._();

  static final CallManager instance = CallManager._();

  List<LiveCall> _calls = const <LiveCall>[];
  CallAudio _audio = const CallAudio();
  int _simCount = 1;
  EndedCall? _ended;

  List<LiveCall> get calls => _calls;
  CallAudio get audio => _audio;
  int get simCount => _simCount;
  bool get hasCalls => _calls.isNotEmpty;

  /// Set while the last call has just ended and the call screen shows "Call ended".
  EndedCall? get ended => _ended;

  LiveCall? get ringing => _firstWhere((LiveCall call) => call.isRinging);

  /// The call the screen is about: active first, then connecting, then held. Never a ringing one.
  LiveCall? get foreground {
    LiveCall? best;
    for (final LiveCall call in _calls) {
      if (call.isRinging || call.phase == CallPhase.disconnected) continue;
      if (best == null || _priority(call) > _priority(best)) best = call;
    }
    return best;
  }

  /// The second, non-ringing call (usually on hold) when two calls are up.
  LiveCall? get background {
    final LiveCall? front = foreground;
    return _firstWhere((LiveCall call) => call.id != front?.id && !call.isRinging);
  }

  /// A call ringing on top of an established one.
  LiveCall? get waiting => foreground == null ? null : ringing;

  void applySnapshot(Map<Object?, Object?> snapshot) {
    final List<LiveCall> calls = (snapshot['calls'] as List<Object?>? ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map(LiveCall.fromMap)
        .toList(growable: false);
    final Object? audio = snapshot['audio'];
    final CallAudio nextAudio = audio is Map<Object?, Object?> ? CallAudio.fromMap(audio) : _audio;
    final int simCount = (snapshot['simCount'] as num?)?.toInt() ?? _simCount;

    final bool changed = !listEquals(calls, _calls) || nextAudio != _audio || simCount != _simCount;
    _calls = calls;
    _audio = nextAudio;
    _simCount = simCount;
    if (calls.isNotEmpty && _ended != null) {
      _ended = null;
      notifyListeners();
    } else if (changed) {
      notifyListeners();
    }
  }

  void applyAudio(Map<Object?, Object?> audio) => setAudio(CallAudio.fromMap(audio));

  /// Also used for optimistic UI: native confirms or corrects it with `audioStateChanged`.
  void setAudio(CallAudio audio) {
    if (audio == _audio) return;
    _audio = audio;
    notifyListeners();
  }

  void markEnded(EndedCall call) {
    _ended = call;
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _calls = const <LiveCall>[];
    _audio = const CallAudio();
    _simCount = 1;
    _ended = null;
  }

  LiveCall? _firstWhere(bool Function(LiveCall call) test) {
    for (final LiveCall call in _calls) {
      if (test(call)) return call;
    }
    return null;
  }

  static int _priority(LiveCall call) => switch (call.phase) {
        CallPhase.active => 3,
        CallPhase.holding => 1,
        _ => 2,
      };
}

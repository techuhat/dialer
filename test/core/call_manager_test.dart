import 'package:flutter_test/flutter_test.dart';
import 'package:umar_dailer/core/call_manager.dart';
import 'package:umar_dailer/core/models/live_call.dart';

Map<String, Object?> _call(String id, String state, {String number = '9876543210', bool incoming = false}) =>
    <String, Object?>{'id': id, 'number': number, 'state': state, 'incoming': incoming};

Map<String, Object?> _snapshot(List<Map<String, Object?>> calls, {Map<String, Object?>? audio}) =>
    <String, Object?>{'calls': calls, 'audio': audio, 'simCount': 2};

void main() {
  final CallManager manager = CallManager.instance;

  setUp(manager.reset);

  test('parses calls and audio from a native snapshot', () {
    manager.applySnapshot(_snapshot(
      <Map<String, Object?>>[
        <String, Object?>{
          ..._call('call-1', 'active'),
          'name': 'Asha',
          'connectedAt': 1700000000000,
          'hd': true,
          'simSlot': 1,
          'carrier': 'Jio',
        },
      ],
      audio: <String, Object?>{'route': 'speaker', 'routes': <String>['earpiece', 'speaker'], 'muted': true},
    ));

    final LiveCall call = manager.foreground!;
    expect(call.displayName, 'Asha');
    expect(call.phase, CallPhase.active);
    expect(call.connectedAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
    expect(call.isHd, isTrue);
    expect(call.simLabel, 'SIM 2 · Jio');
    expect(manager.audio.isSpeaker, isTrue);
    expect(manager.audio.isMuted, isTrue);
    expect(manager.simCount, 2);
  });

  test('foreground prefers the active call over a held one', () {
    manager.applySnapshot(_snapshot(<Map<String, Object?>>[
      _call('held', 'holding', number: '111'),
      _call('live', 'active', number: '222'),
    ]));

    expect(manager.foreground!.id, 'live');
    expect(manager.background!.id, 'held');
    expect(manager.waiting, isNull);
  });

  test('a ringing call on top of an established one is a waiting call', () {
    manager.applySnapshot(_snapshot(<Map<String, Object?>>[
      _call('live', 'active'),
      _call('new', 'ringing', number: '333', incoming: true),
    ]));

    expect(manager.foreground!.id, 'live');
    expect(manager.waiting!.id, 'new');
    expect(manager.background, isNull);
  });

  test('a lone ringing call is never the foreground call', () {
    manager.applySnapshot(_snapshot(<Map<String, Object?>>[_call('new', 'ringing', incoming: true)]));

    expect(manager.foreground, isNull);
    expect(manager.ringing!.id, 'new');
    expect(manager.waiting, isNull);
  });

  test('unknown numbers fall back to the formatted number', () {
    manager.applySnapshot(_snapshot(<Map<String, Object?>>[_call('c', 'dialing', number: '+919876543210')]));

    expect(manager.foreground!.displayName, '+91 98765 43210');
    expect(manager.foreground!.isConnecting, isTrue);
  });

  test('notifies only when something visible changed', () {
    int notifications = 0;
    void listener() => notifications++;
    manager.addListener(listener);
    addTearDown(() => manager.removeListener(listener));

    manager.applySnapshot(_snapshot(<Map<String, Object?>>[_call('c', 'active')]));
    manager.applySnapshot(_snapshot(<Map<String, Object?>>[_call('c', 'active')]));
    expect(notifications, 1);

    manager.applySnapshot(_snapshot(<Map<String, Object?>>[_call('c', 'holding')]));
    expect(notifications, 2);
  });

  test('a new call clears the "call ended" state', () {
    manager.markEnded(const EndedCall(number: '111', duration: Duration(seconds: 42)));
    expect(manager.ended, isNotNull);

    manager.applySnapshot(_snapshot(<Map<String, Object?>>[_call('next', 'ringing', incoming: true)]));
    expect(manager.ended, isNull);
  });
}

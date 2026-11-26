import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:umar_dailer/core/call_manager.dart';
import 'package:umar_dailer/core/call_service.dart';
import 'package:umar_dailer/core/models/live_call.dart';
import 'package:umar_dailer/pages/call/in_call_screen.dart';
import 'package:umar_dailer/pages/call/incoming_call_screen.dart';

Map<String, Object?> _call(String id, String state, {String? name, String number = '9876543210'}) =>
    <String, Object?>{
      'id': id,
      'number': number,
      'name': name,
      'state': state,
      'incoming': state == 'ringing',
      'connectedAt': state == 'active' ? DateTime.now().millisecondsSinceEpoch : null,
      'canHold': true,
      'canMerge': true,
    };

void main() {
  final CallManager manager = CallManager.instance;
  final List<MethodCall> commands = <MethodCall>[];

  setUp(() {
    manager.reset();
    commands.clear();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      CallService.channel,
      (MethodCall call) async {
        commands.add(call);
        return true;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(CallService.channel, null);
  });

  void show(List<Map<String, Object?>> calls) {
    manager.applySnapshot(<String, Object?>{'calls': calls, 'simCount': 1});
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pump(const Duration(milliseconds: 50));
  }

  // Repeating animations and the call timer must be disposed before a test ends.
  Future<void> unmount(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  group('IncomingCallScreen', () {
    testWidgets('shows the caller and the answer affordances', (WidgetTester tester) async {
      show(<Map<String, Object?>>[_call('c1', 'ringing', name: 'Asha Verma')]);
      await pumpScreen(tester, const IncomingCallScreen());

      expect(find.text('Asha Verma'), findsOneWidget);
      expect(find.text('Incoming call'), findsOneWidget);
      expect(find.text('Swipe up to answer'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('swiping the handle up answers', (WidgetTester tester) async {
      show(<Map<String, Object?>>[_call('c1', 'ringing')]);
      await pumpScreen(tester, const IncomingCallScreen());

      await tester.timedDrag(find.byIcon(Icons.call_rounded), const Offset(0, -160), const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(commands.map((MethodCall c) => c.method), contains('answer'));
      await unmount(tester);
    });

    testWidgets('Decline rejects only the ringing call', (WidgetTester tester) async {
      show(<Map<String, Object?>>[_call('c1', 'ringing')]);
      await pumpScreen(tester, const IncomingCallScreen());

      await tester.tap(find.text('Decline'));
      await tester.pump();

      expect(commands.single.method, 'reject');
      await unmount(tester);
    });
  });

  group('InCallScreen', () {
    testWidgets('active call shows the timer and the control grid', (WidgetTester tester) async {
      show(<Map<String, Object?>>[_call('c1', 'active', name: 'Asha Verma')]);
      await pumpScreen(tester, const InCallScreen());

      expect(find.text('Asha Verma'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      for (final String label in <String>['Mute', 'Keypad', 'Speaker', 'Add call', 'Hold', 'Notes']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('TalkBack can use the controls and end the call', (WidgetTester tester) async {
      show(<Map<String, Object?>>[_call('c1', 'active')]);
      await pumpScreen(tester, const InCallScreen());

      expect(tester.getSemantics(find.bySemanticsLabel('Mute')), isSemantics(isButton: true, hasTapAction: true));
      expect(tester.getSemantics(find.bySemanticsLabel('End call')), isSemantics(isButton: true, hasTapAction: true));
      tester.semantics.tap(find.semantics.byLabel('End call'));
      await tester.pump();

      expect(commands.map((MethodCall c) => c.method), contains('end'));
      await unmount(tester);
    });

    testWidgets('outgoing call reads "Calling…"', (WidgetTester tester) async {
      show(<Map<String, Object?>>[_call('c1', 'dialing')]);
      await pumpScreen(tester, const InCallScreen());

      expect(find.text('Calling…'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('mute toggles at once and asks native to mute', (WidgetTester tester) async {
      show(<Map<String, Object?>>[_call('c1', 'active')]);
      await pumpScreen(tester, const InCallScreen());

      await tester.tap(find.text('Mute'));
      await tester.pump();

      expect(find.text('Unmute'), findsOneWidget);
      final MethodCall mute = commands.firstWhere((MethodCall c) => c.method == 'mute');
      expect((mute.arguments as Map<Object?, Object?>)['on'], isTrue);
      await unmount(tester);
    });

    testWidgets('two calls offer merge and swap and show the held call', (WidgetTester tester) async {
      show(<Map<String, Object?>>[
        _call('c1', 'active', name: 'Asha Verma'),
        _call('c2', 'holding', name: 'Ravi', number: '9123456780'),
      ]);
      await pumpScreen(tester, const InCallScreen());

      expect(find.text('Merge'), findsOneWidget);
      expect(find.text('Swap'), findsOneWidget);
      expect(find.text('On hold · Ravi'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a waiting call offers decline, end & answer, hold & answer', (WidgetTester tester) async {
      show(<Map<String, Object?>>[
        _call('c1', 'active', name: 'Asha Verma'),
        _call('c2', 'ringing', name: 'Ravi', number: '9123456780'),
      ]);
      await pumpScreen(tester, const InCallScreen());

      expect(find.text('Ravi'), findsOneWidget);
      await tester.tap(find.text('Hold & answer'));
      await tester.pump();
      expect(commands.single.method, 'holdAndAnswer');
      await unmount(tester);
    });

    testWidgets('shows "Call ended" with the duration once the last call is gone', (WidgetTester tester) async {
      show(<Map<String, Object?>>[_call('c1', 'active', name: 'Asha Verma')]);
      await pumpScreen(tester, const InCallScreen());

      show(const <Map<String, Object?>>[]);
      manager.markEnded(const EndedCall(number: '9876543210', duration: Duration(minutes: 2, seconds: 5)));
      await tester.pump();

      expect(find.text('Call ended · 02:05'), findsOneWidget);
      expect(find.text('Asha Verma'), findsOneWidget);
      await unmount(tester);
    });
  });
}

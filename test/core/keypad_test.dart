import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umar_dailer/core/widgets/keypad.dart';

Future<void> _pumpKeypad(WidgetTester tester, {required ValueChanged<String> onKey, bool clicks = true}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 420,
          child: Keypad(
            style: const KeypadStyle(digit: Colors.white, letters: Colors.white70, fill: Colors.black, size: 64),
            onKey: onKey,
            onAlternate: (String value) => onKey('alt $value'),
            clicks: clicks,
          ),
        ),
      ),
    ),
  );
}

/// Platform calls (haptics, system sounds) made during the test.
List<String> _recordPlatform(WidgetTester tester) {
  final List<String> calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
    calls.add(call.method);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return calls;
}

void main() {
  testWidgets('keypad keys can be pressed with TalkBack, long press included', (WidgetTester tester) async {
    final List<String> keys = <String>[];
    await _pumpKeypad(tester, onKey: keys.add);

    expect(tester.getSemantics(find.bySemanticsLabel('5')), isSemantics(isButton: true, hasTapAction: true));
    tester.semantics.tap(find.semantics.byLabel('5'));
    tester.semantics.longPress(find.semantics.byLabel('0'));
    await tester.pump();

    expect(keys, <String>['5', 'alt +']);
  });

  testWidgets('a key clicks once by default', (WidgetTester tester) async {
    final List<String> platform = _recordPlatform(tester);
    await _pumpKeypad(tester, onKey: (_) {});

    await tester.tap(find.text('5'));
    await tester.pump();

    expect(platform.where((String method) => method == 'SystemSound.play'), hasLength(1));
  });

  testWidgets('without clicks a key still buzzes but makes no sound', (WidgetTester tester) async {
    final List<String> platform = _recordPlatform(tester);
    final List<String> keys = <String>[];
    await _pumpKeypad(tester, onKey: keys.add, clicks: false);

    await tester.tap(find.text('5'));
    await tester.pump();

    expect(keys, <String>['5']);
    expect(platform, contains('HapticFeedback.vibrate'));
    expect(platform, isNot(contains('SystemSound.play')));
  });
}

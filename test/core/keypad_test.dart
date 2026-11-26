import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umar_dailer/core/widgets/keypad.dart';

void main() {
  testWidgets('keypad keys can be pressed with TalkBack, long press included', (WidgetTester tester) async {
    final List<String> keys = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 420,
            child: Keypad(
              style: const KeypadStyle(digit: Colors.white, letters: Colors.white70, fill: Colors.black, size: 64),
              onKey: keys.add,
              onAlternate: (String value) => keys.add('alt $value'),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSemantics(find.bySemanticsLabel('5')), isSemantics(isButton: true, hasTapAction: true));
    tester.semantics.tap(find.semantics.byLabel('5'));
    tester.semantics.longPress(find.semantics.byLabel('0'));
    await tester.pump();

    expect(keys, <String>['5', 'alt +']);
  });
}

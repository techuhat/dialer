import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umar_dailer/pages/dialpad/dial_input.dart';

void main() {
  test('inserts and deletes at the cursor', () {
    final DialInputController input = DialInputController()
      ..insert('9')
      ..insert('8');
    expect(input.text, '98');

    input
      ..selection = const TextSelection.collapsed(offset: 1)
      ..insert('5');
    expect(input.text, '958');
    expect(input.selection.baseOffset, 2);

    expect(input.backspace(), isTrue);
    expect(input.text, '98');
    expect(input.selection.baseOffset, 1);

    input.selection = const TextSelection(baseOffset: 0, extentOffset: 2);
    expect(input.backspace(), isTrue);
    expect(input.text, isEmpty);
    expect(input.backspace(), isFalse);
  });

  test('takes only dialable characters from pasted or linked numbers', () {
    final DialInputController input = DialInputController()..replaceAll('+91 (98765) 43-210, ext');
    expect(input.text, '+919876543210,');
    expect(input.selection.baseOffset, input.text.length);
    expect(input.clearAll(), isTrue);
    expect(input.clearAll(), isFalse);
  });

  testWidgets('draws the groups without changing the text', (WidgetTester tester) async {
    final DialInputController input = DialInputController()..replaceAll('9876543210');
    late TextSpan span;
    await tester.pumpWidget(
      Builder(
        builder: (BuildContext context) {
          span = input.buildTextSpan(context: context, style: const TextStyle(fontSize: 30), withComposing: false);
          return const SizedBox();
        },
      ),
    );

    expect(span.toPlainText(), '9876543210');
    expect(span.children, hasLength(3));
    expect((span.children![1] as TextSpan).style?.letterSpacing, 9);
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umar_dailer/core/models/contact.dart';
import 'package:umar_dailer/core/services/contacts_service.dart';
import 'package:umar_dailer/core/theme.dart';
import 'package:umar_dailer/core/widgets/nav_parts.dart';
import 'package:umar_dailer/pages/dialpad/dialpad_page.dart';

Map<String, dynamic> _contact(String id, String name, String number) => Contact(
  id: id,
  name: name,
  phones: <PhoneNumber>[PhoneNumber(number: number, label: 'Mobile')],
).toMap();

void main() {
  setUp(() async {
    await ContactsService.loadWarmSnapshot(
      () async => <String, dynamic>{
        'contacts': jsonEncode(<Map<String, dynamic>>[
          _contact('1', 'Asha Verma', '+91 98765 43210'),
          _contact('2', 'Ravi Kumar', '9123456780'),
        ]),
      },
    );
  });

  Future<void> pumpKeypad(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const DialpadPage()));
    await tester.pump();
  }

  Future<void> type(WidgetTester tester, String digits) async {
    for (final String digit in digits.split('')) {
      await tester.tap(find.bySemanticsLabel(digit).first);
      await tester.pump();
    }
  }

  String typed(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('typing letters of a name suggests the contact; a tap fills the number', (WidgetTester tester) async {
    await pumpKeypad(tester);
    expect(find.text('Hold 0 for +. Hold * for a pause.'), findsOneWidget);

    await type(tester, '2742');
    await tester.pumpAndSettle();
    expect(find.text('Asha Verma', findRichText: true), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('^Asha Verma')));
    await tester.pumpAndSettle();
    expect(typed(tester), '+919876543210');
    expect(find.text('Asha Verma'), findsOneWidget, reason: 'the caption names the contact');
  });

  testWidgets('a saved number shows its name and cannot be saved again', (WidgetTester tester) async {
    await pumpKeypad(tester);
    expect(tester.getSemantics(find.bySemanticsLabel('Call')), isSemantics(isEnabled: false));

    await type(tester, '9123456780');
    await tester.pumpAndSettle();

    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Save as contact')), isSemantics(isEnabled: false));
    expect(tester.getSemantics(find.bySemanticsLabel('Call')), isSemantics(isEnabled: true, hasTapAction: true));
  });

  testWidgets('a new number can be saved and shows the note', (WidgetTester tester) async {
    await pumpKeypad(tester);
    await type(tester, '8888899999');
    await tester.pumpAndSettle();

    expect(find.text('Not in your contacts'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Save as contact')),
      isSemantics(isEnabled: true, hasTapAction: true),
    );
  });

  testWidgets('holding delete clears the number', (WidgetTester tester) async {
    await pumpKeypad(tester);
    await type(tester, '98');
    await tester.tap(find.bySemanticsLabel('Delete'));
    await tester.pump();
    expect(typed(tester), '9');

    await tester.longPress(find.bySemanticsLabel('Delete'));
    await tester.pumpAndSettle();
    expect(typed(tester), isEmpty);
  });

  testWidgets('dialling 1985 spins the dial all the way round', (WidgetTester tester) async {
    await pumpKeypad(tester);
    final int spins = RotaryDial.spins.value;
    await type(tester, '1985');
    await tester.pump();

    expect(RotaryDial.spins.value, spins + 1);
    expect(find.textContaining('1985'), findsWidgets);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}

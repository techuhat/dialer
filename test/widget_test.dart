import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:umar_dailer/app.dart';

void main() {
  testWidgets('Dialer app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Bounded pumps, not pumpAndSettle(). The first screen is a bootstrap splash
    // with a CircularProgressIndicator, which schedules frames forever — so
    // pumpAndSettle() can never return and always times out, regardless of whether
    // the app is healthy.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The app built and mounted its root without throwing.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

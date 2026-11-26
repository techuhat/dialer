import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umar_dailer/core/widgets/fast_scroller.dart';

/// Section headings (String) every ten rows (int).
final List<Object> _rows = <Object>[
  for (int i = 0; i < 300; i++)
    if (i % 10 == 0) 'Section ${i ~/ 10}' else i,
];

void main() {
  late ScrollController controller;
  late List<int> tapped;

  Future<void> pumpList(WidgetTester tester, List<Object> rows) async {
    controller = ScrollController();
    addTearDown(controller.dispose);
    tapped = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FastScroller(
            controller: controller,
            labelAt: (double fraction) => FastScroller.headingAt(rows, fraction),
            child: ListView.builder(
              controller: controller,
              itemCount: rows.length,
              itemBuilder: (BuildContext context, int index) {
                final Object row = rows[index];
                return SizedBox(
                  height: 50,
                  child: row is String
                      ? Text(row)
                      : InkWell(onTap: () => tapped.add(row as int), child: Text('Row $row')),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  test('headingAt names the section a place in the list belongs to', () {
    expect(FastScroller.headingAt(_rows, 0), 'Section 0');
    expect(FastScroller.headingAt(_rows, 0.5), 'Section 15');
    expect(FastScroller.headingAt(_rows, 0.52), 'Section 15', reason: 'a row under the heading');
    expect(FastScroller.headingAt(_rows, 1), 'Section 29');
    expect(FastScroller.headingAt(const <Object>[], 0.5), isNull);
  });

  testWidgets('the thumb drags a long list to its end, with a bubble naming the place', (WidgetTester tester) async {
    await pumpList(tester, _rows);
    final Rect list = tester.getRect(find.byType(FastScroller));

    controller.jumpTo(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(FastScroller.thumbKey), findsOneWidget, reason: 'scrolling brings the thumb out');

    final TestGesture gesture = await tester.startGesture(Offset(list.right - 8, list.top + 30));
    for (int step = 1; step <= 20; step++) {
      await gesture.moveBy(Offset(0, list.height / 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller.offset, closeTo(controller.position.maxScrollExtent, 1));
    expect(find.text('Section 29'), findsWidgets, reason: 'the bubble names the last section');

    await gesture.up();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse, reason: 'the thumb has faded out');
  });

  testWidgets('a hidden thumb lets taps through to the row under it', (WidgetTester tester) async {
    await pumpList(tester, _rows);
    final Rect list = tester.getRect(find.byType(FastScroller));

    await tester.tapAt(Offset(list.right - 8, list.top + 75));
    expect(tapped, <int>[1]);
  });

  testWidgets('a short list gets no thumb at all', (WidgetTester tester) async {
    await pumpList(tester, _rows.take(12).toList());
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    expect(find.byKey(FastScroller.thumbKey), findsNothing);
  });
}

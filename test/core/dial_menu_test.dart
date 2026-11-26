import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umar_dailer/core/theme.dart';
import 'package:umar_dailer/core/widgets/dial_menu.dart';
import 'package:umar_dailer/core/widgets/nav_parts.dart';

const List<NavDestination> _pages = <NavDestination>[
  NavDestination(icon: Icons.schedule_outlined, selectedIcon: Icons.schedule, label: 'Recents'),
  NavDestination(icon: Icons.people_outline, selectedIcon: Icons.people, label: 'Contacts'),
  NavDestination(icon: Icons.dialpad, selectedIcon: Icons.dialpad, label: 'Keypad'),
  NavDestination(icon: Icons.sticky_note_2_outlined, selectedIcon: Icons.sticky_note_2, label: 'Notes'),
  NavDestination(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings'),
];

void main() {
  late List<int> selected;
  late int pageTaps;

  Future<void> pumpMenu(WidgetTester tester, {Map<int, int> badges = const <int, int>{}}) async {
    selected = <int>[];
    pageTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Stack(
          children: <Widget>[
            Scaffold(
              body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => pageTaps++,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned.fill(
              child: DialMenu(destinations: _pages, selectedIndex: 0, onSelected: selected.add, badges: badges),
            ),
          ],
        ),
      ),
    );
  }

  Finder dial() => find.bySemanticsLabel('Page menu');
  bool isOpen() => find.text('Notes').evaluate().isNotEmpty;
  RotaryDialFace face(WidgetTester tester) => tester.widget<RotaryDialFace>(find.byType(RotaryDialFace));

  testWidgets('tap opens the pages and tapping one opens it', (WidgetTester tester) async {
    await pumpMenu(tester);
    expect(isOpen(), isFalse);

    await tester.tap(dial());
    await tester.pumpAndSettle();
    expect(isOpen(), isTrue);
    expect(find.text('Where to?'), findsOneWidget);

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(selected, <int>[3]);
    expect(isOpen(), isFalse);
  });

  testWidgets('tapping outside or the dial again closes without opening a page', (WidgetTester tester) async {
    await pumpMenu(tester);
    await tester.tap(dial());
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(isOpen(), isFalse);
    expect(pageTaps, 0, reason: 'the scrim takes the tap');

    await tester.tap(dial());
    await tester.pumpAndSettle();
    await tester.tap(dial());
    await tester.pumpAndSettle();
    expect(isOpen(), isFalse);
    expect(selected, isEmpty);

    await tester.tapAt(const Offset(20, 20));
    expect(pageTaps, 1, reason: 'a closed menu leaves the page usable');
  });

  testWidgets('hold, slide onto a page and let go opens it', (WidgetTester tester) async {
    await pumpMenu(tester);
    final TestGesture gesture = await tester.startGesture(tester.getCenter(dial()));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(isOpen(), isTrue);
    expect(find.text('Slide to a page'), findsOneWidget);

    await gesture.moveTo(tester.getCenter(find.byIcon(Icons.people_outline)));
    await tester.pumpAndSettle();
    expect(find.text('Contacts'), findsNWidgets(2), reason: 'the caption names the lit page');
    expect(
      face(tester).light,
      closeTo(RotaryDial.tickToward(const Offset(-0.59, -0.81)), 0.3),
      reason: 'the ticks facing Contacts, up-left, light up',
    );

    await gesture.up();
    await tester.pump();
    expect(selected, <int>[1]);
    await tester.pump(const Duration(milliseconds: 200));
    expect(face(tester).turns, greaterThan(0), reason: 'the ring dials the lit tick');
    expect(face(tester).light, isNotNull, reason: 'the lit tick travels with the ring');

    await tester.pumpAndSettle();
    expect(isOpen(), isFalse);
    expect(face(tester).turns, 0);
    expect(face(tester).light, isNull);
  });

  testWidgets('hold and let go away from the pages just closes', (WidgetTester tester) async {
    await pumpMenu(tester);
    final TestGesture gesture = await tester.startGesture(tester.getCenter(dial()));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(isOpen(), isTrue);

    await gesture.up();
    await tester.pump();
    expect(face(tester).turns, 0, reason: 'nothing dialled');
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(isOpen(), isFalse);
    expect(face(tester).light, isNull);
  });

  testWidgets('the easter egg spins the dial once all the way round', (WidgetTester tester) async {
    await pumpMenu(tester);
    RotaryDial.spins.value++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(face(tester).turns, greaterThan(0.2));

    await tester.pumpAndSettle();
    expect(face(tester).turns, 0);
    expect(face(tester).light, isNull);
  });

  testWidgets('dragging off the dial works without waiting for the hold', (WidgetTester tester) async {
    await pumpMenu(tester);
    final Offset center = tester.getCenter(dial());
    final TestGesture gesture = await tester.startGesture(center);
    for (int step = 1; step <= 10; step++) {
      await gesture.moveTo(center + Offset(0, -12.0 * step));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, <int>[2], reason: 'straight up is the Keypad');
  });

  testWidgets('back closes the open menu instead of leaving the screen', (WidgetTester tester) async {
    await pumpMenu(tester);
    await tester.tap(dial());
    await tester.pumpAndSettle();

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(isOpen(), isFalse);
    expect(selected, isEmpty);
  });

  testWidgets('missed calls show on the dial and on Recents, and TalkBack can use it', (WidgetTester tester) async {
    await pumpMenu(tester, badges: const <int, int>{0: 4});
    expect(
      tester.getSemantics(dial()),
      isSemantics(label: 'Page menu', value: 'Recents', isButton: true, hasTapAction: true, isExpanded: false),
    );

    await tester.tap(dial());
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Recents, 4 new')),
      isSemantics(isButton: true, isSelected: true, hasTapAction: true),
    );
    expect(tester.getSemantics(dial()), isSemantics(isExpanded: true));
  });
}

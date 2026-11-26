import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:umar_dailer/core/services/theme_service.dart';
import 'package:umar_dailer/core/theme.dart';
import 'package:umar_dailer/core/widgets/dial_menu.dart';
import 'package:umar_dailer/core/widgets/dialer_nav_bar.dart';
import 'package:umar_dailer/core/widgets/nav_parts.dart';
import 'package:umar_dailer/pages/dialpad_page.dart';

const List<NavDestination> _pages = <NavDestination>[
  NavDestination(icon: Icons.schedule_outlined, selectedIcon: Icons.schedule, label: 'Recents'),
  NavDestination(icon: Icons.people_outline, selectedIcon: Icons.people, label: 'Contacts'),
  NavDestination(icon: Icons.dialpad, selectedIcon: Icons.dialpad, label: 'Keypad'),
  NavDestination(icon: Icons.sticky_note_2_outlined, selectedIcon: Icons.sticky_note_2, label: 'Notes'),
  NavDestination(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings'),
];

/// The keypad inside HomePage's shell: a Scaffold with extendBody and either navigation style.
Future<void> _pumpKeypad(WidgetTester tester, {required bool dialMenu}) async {
  tester.view.physicalSize = const Size(1080, 2280);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 72, bottom: 72);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeService>(
      create: (_) => ThemeService(),
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (BuildContext context) => Stack(
            children: <Widget>[
              Scaffold(
                extendBody: true,
                body: const DialpadPage(),
                bottomNavigationBar: dialMenu
                    ? SizedBox(height: DialMenu.clearance(context))
                    : DialerNavBar(destinations: _pages, selectedIndex: 2, onSelected: (_) {}),
              ),
              if (dialMenu)
                Positioned.fill(
                  child: DialMenu(destinations: _pages, selectedIndex: 2, onSelected: (_) {}),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('the Call button sits just above the classic bar', (WidgetTester tester) async {
    await _pumpKeypad(tester, dialMenu: false);
    final Rect call = tester.getRect(find.widgetWithText(FilledButton, 'Call'));
    final Rect bar = tester.getRect(find.byType(DialerNavBar));

    expect(bar.top - call.bottom, inInclusiveRange(0, 16));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Call button sits just above the dial menu', (WidgetTester tester) async {
    await _pumpKeypad(tester, dialMenu: true);
    final Rect call = tester.getRect(find.widgetWithText(FilledButton, 'Call'));
    final Rect dial = tester.getRect(find.bySemanticsLabel('Page menu'));

    expect(dial.top - call.bottom, inInclusiveRange(8, 32));
    expect(tester.takeException(), isNull);
  });
}

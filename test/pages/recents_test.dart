import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umar_dailer/core/call_service.dart';
import 'package:umar_dailer/core/models/call_log_entry.dart';
import 'package:umar_dailer/core/services/call_log_service.dart';
import 'package:umar_dailer/core/widgets/dialer_nav_bar.dart';
import 'package:umar_dailer/pages/recents/recent_widgets.dart';
import 'package:umar_dailer/pages/recents/recents_page.dart';
import 'package:umar_dailer/pages/recents/stats_page.dart';

CallLogEntry _call(String id, String number, CallType type, DateTime at, {String? name, int duration = 0}) =>
    CallLogEntry(id: id, number: number, type: type, timestamp: at, name: name, duration: duration);

void main() {
  final DateTime now = DateTime.now();

  group('groupRecents', () {
    test('merges only adjacent calls with one number on one day', () {
      final List<RecentGroup> groups = groupRecents(<CallLogEntry>[
        _call('1', '+919876543210', CallType.missed, now),
        _call('2', '9876543210', CallType.missed, now.subtract(const Duration(minutes: 5))),
        _call('3', '9123456780', CallType.outgoing, now.subtract(const Duration(minutes: 9))),
        _call('4', '9876543210', CallType.incoming, now.subtract(const Duration(minutes: 20))),
      ]);

      expect(groups.map((RecentGroup g) => g.entries.length), <int>[2, 1, 1]);
    });

    test('never merges across days or withheld numbers', () {
      final List<RecentGroup> groups = groupRecents(<CallLogEntry>[
        _call('1', '9876543210', CallType.incoming, DateTime(2026, 11, 26, 0, 10)),
        _call('2', '9876543210', CallType.incoming, DateTime(2026, 11, 25, 23, 50)),
        _call('3', '', CallType.missed, DateTime(2026, 11, 25, 22)),
        _call('4', '', CallType.missed, DateTime(2026, 11, 25, 21)),
      ]);

      expect(groups.length, 4);
    });
  });

  test('filters treat declined as incoming and voicemail as missed', () {
    final CallLogEntry declined = _call('1', '1', CallType.rejected, now);
    final CallLogEntry voicemail = _call('2', '1', CallType.voicemail, now);

    expect(RecentsFilter.incoming.accepts(declined), isTrue);
    expect(RecentsFilter.missed.accepts(declined), isFalse);
    expect(RecentsFilter.missed.accepts(voicemail), isTrue);
    expect(RecentsFilter.outgoing.accepts(voicemail), isFalse);
  });

  test('recentTimeLabel shows a time for recent calls and a date for older ones', () {
    final DateTime ref = DateTime(2026, 11, 26, 18);
    expect(recentTimeLabel(DateTime(2026, 11, 26, 14, 5), now: ref), '2:05 pm');
    expect(recentTimeLabel(DateTime(2026, 11, 10, 9), now: ref), 'Tue 10 Nov');
    expect(recentTimeLabel(DateTime(2024, 3, 1, 9), now: ref), '1 Mar 2024');
  });

  group('widgets', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(CallService.channel, (MethodCall call) async => null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(CallService.channel, null);
    });

    Future<void> pump(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
      await tester.pump();
    }

    testWidgets('Recents shows sections, groups and the missed filter', (WidgetTester tester) async {
      CallLogService.setEntriesForTest(<CallLogEntry>[
        _call('1', '9876543210', CallType.missed, now, name: 'Asha Verma'),
        _call('2', '9876543210', CallType.missed, now.subtract(const Duration(minutes: 1)), name: 'Asha Verma'),
        _call('3', '9123456780', CallType.outgoing, now.subtract(const Duration(days: 3)), name: 'Ravi'),
      ]);
      await pump(tester, const RecentsPage());

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Older'), findsOneWidget);
      expect(find.text('Asha Verma (2)'), findsOneWidget);
      expect(find.text('Ravi'), findsOneWidget);

      await tester.tap(find.text('Missed'));
      await tester.pump();
      expect(find.text('Ravi'), findsNothing);

      await tester.tap(find.text('Outgoing'));
      await tester.pump();
      expect(find.text('Ravi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty log gets the friendly empty state', (WidgetTester tester) async {
      CallLogService.setEntriesForTest(const <CallLogEntry>[]);
      await pump(tester, const RecentsPage());

      expect(find.text('No calls yet'), findsOneWidget);
    });

    testWidgets('Stats renders the headline, breakdown and day bars', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      CallLogService.setEntriesForTest(<CallLogEntry>[
        _call('1', '9876543210', CallType.incoming, now, name: 'Asha', duration: 3700),
        _call('2', '9123456780', CallType.missed, now.subtract(const Duration(days: 1)), name: 'Ravi'),
      ]);
      await tester.pumpWidget(const MaterialApp(home: StatsPage()));
      await tester.pump();

      expect(find.text('Talk time'), findsOneWidget);
      expect(find.text('1h 1m'), findsOneWidget);
      expect(find.text('Breakdown'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('whole movie'), 200);
      expect(find.textContaining('whole movie'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nav bar selects tabs and shows the missed badge', (WidgetTester tester) async {
      int? selected;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: DialerNavBar(
            destinations: const <NavDestination>[
              NavDestination(icon: Icons.schedule_outlined, selectedIcon: Icons.schedule, label: 'Recents'),
              NavDestination(icon: Icons.people_outline, selectedIcon: Icons.people, label: 'Contacts'),
              NavDestination(icon: Icons.dialpad, selectedIcon: Icons.dialpad, label: 'Keypad'),
              NavDestination(icon: Icons.sticky_note_2_outlined, selectedIcon: Icons.sticky_note_2, label: 'Notes'),
              NavDestination(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings'),
            ],
            selectedIndex: 0,
            onSelected: (int index) => selected = index,
            badges: const <int, int>{0: 3},
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.text('Notes'));
      expect(selected, 3);
      await tester.tap(find.bySemanticsLabel('Keypad'));
      expect(selected, 2);
      await tester.pumpAndSettle();
    });
  });
}

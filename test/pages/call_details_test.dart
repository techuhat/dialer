import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:umar_dailer/core/call_service.dart';
import 'package:umar_dailer/core/models/call_log_entry.dart';
import 'package:umar_dailer/core/services/call_log_service.dart';
import 'package:umar_dailer/pages/recents/call_details_page.dart';

void main() {
  final DateTime now = DateTime.now();
  final List<CallLogEntry> history = <CallLogEntry>[
    for (int i = 0; i < 40; i++)
      CallLogEntry(
        id: '$i',
        number: '+919876543210',
        type: i.isEven ? CallType.incoming : CallType.outgoing,
        timestamp: now.subtract(Duration(hours: i * 7)),
        duration: 60,
      ),
  ];
  final List<Map<Object?, Object?>> requests = <Map<Object?, Object?>>[];

  setUp(() {
    requests.clear();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    CallLogService.setEntriesForTest(const <CallLogEntry>[]);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      CallService.channel,
      (MethodCall call) async {
        if (call.method != 'getCallLog') return null;
        requests.add(call.arguments as Map<Object?, Object?>);
        return <String, Object?>{'rows': history.map((CallLogEntry e) => e.toMap()).toList(), 'more': false};
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(CallService.channel, null);
  });

  testWidgets('a long history opens as a summary and the latest calls, the rest on request', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: CallDetailsPage(number: '09876543210', name: 'Asha Verma')));
    await tester.pump();

    expect(requests.single['number'], '09876543210');
    expect(find.text('40'), findsOneWidget);
    expect(find.text('40m 0s'), findsOneWidget);
    expect(find.text('20 incoming'), findsOneWidget);
    expect(find.text('20 outgoing'), findsOneWidget);

    final Finder more = find.text('Show 25 more calls');
    await tester.scrollUntilVisible(more, 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('1m 0s'), findsWidgets);
    await tester.tap(more);
    await tester.pump();

    expect(more, findsNothing);
    expect(tester.takeException(), isNull);
  });
}

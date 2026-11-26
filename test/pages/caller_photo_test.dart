import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umar_dailer/core/models/contact.dart';
import 'package:umar_dailer/core/services/caller_details.dart';
import 'package:umar_dailer/core/widgets/contact_avatar.dart';
import 'package:umar_dailer/pages/call/call_widgets.dart';
import 'package:umar_dailer/pages/call/caller_backdrop.dart';

import '../helpers/photos.dart';

CallerDetails _caller(Uint8List? photo, [Size? size]) => CallerDetails(
  contact: Contact(id: '7', name: 'Asha Verma', phones: const <PhoneNumber>[], photoBytes: photo),
  photoSize: size,
  number: '9876543210',
);

Future<void> _pump(WidgetTester tester, CallerDetails details, {bool reveal = false, bool still = false}) {
  return tester.pumpWidget(
    MaterialApp(
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: still),
        child: child!,
      ),
      home: CallBackground(
        details: details,
        reveal: reveal,
        child: CallerHeader(name: 'Asha Verma', details: details),
      ),
    ),
  );
}

void main() {
  late Uint8List sharp;
  late Uint8List thumbnail;

  setUpAll(() async {
    sharp = await pngBytes(720, 720);
    thumbnail = await pngBytes(96, 96);
  });

  testWidgets('a sharp photo is the poster: painted once, no circle', (WidgetTester tester) async {
    await _pump(tester, _caller(sharp, const Size(720, 720)));

    expect(photoPaints, findsOneWidget);
    expect(find.byType(ContactAvatar), findsNothing);
    expect(find.text('Asha Verma'), findsOneWidget);
  });

  testWidgets('a small photo sits in the circle over a wash of itself, with no blur filter to run', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _caller(thumbnail, const Size(96, 96)));

    expect(find.byType(ContactAvatar), findsOneWidget);
    expect(photoPaints, findsNWidgets(2));
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('no photo keeps the initials on the brand gradient', (WidgetTester tester) async {
    await _pump(tester, _caller(null));

    expect(find.byType(ContactAvatar), findsOneWidget);
    expect(photoPaints, findsNothing);
  });

  testWidgets('the poster scans in once, then stays still', (WidgetTester tester) async {
    await _pump(tester, _caller(sharp, const Size(720, 720)), reveal: true);
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('with reduced motion the poster shows at once', (WidgetTester tester) async {
    await _pump(tester, _caller(sharp, const Size(720, 720)), reveal: true, still: true);

    expect(tester.hasRunningAnimations, isFalse);
  });
}

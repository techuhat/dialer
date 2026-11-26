import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umar_dailer/core/widgets/contact_avatar.dart';
import 'package:umar_dailer/pages/contact_photo_preview_page.dart';

import '../helpers/photos.dart';

/// The page measures the photo on the real event loop before it settles on a style.
Future<void> _pumpPreview(WidgetTester tester, Uint8List photo) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(
        home: ContactPhotoPreviewPage(photoBytes: photo, contactId: '7', contactName: 'Asha Verma'),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
}

void main() {
  testWidgets('a sharp photo previews as the call poster: painted once, name at the top', (WidgetTester tester) async {
    final Uint8List photo = (await tester.runAsync(() => pngBytes(720, 720)))!;
    await _pumpPreview(tester, photo);

    expect(photoPaints, findsOneWidget);
    expect(find.byType(ContactAvatar), findsNothing);
    expect(tester.getCenter(find.text('Asha Verma')).dy, lessThan(780 * 0.3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a small photo previews in the circle, as the call screen will show it', (WidgetTester tester) async {
    final Uint8List photo = (await tester.runAsync(() => pngBytes(96, 96)))!;
    await _pumpPreview(tester, photo);

    expect(find.byType(ContactAvatar), findsOneWidget);
    expect(photoPaints, findsNWidgets(2));
  });
}

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:umar_dailer/core/models/contact_photo_settings.dart';

import '../helpers/photos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final Uint8List bytes = Uint8List(1);

  test('no photo gets the initials', () {
    expect(PhotoStyle.of(null, null), PhotoStyle.none);
  });

  test('a photo sharp enough to fill the screen becomes the poster', () {
    expect(PhotoStyle.of(bytes, const Size(720, 720)), PhotoStyle.poster);
    expect(PhotoStyle.of(bytes, const Size(1080, 400)), PhotoStyle.poster);
  });

  test('a thumbnail, or a photo of unknown size, stays in the circle', () {
    expect(PhotoStyle.of(bytes, const Size(96, 96)), PhotoStyle.ambient);
    expect(PhotoStyle.of(bytes, const Size(1080, 399)), PhotoStyle.ambient);
    expect(PhotoStyle.of(bytes, null), PhotoStyle.ambient);
  });

  test('measure reads the pixel size from the image header', () async {
    expect(await PhotoStyle.measure(await pngBytes(12, 7)), const Size(12, 7));
    expect(await PhotoStyle.measure(Uint8List.fromList(<int>[1, 2, 3])), isNull);
  });
}

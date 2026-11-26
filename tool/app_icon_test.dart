// Draws the launcher icons with DialMarkPainter, the painter of the dial inside the app, so the
// icon and the dial never drift apart. After changing the mark, run:
//   flutter test tool/app_icon_test.dart
//   dart run flutter_launcher_icons     (iOS, from assets/brand/app_icon_ios.png)
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umar_dailer/core/widgets/nav_parts.dart';

const String _res = 'android/app/src/main/res';
const Map<String, double> _densities = <String, double>{'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4};

Future<void> _png(String path, int pixels, void Function(Canvas canvas, double size) draw) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  draw(Canvas(recorder), pixels.toDouble());
  final ui.Image image = await recorder.endRecording().toImage(pixels, pixels);
  final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// Paints the mark centred on the canvas with the given radius.
void _mark(Canvas canvas, double size, double radius, DialMarkPainter painter) {
  canvas
    ..save()
    ..translate(size / 2 - radius, size / 2 - radius);
  painter.paint(canvas, Size.square(radius * 2));
  canvas.restore();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('draws the launcher icons', () async {
    for (final MapEntry<String, double> density in _densities.entries) {
      // Before adaptive icons: the round mark, 44dp across on a 48dp canvas.
      await _png(
        '$_res/mipmap-${density.key}/launcher_icon.png',
        (48 * density.value).round(),
        (Canvas canvas, double size) => _mark(canvas, size, size * 22 / 48, const DialMarkPainter()),
      );
      // Adaptive layers are 108dp and launchers show the middle 72dp; the mark fills that circle
      // and its ticks stay inside the 66dp safe zone. The disc is the gradient background layer.
      final int layer = (108 * density.value).round();
      await _png(
        '$_res/drawable-${density.key}/ic_launcher_foreground.png',
        layer,
        (Canvas canvas, double size) => _mark(canvas, size, size / 3, const DialMarkPainter(disc: false)),
      );
      await _png(
        '$_res/drawable-${density.key}/ic_launcher_monochrome.png',
        layer,
        (Canvas canvas, double size) =>
            _mark(canvas, size, size / 3, const DialMarkPainter(disc: false, monochrome: true)),
      );
    }

    // iOS rounds the corners itself, so its icon is the full gradient square behind the mark.
    await _png('assets/brand/app_icon_ios.png', 1024, (Canvas canvas, double size) {
      final Rect square = Offset.zero & Size.square(size);
      canvas.drawRect(square, Paint()..shader = RotaryDialFace.gradient.createShader(square));
      _mark(canvas, size, size * 0.4, const DialMarkPainter(disc: false));
    });
  });
}

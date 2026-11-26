import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// PNG bytes of a [width]×[height] "portrait": a face-coloured disc on a blue ground.
/// Needs the real event loop: call it from `tester.runAsync` inside widget tests.
Future<Uint8List> pngBytes(int width, int height) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawColor(const Color(0xFF3D6E9E), BlendMode.src)
    ..drawCircle(Offset(width / 2, height * 0.42), width * 0.22, Paint()..color = const Color(0xFFE8C4A0));
  final ui.Image image = await recorder.endRecording().toImage(width, height);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

bool _isPhoto(ImageProvider<Object> image) =>
    image is MemoryImage || (image is ResizeImage && image.imageProvider is MemoryImage);

/// Every widget that paints a contact photo: memory [Image]s (resized or not) and box decorations
/// with an image.
final Finder photoPaints = find.byWidgetPredicate(
  (Widget widget) =>
      (widget is Image && _isPhoto(widget.image)) ||
      (widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).image != null),
);

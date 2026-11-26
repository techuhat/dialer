import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/contact_photo_settings.dart';

/// Full-bleed contact photo honouring the per-contact [ContactPhotoSettings].
class PhotoBackdrop extends StatelessWidget {
  const PhotoBackdrop({
    required this.photo,
    this.settings,
    this.defaultOverlay = 0.35,
    this.topShade = 0.5,
    this.backgroundColor = const Color(0xFF0A1929),
    super.key,
  });

  final Uint8List photo;
  final ContactPhotoSettings? settings;
  final double defaultOverlay;

  /// Overlay strength at the top relative to the bottom, which carries the controls.
  final double topShade;
  final Color backgroundColor;

  static BoxFit boxFit(String mode) => switch (mode) {
        PhotoFitMode.contain => BoxFit.contain,
        PhotoFitMode.fill => BoxFit.fill,
        PhotoFitMode.fitWidth => BoxFit.fitWidth,
        PhotoFitMode.fitHeight => BoxFit.fitHeight,
        _ => BoxFit.cover,
      };

  @override
  Widget build(BuildContext context) {
    final BoxFit fit = boxFit(settings?.fitMode ?? PhotoFitMode.cover);
    final double overlay = settings?.overlayOpacity ?? defaultOverlay;
    final double rotation = settings?.rotation ?? 0;
    Widget image = Image.memory(photo, fit: fit, gaplessPlayback: true, filterQuality: FilterQuality.medium);
    if (rotation != 0) image = Transform.rotate(angle: rotation * math.pi / 180, child: image);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(color: backgroundColor),
        Center(child: image),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.black.withValues(alpha: overlay * topShade),
                Colors.black.withValues(alpha: overlay),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

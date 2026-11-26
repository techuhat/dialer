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
    this.wash = false,
    this.backgroundColor = const Color(0xFF0A1929),
    super.key,
  });

  final Uint8List photo;
  final ContactPhotoSettings? settings;
  final double defaultOverlay;

  /// Overlay strength at the top relative to the bottom, which carries the controls.
  final double topShade;

  /// Only a soft wash of the photo's colours: decoded a few pixels wide and stretched, which blurs
  /// it for free instead of running a blur filter every frame behind the call animations.
  final bool wash;
  final Color backgroundColor;

  /// Few enough pixels that no feature survives, only colour.
  static const int _washWidth = 4;

  static BoxFit boxFit(String mode) => switch (mode) {
        PhotoFitMode.contain => BoxFit.contain,
        PhotoFitMode.fill => BoxFit.fill,
        PhotoFitMode.fitWidth => BoxFit.fitWidth,
        PhotoFitMode.fitHeight => BoxFit.fitHeight,
        _ => BoxFit.cover,
      };

  @override
  Widget build(BuildContext context) {
    final double overlay = settings?.overlayOpacity ?? defaultOverlay;
    // Given the whole box: left to size itself, an Image keeps the photo's own aspect ratio and a
    // square photo sat in the middle of the screen whatever the fit.
    Widget image = SizedBox.expand(
      child: Image.memory(
        photo,
        fit: wash ? BoxFit.cover : boxFit(settings?.fitMode ?? PhotoFitMode.cover),
        cacheWidth: wash ? _washWidth : null,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      ),
    );
    // RotatedBox lays the photo out turned, so a sideways photo still fills the screen.
    final int turns = ((settings?.rotation ?? 0) / 90).round() % 4;
    if (turns != 0) image = RotatedBox(quarterTurns: turns, child: image);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(color: backgroundColor),
        image,
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

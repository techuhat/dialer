import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../utils/format_utils.dart';

/// Contact photo, or coloured initials, or a person glyph for bare numbers.
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({required this.name, this.photo, this.size = 48, super.key});

  final String name;
  final Uint8List? photo;
  final double size;

  /// Same palette and hash as the native notification avatar.
  static const List<Color> palette = <Color>[
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFE53935),
    Color(0xFF8E24AA),
    Color(0xFFF4511E),
    Color(0xFF00897B),
    Color(0xFFD81B60),
    Color(0xFF5E35B1),
  ];

  static Color colorFor(String name) => palette[NameUtils.stableHash(name) % palette.length];

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = photo;
    if (bytes != null) {
      return ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        ),
      );
    }

    final String initials = NameUtils.initials(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colorFor(name), shape: BoxShape.circle),
      child: initials.isEmpty
          ? Icon(Icons.person_rounded, color: Colors.white, size: size * 0.56)
          : Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * (initials.length > 1 ? 0.36 : 0.42),
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}

import 'dart:io';

import 'package:image/image.dart' as img;

/// Adds transparent padding around the base launcher icon so the final
/// generated launcher assets appear slightly smaller within their masks.
void main() {
  final input = File('launcher.png');
  if (!input.existsSync()) {
    stderr.writeln('Base launcher.png not found.');
    exitCode = 1;
    return;
  }

  final bytes = input.readAsBytesSync();
  final source = img.decodeImage(bytes);
  if (source == null) {
    stderr.writeln('Unable to decode launcher.png');
    exitCode = 1;
    return;
  }

  const scale = 0.78; // shrink to 78% to create noticeable padding
  final targetWidth = source.width;
  final targetHeight = source.height;

  final resized = img.copyResize(
    source,
    width: (source.width * scale).round(),
    height: (source.height * scale).round(),
    interpolation: img.Interpolation.linear,
  );

  final output = img.Image(width: targetWidth, height: targetHeight, numChannels: 4);

  final dx = (targetWidth - resized.width) ~/ 2;
  final dy = (targetHeight - resized.height) ~/ 2;
  img.compositeImage(output, resized, dstX: dx, dstY: dy);

  final outFile = File('launcher_padded.png');
  outFile.writeAsBytesSync(img.encodePng(output));
  stdout.writeln('Generated ${outFile.path} with padded icon.');
}

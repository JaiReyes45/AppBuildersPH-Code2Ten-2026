import 'dart:io';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

class OcrInput {
  OcrInput(this.path, this.scaleX, this.scaleY, this.resized);
  final String path;
  final double scaleX, scaleY;
  final bool resized;
  Future<void> close() async {
    if (resized) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  static Future<OcrInput> prepare(String path, {int maxLongEdge = 1600}) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      await File(path).readAsBytes(),
    );
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final longest = descriptor.width > descriptor.height
          ? descriptor.width
          : descriptor.height;
      if (longest <= maxLongEdge) return OcrInput(path, 1, 1, false);
      final ratio = maxLongEdge / longest;
      codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * ratio).round(),
        targetHeight: (descriptor.height * ratio).round(),
      );
      image = (await codec.getNextFrame()).image;
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return OcrInput(path, 1, 1, false);
      final root = await getTemporaryDirectory();
      final output = File(
        '${root.path}/sseeker-ocr-${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await output.writeAsBytes(bytes.buffer.asUint8List());
      return OcrInput(
        output.path,
        descriptor.width / image.width,
        descriptor.height / image.height,
        true,
      );
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}

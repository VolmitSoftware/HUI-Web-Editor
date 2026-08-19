library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

const int maxImportedGifFrames = 128;
const int maxImportedGifPixels = 2048 * 2048;

final class GifPngFrame {
  const GifPngFrame({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

final class GifPngAnimation {
  const GifPngAnimation({required this.frames, required this.totalFrames});

  final List<GifPngFrame> frames;
  final int totalFrames;
}

GifPngAnimation? decodeGifPngAnimation(Uint8List bytes) {
  final img.Image? decoded = img.decodeGif(bytes);
  if (decoded == null || decoded.frames.isEmpty) return null;
  final int totalFrames = decoded.frames.length;
  final int count = totalFrames > maxImportedGifFrames
      ? maxImportedGifFrames
      : totalFrames;
  final List<GifPngFrame> frames = <GifPngFrame>[];
  for (int index = 0; index < count; index++) {
    final img.Image frame = decoded.frames[index];
    if (frame.width <= 0 ||
        frame.height <= 0 ||
        frame.width * frame.height > maxImportedGifPixels) {
      return null;
    }
    frames.add(
      GifPngFrame(
        bytes: img.encodePng(frame),
        width: frame.width,
        height: frame.height,
      ),
    );
  }
  return GifPngAnimation(frames: frames, totalFrames: totalFrames);
}

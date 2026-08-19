/// Off-web codec backend for `image_library.dart`.
///
/// Image decoding needs a browser (`<img>` + 2D canvas), so the VM build simply
/// reports failure. Everything else in the library — path rules, persistence,
/// zip export — is pure Dart and works here.
library;

import 'gif_frame_codec.dart';

/// Name comes from the picked file, dimensions from the decoded bitmap, and
/// [dataUri] is always a normalized `image/png` data URI.
typedef DecodedImageFile = ({String dataUri, int width, int height});

typedef DecodedImageBatch = ({
  String name,
  List<DecodedImageFile> frames,
  int totalFrames,
});

/// Row-major RGBA flattened to 0xAARRGGBB, one entry per source pixel.
typedef DecodedPixels = ({int width, int height, List<int> argb});

/// Largest bitmap the pixel reader will materialize; Gloss images are a few
/// dozen pixels across, anything larger is a mistake and would freeze the tab.
const int maxDecodablePixels = 2048 * 2048;
const int maxDecodedAnimationFrames = maxImportedGifFrames;

Future<DecodedImageBatch?> decodeImageFileToPngFrames(Object file) async =>
    null;

Future<DecodedPixels?> readImagePixels(String dataUri) async => null;

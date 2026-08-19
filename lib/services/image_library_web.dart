/// Browser codec backend for `image_library.dart`.
///
/// Uses a detached `<canvas>` (never attached to the document) for both jobs:
/// normalizing any browser-decodable format to a PNG data URI, and reading the
/// pixel grid the plugin rasterizes one character per pixel. Data and blob URLs
/// do not taint the canvas, so `getImageData` stays legal.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'gif_frame_codec.dart';

typedef DecodedImageFile = ({String dataUri, int width, int height});

typedef DecodedImageBatch = ({
  String name,
  List<DecodedImageFile> frames,
  int totalFrames,
});

typedef DecodedPixels = ({int width, int height, List<int> argb});

const int maxDecodablePixels = 2048 * 2048;
const int maxDecodedAnimationFrames = maxImportedGifFrames;

/// [file] must be a `package:web` `File`; it is typed as [Object] so the
/// pure-Dart facade never has to import `dart:js_interop`.
Future<DecodedImageBatch?> decodeImageFileToPngFrames(Object file) async {
  final web.File source = file as web.File;
  if (source.type.toLowerCase() == 'image/gif' ||
      source.name.toLowerCase().endsWith('.gif')) {
    return _decodeGif(source);
  }
  final String url = web.URL.createObjectURL(source);
  try {
    final web.HTMLImageElement image = await _loadImage(url);
    final int width = image.naturalWidth;
    final int height = image.naturalHeight;
    if (width <= 0 || height <= 0 || width * height > maxDecodablePixels) {
      return null;
    }
    final web.CanvasRenderingContext2D? context = _context(width, height);
    if (context == null) {
      return null;
    }
    context.drawImage(image, 0, 0);
    return (
      name: source.name,
      frames: <DecodedImageFile>[
        (
          dataUri: context.canvas.toDataURL('image/png'),
          width: width,
          height: height,
        ),
      ],
      totalFrames: 1,
    );
  } catch (_) {
    return null;
  } finally {
    web.URL.revokeObjectURL(url);
  }
}

Future<DecodedImageBatch?> _decodeGif(web.File source) async {
  try {
    final JSArrayBuffer buffer = await source.arrayBuffer().toDart;
    final Uint8List bytes = buffer.toDart.asUint8List();
    final GifPngAnimation? decoded = decodeGifPngAnimation(bytes);
    if (decoded == null) return null;
    final List<DecodedImageFile> frames = <DecodedImageFile>[];
    for (final GifPngFrame frame in decoded.frames) {
      frames.add((
        dataUri: 'data:image/png;base64,${base64Encode(frame.bytes)}',
        width: frame.width,
        height: frame.height,
      ));
    }
    return (
      name: source.name,
      frames: frames,
      totalFrames: decoded.totalFrames,
    );
  } catch (_) {
    return null;
  }
}

Future<DecodedPixels?> readImagePixels(String dataUri) async {
  try {
    final web.HTMLImageElement image = await _loadImage(dataUri);
    final int width = image.naturalWidth;
    final int height = image.naturalHeight;
    if (width <= 0 || height <= 0 || width * height > maxDecodablePixels) {
      return null;
    }
    final web.CanvasRenderingContext2D? context = _context(width, height);
    if (context == null) {
      return null;
    }
    context.drawImage(image, 0, 0);
    final Uint8ClampedList rgba = context
        .getImageData(0, 0, width, height)
        .data
        .toDart;
    final List<int> argb = List<int>.filled(width * height, 0);
    for (int pixel = 0; pixel < argb.length; pixel++) {
      final int i = pixel * 4;
      argb[pixel] =
          (rgba[i + 3] << 24) |
          (rgba[i] << 16) |
          (rgba[i + 1] << 8) |
          rgba[i + 2];
    }
    return (width: width, height: height, argb: argb);
  } catch (_) {
    return null;
  }
}

web.CanvasRenderingContext2D? _context(int width, int height) {
  final web.HTMLCanvasElement canvas = web.HTMLCanvasElement()
    ..width = width
    ..height = height;
  final web.RenderingContext? context = canvas.getContext('2d');
  if (context == null) {
    return null;
  }
  return context as web.CanvasRenderingContext2D;
}

Future<web.HTMLImageElement> _loadImage(String src) {
  final Completer<web.HTMLImageElement> completer =
      Completer<web.HTMLImageElement>();
  final web.HTMLImageElement image = web.HTMLImageElement();
  late final JSFunction onLoad;
  late final JSFunction onError;
  void detach() {
    image.removeEventListener('load', onLoad);
    image.removeEventListener('error', onError);
  }

  onLoad = ((web.Event _) {
    detach();
    completer.complete(image);
  }).toJS;
  onError = ((web.Event _) {
    detach();
    completer.completeError(StateError('Image could not be decoded.'));
  }).toJS;
  image.addEventListener('load', onLoad);
  image.addEventListener('error', onError);
  image.src = src;
  return completer.future;
}

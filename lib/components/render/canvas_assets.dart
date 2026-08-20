/// Decoded bitmaps the canvas draws every frame.
///
/// Two rules govern this file, both learned from the old editor (report-old-
/// editor 5.2): never construct an `Image` inside the draw loop, and never
/// measure one before it has decoded. Everything here is cached, decoded
/// off-frame, and reported as "not ready" until it can be drawn correctly; the
/// [CanvasAssets.onReady] callback schedules the repaint that picks it up.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../logic/mc_text.dart' show mcColorCss;
import '../../services/image_library.dart';

/// Relative so the bundle works from Undertow at `/` and from the hosted site.
const String huiBackdropAssetUrl = 'assets/backdrop/hui_backdrop.webp';

/// `TextImageMenuIcon.MISSING`: 8 rows of 4 black + 4 magenta, inverted from
/// row 5 down.
const int huiMissingCheckerCells = 8;
const String huiMissingCheckerMagenta = '#f800f8';
const String huiMissingCheckerBlack = '#000000';

class CanvasAssets {
  CanvasAssets({required this.onReady});

  /// Called when a previously pending bitmap becomes drawable.
  final void Function() onReady;

  final Map<String, web.HTMLImageElement> _images =
      <String, web.HTMLImageElement>{};
  final Set<String> _pendingImages = <String>{};
  final Set<String> _failedImages = <String>{};

  final Map<String, _PixelCanvas> _pixelCanvases = <String, _PixelCanvas>{};
  web.HTMLCanvasElement? _missingChecker;

  bool _disposed = false;

  /// Backdrop photo, or null until it decodes.
  web.HTMLImageElement? get backdrop => image(huiBackdropAssetUrl);

  /// Any decoded bitmap by URL or data URI; null while decoding or on failure.
  web.HTMLImageElement? image(String url) {
    if (url.isEmpty || _failedImages.contains(url)) return null;
    final web.HTMLImageElement? cached = _images[url];
    if (cached != null) return cached;
    if (_pendingImages.add(url)) {
      _load(url);
    }
    return null;
  }

  void _load(String url) {
    final web.HTMLImageElement element = web.HTMLImageElement()
      ..decoding = 'async'
      ..src = url;
    element.decode().toDart.then<void>(
      (JSAny? _) {
        _pendingImages.remove(url);
        if (_disposed) return;
        if (element.naturalWidth <= 0) {
          _failedImages.add(url);
          return;
        }
        _images[url] = element;
        onReady();
      },
      onError: (Object _) {
        _pendingImages.remove(url);
        if (_disposed) return;
        _failedImages.add(url);
      },
    );
  }

  /// One offscreen canvas per image, one device pixel per source pixel.
  ///
  /// Minecraft text has no per-glyph alpha, so a pixel is either drawn opaque
  /// or skipped entirely — the same binarisation the plugin gets for free by
  /// emitting a coloured block glyph or a space. The plugin's test is
  /// `alpha < 255`, not `alpha == 0`: an anti-aliased edge pixel is blank in
  /// game, and the JPEG exemption never applies here because the image library
  /// re-encodes every upload to PNG.
  web.HTMLCanvasElement pixelCanvas(String key, ImagePixels pixels) {
    final _PixelCanvas? cached = _pixelCanvases[key];
    if (cached != null && identical(cached.source, pixels)) {
      return cached.canvas;
    }
    final web.HTMLCanvasElement canvas = web.HTMLCanvasElement()
      ..width = pixels.width
      ..height = pixels.height;
    final web.CanvasRenderingContext2D context =
        canvas.getContext('2d')! as web.CanvasRenderingContext2D;
    for (int y = 0; y < pixels.height; y++) {
      for (int x = 0; x < pixels.width; x++) {
        final int argb = pixels.at(x, y);
        if (((argb >> 24) & 0xFF) < 255) continue;
        context.fillStyle = mcColorCss(argb).toJS;
        context.fillRect(x.toDouble(), y.toDouble(), 1, 1);
      }
    }
    _pixelCanvases[key] = _PixelCanvas(canvas: canvas, source: pixels);
    return canvas;
  }

  /// The plugin's magenta/black placeholder, built once.
  web.HTMLCanvasElement get missingChecker {
    final web.HTMLCanvasElement? cached = _missingChecker;
    if (cached != null) return cached;
    const int size = huiMissingCheckerCells;
    final web.HTMLCanvasElement canvas = web.HTMLCanvasElement()
      ..width = size
      ..height = size;
    final web.CanvasRenderingContext2D context =
        canvas.getContext('2d')! as web.CanvasRenderingContext2D;
    for (int y = 0; y < size; y++) {
      final bool inverted = y >= size ~/ 2;
      for (int x = 0; x < size; x++) {
        final bool leftHalf = x < size ~/ 2;
        final bool magenta = leftHalf == inverted;
        context.fillStyle =
            (magenta ? huiMissingCheckerMagenta : huiMissingCheckerBlack).toJS;
        context.fillRect(x.toDouble(), y.toDouble(), 1, 1);
      }
    }
    _missingChecker = canvas;
    return canvas;
  }

  /// Drops decoded pixel grids that the image library no longer knows about.
  void prunePixelCanvases(Set<String> livePaths) {
    if (_pixelCanvases.isEmpty) return;
    _pixelCanvases.removeWhere(
      (String key, _PixelCanvas _) => !livePaths.contains(key.split('#').first),
    );
  }

  void dispose() {
    _disposed = true;
    _images.clear();
    _pendingImages.clear();
    _failedImages.clear();
    _pixelCanvases.clear();
    _missingChecker = null;
  }
}

class _PixelCanvas {
  const _PixelCanvas({required this.canvas, required this.source});

  final web.HTMLCanvasElement canvas;
  final ImagePixels source;
}

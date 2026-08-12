/// Offscreen rasterization of one icon, for the 3D preview.
///
/// The preview cannot paint into the 2D canvas, but it must not grow a second
/// renderer either: text metrics, image binarisation and item sprites have to
/// stay bit-identical between the two views. So this fits a [HuiViewport] to a
/// single [CanvasItem], wraps it in the same [CanvasBrush], and calls the same
/// [IconRenderers.paint]. The only thing that is new here is the cache.
///
/// Sprites are keyed by `spriteCacheKey`, so two identical decorations resolve
/// to ONE canvas. Consumers must blit that canvas into their own — an
/// `HTMLCanvasElement` can only live at one place in the DOM, and adopting a
/// cached one silently steals it from whoever had it first.
library;

import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../../logic/canvas_scene.dart';
import '../../logic/hui_geometry.dart';
import '../../logic/icon_content.dart';
import '../../logic/viewport_math.dart';
import '../../state/editor_store.dart' show HuiBackdropMode;
import 'canvas_assets.dart';
import 'canvas_brush.dart';
import 'icon_renderers.dart';

/// Distinct appearances held at once. A menu is dozens of components and an
/// animation cycles a handful of frames each, so this is generous.
const int huiSpriteCacheCapacity = 256;

/// Ceilings on one rasterized bitmap. A 64-row image at a high dolly would
/// otherwise ask for a canvas nothing can composite.
const int huiSpriteMaxEdgePx = 1024;
const int huiSpriteMaxPixels = 512 * 512;

/// One rasterized icon plus the rectangle its bitmap covers.
class IconSprite {
  const IconSprite({
    required this.canvas,
    required this.localRect,
    required this.pixelsPerBlock,
  });

  /// Owned by the cache. Blit it; never insert it into the DOM.
  final web.HTMLCanvasElement canvas;

  /// Block-space extent the bitmap spans, padding included, RELATIVE to the
  /// item's anchor — see [spriteExtentFor]. A quad sized AND positioned from
  /// this puts every drawn pixel exactly where the 2D canvas has it, with no
  /// second derivation to drift.
  ///
  /// Deliberately not absolute: sprites are cached by appearance, so this rect
  /// belongs to every item that shares the bitmap, not to the one that
  /// rasterized it first.
  final HuiRect localRect;

  /// Effective scale, which is the requested one unless a ceiling bit.
  final double pixelsPerBlock;

  double get widthPx => canvas.width.toDouble();

  double get heightPx => canvas.height.toDouble();
}

class IconSpriteRasterizer {
  IconSpriteRasterizer({
    required this.onReady,
    this.trueRender = true,
    this.dark = true,
  });

  /// Fired when a late bitmap decode makes previously drawn sprites stale.
  final void Function() onReady;

  /// The preview shows where icons really land, so it rasterizes with the
  /// in-game vertical bias. Fixed per instance: `spriteCacheKey` does not carry
  /// it, because one rasterizer only ever renders one mode.
  final bool trueRender;

  /// Placeholder and label chrome is drawn against the 3D stage, which is dark.
  final bool dark;

  late final CanvasAssets _assets = CanvasAssets(onReady: _onAssetReady);
  final McFontMetrics _metrics = McFontMetrics();

  /// Insertion-ordered, so the first key is the least recently used.
  final Map<String, IconSprite> _cache = <String, IconSprite>{};

  late final CanvasPalette _palette = CanvasPalette.resolve(
    dark ? HuiBackdropMode.dark : HuiBackdropMode.light,
    !dark,
  );

  bool _disposed = false;

  int get cachedCount => _cache.length;

  /// Bitmap for [item] at [pxPerBlock], or null when the icon draws nothing.
  IconSprite? sprite(
    CanvasItem item, {
    required double pxPerBlock,
    required double uiScale,
    int obfuscationTick = 0,
  }) {
    if (_disposed || !pxPerBlock.isFinite || pxPerBlock <= 0) return null;
    final String key = spriteCacheKey(
      item,
      pxPerBlock: pxPerBlock,
      uiScale: uiScale,
      obfuscationTick: obfuscationTick,
    );
    final IconSprite? cached = _cache.remove(key);
    if (cached != null) {
      // Re-inserting moves it to the tail; eviction always takes the head.
      _cache[key] = cached;
      return cached;
    }
    final IconSprite? rendered = _rasterize(
      item,
      pxPerBlock: pxPerBlock,
      uiScale: uiScale,
      obfuscationTick: obfuscationTick,
    );
    if (rendered == null) return null;
    if (_cache.length >= huiSpriteCacheCapacity) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = rendered;
    return rendered;
  }

  /// Drops every bitmap. The image library calls for this when a path is
  /// re-uploaded under the same name.
  void clear() => _cache.clear();

  void dispose() {
    _disposed = true;
    _cache.clear();
    _assets.dispose();
  }

  void _onAssetReady() {
    // A pending bitmap just became drawable, so every sprite that drew the
    // dashed placeholder in its place is stale.
    _cache.clear();
    onReady();
  }

  IconSprite? _rasterize(
    CanvasItem item, {
    required double pxPerBlock,
    required double uiScale,
    required int obfuscationTick,
  }) {
    final HuiRect local = spriteExtentFor(
      item,
      uiScale: uiScale,
      trueRender: trueRender,
    );
    if (local.w <= 0 || local.h <= 0) return null;
    final HuiRect extent = local.translate(item.anchor.x, item.anchor.y);
    final double scale = _fittedScale(extent, pxPerBlock);
    final int widthPx = (extent.w * scale).ceil();
    final int heightPx = (extent.h * scale).ceil();
    if (widthPx <= 0 || heightPx <= 0) return null;

    final web.HTMLCanvasElement canvas = web.HTMLCanvasElement()
      ..width = widthPx
      ..height = heightPx;
    final web.RenderingContext? raw = canvas.getContext('2d');
    if (raw == null) return null;

    // Device pixel ratio stays 1: the caller folds any oversampling it wants
    // into pxPerBlock, so brush pixels are backing-store pixels one for one.
    final HuiViewport viewport = HuiViewport(
      widthPx: widthPx.toDouble(),
      heightPx: heightPx.toDouble(),
      basePixelsPerBlock: scale,
    ).centerOn(extent.x, extent.y);

    IconRenderers(
      brush: CanvasBrush(
        ctx: raw as web.CanvasRenderingContext2D,
        viewport: viewport,
        palette: _palette,
      ),
      assets: _assets,
      metrics: _metrics,
      uiScale: uiScale,
      trueRender: trueRender,
      obfuscationTick: obfuscationTick,
    ).paint(item);

    return IconSprite(canvas: canvas, localRect: local, pixelsPerBlock: scale);
  }

  double _fittedScale(HuiRect extent, double requested) {
    double scale = requested;
    final double longest = math.max(extent.w, extent.h);
    if (longest > 0) {
      scale = math.min(scale, huiSpriteMaxEdgePx / longest);
    }
    final double area = extent.w * extent.h;
    if (area > 0) {
      scale = math.min(scale, math.sqrt(huiSpriteMaxPixels / area));
    }
    return scale > 0 ? scale : requested;
  }
}

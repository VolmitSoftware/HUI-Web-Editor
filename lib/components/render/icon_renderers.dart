/// The four icon renderers, drawn at the plugin's real block metrics.
///
/// Everything is derived from two constants (report-holoui 2.2):
/// `NAMETAG_SIZE = 0.21875` blocks per text line and
/// `VANILLA_TEXT_BLOCKS_PER_PIXEL = 1/40` blocks per Minecraft font pixel. A
/// full-block glyph is 9 font pixels wide, which is why an image pixel is
/// `huiCharCell = 0.225` blocks across but only `huiLineHeight` tall — images
/// really are very slightly squashed in game.
library;

import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../../logic/canvas_scene.dart';
import '../../logic/hui_geometry.dart';
import '../../logic/mc_text.dart';
import '../../services/image_library.dart';
import 'canvas_assets.dart';
import 'canvas_brush.dart';

/// Blocks per Minecraft font pixel at uiScale 1.
const double huiBlocksPerFontPixel = 1 / 40;

/// Advance of a standard Minecraft glyph, in font pixels (5 px + 1 px gap).
const double huiGlyphAdvancePixels = 6;

/// Distance from the baseline to the centre of the 8 px glyph cell, in font
/// pixels: 7 px sit above the baseline and 1 px below.
const double huiBaselineOffsetPixels = 3;

/// Characters an obfuscated span scrambles through.
const String huiObfuscatedAlphabet =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#%&@\$?!';

/// Calibrates the Minecraftia webfont so one Minecraft pixel maps to a known
/// number of CSS pixels regardless of the font's internal em size.
class McFontMetrics {
  McFontMetrics();

  /// CSS pixels of glyph advance per font-size unit, for one Minecraft pixel.
  /// The fallback assumes a 1 em = 8 font-pixel design, which is what
  /// Minecraft-Regular.ttf uses.
  double _pixelsPerFontUnit = 1 / 8;
  bool _calibrated = false;

  /// Single-glyph advances, keyed by font plus glyph. Bold runs are drawn one
  /// glyph at a time, and `measureText` per glyph per frame is not free.
  final Map<String, double> _glyphWidths = <String, double>{};

  bool get isCalibrated => _calibrated;

  /// Advance of one [glyph] at the font currently set on [ctx]. [fontKey] must
  /// identify that font, since the cache cannot see it.
  double glyphWidth(
    web.CanvasRenderingContext2D ctx,
    String glyph,
    String fontKey,
  ) {
    final String key = '$fontKey|$glyph';
    final double? cached = _glyphWidths[key];
    if (cached != null) return cached;
    final double width = ctx.measureText(glyph).width;
    if (_glyphWidths.length >= 512) _glyphWidths.clear();
    _glyphWidths[key] = width;
    return width;
  }

  /// Measures a known glyph run and solves for the font size that yields one
  /// Minecraft pixel. Safe to call repeatedly; only the first success sticks.
  void calibrate(web.CanvasRenderingContext2D ctx) {
    if (_calibrated) return;
    const String sample = 'AAAAAAAAAA';
    const double probeSize = 200;
    final String previous = ctx.font;
    ctx.font = '${probeSize}px "Minecraftia", monospace';
    final double width = ctx.measureText(sample).width;
    ctx.font = previous;
    if (!width.isFinite || width <= 0) return;
    final double pixelsPerUnit =
        width / (sample.length * huiGlyphAdvancePixels) / probeSize;
    if (!pixelsPerUnit.isFinite || pixelsPerUnit <= 0) return;
    _pixelsPerFontUnit = pixelsPerUnit;
    _calibrated = true;
  }

  /// Forces the next [calibrate] to re-measure, e.g. once the webfont lands.
  void invalidate() {
    _calibrated = false;
    _glyphWidths.clear();
  }

  /// Font size that renders one Minecraft pixel at [pixelSizePx] CSS pixels.
  double fontSizeFor(double pixelSizePx) => pixelSizePx / _pixelsPerFontUnit;
}

/// Draws one [CanvasItem]'s icon.
class IconRenderers {
  IconRenderers({
    required this.brush,
    required this.assets,
    required this.metrics,
    required this.uiScale,
    required this.trueRender,
    required this.obfuscationTick,
  });

  final CanvasBrush brush;
  final CanvasAssets assets;
  final McFontMetrics metrics;
  final double uiScale;
  final bool trueRender;

  /// Advances every 100 ms; seeds the obfuscated scramble so it is stable
  /// within a frame and different between ticks.
  final int obfuscationTick;

  /// Blocks per Minecraft font pixel at the preview scale.
  double get _blockPerFontPixel => huiBlocksPerFontPixel * uiScale;

  /// CSS pixels per Minecraft font pixel.
  double get _fontPixelPx => brush.px(_blockPerFontPixel);

  void paint(CanvasItem item) {
    switch (item.kind) {
      case CanvasIconKind.text:
        _paintText(item);
      case CanvasIconKind.image:
        _paintImage(item);
      // A custom item resolves to a plain ItemStack in game, so it draws
      // exactly where a vanilla item icon would; only the sprite differs.
      case CanvasIconKind.item:
      case CanvasIconKind.customItem:
        _paintItem(item);
      case CanvasIconKind.missing:
        _paintMissing(item);
    }
  }

  // --- text -----------------------------------------------------------------

  void _paintText(CanvasItem item) {
    final McTextResult? parsed = item.text;
    if (parsed == null || parsed.lineCount == 0) return;
    final double fontPixel = _fontPixelPx;
    if (fontPixel < 0.35) {
      // Below this the glyphs are sub-pixel mush; a solid bar reads better.
      _paintTooSmall(item);
      return;
    }
    metrics.calibrate(brush.ctx);
    final double fontSize = metrics.fontSizeFor(fontPixel);
    brush.save();
    brush.textAlign = 'left';
    brush.textBaseline = 'alphabetic';
    for (int line = 0; line < parsed.lineCount; line++) {
      _paintTextLine(
        item: item,
        spans: parsed.lines[line],
        lineIndex: line,
        lineCount: parsed.lineCount,
        fontSize: fontSize,
        fontPixel: fontPixel,
      );
    }
    brush.restore();
  }

  void _paintTextLine({
    required CanvasItem item,
    required List<McSpan> spans,
    required int lineIndex,
    required int lineCount,
    required double fontSize,
    required double fontPixel,
  }) {
    if (spans.isEmpty) return;
    final double centerY = textLineCenterY(
      anchorY: item.anchor.y,
      uiScale: uiScale,
      lineIndex: lineIndex,
      lineCount: lineCount,
      trueRender: trueRender,
    );
    final double baselineY =
        brush.sy(centerY) + huiBaselineOffsetPixels * fontPixel;

    final List<double> advances = <double>[];
    double total = 0;
    for (final McSpan span in spans) {
      brush.setMinecraftFont(fontSize, italic: span.italic);
      // Minecraft widens every GLYPH of a bold run by one font pixel, not the
      // run as a whole, so an N-glyph run is N pixels wider than plain.
      final double width = brush.measure(span.text) +
          (span.bold ? fontPixel * span.text.runes.length : 0);
      advances.add(width);
      total += width;
    }

    double x = brush.sx(item.anchor.x) - total / 2;
    for (int i = 0; i < spans.length; i++) {
      final McSpan span = spans[i];
      final double advance = advances[i];
      brush.setMinecraftFont(fontSize, italic: span.italic);
      brush.fill = rgbCss(span.color);
      final String text = span.obfuscated
          ? _scramble(span.text, item.index * 131 + lineIndex * 17 + i)
          : span.text;
      if (span.bold) {
        _fillBoldRun(
          text: text,
          x: x,
          baselineY: baselineY,
          fontSize: fontSize,
          italic: span.italic,
          fontPixel: fontPixel,
        );
      } else {
        brush.fillTextPx(text, x, baselineY);
      }
      if (span.underlined) {
        brush.fillRectPx(x, baselineY + fontPixel, advance, fontPixel);
      }
      if (span.strikethrough) {
        brush.fillRectPx(
          x,
          baselineY - huiBaselineOffsetPixels * fontPixel,
          advance,
          fontPixel,
        );
      }
      x += advance;
    }
  }

  /// Bold is the same glyph drawn twice a pixel apart with the advance widened
  /// by that pixel. Because the widening is per glyph, the run cannot be drawn
  /// in one `fillText` without the drawn text falling short of its own width.
  void _fillBoldRun({
    required String text,
    required double x,
    required double baselineY,
    required double fontSize,
    required bool italic,
    required double fontPixel,
  }) {
    final String fontKey = '${fontSize.toStringAsFixed(2)}|$italic';
    double cursor = x;
    for (final int rune in text.runes) {
      final String glyph = String.fromCharCode(rune);
      brush.fillTextPx(glyph, cursor, baselineY);
      brush.fillTextPx(glyph, cursor + fontPixel, baselineY);
      cursor += metrics.glyphWidth(brush.ctx, glyph, fontKey) + fontPixel;
    }
  }

  /// Stable within one 100 ms tick, different across ticks.
  String _scramble(String text, int salt) {
    final math.Random random = math.Random(obfuscationTick * 92821 + salt);
    final StringBuffer buffer = StringBuffer();
    for (final int unit in text.codeUnits) {
      if (unit == 0x20) {
        buffer.writeCharCode(unit);
        continue;
      }
      buffer.write(
        huiObfuscatedAlphabet[random.nextInt(huiObfuscatedAlphabet.length)],
      );
    }
    return buffer.toString();
  }

  /// Zoomed far out: draw each line as a solid bar so the layout still reads.
  void _paintTooSmall(CanvasItem item) {
    final McTextResult? parsed = item.text;
    if (parsed == null) return;
    final List<String> plain = parsed.plainLines;
    brush.save();
    brush.alpha = 0.75;
    brush.fill = brush.palette.label;
    for (int line = 0; line < parsed.lineCount; line++) {
      final double centerY = textLineCenterY(
        anchorY: item.anchor.y,
        uiScale: uiScale,
        lineIndex: line,
        lineCount: parsed.lineCount,
        trueRender: trueRender,
      );
      final int chars = plain[line].length;
      if (chars == 0) continue;
      final double width = brush.px(chars * huiTextCharWidth * uiScale);
      final double height = math.max(1, brush.px(huiLineHeight * uiScale) * 0.6);
      brush.fillRectPx(
        brush.sx(item.anchor.x) - width / 2,
        brush.sy(centerY) - height / 2,
        width,
        height,
      );
    }
    brush.restore();
  }

  // --- images ---------------------------------------------------------------

  void _paintImage(CanvasItem item) {
    final ImagePixels? pixels = item.pixels;
    final String? path = item.imagePath;
    if (pixels == null || path == null) {
      _paintPendingImage(item);
      return;
    }
    final web.HTMLCanvasElement grid = assets.pixelCanvas(
      '$path#${pixels.width}x${pixels.height}',
      pixels,
    );
    // An animated frame shorter than the tallest frame is padded with blank
    // rows at the BOTTOM, so it hangs from the top of the stack rather than
    // being centred in it.
    _blit(grid, item, rows: pixels.height);
  }

  void _paintMissing(CanvasItem item) => _blit(assets.missingChecker, item);

  void _blit(web.HTMLCanvasElement source, CanvasItem item, {int? rows}) {
    final HuiRect rect = item.visual;
    final int stackRows = math.max(1, item.shape.rows);
    final int drawnRows = math.min(math.max(1, rows ?? stackRows), stackRows);
    final double width = brush.px(rect.w);
    final double height = brush.px(rect.h) * drawnRows / stackRows;
    if (width < 0.5 || height < 0.5) return;
    brush.save();
    brush.smoothing = false;
    brush.ctx.drawImage(
      source,
      brush.sx(rect.left),
      brush.sy(rect.top),
      width,
      height,
    );
    brush.restore();
  }

  /// Decoded pixel grids arrive asynchronously; show the footprint meanwhile.
  void _paintPendingImage(CanvasItem item) {
    final HuiRect rect = item.visual;
    if (rect.w <= 0 || rect.h <= 0) return;
    brush.save();
    brush.dash(<double>[4, 4]);
    brush.lineWidth = 1;
    brush.stroke = brush.palette.placeholder;
    brush.strokeWorldRect(rect);
    brush.restore();
  }

  // --- items ----------------------------------------------------------------

  void _paintItem(CanvasItem item) {
    final HuiRect rect = item.visual;
    final double size = brush.px(rect.w);
    if (size < 0.5) return;
    final double left = brush.sx(rect.left);
    final double top = brush.sy(rect.top);

    final String? texture = item.itemTexture;
    final web.HTMLImageElement? sprite =
        texture == null ? null : assets.image(texture);
    if (sprite != null) {
      brush.save();
      brush.smoothing = false;
      brush.ctx.drawImage(sprite, left, top, size, size);
      brush.restore();
    } else {
      _paintItemPlaceholder(item, left, top, size);
    }

    if (item.itemCount > 1) {
      _paintItemCount(item);
    }
  }

  /// A key with no catalogue sprite is not necessarily invalid — the catalogue
  /// can lag the server, and a custom item has no sprite at all until the
  /// server exports one — so this reads as "no preview", not as broken.
  void _paintItemPlaceholder(
    CanvasItem item,
    double left,
    double top,
    double size,
  ) {
    final bool custom = item.kind == CanvasIconKind.customItem;
    brush.save();
    brush.lineWidth = 1.2;
    brush.dash(<double>[5, 4]);
    brush.stroke = brush.palette.placeholder;
    brush.roundedRectPx(left, top, size, size, math.min(6, size / 4));
    brush.ctx.stroke();
    brush.clearDash();
    if (size >= 28) {
      final double labelSize = math.min(11, size / 4.5);
      final double centerY =
          top + size / 2 + (custom ? -labelSize * 0.45 : 0);
      brush.setUiFont(labelSize, bold: true);
      brush.textAlign = 'center';
      brush.textBaseline = 'middle';
      brush.fill = brush.palette.labelMuted;
      brush.fillTextPx(
        brush.ellipsize(item.itemKey, size - 8),
        left + size / 2,
        centerY,
      );
      if (custom) {
        // Which plugin owns the id matters as much as the id itself: the same
        // bare id can exist in two providers.
        brush.setUiFont(math.max(8, labelSize * 0.82));
        brush.alpha = 0.75;
        brush.fillTextPx(
          brush.ellipsize(
            item.itemProvider.isEmpty ? 'auto' : item.itemProvider,
            size - 8,
          ),
          left + size / 2,
          centerY + labelSize * 1.15,
        );
      }
    }
    brush.restore();
  }

  void _paintItemCount(CanvasItem item) {
    final double fontPixel = _fontPixelPx;
    if (fontPixel < 0.5) return;
    metrics.calibrate(brush.ctx);
    final double labelY = trueRender
        ? itemCountLabelY(anchorY: item.anchor.y, uiScale: uiScale)
        : item.visual.bottom - huiLineHeight * uiScale * 0.6;
    brush.save();
    brush.setMinecraftFont(metrics.fontSizeFor(fontPixel));
    brush.textAlign = 'center';
    brush.textBaseline = 'alphabetic';
    brush.fill = '#ffffff';
    final double baseline =
        brush.sy(labelY) + huiBaselineOffsetPixels * fontPixel;
    final String text = '${item.itemCount}';
    final double x = brush.sx(item.anchor.x);
    brush.fillTextPx(text, x, baseline);
    // The plugin draws this label bold, which in Minecraft is a 1 px re-draw.
    brush.fillTextPx(text, x + fontPixel, baseline);
    brush.restore();
  }
}

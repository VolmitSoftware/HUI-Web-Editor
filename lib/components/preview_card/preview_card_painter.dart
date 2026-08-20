/// Paints one container-preview frame at an integer pixel scale.
///
/// Stateless apart from the font calibration, so a frame is a pure function of
/// ([PreviewCardScene], [PreviewCardView], [PreviewCardFrameOptions]). Nothing
/// in here reads the store, which is what lets a drag repaint without a Jaspr
/// rebuild — the same contract [CanvasPainter](../canvas/canvas_painter.dart)
/// holds for the component canvas.
///
/// The one value that flows back out is the measured width of each label: the
/// format carries no label extent (`CardLabel.size` is always null), so the
/// only thing that knows how wide a label really is, is the context that just
/// drew it. The viewport hands those widths to the hit model.
library;

import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../../logic/preview_card_edit.dart';
import '../../logic/preview_card_scene.dart';
import '../../logic/preview_sim.dart';
import '../../logic/mc_text.dart';
import '../render/canvas_brush.dart';
import '../render/icon_renderers.dart';

/// Screen radius of a resize grip, and the same number the interaction layer
/// grabs one from.
const double previewHandleRadiusPx = 4;

/// Grid spacing in CARD pixels. 8 is half a well and a third of the 24 px
/// major, so a slot grid lands on the lines instead of between them.
const int previewGridMinorPx = 8;
const int previewGridMajorPx = 24;

/// Below this the grid is denser than the pixels it would describe.
const int previewGridMinZoom = 3;

class PreviewCardFrameOptions {
  const PreviewCardFrameOptions({
    required this.showGrid,
    this.fillBackground = true,
    this.selectedElement,
    this.hoveredItem,
    this.handles = const <PreviewHandleSpot>[],
    this.labelWidths,
  });

  final bool showGrid;

  /// False for the in-game preview, whose backdrop is the game screen behind
  /// the canvas. The artboard fill is an editor surface; painting it there
  /// would cover the frame the card is supposed to be sitting on.
  final bool fillBackground;

  /// Index into `doc.elements`. EVERY item that element emitted is ringed, so a
  /// `repeat` shows the whole run it stands for rather than one instance.
  final int? selectedElement;

  final int? hoveredItem;

  /// Resize grips for the selection, in card pixels. Empty when the selected
  /// element has no constant extent to drag.
  final List<PreviewHandleSpot> handles;

  /// Widths measured by the previous frame, so selection rings around a label
  /// are right on the first frame after a change rather than one late.
  final List<double>? labelWidths;
}

class PreviewCardPainter {
  PreviewCardPainter({required this.metrics});

  final McFontMetrics metrics;

  /// Draws one frame and returns the measured label widths in CARD pixels,
  /// aligned with `scene.items` (0 for anything that is not a label).
  List<double> paint({
    required web.CanvasRenderingContext2D ctx,
    required PreviewCardView view,
    required PreviewCardScene scene,
    required PreviewCardFrameOptions options,
    required CanvasPalette palette,
    required double devicePixelRatio,
  }) {
    ctx.setTransform(devicePixelRatio.toJS, 0, 0, devicePixelRatio, 0, 0);
    ctx.clearRect(0, 0, view.widthPx, view.heightPx);
    if (options.fillBackground) {
      _fill(ctx, palette.background);
      ctx.fillRect(0, 0, view.widthPx, view.heightPx);
    }
    if (options.showGrid) _paintGrid(ctx, view, palette);

    final List<double> labelWidths = List<double>.filled(
      scene.items.length,
      0,
      growable: false,
    );
    for (final int index in previewPaintOrder(scene)) {
      final CardItem item = scene.items[index];
      switch (item) {
        case CardPanel():
          _paintRect(
            ctx,
            view,
            item.x,
            item.y,
            item.width,
            item.height,
            item.color,
          );
        case CardCell():
          _paintRect(
            ctx,
            view,
            item.x,
            item.y,
            item.size,
            item.size,
            item.color,
          );
        case CardSlot():
          _paintSlot(ctx, view, item, palette);
        case CardLabel():
          labelWidths[index] = _paintLabel(ctx, view, item, palette);
      }
    }

    _paintHover(ctx, view, scene, options, palette, labelWidths);
    _paintSelection(ctx, view, scene, options, palette, labelWidths);
    _paintHandles(ctx, view, options, palette);
    if (scene.items.isEmpty) _paintEmptyState(ctx, view, palette);
    return labelWidths;
  }

  // --- chrome ---------------------------------------------------------------

  /// Minor lines, major lines and the two card axes. Drawn across the whole
  /// surface rather than only under the card: the author places elements by
  /// their distance from the centre, and a grid that stopped at the content
  /// would stop exactly where it is needed.
  void _paintGrid(
    web.CanvasRenderingContext2D ctx,
    PreviewCardView view,
    CanvasPalette palette,
  ) {
    if (view.zoom < previewGridMinZoom) return;
    ctx.save();
    ctx.lineWidth = 1;
    _stroke(ctx, palette.gridMinor);
    _gridLines(ctx, view, previewGridMinorPx);
    _stroke(ctx, palette.gridMajor);
    _gridLines(ctx, view, previewGridMajorPx);
    _stroke(ctx, palette.axis);
    _line(
      ctx,
      _crisp(view.toScreenX(0)),
      0,
      _crisp(view.toScreenX(0)),
      view.heightPx,
    );
    _line(
      ctx,
      0,
      _crisp(view.toScreenY(0)),
      view.widthPx,
      _crisp(view.toScreenY(0)),
    );
    ctx.restore();
  }

  void _gridLines(
    web.CanvasRenderingContext2D ctx,
    PreviewCardView view,
    int stepCardPx,
  ) {
    final double step = (stepCardPx * view.zoom).toDouble();
    if (step < 4) return;
    for (double x = view.originX % step; x < view.widthPx; x += step) {
      _line(ctx, _crisp(x), 0, _crisp(x), view.heightPx);
    }
    for (double y = view.originY % step; y < view.heightPx; y += step) {
      _line(ctx, 0, _crisp(y), view.widthPx, _crisp(y));
    }
  }

  // --- items ----------------------------------------------------------------

  void _paintRect(
    web.CanvasRenderingContext2D ctx,
    PreviewCardView view,
    int cardX,
    int cardY,
    int width,
    int height,
    int argb,
  ) {
    if (width <= 0 || height <= 0 || _alpha(argb) == 0) return;
    _fill(ctx, previewArgbCss(argb));
    ctx.fillRect(
      view.toScreenX(cardX - width / 2),
      view.toScreenY(cardY + height / 2),
      width * view.zoom,
      height * view.zoom,
    );
  }

  /// The well, then whatever the simulation holds in that slot. The stack is a
  /// labelled placeholder rather than a sprite: a preview slot draws a live
  /// `ItemStack` in game, and the editor has no way to know which one until the
  /// simulation panel says so.
  void _paintSlot(
    web.CanvasRenderingContext2D ctx,
    PreviewCardView view,
    CardSlot slot,
    CanvasPalette palette,
  ) {
    _paintRect(ctx, view, slot.x, slot.y, slot.size, slot.size, slot.wellColor);
    final double size = (slot.size * view.zoom).toDouble();
    final double left = view.toScreenX(slot.x - slot.size / 2);
    final double top = view.toScreenY(slot.y + slot.size / 2);
    final SimSlotItem? item = slot.item;
    if (item == null) {
      if (size < 10) return;
      ctx.save();
      ctx.globalAlpha = 0.5;
      ctx.lineWidth = 1;
      _stroke(ctx, palette.placeholder);
      ctx.strokeRect(left + 2.5, top + 2.5, size - 5, size - 5);
      ctx.restore();
      return;
    }
    ctx.save();
    _fill(ctx, palette.labelBackground);
    ctx.fillRect(left + 2, top + 2, size - 4, size - 4);
    if (size >= 22) {
      ctx.font =
          '600 ${math.min(11, size / 3.4).toStringAsFixed(1)}px '
          '"Geist", ui-sans-serif, system-ui, sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      _fill(ctx, palette.label);
      ctx.fillText(_slotGlyph(item.material), left + size / 2, top + size / 2);
      if (item.count > 1) {
        ctx.textAlign = 'right';
        ctx.textBaseline = 'alphabetic';
        _fill(ctx, palette.labelMuted);
        ctx.fillText('${item.count}', left + size - 3, top + size - 3);
      }
    }
    ctx.restore();
  }

  /// Two letters is what fits inside an 18 px well at a readable size, and the
  /// full key is one hover away in the inspector.
  static String _slotGlyph(String material) {
    final List<String> words = material.split('_');
    if (words.length > 1 && words[0].isNotEmpty && words[1].isNotEmpty) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return material.isEmpty
        ? '?'
        : material.substring(0, math.min(2, material.length)).toUpperCase();
  }

  /// Draws one label's runs, centred on its position, and returns its width in
  /// card pixels. One Minecraft font pixel is one card pixel, which is the
  /// mapping [previewGlyphAdvancePx] describes.
  double _paintLabel(
    web.CanvasRenderingContext2D ctx,
    PreviewCardView view,
    CardLabel label,
    CanvasPalette palette,
  ) {
    if (label.text.isEmpty) return 0;
    final double fontPixel = view.zoom.toDouble();
    final double nominal = previewLabelWidth(label);
    if (fontPixel < 0.5) {
      // Too small for glyphs: a bar still shows where the line sits.
      _paintLabelBar(ctx, view, label, nominal, palette);
      return nominal;
    }
    metrics.calibrate(ctx);
    final double fontSize = metrics.fontSizeFor(fontPixel);

    final List<double> advances = <double>[];
    double total = 0;
    for (final McSpan span in label.text) {
      _setMinecraftFont(ctx, fontSize, span.italic);
      // Minecraft widens every GLYPH of a bold run by one pixel, not the run.
      final double width =
          ctx.measureText(span.text).width +
          (span.bold ? fontPixel * span.text.runes.length : 0);
      advances.add(width);
      total += width;
    }

    // 7 glyph pixels sit above the baseline and 1 below, so dropping the
    // baseline by [huiBaselineOffsetPixels] centres the cell on the position
    // the format names — the same offset the component canvas draws text at.
    final double baselineY =
        view.toScreenY(label.y) + huiBaselineOffsetPixels * fontPixel;
    double x = view.toScreenX(label.x) - total / 2;

    ctx.save();
    ctx.textAlign = 'left';
    ctx.textBaseline = 'alphabetic';
    if (_alpha(label.background) != 0) {
      _fill(ctx, previewArgbCss(label.background));
      ctx.fillRect(
        x - fontPixel,
        view.toScreenY(label.y + previewLabelLineHeightPx / 2),
        total + fontPixel * 2,
        previewLabelLineHeightPx * view.zoom,
      );
    }
    for (int i = 0; i < label.text.length; i++) {
      final McSpan span = label.text[i];
      _setMinecraftFont(ctx, fontSize, span.italic);
      _fill(ctx, mcColorCss(span.color));
      if (span.bold) {
        _fillBoldRun(
          ctx,
          span.text,
          x,
          baselineY,
          fontSize,
          span.italic,
          fontPixel,
        );
      } else {
        ctx.fillText(span.text, x, baselineY);
      }
      if (span.underlined) {
        ctx.fillRect(x, baselineY + fontPixel, advances[i], fontPixel);
      }
      if (span.strikethrough) {
        ctx.fillRect(
          x,
          baselineY - huiBaselineOffsetPixels * fontPixel,
          advances[i],
          fontPixel,
        );
      }
      x += advances[i];
    }
    ctx.restore();
    return total / view.zoom;
  }

  /// Bold is the same glyph drawn twice a pixel apart, with the advance widened
  /// by that pixel — so the run cannot be drawn in one `fillText`.
  void _fillBoldRun(
    web.CanvasRenderingContext2D ctx,
    String text,
    double x,
    double baselineY,
    double fontSize,
    bool italic,
    double fontPixel,
  ) {
    final String fontKey = '${fontSize.toStringAsFixed(2)}|$italic';
    double cursor = x;
    for (final int rune in text.runes) {
      final String glyph = String.fromCharCode(rune);
      ctx.fillText(glyph, cursor, baselineY);
      ctx.fillText(glyph, cursor + fontPixel, baselineY);
      cursor += metrics.glyphWidth(ctx, glyph, fontKey) + fontPixel;
    }
  }

  void _paintLabelBar(
    web.CanvasRenderingContext2D ctx,
    PreviewCardView view,
    CardLabel label,
    double widthCardPx,
    CanvasPalette palette,
  ) {
    if (widthCardPx <= 0) return;
    ctx.save();
    ctx.globalAlpha = 0.75;
    _fill(ctx, palette.label);
    ctx.fillRect(
      view.toScreenX(label.x - widthCardPx / 2),
      view.toScreenY(label.y) - 1,
      widthCardPx * view.zoom,
      math.max(1, view.zoom * 0.6),
    );
    ctx.restore();
  }

  // --- overlays -------------------------------------------------------------

  void _paintHover(
    web.CanvasRenderingContext2D ctx,
    PreviewCardView view,
    PreviewCardScene scene,
    PreviewCardFrameOptions options,
    CanvasPalette palette,
    List<double> labelWidths,
  ) {
    final int? index = options.hoveredItem;
    if (index == null || index >= scene.items.length) return;
    if (previewElementIndexOf(scene, index) == options.selectedElement) return;
    ctx.save();
    ctx.lineWidth = 1;
    ctx.globalAlpha = 0.7;
    _stroke(ctx, palette.label);
    _strokeBox(
      ctx,
      view,
      previewItemBox(
        scene.items[index],
        labelWidth: _widthAt(labelWidths, index),
      ),
    );
    ctx.restore();
  }

  /// Every instance of the selected element rings, so a `repeat` reads as the
  /// one thing it is. The dash is the same shape language the component canvas
  /// uses for a selection; it does not march here because a preview frame is
  /// already repainting on the simulation clock.
  void _paintSelection(
    web.CanvasRenderingContext2D ctx,
    PreviewCardView view,
    PreviewCardScene scene,
    PreviewCardFrameOptions options,
    CanvasPalette palette,
    List<double> labelWidths,
  ) {
    final int? selected = options.selectedElement;
    if (selected == null) return;
    ctx.save();
    ctx.setLineDash(<JSNumber>[6.toJS, 4.toJS].toJS);
    ctx.lineWidth = 1.6;
    _stroke(ctx, palette.selection);
    for (int i = 0; i < scene.items.length; i++) {
      if (previewElementIndexOf(scene, i) != selected) continue;
      _strokeBox(
        ctx,
        view,
        previewItemBox(scene.items[i], labelWidth: _widthAt(labelWidths, i)),
      );
    }
    ctx.restore();
  }

  void _paintHandles(
    web.CanvasRenderingContext2D ctx,
    PreviewCardView view,
    PreviewCardFrameOptions options,
    CanvasPalette palette,
  ) {
    if (options.handles.isEmpty) return;
    ctx.save();
    ctx.lineWidth = 1.5;
    _stroke(ctx, palette.selection);
    _fill(ctx, palette.background);
    for (final PreviewHandleSpot spot in options.handles) {
      final double x = view.toScreenX(spot.x);
      final double y = view.toScreenY(spot.y);
      ctx.fillRect(
        x - previewHandleRadiusPx,
        y - previewHandleRadiusPx,
        previewHandleRadiusPx * 2,
        previewHandleRadiusPx * 2,
      );
      ctx.strokeRect(
        x - previewHandleRadiusPx,
        y - previewHandleRadiusPx,
        previewHandleRadiusPx * 2,
        previewHandleRadiusPx * 2,
      );
    }
    ctx.restore();
  }

  void _paintEmptyState(
    web.CanvasRenderingContext2D ctx,
    PreviewCardView view,
    CanvasPalette palette,
  ) {
    ctx.save();
    ctx.font = '600 12.5px "Geist", ui-sans-serif, system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    _fill(ctx, palette.labelMuted);
    ctx.fillText(
      'Nothing drawn yet - add an element, or check the simulated state',
      view.widthPx / 2,
      view.heightPx / 2,
    );
    ctx.restore();
  }

  void _strokeBox(
    web.CanvasRenderingContext2D ctx,
    PreviewCardView view,
    PreviewBox box,
  ) {
    final double left = _crisp(view.toScreenX(box.left)) - 1;
    final double top = _crisp(view.toScreenY(box.top)) - 1;
    final double right = _crisp(view.toScreenX(box.right)) + 1;
    final double bottom = _crisp(view.toScreenY(box.bottom)) + 1;
    ctx.strokeRect(left, top, right - left, bottom - top);
  }

  static double? _widthAt(List<double> widths, int index) =>
      index < widths.length && widths[index] > 0 ? widths[index] : null;

  static void _setMinecraftFont(
    web.CanvasRenderingContext2D ctx,
    double sizePx,
    bool italic,
  ) {
    ctx.font =
        '${italic ? 'italic ' : ''}${sizePx.toStringAsFixed(2)}px '
        '"Minecraftia", "Geist Mono", monospace';
  }

  static void _fill(web.CanvasRenderingContext2D ctx, String css) =>
      ctx.fillStyle = css.toJS;

  static void _stroke(web.CanvasRenderingContext2D ctx, String css) =>
      ctx.strokeStyle = css.toJS;

  static void _line(
    web.CanvasRenderingContext2D ctx,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    ctx.beginPath();
    ctx.moveTo(x1, y1);
    ctx.lineTo(x2, y2);
    ctx.stroke();
  }

  /// Half-pixel offset keeps 1 px strokes off the seam between device pixels.
  static double _crisp(double value) => value.roundToDouble() + 0.5;
}

/// One unsigned-ARGB colour as a CSS colour, alpha included.
///
/// Channels are pulled out with integer division rather than shifts, the same
/// way `preview_expr_functions.dart` does it: a preview colour is a full
/// unsigned 32-bit value and `dart compile js` has no 32-bit signed shift to
/// lean on.
String previewArgbCss(int argb) {
  final int a = (argb ~/ 0x1000000) % 256;
  final int r = (argb ~/ 0x10000) % 256;
  final int g = (argb ~/ 0x100) % 256;
  final int b = argb % 256;
  return 'rgba($r, $g, $b, ${(a / 255).toStringAsFixed(3)})';
}

int _alpha(int argb) => (argb ~/ 0x1000000) % 256;

/// Low-level drawing helpers shared by every canvas painter.
///
/// The brush owns the world-to-screen mapping so no painter ever recomputes it,
/// and it keeps all `package:web` canvas interop in one place: `fillStyle` and
/// friends take `JSAny`, which is noisy to repeat at 200 call sites.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../logic/hui_geometry.dart';
import '../../logic/viewport_math.dart';
import '../../state/editor_store.dart' show HuiBackdropMode;

/// Every colour the canvas draws with, resolved once per frame from the
/// backdrop mode and the page theme.
class CanvasPalette {
  const CanvasPalette({
    required this.dark,
    required this.background,
    required this.scrim,
    required this.gridMinor,
    required this.gridMajor,
    required this.axis,
    required this.ground,
    required this.eyeLine,
    required this.player,
    required this.playerEdge,
    required this.label,
    required this.labelMuted,
    required this.labelBackground,
    required this.menuCenter,
    required this.anchor,
    required this.hitbox,
    required this.hitboxPassive,
    required this.selection,
    required this.selectionHalo,
    required this.overlap,
    required this.placeholder,
  });

  /// True when the canvas is drawing on a dark surface.
  final bool dark;

  final String background;

  /// Laid over the backdrop photo so overlays stay readable.
  final String scrim;

  final String gridMinor;
  final String gridMajor;
  final String axis;
  final String ground;
  final String eyeLine;
  final String player;
  final String playerEdge;
  final String label;
  final String labelMuted;
  final String labelBackground;
  final String menuCenter;
  final String anchor;
  final String hitbox;
  final String hitboxPassive;
  final String selection;
  final String selectionHalo;
  final String overlap;
  final String placeholder;

  static const CanvasPalette _darkPalette = CanvasPalette(
    dark: true,
    background: '#0a0c0d',
    scrim: 'rgba(6, 8, 9, 0.42)',
    gridMinor: 'rgba(255, 255, 255, 0.055)',
    gridMajor: 'rgba(255, 255, 255, 0.13)',
    axis: 'rgba(255, 255, 255, 0.26)',
    ground: 'rgba(126, 214, 160, 0.62)',
    eyeLine: 'rgba(126, 214, 160, 0.34)',
    player: 'rgba(226, 236, 244, 0.10)',
    playerEdge: 'rgba(226, 236, 244, 0.30)',
    label: 'rgba(240, 244, 248, 0.92)',
    labelMuted: 'rgba(240, 244, 248, 0.55)',
    labelBackground: 'rgba(10, 12, 13, 0.78)',
    menuCenter: '#f2c94c',
    anchor: '#f2994a',
    hitbox: '#4aa3ff',
    hitboxPassive: 'rgba(74, 163, 255, 0.45)',
    selection: '#6ee7b7',
    selectionHalo: 'rgba(110, 231, 183, 0.22)',
    overlap: '#ff5a5a',
    placeholder: 'rgba(240, 244, 248, 0.35)',
  );

  static const CanvasPalette _lightPalette = CanvasPalette(
    dark: false,
    background: '#f4f5f3',
    scrim: 'rgba(255, 255, 255, 0.30)',
    gridMinor: 'rgba(12, 20, 18, 0.07)',
    gridMajor: 'rgba(12, 20, 18, 0.16)',
    axis: 'rgba(12, 20, 18, 0.32)',
    ground: 'rgba(24, 122, 74, 0.72)',
    eyeLine: 'rgba(24, 122, 74, 0.40)',
    player: 'rgba(18, 28, 26, 0.09)',
    playerEdge: 'rgba(18, 28, 26, 0.34)',
    label: 'rgba(14, 20, 18, 0.92)',
    labelMuted: 'rgba(14, 20, 18, 0.58)',
    labelBackground: 'rgba(250, 250, 249, 0.86)',
    menuCenter: '#b8860b',
    anchor: '#c26a12',
    hitbox: '#1f6fd0',
    hitboxPassive: 'rgba(31, 111, 208, 0.45)',
    selection: '#0f9d6c',
    selectionHalo: 'rgba(15, 157, 108, 0.20)',
    overlap: '#d43a3a',
    placeholder: 'rgba(14, 20, 18, 0.38)',
  );

  /// The backdrop mode wins over the page theme: a light backdrop needs dark
  /// chrome even in dark mode, and the photo backdrop is always dark.
  static CanvasPalette resolve(HuiBackdropMode mode, bool pageIsLight) =>
      switch (mode) {
        HuiBackdropMode.light => _lightPalette,
        HuiBackdropMode.dark => _darkPalette,
        HuiBackdropMode.image => _darkPalette,
        HuiBackdropMode.none => pageIsLight ? _lightPalette : _darkPalette,
      };
}

/// Canvas 2D wrapper bound to one viewport. All coordinates handed to the
/// `world*` methods are blocks with y up; everything else is CSS pixels.
class CanvasBrush {
  CanvasBrush({
    required this.ctx,
    required this.viewport,
    required this.palette,
  });

  final web.CanvasRenderingContext2D ctx;
  final HuiViewport viewport;
  final CanvasPalette palette;

  double get widthPx => viewport.widthPx;

  double get heightPx => viewport.heightPx;

  double sx(double blockX) => viewport.worldToScreenX(blockX);

  double sy(double blockY) => viewport.worldToScreenY(blockY);

  double px(double blocks) => viewport.blocksToPixels(blocks);

  double blocks(double pixels) => viewport.pixelsToBlocks(pixels);

  void save() => ctx.save();

  void restore() => ctx.restore();

  set fill(String color) => ctx.fillStyle = color.toJS;

  set stroke(String color) => ctx.strokeStyle = color.toJS;

  set alpha(double value) => ctx.globalAlpha = value;

  set lineWidth(double value) => ctx.lineWidth = value;

  set smoothing(bool value) => ctx.imageSmoothingEnabled = value;

  void dash(List<double> pattern) => ctx.setLineDash(
    <JSNumber>[for (final double value in pattern) value.toJS].toJS,
  );

  void clearDash() => ctx.setLineDash(const <JSNumber>[].toJS);

  void clear() => ctx.clearRect(0, 0, widthPx, heightPx);

  void fillCanvas(String color) {
    fill = color;
    ctx.fillRect(0, 0, widthPx, heightPx);
  }

  void fillRectPx(double x, double y, double w, double h) =>
      ctx.fillRect(x, y, w, h);

  void strokeRectPx(double x, double y, double w, double h) =>
      ctx.strokeRect(x, y, w, h);

  /// Fills a block-space rectangle.
  void fillWorldRect(HuiRect rect) =>
      ctx.fillRect(sx(rect.left), sy(rect.top), px(rect.w), px(rect.h));

  /// Strokes a block-space rectangle, snapped to the pixel grid so hairlines
  /// stay crisp at any zoom.
  void strokeWorldRect(HuiRect rect, {double inset = 0}) {
    final double left = _crisp(sx(rect.left) - inset);
    final double top = _crisp(sy(rect.top) - inset);
    final double right = _crisp(sx(rect.right) + inset);
    final double bottom = _crisp(sy(rect.bottom) + inset);
    ctx.strokeRect(left, top, right - left, bottom - top);
  }

  void roundedRectPx(double x, double y, double w, double h, double radius) {
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, radius.toJS);
  }

  void linePx(double x1, double y1, double x2, double y2) {
    ctx.beginPath();
    ctx.moveTo(x1, y1);
    ctx.lineTo(x2, y2);
    ctx.stroke();
  }

  /// Full-width horizontal rule at a block-space y.
  void horizontalRule(double blockY) {
    final double y = _crisp(sy(blockY));
    linePx(0, y, widthPx, y);
  }

  /// Full-height vertical rule at a block-space x.
  void verticalRule(double blockX) {
    final double x = _crisp(sx(blockX));
    linePx(x, 0, x, heightPx);
  }

  void dot(double blockX, double blockY, double radiusPx) {
    ctx.beginPath();
    ctx.arc(sx(blockX), sy(blockY), radiusPx, 0, 6.283185307179586);
    ctx.fill();
  }

  void ring(double blockX, double blockY, double radiusPx) {
    ctx.beginPath();
    ctx.arc(sx(blockX), sy(blockY), radiusPx, 0, 6.283185307179586);
    ctx.stroke();
  }

  void crosshair(double blockX, double blockY, double armPx) {
    final double x = _crisp(sx(blockX));
    final double y = _crisp(sy(blockY));
    linePx(x - armPx, y, x + armPx, y);
    linePx(x, y - armPx, x, y + armPx);
  }

  void setUiFont(double sizePx, {bool bold = false}) {
    ctx.font =
        '${bold ? '600 ' : ''}${sizePx.toStringAsFixed(1)}px '
        '"Geist", ui-sans-serif, system-ui, sans-serif';
  }

  void setMinecraftFont(double sizePx, {bool italic = false}) {
    ctx.font =
        '${italic ? 'italic ' : ''}${sizePx.toStringAsFixed(2)}px '
        '"Minecraftia", "Geist Mono", monospace';
  }

  double measure(String text) => ctx.measureText(text).width;

  void fillTextPx(String text, double x, double y) => ctx.fillText(text, x, y);

  set textAlign(String value) => ctx.textAlign = value;

  set textBaseline(String value) => ctx.textBaseline = value;

  /// Small label chip. Returns the chip width so callers can lay several out.
  double chip(
    String text,
    double x,
    double y, {
    required String color,
    double fontSize = 10.5,
    bool bold = true,
    String? background,
    bool alignRight = false,
  }) {
    save();
    setUiFont(fontSize, bold: bold);
    textAlign = 'left';
    textBaseline = 'middle';
    clearDash();
    final double textWidth = measure(text);
    const double padX = 5;
    final double chipWidth = textWidth + padX * 2;
    final double chipHeight = fontSize + 8;
    final double left = alignRight ? x - chipWidth : x;
    fill = background ?? palette.labelBackground;
    roundedRectPx(left, y - chipHeight / 2, chipWidth, chipHeight, 4);
    ctx.fill();
    fill = color;
    fillTextPx(text, left + padX, y + 0.5);
    restore();
    return chipWidth;
  }

  /// Truncates to fit [maxWidthPx], appending an ellipsis. The font must
  /// already be set.
  String ellipsize(String text, double maxWidthPx) {
    if (maxWidthPx <= 0) return '';
    if (measure(text) <= maxWidthPx) return text;
    int low = 0;
    int high = text.length;
    while (low < high) {
      final int mid = (low + high + 1) ~/ 2;
      if (measure('${text.substring(0, mid)}...') <= maxWidthPx) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low <= 0 ? '...' : '${text.substring(0, low)}...';
  }

  /// Half-pixel offset keeps 1 px strokes from straddling two device pixels.
  double _crisp(double value) => value.roundToDouble() + 0.5;
}

/// `0xAARRGGBB` to a CSS colour, ignoring alpha (Minecraft text is opaque).
String rgbCss(int argb) {
  final String hex = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  return '#$hex';
}

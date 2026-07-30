/// World chrome: backdrop, block grid, ground line, player reference and the
/// menu-centre marker.
///
/// The frame is player-relative exactly as the plugin builds it (report-holoui
/// 2.1): x grows to the player's right, y grows up from the FEET, and the menu
/// centre sits at the menu offset. uiScale never touches the menu offset, so
/// the standoff drawn here is fixed while component spacing breathes.
library;

import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../../logic/viewport_math.dart';
import '../../model/vec3.dart';
import '../../state/editor_store.dart' show HuiBackdropMode;
import 'canvas_assets.dart';
import 'canvas_brush.dart';

/// Player eye height in blocks; the reason a menu at `y 1.7` reads at face
/// level.
const double huiPlayerEyeHeight = 1.62;

/// Standing player height in blocks.
const double huiPlayerHeight = 1.8;

/// Fills the canvas background for the current backdrop mode.
void paintBackdrop(
  CanvasBrush brush,
  CanvasAssets assets,
  HuiBackdropMode mode,
) {
  brush.clear();
  if (mode == HuiBackdropMode.none) {
    return;
  }
  if (mode != HuiBackdropMode.image) {
    brush.fillCanvas(brush.palette.background);
    return;
  }
  final web.HTMLImageElement? photo = assets.backdrop;
  brush.fillCanvas(brush.palette.background);
  if (photo == null) {
    return;
  }
  final double imageWidth = photo.naturalWidth.toDouble();
  final double imageHeight = photo.naturalHeight.toDouble();
  if (imageWidth <= 0 || imageHeight <= 0) {
    return;
  }
  // Cover fit: the backdrop is ambience, not a calibrated world reference, so
  // it stays pinned to the viewport instead of tracking pan and zoom.
  final double scale = math.max(
    brush.widthPx / imageWidth,
    brush.heightPx / imageHeight,
  );
  final double drawWidth = imageWidth * scale;
  final double drawHeight = imageHeight * scale;
  brush.save();
  brush.smoothing = true;
  brush.ctx.drawImage(
    photo,
    (brush.widthPx - drawWidth) / 2,
    (brush.heightPx - drawHeight) / 2,
    drawWidth,
    drawHeight,
  );
  brush.restore();
  brush.fillCanvas(brush.palette.scrim);
}

/// Block grid with an adaptive step, a 0.25 sub-grid when there is room, and
/// numeric rulers on the major lines.
void paintGrid(CanvasBrush brush) {
  final CanvasPalette palette = brush.palette;
  final WorldBounds view = brush.viewport.visibleWorld;
  final double pixelsPerBlock = brush.px(1);
  final double majorStep = pixelsPerBlock >= 26
      ? 1
      : pixelsPerBlock >= 6
          ? 5
          : 25;
  final bool showSubGrid = brush.px(0.25) >= 13;

  brush.save();
  brush.clearDash();
  brush.lineWidth = 1;

  if (showSubGrid) {
    brush.stroke = palette.gridMinor;
    _rules(brush, view, 0.25, vertical: true);
    _rules(brush, view, 0.25, vertical: false);
  }

  brush.stroke = palette.gridMajor;
  _rules(brush, view, majorStep, vertical: true);
  _rules(brush, view, majorStep, vertical: false);

  brush.stroke = palette.axis;
  brush.lineWidth = 1.4;
  brush.verticalRule(0);
  brush.restore();

  if (brush.px(majorStep) >= 46) {
    _paintRulerLabels(brush, view, majorStep);
  }
}

void _rules(
  CanvasBrush brush,
  WorldBounds view,
  double step,
  {required bool vertical}) {
  final double min = vertical ? view.minX : view.minY;
  final double max = vertical ? view.maxX : view.maxY;
  final int first = (min / step).floor();
  final int last = (max / step).ceil();
  if (last - first > 400) return;
  for (int i = first; i <= last; i++) {
    final double value = i * step;
    if (vertical) {
      brush.verticalRule(value);
    } else {
      brush.horizontalRule(value);
    }
  }
}

void _paintRulerLabels(CanvasBrush brush, WorldBounds view, double step) {
  final CanvasPalette palette = brush.palette;
  brush.save();
  brush.setUiFont(10, bold: false);
  brush.fill = palette.labelMuted;
  brush.textBaseline = 'middle';

  brush.textAlign = 'left';
  final int firstY = (view.minY / step).floor();
  final int lastY = (view.maxY / step).ceil();
  if (lastY - firstY <= 120) {
    for (int i = firstY; i <= lastY; i++) {
      final double value = i * step;
      if (value == 0) continue;
      brush.fillTextPx(_rulerLabel(value), 6, brush.sy(value));
    }
  }

  brush.textAlign = 'center';
  final int firstX = (view.minX / step).floor();
  final int lastX = (view.maxX / step).ceil();
  if (lastX - firstX <= 120) {
    for (int i = firstX; i <= lastX; i++) {
      final double value = i * step;
      if (value == 0) continue;
      brush.fillTextPx(_rulerLabel(value), brush.sx(value), brush.heightPx - 12);
    }
  }
  brush.restore();
}

String _rulerLabel(double value) {
  final String text = value.abs() >= 1 && value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return value > 0 ? '+$text' : text;
}

/// Ground line at y = 0 plus the standing-player reference and its eye line.
void paintPlayerReference(CanvasBrush brush) {
  final CanvasPalette palette = brush.palette;

  brush.save();
  brush.clearDash();
  brush.stroke = palette.ground;
  brush.lineWidth = 1.8;
  brush.horizontalRule(0);

  brush.dash(<double>[6, 5]);
  brush.stroke = palette.eyeLine;
  brush.lineWidth = 1.2;
  brush.horizontalRule(huiPlayerEyeHeight);
  brush.clearDash();

  brush.fill = palette.player;
  brush.stroke = palette.playerEdge;
  brush.lineWidth = 1;
  for (final _Limb limb in _playerLimbs) {
    final double left = brush.sx(limb.left);
    final double top = brush.sy(limb.top);
    final double width = brush.px(limb.right - limb.left);
    final double height = brush.px(limb.top - limb.bottom);
    brush.fillRectPx(left, top, width, height);
    brush.strokeRectPx(left, top, width, height);
  }
  brush.restore();

  brush.chip(
    'eye 1.62',
    brush.widthPx - 10,
    brush.sy(huiPlayerEyeHeight) - 11,
    color: palette.label,
    alignRight: true,
  );
  brush.chip(
    'y 0 - feet',
    brush.widthPx - 10,
    brush.sy(0) + 12,
    color: palette.label,
    alignRight: true,
  );
}

/// Yellow menu-centre marker, mirroring the plugin's `debugPosition` particle.
void paintMenuCenter(CanvasBrush brush, Vec3 menuOffset, {bool labelled = true}) {
  final CanvasPalette palette = brush.palette;
  brush.save();
  brush.clearDash();
  brush.stroke = palette.menuCenter;
  brush.lineWidth = 1.4;
  brush.crosshair(menuOffset.x, menuOffset.y, 9);
  brush.ring(menuOffset.x, menuOffset.y, 4.5);
  brush.restore();
  if (labelled) {
    brush.chip(
      'menu centre',
      brush.sx(menuOffset.x) + 12,
      brush.sy(menuOffset.y) - 12,
      color: palette.menuCenter,
    );
  }
}

class _Limb {
  const _Limb(this.left, this.bottom, this.right, this.top);

  final double left;
  final double bottom;
  final double right;
  final double top;
}

/// Stylised standing player, 1.8 blocks tall, centred on x = 0.
const List<_Limb> _playerLimbs = <_Limb>[
  _Limb(-0.19, 0, -0.03, 0.68),
  _Limb(0.03, 0, 0.19, 0.68),
  _Limb(-0.22, 0.68, 0.22, 1.30),
  _Limb(-0.34, 0.70, -0.22, 1.28),
  _Limb(0.22, 0.70, 0.34, 1.28),
  _Limb(-0.25, 1.30, 0.25, huiPlayerHeight),
];

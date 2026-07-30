/// Paints one canvas frame: world chrome, icons in depth order, then overlays.
///
/// The painter is stateless apart from its bitmap caches, so a frame is a pure
/// function of ([CanvasScene], [HuiViewport], [CanvasFrameOptions]). Nothing in
/// here reads the store, which is what lets a drag repaint without a rebuild.
library;

import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../../logic/hui_geometry.dart';
import '../../logic/viewport_math.dart';
import '../../state/editor_store.dart' show HuiBackdropMode;
import 'backdrop.dart';
import 'canvas_assets.dart';
import 'canvas_brush.dart';
import 'canvas_scene.dart';
import 'icon_renderers.dart';

class CanvasFrameOptions {
  const CanvasFrameOptions({
    required this.backdrop,
    required this.showGrid,
    required this.showHitboxes,
    required this.showAnchors,
    required this.trueRender,
    required this.uiScale,
    this.selectedId,
    this.hoveredId,
    this.draggingId,
    this.obfuscationTick = 0,
  });

  final HuiBackdropMode backdrop;
  final bool showGrid;
  final bool showHitboxes;
  final bool showAnchors;
  final bool trueRender;
  final double uiScale;
  final String? selectedId;
  final String? hoveredId;
  final String? draggingId;
  final int obfuscationTick;

  /// Component ids are only worth drawing when the user asked for the debug
  /// overlay; otherwise they cover the artwork.
  bool get showAllIds => showAnchors;
}

class CanvasPainter {
  CanvasPainter({required this.assets, required this.metrics});

  final CanvasAssets assets;
  final McFontMetrics metrics;

  void paint({
    required web.CanvasRenderingContext2D ctx,
    required HuiViewport viewport,
    required CanvasPalette palette,
    required CanvasScene scene,
    required CanvasFrameOptions options,
  }) {
    final double ratio = viewport.devicePixelRatio;
    ctx.setTransform(ratio.toJS, 0, 0, ratio, 0, 0);
    final CanvasBrush brush = CanvasBrush(
      ctx: ctx,
      viewport: viewport,
      palette: palette,
    );

    paintBackdrop(brush, assets, options.backdrop);
    if (options.showGrid) {
      paintGrid(brush);
    }
    paintPlayerReference(brush);

    _paintOverlapFills(brush, scene);

    final IconRenderers renderers = IconRenderers(
      brush: brush,
      assets: assets,
      metrics: metrics,
      uiScale: options.uiScale,
      trueRender: options.trueRender,
      obfuscationTick: options.obfuscationTick,
    );
    for (final CanvasItem item in scene.drawOrder) {
      renderers.paint(item);
    }

    if (options.showHitboxes) {
      _paintHitboxes(brush, scene);
    }
    _paintOverlapOutlines(brush, scene);

    paintMenuCenter(brush, scene.menuOffset, labelled: options.showAnchors);
    if (options.showAnchors) {
      _paintAnchors(brush, scene);
    }

    _paintDragGuides(brush, scene, options);
    _paintDepthBadges(brush, scene);
    _paintLabels(brush, scene, options);
    _paintSelection(brush, scene, options);

    if (scene.isEmpty) {
      _paintEmptyState(brush);
    }
  }

  // --- overlays -------------------------------------------------------------

  void _paintHitboxes(CanvasBrush brush, CanvasScene scene) {
    brush.save();
    brush.lineWidth = 1.2;
    for (final CanvasItem item in scene.drawOrder) {
      final HuiRect box = item.hitbox;
      if (box.w <= 0 || box.h <= 0) continue;
      if (item.clickable) {
        brush.clearDash();
        brush.stroke = brush.palette.hitbox;
      } else {
        brush.dash(<double>[4, 4]);
        brush.stroke = brush.palette.hitboxPassive;
      }
      brush.strokeWorldRect(box);
    }
    brush.restore();
  }

  void _paintOverlapFills(CanvasBrush brush, CanvasScene scene) {
    if (scene.overlaps.isEmpty) return;
    brush.save();
    brush.alpha = 0.18;
    brush.fill = brush.palette.overlap;
    for (final CanvasOverlap overlap in scene.overlaps) {
      brush.fillWorldRect(overlap.region);
    }
    brush.restore();
  }

  void _paintOverlapOutlines(CanvasBrush brush, CanvasScene scene) {
    if (scene.overlaps.isEmpty) return;
    brush.save();
    brush.dash(<double>[3, 3]);
    brush.lineWidth = 1.2;
    brush.stroke = brush.palette.overlap;
    for (final CanvasOverlap overlap in scene.overlaps) {
      brush.strokeWorldRect(overlap.region);
    }
    brush.restore();
    final CanvasOverlap first = scene.overlaps.first;
    brush.chip(
      scene.overlaps.length == 1
          ? 'overlap: ${first.firstId} + ${first.secondId}'
          : '${scene.overlaps.length} clickable overlaps',
      brush.sx(first.region.x),
      brush.sy(first.region.top) - 14,
      color: brush.palette.overlap,
    );
  }

  void _paintAnchors(CanvasBrush brush, CanvasScene scene) {
    brush.save();
    brush.fill = brush.palette.anchor;
    for (final CanvasItem item in scene.items) {
      brush.dot(item.anchor.x, item.anchor.y, 3);
    }
    brush.restore();
  }

  /// Alignment guides through the anchor of the component being dragged.
  void _paintDragGuides(
    CanvasBrush brush,
    CanvasScene scene,
    CanvasFrameOptions options,
  ) {
    final String? draggingId = options.draggingId;
    if (draggingId == null) return;
    final CanvasItem? item = scene.byId(draggingId);
    if (item == null) return;
    brush.save();
    brush.dash(<double>[3, 6]);
    brush.lineWidth = 1;
    brush.stroke = brush.palette.selection;
    brush.alpha = 0.5;
    brush.horizontalRule(item.anchor.y);
    brush.verticalRule(item.anchor.x);
    brush.restore();
  }

  void _paintDepthBadges(CanvasBrush brush, CanvasScene scene) {
    for (final CanvasItem item in scene.drawOrder) {
      final double z = item.component.offset.z;
      if (z == 0) continue;
      final HuiRect box = item.outline;
      brush.chip(
        'z ${z > 0 ? '+' : ''}${_trim(z)}',
        brush.sx(box.right) + 6,
        brush.sy(box.top) + 8,
        color: brush.palette.labelMuted,
      );
    }
  }

  void _paintLabels(
    CanvasBrush brush,
    CanvasScene scene,
    CanvasFrameOptions options,
  ) {
    for (final CanvasItem item in scene.drawOrder) {
      final bool selected = item.id == options.selectedId;
      final bool hovered = item.id == options.hoveredId;
      if (!options.showAllIds && !selected && !hovered) continue;
      final HuiRect box = item.outline;
      brush.setUiFont(10.5, bold: true);
      final double maxWidth = math.max(56, brush.px(box.w) + 48);
      brush.chip(
        brush.ellipsize(item.id, maxWidth),
        brush.sx(box.left),
        brush.sy(box.top) - 11,
        color: selected ? brush.palette.selection : brush.palette.label,
      );
    }
  }

  void _paintSelection(
    CanvasBrush brush,
    CanvasScene scene,
    CanvasFrameOptions options,
  ) {
    final String? selectedId = options.selectedId;
    if (selectedId == null) return;
    final CanvasItem? item = scene.byId(selectedId);
    if (item == null) return;
    final HuiRect box = item.outline;
    brush.save();
    brush.clearDash();
    brush.lineWidth = 4;
    brush.stroke = brush.palette.selectionHalo;
    brush.strokeWorldRect(box, inset: 3);
    brush.lineWidth = 1.6;
    brush.stroke = brush.palette.selection;
    brush.strokeWorldRect(box, inset: 3);
    brush.restore();
    _paintHandles(brush, box);
  }

  /// Corner ticks. They are decoration only: the canvas has no resize gesture
  /// because HoloUI has no per-component scale.
  void _paintHandles(CanvasBrush brush, HuiRect box) {
    const double arm = 7;
    final double left = brush.sx(box.left) - 3;
    final double right = brush.sx(box.right) + 3;
    final double top = brush.sy(box.top) - 3;
    final double bottom = brush.sy(box.bottom) + 3;
    brush.save();
    brush.clearDash();
    brush.lineWidth = 2;
    brush.stroke = brush.palette.selection;
    brush.linePx(left, top, left + arm, top);
    brush.linePx(left, top, left, top + arm);
    brush.linePx(right, top, right - arm, top);
    brush.linePx(right, top, right, top + arm);
    brush.linePx(left, bottom, left + arm, bottom);
    brush.linePx(left, bottom, left, bottom - arm);
    brush.linePx(right, bottom, right - arm, bottom);
    brush.linePx(right, bottom, right, bottom - arm);
    brush.restore();
  }

  void _paintEmptyState(CanvasBrush brush) {
    brush.save();
    brush.setUiFont(12.5, bold: true);
    brush.textAlign = 'center';
    brush.textBaseline = 'middle';
    brush.fill = brush.palette.labelMuted;
    brush.fillTextPx(
      'No components yet - add one from the Components rail',
      brush.widthPx / 2,
      brush.heightPx / 2,
    );
    brush.restore();
  }

  static String _trim(double value) {
    final String text = value.toStringAsFixed(3);
    if (!text.contains('.')) return text;
    return text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

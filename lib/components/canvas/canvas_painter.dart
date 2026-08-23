/// Paints one canvas frame: world chrome, icons in depth order, then overlays.
///
/// The painter is stateless apart from its bitmap caches, so a frame is a pure
/// function of ([CanvasScene], [HuiViewport], [CanvasFrameOptions]). Nothing in
/// here reads the store, which is what lets a drag repaint without a rebuild.
library;

import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../../l10n/hui_localizations.dart';
import '../../logic/canvas_scene.dart';
import '../../logic/hui_geometry.dart';
import '../../logic/multi_select.dart';
import '../../logic/viewport_math.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart' show HuiBackdropMode;
import '../render/canvas_assets.dart';
import '../render/canvas_brush.dart';
import '../render/icon_renderers.dart';
import 'backdrop.dart';

/// Dash pattern of the selection ring, in screen pixels, and how far one march
/// tick advances it. Both live here rather than in the viewport so the phase
/// the clock produces can never drift from the pattern it is marching.
///
/// 10 px of period at 2 px per 80 ms tick is one full cycle every 400 ms —
/// slow enough to read as a crawl rather than a strobe.
const List<double> huiSelectionDash = <double>[6, 4];
const double huiSelectionDashStep = 2;

class CanvasFrameOptions {
  const CanvasFrameOptions({
    required this.backdrop,
    required this.showGrid,
    required this.showHitboxes,
    required this.showAnchors,
    required this.trueRender,
    required this.uiScale,
    this.selectedId,
    this.selectedIds = const <String>{},
    this.hoveredId,
    this.draggingId,
    this.marquee,
    this.guides = const <AlignmentGuide>[],
    this.obfuscationTick = 0,
    this.selectionDashOffset = 0,
  });

  final HuiBackdropMode backdrop;
  final bool showGrid;
  final bool showHitboxes;
  final bool showAnchors;
  final bool trueRender;
  final double uiScale;

  /// The primary — the most recent member of [selectedIds]. It alone carries
  /// the heavy ring and the corner ticks, so a group still has an obvious
  /// "the one the inspector is editing".
  final String? selectedId;

  final Set<String> selectedIds;
  final String? hoveredId;
  final String? draggingId;

  /// Live rubber band in world blocks, or null when no marquee is running.
  final HuiRect? marquee;

  /// Smart-alignment lines for the drag in flight. Driven by the guide list
  /// alone: a correction of exactly zero still means "you are flush with this",
  /// and the line has to show.
  final List<AlignmentGuide> guides;

  final int obfuscationTick;

  /// Phase of the marching selection dash, in screen pixels. The viewport owns
  /// the clock and holds this at 0 whenever the march is not running (nothing
  /// selected, or reduced motion), so the painter stays a pure function of its
  /// options and never has to ask whether motion is allowed.
  final double selectionDashOffset;

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
    _paintSelectedButtonHitboxes(brush, scene, options);
    _paintOverlapOutlines(brush, scene);

    paintMenuCenter(brush, scene.menuOffset, labelled: options.showAnchors);
    if (options.showAnchors) {
      _paintAnchors(brush, scene);
    }

    _paintDragGuides(brush, scene, options);
    _paintSmartGuides(brush, options);
    _paintDepthBadges(brush, scene);
    _paintLabels(brush, scene, options);
    _paintSelection(brush, scene, options);
    _paintMarquee(brush, options);

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

  void _paintSelectedButtonHitboxes(
    CanvasBrush brush,
    CanvasScene scene,
    CanvasFrameOptions options,
  ) {
    if (options.selectedIds.isEmpty) return;
    brush.save();
    for (final String id in options.selectedIds) {
      final CanvasItem? item = scene.byId(id);
      if (item == null || item.component.data is! HuiButtonData) continue;
      final HuiRect box = item.hitbox;
      if (box.w <= 0 || box.h <= 0) continue;
      brush.clearDash();
      brush.fill = brush.palette.hitbox;
      brush.alpha = 0.1;
      brush.fillWorldRect(box);
      brush.alpha = 1;
      brush.lineWidth = id == options.selectedId ? 2 : 1.4;
      brush.stroke = brush.palette.hitbox;
      brush.strokeWorldRect(box);
      if (item.visual.x != box.x || item.visual.y != box.y) {
        brush.dash(<double>[3, 4]);
        brush.linePx(
          brush.sx(item.visual.x),
          brush.sy(item.visual.y),
          brush.sx(box.x),
          brush.sy(box.y),
        );
        brush.clearDash();
      }
      brush.fill = brush.palette.hitbox;
      brush.dot(box.x, box.y, id == options.selectedId ? 3.5 : 2.5);
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
          ? huiText('overlap: {first} + {second}', <String, Object?>{
              'first': first.firstId,
              'second': first.secondId,
            })
          : huiPlural(
              'canvas.clickable_overlaps',
              scene.overlaps.length,
              oneEnglish: '{count} clickable overlap',
              otherEnglish: '{count} clickable overlaps',
            ),
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

  /// Edge and centre alignments found for the drag in flight.
  ///
  /// Solid for an edge, dashed for a centre-to-centre line, so a group that is
  /// centred on something reads differently from one that is flush against it.
  void _paintSmartGuides(CanvasBrush brush, CanvasFrameOptions options) {
    if (options.guides.isEmpty) return;
    brush.save();
    brush.lineWidth = 1;
    brush.stroke = brush.palette.anchor;
    for (final AlignmentGuide guide in options.guides) {
      if (guide.match == GuideMatch.center) {
        brush.dash(<double>[3, 3]);
      } else {
        brush.clearDash();
      }
      // 10px of overshoot so the line reads as a rule rather than a bar.
      if (guide.axis == GuideAxis.vertical) {
        final double x = brush.sx(guide.position);
        brush.linePx(
          x,
          brush.sy(guide.end) - 10,
          x,
          brush.sy(guide.start) + 10,
        );
      } else {
        final double y = brush.sy(guide.position);
        brush.linePx(
          brush.sx(guide.start) - 10,
          y,
          brush.sx(guide.end) + 10,
          y,
        );
      }
    }
    brush.restore();
  }

  /// The live rubber band. Painted last of the overlays so it always reads as
  /// the thing the pointer is doing right now.
  void _paintMarquee(CanvasBrush brush, CanvasFrameOptions options) {
    final HuiRect? band = options.marquee;
    if (band == null) return;
    brush.save();
    brush.alpha = 0.12;
    brush.fill = brush.palette.selection;
    brush.fillWorldRect(band);
    brush.alpha = 1;
    brush.dash(<double>[4, 3]);
    brush.lineWidth = 1;
    brush.stroke = brush.palette.selection;
    brush.strokeWorldRect(band);
    brush.restore();
  }

  void _paintLabels(
    CanvasBrush brush,
    CanvasScene scene,
    CanvasFrameOptions options,
  ) {
    for (final CanvasItem item in scene.drawOrder) {
      final bool selected = options.selectedIds.contains(item.id);
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

  /// Every member gets a marching ring; the primary gets the halo and the
  /// corner ticks.
  ///
  /// Drawn in scene order rather than selection order so the emphasis never
  /// depends on the sequence the user happened to click in. The dash is the
  /// selection's shape language and stays whether or not it marches, so
  /// reduced motion removes the movement without redesigning the ring.
  void _paintSelection(
    CanvasBrush brush,
    CanvasScene scene,
    CanvasFrameOptions options,
  ) {
    if (options.selectedIds.isEmpty) return;
    final String? primaryId = options.selectedId;
    HuiRect? primaryBox;
    brush.save();
    _armSelectionDash(brush, options);
    for (final CanvasItem item in scene.drawOrder) {
      if (!options.selectedIds.contains(item.id)) continue;
      final HuiRect box = item.outline;
      if (item.id == primaryId) {
        primaryBox = box;
        continue;
      }
      brush.alpha = 0.8;
      brush.lineWidth = 1.2;
      brush.stroke = brush.palette.selection;
      brush.strokeWorldRect(box, inset: 3);
    }
    brush.alpha = 1;
    if (primaryBox != null) {
      // The halo stays solid: two dashed rings a hair apart beat against each
      // other while they march, which reads as a rendering fault.
      brush.clearDash();
      brush.lineWidth = 4;
      brush.stroke = brush.palette.selectionHalo;
      brush.strokeWorldRect(primaryBox, inset: 3);
      _armSelectionDash(brush, options);
      brush.lineWidth = 1.6;
      brush.stroke = brush.palette.selection;
      brush.strokeWorldRect(primaryBox, inset: 3);
    }
    // Restores the dash offset too: the 2D context saves it with the rest of
    // the drawing state, so nothing painted after this inherits the phase.
    brush.restore();
    if (primaryBox != null) _paintHandles(brush, primaryBox);
  }

  /// [CanvasBrush] has no dash-offset setter and belongs to another owner, so
  /// the phase is written straight onto the context it already exposes.
  void _armSelectionDash(CanvasBrush brush, CanvasFrameOptions options) {
    brush.dash(huiSelectionDash);
    brush.ctx.lineDashOffset = options.selectionDashOffset;
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
      huiText('No components yet - add one from the Components rail'),
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

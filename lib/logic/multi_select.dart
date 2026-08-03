/// Pure geometry for canvas multi-select: marquee hit-testing, align,
/// distribute, smart alignment guides and z-order.
///
/// Everything here works on the resolved frame from [CanvasScene] and returns
/// component offsets ready for `EditorStore.setOffsets`, which takes them
/// verbatim in one undo step. Nothing here touches the DOM or the store.
///
/// Two conventions run through the whole file:
///
///  - **Rects are [CanvasItem.outline], never the hitbox.** The user is
///    arranging what they can see, and for text the two genuinely disagree —
///    the drawn box is `chars * 0.15` wide while the collision plane is
///    `chars * lineHeight / 2` (`TextMenuIcon.java:66-72`). Aligning to the
///    invisible plane would leave visibly ragged edges. `outline` already falls
///    back to the hitbox for icons that draw nothing.
///
///  - **World positions are inverted back through the anchor.** A component
///    offset is not a world position: the anchor is
///    `menuOffset + offset * uiScale`, and the menu offset itself is NOT scaled
///    (`MenuComponent.java:50-60`, `HuiSettings.java:60-66`). Every target here
///    is computed in world blocks and then inverted with
///    `offset = (target - menuOffset) / uiScale`, rounded to four decimals the
///    way `EditorStore._round` does so exported JSON stays stable.
library;

import 'dart:math' as math;

import '../model/model.dart' show Vec3;
import 'canvas_scene.dart';
import 'hui_geometry.dart' show HuiRect;
import 'viewport_math.dart' show WorldBounds;

/// Align edges/centres of a selection against its own bounding box.
enum HuiAlign { left, centerX, right, top, middleY, bottom }

/// Axis for [distributeOffsets].
enum HuiAxis { horizontal, vertical }

/// Draw-order operations. See [zOrderOffsets] for the sign convention.
enum HuiZOrder { forward, backward, toFront, toBack }

/// Orientation of a drawn guide line: [vertical] is a line of constant world
/// x, [horizontal] a line of constant world y.
enum GuideAxis { vertical, horizontal }

/// Whether a guide came from two edges meeting or two centres meeting. An
/// edge-to-centre coincidence counts as an edge match, because the centre is
/// only interesting when it lines up with another centre.
enum GuideMatch { edge, center }

/// One drawn guide line: where it sits, how far it should be drawn, and which
/// components put it there.
class AlignmentGuide {
  const AlignmentGuide({
    required this.axis,
    required this.match,
    required this.position,
    required this.start,
    required this.end,
    required this.ids,
  });

  final GuideAxis axis;
  final GuideMatch match;

  /// World x for [GuideAxis.vertical], world y for [GuideAxis.horizontal].
  final double position;

  /// Extent along the other axis, covering the snapped selection and every
  /// component in [ids].
  final double start;
  final double end;

  /// Components sitting on this line, in the order they were supplied.
  final List<String> ids;

  @override
  String toString() =>
      'AlignmentGuide(${axis.name}, ${match.name}, $position, $ids)';
}

/// The correction a drag should apply, plus the lines to draw for it.
class GuideSnap {
  const GuideSnap({
    this.dx = 0,
    this.dy = 0,
    this.guides = const <AlignmentGuide>[],
  });

  static const GuideSnap none = GuideSnap();

  final double dx;
  final double dy;
  final List<AlignmentGuide> guides;

  /// True when nothing matched. A zero [dx] with a guide present is a real
  /// result — it means the drag is already exactly aligned and the line should
  /// be shown.
  bool get isEmpty => guides.isEmpty;

  bool get snappedX =>
      guides.any((AlignmentGuide g) => g.axis == GuideAxis.vertical);

  bool get snappedY =>
      guides.any((AlignmentGuide g) => g.axis == GuideAxis.horizontal);
}

/// One frame of a group drag: where every member lands, and the lines to draw.
class GroupDrag {
  const GroupDrag({required this.offsets, required this.guides});

  static const GroupDrag none = GroupDrag(
    offsets: <String, Vec3>{},
    guides: <AlignmentGuide>[],
  );

  /// Ready for `EditorStore.setOffsets` — already snapped, already corrected,
  /// so the store must not snap them again.
  final Map<String, Vec3> offsets;

  final List<AlignmentGuide> guides;
}

/// Rubber band between two world-space corners.
///
/// Normalised, so the band is the same rect whichever way it was dragged, and
/// a perfectly straight drag legitimately has a zero extent — [idsInMarquee] is
/// inclusive for exactly that reason.
HuiRect marqueeRect(double x0, double y0, double x1, double y1) =>
    HuiRect.fromEdges(
      left: math.min(x0, x1),
      bottom: math.min(y0, y1),
      right: math.max(x0, x1),
      top: math.max(y0, y1),
    );

/// Union of the drawn outlines of [ids], or null when none of them resolve.
WorldBounds? outlineBounds(CanvasScene scene, Iterable<String> ids) {
  WorldBounds? bounds;
  for (final String id in ids) {
    final CanvasItem? item = scene.byId(id);
    if (item == null) continue;
    final WorldBounds rect = item.outline.bounds;
    bounds = bounds == null ? rect : bounds.union(rect);
  }
  return bounds;
}

/// Every offset moved by the same delta, rounded the way `EditorStore._round`
/// rounds.
///
/// An axis with a zero delta is copied through untouched rather than rounded:
/// an authored `z` of 0.135791 has to survive an xy drag exactly, which is the
/// same rule `moveComponent` follows.
Map<String, Vec3> shiftOffsets({
  required Map<String, Vec3> offsets,
  double dx = 0,
  double dy = 0,
  double dz = 0,
}) =>
    <String, Vec3>{
      for (final MapEntry<String, Vec3> entry in offsets.entries)
        entry.key: Vec3(
          dx == 0 ? entry.value.x : _round4(entry.value.x + dx),
          dy == 0 ? entry.value.y : _round4(entry.value.y + dy),
          dz == 0 ? entry.value.z : _round4(entry.value.z + dz),
        ),
    };

/// Resolves one pointer-move of a group drag.
///
/// [grabbedTarget] is the offset the store already snapped for the component
/// under the pointer; its delta from [startOffsets] is what the rest of the
/// group follows, so the selection can never tear apart on the grid.
///
/// Guides are solved AFTER that snap and their correction is added on top,
/// which is the whole reason "a guide beats the block grid inside the
/// threshold" needs no special case. Members of [startOffsets] are excluded
/// from the guide pool — a selection that snapped to itself would be pinned in
/// place.
GroupDrag resolveGroupDrag({
  required CanvasScene scene,
  required Map<String, Vec3> startOffsets,
  required WorldBounds startBounds,
  required String grabbedId,
  required Vec3 grabbedTarget,
  required double guideThresholdBlocks,
}) {
  final Vec3? start = startOffsets[grabbedId];
  if (start == null || !_invertible(scene)) return GroupDrag.none;

  final double scale = scene.uiScale;
  double worldDx = (grabbedTarget.x - start.x) * scale;
  double worldDy = (grabbedTarget.y - start.y) * scale;

  final GuideSnap snap = smartGuides(
    moving: WorldBounds(
      minX: startBounds.minX + worldDx,
      minY: startBounds.minY + worldDy,
      maxX: startBounds.maxX + worldDx,
      maxY: startBounds.maxY + worldDy,
    ),
    others: <CanvasItem>[
      for (final CanvasItem item in scene.items)
        if (!startOffsets.containsKey(item.id)) item,
    ],
    thresholdBlocks: guideThresholdBlocks,
  );
  worldDx += snap.dx;
  worldDy += snap.dy;

  return GroupDrag(
    offsets: shiftOffsets(
      offsets: startOffsets,
      dx: worldDx / scale,
      dy: worldDy / scale,
    ),
    guides: snap.guides,
  );
}

/// Ids whose drawn outline the rubber band touches.
///
/// Inclusive, unlike [HuiRect.overlaps]: a band dragged perfectly horizontally
/// has zero height, and a strict test would select nothing at all.
Set<String> idsInMarquee(CanvasScene scene, HuiRect marquee) {
  final Set<String> ids = <String>{};
  for (final CanvasItem item in scene.items) {
    if (_touches(marquee, item.outline)) ids.add(item.id);
  }
  return ids;
}

/// Offsets that flush every selected outline against the selection's own
/// bounding box. Fewer than two resolved components is a no-op, and `z` is
/// never touched — depth is the draw order, not a layout axis.
///
/// Every resolved id is returned, including the ones already in place;
/// `EditorStore.mutate` drops the undo step when nothing actually moved.
Map<String, Vec3> alignOffsets({
  required CanvasScene scene,
  required List<String> ids,
  required HuiAlign align,
}) {
  final List<CanvasItem> picked = _resolve(scene, ids);
  if (picked.length < 2 || !_invertible(scene)) return const <String, Vec3>{};

  double minLeft = double.infinity;
  double maxRight = double.negativeInfinity;
  double minBottom = double.infinity;
  double maxTop = double.negativeInfinity;
  for (final CanvasItem item in picked) {
    final HuiRect rect = item.outline;
    minLeft = math.min(minLeft, rect.left);
    maxRight = math.max(maxRight, rect.right);
    minBottom = math.min(minBottom, rect.bottom);
    maxTop = math.max(maxTop, rect.top);
  }

  final Map<String, Vec3> out = <String, Vec3>{};
  for (final CanvasItem item in picked) {
    final HuiRect rect = item.outline;
    final double delta = switch (align) {
      HuiAlign.left => minLeft - rect.left,
      HuiAlign.centerX => (minLeft + maxRight) / 2 - rect.x,
      HuiAlign.right => maxRight - rect.right,
      HuiAlign.top => maxTop - rect.top,
      HuiAlign.middleY => (minBottom + maxTop) / 2 - rect.y,
      HuiAlign.bottom => minBottom - rect.bottom,
    };
    out[item.id] = _shift(scene, item, delta, _isHorizontal(align));
  }
  return out;
}

/// Offsets that leave equal gaps between the selected outlines along [axis].
///
/// The outermost two edges stay put and everything between them is respaced;
/// fewer than three resolved components has nothing to space, so it is a no-op.
/// `z` is never touched.
Map<String, Vec3> distributeOffsets({
  required CanvasScene scene,
  required List<String> ids,
  required HuiAxis axis,
}) {
  final List<CanvasItem> picked = _resolve(scene, ids);
  if (picked.length < 3 || !_invertible(scene)) return const <String, Vec3>{};

  final bool horizontal = axis == HuiAxis.horizontal;
  double lowOf(CanvasItem i) =>
      horizontal ? i.outline.left : i.outline.bottom;
  double highOf(CanvasItem i) =>
      horizontal ? i.outline.right : i.outline.top;
  double sizeOf(CanvasItem i) => horizontal ? i.outline.w : i.outline.h;

  // Declaration index breaks ties so two coincident components keep a stable
  // order instead of swapping on every invocation.
  final List<CanvasItem> ordered = List<CanvasItem>.of(picked)
    ..sort((CanvasItem a, CanvasItem b) {
      final int byPosition = lowOf(a).compareTo(lowOf(b));
      return byPosition != 0 ? byPosition : a.index.compareTo(b.index);
    });

  double spanLow = double.infinity;
  double spanHigh = double.negativeInfinity;
  double content = 0;
  for (final CanvasItem item in ordered) {
    spanLow = math.min(spanLow, lowOf(item));
    spanHigh = math.max(spanHigh, highOf(item));
    content += sizeOf(item);
  }
  final double gap = (spanHigh - spanLow - content) / (ordered.length - 1);

  final Map<String, Vec3> out = <String, Vec3>{};
  double cursor = spanLow;
  for (final CanvasItem item in ordered) {
    out[item.id] = _shift(scene, item, cursor - lowOf(item), horizontal);
    cursor += sizeOf(item) + gap;
  }
  return out;
}

/// Edge and centre alignments between a dragged selection and its neighbours.
///
/// The axes are solved independently: a drag can snap horizontally against one
/// component and vertically against another. On each axis the nearest candidate
/// within [thresholdBlocks] wins, and every neighbour that lands on that same
/// winning line contributes to the guides.
GuideSnap smartGuides({
  required WorldBounds moving,
  required Iterable<CanvasItem> others,
  required double thresholdBlocks,
}) {
  if (!thresholdBlocks.isFinite || thresholdBlocks <= 0) return GuideSnap.none;
  final List<CanvasItem> pool = others.toList(growable: false);
  if (pool.isEmpty) return GuideSnap.none;

  final _AxisSnap x = _solveAxis(
    lines: <double>[moving.minX, moving.centerX, moving.maxX],
    pool: pool,
    axis: GuideAxis.vertical,
    threshold: thresholdBlocks,
  );
  final _AxisSnap y = _solveAxis(
    lines: <double>[moving.minY, moving.centerY, moving.maxY],
    pool: pool,
    axis: GuideAxis.horizontal,
    threshold: thresholdBlocks,
  );
  if (x.matches.isEmpty && y.matches.isEmpty) return GuideSnap.none;

  // Guides are drawn against where the selection ends up, not where it was.
  final WorldBounds moved = WorldBounds(
    minX: moving.minX + x.delta,
    minY: moving.minY + y.delta,
    maxX: moving.maxX + x.delta,
    maxY: moving.maxY + y.delta,
  );
  return GuideSnap(
    dx: x.delta,
    dy: y.delta,
    guides: <AlignmentGuide>[
      ..._buildGuides(x.matches, GuideAxis.vertical, moved),
      ..._buildGuides(y.matches, GuideAxis.horizontal, moved),
    ],
  );
}

/// Offsets that restack the selection.
///
/// The sign is the opposite of what the names suggest: [CanvasScene.drawOrder]
/// paints larger `z` FIRST (`canvas_scene.dart:323-327`), so the smallest `z`
/// ends up on top and is what a click resolves to. Bringing something forward
/// therefore SUBTRACTS [step].
///
/// [HuiZOrder.toFront] moves the whole selection past the nearest unselected
/// component by shifting it as a rigid group — relative order and gaps inside
/// the selection survive, which collapsing every member onto one `z` would not.
/// With nothing unselected there is nothing to move past, so it is a no-op.
Map<String, Vec3> zOrderOffsets({
  required List<CanvasItem> items,
  required Set<String> ids,
  required HuiZOrder op,
  required double step,
}) {
  if (ids.isEmpty || !step.isFinite) return const <String, Vec3>{};

  final List<CanvasItem> selected = <CanvasItem>[];
  double minSelected = double.infinity;
  double maxSelected = double.negativeInfinity;
  double minRest = double.infinity;
  double maxRest = double.negativeInfinity;
  for (final CanvasItem item in items) {
    // Authored offset z, not the scene depth: the two order identically for a
    // positive uiScale, and the offset is what gets written back.
    final double z = item.component.offset.z;
    if (ids.contains(item.id)) {
      selected.add(item);
      minSelected = math.min(minSelected, z);
      maxSelected = math.max(maxSelected, z);
    } else {
      minRest = math.min(minRest, z);
      maxRest = math.max(maxRest, z);
    }
  }
  if (selected.isEmpty) return const <String, Vec3>{};
  final bool hasRest = minRest.isFinite;

  final double delta;
  switch (op) {
    case HuiZOrder.forward:
      delta = -step;
    case HuiZOrder.backward:
      delta = step;
    case HuiZOrder.toFront:
      if (!hasRest) return const <String, Vec3>{};
      delta = (minRest - step) - maxSelected;
    case HuiZOrder.toBack:
      if (!hasRest) return const <String, Vec3>{};
      delta = (maxRest + step) - minSelected;
  }

  final Map<String, Vec3> out = <String, Vec3>{};
  for (final CanvasItem item in selected) {
    final Vec3 offset = item.component.offset;
    out[item.id] = Vec3(offset.x, offset.y, _round4(offset.z + delta));
  }
  return out;
}

// --- internals --------------------------------------------------------------

/// Slack for every "these edges coincide" comparison in this file. A billionth
/// of a block is far below anything the canvas can express, and without it an
/// edge that is exactly flush fails the test: [HuiRect.fromEdges] recovers its
/// edges through a centre and a width, so a rect built from 0.3 does not hold
/// the same double as one whose right edge computes to 0.3.
const double _epsilon = 1e-9;

bool _touches(HuiRect a, HuiRect b) =>
    a.left <= b.right + _epsilon &&
    a.right >= b.left - _epsilon &&
    a.bottom <= b.top + _epsilon &&
    a.top >= b.bottom - _epsilon;

bool _isHorizontal(HuiAlign align) => switch (align) {
      HuiAlign.left || HuiAlign.centerX || HuiAlign.right => true,
      HuiAlign.top || HuiAlign.middleY || HuiAlign.bottom => false,
    };

/// A uiScale of zero or worse cannot be inverted, so every operation that has
/// to write an offset back declines rather than emitting infinities.
bool _invertible(CanvasScene scene) =>
    scene.uiScale.isFinite && scene.uiScale > 0;

/// Scene items for [ids], deduplicated, in the order the ids were given.
/// Unknown ids are dropped.
List<CanvasItem> _resolve(CanvasScene scene, List<String> ids) {
  final Set<String> seen = <String>{};
  final List<CanvasItem> picked = <CanvasItem>[];
  for (final String id in ids) {
    if (!seen.add(id)) continue;
    final CanvasItem? item = scene.byId(id);
    if (item != null) picked.add(item);
  }
  return picked;
}

/// Moves [item] by [delta] world blocks along one axis and inverts the result
/// back into an offset. The delta is measured on the drawn rect but applied to
/// the anchor, which is what keeps true-render biases from being aligned away.
Vec3 _shift(
  CanvasScene scene,
  CanvasItem item,
  double delta,
  bool horizontal,
) {
  final Vec3 offset = item.component.offset;
  if (horizontal) {
    final double world = item.anchor.x + delta;
    return Vec3(
      _round4((world - scene.menuOffset.x) / scene.uiScale),
      offset.y,
      offset.z,
    );
  }
  final double world = item.anchor.y + delta;
  return Vec3(
    offset.x,
    _round4((world - scene.menuOffset.y) / scene.uiScale),
    offset.z,
  );
}

/// `EditorStore._round` — four decimals, so exported JSON and snapshot
/// comparisons stay stable.
double _round4(double value) =>
    !value.isFinite ? 0 : (value * 10000).roundToDouble() / 10000;

class _GuideMatchHit {
  const _GuideMatchHit(this.position, this.match, this.item);

  final double position;
  final GuideMatch match;
  final CanvasItem item;
}

class _AxisSnap {
  const _AxisSnap(this.delta, this.matches);

  static const _AxisSnap none = _AxisSnap(0, <_GuideMatchHit>[]);

  final double delta;
  final List<_GuideMatchHit> matches;
}

/// Nearest-wins search over the three moving lines against the three lines of
/// every neighbour. Exact ties keep the first candidate found, so the result is
/// stable across frames of a drag.
_AxisSnap _solveAxis({
  required List<double> lines,
  required List<CanvasItem> pool,
  required GuideAxis axis,
  required double threshold,
}) {
  double? best;
  for (final CanvasItem item in pool) {
    final List<double> theirs = _linesOf(item.outline, axis);
    for (int m = 0; m < 3; m++) {
      for (int o = 0; o < 3; o++) {
        final double delta = theirs[o] - lines[m];
        if (delta.abs() > threshold + _epsilon) continue;
        if (best == null || delta.abs() < best.abs()) best = delta;
      }
    }
  }
  if (best == null) return _AxisSnap.none;

  final List<_GuideMatchHit> matches = <_GuideMatchHit>[];
  for (final CanvasItem item in pool) {
    final List<double> theirs = _linesOf(item.outline, axis);
    for (int m = 0; m < 3; m++) {
      for (int o = 0; o < 3; o++) {
        if ((theirs[o] - lines[m] - best).abs() > _epsilon) continue;
        matches.add(
          _GuideMatchHit(
            theirs[o],
            m == 1 && o == 1 ? GuideMatch.center : GuideMatch.edge,
            item,
          ),
        );
      }
    }
  }
  return _AxisSnap(best, matches);
}

/// Low edge, centre, high edge of [rect] along the axis a guide of [axis]
/// would be drawn against.
List<double> _linesOf(HuiRect rect, GuideAxis axis) =>
    axis == GuideAxis.vertical
        ? <double>[rect.left, rect.x, rect.right]
        : <double>[rect.bottom, rect.y, rect.top];

/// Collapses the raw hits into one guide per (position, match), each spanning
/// the snapped selection and every neighbour on that line.
List<AlignmentGuide> _buildGuides(
  List<_GuideMatchHit> hits,
  GuideAxis axis,
  WorldBounds moved,
) {
  final bool vertical = axis == GuideAxis.vertical;
  final double movedLow = vertical ? moved.minY : moved.minX;
  final double movedHigh = vertical ? moved.maxY : moved.maxX;

  final List<double> positions = <double>[];
  final List<GuideMatch> kinds = <GuideMatch>[];
  final List<List<String>> ids = <List<String>>[];
  final List<double> lows = <double>[];
  final List<double> highs = <double>[];

  for (final _GuideMatchHit hit in hits) {
    int slot = -1;
    for (int i = 0; i < positions.length; i++) {
      if (kinds[i] == hit.match &&
          (positions[i] - hit.position).abs() <= _epsilon) {
        slot = i;
        break;
      }
    }
    if (slot < 0) {
      positions.add(hit.position);
      kinds.add(hit.match);
      ids.add(<String>[]);
      lows.add(movedLow);
      highs.add(movedHigh);
      slot = positions.length - 1;
    }
    if (!ids[slot].contains(hit.item.id)) ids[slot].add(hit.item.id);
    final HuiRect rect = hit.item.outline;
    lows[slot] = math.min(lows[slot], vertical ? rect.bottom : rect.left);
    highs[slot] = math.max(highs[slot], vertical ? rect.top : rect.right);
  }

  return <AlignmentGuide>[
    for (int i = 0; i < positions.length; i++)
      AlignmentGuide(
        axis: axis,
        match: kinds[i],
        position: positions[i],
        start: lows[i],
        end: highs[i],
        ids: List<String>.unmodifiable(ids[i]),
      ),
  ];
}

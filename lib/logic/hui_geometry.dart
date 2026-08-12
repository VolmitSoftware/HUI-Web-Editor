/// HoloUI icon geometry: hitboxes, visual extents and text-stack layout.
///
/// Everything here is block space with `y` up, expressed relative to the menu
/// centre unless a menu offset is supplied. Values are ports of the plugin's
/// own constants; see report-holoui sections 2.2, 2.3 and 2.5.
///
/// Drawn text keeps the display-entity migration's below-anchor bias. Its click
/// plane follows that rendered centre so looking at the glyphs activates it.
library;

import 'dart:math' as math;

import '../model/hui_component.dart'
    show
        HuiButtonData,
        HuiComponent,
        HuiComponentData,
        HuiHitbox,
        HuiHitboxAnchor;
import '../model/vec3.dart' show Vec3;
import 'viewport_math.dart' show WorldBounds, WorldPoint;

/// `MenuIcon.NAMETAG_SIZE = 1/16F * 3.5F` - blocks per text line at uiScale 1.
const double huiLineHeight = 0.21875;

/// Width of one image pixel / full-block glyph: 8 px + 1 px spacing at
/// `VANILLA_TEXT_BLOCKS_PER_PIXEL = 1/40`.
const double huiCharCell = 0.225;

/// Item hitbox and visual square edge at uiScale 1.
const double huiItemSize = 0.75;

/// Approximate advance of a regular Minecraft glyph (5 px + 1 px spacing at
/// 1/40 blocks per pixel). Used for visual bounds only - the canvas measures
/// real text when it needs exact widths; the plugin's hitbox math ignores this.
const double huiTextCharWidth = 0.15;

/// The item collision plane is centred this far below the anchor (x uiScale).
const double huiItemHitboxDrop = 0.05;

/// Drawn text lands this far below the anchor (x uiScale):
/// `2 * huiLineHeight - 4.5 px / 40` = 0.4375 - 0.1125.
const double huiTextTrueRenderBias = 0.325;

/// `ItemMenuIcon.ITEM_OFFSET`.
const double huiItemDisplayOffset = 1.0;

/// `-ItemMenuIcon.BLOCK_OFFSET` - block-like items hang less far down, and
/// unlike loose items they are teleported to exactly this drop on spawn, so no
/// nametag term is added.
const double huiBlockDisplayOffset = 0.95;

/// Extra drop applied when the stack amount is exactly 1.
const double huiSingleItemCountOffset = 0.09;

/// Block-like items are additionally pushed this far along +z from the anchor.
const double huiBlockDepthOffset = 0.3;

/// The `count > 1` label sits `huiLineHeight + this` below the anchor.
const double huiItemCountLabelOffset = 0.37;

/// `TextImageMenuIcon.MISSING` is an 8x8 black/magenta checker.
const int huiMissingIconSize = 8;

enum IconShapeKind { text, image, item, block, entity }

/// The measured shape of an icon, computed by the caller from the parsed text,
/// the decoded image or the item stack. Geometry never parses anything itself.
class IconShape {
  final IconShapeKind kind;

  /// Text lines, or image rows. Always 1 for items.
  final int lines;

  /// Longest line in characters, or image columns. Always 0 for items.
  final int maxLineChars;

  final bool isItem;

  /// Block-like items use a shallower true-render drop and a +z push.
  final bool isBlockItem;

  /// Stack amount; only `== 1` versus `> 1` matters to the geometry.
  final int itemCount;
  final double entityWidth;
  final double entityHeight;

  const IconShape._({
    required this.kind,
    required this.lines,
    required this.maxLineChars,
    required this.isItem,
    required this.isBlockItem,
    required this.itemCount,
    required this.entityWidth,
    required this.entityHeight,
  });

  const IconShape.text({required int lines, required int maxLineChars})
    : this._(
        kind: IconShapeKind.text,
        lines: lines,
        maxLineChars: maxLineChars,
        isItem: false,
        isBlockItem: false,
        itemCount: 1,
        entityWidth: 0,
        entityHeight: 0,
      );

  /// `textImage` / `animatedTextImage`: one row per image pixel row.
  const IconShape.image({required int rows, required int columns})
    : this._(
        kind: IconShapeKind.image,
        lines: rows,
        maxLineChars: columns,
        isItem: false,
        isBlockItem: false,
        itemCount: 1,
        entityWidth: 0,
        entityHeight: 0,
      );

  const IconShape.item({int count = 1, bool isBlockItem = false})
    : this._(
        kind: IconShapeKind.item,
        lines: 1,
        maxLineChars: 0,
        isItem: true,
        isBlockItem: isBlockItem,
        itemCount: count,
        entityWidth: 0,
        entityHeight: 0,
      );

  const IconShape.entity({required double width, required double height})
    : this._(
        kind: IconShapeKind.entity,
        lines: 1,
        maxLineChars: 0,
        isItem: false,
        isBlockItem: false,
        itemCount: 1,
        entityWidth: width,
        entityHeight: height,
      );

  const IconShape.block()
    : this._(
        kind: IconShapeKind.block,
        lines: 1,
        maxLineChars: 0,
        isItem: false,
        isBlockItem: true,
        itemCount: 1,
        entityWidth: 0,
        entityHeight: 0,
      );

  /// Shape of the missing-icon placeholder drawn for a null or broken icon.
  const IconShape.missing()
    : this._(
        kind: IconShapeKind.image,
        lines: huiMissingIconSize,
        maxLineChars: huiMissingIconSize,
        isItem: false,
        isBlockItem: false,
        itemCount: 1,
        entityWidth: 0,
        entityHeight: 0,
      );

  int get rows => lines;

  int get columns => maxLineChars;

  bool get isEntity => kind == IconShapeKind.entity;

  bool get isBlock => kind == IconShapeKind.block;

  @override
  bool operator ==(Object other) =>
      other is IconShape &&
      other.kind == kind &&
      other.lines == lines &&
      other.maxLineChars == maxLineChars &&
      other.isBlockItem == isBlockItem &&
      other.itemCount == itemCount &&
      other.entityWidth == entityWidth &&
      other.entityHeight == entityHeight;

  @override
  int get hashCode => Object.hash(
    kind,
    lines,
    maxLineChars,
    isBlockItem,
    itemCount,
    entityWidth,
    entityHeight,
  );

  @override
  String toString() =>
      'IconShape(${kind.name}, lines: $lines, chars: $maxLineChars)';
}

/// A block-space rectangle. [x] and [y] are the CENTRE, `y` grows up.
class HuiRect {
  final double x;
  final double y;
  final double w;
  final double h;

  const HuiRect({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  const HuiRect.fromEdges({
    required double left,
    required double bottom,
    required double right,
    required double top,
  }) : x = (left + right) / 2,
       y = (bottom + top) / 2,
       w = right - left,
       h = top - bottom;

  static const HuiRect zero = HuiRect(x: 0, y: 0, w: 0, h: 0);

  double get halfWidth => w / 2;

  double get halfHeight => h / 2;

  double get left => x - w / 2;

  double get right => x + w / 2;

  /// Lower edge (smaller y).
  double get bottom => y - h / 2;

  /// Upper edge (larger y).
  double get top => y + h / 2;

  bool contains(double pointX, double pointY) =>
      pointX >= left && pointX <= right && pointY >= bottom && pointY <= top;

  /// Strict overlap: rectangles that merely touch do not count.
  bool overlaps(HuiRect other) =>
      left < other.right &&
      right > other.left &&
      bottom < other.top &&
      top > other.bottom;

  HuiRect translate(double dx, double dy) =>
      HuiRect(x: x + dx, y: y + dy, w: w, h: h);

  HuiRect inflate(double blocks) => HuiRect(
    x: x,
    y: y,
    w: math.max(0, w + blocks * 2),
    h: math.max(0, h + blocks * 2),
  );

  HuiRect union(HuiRect other) => HuiRect.fromEdges(
    left: math.min(left, other.left),
    bottom: math.min(bottom, other.bottom),
    right: math.max(right, other.right),
    top: math.max(top, other.top),
  );

  /// Viewport-ready bounds for fit-to-content.
  WorldBounds get bounds =>
      WorldBounds(minX: left, minY: bottom, maxX: right, maxY: top);

  @override
  bool operator ==(Object other) =>
      other is HuiRect &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h;

  @override
  int get hashCode => Object.hash(x, y, w, h);

  @override
  String toString() => 'HuiRect(x: $x, y: $y, w: $w, h: $h)';
}

/// `CollisionPlane` for an icon anchored at ([anchorX], [anchorY]).
/// Text-backed planes follow the visible glyph centre. Items retain their
/// item-specific drop. [override] replaces dimensions without changing that
/// icon-derived centre.
HuiRect hitboxAt({
  required double anchorX,
  required double anchorY,
  required double uiScale,
  required IconShape shape,
  HuiHitbox? override,
  bool trueRender = true,
  double scaleX = 1,
  double scaleY = 1,
}) {
  final double scale = _safeScale(uiScale);
  final double iconScaleX = _safeScale(scaleX);
  final double iconScaleY = _safeScale(scaleY);
  final bool customSize = override?.hasCustomSize ?? false;
  if (shape.isItem) {
    final double width = !customSize
        ? huiItemSize * scale * iconScaleX
        : _safeDimension(override!.width!) * scale;
    final double height = !customSize
        ? huiItemSize * scale * iconScaleY
        : _safeDimension(override!.height!) * scale;
    return HuiRect(
      x: anchorX,
      y: anchorY - huiItemHitboxDrop * scale,
      w: width,
      h: height,
    );
  }
  if (shape.isBlock) {
    final double width = !customSize
        ? huiItemSize * scale * iconScaleX
        : _safeDimension(override!.width!) * scale;
    final double height = !customSize
        ? huiItemSize * scale * iconScaleY
        : _safeDimension(override!.height!) * scale;
    return HuiRect(
      x: anchorX,
      y: anchorY - huiItemHitboxDrop * scale,
      w: width,
      h: height,
    );
  }
  if (shape.isEntity) {
    final double width = !customSize
        ? _safeDimension(shape.entityWidth) * scale
        : _safeDimension(override!.width!) * scale;
    final double height = !customSize
        ? _safeDimension(shape.entityHeight) * scale
        : _safeDimension(override!.height!) * scale;
    return HuiRect(
      x: anchorX,
      y: anchorY + _safeDimension(shape.entityHeight) * scale / 2,
      w: width,
      h: height,
    );
  }
  final double lineHeight = huiLineHeight * scale * iconScaleY;
  final double characterWidth = huiLineHeight * scale * iconScaleX;
  final int lines = math.max(0, shape.lines);
  final int chars = math.max(0, shape.maxLineChars);
  final double width = !customSize
      ? chars * characterWidth / 2
      : _safeDimension(override!.width!) * scale;
  final double height = !customSize
      ? shape.kind == IconShapeKind.image
            ? math.max(0, lines - 1) * lineHeight
            : lines * lineHeight
      : _safeDimension(override!.height!) * scale;
  return HuiRect(
    x: anchorX,
    y: anchorY - (trueRender ? huiTextTrueRenderBias * scale * iconScaleY : 0),
    w: width,
    h: height,
  );
}

/// Drawn extent of an icon anchored at ([anchorX], [anchorY]).
/// With `trueRender: false` (the authoring default, and what the old editor
/// did) the icon is centred on the anchor; with `trueRender: true` it carries
/// the in-game vertical bias.
HuiRect visualBoundsAt({
  required double anchorX,
  required double anchorY,
  required double uiScale,
  required IconShape shape,
  bool trueRender = false,
  double scaleX = 1,
  double scaleY = 1,
}) {
  final double scale = _safeScale(uiScale);
  final double iconScaleX = _safeScale(scaleX);
  final double iconScaleY = _safeScale(scaleY);
  if (shape.isItem) {
    final double width = huiItemSize * scale * iconScaleX;
    final double height = huiItemSize * scale * iconScaleY;
    final double drop = trueRender
        ? itemTrueRenderBias(
                count: shape.itemCount,
                isBlockItem: shape.isBlockItem,
                scaleY: iconScaleY,
              ) *
              scale
        : 0;
    return HuiRect(x: anchorX, y: anchorY - drop, w: width, h: height);
  }
  if (shape.isBlock) {
    return HuiRect(
      x: anchorX,
      y: anchorY - (trueRender ? huiItemHitboxDrop * scale : 0),
      w: huiItemSize * scale * iconScaleX,
      h: huiItemSize * scale * iconScaleY,
    );
  }
  if (shape.isEntity) {
    final double width = _safeDimension(shape.entityWidth) * scale;
    final double height = _safeDimension(shape.entityHeight) * scale;
    return HuiRect(x: anchorX, y: anchorY + height / 2, w: width, h: height);
  }
  final int lines = math.max(0, shape.lines);
  final int chars = math.max(0, shape.maxLineChars);
  final double cellWidth = shape.kind == IconShapeKind.image
      ? huiCharCell
      : huiTextCharWidth;
  final double drop = trueRender
      ? huiTextTrueRenderBias * scale * iconScaleY
      : 0;
  return HuiRect(
    x: anchorX,
    y: anchorY - drop,
    w: chars * cellWidth * scale * iconScaleX,
    h: lines * huiLineHeight * scale * iconScaleY,
  );
}

/// Anchor of [component] in block space.
///
/// `uiScale` multiplies the component offset but never the menu offset, so the
/// standoff distance stays fixed while the layout spreads (report-holoui 2.1).
/// Pass [menuOffset] to get player-relative coordinates (y = 0 at the feet);
/// omit it for menu-local coordinates.
WorldPoint anchorFor({
  required HuiComponent component,
  required double uiScale,
  Vec3? menuOffset,
}) {
  final double scale = _safeScale(uiScale);
  return WorldPoint(
    (menuOffset?.x ?? 0) + component.offset.x * scale,
    (menuOffset?.y ?? 0) + component.offset.y * scale,
  );
}

/// Depth of [component]; the canvas draws larger z first and uses it for
/// click-order ties.
double depthFor({
  required HuiComponent component,
  required double uiScale,
  Vec3? menuOffset,
}) => (menuOffset?.z ?? 0) + component.offset.z * _safeScale(uiScale);

/// [hitboxAt] for a component, using its offset as the anchor.
HuiRect hitboxFor({
  required HuiComponent component,
  required double uiScale,
  required IconShape shape,
  Vec3? menuOffset,
  bool trueRender = true,
  double scaleX = 1,
  double scaleY = 1,
}) {
  final WorldPoint anchor = anchorFor(
    component: component,
    uiScale: uiScale,
    menuOffset: menuOffset,
  );
  final HuiHitbox? hitbox = switch (component.data) {
    HuiButtonData(:final HuiHitbox? hitbox) => hitbox,
    _ => null,
  };
  final HuiRect automatic = hitboxAt(
    anchorX: anchor.x,
    anchorY: anchor.y,
    uiScale: uiScale,
    shape: shape,
    override: hitbox,
    trueRender: trueRender,
    scaleX: scaleX,
    scaleY: scaleY,
  );
  if (hitbox == null) return automatic;
  final double scale = _safeScale(uiScale);
  if (hitbox.anchor == HuiHitboxAnchor.menu) {
    final HuiRect runtimeAutomatic = trueRender
        ? automatic
        : hitboxAt(
            anchorX: anchor.x,
            anchorY: anchor.y,
            uiScale: uiScale,
            shape: shape,
            override: hitbox,
            trueRender: true,
            scaleX: scaleX,
            scaleY: scaleY,
          );
    return HuiRect(
      x: (menuOffset?.x ?? 0) + hitbox.offset.x * scale,
      y:
          (menuOffset?.y ?? 0) +
          hitbox.offset.y * scale +
          automatic.y -
          runtimeAutomatic.y,
      w: automatic.w,
      h: automatic.h,
    );
  }
  return HuiRect(
    x: automatic.x + hitbox.offset.x * scale,
    y: automatic.y + hitbox.offset.y * scale,
    w: automatic.w,
    h: automatic.h,
  );
}

double hitboxDepthFor({
  required HuiComponent component,
  required double uiScale,
  Vec3? menuOffset,
}) {
  final double scale = _safeScale(uiScale);
  final HuiComponentData data = component.data;
  if (data is! HuiButtonData || data.hitbox == null) {
    return depthFor(
      component: component,
      uiScale: uiScale,
      menuOffset: menuOffset,
    );
  }
  final HuiHitbox hitbox = data.hitbox!;
  if (hitbox.anchor == HuiHitboxAnchor.menu) {
    return (menuOffset?.z ?? 0) + hitbox.offset.z * scale;
  }
  return depthFor(
        component: component,
        uiScale: uiScale,
        menuOffset: menuOffset,
      ) +
      hitbox.offset.z * scale;
}

/// [visualBoundsAt] for a component, using its offset as the anchor.
HuiRect visualBoundsFor({
  required HuiComponent component,
  required double uiScale,
  required IconShape shape,
  bool trueRender = false,
  Vec3? menuOffset,
  double scaleX = 1,
  double scaleY = 1,
}) {
  final WorldPoint anchor = anchorFor(
    component: component,
    uiScale: uiScale,
    menuOffset: menuOffset,
  );
  return visualBoundsAt(
    anchorX: anchor.x,
    anchorY: anchor.y,
    uiScale: uiScale,
    shape: shape,
    trueRender: trueRender,
    scaleX: scaleX,
    scaleY: scaleY,
  );
}

/// Distance below the anchor at which an item display actually renders, per
/// unit uiScale.
///
/// Non-block items keep the spawn-time drop `-scaledTagSize -
/// (ITEM_OFFSET + countOffset)`. Block-like items do NOT: `ItemMenuIcon.spawn`
/// calls `rotate` immediately and `rotate` teleports the display to
/// `this.position + BLOCK_OFFSET * scale`, rotated about the anchor (which
/// preserves y), dropping the `scaledTagSize` term the spawn location carried.
double itemTrueRenderBias({
  required int count,
  required bool isBlockItem,
  double scaleY = 1,
}) {
  if (isBlockItem) {
    return huiBlockDisplayOffset;
  }
  return huiLineHeight * _safeScale(scaleY) +
      huiItemDisplayOffset +
      (count == 1 ? huiSingleItemCountOffset : 0);
}

/// Centre y of one line of a text or image stack. Line 0 is the top line.
/// Lines are spaced `huiLineHeight * uiScale` apart and the stack is centred on
/// the anchor unless [trueRender] shifts it down by [huiTextTrueRenderBias].
double textLineCenterY({
  required double anchorY,
  required double uiScale,
  required int lineIndex,
  required int lineCount,
  bool trueRender = false,
  double scaleY = 1,
}) {
  final double scale = _safeScale(uiScale);
  final double iconScaleY = _safeScale(scaleY);
  final double lineHeight = huiLineHeight * scale * iconScaleY;
  final int count = math.max(1, lineCount);
  final double y = anchorY + ((count - 1) / 2 - lineIndex) * lineHeight;
  return trueRender ? y - huiTextTrueRenderBias * scale * iconScaleY : y;
}

/// Centre y of the stack-count label drawn under an item icon when count > 1.
double itemCountLabelY({
  required double anchorY,
  required double uiScale,
  double scaleY = 1,
}) {
  final double scale = _safeScale(uiScale);
  return anchorY -
      (huiLineHeight * _safeScale(scaleY) + huiItemCountLabelOffset) * scale;
}

double _safeScale(double uiScale) =>
    uiScale.isFinite && uiScale > 0 ? uiScale : 0;

double _safeDimension(double dimension) =>
    dimension.isFinite && dimension > 0 ? dimension : 0;

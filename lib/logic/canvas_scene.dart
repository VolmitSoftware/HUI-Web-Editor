/// Resolved, DOM-free description of one canvas frame.
///
/// The painter and the hit tester both consume this, which is the only way the
/// two stay in agreement: what you can click is exactly what was drawn. Nothing
/// here touches the DOM, so the whole layout pass is testable on the VM.
///
/// [CanvasItem.hitbox] is the plugin's `CollisionPlane` and [CanvasItem.visual]
/// is where the icon draws. Text-backed planes share the rendered glyph centre.
///
/// It lives under `logic/` rather than with the canvas because the 3D preview
/// resolves the same frame: one layout pass, two views, no way for them to
/// disagree on a measurement.
library;

import 'dart:math' as math;

import '../model/model.dart';
import '../services/catalogs.dart';
import '../services/image_library.dart';
import 'hui_geometry.dart';
import 'mc_text.dart';
import 'viewport_math.dart';

/// One animation tick is one Minecraft tick.
const Duration huiAnimationTick = Duration(milliseconds: 50);

/// Extra grab room around a hitbox so hairline icons stay clickable.
const double huiPickToleranceBlocks = 0.03;

enum CanvasIconKind { text, image, item, customItem, missing }

/// Everything the painter needs about one component, already measured.
class CanvasItem {
  const CanvasItem({
    required this.component,
    required this.index,
    required this.kind,
    required this.shape,
    required this.anchor,
    required this.depth,
    required this.hitbox,
    required this.visual,
    required this.clickable,
    required this.isToggle,
    required this.toggleShowsTrue,
    this.icon,
    this.text,
    this.imagePath,
    this.pixels,
    this.itemKey = '',
    this.itemCount = 1,
    this.itemTexture,
    this.itemProvider = '',
    this.animationFrame = -1,
    this.animationFrameCount = 0,
  });

  final HuiComponent component;

  /// Position in `menu.components`; the click-dispatch order in game and the
  /// tie-break for equal depth here.
  final int index;

  final CanvasIconKind kind;
  final IconShape shape;
  final WorldPoint anchor;
  final double depth;

  /// The plugin's collision plane, centred on the rendered icon.
  final HuiRect hitbox;

  /// Where the icon draws, honouring the true-render bias when enabled.
  final HuiRect visual;

  /// Buttons and toggles fire on click; decorations never do.
  final bool clickable;

  final bool isToggle;
  final bool toggleShowsTrue;

  /// The icon actually being previewed (a toggle resolves to one of its two).
  final HuiIcon? icon;

  /// Populated for [CanvasIconKind.text].
  final McTextResult? text;

  /// Populated for [CanvasIconKind.image]: the frame currently on screen.
  final String? imagePath;

  /// Null while the decode is still in flight; a repaint follows.
  final ImagePixels? pixels;

  /// The material key for [CanvasIconKind.item], the provider's own id for
  /// [CanvasIconKind.customItem]. Only the former is lowercased.
  final String itemKey;
  final int itemCount;

  /// Data URI from the material catalog, or null when the catalog has no
  /// sprite for this key. A custom item resolves it through its exported base
  /// material, so it is null until the id appears in a catalog export.
  final String? itemTexture;

  /// Provider id of a [CanvasIconKind.customItem], drawn as the placeholder
  /// badge. Empty for every other kind.
  final String itemProvider;

  final int animationFrame;
  final int animationFrameCount;

  String get id => component.id;

  bool get isAnimated => animationFrameCount > 1;

  /// Region a click may land on when nothing was hit on the drawn icon itself.
  /// The union is a fallback for icons whose visual extent exceeds the plane.
  HuiRect get pickRegion =>
      hitbox.w <= 0 || hitbox.h <= 0 ? visual : hitbox.union(visual);

  /// Selection outline box, and the primary pick target.
  HuiRect get outline => visual.w <= 0 || visual.h <= 0 ? hitbox : visual;
}

/// Measured text runs wider than the character-count estimate in
/// [visualBoundsAt] - bold widens every glyph by a font pixel - so a rasterized
/// icon is given room rather than clipping its last glyph.
const double huiSpritePadFractionX = 0.25;
const double huiSpritePadFractionY = 0.12;
const double huiSpritePadBlocks = 0.05;

/// Block-space rectangle a rasterized icon bitmap covers, RELATIVE to the
/// item's anchor.
///
/// One definition, two consumers: `IconSpriteRasterizer` fits its offscreen
/// viewport to this, and the 3D stage both sizes and POSITIONS its quad from
/// it. They used to derive it independently, which is a standing invitation
/// for the bitmap and the quad it is blitted into to drift apart by a nametag.
///
/// Relative to the anchor rather than absolute, because sprites are cached by
/// appearance: two identical decorations share one bitmap, so an absolute
/// rectangle would carry the world position of whichever item rasterized it
/// first and stack the two on top of each other.
///
/// The centre is the drawn box's - `visual` already carries the true-render
/// drop (`MenuIcon.java:129` plus `TextMenuIcon.java:58`, or
/// `ItemMenuIcon.java:83-89`) - with two documented exceptions: an icon that
/// draws nothing falls back to its collision plane, and a stack of more than
/// one grows down to swallow the count label `ItemMenuIcon` spawns under it
/// (`ItemMenuIcon.java:91-94,142-149`). Padding is symmetric and never moves
/// the centre.
HuiRect spriteExtentFor(
  CanvasItem item, {
  required double uiScale,
  required bool trueRender,
}) {
  HuiRect rect = item.visual;
  if (rect.w <= 0 || rect.h <= 0) rect = item.outline;
  if (rect.w <= 0 || rect.h <= 0) return HuiRect.zero;
  if (item.shape.isItem && item.itemCount > 1) {
    rect = rect.union(_countLabelRect(item, uiScale, rect, trueRender));
  }
  final double padX =
      rect.w * huiSpritePadFractionX + huiSpritePadBlocks * uiScale;
  final double padY =
      rect.h * huiSpritePadFractionY + huiSpritePadBlocks * uiScale;
  return HuiRect.fromEdges(
    left: rect.left - padX,
    bottom: rect.bottom - padY,
    right: rect.right + padX,
    top: rect.top + padY,
  ).translate(-item.anchor.x, -item.anchor.y);
}

/// The bold `xN` label under a stack of more than one, as the renderer draws
/// it: on the anchor in true-render mode, tucked under the icon otherwise.
HuiRect _countLabelRect(
  CanvasItem item,
  double uiScale,
  HuiRect icon,
  bool trueRender,
) {
  final double lineHeight = huiLineHeight * uiScale;
  return HuiRect(
    x: item.anchor.x,
    y: trueRender
        ? itemCountLabelY(anchorY: item.anchor.y, uiScale: uiScale)
        : icon.bottom - lineHeight * 0.6,
    // Two digits at the glyph advance, with slack for a three-digit stack.
    w: math.max(icon.w, huiTextCharWidth * uiScale * 4),
    h: lineHeight * 2,
  );
}

/// A pair of clickable components whose planes intersect: in game a single
/// click fires both.
class CanvasOverlap {
  const CanvasOverlap({
    required this.firstId,
    required this.secondId,
    required this.region,
  });

  final String firstId;
  final String secondId;
  final HuiRect region;
}

/// One resolved frame.
class CanvasScene {
  CanvasScene({
    required this.items,
    required this.drawOrder,
    required this.overlaps,
    required this.menuOffset,
    required this.uiScale,
    required this.trueRender,
  });

  /// Declaration order.
  final List<CanvasItem> items;

  /// Farthest first: larger `z` is further from the camera, so it paints below.
  final List<CanvasItem> drawOrder;

  final List<CanvasOverlap> overlaps;
  final Vec3 menuOffset;
  final double uiScale;
  final bool trueRender;

  late final Set<String> overlappingIds = <String>{
    for (final CanvasOverlap overlap in overlaps) ...<String>[
      overlap.firstId,
      overlap.secondId,
    ],
  };

  bool get isEmpty => items.isEmpty;

  CanvasItem? byId(String id) {
    for (final CanvasItem item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Topmost item under a world point: the last one painted wins, which for
  /// equal depth means the last declared.
  ///
  /// Two passes. The drawn icon always wins, because a click on what you can
  /// see must never select something else; only when nothing was drawn under
  /// the cursor does the collision plane come into play.
  CanvasItem? hitTest(
    double worldX,
    double worldY, {
    double tolerance = huiPickToleranceBlocks,
  }) =>
      _topmost(worldX, worldY, tolerance, drawn: true) ??
      _topmost(worldX, worldY, tolerance, drawn: false);

  CanvasItem? _topmost(
    double worldX,
    double worldY,
    double tolerance, {
    required bool drawn,
  }) {
    for (int i = drawOrder.length - 1; i >= 0; i--) {
      final CanvasItem item = drawOrder[i];
      final HuiRect region = drawn ? item.outline : item.pickRegion;
      if (region.inflate(tolerance).contains(worldX, worldY)) {
        return item;
      }
    }
    return null;
  }

  /// Content extent for fit-to-view: every icon, every plane, and the menu
  /// centre marker.
  WorldBounds get contentBounds {
    WorldBounds bounds = WorldBounds(
      minX: menuOffset.x,
      minY: menuOffset.y,
      maxX: menuOffset.x,
      maxY: menuOffset.y,
    );
    for (final CanvasItem item in items) {
      bounds = bounds.union(item.visual.bounds).union(item.hitbox.bounds);
    }
    return bounds;
  }
}

/// Parsed-text memo. Text icons are re-resolved on every repaint, and a
/// 60 fps drag would otherwise re-parse every string 60 times a second.
class McTextCache {
  McTextCache({this.capacity = 256});

  final int capacity;
  final Map<String, McTextResult> _entries = <String, McTextResult>{};

  McTextResult parse(String raw) {
    final McTextResult? cached = _entries[raw];
    if (cached != null) return cached;
    final McTextResult parsed = parseMcText(raw);
    if (_entries.length >= capacity) {
      _entries.remove(_entries.keys.first);
    }
    _entries[raw] = parsed;
    return parsed;
  }

  void clear() => _entries.clear();
}

/// Widest row of [pixels] measured in the characters the plugin actually emits.
///
/// `TextImageMenuIcon.createComponents` writes one `█` for an opaque pixel but
/// a bold space AND a plain space for any pixel with alpha below 255, and
/// `CollisionPlane` width is `TextUtils.content(row).length() * lineHeight / 2`
/// — which recurses into those two children. A transparent pixel therefore
/// counts twice, so the plane cannot be derived from the pixel width.
int imageRowChars(ImagePixels pixels) {
  int widest = 0;
  for (int y = 0; y < pixels.height; y++) {
    int chars = 0;
    for (int x = 0; x < pixels.width; x++) {
      chars += ((pixels.at(x, y) >> 24) & 0xFF) < 255 ? 2 : 1;
    }
    if (chars > widest) widest = chars;
  }
  return widest;
}

/// Memo for [imageRowChars]. Scenes are rebuilt on every repaint and a 32x32
/// icon is a thousand samples, so the scan is done once per decoded grid.
class ImageCharCache {
  ImageCharCache({this.capacity = 128});

  final int capacity;
  final Map<String, int> _entries = <String, int>{};

  int maxRowChars(String path, ImagePixels pixels) {
    final String key = '$path#${pixels.width}x${pixels.height}';
    final int? cached = _entries[key];
    if (cached != null) return cached;
    final int measured = imageRowChars(pixels);
    if (_entries.length >= capacity) {
      _entries.remove(_entries.keys.first);
    }
    _entries[key] = measured;
    return measured;
  }

  void clear() => _entries.clear();
}

/// Builds the frame. [animationTicks] is the number of elapsed Minecraft ticks,
/// which selects the frame of every animated icon.
CanvasScene buildCanvasScene({
  required HuiMenu menu,
  required double uiScale,
  required bool trueRender,
  required bool Function(String id) togglePreview,
  required McTextCache textCache,
  ImageLibrary? images,
  HuiCatalogs? catalogs,
  ImageCharCache? charCache,
  int animationTicks = 0,
}) {
  final List<CanvasItem> items = <CanvasItem>[];
  for (int index = 0; index < menu.components.length; index++) {
    items.add(
      _resolveItem(
        component: menu.components[index],
        index: index,
        menuOffset: menu.offset,
        uiScale: uiScale,
        trueRender: trueRender,
        togglePreview: togglePreview,
        textCache: textCache,
        images: images,
        catalogs: catalogs,
        charCache: charCache,
        animationTicks: animationTicks,
      ),
    );
  }

  final List<CanvasItem> drawOrder = List<CanvasItem>.of(items)
    ..sort((CanvasItem a, CanvasItem b) {
      final int byDepth = b.depth.compareTo(a.depth);
      return byDepth != 0 ? byDepth : a.index.compareTo(b.index);
    });

  return CanvasScene(
    items: items,
    drawOrder: drawOrder,
    overlaps: _findOverlaps(items),
    menuOffset: menu.offset.copy(),
    uiScale: uiScale,
    trueRender: trueRender,
  );
}

CanvasItem _resolveItem({
  required HuiComponent component,
  required int index,
  required Vec3 menuOffset,
  required double uiScale,
  required bool trueRender,
  required bool Function(String id) togglePreview,
  required McTextCache textCache,
  required ImageLibrary? images,
  required HuiCatalogs? catalogs,
  required ImageCharCache? charCache,
  required int animationTicks,
}) {
  final HuiComponentData data = component.data;
  final bool isToggle = data is HuiToggleData;
  final bool showsTrue = isToggle && togglePreview(component.id);
  final HuiIcon? icon = switch (data) {
    HuiButtonData() => data.icon,
    HuiDecorationData() => data.icon,
    HuiToggleData() => showsTrue ? data.trueIcon : data.falseIcon,
  };
  final bool clickable = data is HuiButtonData || data is HuiToggleData;

  CanvasIconKind kind = CanvasIconKind.missing;
  IconShape shape = const IconShape.missing();

  // Diverges from `shape` for images: the drawn box is measured in pixels and
  // the collision plane in characters, which are not the same count.
  IconShape hitShape = const IconShape.missing();
  McTextResult? text;
  String? imagePath;
  ImagePixels? pixels;
  String itemKey = '';
  int itemCount = 1;
  String? itemTexture;
  String itemProvider = '';
  int animationFrame = -1;
  int animationFrameCount = 0;

  switch (icon) {
    case null:
      break;
    case HuiTextIcon():
      // A text icon that parses to nothing renders nothing in game; it is not
      // the missing placeholder, so it keeps its kind and a zero-size shape.
      final McTextResult parsed = textCache.parse(icon.text);
      kind = CanvasIconKind.text;
      text = parsed;
      shape = IconShape.text(
        lines: parsed.lineCount,
        maxLineChars: parsed.maxLineLength,
      );
      hitShape = shape;
    case HuiTextImageIcon():
      final _ResolvedImage resolved = _resolveImage(icon.path, images);
      if (resolved.valid) {
        kind = CanvasIconKind.image;
        imagePath = icon.path;
        pixels = resolved.pixels;
        shape = IconShape.image(rows: resolved.height, columns: resolved.width);
        hitShape = IconShape.image(
          rows: resolved.height,
          columns: _hitChars(icon.path, resolved, charCache),
        );
      }
    case HuiAnimatedImageIcon():
      animationFrameCount = icon.source.length;
      if (animationFrameCount > 0) {
        final int speed = math.max(1, icon.speed);
        animationFrame = (animationTicks ~/ speed) % animationFrameCount;
        final String path = icon.source[animationFrame];
        final _ResolvedImage resolved = _resolveImage(path, images);
        if (resolved.valid) {
          kind = CanvasIconKind.image;
          imagePath = path;
          pixels = resolved.pixels;
          // Every frame is padded with blank rows up to the tallest frame, and
          // the collision plane is built ONCE from frame 0
          // (AnimatedTextImageMenuIcon.createBoundingBox), so neither the
          // stack height nor the plane may follow the frame on screen.
          final int stackRows = math.max(
            resolved.height,
            _animatedStackRows(icon.source, images),
          );
          shape = IconShape.image(rows: stackRows, columns: resolved.width);
          hitShape = IconShape.image(
            rows: stackRows,
            columns: _animatedHitChars(
              source: icon.source,
              stackRows: stackRows,
              current: resolved,
              currentPath: path,
              images: images,
              charCache: charCache,
            ),
          );
        }
      }
    case HuiItemIcon():
      itemKey = icon.item.trim().toLowerCase();
      itemCount = math.max(1, icon.count);
      if (itemKey.isNotEmpty) {
        kind = CanvasIconKind.item;
        itemTexture = catalogs?.textureFor(itemKey);
        shape = IconShape.item(
          count: itemCount,
          isBlockItem: huiIsBlockLikeMaterial(itemKey),
        );
        hitShape = shape;
      }
    case HuiCustomItemIcon():
      // The resolved stack is a plain ItemStack, so the plugin renders it
      // through the same ItemMenuIcon: the geometry is the vanilla item's,
      // down to the collision plane. Only the sprite is approximate, and only
      // when the server exported a base material for this id.
      itemKey = icon.item.trim();
      itemCount = math.max(1, icon.count);
      itemProvider = icon.provider.trim();
      if (itemKey.isNotEmpty) {
        kind = CanvasIconKind.customItem;
        final String? material = catalogs?.customItems
            .entry(itemProvider, itemKey)
            ?.material;
        itemTexture = material == null ? null : catalogs?.textureFor(material);
        shape = IconShape.item(
          count: itemCount,
          isBlockItem: material != null && huiIsBlockLikeMaterial(material),
        );
        hitShape = shape;
      }
  }

  final WorldPoint anchor = anchorFor(
    component: component,
    uiScale: uiScale,
    menuOffset: menuOffset,
  );
  return CanvasItem(
    component: component,
    index: index,
    kind: kind,
    shape: shape,
    anchor: anchor,
    depth: depthFor(
      component: component,
      uiScale: uiScale,
      menuOffset: menuOffset,
    ),
    hitbox: hitboxAt(
      anchorX: anchor.x,
      anchorY: anchor.y,
      uiScale: uiScale,
      shape: hitShape,
      override: data is HuiButtonData ? data.hitbox : null,
      trueRender: trueRender,
    ),
    visual: visualBoundsAt(
      anchorX: anchor.x,
      anchorY: anchor.y,
      uiScale: uiScale,
      shape: shape,
      trueRender: trueRender,
    ),
    clickable: clickable,
    isToggle: isToggle,
    toggleShowsTrue: showsTrue,
    icon: icon,
    text: text,
    imagePath: imagePath,
    pixels: pixels,
    itemKey: itemKey,
    itemCount: itemCount,
    itemTexture: itemTexture,
    itemProvider: itemProvider,
    animationFrame: animationFrame,
    animationFrameCount: animationFrameCount,
  );
}

class _ResolvedImage {
  const _ResolvedImage({
    required this.valid,
    required this.width,
    required this.height,
    this.pixels,
  });

  static const _ResolvedImage invalid = _ResolvedImage(
    valid: false,
    width: 0,
    height: 0,
  );

  final bool valid;
  final int width;
  final int height;
  final ImagePixels? pixels;
}

/// An unknown path renders the plugin's magenta/black placeholder, exactly as a
/// failed `ImageIO.read` does in game.
_ResolvedImage _resolveImage(String path, ImageLibrary? images) {
  if (path.trim().isEmpty || images == null) {
    return _ResolvedImage.invalid;
  }
  final StoredImage? stored = images.byPath(path);
  if (stored == null || stored.width <= 0 || stored.height <= 0) {
    return _ResolvedImage.invalid;
  }
  return _ResolvedImage(
    valid: true,
    width: stored.width,
    height: stored.height,
    // Null on a cache miss; the library notifies and the canvas repaints.
    pixels: images.pixelsFor(path),
  );
}

/// Plane width of one image in characters. Until the decode lands the pixel
/// width is the only number available; the repaint that follows the decode
/// replaces it with the real count.
int _hitChars(String path, _ResolvedImage resolved, ImageCharCache? charCache) {
  final ImagePixels? pixels = resolved.pixels;
  if (pixels == null) return resolved.width;
  return charCache == null
      ? imageRowChars(pixels)
      : charCache.maxRowChars(path, pixels);
}

/// Tallest frame in the set: the height every frame is padded to.
int _animatedStackRows(List<String> source, ImageLibrary? images) {
  int rows = 0;
  for (final String path in source) {
    final _ResolvedImage frame = _resolveImage(path, images);
    if (frame.valid && frame.height > rows) rows = frame.height;
  }
  return rows;
}

/// Frame 0's widest row in characters, including the blank rows it is padded
/// with — each of those is a bold space plus a space per source COLUMN, so a
/// short first frame is measured two characters per column.
int _animatedHitChars({
  required List<String> source,
  required int stackRows,
  required _ResolvedImage current,
  required String currentPath,
  required ImageLibrary? images,
  required ImageCharCache? charCache,
}) {
  final String firstPath = source.first;
  final _ResolvedImage first = _resolveImage(firstPath, images);
  if (!first.valid) {
    // Frame 0 missing means the plugin never builds the icon at all; the
    // current frame is the least misleading stand-in.
    return _hitChars(currentPath, current, charCache);
  }
  final int chars = _hitChars(firstPath, first, charCache);
  if (stackRows <= first.height) return chars;
  return math.max(chars, first.width * 2);
}

List<CanvasOverlap> _findOverlaps(List<CanvasItem> items) {
  final List<CanvasOverlap> overlaps = <CanvasOverlap>[];
  for (int i = 0; i < items.length; i++) {
    final CanvasItem a = items[i];
    if (!a.clickable || a.hitbox.w <= 0 || a.hitbox.h <= 0) continue;
    for (int j = i + 1; j < items.length; j++) {
      final CanvasItem b = items[j];
      if (!b.clickable || b.hitbox.w <= 0 || b.hitbox.h <= 0) continue;
      if (!a.hitbox.overlaps(b.hitbox)) continue;
      overlaps.add(
        CanvasOverlap(
          firstId: a.id,
          secondId: b.id,
          region: HuiRect.fromEdges(
            left: math.max(a.hitbox.left, b.hitbox.left),
            bottom: math.max(a.hitbox.bottom, b.hitbox.bottom),
            right: math.min(a.hitbox.right, b.hitbox.right),
            top: math.min(a.hitbox.top, b.hitbox.top),
          ),
        ),
      );
    }
  }
  return overlaps;
}

/// Heuristic stand-in for Bukkit's `Material.isBlock()` plus
/// `ItemMenuIcon.BLOCK_BLACKLIST`. The catalog carries no block flag, and the
/// only thing this changes is the true-render vertical drop (1.169 vs 1.309
/// blocks), so an occasional miss is cosmetic and confined to that mode.
bool huiIsBlockLikeMaterial(String key) {
  final String normalized = key.contains(':')
      ? key.substring(key.indexOf(':') + 1)
      : key;
  if (normalized.isEmpty || _flatRenderedBlocks.contains(normalized)) {
    return false;
  }
  for (final String suffix in _itemSuffixes) {
    if (normalized.endsWith(suffix)) return false;
  }
  if (_itemExact.contains(normalized)) return false;
  for (final String suffix in _blockSuffixes) {
    if (normalized.endsWith(suffix)) return true;
  }
  return _blockExact.contains(normalized);
}

/// `ItemMenuIcon.BLOCK_BLACKLIST` — blocks the plugin deliberately draws flat.
const Set<String> _flatRenderedBlocks = <String>{
  'barrier',
  'light',
  'hopper',
  'turtle_egg',
  'grass',
  'short_grass',
  'tall_grass',
  'poppy',
  'dandelion',
  'glass_pane',
  'white_stained_glass_pane',
  'orange_stained_glass_pane',
  'magenta_stained_glass_pane',
  'light_blue_stained_glass_pane',
  'yellow_stained_glass_pane',
  'lime_stained_glass_pane',
  'pink_stained_glass_pane',
  'gray_stained_glass_pane',
  'light_gray_stained_glass_pane',
  'cyan_stained_glass_pane',
  'purple_stained_glass_pane',
  'blue_stained_glass_pane',
  'brown_stained_glass_pane',
  'green_stained_glass_pane',
  'red_stained_glass_pane',
  'black_stained_glass_pane',
};

const Set<String> _itemSuffixes = <String>{
  '_sword',
  '_pickaxe',
  '_axe',
  '_shovel',
  '_hoe',
  '_helmet',
  '_chestplate',
  '_leggings',
  '_boots',
  '_horse_armor',
  '_ingot',
  '_nugget',
  '_dye',
  '_bucket',
  '_boat',
  '_raft',
  '_minecart',
  '_spawn_egg',
  '_seeds',
  '_stew',
  '_soup',
  '_pie',
  '_apple',
  '_arrow',
  '_potion',
  '_bottle',
  '_shard',
  '_disc',
  '_upgrade_smithing_template',
  '_pottery_sherd',
  '_banner_pattern',
  '_smithing_template',
  '_horse_spawn_egg',
};

const Set<String> _itemExact = <String>{
  'stick',
  'string',
  'flint',
  'feather',
  'leather',
  'paper',
  'book',
  'writable_book',
  'written_book',
  'enchanted_book',
  'knowledge_book',
  'map',
  'filled_map',
  'compass',
  'recovery_compass',
  'clock',
  'spyglass',
  'bow',
  'crossbow',
  'trident',
  'shield',
  'elytra',
  'saddle',
  'name_tag',
  'lead',
  'shears',
  'fishing_rod',
  'carrot_on_a_stick',
  'warped_fungus_on_a_stick',
  'bread',
  'wheat',
  'sugar',
  'egg',
  'bone',
  'bone_meal',
  'blaze_rod',
  'blaze_powder',
  'ghast_tear',
  'gunpowder',
  'ender_pearl',
  'ender_eye',
  'nether_star',
  'fire_charge',
  'firework_rocket',
  'firework_star',
  'coal',
  'charcoal',
  'diamond',
  'emerald',
  'quartz',
  'amethyst_shard',
  'copper_ingot',
  'raw_iron',
  'raw_gold',
  'raw_copper',
  'redstone',
  'glowstone_dust',
  'slime_ball',
  'magma_cream',
  'brick',
  'nether_brick',
  'clay_ball',
  'glass_bottle',
  'experience_bottle',
  'rotten_flesh',
  'spider_eye',
  'fermented_spider_eye',
  'phantom_membrane',
  'rabbit_hide',
  'rabbit_foot',
  'nautilus_shell',
  'heart_of_the_sea',
  'totem_of_undying',
  'trial_key',
  'ominous_trial_key',
  'breeze_rod',
  'wind_charge',
  'mace',
  'goat_horn',
  'echo_shard',
  'disc_fragment_5',
  'armor_stand',
  'item_frame',
  'glow_item_frame',
  'painting',
  'flower_pot',
  'end_crystal',
  'brush',
  'wolf_armor',
};

const Set<String> _blockSuffixes = <String>{
  '_block',
  '_blocks',
  '_stairs',
  '_slab',
  '_fence',
  '_fence_gate',
  '_wall',
  '_door',
  '_trapdoor',
  '_log',
  '_wood',
  '_planks',
  '_leaves',
  '_sapling',
  '_ore',
  '_bricks',
  '_concrete',
  '_concrete_powder',
  '_terracotta',
  '_glass',
  '_wool',
  '_carpet',
  '_bed',
  '_sand',
  '_stone',
  '_dirt',
  '_sign',
  '_button',
  '_pressure_plate',
  '_shulker_box',
  '_stem',
  '_pillar',
  '_tiles',
  '_candle',
  '_lantern',
  '_torch',
  '_chest',
  '_furnace',
  '_table',
  '_rail',
  '_piston',
  '_head',
  '_skull',
  '_mushroom',
  '_coral',
  '_coral_fan',
  '_roots',
  '_vines',
  '_cake',
  '_pane',
  '_bulb',
  '_grate',
  '_pot',
  '_moss',
  '_sculk',
  '_ice',
  '_snow',
  '_gravel',
  '_clay',
  '_bookshelf',
  '_anvil',
};

const Set<String> _blockExact = <String>{
  'stone',
  'dirt',
  'grass_block',
  'sand',
  'gravel',
  'cobblestone',
  'bedrock',
  'obsidian',
  'glass',
  'ice',
  'snow',
  'clay',
  'netherrack',
  'glowstone',
  'sponge',
  'tnt',
  'bookshelf',
  'chest',
  'ender_chest',
  'crafting_table',
  'furnace',
  'anvil',
  'beacon',
  'cactus',
  'pumpkin',
  'melon',
  'jukebox',
  'ladder',
  'scaffolding',
  'barrel',
  'lodestone',
  'respawn_anchor',
  'lectern',
  'composter',
  'grindstone',
  'smithing_table',
  'fletching_table',
  'cartography_table',
  'loom',
  'stonecutter',
  'bell',
  'campfire',
  'soul_campfire',
  'conduit',
  'dragon_egg',
  'spawner',
  'trial_spawner',
  'vault',
  'crafter',
  'beehive',
  'bee_nest',
  'target',
  'observer',
  'dispenser',
  'dropper',
  'hopper_minecart',
  'note_block',
  'redstone_lamp',
  'daylight_detector',
  'sea_lantern',
  'shroomlight',
  'magma_block',
  'slime_block',
  'honey_block',
  'end_stone',
  'purpur_block',
  'prismarine',
  'terracotta',
  'calcite',
  'tuff',
  'deepslate',
  'basalt',
  'dripstone_block',
  'moss_block',
  'mud',
  'mangrove_roots',
  'sculk',
  'amethyst_block',
};

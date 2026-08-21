/// Identity of a rasterized icon.
///
/// The 3D preview draws each icon by blitting a cached bitmap, so it needs one
/// string that changes whenever the drawn pixels would change and never
/// otherwise. Two structurally identical decorations must produce the same key
/// — sharing one sprite between them is the whole point.
///
/// Pure, so the rule is testable on the VM even though the rasterizer that
/// consumes it is not.
library;

import '../model/model.dart';
import 'canvas_scene.dart';
import 'mc_text.dart';

/// Cache key for the bitmap of [item] at a given rasterization scale.
///
/// [pxPerBlock] and [uiScale] both change the glyph size, so both participate.
/// [obfuscationTick] participates ONLY when the parsed text actually contains
/// an obfuscated span: a static label must not re-rasterize ten times a second
/// just because something else on screen scrambles.
String spriteCacheKey(
  CanvasItem item, {
  required double pxPerBlock,
  required double uiScale,
  required int obfuscationTick,
}) {
  final StringBuffer key = StringBuffer(item.kind.name)
    ..write('|')
    // A toggle draws one of two icons; the resolved side is part of the
    // appearance even when both sides parse to the same shape.
    ..write(item.isToggle ? (item.toggleShowsTrue ? 't' : 'f') : '-')
    ..write('|')
    ..write(_num(uiScale))
    ..write('|')
    ..write(_num(pxPerBlock));

  switch (item.kind) {
    case CanvasIconKind.text:
      final HuiIcon? icon = item.icon;
      key
        ..write('|')
        ..write(icon is HuiTextIcon ? icon.text : '');
      if (_hasObfuscatedSpan(item.text)) {
        key
          ..write('|o')
          ..write(obfuscationTick);
      }
    case CanvasIconKind.image:
      // The frame path is the frame identity: an animation that reuses a path
      // legitimately reuses its sprite. Dimensions ride along because the
      // decode can land after the first key was minted.
      key
        ..write('|')
        ..write(item.imagePath ?? '')
        ..write('|')
        ..write(item.shape.rows)
        ..write('x')
        ..write(item.shape.columns);
    case CanvasIconKind.item:
    case CanvasIconKind.block:
    case CanvasIconKind.customItem:
    // A head draws the one generic sprite for every name, so the authored
    // player in `itemKey` is what keeps two heads from sharing a bitmap once
    // the label under an unresolved sprite differs.
    case CanvasIconKind.playerHead:
      key
        ..write('|')
        ..write(item.itemProvider)
        ..write('|')
        ..write(item.itemKey)
        ..write('|')
        ..write(item.itemCount)
        ..write('|')
        // Sprites are data URIs of a kilobyte or two; hashing keeps the key
        // small. The texture is derived from the item key anyway, so this only
        // has to notice the catalog arriving after the first paint.
        ..write(item.itemTexture?.hashCode.toRadixString(36) ?? '-');
    case CanvasIconKind.entity:
      key
        ..write('|')
        ..write(item.entityKey)
        ..write('|')
        ..write(item.entityTexture?.hashCode.toRadixString(36) ?? '-')
        ..write('|')
        ..write(_num(item.shape.entityWidth))
        ..write('x')
        ..write(_num(item.shape.entityHeight));
    case CanvasIconKind.missing:
      // The magenta/black checker is the same 8x8 bitmap everywhere.
      break;
  }
  return key.toString();
}

/// Blocks are authored to a few decimals and scales come from sliders; four
/// digits is far past what a rasterizer can resolve and keeps float noise from
/// splitting the cache.
String _num(double value) => value.isFinite ? value.toStringAsFixed(4) : '0';

bool _hasObfuscatedSpan(McTextResult? parsed) {
  if (parsed == null) return false;
  for (final List<McSpan> line in parsed.lines) {
    for (final McSpan span in line) {
      if (span.obfuscated) return true;
    }
  }
  return false;
}

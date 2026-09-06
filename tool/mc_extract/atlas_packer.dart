/// Packs same-width tiles into one PNG on a 16-pixel grid.
///
/// Tile (0, 0) is always the missing-texture checker so an unresolved texture
/// id draws the client's own magenta and black. Animated strips (a `.mcmeta`
/// beside the PNG) keep their full height and record their frame count; the
/// manifest's UV lookup takes frame 0.
library;

import 'dart:math' as math;

import 'package:gloss_editor/mc/assets/mc_pack_manifest.dart';
import 'package:image/image.dart' as img;

final class AtlasTile {
  const AtlasTile(this.id, this.image, this.frames);
  final String id;
  final img.Image image;
  final int frames;
}

final class PackedAtlas {
  const PackedAtlas(this.image, this.entries);
  final img.Image image;
  final Map<String, McAtlasEntry> entries;
}

img.Image missingTile(int size) {
  final img.Image tile = img.Image(width: size, height: size, numChannels: 4);
  final img.Color magenta = img.ColorRgba8(0xF8, 0x00, 0xF8, 0xFF);
  final img.Color black = img.ColorRgba8(0, 0, 0, 0xFF);
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final bool left = x < size / 2, top = y < size / 2;
      tile.setPixel(x, y, left == top ? magenta : black);
    }
  }
  return tile;
}

/// Shelf packing: tiles sorted tallest first, rows of [tile]-pixel columns,
/// width chosen as the smallest power of two that keeps the sheet roughly
/// square. Oversized tiles (a 32-px item) span several columns.
PackedAtlas packAtlas(List<AtlasTile> tiles, {int tile = 16}) {
  final List<AtlasTile> sorted = <AtlasTile>[
    AtlasTile('missing', missingTile(tile), 1),
    ...tiles..sort((AtlasTile a, AtlasTile b) {
      final int byHeight = b.image.height.compareTo(a.image.height);
      return byHeight != 0 ? byHeight : a.id.compareTo(b.id);
    }),
  ];
  int area = 0;
  for (final AtlasTile t in sorted) {
    area += _ceilTo(t.image.width, tile) * _ceilTo(t.image.height, tile);
  }
  int width = tile;
  while (width * width < area * 1.15) {
    width *= 2;
  }
  final Map<String, McAtlasEntry> entries = <String, McAtlasEntry>{};
  int cursorX = 0, cursorY = 0, shelfHeight = 0;
  for (final AtlasTile t in sorted) {
    final int w = _ceilTo(t.image.width, tile);
    final int h = _ceilTo(t.image.height, tile);
    if (cursorX + w > width) {
      cursorX = 0;
      cursorY += shelfHeight;
      shelfHeight = 0;
    }
    entries[t.id] = McAtlasEntry(
      id: t.id,
      x: cursorX,
      y: cursorY,
      width: t.image.width,
      height: t.image.height,
      frames: t.frames,
    );
    cursorX += w;
    shelfHeight = math.max(shelfHeight, h);
  }
  final int height = _ceilTo(cursorY + shelfHeight, tile);
  final img.Image sheet = img.Image(width: width, height: height, numChannels: 4);
  img.fill(sheet, color: img.ColorRgba8(0, 0, 0, 0));
  for (final AtlasTile t in sorted) {
    final McAtlasEntry entry = entries[t.id]!;
    img.compositeImage(sheet, t.image, dstX: entry.x, dstY: entry.y, blend: img.BlendMode.direct);
  }
  return PackedAtlas(sheet, entries);
}

int _ceilTo(int value, int step) => ((value + step - 1) ~/ step) * step;

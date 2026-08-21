import 'dart:io';

import 'package:gloss_editor/config/showcase_flavor.dart';
import 'package:gloss_editor/logic/real_drop_block_geometry.dart';
import 'package:test/test.dart';

void main() {
  test('placeable samples use block geometry and items retain sprites', () {
    for (final ShowcaseDrop drop in showcaseDrops) {
      expect(
        realDropUsesBlockGeometry(drop.block),
        drop.block,
        reason: drop.material,
      );
    }
  });

  test('every placeable sample has explicit block geometry and textures', () {
    for (final ShowcaseDrop drop in showcaseDrops.where(
      (ShowcaseDrop drop) => drop.block,
    )) {
      expect(
        realDropBlockGeometries,
        contains(drop.material),
        reason: '${drop.material} must not fall back to another block texture',
      );
      final RealDropBlockGeometry geometry = realDropBlockGeometry(
        drop.material,
      );
      expect(geometry.width, greaterThan(0), reason: drop.material);
      expect(geometry.height, greaterThan(0), reason: drop.material);
      expect(geometry.depth, greaterThan(0), reason: drop.material);
      for (final String texture in <String>{
        geometry.sideTexture,
        geometry.topTexture,
        geometry.bottomTexture,
      }) {
        expect(
          File('web/$texture').existsSync(),
          isTrue,
          reason: '${drop.material} references missing $texture',
        );
      }
    }
  });

  test('oak slab uses half-height block bounds', () {
    final RealDropBlockGeometry geometry = realDropBlockGeometry('OAK_SLAB');
    expect(geometry.width, 1);
    expect(geometry.height, 0.5);
    expect(geometry.depth, 1);
    expect(geometry.sideTexture, endsWith('/oak_planks.png'));
  });

  test('cube and log face textures preserve their block geometry', () {
    final RealDropBlockGeometry cobblestone = realDropBlockGeometry(
      'cobblestone',
    );
    expect(cobblestone.width, 1);
    expect(cobblestone.height, 1);
    expect(cobblestone.depth, 1);
    expect(cobblestone.topTexture, cobblestone.sideTexture);
    expect(cobblestone.bottomTexture, cobblestone.sideTexture);

    final RealDropBlockGeometry log = realDropBlockGeometry('cherry_log');
    expect(log.topTexture, isNot(log.sideTexture));
    expect(log.bottomTexture, log.topTexture);
  });
}

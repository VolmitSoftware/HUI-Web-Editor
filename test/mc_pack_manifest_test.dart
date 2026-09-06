/// `pack.json`: what the tool writes and what the loader reads back.
library;

import 'package:gloss_editor/mc/assets/mc_pack_manifest.dart';
import 'package:gloss_editor/mc/mesh/mc_mesh.dart';
import 'package:test/test.dart';

McPackManifest _manifest() => const McPackManifest(
  version: '26.2',
  jarSha256: 'abc',
  generatedAt: '2026-09-05T00:00:00Z',
  blocks: McAtlas(
    image: 'blocks.png',
    width: 64,
    height: 64,
    entries: <String, McAtlasEntry>{
      'block/stone': McAtlasEntry(id: 'block/stone', x: 16, y: 32, width: 16, height: 16, frames: 1),
      'block/water_still': McAtlasEntry(id: 'block/water_still', x: 0, y: 0, width: 16, height: 32, frames: 2),
    },
  ),
  items: McAtlas(image: 'items.png', width: 16, height: 16, entries: <String, McAtlasEntry>{}),
  entityTextures: <String, String>{'zombie': 'entity/zombie/zombie.png'},
  hud: <String, String>{'hotbar': 'hud/hotbar.png'},
  environment: <String, String>{'sun': 'environment/sun.png'},
  player: McPlayerMeta(name: 'Magic_Psycho', uuid: '85ff4989a64f4db693f100c85bfc4e75', slim: false, cape: true),
  counts: <String, int>{'models': 3},
  spriteFallbacks: <String>['chest'],
);

void main() {
  test('round-trips through JSON', () {
    final McPackManifest copy = McPackManifest.fromJson(_manifest().toJson());
    expect(copy.version, '26.2');
    expect(copy.blocks.entries['block/stone']!.x, 16);
    expect(copy.player.cape, isTrue);
    expect(copy.spriteFallbacks, <String>['chest']);
    expect(copy.entityTextures['zombie'], 'entity/zombie/zombie.png');
  });

  test('atlas UVs are normalised and take frame 0 of an animation', () {
    final McAtlas atlas = _manifest().blocks;
    final McUvRect stone = atlas.uv('block/stone')!;
    expect(stone.u0, 0.25);
    expect(stone.v0, 0.5);
    expect(stone.u1, 0.5);
    expect(stone.v1, 0.75);
    final McUvRect water = atlas.uv('block/water_still')!;
    expect(water.v1 - water.v0, 0.25);
    expect(atlas.uv('block/nothing'), isNull);
  });

  test('the base url is versioned', () {
    expect(mcPackBaseUrl('26.2'), 'assets/mc/26.2');
  });
}

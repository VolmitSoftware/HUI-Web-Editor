/// Resource ids the pack, the resolver and the stages agree on.
library;

import 'package:gloss_editor/mc/assets/mc_ids.dart';
import 'package:test/test.dart';

void main() {
  test('the minecraft namespace is implicit', () {
    expect(mcStrip('minecraft:block/stone'), 'block/stone');
    expect(mcStrip('block/stone'), 'block/stone');
    expect(mcStrip('gloss:thing'), 'gloss:thing');
  });

  test('model references keep their block or item folder', () {
    expect(mcModelId('minecraft:block/grass_block'), 'block/grass_block');
    expect(mcModelId('item/diamond_sword'), 'item/diamond_sword');
    expect(mcModelId('builtin/generated'), 'builtin/generated');
  });

  test('texture references are folder-qualified without a namespace', () {
    expect(mcTextureId('minecraft:block/dirt'), 'block/dirt');
    expect(mcTextureId('#side'), '#side');
  });

  test('item and block ids are lower-case bare keys', () {
    expect(mcItemId('DIAMOND_SWORD'), 'diamond_sword');
    expect(mcItemId('minecraft:Oak_Slab'), 'oak_slab');
    expect(mcBlockId('minecraft:GRASS_BLOCK'), 'grass_block');
  });
}

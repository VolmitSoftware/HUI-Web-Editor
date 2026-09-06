/// Plains tint constants and the per-face tint lookup.
library;

import 'package:gloss_editor/mc/assets/mc_model_json.dart';
import 'package:gloss_editor/mc/assets/mc_tint.dart';
import 'package:test/test.dart';

void main() {
  test('plains grass is #91BD59 and foliage #77AB2F', () {
    expect(mcTintGrass, <double>[0x91 / 255, 0xBD / 255, 0x59 / 255]);
    expect(mcTintFoliage, <double>[0x77 / 255, 0xAB / 255, 0x2F / 255]);
  });

  test('a face without a tint index is white', () {
    expect(mcTintFor(const <McTintJson>[McTintJson(type: 'grass')], null), mcTintNone);
  });

  test('tint indices pick the definition tint in order', () {
    final List<McTintJson> tints = <McTintJson>[
      const McTintJson(type: 'constant', defaultArgb: 0xFF3F76E4),
      const McTintJson(type: 'foliage'),
    ];
    expect(mcTintFor(tints, 0), <double>[0x3F / 255, 0x76 / 255, 0xE4 / 255]);
    expect(mcTintFor(tints, 1), mcTintFoliage);
    expect(mcTintFor(tints, 5), mcTintNone);
  });

  test('world blocks tint by name when there is no item definition', () {
    expect(mcTintForBlock('grass_block', 0), mcTintGrass);
    expect(mcTintForBlock('short_grass', 0), mcTintGrass);
    expect(mcTintForBlock('oak_leaves', 0), mcTintFoliage);
    expect(mcTintForBlock('water', 0), mcTintWater);
    expect(mcTintForBlock('stone', 0), mcTintNone);
    expect(mcTintForBlock('grass_block', null), mcTintNone);
  });
}

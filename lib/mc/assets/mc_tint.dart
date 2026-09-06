/// Tints, with no biome to read: the client's plains values, stated once.
///
/// Grass and foliage colormaps are sampled at plains temperature and downfall
/// in the client; the constants here are those samples. Water is the plains
/// water colour. `constant` tints carry their own ARGB. Anything else the
/// editor cannot know (potion, map colour, dye without an item) is white,
/// which is what an untinted quad draws as.
library;

import '../mesh/mc_mesh.dart';
import 'mc_model_json.dart';

const List<double> mcTintNone = <double>[1, 1, 1];
const List<double> mcTintGrass = <double>[0x91 / 255, 0xBD / 255, 0x59 / 255];
const List<double> mcTintFoliage = <double>[0x77 / 255, 0xAB / 255, 0x2F / 255];
const List<double> mcTintDryFoliage = <double>[0xBF / 255, 0xB7 / 255, 0x55 / 255];
const List<double> mcTintWater = <double>[0x3F / 255, 0x76 / 255, 0xE4 / 255];

List<double> mcArgbToRgb(int argb) => <double>[
  ((argb >> 16) & 0xFF) / 255,
  ((argb >> 8) & 0xFF) / 255,
  (argb & 0xFF) / 255,
];

List<double> _byType(McTintJson tint) => switch (tint.type) {
  'grass' => mcTintGrass,
  'foliage' => mcTintFoliage,
  'dry_foliage' => mcTintDryFoliage,
  'water' => mcTintWater,
  'constant' => tint.defaultArgb == null ? mcTintNone : mcArgbToRgb(tint.defaultArgb!),
  _ => tint.defaultArgb == null ? mcTintNone : mcArgbToRgb(tint.defaultArgb!),
};

/// The tint for a face's `tintindex` against an item definition's `tints`.
List<double> mcTintFor(List<McTintJson> tints, int? tintIndex) {
  if (tintIndex == null || tintIndex < 0 || tintIndex >= tints.length) {
    return mcTintNone;
  }
  return _byType(tints[tintIndex]);
}

McTintLookup mcTintLookup(List<McTintJson> tints) =>
    (int? index) => mcTintFor(tints, index);

/// World blocks have no item definition in hand; tint by block name.
List<double> mcTintForBlock(String blockId, int? tintIndex) {
  if (tintIndex == null) return mcTintNone;
  if (blockId == 'water' || blockId.endsWith('_water')) return mcTintWater;
  if (blockId.endsWith('_leaves') || blockId == 'vine') return mcTintFoliage;
  if (blockId == 'grass_block' ||
      blockId == 'short_grass' ||
      blockId == 'tall_grass' ||
      blockId == 'fern' ||
      blockId == 'large_fern' ||
      blockId == 'sugar_cane') {
    return mcTintGrass;
  }
  return mcTintNone;
}

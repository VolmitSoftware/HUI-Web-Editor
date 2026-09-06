/// `RealDropModel.blockGeometry`, ported suffix for suffix
/// (`../Gloss/src/main/java/art/arcane/gloss/drop/RealDropModel.java:227-256`).
library;

import 'package:gloss_editor/logic/real_drop_block_geometry.dart';
import 'package:test/test.dart';

void main() {
  RealDropBlockGeometry g(String material) => realDropBlockGeometry(material);

  test('slabs, carpets and pressure plates are the plugin heights', () {
    expect(g('oak_slab').height, 0.5);
    expect(g('STONE_SLAB').height, 0.5);
    expect(g('red_carpet').height, 0.0625);
    expect(g('oak_pressure_plate').height, 0.0625);
  });

  test('named specials match the Java switch', () {
    expect(g('snow').height, 0.125);
    expect(g('cake').width, 0.875);
    expect(g('cake').height, 0.5);
    expect(g('lantern').width, 0.5);
    expect(g('lantern').height, 0.6875);
    expect(g('soul_lantern').height, 0.6875);
    expect(g('black_candle').width, 0.125);
    expect(g('candle').height, 0.375);
    expect(g('red_bed').height, 0.5625);
    expect(g('cherry_sapling').width, 0.75);
    expect(g('cherry_sapling').height, 1);
  });

  test('everything else is a full cube', () {
    expect(
      g('cobblestone'),
      const RealDropBlockGeometry(width: 1, height: 1, depth: 1),
    );
    expect(g('sculk').depth, 1);
    expect(g('anything_at_all').height, 1);
  });

  test('half extents are half the bounds', () {
    expect(g('oak_slab').halfY, 0.25);
    expect(g('cake').halfX, 0.4375);
  });
}

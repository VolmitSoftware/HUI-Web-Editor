/// `RealDropModel.blockGeometry(Material)`, ported suffix for suffix
/// (`RealDropModel.java:227-256`): the bounds the plugin uses to rest a cube
/// on the ground. Java states centre and half extents; this states the full
/// width, height and depth, which is what the stage math takes, and derives
/// the halves. The drawn model comes from the resolver; this table is only
/// the plugin's resting math and is refreshed FROM Gloss.
library;

final class RealDropBlockGeometry {
  const RealDropBlockGeometry({
    required this.width,
    required this.height,
    required this.depth,
  });

  final double width;
  final double height;
  final double depth;

  double get halfX => width / 2;
  double get halfY => height / 2;
  double get halfZ => depth / 2;

  @override
  bool operator ==(Object other) =>
      other is RealDropBlockGeometry &&
      other.width == width &&
      other.height == height &&
      other.depth == depth;

  @override
  int get hashCode => Object.hash(width, height, depth);
}

const RealDropBlockGeometry _cube = RealDropBlockGeometry(
  width: 1,
  height: 1,
  depth: 1,
);

bool realDropUsesBlockGeometry(bool block) => block;

RealDropBlockGeometry realDropBlockGeometry(String material) {
  final String name = material.toUpperCase().replaceFirst('MINECRAFT:', '');
  if (name.endsWith('_SLAB')) {
    return const RealDropBlockGeometry(width: 1, height: 0.5, depth: 1);
  }
  if (name.endsWith('_CARPET')) {
    return const RealDropBlockGeometry(width: 1, height: 0.0625, depth: 1);
  }
  if (name.endsWith('_PRESSURE_PLATE')) {
    return const RealDropBlockGeometry(width: 1, height: 0.0625, depth: 1);
  }
  if (name == 'SNOW') {
    return const RealDropBlockGeometry(width: 1, height: 0.125, depth: 1);
  }
  if (name == 'CAKE') {
    return const RealDropBlockGeometry(width: 0.875, height: 0.5, depth: 0.875);
  }
  if (name == 'LANTERN' || name == 'SOUL_LANTERN') {
    return const RealDropBlockGeometry(width: 0.5, height: 0.6875, depth: 0.5);
  }
  if (name.endsWith('_CANDLE') || name == 'CANDLE') {
    return const RealDropBlockGeometry(
      width: 0.125,
      height: 0.375,
      depth: 0.125,
    );
  }
  if (name.endsWith('_BED')) {
    return const RealDropBlockGeometry(width: 1, height: 0.5625, depth: 1);
  }
  if (name.endsWith('_SAPLING')) {
    return const RealDropBlockGeometry(width: 0.75, height: 1, depth: 0.75);
  }
  return _cube;
}

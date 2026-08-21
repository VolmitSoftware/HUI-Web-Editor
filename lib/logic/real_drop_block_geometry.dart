library;

final class RealDropBlockGeometry {
  const RealDropBlockGeometry({
    required this.width,
    required this.height,
    required this.depth,
    required this.sideTexture,
    String? topTexture,
    String? bottomTexture,
  }) : topTexture = topTexture ?? sideTexture,
       bottomTexture = bottomTexture ?? sideTexture;

  final double width;
  final double height;
  final double depth;
  final String sideTexture;
  final String topTexture;
  final String bottomTexture;
}

const String _blockAsset = 'assets/minecraft/block';

const Map<String, RealDropBlockGeometry> realDropBlockGeometries =
    <String, RealDropBlockGeometry>{
      'cherry_log': RealDropBlockGeometry(
        width: 1,
        height: 1,
        depth: 1,
        sideTexture: '$_blockAsset/cherry_log.png',
        topTexture: '$_blockAsset/cherry_log_top.png',
        bottomTexture: '$_blockAsset/cherry_log_top.png',
      ),
      'cobblestone': RealDropBlockGeometry(
        width: 1,
        height: 1,
        depth: 1,
        sideTexture: '$_blockAsset/cobblestone.png',
      ),
      'cake': RealDropBlockGeometry(
        width: 0.875,
        height: 0.5,
        depth: 0.875,
        sideTexture: '$_blockAsset/cake_side.png',
        topTexture: '$_blockAsset/cake_top.png',
        bottomTexture: '$_blockAsset/cake_bottom.png',
      ),
      'red_carpet': RealDropBlockGeometry(
        width: 1,
        height: 0.0625,
        depth: 1,
        sideTexture: '$_blockAsset/red_wool.png',
      ),
      'oak_slab': RealDropBlockGeometry(
        width: 1,
        height: 0.5,
        depth: 1,
        sideTexture: '$_blockAsset/oak_planks.png',
      ),
      'lantern': RealDropBlockGeometry(
        width: 0.5,
        height: 0.6875,
        depth: 0.5,
        sideTexture: '$_blockAsset/lantern.png',
      ),
      'black_candle': RealDropBlockGeometry(
        width: 0.125,
        height: 0.375,
        depth: 0.125,
        sideTexture: '$_blockAsset/black_candle.png',
      ),
      'sea_lantern': RealDropBlockGeometry(
        width: 1,
        height: 1,
        depth: 1,
        sideTexture: '$_blockAsset/sea_lantern.png',
      ),
      'red_bed': RealDropBlockGeometry(
        width: 1,
        height: 0.5625,
        depth: 1,
        sideTexture: '$_blockAsset/red_bed_foot_east.png',
        topTexture: '$_blockAsset/red_bed_foot_up.png',
      ),
      'snow': RealDropBlockGeometry(
        width: 1,
        height: 0.125,
        depth: 1,
        sideTexture: '$_blockAsset/snow.png',
      ),
      'cherry_sapling': RealDropBlockGeometry(
        width: 0.75,
        height: 1,
        depth: 0.75,
        sideTexture: '$_blockAsset/cherry_sapling.png',
      ),
      'sculk': RealDropBlockGeometry(
        width: 1,
        height: 1,
        depth: 1,
        sideTexture: '$_blockAsset/sculk.png',
      ),
    };

const RealDropBlockGeometry _fallbackBlockGeometry = RealDropBlockGeometry(
  width: 1,
  height: 1,
  depth: 1,
  sideTexture: '$_blockAsset/cobblestone.png',
);

bool realDropUsesBlockGeometry(bool block) => block;

RealDropBlockGeometry realDropBlockGeometry(String material) =>
    realDropBlockGeometries[material.toLowerCase()] ?? _fallbackBlockGeometry;

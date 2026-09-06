/// `builtin/generated`: the client turns a flat item texture into a
/// 1/16-block-thick model. The front (south, +Z) and back (north) are one full
/// quad each and the texture's alpha cuts the silhouette; the four sides are
/// drawn only along the alpha edge, one pixel deep, and merged along runs so a
/// sword is a few hundred quads rather than a few thousand.
///
/// Model space matches the client: X right, Y up, the slab centred on z = 0.5
/// (7.5/16 .. 8.5/16). Texture row 0 is the top of the item, so texture V and
/// model Y run in opposite directions. Every layer sits at the same depth and
/// is emitted in order; the GL pass uses `LEQUAL` so a later layer wins on the
/// shared faces, which is the client's own result.
///
/// Every quad winds clockwise seen from outside, the convention `mc_mesh.dart`
/// sets for the whole pipeline; the GL pass leaves `CULL_FACE` off.
///
/// Pixels come through [McPixelSource] so the VM tests hand in lists and the
/// browser hands in a decoded canvas.
library;

import 'mc_mesh.dart';

const double mcGeneratedDepthBlocks = 1 / 16;
const double _front = 8.5 / 16;
const double _back = 7.5 / 16;

abstract interface class McPixelSource {
  int get width;
  int get height;

  /// 0..255; anything above 0 is part of the item, as in the client.
  int alphaAt(int x, int y);
}

final class McListPixels implements McPixelSource {
  const McListPixels(this.width, this.height, this.alpha);

  @override
  final int width;
  @override
  final int height;
  final List<int> alpha;

  @override
  int alphaAt(int x, int y) =>
      x < 0 || y < 0 || x >= width || y >= height ? 0 : alpha[y * width + x];
}

final class McGeneratedLayer {
  const McGeneratedLayer(this.pixels, this.uv, this.tintIndex);
  final McPixelSource pixels;
  final McUvRect uv;
  final int? tintIndex;
}

McMesh mcMeshGenerated(
  List<McGeneratedLayer> layers, {
  required McTintLookup tint,
}) {
  final McMeshBuilder builder = McMeshBuilder();
  for (final McGeneratedLayer layer in layers) {
    _appendLayer(builder, layer, tint(layer.tintIndex));
  }
  return builder.build();
}

void _appendLayer(McMeshBuilder builder, McGeneratedLayer layer, List<double> tint) {
  final McPixelSource pixels = layer.pixels;
  final int w = pixels.width, h = pixels.height;
  bool any = false;
  for (int y = 0; y < h && !any; y++) {
    for (int x = 0; x < w; x++) {
      if (pixels.alphaAt(x, y) > 0) {
        any = true;
        break;
      }
    }
  }
  if (!any) return;
  final McUvRect r = layer.uv;
  // Front (south) and back (north), full texture.
  builder.quad(
    <List<double>>[[0, 1, _front], [1, 1, _front], [1, 0, _front], [0, 0, _front]],
    <List<double>>[[r.u0, r.v0], [r.u1, r.v0], [r.u1, r.v1], [r.u0, r.v1]],
    1.0,
    tint,
  );
  builder.quad(
    <List<double>>[[1, 1, _back], [0, 1, _back], [0, 0, _back], [1, 0, _back]],
    <List<double>>[[r.u1, r.v0], [r.u0, r.v0], [r.u0, r.v1], [r.u1, r.v1]],
    1.0,
    tint,
  );

  double px(int x) => x / w;
  double py(int y) => 1 - y / h;
  double tu(int x) => r.u(x / w);
  double tv(int y) => r.v(y / h);

  // Horizontal edges (up and down faces): scan rows, merge runs along X.
  for (int y = 0; y < h; y++) {
    int runStart = -1;
    for (int x = 0; x <= w; x++) {
      final bool exposed = x < w && pixels.alphaAt(x, y) > 0 && pixels.alphaAt(x, y - 1) == 0;
      if (exposed && runStart < 0) runStart = x;
      if (!exposed && runStart >= 0) {
        // Top edge of pixel row y: an "up" face at model Y = py(y).
        builder.quad(
          <List<double>>[[px(runStart), py(y), _back], [px(x), py(y), _back], [px(x), py(y), _front], [px(runStart), py(y), _front]],
          <List<double>>[[tu(runStart), tv(y)], [tu(x), tv(y)], [tu(x), tv(y + 1)], [tu(runStart), tv(y + 1)]],
          1.0,
          tint,
        );
        runStart = -1;
      }
    }
    runStart = -1;
    for (int x = 0; x <= w; x++) {
      final bool exposed = x < w && pixels.alphaAt(x, y) > 0 && pixels.alphaAt(x, y + 1) == 0;
      if (exposed && runStart < 0) runStart = x;
      if (!exposed && runStart >= 0) {
        // Bottom edge of pixel row y: a "down" face at model Y = py(y + 1).
        builder.quad(
          <List<double>>[[px(runStart), py(y + 1), _front], [px(x), py(y + 1), _front], [px(x), py(y + 1), _back], [px(runStart), py(y + 1), _back]],
          <List<double>>[[tu(runStart), tv(y)], [tu(x), tv(y)], [tu(x), tv(y + 1)], [tu(runStart), tv(y + 1)]],
          1.0,
          tint,
        );
        runStart = -1;
      }
    }
  }
  // Vertical edges (west and east faces): scan columns, merge runs along Y.
  for (int x = 0; x < w; x++) {
    int runStart = -1;
    for (int y = 0; y <= h; y++) {
      final bool exposed = y < h && pixels.alphaAt(x, y) > 0 && pixels.alphaAt(x - 1, y) == 0;
      if (exposed && runStart < 0) runStart = y;
      if (!exposed && runStart >= 0) {
        // West face at model X = px(x).
        builder.quad(
          <List<double>>[[px(x), py(runStart), _back], [px(x), py(runStart), _front], [px(x), py(y), _front], [px(x), py(y), _back]],
          <List<double>>[[tu(x), tv(runStart)], [tu(x + 1), tv(runStart)], [tu(x + 1), tv(y)], [tu(x), tv(y)]],
          1.0,
          tint,
        );
        runStart = -1;
      }
    }
    runStart = -1;
    for (int y = 0; y <= h; y++) {
      final bool exposed = y < h && pixels.alphaAt(x, y) > 0 && pixels.alphaAt(x + 1, y) == 0;
      if (exposed && runStart < 0) runStart = y;
      if (!exposed && runStart >= 0) {
        // East face at model X = px(x + 1).
        builder.quad(
          <List<double>>[[px(x + 1), py(runStart), _front], [px(x + 1), py(runStart), _back], [px(x + 1), py(y), _back], [px(x + 1), py(y), _front]],
          <List<double>>[[tu(x), tv(runStart)], [tu(x + 1), tv(runStart)], [tu(x + 1), tv(y)], [tu(x), tv(y)]],
          1.0,
          tint,
        );
        runStart = -1;
      }
    }
  }
}

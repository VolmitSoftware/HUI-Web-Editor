/// A CPU rasteriser over `package:image`: the same vertex data, matrices and
/// per-face shade the GL pass draws, so the world still the tool ships is the
/// picture the browser draws, and the VM can check geometry without a GPU.
///
/// Nearest-neighbour sampling, alpha test, z-buffer, no perspective-correct
/// interpolation beyond 1/w on depth and UV (enough at these triangle sizes).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../assets/mc_model_resolver.dart';
import '../assets/mc_pack_manifest.dart';
import '../mesh/mc_mesh.dart';
import '../scene/mc_camera.dart';
import '../scene/mc_math.dart';
import '../scene/mc_projection_bridge.dart';
import '../scene/mc_world_scene.dart';

final class McRasterTarget {
  McRasterTarget(this.width, this.height)
      : image = img.Image(width: width, height: height, numChannels: 4),
        depth = Float32List(width * height);

  final int width;
  final int height;
  final img.Image image;
  final Float32List depth;

  /// Vertical sky gradient, depth reset to the far plane.
  void clear(List<double> skyTop, List<double> skyBottom) {
    for (int y = 0; y < height; y++) {
      final double t = y / math.max(1, height - 1);
      final int r = ((skyTop[0] + (skyBottom[0] - skyTop[0]) * t) * 255).round();
      final int g = ((skyTop[1] + (skyBottom[1] - skyTop[1]) * t) * 255).round();
      final int b = ((skyTop[2] + (skyBottom[2] - skyTop[2]) * t) * 255).round();
      for (int x = 0; x < width; x++) {
        image.setPixelRgba(x, y, r, g, b, 255);
      }
    }
    depth.fillRange(0, depth.length, 1);
  }
}

void mcRasterMesh(
  McRasterTarget target,
  McMesh mesh, {
  required McMat4 model,
  required McMat4 view,
  required McMat4 projection,
  required img.Image texture,
  double alphaCutoff = 0.1,
  List<double>? overlay,
}) {
  final McMat4 mvp = projection.multiply(view).multiply(model);
  final Float64List m = mvp.m;
  final int n = mesh.vertexCount;
  final Float64List sx = Float64List(n), sy = Float64List(n), sz = Float64List(n), sw = Float64List(n);
  for (int v = 0; v < n; v++) {
    final double x = mesh.positions[v * 3], y = mesh.positions[v * 3 + 1], z = mesh.positions[v * 3 + 2];
    final double cx = m[0] * x + m[4] * y + m[8] * z + m[12];
    final double cy = m[1] * x + m[5] * y + m[9] * z + m[13];
    final double cz = m[2] * x + m[6] * y + m[10] * z + m[14];
    final double cw = m[3] * x + m[7] * y + m[11] * z + m[15];
    sw[v] = cw;
    if (cw <= 1e-6) continue;
    sx[v] = (cx / cw + 1) / 2 * target.width;
    sy[v] = (1 - cy / cw) / 2 * target.height;
    sz[v] = cz / cw;
  }
  for (int t = 0; t < mesh.indices.length; t += 3) {
    final int a = mesh.indices[t], b = mesh.indices[t + 1], c = mesh.indices[t + 2];
    if (sw[a] <= 1e-6 || sw[b] <= 1e-6 || sw[c] <= 1e-6) continue;
    _triangle(target, mesh, texture, alphaCutoff, overlay, a, b, c, sx, sy, sz, sw);
  }
}

void _triangle(
  McRasterTarget target,
  McMesh mesh,
  img.Image texture,
  double alphaCutoff,
  List<double>? overlay,
  int a,
  int b,
  int c,
  Float64List sx,
  Float64List sy,
  Float64List sz,
  Float64List sw,
) {
  final double x0 = sx[a], y0 = sy[a], x1 = sx[b], y1 = sy[b], x2 = sx[c], y2 = sy[c];
  final double area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0);
  if (area.abs() < 1e-9) return;
  final int minX = math.max(0, math.min(x0, math.min(x1, x2)).floor());
  final int maxX = math.min(target.width - 1, math.max(x0, math.max(x1, x2)).ceil());
  final int minY = math.max(0, math.min(y0, math.min(y1, y2)).floor());
  final int maxY = math.min(target.height - 1, math.max(y0, math.max(y1, y2)).ceil());
  final double inv = 1 / area;
  final double wa = 1 / sw[a], wb = 1 / sw[b], wc = 1 / sw[c];
  for (int y = minY; y <= maxY; y++) {
    final double py = y + 0.5;
    for (int x = minX; x <= maxX; x++) {
      final double px = x + 0.5;
      double l0 = ((x1 - px) * (y2 - py) - (x2 - px) * (y1 - py)) * inv;
      double l1 = ((x2 - px) * (y0 - py) - (x0 - px) * (y2 - py)) * inv;
      double l2 = 1 - l0 - l1;
      if (l0 < -1e-6 || l1 < -1e-6 || l2 < -1e-6) continue;
      final double z = l0 * sz[a] + l1 * sz[b] + l2 * sz[c];
      final int index = y * target.width + x;
      if (z >= target.depth[index]) continue;
      // Perspective-correct UV.
      final double pw = l0 * wa + l1 * wb + l2 * wc;
      l0 = l0 * wa / pw;
      l1 = l1 * wb / pw;
      l2 = l2 * wc / pw;
      final double u = l0 * mesh.uvs[a * 2] + l1 * mesh.uvs[b * 2] + l2 * mesh.uvs[c * 2];
      final double v = l0 * mesh.uvs[a * 2 + 1] + l1 * mesh.uvs[b * 2 + 1] + l2 * mesh.uvs[c * 2 + 1];
      final int tx = (u * texture.width).floor().clamp(0, texture.width - 1);
      final int ty = (v * texture.height).floor().clamp(0, texture.height - 1);
      final img.Pixel texel = texture.getPixel(tx, ty);
      if (texel.a / 255 < alphaCutoff) continue;
      final double shade = mesh.shades[a];
      double r = texel.r / 255 * mesh.tints[a * 3] * shade;
      double g = texel.g / 255 * mesh.tints[a * 3 + 1] * shade;
      double bl = texel.b / 255 * mesh.tints[a * 3 + 2] * shade;
      if (overlay != null) {
        r = r + (overlay[0] - r) * overlay[3];
        g = g + (overlay[1] - g) * overlay[3];
        bl = bl + (overlay[2] - bl) * overlay[3];
      }
      target.depth[index] = z;
      target.image.setPixelRgba(x, y, (r * 255).round(), (g * 255).round(), (bl * 255).round(), 255);
    }
  }
}

const List<double> mcSkyTop = <double>[0x78 / 255, 0xA7 / 255, 0xFF / 255];
const List<double> mcSkyHorizon = <double>[0xC0 / 255, 0xD8 / 255, 0xFF / 255];

/// The game frame's fixed view of the world, for the no-WebGL fallback and
/// the 2D artboard backdrop.
img.Image mcRenderWorldStill({
  required McPackManifest manifest,
  required McModelResolver resolver,
  required img.Image blocksAtlas,
  required int width,
  required int height,
}) {
  final McRasterTarget target = McRasterTarget(width, height);
  target.clear(mcSkyTop, mcSkyHorizon);
  final McCamera camera = mcCameraHome(McStageKind.frame, mcWorldSpawn);
  final McMat4 view = camera.view();
  final McMat4 projection = mcGlProjection(
    viewportWidthPx: width.toDouble(),
    viewportHeightPx: height.toDouble(),
    perspectivePx: 900,
  );
  for (final McMesh chunk in mcMeshWorldChunks(McWorldScene.standard, resolver, manifest.blocks.uv)) {
    mcRasterMesh(target, chunk, model: McMat4.identity(), view: view, projection: projection, texture: blocksAtlas);
  }
  return target.image;
}

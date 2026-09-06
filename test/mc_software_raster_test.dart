/// A z-buffer rasteriser: enough to prove the GL pass's geometry on the VM.
library;

import 'dart:typed_data';

import 'package:gloss_editor/mc/mesh/mc_mesh.dart';
import 'package:gloss_editor/mc/raster/mc_software_raster.dart';
import 'package:gloss_editor/mc/scene/mc_camera.dart';
import 'package:gloss_editor/mc/scene/mc_math.dart';
import 'package:gloss_editor/mc/scene/mc_projection_bridge.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

McMesh _quad(double z, List<double> tint) => McMesh(
  positions: Float32List.fromList(<double>[-1, -1, z, 1, -1, z, 1, 1, z, -1, 1, z]),
  uvs: Float32List.fromList(<double>[0, 1, 1, 1, 1, 0, 0, 0]),
  shades: Float32List.fromList(<double>[1, 1, 1, 1]),
  tints: Float32List.fromList(<double>[...tint, ...tint, ...tint, ...tint]),
  indices: Uint16List.fromList(<int>[0, 1, 2, 0, 2, 3]),
);

img.Image _white() {
  final img.Image texture = img.Image(width: 2, height: 2, numChannels: 4);
  img.fill(texture, color: img.ColorRgba8(255, 255, 255, 255));
  return texture;
}

void main() {
  test('a quad in front of the camera paints pixels and writes depth', () {
    final McRasterTarget target = McRasterTarget(64, 64);
    target.clear(const <double>[0, 0, 0], const <double>[0, 0, 0]);
    const McCamera camera = McCamera(pivot: McVec3.zero, yawDeg: 180, pitchDeg: 0, distance: 4);
    mcRasterMesh(
      target,
      _quad(0, const <double>[1, 0, 0]),
      model: McMat4.identity(),
      view: camera.view(),
      projection: mcGlProjection(viewportWidthPx: 64, viewportHeightPx: 64, perspectivePx: 64),
      texture: _white(),
    );
    final img.Pixel centre = target.image.getPixel(32, 32);
    expect(centre.r, 255);
    expect(centre.g, 0);
    expect(target.depth[32 * 64 + 32], lessThan(1));
    expect(target.image.getPixel(1, 1).r, 0, reason: 'corner outside the quad');
  });

  test('nearer geometry wins the depth test regardless of draw order', () {
    final McRasterTarget target = McRasterTarget(32, 32);
    target.clear(const <double>[0, 0, 0], const <double>[0, 0, 0]);
    const McCamera camera = McCamera(pivot: McVec3.zero, yawDeg: 180, pitchDeg: 0, distance: 4);
    final McMat4 projection = mcGlProjection(viewportWidthPx: 32, viewportHeightPx: 32, perspectivePx: 32);
    mcRasterMesh(target, _quad(1, const <double>[0, 1, 0]), model: McMat4.identity(), view: camera.view(), projection: projection, texture: _white());
    mcRasterMesh(target, _quad(-1, const <double>[1, 0, 0]), model: McMat4.identity(), view: camera.view(), projection: projection, texture: _white());
    // Camera at z = +4 looking toward -Z: z = 1 is nearer than z = -1.
    expect(target.image.getPixel(16, 16).g, 255);
    expect(target.image.getPixel(16, 16).r, 0);
  });

  test('alpha below the cutoff is discarded', () {
    final McRasterTarget target = McRasterTarget(16, 16);
    target.clear(const <double>[0, 0, 1], const <double>[0, 0, 1]);
    final img.Image clear = img.Image(width: 2, height: 2, numChannels: 4);
    img.fill(clear, color: img.ColorRgba8(255, 255, 255, 0));
    const McCamera camera = McCamera(pivot: McVec3.zero, yawDeg: 180, pitchDeg: 0, distance: 4);
    mcRasterMesh(
      target,
      _quad(0, const <double>[1, 1, 1]),
      model: McMat4.identity(),
      view: camera.view(),
      projection: mcGlProjection(viewportWidthPx: 16, viewportHeightPx: 16, perspectivePx: 16),
      texture: clear,
    );
    expect(target.image.getPixel(8, 8).b, 255);
  });
}

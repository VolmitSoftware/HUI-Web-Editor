/// Element cuboids to quads, the way the client's `BlockModel` bakes them.
///
/// Each declared face is one quad. Corners are listed so the face winds
/// CLOCKWISE seen from outside (the geometric normal points into the block);
/// `mc_mesh.dart` owns that convention for the whole pipeline. The face's
/// `[u1, v1, u2, v2]` (texture pixels, V down) lands with `(u1, v1)` on the
/// corner the client puts it on; `rotation` (0/90/180/270) turns that
/// assignment. Element `rotation` spins the corners about `origin` on one
/// axis, and `rescale` stretches the other two axes by `1/cos(angle)` so a
/// 45-degree cross still spans the block.
///
/// Shade is the client's flat directional light: up 1.0, down 0.5, north and
/// south 0.8, east and west 0.6; `shade: false` (plants) is 1.0 everywhere.
/// Cull is the caller's business: the world scene passes a neighbour test,
/// display models pass nothing and draw every face.
library;

import 'dart:math' as math;

import '../assets/mc_model_json.dart';
import '../assets/mc_model_resolver.dart';
import 'mc_mesh.dart';

const double mcShadeUp = 1.0;
const double mcShadeDown = 0.5;
const double mcShadeNorthSouth = 0.8;
const double mcShadeEastWest = 0.6;

const double _degToRad = math.pi / 180;

double mcShadeFor(String face) => switch (face) {
  'up' => mcShadeUp,
  'down' => mcShadeDown,
  'north' || 'south' => mcShadeNorthSouth,
  _ => mcShadeEastWest,
};

McMesh mcMeshElements(
  McResolvedModel model, {
  required McUvLookup uv,
  required McTintLookup tint,
  bool Function(String face)? cull,
}) {
  final McMeshBuilder builder = McMeshBuilder();
  for (final McResolvedElement element in model.elements) {
    mcAppendElement(builder, element, uv: uv, tint: tint, cull: cull);
  }
  return builder.build();
}

void mcAppendElement(
  McMeshBuilder builder,
  McResolvedElement element, {
  required McUvLookup uv,
  required McTintLookup tint,
  bool Function(String face)? cull,
}) {
  final List<double> a = <double>[for (final double v in element.from) v / 16];
  final List<double> b = <double>[for (final double v in element.to) v / 16];
  for (final MapEntry<String, McResolvedFace> entry in element.faces.entries) {
    final String face = entry.key;
    if (cull != null && cull(face)) continue;
    final List<List<double>> corners = _corners(face, a, b);
    if (element.rotation != null) {
      for (int i = 0; i < 4; i++) {
        corners[i] = _rotate(corners[i], element.rotation!);
      }
    }
    final McUvRect rect = uv(entry.value.texture) ?? McUvRect.missing;
    builder.quad(
      corners,
      _uvCorners(rect, entry.value.uv, entry.value.rotation),
      element.shade ? mcShadeFor(face) : 1.0,
      tint(entry.value.tintIndex),
    );
  }
}

/// Corner order per face: top-left, top-right, bottom-right, bottom-left as
/// seen from outside the block, so `uv[0]` is the texture's top-left. That
/// order runs clockwise from outside, and it is the reverse of the cycle
/// `FaceInfo` walks in the client, which is why [_uvCorners] has to negate
/// the face's quarter turns.
List<List<double>> _corners(String face, List<double> a, List<double> b) {
  final double x0 = a[0], y0 = a[1], z0 = a[2];
  final double x1 = b[0], y1 = b[1], z1 = b[2];
  return switch (face) {
    'up' => <List<double>>[[x0, y1, z0], [x1, y1, z0], [x1, y1, z1], [x0, y1, z1]],
    'down' => <List<double>>[[x0, y0, z1], [x1, y0, z1], [x1, y0, z0], [x0, y0, z0]],
    'north' => <List<double>>[[x1, y1, z0], [x0, y1, z0], [x0, y0, z0], [x1, y0, z0]],
    'south' => <List<double>>[[x0, y1, z1], [x1, y1, z1], [x1, y0, z1], [x0, y0, z1]],
    'west' => <List<double>>[[x0, y1, z0], [x0, y1, z1], [x0, y0, z1], [x0, y0, z0]],
    'east' => <List<double>>[[x1, y1, z1], [x1, y1, z0], [x1, y0, z0], [x1, y0, z1]],
    _ => throw ArgumentError.value(face, 'face'),
  };
}

/// `[u1, v1, u2, v2]` in 0..16 texture pixels mapped into the atlas rect, in
/// corner order, then rotated by quarter turns.
///
/// The client shifts its OWN vertex index (`BlockFaceUV.getShiftedIndex`:
/// `uv[k] = base[(k + turns) % 4]`) over the cycle `FaceInfo` defines.
/// [_corners] walks that cycle backwards, so the same rotation is a negative
/// shift here; adding the turns would render 90 as the client's 270.
List<List<double>> _uvCorners(McUvRect rect, List<double> uv, int rotation) {
  final double u1 = uv[0] / 16, v1 = uv[1] / 16, u2 = uv[2] / 16, v2 = uv[3] / 16;
  final List<List<double>> mapped = <List<double>>[
    <double>[rect.u(u1), rect.v(v1)],
    <double>[rect.u(u2), rect.v(v1)],
    <double>[rect.u(u2), rect.v(v2)],
    <double>[rect.u(u1), rect.v(v2)],
  ];
  final int turns = ((rotation ~/ 90) % 4 + 4) % 4;
  return <List<double>>[for (int i = 0; i < 4; i++) mapped[(i + 4 - turns) % 4]];
}

List<double> _rotate(List<double> point, McRotationJson rotation) {
  final double ox = rotation.origin[0] / 16;
  final double oy = rotation.origin[1] / 16;
  final double oz = rotation.origin[2] / 16;
  double x = point[0] - ox, y = point[1] - oy, z = point[2] - oz;
  final double angle = rotation.angle * _degToRad;
  final double c = math.cos(angle), s = math.sin(angle);
  final double rescale = rotation.rescale ? 1 / math.cos(angle).abs() : 1;
  switch (rotation.axis) {
    case 'x':
      final double ny = y * c - z * s, nz = y * s + z * c;
      y = ny * rescale;
      z = nz * rescale;
    case 'y':
      final double nx = x * c + z * s, nz = -x * s + z * c;
      x = nx * rescale;
      z = nz * rescale;
    default:
      final double nx = x * c - y * s, ny = x * s + y * c;
      x = nx * rescale;
      y = ny * rescale;
  }
  return <double>[x + ox, y + oy, z + oz];
}

/// Boxes to quads with the vanilla unwrap, in world blocks, feet at y = 0.
///
/// Corners wind clockwise seen from outside, the same convention as
/// `mc_mesh.dart`: the geometric normal points inward, so the GL pass must
/// leave `CULL_FACE` off.
library;

import '../mesh/mc_mesh.dart';
import '../scene/mc_math.dart';
import 'mc_rig.dart';

const double _feetPx = 24;

McMesh mcMeshRig(McRig rig, {McRigPose? pose, bool overlayOnly = false}) {
  final McMeshBuilder builder = McMeshBuilder();
  final McRigPose p = pose ?? const McRigPose();
  for (final McRigPart part in rig.parts) {
    _part(builder, rig, part, McMat4.identity(), p, overlayOnly);
  }
  return builder.build();
}

void _part(McMeshBuilder builder, McRig rig, McRigPart part, McMat4 parent, McRigPose pose, bool overlayOnly) {
  final McVec3 extra = pose.partRotationsDeg[part.name] ?? McVec3.zero;
  final McVec3 rot = part.rotationDeg + extra;
  McMat4 local = parent
      .multiply(McMat4.translation(part.pivot.x, part.pivot.y, part.pivot.z))
      .multiply(McMat4.rotationZ(rot.z))
      .multiply(McMat4.rotationY(rot.y))
      .multiply(McMat4.rotationX(rot.x));
  if (part.name == 'body' && pose.breathe != 0) {
    local = local.multiply(McMat4.scale(1, 1 + pose.breathe * 0.015, 1));
  }
  if (part.overlay == overlayOnly) {
    for (final McBox box in part.boxes) {
      _box(builder, rig, box, local);
    }
  }
  for (final McRigPart child in part.children) {
    _part(builder, rig, child, local, pose, overlayOnly);
  }
}

void _box(McMeshBuilder builder, McRig rig, McBox box, McMat4 local) {
  final double i = box.inflate;
  final double y0 = box.origin.y - i, z0 = box.origin.z - i;
  final double y1 = box.origin.y + box.size.y + i, z1 = box.origin.z + box.size.z + i;
  // `ModelPart.Cube` mirrors by swapping the two X bounds and keeping every
  // polygon's UV pairing, so the west rect lands on the +X face, the east rect
  // on the -X face and the front's U runs the other way: the box is reflected
  // through its own YZ plane. Winding flips with it, which the two-sided GL
  // pass does not care about.
  final double x0 = box.mirror ? box.origin.x + box.size.x + i : box.origin.x - i;
  final double x1 = box.mirror ? box.origin.x - i : box.origin.x + box.size.x + i;
  final int w = box.size.x.round(), h = box.size.y.round(), d = box.size.z.round();
  final double tw = rig.textureWidth.toDouble(), th = rig.textureHeight.toDouble();
  McUvRect uv(int u, int v, int uw, int vh) => McUvRect(u / tw, v / th, (u + uw) / tw, (v + vh) / th);
  // The client's `Cube` hands the bottom polygon its V bounds reversed
  // (`v0 = v + d`, `v1 = v`), so the underside reads the other way up.
  McUvRect uvFlipV(int u, int v, int uw, int vh) => McUvRect(u / tw, (v + vh) / th, (u + uw) / tw, v / th);
  List<double> world(double x, double y, double z) {
    final McVec3 p = local.transformPoint(McVec3(x, y, z));
    return <double>[p.x / 16 * rig.scale, (_feetPx - p.y) / 16 * rig.scale, -p.z / 16 * rig.scale];
  }

  void face(List<List<double>> corners, McUvRect r, double shade, {bool flipU = false}) {
    final List<List<double>> uvs = flipU
        ? <List<double>>[
            <double>[r.u1, r.v0],
            <double>[r.u0, r.v0],
            <double>[r.u0, r.v1],
            <double>[r.u1, r.v1],
          ]
        : <List<double>>[
            <double>[r.u0, r.v0],
            <double>[r.u1, r.v0],
            <double>[r.u1, r.v1],
            <double>[r.u0, r.v1],
          ];
    builder.quad(corners, uvs, shade, const <double>[1, 1, 1]);
  }

  // Vanilla unwrap (`ModelPart.Cube`): top at (u+d, v), bottom at (u+d+w, v)
  // with its V reversed, then the row at v+d: west (u, d wide), north (u+d,
  // w), east (u+d+w, d), south (u+2d+w, w). West is min X, which is the
  // entity's right (`HumanoidModel` puts right_arm at x = -5), so the skin's
  // first side rect belongs to the min-X face, not the max-X one. The client
  // hands each side polygon its first corner the larger U, hence `flipU`.
  // Model Z grows toward the viewer, so "north" here is the box's -Z face.
  face(<List<double>>[world(x0, y0, z1), world(x1, y0, z1), world(x1, y0, z0), world(x0, y0, z0)], uv(box.u + d, box.v, w, d), 1.0);
  face(<List<double>>[world(x0, y1, z0), world(x1, y1, z0), world(x1, y1, z1), world(x0, y1, z1)], uvFlipV(box.u + d + w, box.v, w, d), 0.5);
  face(<List<double>>[world(x1, y0, z1), world(x1, y0, z0), world(x1, y1, z0), world(x1, y1, z1)], uv(box.u + d + w, box.v + d, d, h), 0.6, flipU: true);
  face(<List<double>>[world(x1, y0, z0), world(x0, y0, z0), world(x0, y1, z0), world(x1, y1, z0)], uv(box.u + d, box.v + d, w, h), 0.8, flipU: true);
  face(<List<double>>[world(x0, y0, z0), world(x0, y0, z1), world(x0, y1, z1), world(x0, y1, z0)], uv(box.u, box.v + d, d, h), 0.6, flipU: true);
  face(<List<double>>[world(x0, y0, z1), world(x1, y0, z1), world(x1, y1, z1), world(x0, y1, z1)], uv(box.u + 2 * d + w, box.v + d, w, h), 0.8, flipU: true);
}

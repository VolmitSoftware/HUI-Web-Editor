/// Box models with the vanilla UV layout, and the player in particular.
library;

import 'dart:math' as math;

import 'package:gloss_editor/mc/mesh/mc_mesh.dart';
import 'package:gloss_editor/mc/rigs/mc_player_rig.dart';
import 'package:gloss_editor/mc/rigs/mc_rig.dart';
import 'package:gloss_editor/mc/rigs/mc_rig_mesher.dart';
import 'package:gloss_editor/mc/rigs/mc_rigs.dart';
import 'package:gloss_editor/mc/scene/mc_math.dart';
import 'package:test/test.dart';

void main() {
  test('every player box UV rect lies inside a 64x64 skin', () {
    for (final bool slim in <bool>[false, true]) {
      final McRig rig = mcPlayerRig(slim: slim);
      for (final McRigPart part in rig.allParts) {
        for (final McBox box in part.boxes) {
          final double w = box.size.x, h = box.size.y, d = box.size.z;
          expect(box.u + 2 * d + 2 * w, lessThanOrEqualTo(64), reason: part.name);
          expect(box.v + d + h, lessThanOrEqualTo(64), reason: part.name);
        }
      }
    }
  });

  test('the wide and slim players differ only in arm width', () {
    final McRig wide = mcPlayerRig(slim: false);
    final McRig slim = mcPlayerRig(slim: true);
    expect(wide.part('right_arm').boxes.first.size.x, 4);
    expect(slim.part('right_arm').boxes.first.size.x, 3);
    expect(wide.part('head').boxes.first.size.x, 8);
    expect(slim.part('body').boxes.first.size.toList(), <double>[8, 12, 4]);
    expect(wide.part('right_leg').boxes.first.size.toList(), <double>[4, 12, 4]);
  });

  test('overlay layers inflate by the client amounts', () {
    final McRig rig = mcPlayerRig(slim: false);
    expect(rig.part('head').boxes[1].inflate, 0.5);
    expect(rig.part('body').boxes[1].inflate, 0.25);
    expect(rig.part('right_leg').boxes[1].inflate, 0.25);
  });

  test('the player stands 1.875 blocks tall at the client scale', () {
    final McRig rig = mcPlayerRig(slim: false);
    expect(rig.scale, 0.9375);
    final McMesh mesh = mcMeshRig(rig);
    double minY = 99, maxY = -99;
    for (int v = 0; v < mesh.vertexCount; v++) {
      final double y = mesh.positions[v * 3 + 1];
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    expect(minY, closeTo(0, 1e-9));
    expect(maxY, closeTo((32 + 0.5) / 16 * 0.9375, 1e-9));
  });

  test('a box unwraps to six quads and a mirrored box swaps east and west', () {
    // `ModelPart.Cube` mirrors by swapping the box's two X bounds and keeping
    // every polygon's UV pairing: the west rect (u .. u+d) lands on the +X
    // face, the east rect (u+d+w .. u+2d+w) on the -X face, and the front's
    // U runs the other way across X. `HumanoidModel.createMesh` (26.2 jar)
    // builds the zombie's and skeleton's left limbs this way from the right
    // limbs' rects.
    const double w = 4, h = 12, d = 4, texture = 64;
    McRig rig({required bool mirror}) => McRig(
      id: 'test',
      textureWidth: 64,
      textureHeight: 64,
      heightBlocks: 1,
      eyeHeightBlocks: 0.5,
      parts: <McRigPart>[
        McRigPart(
          name: 'a',
          pivot: McVec3.zero,
          boxes: <McBox>[McBox(origin: const McVec3(0, 0, 0), size: const McVec3(w, h, d), u: 16, v: 16, mirror: mirror)],
        ),
      ],
    );
    final McMesh plain = mcMeshRig(rig(mirror: false));
    final McMesh mirrored = mcMeshRig(rig(mirror: true));
    expect(plain.triangleCount, 12);
    expect(mirrored.triangleCount, 12);

    // The quad whose four corners all sit at world x = [at], and its U range.
    (double, double) sideU(McMesh mesh, double at) {
      for (int q = 0; q < mesh.vertexCount ~/ 4; q++) {
        bool flat = true;
        for (int i = 0; i < 4; i++) {
          if ((mesh.positions[(q * 4 + i) * 3] - at).abs() > 1e-9) flat = false;
        }
        if (!flat) continue;
        double lo = 2, hi = -1;
        for (int i = 0; i < 4; i++) {
          final double u = mesh.uvs[(q * 4 + i) * 2];
          lo = math.min(lo, u);
          hi = math.max(hi, u);
        }
        return (lo, hi);
      }
      fail('no quad at x = $at');
    }

    const double west0 = 16 / texture, west1 = (16 + d) / texture;
    const double east0 = (16 + d + w) / texture, east1 = (16 + 2 * d + w) / texture;
    expect(sideU(plain, 0), (west0, west1));
    expect(sideU(plain, w / 16), (east0, east1));
    expect(sideU(mirrored, 0), (east0, east1));
    expect(sideU(mirrored, w / 16), (west0, west1));

    // Front face (model min-Z, world max-Z): unmirrored the smaller U sits at
    // min-X; mirrored, the larger U does.
    double frontU(McMesh mesh, double x) {
      for (int q = 0; q < mesh.vertexCount ~/ 4; q++) {
        bool front = true;
        for (int i = 0; i < 4; i++) {
          if (mesh.positions[(q * 4 + i) * 3 + 2].abs() > 1e-9) front = false;
        }
        if (!front) continue;
        for (int i = 0; i < 4; i++) {
          if ((mesh.positions[(q * 4 + i) * 3] - x).abs() < 1e-9) return mesh.uvs[(q * 4 + i) * 2];
        }
      }
      fail('no front corner at x = $x');
    }

    const double north0 = (16 + d) / texture, north1 = (16 + d + w) / texture;
    expect(frontU(plain, 0), closeTo(north0, 1e-9));
    expect(frontU(plain, w / 16), closeTo(north1, 1e-9));
    expect(frontU(mirrored, 0), closeTo(north1, 1e-9));
    expect(frontU(mirrored, w / 16), closeTo(north0, 1e-9));

    // Same box, same footprint: only the texture is reflected.
    expect(mirrored.positions.toSet(), plain.positions.toSet());
  });

  test('the side rects bind to the client faces and the underside flips V', () {
    // A box with three distinct dimensions, so every rect of the unwrap is a
    // different width: top (u+d, v, w x d), bottom (u+d+w, v, w x d) with its
    // V reversed, then west (u, v+d, d x h), north (u+d, w x h),
    // east (u+d+w, d x h), south (u+2d+w, w x h) -- `ModelPart.Cube`.
    const double w = 8, h = 12, d = 4, texture = 64;
    const McRig rig = McRig(
      id: 'unwrap',
      textureWidth: 64,
      textureHeight: 64,
      heightBlocks: 1,
      eyeHeightBlocks: 0.5,
      parts: <McRigPart>[
        McRigPart(
          name: 'a',
          pivot: McVec3.zero,
          boxes: <McBox>[McBox(origin: McVec3(0, 0, 0), size: McVec3(w, h, d), u: 0, v: 0)],
        ),
      ],
    );
    final McMesh mesh = mcMeshRig(rig);
    expect(mesh.vertexCount, 24);

    List<double> quadAxis(int quad, int axis) => <double>[
      for (int i = 0; i < 4; i++) mesh.positions[(quad * 4 + i) * 3 + axis],
    ];
    List<double> quadU(int quad) => <double>[
      for (int i = 0; i < 4; i++) mesh.uvs[(quad * 4 + i) * 2],
    ];
    List<double> quadV(int quad) => <double>[
      for (int i = 0; i < 4; i++) mesh.uvs[(quad * 4 + i) * 2 + 1],
    ];
    bool flat(List<double> values, double at) =>
        values.every((double v) => (v - at).abs() < 1e-9);

    // Model X survives into world X unchanged, so the two side faces are the
    // quads whose four corners all sit at one end of the X span.
    int minX = -1, maxX = -1, top = -1, bottom = -1;
    for (int q = 0; q < mesh.vertexCount ~/ 4; q++) {
      final List<double> xs = quadAxis(q, 0);
      final List<double> ys = quadAxis(q, 1);
      if (flat(xs, 0)) minX = q;
      if (flat(xs, w / 16)) maxX = q;
      // Model Y is down, so the visual top is the model-y0 face at world
      // (24 - 0) / 16 and the visual bottom is model y1 at (24 - h) / 16.
      if (flat(ys, 24 / 16)) top = q;
      if (flat(ys, (24 - h) / 16)) bottom = q;
    }
    expect(<int>[minX, maxX, top, bottom], everyElement(greaterThanOrEqualTo(0)));

    expect(quadU(minX).reduce(math.min), closeTo(0, 1e-9), reason: 'west starts at u');
    expect(quadU(minX).reduce(math.max), closeTo(d / texture, 1e-9), reason: 'west is d wide');
    expect(quadU(maxX).reduce(math.min), closeTo((d + w) / texture, 1e-9), reason: 'east starts at u+d+w');
    expect(quadU(maxX).reduce(math.max), closeTo((2 * d + w) / texture, 1e-9), reason: 'east is d wide');

    // The top runs v -> v+d down its corner list; the bottom runs the other
    // way, which is the client's reversed V bounds on that polygon.
    expect(quadV(top), <double>[0, 0, d / texture, d / texture]);
    expect(quadV(bottom), <double>[d / texture, d / texture, 0, 0]);
    expect(quadU(top).reduce(math.min), closeTo(d / texture, 1e-9));
    expect(quadU(bottom).reduce(math.min), closeTo((d + w) / texture, 1e-9));

    // The front (min-Z) face is the "north" rect (u+d, v+d, w x h). The
    // mesher's world map is (x, 24-y, -z), so model min-Z ends up at world
    // max-Z, its outward normal facing +Z -- a viewer standing further along
    // +Z and looking back along -Z faces it. This codebase's camera basis is
    // right-handed (`right = forward x up`): looking along -Z with up +Y
    // gives `right = (0,0,-1) x (0,1,0) = (1,0,0)`, world +X. Two people
    // facing each other have right-to-left, so model min-X (`west`, the
    // entity's right per the unwrap above) reads on the VIEWER's left, where
    // a skin's texture is read left to right -- the smaller u lands there.
    // Model max-X (the entity's left) reads on the viewer's right, the
    // larger u. So an unmirrored front face carries the smaller u (`u+d`) at
    // model min-X and the larger u (`u+d+w`) at model max-X.
    int front = -1;
    for (int q = 0; q < mesh.vertexCount ~/ 4; q++) {
      if (flat(quadAxis(q, 2), 0)) front = q;
    }
    expect(front, greaterThanOrEqualTo(0));
    for (int i = 0; i < 4; i++) {
      final double x = mesh.positions[(front * 4 + i) * 3];
      final double u = mesh.uvs[(front * 4 + i) * 2];
      if ((x - 0).abs() < 1e-9) {
        expect(u, closeTo(d / texture, 1e-9), reason: 'front min-X carries the smaller u');
      } else if ((x - w / 16).abs() < 1e-9) {
        expect(u, closeTo((d + w) / texture, 1e-9), reason: 'front max-X carries the larger u');
      }
    }
  });

  test('the idle pose breathes the body and never swings a limb', () {
    final McRig rig = mcPlayerRig(slim: false);
    final McRigPose a = mcIdlePose(rig, 0);
    final McRigPose b = mcIdlePose(rig, 900);
    expect(a.breathe, isNot(b.breathe));
    expect(a.partRotationsDeg['right_arm'], isNull);
  });

  test('the head rig is the head alone, its bottom on the floor', () {
    final McRig rig = mcHeadRig(slim: false);
    expect(rig.heightBlocks, 0.5);
    expect(rig.parts.length, 1);
    expect(rig.part('head').boxes.length, 2);
    expect(rig.part('head').boxes[1].inflate, 0.5);
    expect(identical(mcRigById('player_head', slim: false), null), isFalse);
    final McMesh mesh = mcMeshRig(rig);
    double minY = 99, maxY = -99;
    for (int v = 0; v < mesh.vertexCount; v++) {
      final double y = mesh.positions[v * 3 + 1];
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    // The hat layer inflates half a pixel past the 8 px box on every side.
    expect(minY, closeTo(-0.5 / 16 * 0.9375, 1e-9));
    expect(maxY, closeTo(8.5 / 16 * 0.9375, 1e-9));
  });
}

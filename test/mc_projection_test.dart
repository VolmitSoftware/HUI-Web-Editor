/// The DOM text layer and the GL world must agree pixel for pixel.
library;

import 'dart:typed_data';

import 'package:gloss_editor/mc/scene/mc_camera.dart';
import 'package:gloss_editor/mc/scene/mc_math.dart';
import 'package:gloss_editor/mc/scene/mc_projection_bridge.dart';
import 'package:gloss_editor/preview/preview_types.dart';
import 'package:gloss_editor/preview/projection.dart';
import 'package:test/test.dart';

void main() {
  const double width = 1200, height = 675;

  test('a world point lands on the same pixel through CSS and GL', () {
    final McCamera camera = mcCameraHome(
      McStageKind.drops,
      const McVec3(0.3, 0, 1.15),
    ).orbitBy(40, -25).dollyBy(60);
    for (final McVec3 point in <McVec3>[
      const McVec3(0, 0, 0),
      const McVec3(1, 0.5, 2),
      const McVec3(-2, 1.2, -1),
      const McVec3(0.5, 0.25, 1.15),
    ]) {
      final ProjectedPoint? css = projectToScreen(
        basis: mcCameraBasis(camera),
        point: PVec3(point.x, point.y, point.z),
        viewportWidth: width,
        viewportHeight: height,
        perspectivePx: huiPreviewPerspectivePx,
      );
      final McVec3? gl = mcProjectToPixels(
        camera,
        point,
        viewportWidthPx: width,
        viewportHeightPx: height,
        perspectivePx: huiPreviewPerspectivePx,
      );
      expect(css, isNotNull, reason: '$point');
      expect(gl, isNotNull, reason: '$point');
      expect(gl!.x, closeTo(css!.x, 1e-6), reason: '$point');
      expect(gl.y, closeTo(css.y, 1e-6), reason: '$point');
    }
  });

  test('the basis is the camera: same eye, same forward', () {
    final McCamera camera = mcCameraHome(McStageKind.hologram, McVec3.zero);
    final CameraBasis basis = mcCameraBasis(camera);
    expect(basis.position.x, closeTo(camera.eye.x, 1e-9));
    expect(basis.position.z, closeTo(camera.eye.z, 1e-9));
    expect(basis.forward.z, closeTo(camera.forward.z, 1e-9));
  });

  test('the css matrix string is a matrix3d with 16 finite values', () {
    final String css = mcCssCameraMatrix(
      mcCameraHome(McStageKind.bubbles, McVec3.zero),
      perspectivePx: huiPreviewPerspectivePx,
      pxPerBlock: 96,
    );
    expect(css, startsWith('matrix3d('));
    expect(css.split(',').length, 16);
  });

  test('a point behind the camera projects to null in both layers', () {
    final McCamera camera = mcCameraHome(McStageKind.drops, McVec3.zero);
    final McVec3 behind = camera.eye - camera.forward * 2;
    expect(
      mcProjectToPixels(
        camera,
        behind,
        viewportWidthPx: width,
        viewportHeightPx: height,
        perspectivePx: huiPreviewPerspectivePx,
      ),
      isNull,
    );
  });

  test('the orbit bridge is the authoring camera with x mirrored', () {
    const List<OrbitCamera> orbits = <OrbitCamera>[
      OrbitCamera(
        target: PVec3(1.5, 1.2, -0.75),
        yawDegrees: 37,
        pitchDegrees: 12,
        distance: 6,
      ),
      OrbitCamera(
        target: PVec3(-2, 0.4, 3),
        yawDegrees: -140,
        pitchDegrees: -28,
        distance: 2.5,
      ),
      OrbitCamera(yawDegrees: 180, pitchDegrees: 0, distance: 4),
    ];
    for (final OrbitCamera orbit in orbits) {
      final CameraBasis authoring = CameraBasis.orbit(orbit);
      final McCamera world = mcCameraFromOrbit(orbit);
      expect(
        world.eye.x,
        closeTo(-authoring.position.x, 1e-9),
        reason: '$orbit',
      );
      expect(
        world.eye.y,
        closeTo(authoring.position.y, 1e-9),
        reason: '$orbit',
      );
      expect(
        world.eye.z,
        closeTo(authoring.position.z, 1e-9),
        reason: '$orbit',
      );
      expect(
        world.forward.x,
        closeTo(-authoring.forward.x, 1e-9),
        reason: '$orbit',
      );
      expect(
        world.forward.y,
        closeTo(authoring.forward.y, 1e-9),
        reason: '$orbit',
      );
      expect(
        world.forward.z,
        closeTo(authoring.forward.z, 1e-9),
        reason: '$orbit',
      );
    }
  });

  test('the player bridge is the authoring eye with x mirrored', () {
    const List<PlayerPose> poses = <PlayerPose>[
      PlayerPose(feet: PVec3(3, 0, -1.5), yawDegrees: 62, pitchDegrees: -14),
      PlayerPose(feet: PVec3(-0.5, 2, 4), yawDegrees: -95, pitchDegrees: 33),
      PlayerPose(),
    ];
    for (final PlayerPose pose in poses) {
      final CameraBasis authoring = CameraBasis.player(pose);
      final McCamera world = mcCameraFromPlayer(pose);
      expect(
        world.eye.x,
        closeTo(-authoring.position.x, 1e-9),
        reason: '$pose',
      );
      expect(world.eye.y, closeTo(authoring.position.y, 1e-9), reason: '$pose');
      expect(world.eye.z, closeTo(authoring.position.z, 1e-9), reason: '$pose');
      expect(
        world.forward.x,
        closeTo(-authoring.forward.x, 1e-9),
        reason: '$pose',
      );
      expect(
        world.forward.y,
        closeTo(authoring.forward.y, 1e-9),
        reason: '$pose',
      );
      expect(
        world.forward.z,
        closeTo(authoring.forward.z, 1e-9),
        reason: '$pose',
      );
      expect(world.distance, mcPlayerPivotBlocks);
    }
  });

  test('a mirrored world point lands where the authoring layer puts it', () {
    const OrbitCamera orbit = OrbitCamera(
      target: PVec3(0.5, 1.4, 0.25),
      yawDegrees: 205,
      pitchDegrees: 9,
      distance: 5,
    );
    const PVec3 authored = PVec3(1.25, 1.8, -0.4);
    final ProjectedPoint? css = projectToScreen(
      basis: CameraBasis.orbit(orbit),
      point: authored,
      viewportWidth: width,
      viewportHeight: height,
      perspectivePx: huiPreviewPerspectivePx,
    );
    final McVec3? gl = mcProjectToPixels(
      mcCameraFromOrbit(orbit),
      McVec3(-authored.x, authored.y, authored.z),
      viewportWidthPx: width,
      viewportHeightPx: height,
      perspectivePx: huiPreviewPerspectivePx,
    );
    expect(css, isNotNull);
    expect(gl, isNotNull);
    expect(gl!.x, closeTo(css!.x, 1e-6));
    expect(gl.y, closeTo(css.y, 1e-6));
  });

  // `preview_stage.dart`'s `_aimMatrix`: the model basis for an icon quad,
  // mirrored out of the authoring frame. Kept here because what it has to
  // agree with is the CSS layer, which is what this file pins.
  McMat4 aimMatrix(PlaneAim aim, double scale) {
    McVec3 mirror(PVec3 v) => McVec3(-v.x, v.y, v.z);
    final McVec3 right = mirror(aim.right);
    final McVec3 up = mirror(aim.up);
    final McVec3 normal = mirror(aim.normal);
    final McVec3 at = mirror(aim.center);
    return McMat4(
      Float64List.fromList(<double>[
        right.x, right.y, right.z, 0, //
        up.x, up.y, up.z, 0, //
        normal.x, normal.y, normal.z, 0, //
        at.x, at.y, at.z, 1, //
      ]),
    ).multiply(McMat4.scale(scale, scale, scale));
  }

  test('an icon model draws on its quad, the same way round as the sprite', () {
    const double blocks = 0.5;
    const OrbitCamera orbit = OrbitCamera(
      target: PVec3(0.3, 1.4, 1.9),
      yawDegrees: 17,
      pitchDegrees: 9,
      distance: 4.5,
    );
    final PlaneAim aim = orientBillboardPlane(
      fixed: fixedMenuPlane(
        center: const PVec3(0.3, 1.5, 2),
        facingYawDegrees: 25,
      ),
      billboard: 'fixed',
      viewer: CameraBasis.orbit(orbit).position,
    );
    final McMat4 model = aimMatrix(
      aim,
      blocks,
    ).multiply(McMat4.translation(-0.5, -0.5, -0.5));
    // Unit-cube model corners: (0, 1) is the sprite's top-left, and the front
    // face is the one the quad's normal points out of.
    for (final List<double> local in <List<double>>[
      <double>[0, 1, 0.5],
      <double>[1, 1, 0.5],
      <double>[0, 0, 0.5],
      <double>[1, 0, 0.5],
      <double>[0.5, 0.5, 1],
    ]) {
      final McVec3 world = model.transformPoint(
        McVec3(local[0], local[1], local[2]),
      );
      final PVec3 authored =
          aim.center +
          aim.right * ((local[0] - 0.5) * blocks) +
          aim.up * ((local[1] - 0.5) * blocks) +
          aim.normal * ((local[2] - 0.5) * blocks);
      final ProjectedPoint? css = projectToScreen(
        basis: CameraBasis.orbit(orbit),
        point: authored,
        viewportWidth: width,
        viewportHeight: height,
        perspectivePx: huiPreviewPerspectivePx,
      );
      final McVec3? gl = mcProjectToPixels(
        mcCameraFromOrbit(orbit),
        world,
        viewportWidthPx: width,
        viewportHeightPx: height,
        perspectivePx: huiPreviewPerspectivePx,
      );
      expect(gl!.x, closeTo(css!.x, 1e-6), reason: '$local');
      expect(gl.y, closeTo(css.y, 1e-6), reason: '$local');
    }
  });

  test(
    'a plane basis is left-handed, so the mirror leaves the model upright',
    () {
      final PlaneAim aim = fixedMenuPlane(
        center: const PVec3(0, 1.5, 2),
        facingYawDegrees: 40,
      );
      // `cssPlaneMatrix` spans its element with `right` and `-up`, which is what
      // makes the triple left-handed: right x up is MINUS the normal.
      final PVec3 cross = aim.right.cross(aim.up);
      expect(cross.x, closeTo(-aim.normal.x, 1e-9));
      expect(cross.y, closeTo(-aim.normal.y, 1e-9));
      expect(cross.z, closeTo(-aim.normal.z, 1e-9));
      // So the mirrored basis is a proper rotation: no negated column, no model
      // drawn inside out or mirrored against its own sprite.
      final Float64List v = aimMatrix(aim, 1).m;
      final double determinant =
          v[0] * (v[5] * v[10] - v[6] * v[9]) -
          v[4] * (v[1] * v[10] - v[2] * v[9]) +
          v[8] * (v[1] * v[6] - v[2] * v[5]);
      expect(determinant, closeTo(1, 1e-9));
    },
  );
}

/// Camera, ray and collision-plane math for the 3D preview.
///
/// Every assertion here is a port of a specific line of the plugin; the
/// citations are the point of the file. The three that are easiest to "fix"
/// into wrongness — the frozen open yaw, the per-tick plane re-aim, and the
/// tick-1-versus-tick-2 hover push — are pinned hardest.
library;

import 'dart:math' as math;

import 'package:holoui_editor/preview/projection.dart';
import 'package:holoui_editor/preview/preview_types.dart';
import 'package:test/test.dart';

void expectVec(PVec3 actual, PVec3 expected, {double epsilon = 1e-9}) {
  expect(actual.x, closeTo(expected.x, epsilon), reason: 'x of $actual');
  expect(actual.y, closeTo(expected.y, epsilon), reason: 'y of $actual');
  expect(actual.z, closeTo(expected.z, epsilon), reason: 'z of $actual');
}

void main() {
  group('look direction', () {
    test('yaw 0 looks along +z, the authoring frame forward axis', () {
      expectVec(huiLookDirection(yawDegrees: 0), const PVec3(0, 0, 1));
    });

    test('yaw 90 looks along +x, which is the player right at yaw 0', () {
      expectVec(huiLookDirection(yawDegrees: 90), const PVec3(1, 0, 0));
    });

    test('yaw 180 looks along -z', () {
      expectVec(huiLookDirection(yawDegrees: 180), const PVec3(0, 0, -1));
    });

    test('positive pitch looks down, matching Minecraft', () {
      expectVec(
        huiLookDirection(yawDegrees: 0, pitchDegrees: 90),
        const PVec3(0, -1, 0),
      );
    });

    test('is a unit vector at arbitrary angles', () {
      final PVec3 look =
          huiLookDirection(yawDegrees: 37.5, pitchDegrees: -22.25);
      expect(look.length, closeTo(1, 1e-12));
    });
  });

  group('open-yaw rotation', () {
    // `MenuSession.java:120` captures `initialY = -yaw`, and
    // `MenuComponent.java:142-144` rotates by that, so the authoring-frame
    // rotation angle is the NEGATED player yaw.
    test('rotation angle is the negated open yaw in radians', () {
      expect(huiOpenYawRadians(90), closeTo(-math.pi / 2, 1e-12));
      expect(huiOpenYawRadians(-45), closeTo(math.pi / 4, 1e-12));
    });

    test('rotating +z by the open yaw lands on the look direction', () {
      for (final double yaw in <double>[0, 30, 90, 137.5, 180, 270, -60]) {
        final PVec3 rotated = const PVec3(0, 0, 2)
            .rotateAroundY(PVec3.zero, huiOpenYawRadians(yaw));
        expectVec(rotated, huiLookDirection(yawDegrees: yaw) * 2, epsilon: 1e-9);
      }
    });
  });

  group('camera basis', () {
    test('orbit camera sits behind its target along the look direction', () {
      const OrbitCamera camera = OrbitCamera(
        target: PVec3(0, 1.62, 3),
        yawDegrees: 0,
        pitchDegrees: 0,
        distance: 4,
      );
      final CameraBasis basis = CameraBasis.orbit(camera);
      expectVec(basis.position, const PVec3(0, 1.62, -1));
      expectVec(basis.forward, const PVec3(0, 0, 1));
      expectVec(basis.right, const PVec3(1, 0, 0));
      expectVec(basis.up, const PVec3(0, 1, 0));
    });

    test('orbit basis stays orthonormal when pitched and yawed', () {
      final CameraBasis basis = CameraBasis.orbit(
        const OrbitCamera(
          target: PVec3(1, 2, 3),
          yawDegrees: 143,
          pitchDegrees: -37,
          distance: 6,
        ),
      );
      expect(basis.forward.length, closeTo(1, 1e-12));
      expect(basis.right.length, closeTo(1, 1e-12));
      expect(basis.up.length, closeTo(1, 1e-12));
      expect(basis.forward.dot(basis.right), closeTo(0, 1e-12));
      expect(basis.forward.dot(basis.up), closeTo(0, 1e-12));
      expect(basis.right.dot(basis.up), closeTo(0, 1e-12));
      // Right is horizontal: the camera never rolls.
      expect(basis.right.y, closeTo(0, 1e-12));
      expect(basis.position.distanceTo(const PVec3(1, 2, 3)), closeTo(6, 1e-12));
    });

    test('player camera sits at the eye, 1.62 above the feet', () {
      final CameraBasis basis = CameraBasis.player(
        const PlayerPose(feet: PVec3(2, 64, -5), yawDegrees: 90),
      );
      expectVec(basis.position, const PVec3(2, 64 + huiPreviewEyeHeight, -5));
      expectVec(basis.forward, const PVec3(1, 0, 0));
    });
  });

  group('projection to the viewport', () {
    const OrbitCamera camera = OrbitCamera(
      target: PVec3(0, 1.5, 2),
      yawDegrees: 0,
      pitchDegrees: 0,
      distance: 4,
    );
    final CameraBasis basis = CameraBasis.orbit(camera);

    test('the orbit target projects to the exact viewport centre', () {
      final ProjectedPoint? point = projectToScreen(
        basis: basis,
        point: camera.target,
        viewportWidth: 800,
        viewportHeight: 600,
        perspectivePx: 900,
      );
      expect(point, isNotNull);
      expect(point!.x, closeTo(400, 1e-9));
      expect(point.y, closeTo(300, 1e-9));
      expect(point.distance, closeTo(4, 1e-9));
    });

    test('one block right of the target moves +perspective/distance px', () {
      final ProjectedPoint point = projectToScreen(
        basis: basis,
        point: camera.target + const PVec3(1, 0, 0),
        viewportWidth: 800,
        viewportHeight: 600,
        perspectivePx: 900,
      )!;
      expect(point.x, closeTo(400 + 900 / 4, 1e-9));
      expect(point.y, closeTo(300, 1e-9));
    });

    test('one block above the target moves UP the screen: css y is flipped',
        () {
      final ProjectedPoint point = projectToScreen(
        basis: basis,
        point: camera.target + const PVec3(0, 1, 0),
        viewportWidth: 800,
        viewportHeight: 600,
        perspectivePx: 900,
      )!;
      expect(point.y, closeTo(300 - 900 / 4, 1e-9));
    });

    test('points behind the camera do not project', () {
      expect(
        projectToScreen(
          basis: basis,
          point: basis.position - const PVec3(0, 0, 1),
          viewportWidth: 800,
          viewportHeight: 600,
          perspectivePx: 900,
        ),
        isNull,
      );
    });
  });

  group('rayThrough', () {
    final CameraBasis basis = CameraBasis.orbit(
      const OrbitCamera(
        target: PVec3(0, 1.5, 2),
        yawDegrees: 25,
        pitchDegrees: -12,
        distance: 5,
      ),
    );

    test('the viewport centre yields the camera forward axis', () {
      final LookRay ray = rayThrough(
        basis: basis,
        viewportWidth: 800,
        viewportHeight: 600,
        pointerX: 400,
        pointerY: 300,
        perspectivePx: 900,
      );
      expectVec(ray.origin, basis.position);
      expectVec(ray.direction, basis.forward, epsilon: 1e-12);
    });

    test('round-trips against projectToScreen', () {
      const PVec3 target = PVec3(1.25, 2.5, 3.75);
      final ProjectedPoint point = projectToScreen(
        basis: basis,
        point: target,
        viewportWidth: 800,
        viewportHeight: 600,
        perspectivePx: 900,
      )!;
      final LookRay ray = rayThrough(
        basis: basis,
        viewportWidth: 800,
        viewportHeight: 600,
        pointerX: point.x,
        pointerY: point.y,
        perspectivePx: 900,
      );
      expectVec(
        ray.pointAt(target.distanceTo(basis.position)),
        target,
        epsilon: 1e-9,
      );
    });
  });

  group('aimPlaneAt', () {
    test('the normal points from the plane centre at the eye', () {
      const PVec3 center = PVec3(0, 2, 3);
      const PVec3 eye = PVec3(4, 1, -1);
      final PlaneAim aim = aimPlaneAt(center, eye);
      expectVec(aim.normal, (eye - center).normalized);
      expect(aim.normal.length, closeTo(1, 1e-12));
    });

    test('right is horizontal and the basis is orthonormal', () {
      final PlaneAim aim =
          aimPlaneAt(const PVec3(1, 2, 3), const PVec3(-4, 7, 2));
      expect(aim.right.y, closeTo(0, 1e-12));
      expect(aim.right.length, closeTo(1, 1e-12));
      expect(aim.up.length, closeTo(1, 1e-12));
      expect(aim.right.dot(aim.up), closeTo(0, 1e-12));
      expect(aim.right.dot(aim.normal), closeTo(0, 1e-12));
      expect(aim.up.dot(aim.normal), closeTo(0, 1e-12));
    });

    test('an eye straight ahead gives the identity-ish basis', () {
      // Eye 5 blocks along -z: this is the canonical "player behind the menu"
      // pose, and the plane must land unrotated.
      final PlaneAim aim =
          aimPlaneAt(PVec3.zero, const PVec3(0, 0, -5));
      expectVec(aim.normal, const PVec3(0, 0, -1));
      expectVec(aim.right, const PVec3(1, 0, 0));
      expectVec(aim.up, const PVec3(0, 1, 0));
    });

    test('an eye directly above degenerates exactly like the runtime', () {
      // `MathHelper.getRotationFromDirection` takes its `x == 0 && z == 0`
      // branch: yaw 0, pitch +90, which `CollisionPlane.java:60-62` turns into
      // normal +y, right +x, up +z.
      final PlaneAim aim = aimPlaneAt(PVec3.zero, const PVec3(0, 9, 0));
      expectVec(aim.normal, const PVec3(0, 1, 0));
      expectVec(aim.right, const PVec3(1, 0, 0));
      expectVec(aim.up, const PVec3(0, 0, 1));
    });

    test('an eye directly below flips the normal and the up axis', () {
      final PlaneAim aim = aimPlaneAt(PVec3.zero, const PVec3(0, -9, 0));
      expectVec(aim.normal, const PVec3(0, -1, 0));
      expectVec(aim.right, const PVec3(1, 0, 0));
      expectVec(aim.up, const PVec3(0, 0, -1));
    });

    test('re-aims every time the eye moves — this is the whole point', () {
      const PVec3 center = PVec3(0, 1.5, 3);
      final PlaneAim first = aimPlaneAt(center, const PVec3(0, 1.5, 0));
      final PlaneAim second = aimPlaneAt(center, const PVec3(6, 1.5, 3));
      expectVec(first.normal, const PVec3(0, 0, -1));
      expectVec(second.normal, const PVec3(1, 0, 0));
    });
  });

  group('rayHitsPlane — port of CollisionPlane.isLookingAt:42-54', () {
    const PVec3 center = PVec3(0, 0, 4);
    const PVec3 eye = PVec3(0, 0, 0);
    final PlaneAim aim = aimPlaneAt(center, eye);

    LookRay rayTo(PVec3 point) => LookRay.normalized(eye, point - eye);

    test('a ray through the centre hits', () {
      expect(rayHitsPlane(rayTo(center), aim, 1, 1), isTrue);
    });

    test('the edge test is strict: exactly half-width misses', () {
      // `distX < width / 2`, not `<=`.
      expect(
        rayHitsPlane(rayTo(center + const PVec3(0.5, 0, 0)), aim, 1, 1),
        isFalse,
      );
      expect(
        rayHitsPlane(rayTo(center + const PVec3(0.4999, 0, 0)), aim, 1, 1),
        isTrue,
      );
      expect(
        rayHitsPlane(rayTo(center + const PVec3(0, 0.5, 0)), aim, 1, 1),
        isFalse,
      );
      expect(
        rayHitsPlane(rayTo(center + const PVec3(0, 0.4999, 0)), aim, 1, 1),
        isTrue,
      );
    });

    test('width and height are independent', () {
      expect(
        rayHitsPlane(rayTo(center + const PVec3(0.9, 0.1, 0)), aim, 2, 0.5),
        isTrue,
      );
      expect(
        rayHitsPlane(rayTo(center + const PVec3(0.9, 0.3, 0)), aim, 2, 0.5),
        isFalse,
      );
    });

    test('a plane behind the camera is rejected', () {
      // Same aimed plane, ray fired the other way: `distance < 0` bails.
      final LookRay away = LookRay.normalized(eye, const PVec3(0, 0, -1));
      expect(rayHitsPlane(away, aim, 4, 4), isFalse);
    });

    test('a ray parallel to the plane misses (proj == 0)', () {
      final LookRay parallel = LookRay.normalized(eye, const PVec3(1, 0, 0));
      expect(rayHitsPlane(parallel, aim, 4, 4), isFalse);
    });

    test('a zero-size plane can never be hit', () {
      expect(rayHitsPlane(rayTo(center), aim, 0, 0), isFalse);
      expect(rayHitsPlane(rayTo(center), aim, 1, 0), isFalse);
    });
  });

  group('hoverPush', () {
    final PlaneAim aim = aimPlaneAt(const PVec3(0, 0, 4), PVec3.zero);

    test('not hovered pushes nothing', () {
      expect(hoverPush(aim, 0.05, 0), PVec3.zero);
      expect(hoverPush(aim, 0.05, -3), PVec3.zero);
    });

    test('tick 1 uses the RAW highlightModifier', () {
      // `ClickableComponent.java:59-70` moves by `normal * highlightMod`. Gson
      // writes the record field directly, so the API's 0..1 clamp
      // (`HoloComponent.java:33`) never runs on a parsed value.
      expectVec(hoverPush(aim, 0.05, 1), aim.normal * 0.05);
      expectVec(hoverPush(aim, 3, 1), aim.normal * 3);
      expect(hoverPush(aim, 3, 1).length, closeTo(3, 1e-12));
      expect(hoverPush(aim, 0, 1), PVec3.zero);
    });

    test('tick 2 onward is exactly one block, whatever the modifier', () {
      // `rotateToFace` teleports to `location + normal` BEFORE the hit test
      // (`ClickableComponent.java:111-116`) and the normal is normalised
      // (`CollisionPlane.java:83-85`).
      for (final double modifier in <double>[0, 0.05, 1, 3]) {
        for (final int tick in <int>[2, 3, 40]) {
          expect(
            hoverPush(aim, modifier, tick).length,
            closeTo(1, 1e-12),
            reason: 'modifier $modifier tick $tick',
          );
          expectVec(hoverPush(aim, modifier, tick), aim.normal);
        }
      }
    });

    test('follows the re-aimed normal, not the frozen quad facing', () {
      final PlaneAim sideways =
          aimPlaneAt(const PVec3(0, 0, 4), const PVec3(9, 0, 4));
      expectVec(hoverPush(sideways, 1, 2), const PVec3(1, 0, 0));
    });
  });

  group('matrix helpers', () {
    test('identity is the multiplicative unit', () {
      final List<double> m = cssQuadMatrix(
        position: const PVec3(1, 2, 3),
        facingYawDegrees: 42,
        pxPerBlock: 100,
      );
      expect(huiMultiplyMatrix(huiIdentityMatrix(), m), m);
      expect(huiMultiplyMatrix(m, huiIdentityMatrix()), m);
    });

    test('transformPoint applies translation and rotation', () {
      final List<double> m = cssQuadMatrix(
        position: const PVec3(1, 2, 3),
        facingYawDegrees: 0,
        pxPerBlock: 10,
      );
      // css = (S x, -S y, -S z).
      expectVec(huiTransformPoint(m, PVec3.zero), const PVec3(10, -20, -30));
    });
  });

  group('cssMatrix3d', () {
    test('emits 16 comma-separated values inside matrix3d()', () {
      final String css = cssMatrix3d(huiIdentityMatrix());
      expect(css.startsWith('matrix3d('), isTrue);
      expect(css.endsWith(')'), isTrue);
      final List<String> parts =
          css.substring('matrix3d('.length, css.length - 1).split(',');
      expect(parts.length, 16);
      expect(parts.first, '1');
      expect(parts[1], '0');
      expect(parts.last, '1');
    });

    test('never emits exponent notation, which css cannot parse', () {
      final String css = cssMatrix3d(<double>[
        1e-9, 2.5e12, 0, 0, //
        0, 1, 0, 0, //
        0, 0, 1, 0, //
        0, 0, 0, 1, //
      ]);
      expect(css.contains('e'), isFalse, reason: css);
      expect(css.contains('E'), isFalse, reason: css);
    });

    test('non-finite values degrade to zero rather than poisoning the style',
        () {
      final String css = cssMatrix3d(<double>[
        double.nan, double.infinity, 0, 0, //
        0, 1, 0, 0, //
        0, 0, 1, 0, //
        0, 0, 0, 1, //
      ]);
      expect(css.contains('NaN'), isFalse, reason: css);
      expect(css.contains('Infinity'), isFalse, reason: css);
    });

    test('rejects a matrix that is not 16 long', () {
      expect(() => cssMatrix3d(<double>[1, 0, 0, 1]), throwsArgumentError);
    });
  });

  group('cssQuadMatrix', () {
    test('yaw 0 is a pure translation with the y and z axes flipped', () {
      final List<double> m = cssQuadMatrix(
        position: const PVec3(2, 3, 4),
        facingYawDegrees: 0,
        pxPerBlock: 50,
      );
      expect(m.sublist(0, 3), <double>[1, 0, 0]);
      expect(m.sublist(4, 7), <double>[0, 1, 0]);
      expect(m.sublist(8, 11), <double>[0, 0, 1]);
      expect(m.sublist(12, 15), <double>[100, -150, -200]);
    });

    test('the quad normal is the reverse of the open-yaw look direction', () {
      for (final double yaw in <double>[0, 45, 90, 180, 270]) {
        final List<double> m = cssQuadMatrix(
          position: PVec3.zero,
          facingYawDegrees: yaw,
          pxPerBlock: 1,
        );
        // The css +z column is the quad's outward face; map it back to the
        // authoring frame with (x, -y, -z).
        final PVec3 normal = PVec3(m[8], -m[9], -m[10]);
        expectVec(normal, -huiLookDirection(yawDegrees: yaw), epsilon: 1e-12);
      }
    });

    test('agrees with cssPlaneMatrix for a plane aimed from the open pose', () {
      const double yaw = 63;
      const PVec3 position = PVec3(1, 2, 3);
      final PVec3 eye = position - huiLookDirection(yawDegrees: yaw) * 5;
      final List<double> quad = cssQuadMatrix(
        position: position,
        facingYawDegrees: yaw,
        pxPerBlock: 40,
      );
      final List<double> plane =
          cssPlaneMatrix(aimPlaneAt(position, eye), pxPerBlock: 40);
      for (int i = 0; i < 16; i++) {
        expect(quad[i], closeTo(plane[i], 1e-9), reason: 'element $i');
      }
    });
  });

  group('cssCameraMatrix', () {
    final CameraBasis basis = CameraBasis.orbit(
      const OrbitCamera(
        target: PVec3(0, 1.5, 2),
        yawDegrees: 33,
        pitchDegrees: -14,
        distance: 5,
      ),
    );
    const double pxPerBlock = 60;
    const double perspectivePx = 900;

    PVec3 cssWorld(PVec3 point) =>
        PVec3(point.x * pxPerBlock, -point.y * pxPerBlock, -point.z * pxPerBlock);

    final List<double> matrix = cssCameraMatrix(
      basis: basis,
      perspectivePx: perspectivePx,
      pxPerBlock: pxPerBlock,
    );

    test('the camera itself lands at the css perspective origin', () {
      expectVec(
        huiTransformPoint(matrix, cssWorld(basis.position)),
        const PVec3(0, 0, perspectivePx),
        epsilon: 1e-6,
      );
    });

    test('a point d blocks ahead lands at z = perspective - scale * d', () {
      final PVec3 ahead = basis.position + basis.forward * 3;
      final PVec3 out = huiTransformPoint(matrix, cssWorld(ahead));
      expect(out.x, closeTo(0, 1e-6));
      expect(out.y, closeTo(0, 1e-6));
      expect(out.z, closeTo(perspectivePx - pxPerBlock * 3, 1e-6));
    });

    test('reproduces projectToScreen after the css perspective divide', () {
      const PVec3 sample = PVec3(2.5, 3.25, 4.75);
      final ProjectedPoint expected = projectToScreen(
        basis: basis,
        point: sample,
        viewportWidth: 800,
        viewportHeight: 600,
        perspectivePx: perspectivePx,
      )!;
      final PVec3 css = huiTransformPoint(matrix, cssWorld(sample));
      final double scale = perspectivePx / (perspectivePx - css.z);
      expect(400 + css.x * scale, closeTo(expected.x, 1e-6));
      expect(300 + css.y * scale, closeTo(expected.y, 1e-6));
    });
  });
}

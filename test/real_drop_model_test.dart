/// The dropped-item presentation model, held against the Gloss source it is
/// ported from.
///
/// `RealDropModelTest.java` is the other half of this file: the cases it
/// asserts there are asserted here, so a change to the plugin's model that
/// this port misses fails in one of the two suites.
library;

import 'dart:math' as math;

import 'package:gloss_editor/logic/real_drop_model.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('a stack grows displays in bands, never one per item', () {
    expect(realDropVisualCount(1, 64, 5), 1);
    expect(realDropVisualCount(16, 64, 5), 2);
    expect(realDropVisualCount(32, 64, 5), 3);
    expect(realDropVisualCount(48, 64, 5), 4);
    expect(realDropVisualCount(64, 64, 5), 5);
    expect(realDropVisualCount(64, 64, 3), 3);
    expect(realDropVisualCount(64, 1, 5), 1);
    expect(realDropVisualCount(64, 64, 99), glossRealDropOffsets.length);
  });

  test('the material shape picks the scale family', () {
    const Map<String, ({bool block, DropModelKind kind})> cases =
        <String, ({bool block, DropModelKind kind})>{
          'STONE': (block: true, kind: DropModelKind.block),
          'OAK_SLAB': (block: true, kind: DropModelKind.thin),
          'WHITE_CARPET': (block: true, kind: DropModelKind.thin),
          'LIGHT_WEIGHTED_PRESSURE_PLATE': (
            block: true,
            kind: DropModelKind.thin,
          ),
          'SNOW': (block: true, kind: DropModelKind.thin),
          'POWDER_SNOW': (block: true, kind: DropModelKind.block),
          'OAK_DOOR': (block: true, kind: DropModelKind.block),
          'RAIL': (block: true, kind: DropModelKind.block),
          'OAK_SIGN': (block: true, kind: DropModelKind.block),
          'TORCH': (block: true, kind: DropModelKind.block),
          'DANDELION': (block: true, kind: DropModelKind.block),
          'IRON_BARS': (block: true, kind: DropModelKind.block),
          'HOPPER': (block: true, kind: DropModelKind.block),
          'OAK_STAIRS': (block: true, kind: DropModelKind.block),
          'DIAMOND_SWORD': (block: false, kind: DropModelKind.flat),
          'TRIDENT': (block: false, kind: DropModelKind.flat),
          'SHIELD': (block: false, kind: DropModelKind.flat),
        };
    cases.forEach((String name, ({bool block, DropModelKind kind}) expected) {
      expect(
        realDropModelKind(name, block: expected.block),
        expected.kind,
        reason: name,
      );
    });

    final GlossRealDropScale scale = GlossRealDropScale();
    expect(realDropScale(DropModelKind.block, scale), scale.defaultScale);
    expect(realDropScale(DropModelKind.thin, scale), scale.thinBlocks);
    expect(realDropScale(DropModelKind.flat, scale), scale.flatItems);
  });

  test('the tumble rate scales every axis by the speed multiplier', () {
    final GlossRealDropMotion base = GlossRealDropMotion(speedMultiplier: 1);
    final GlossRealDropMotion faster = GlossRealDropMotion(
      speedMultiplier: 1.5,
    );
    const ({double x, double y, double z}) units = (x: 0.3, y: -0.4, z: 0.1);
    const ({bool x, bool y, bool z}) signs = (x: false, y: true, z: false);

    final DropAngles slow = realDropSpin(base, units, signs);
    final DropAngles quick = realDropSpin(faster, units, signs);
    expect(quick.x, closeTo(slow.x * 1.5, 1e-9));
    expect(quick.y, closeTo(slow.y * 1.5, 1e-9));
    expect(quick.z, closeTo(slow.z * 1.5, 1e-9));
    expect(slow.y, lessThan(0), reason: 'the direction bit reverses the axis');
    expect(
      slow.x,
      closeTo(base.degreesPerSecondX * (1 + 0.3 * base.variance), 1e-9),
    );
  });

  test(
    'flat items settle broad-side while every block shape lands naturally',
    () {
      final GlossRealDropLanding landing = GlossRealDropLanding();
      const ({double yaw, double tiltX, double tiltZ}) units = (
        yaw: 0.5,
        tiltX: -0.8,
        tiltZ: 0.6,
      );

      expect(realDropLanding(DropModelKind.flat, landing, units).x, 90);
      final DropAngles thin = realDropLanding(
        DropModelKind.thin,
        landing,
        units,
      );
      expect(thin.x.abs(), lessThanOrEqualTo(landing.tiltDegrees));
      expect(thin.z.abs(), lessThanOrEqualTo(landing.tiltDegrees));
      final DropAngles block = realDropLanding(
        DropModelKind.block,
        landing,
        units,
      );
      expect(block.x.abs(), lessThanOrEqualTo(landing.tiltDegrees));
      expect(block.z.abs(), lessThanOrEqualTo(landing.tiltDegrees));
      expect(block.y, closeTo(90, 1e-9), reason: 'randomYaw draws yaw * 180');

      final GlossRealDropLanding fixedYaw = GlossRealDropLanding(
        randomYaw: false,
      );
      expect(realDropLanding(DropModelKind.block, fixedYaw, units).y, 0);
    },
  );

  test('an ordinary cube rests its lowest corner on the surface', () {
    final GlossRealDropScale scale = GlossRealDropScale();
    expect(
      realDropYOffset(
        'STONE',
        DropModelKind.block,
        scale.defaultScale,
        DropRotation.identity,
        grounded: true,
      ),
      closeTo(scale.defaultScale * 0.5, 1e-9),
    );
    expect(
      realDropYOffset(
        'STONE',
        DropModelKind.block,
        scale.defaultScale,
        DropRotation.identity,
        grounded: false,
      ),
      0,
    );
    expect(
      realDropYOffset(
        'DIAMOND_SWORD',
        DropModelKind.flat,
        scale.flatItems,
        DropRotation.identity,
        grounded: true,
      ),
      0,
    );
    // A cube stood on its corner needs more clearance than one on its face.
    final DropRotation tipped = DropRotation.identity
        .rotateX(math.pi / 4)
        .rotateZ(math.pi / 4);
    expect(
      tipped.verticalHalfExtent(0.4),
      greaterThan(DropRotation.identity.verticalHalfExtent(0.4)),
    );
  });

  test('authored Y offsets only lift flat item-display models', () {
    expect(realDropAuthoredYOffset('TRIDENT'), 0.32);
    expect(realDropAuthoredYOffset('SHIELD'), 0.26);
    expect(realDropAuthoredYOffset('WHITE_CARPET'), 0);
    expect(realDropAuthoredYOffset('OAK_SLAB'), 0);
    expect(realDropAuthoredYOffset('RED_BED'), 0);
    expect(realDropAuthoredYOffset('STONE'), 0);
  });

  test('the offset table scales with spread and clamps past its last row', () {
    expect(realDropOffset(0, 0.5), (x: 0.0, y: 0.0, z: 0.0));
    final ({double x, double y, double z}) second = realDropOffset(1, 0.5);
    expect(second.x, closeTo(0.35, 1e-9));
    expect(second.z, closeTo(0.175, 1e-9));
    expect(realDropOffset(99, 1), realDropOffset(4, 1));
    expect(realDropOffset(1, 0), (x: 0.0, y: 0.0, z: 0.0));
  });

  test('rotations compose like the plugin and convert to a CSS matrix', () {
    expect(
      DropRotation.identity.cssMatrix3d(),
      'matrix3d(1.000000, 0.000000, 0.000000, 0, '
      '0.000000, 1.000000, 0.000000, 0, '
      '0.000000, 0.000000, 1.000000, 0, 0, 0, 0, 1)',
    );

    // A flat sprite lies down before it tumbles.
    final DropRotation flat = realDropBaseRotation(DropModelKind.flat);
    expect(flat.m[4], closeTo(0, 1e-9));
    expect(
      realDropBaseRotation(DropModelKind.block).m,
      DropRotation.identity.m,
    );

    // Stack yaw is applied outside the pose, so display 0 keeps it exactly.
    final DropRotation pose = DropRotation.identity.rotateX(0.3);
    expect(realDropIndexedRotation(pose, 0).m, pose.m);
    expect(realDropIndexedRotation(pose, 1).m, isNot(pose.m));

    // The browser's Y points down, so X and Z rotations flip sign in CSS and
    // Y does not.
    final DropRotation yaw = DropRotation.identity.rotateY(0.4);
    expect(yaw.cssMatrix3d(), contains(math.sin(0.4).toStringAsFixed(6)));
  });

  test(
    'flat items keep whichever broad side is already nearest the ground',
    () {
      final DropRotation front = DropRotation.identity
          .rotateY(0.7)
          .rotateX(math.pi * 0.48);
      final DropRotation back = DropRotation.identity
          .rotateY(-0.4)
          .rotateX(math.pi * -0.48);
      final DropRotation alignedFront = realDropBroadFaceAlignedRotation(front);
      final DropRotation alignedBack = realDropBroadFaceAlignedRotation(back);

      expect(front.difference(alignedFront), lessThan(0.08));
      expect(back.difference(alignedBack), lessThan(0.08));
      expect(alignedFront.m[5], closeTo(-1, 1e-9));
      expect(alignedBack.m[5], closeTo(1, 1e-9));
    },
  );
}

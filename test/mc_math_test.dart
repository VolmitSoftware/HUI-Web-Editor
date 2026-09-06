/// Column-major matrices that agree with projection.dart's convention.
library;

import 'dart:math' as math;

import 'package:gloss_editor/mc/scene/mc_math.dart';
import 'package:gloss_editor/preview/projection.dart';
import 'package:test/test.dart';

void main() {
  lerpTests();
  test('identity and translation compose like huiMultiplyMatrix', () {
    final McMat4 t = McMat4.translation(1, 2, 3);
    final McMat4 s = McMat4.scale(2, 2, 2);
    final McMat4 ts = t.multiply(s);
    expect(ts.toList(), huiMultiplyMatrix(t.toList(), s.toList()));
    expect(ts.transformPoint(const McVec3(1, 1, 1)).toList(), <double>[
      3,
      4,
      5,
    ]);
  });

  test('rotationY(90) sends +X to -Z (right-handed, like Minecraft)', () {
    final McVec3 p = McMat4.rotationY(90).transformPoint(const McVec3(1, 0, 0));
    expect(p.x, closeTo(0, 1e-9));
    expect(p.z, closeTo(-1, 1e-9));
  });

  test('lookAt puts the target on the -Z axis', () {
    final McMat4 view = McMat4.lookAt(
      const McVec3(0, 0, 5),
      McVec3.zero,
      McVec3.up,
    );
    final McVec3 p = view.transformPoint(McVec3.zero);
    expect(p.z, closeTo(-5, 1e-9));
    expect(p.x, closeTo(0, 1e-9));
  });

  test('perspective maps near to -1 and far to +1 in clip space', () {
    final McMat4 proj = McMat4.perspective(math.pi / 2, 1, 0.1, 100);
    McVec3 clip(double z) {
      final List<double> m = proj.toList();
      final double cz = m[10] * z + m[14];
      final double w = m[11] * z + m[15];
      return McVec3(0, 0, cz / w);
    }

    expect(clip(-0.1).z, closeTo(-1, 1e-6));
    expect(clip(-100).z, closeTo(1, 1e-6));
  });

  // display pose matrix test lives in mc_display_pose_test.dart
}

void lerpTests() {
  test('lerping a transform keeps the midpoint unit-scaled and turns the short way', () {
    final McMat4 a = McMat4.translation(0, 0, 0).multiply(McMat4.rotationY(0));
    final McMat4 b = McMat4.translation(2, 0, 0).multiply(McMat4.rotationY(90));
    final McMat4 mid = mcLerpTransform(a, b, 0.5);
    // Translation halfway.
    expect(mid.m[12], closeTo(1, 1e-9));
    // Rotation 45 degrees about Y: +X maps to (cos45, 0, -sin45), still unit.
    final McVec3 x = mid.transformPoint(const McVec3(1, 0, 0)) - mid.transformPoint(McVec3.zero);
    expect(x.length, closeTo(1, 1e-9));
    expect(x.x, closeTo(math.cos(math.pi / 4), 1e-9));
    expect(x.z, closeTo(-math.sin(math.pi / 4), 1e-9));
    // Endpoints are exact.
    expect(mcLerpTransform(a, b, 0).toList(), a.toList());
    expect(mcLerpTransform(a, b, 1).toList(), b.toList());
  });

  test('lerping scales linearly and survives a 180 degree turn', () {
    final McMat4 a = McMat4.scale(1, 1, 1);
    final McMat4 b = McMat4.rotationZ(180).multiply(McMat4.scale(3, 3, 3));
    final McMat4 mid = mcLerpTransform(a, b, 0.5);
    final McVec3 x = mid.transformPoint(const McVec3(1, 0, 0));
    expect(x.length, closeTo(2, 1e-9));
  });
}

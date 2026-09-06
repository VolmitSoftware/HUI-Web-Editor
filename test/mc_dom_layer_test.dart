/// Where the text layer puts an element for a world anchor.
library;

import 'dart:math' as math;

import 'package:gloss_editor/components/mc/mc_dom_layer.dart';
import 'package:gloss_editor/mc/scene/mc_camera.dart';
import 'package:gloss_editor/mc/scene/mc_math.dart';
import 'package:test/test.dart';

void main() {
  test('the camera transform is a matrix3d', () {
    final String css = mcDomCameraTransform(mcCameraHome(McStageKind.hologram, McVec3.zero));
    expect(css, startsWith('matrix3d('));
  });

  test('billboard modes parse like the plugin spells them', () {
    expect(McBillboardMode.parse('CENTER'), McBillboardMode.center);
    expect(McBillboardMode.parse('vertical'), McBillboardMode.vertical);
    expect(McBillboardMode.parse('nonsense'), McBillboardMode.fixed);
  });

  test('an anchor transform ends with the bottom-centre alignment', () {
    final String css = mcDomAnchorTransform(
      camera: mcCameraHome(McStageKind.drops, McVec3.zero),
      position: const McVec3(0, 0.5, 1.15),
      billboard: McBillboardMode.center,
    );
    expect(css, contains('matrix3d('));
    expect(css, endsWith('translate(-50%, -100%)'));
  });

  test('a fixed anchor ignores the camera, a center anchor follows it', () {
    final McCamera a = mcCameraHome(McStageKind.drops, McVec3.zero);
    final McCamera b = a.orbitBy(200, 0);
    final String fixedA = mcDomAnchorTransform(camera: a, position: McVec3.zero, billboard: McBillboardMode.fixed);
    final String fixedB = mcDomAnchorTransform(camera: b, position: McVec3.zero, billboard: McBillboardMode.fixed);
    expect(fixedA, fixedB);
    final String centerA = mcDomAnchorTransform(camera: a, position: McVec3.zero, billboard: McBillboardMode.center);
    final String centerB = mcDomAnchorTransform(camera: b, position: McVec3.zero, billboard: McBillboardMode.center);
    expect(centerA, isNot(centerB));
  });

  test('an anchor\'s local +X projects to the viewer\'s right', () {
    final McCamera camera = mcCameraHome(McStageKind.hologram, McVec3.zero);
    final List<double> matrix = mcDomAnchorMatrix(
      camera: camera,
      position: McVec3.zero,
      billboard: McBillboardMode.center,
    );
    expect(_axis(matrix, 0).dot(camera.right), closeTo(1, 1e-9));
  });

  test('VERTICAL keeps world up', () {
    final List<double> matrix = mcDomAnchorMatrix(
      camera: mcCameraHome(McStageKind.hologram, McVec3.zero).orbitBy(140, 90),
      position: const McVec3(0, 1, 0),
      billboard: McBillboardMode.vertical,
    );
    _expectAxis(_axis(matrix, 1), McVec3.up);
  });

  test('VERTICAL pitches about its horizontal right after facing the viewer', () {
    final McCamera camera = mcCameraHome(McStageKind.hologram, McVec3.zero).orbitBy(140, 90);
    final List<double> upright = mcDomAnchorMatrix(
      camera: camera,
      position: const McVec3(0, 1, 0),
      billboard: McBillboardMode.vertical,
    );
    final List<double> pitched = mcDomAnchorMatrix(
      camera: camera,
      position: const McVec3(0, 1, 0),
      billboard: McBillboardMode.vertical,
      pitchDeg: 30,
    );
    final McVec3 facing = _axis(upright, 2);
    final McVec3 right = _axis(upright, 0);
    final double c = math.cos(30 * math.pi / 180), s = math.sin(30 * math.pi / 180);
    // The yaw-to-viewer right is untouched and still horizontal.
    _expectAxis(_axis(pitched, 0), right);
    expect(right.y, closeTo(0, 1e-9));
    // Positive pitch tips the face down, Minecraft's sign, so the normal
    // rotates from `facing` toward -Y and the up axis leans over the same
    // angle toward the viewer.
    _expectAxis(_axis(pitched, 2), facing * c - McVec3.up * s);
    _expectAxis(_axis(pitched, 1), McVec3.up * c + facing * s);
  });

  test('FIXED faces its yaw and pitch', () {
    final McCamera camera = mcCameraHome(McStageKind.hologram, McVec3.zero);
    _expectAxis(
      _axis(
        mcDomAnchorMatrix(
          camera: camera,
          position: McVec3.zero,
          billboard: McBillboardMode.fixed,
          yawDeg: 90,
        ),
        2,
      ),
      const McVec3(-1, 0, 0),
    );
    _expectAxis(
      _axis(
        mcDomAnchorMatrix(
          camera: camera,
          position: McVec3.zero,
          billboard: McBillboardMode.fixed,
          pitchDeg: 90,
        ),
        2,
      ),
      const McVec3(0, -1, 0),
    );
  });

  test('HORIZONTAL keeps the fixed right', () {
    for (final McCamera camera in <McCamera>[
      mcCameraHome(McStageKind.hologram, McVec3.zero),
      mcCameraHome(McStageKind.drops, McVec3.zero).orbitBy(-220, 60),
    ]) {
      final List<double> matrix = mcDomAnchorMatrix(
        camera: camera,
        position: McVec3.zero,
        billboard: McBillboardMode.horizontal,
      );
      _expectAxis(_axis(matrix, 0), const McVec3(1, 0, 0));
    }
  });
}

/// The world direction of the plate's local axis in [column]. `cssPlaneMatrix`
/// writes every column through the `(x, -y, -z)` flip that undoes the camera
/// matrix's; css +Y additionally points down, so the up column comes out
/// negated.
McVec3 _axis(List<double> matrix, int column) {
  final double sign = column == 1 ? -1 : 1;
  return McVec3(
    matrix[column * 4] * sign,
    -matrix[column * 4 + 1] * sign,
    -matrix[column * 4 + 2] * sign,
  ).normalized;
}

void _expectAxis(McVec3 actual, McVec3 expected) {
  expect(actual.x, closeTo(expected.x, 1e-9));
  expect(actual.y, closeTo(expected.y, 1e-9));
  expect(actual.z, closeTo(expected.z, 1e-9));
}

/// Element cuboids to quads: corner order, UV mapping, shade, rotation.
library;

import 'dart:math' as math;

import 'package:gloss_editor/mc/assets/mc_model_json.dart';
import 'package:gloss_editor/mc/assets/mc_model_resolver.dart';
import 'package:gloss_editor/mc/mesh/mc_element_mesher.dart';
import 'package:gloss_editor/mc/mesh/mc_mesh.dart';
import 'package:gloss_editor/mc/scene/mc_math.dart';
import 'package:test/test.dart';

McResolvedModel _cube({McRotationJson? rotation, bool shade = true}) =>
    McResolvedModel(
      id: 'block/test',
      elements: <McResolvedElement>[
        McResolvedElement(
          from: const <double>[0, 0, 0],
          to: const <double>[16, 16, 16],
          shade: shade,
          rotation: rotation,
          faces: <String, McResolvedFace>{
            for (final String face in <String>['down', 'up', 'north', 'south', 'west', 'east'])
              face: McResolvedFace(
                texture: 'block/stone',
                uv: const <double>[0, 0, 16, 16],
                rotation: 0,
                tintIndex: face == 'up' ? 0 : null,
              ),
          },
        ),
      ],
      textures: const <String, String>{},
      display: const <String, McDisplayTransformJson>{},
      generated: false,
      entityBuiltin: false,
      layers: const <String>[],
    );

McUvRect? _atlas(String id) =>
    id == 'block/stone' ? const McUvRect(0.25, 0.5, 0.375, 0.625) : null;

List<double> _tint(int? index) =>
    index == 0 ? const <double>[0.5, 1, 0.25] : const <double>[1, 1, 1];

McResolvedModel _upFace(List<double> uv, int rotation) => McResolvedModel(
      id: 'block/test',
      elements: <McResolvedElement>[
        McResolvedElement(
          from: const <double>[0, 0, 0],
          to: const <double>[16, 16, 16],
          shade: true,
          faces: <String, McResolvedFace>{
            'up': McResolvedFace(
              texture: 'block/stone',
              uv: uv,
              rotation: rotation,
              tintIndex: null,
            ),
          },
        ),
      ],
      textures: const <String, String>{},
      display: const <String, McDisplayTransformJson>{},
      generated: false,
      entityBuiltin: false,
      layers: const <String>[],
    );

/// The client's rule, spelled out: `BlockFaceUV.getShiftedIndex` reads
/// `base[(k + turns) % 4]` at ITS vertex `k`, over the cycle `FaceInfo`
/// defines, and `getU`/`getV` make that cycle `(u1,v1) (u1,v2) (u2,v2)
/// (u2,v1)`. `_corners` walks the same four positions backwards, so its
/// corner `i` is the client's vertex `(4 - i) % 4`.
List<List<double>> _clientUvs(List<double> uv, int rotation) {
  final double u1 = uv[0] / 16, v1 = uv[1] / 16, u2 = uv[2] / 16, v2 = uv[3] / 16;
  final List<List<double>> base = <List<double>>[
    <double>[u1, v1],
    <double>[u1, v2],
    <double>[u2, v2],
    <double>[u2, v1],
  ];
  final int turns = rotation ~/ 90;
  return <List<double>>[
    for (int i = 0; i < 4; i++)
      <double>[
        _atlas('block/stone')!.u(base[((4 - i) % 4 + turns) % 4][0]),
        _atlas('block/stone')!.v(base[((4 - i) % 4 + turns) % 4][1]),
      ],
  ];
}

void main() {
  test('a full cube is six quads of four vertices and two triangles', () {
    final McMesh mesh = mcMeshElements(_cube(), uv: _atlas, tint: _tint);
    expect(mesh.vertexCount, 24);
    expect(mesh.triangleCount, 12);
    expect(mesh.positions.length, 72);
    expect(mesh.uvs.length, 48);
    expect(mesh.indices.length, 36);
  });

  test('positions are in blocks and every corner touches the unit cube', () {
    final McMesh mesh = mcMeshElements(_cube(), uv: _atlas, tint: _tint);
    for (int i = 0; i < mesh.positions.length; i++) {
      expect(mesh.positions[i], anyOf(closeTo(0, 1e-9), closeTo(1, 1e-9)));
    }
  });

  test('shade follows the face direction, and shade:false lights flat', () {
    final McMesh lit = mcMeshElements(_cube(), uv: _atlas, tint: _tint);
    // Float32List round-trips 0.8 and 0.6 with a tiny error, so compare each
    // expected shade individually rather than by exact set equality.
    final List<double> shades = lit.shades.toSet().toList()..sort();
    expect(shades.length, 4);
    expect(shades[0], closeTo(0.5, 1e-6));
    expect(shades[1], closeTo(0.6, 1e-6));
    expect(shades[2], closeTo(0.8, 1e-6));
    expect(shades[3], closeTo(1.0, 1e-6));
    final McMesh flat = mcMeshElements(_cube(shade: false), uv: _atlas, tint: _tint);
    expect(flat.shades.toSet(), <double>{1.0});
  });

  test('UVs land inside the atlas rect and the tinted face carries its tint', () {
    final McMesh mesh = mcMeshElements(_cube(), uv: _atlas, tint: _tint);
    for (int i = 0; i < mesh.uvs.length; i += 2) {
      expect(mesh.uvs[i], inInclusiveRange(0.25, 0.375));
      expect(mesh.uvs[i + 1], inInclusiveRange(0.5, 0.625));
    }
    int tinted = 0;
    for (int v = 0; v < mesh.vertexCount; v++) {
      if (mesh.tints[v * 3 + 1] == 1 && mesh.tints[v * 3] == 0.5) tinted++;
    }
    expect(tinted, 4);
  });

  test('a missing texture maps to the missing tile instead of throwing', () {
    final McMesh mesh = mcMeshElements(
      _cube(),
      uv: (String id) => null,
      tint: _tint,
    );
    expect(mesh.vertexCount, 24);
    expect(mesh.uvs.every((double v) => v >= 0 && v <= 1), isTrue);
  });

  test('a 45 degree Y rotation with rescale keeps the cross-plane diagonal', () {
    final McMesh mesh = mcMeshElements(
      _cube(
        rotation: const McRotationJson(
          origin: <double>[8, 8, 8],
          axis: 'y',
          angle: 45,
          rescale: true,
        ),
      ),
      uv: _atlas,
      tint: _tint,
    );
    // Rescale stretches X and Z by 1/cos(45), so a corner that was at (1, 1)
    // in XZ lands sqrt(2) * 0.5 * sqrt(2) = 1 from the centre along one axis.
    double maxX = 0;
    for (int v = 0; v < mesh.vertexCount; v++) {
      maxX = math.max(maxX, (mesh.positions[v * 3] - 0.5).abs());
    }
    expect(maxX, closeTo(1, 1e-6));
  });

  test('face rotation turns the UV assignment the way the client turns it', () {
    // An asymmetric rect, so a quarter turn cannot look like the identity.
    const List<double> uv = <double>[0, 0, 8, 16];
    for (final int rotation in <int>[0, 90, 180, 270]) {
      final McMesh mesh = mcMeshElements(_upFace(uv, rotation), uv: _atlas, tint: _tint);
      final List<List<double>> got = <List<double>>[
        for (int i = 0; i < 4; i++) <double>[mesh.uvs[i * 2], mesh.uvs[i * 2 + 1]],
      ];
      final List<List<double>> want = _clientUvs(uv, rotation);
      for (int i = 0; i < 4; i++) {
        expect(got[i][0], closeTo(want[i][0], 1e-9), reason: 'rotation $rotation corner $i u');
        expect(got[i][1], closeTo(want[i][1], 1e-9), reason: 'rotation $rotation corner $i v');
      }
    }
  });

  test('rotation 90 lands (u1, v2) on the corner at (x0, z0)', () {
    // `up` corner 0 is (x0, y1, z0). At rotation 90 the client's shift puts
    // its base entry 1 -- (u1, v2) = (0, 16) px -- there, which on the test
    // atlas rect is (0.25, 0.625). Rotation 270 must put entry 3 there
    // instead: (u2, v1) = (8, 0) px, or (0.3125, 0.5).
    final McMesh at90 = mcMeshElements(_upFace(const <double>[0, 0, 8, 16], 90), uv: _atlas, tint: _tint);
    expect(at90.positions[0], closeTo(0, 1e-9));
    expect(at90.positions[2], closeTo(0, 1e-9));
    expect(at90.uvs[0], closeTo(0.25, 1e-9));
    expect(at90.uvs[1], closeTo(0.625, 1e-9));
    final McMesh at270 = mcMeshElements(_upFace(const <double>[0, 0, 8, 16], 270), uv: _atlas, tint: _tint);
    expect(at270.uvs[0], closeTo(0.3125, 1e-9));
    expect(at270.uvs[1], closeTo(0.5, 1e-9));
  });

  test('culled faces are dropped', () {
    final McMesh mesh = mcMeshElements(
      _cube(),
      uv: _atlas,
      tint: _tint,
      cull: (String face) => face == 'down' || face == 'north',
    );
    expect(mesh.vertexCount, 16);
  });

  test('transformed runs positions through the matrix and shares the rest', () {
    final McMesh mesh = mcMeshElements(_cube(), uv: _atlas, tint: _tint);
    final McMesh moved = mesh.transformed(McMat4.translation(1, 2, 3));
    expect(moved.uvs, same(mesh.uvs));
    expect(moved.shades, same(mesh.shades));
    expect(moved.tints, same(mesh.tints));
    expect(moved.indices, same(mesh.indices));
    // The corner at the origin moves to (1, 2, 3).
    bool foundCorner = false;
    for (int v = 0; v < moved.vertexCount; v++) {
      if (moved.positions[v * 3] == 1 &&
          moved.positions[v * 3 + 1] == 2 &&
          moved.positions[v * 3 + 2] == 3) {
        foundCorner = true;
      }
    }
    expect(foundCorner, isTrue);
  });
}

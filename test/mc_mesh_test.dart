/// Mesh builder, merge and UV rect interpolation.
library;

import 'dart:typed_data';

import 'package:gloss_editor/mc/mesh/mc_mesh.dart';
import 'package:test/test.dart';

McMeshBuilder _unitQuad() {
  final McMeshBuilder builder = McMeshBuilder();
  builder.quad(
    const <List<double>>[
      <double>[0, 1, 0],
      <double>[1, 1, 0],
      <double>[1, 1, 1],
      <double>[0, 1, 1],
    ],
    const <List<double>>[
      <double>[0, 0],
      <double>[1, 0],
      <double>[1, 1],
      <double>[0, 1],
    ],
    0.75,
    const <double>[0.5, 1, 0.25],
  );
  return builder;
}

/// A mesh with [vertices] vertices and no triangles, for the size guard.
McMesh _padded(int vertices) => McMesh(
  positions: Float32List(vertices * 3),
  uvs: Float32List(vertices * 2),
  shades: Float32List(vertices),
  tints: Float32List(vertices * 3),
  indices: Uint16List(0),
);

void main() {
  group('McUvRect', () {
    const McUvRect rect = McUvRect(0.25, 0.5, 0.375, 0.625);

    test('u interpolates across the rect', () {
      expect(rect.u(0), 0.25);
      expect(rect.u(1), 0.375);
      expect(rect.u(0.5), closeTo(0.3125, 1e-12));
    });

    test('v interpolates downward across the rect', () {
      expect(rect.v(0), 0.5);
      expect(rect.v(1), 0.625);
      expect(rect.v(0.5), closeTo(0.5625, 1e-12));
    });

    test('the missing tile is the atlas origin', () {
      expect(McUvRect.missing.u0, 0);
      expect(McUvRect.missing.v0, 0);
      expect(McUvRect.missing.u1, 0);
      expect(McUvRect.missing.v1, 0);
    });
  });

  group('McMeshBuilder', () {
    test('one quad is four vertices and two triangles', () {
      final McMesh mesh = _unitQuad().build();
      expect(mesh.vertexCount, 4);
      expect(mesh.triangleCount, 2);
      expect(mesh.positions.length, 12);
      expect(mesh.uvs.length, 8);
      expect(mesh.shades.length, 4);
      expect(mesh.tints.length, 12);
      expect(mesh.indices, <int>[0, 1, 2, 0, 2, 3]);
      expect(mesh.isEmpty, isFalse);
    });

    test('every vertex of a quad carries the quad shade and tint', () {
      final McMesh mesh = _unitQuad().build();
      expect(mesh.shades.toSet(), <double>{0.75});
      for (int v = 0; v < mesh.vertexCount; v++) {
        expect(mesh.tints[v * 3], 0.5);
        expect(mesh.tints[v * 3 + 1], 1);
        expect(mesh.tints[v * 3 + 2], 0.25);
      }
      expect(mesh.positions.sublist(3, 6), <double>[1, 1, 0]);
      expect(mesh.uvs.sublist(4, 6), <double>[1, 1]);
    });

    test('a second quad starts its indices after the first', () {
      final McMeshBuilder builder = _unitQuad();
      expect(builder.vertexCount, 4);
      builder.quad(
        const <List<double>>[
          <double>[0, 0, 1],
          <double>[1, 0, 1],
          <double>[1, 0, 0],
          <double>[0, 0, 0],
        ],
        const <List<double>>[
          <double>[0, 0],
          <double>[1, 0],
          <double>[1, 1],
          <double>[0, 1],
        ],
        0.5,
        const <double>[1, 1, 1],
      );
      final McMesh mesh = builder.build();
      expect(mesh.vertexCount, 8);
      expect(mesh.triangleCount, 4);
      expect(mesh.indices.sublist(6), <int>[4, 5, 6, 4, 6, 7]);
    });

    test('an empty builder builds the empty mesh shape', () {
      final McMesh mesh = McMeshBuilder().build();
      expect(mesh.vertexCount, 0);
      expect(mesh.triangleCount, 0);
      expect(mesh.isEmpty, isTrue);
      expect(McMesh.empty.isEmpty, isTrue);
      expect(McMesh.empty.vertexCount, 0);
    });
  });

  group('McMesh.merge', () {
    test('offsets indices by the preceding vertex count', () {
      final McMesh a = _unitQuad().build();
      final McMesh b = _unitQuad().build();
      final McMesh merged = McMesh.merge(<McMesh>[a, b]);
      expect(merged.vertexCount, 8);
      expect(merged.triangleCount, 4);
      expect(merged.indices, <int>[0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7]);
      expect(merged.positions.length, 24);
      expect(merged.uvs.length, 16);
      expect(merged.shades.length, 8);
      expect(merged.tints.length, 24);
    });

    test('copies each vertex attribute into its slot', () {
      final McMesh a = _unitQuad().build();
      final McMeshBuilder other = McMeshBuilder();
      other.quad(
        const <List<double>>[
          <double>[2, 3, 4],
          <double>[5, 3, 4],
          <double>[5, 3, 6],
          <double>[2, 3, 6],
        ],
        const <List<double>>[
          <double>[0.1, 0.2],
          <double>[0.3, 0.2],
          <double>[0.3, 0.4],
          <double>[0.1, 0.4],
        ],
        0.6,
        const <double>[0, 0, 1],
      );
      final McMesh merged = McMesh.merge(<McMesh>[a, other.build()]);
      expect(merged.positions.sublist(12, 15), <double>[2, 3, 4]);
      expect(merged.uvs.sublist(8, 10), closeToList(<double>[0.1, 0.2]));
      expect(merged.shades[4], closeTo(0.6, 1e-6));
      expect(merged.tints.sublist(12, 15), <double>[0, 0, 1]);
      expect(merged.shades[0], 0.75);
    });

    test('merging nothing yields an empty mesh', () {
      final McMesh merged = McMesh.merge(const <McMesh>[]);
      expect(merged.isEmpty, isTrue);
      expect(merged.vertexCount, 0);
    });

    test('accepts exactly 65535 vertices', () {
      final McMesh merged = McMesh.merge(<McMesh>[_padded(65535)]);
      expect(merged.vertexCount, 65535);
    });

    test('throws once the total passes 16-bit indices', () {
      expect(
        () => McMesh.merge(<McMesh>[_padded(65535), _unitQuad().build()]),
        throwsArgumentError,
      );
    });
  });
}

/// Float32 storage rounds; compare per element.
Matcher closeToList(List<double> expected) => predicate<List<double>>(
  (List<double> actual) {
    if (actual.length != expected.length) return false;
    for (int i = 0; i < actual.length; i++) {
      if ((actual[i] - expected[i]).abs() > 1e-6) return false;
    }
    return true;
  },
  'close to $expected',
);

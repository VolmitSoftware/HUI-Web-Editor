/// GPU-shaped geometry: flat typed arrays the GL edge uploads as-is and the
/// software rasteriser walks on the VM.
///
/// Per vertex: position xyz (blocks), uv (atlas 0..1), shade (0..1) and tint
/// rgb (0..1). Indices are 16-bit, so one mesh holds at most 65535 vertices;
/// the world patch is meshed per column and merged in chunks to stay under it.
library;

import 'dart:typed_data';

import '../scene/mc_math.dart';

final class McUvRect {
  const McUvRect(this.u0, this.v0, this.u1, this.v1);
  final double u0;
  final double v0;
  final double u1;
  final double v1;

  /// A point inside the rect from texture-pixel fractions (0..1 across the
  /// tile, V downward like the PNG).
  double u(double fraction) => u0 + (u1 - u0) * fraction;
  double v(double fraction) => v0 + (v1 - v0) * fraction;

  /// The magenta-and-black tile every atlas reserves at its origin.
  static const McUvRect missing = McUvRect(0, 0, 0, 0);
}

typedef McUvLookup = McUvRect? Function(String textureId);
typedef McTintLookup = List<double> Function(int? tintIndex);

final class McMesh {
  const McMesh({
    required this.positions,
    required this.uvs,
    required this.shades,
    required this.tints,
    required this.indices,
  });

  static final McMesh empty = McMesh(
    positions: Float32List(0),
    uvs: Float32List(0),
    shades: Float32List(0),
    tints: Float32List(0),
    indices: Uint16List(0),
  );

  final Float32List positions;
  final Float32List uvs;
  final Float32List shades;
  final Float32List tints;
  final Uint16List indices;

  int get vertexCount => shades.length;
  int get triangleCount => indices.length ~/ 3;
  bool get isEmpty => indices.isEmpty;

  static McMesh merge(List<McMesh> meshes) {
    int vertices = 0;
    int indices = 0;
    for (final McMesh mesh in meshes) {
      vertices += mesh.vertexCount;
      indices += mesh.indices.length;
    }
    if (vertices > 65535) {
      throw ArgumentError('merged mesh exceeds 16-bit indices: $vertices');
    }
    final Float32List positions = Float32List(vertices * 3);
    final Float32List uvs = Float32List(vertices * 2);
    final Float32List shades = Float32List(vertices);
    final Float32List tints = Float32List(vertices * 3);
    final Uint16List index = Uint16List(indices);
    int vertexOffset = 0;
    int indexOffset = 0;
    for (final McMesh mesh in meshes) {
      positions.setRange(vertexOffset * 3, vertexOffset * 3 + mesh.positions.length, mesh.positions);
      uvs.setRange(vertexOffset * 2, vertexOffset * 2 + mesh.uvs.length, mesh.uvs);
      shades.setRange(vertexOffset, vertexOffset + mesh.shades.length, mesh.shades);
      tints.setRange(vertexOffset * 3, vertexOffset * 3 + mesh.tints.length, mesh.tints);
      for (int i = 0; i < mesh.indices.length; i++) {
        index[indexOffset + i] = mesh.indices[i] + vertexOffset;
      }
      vertexOffset += mesh.vertexCount;
      indexOffset += mesh.indices.length;
    }
    return McMesh(positions: positions, uvs: uvs, shades: shades, tints: tints, indices: index);
  }

  /// A copy with every position run through [matrix]; UVs, shades and tints
  /// are shared, not copied.
  McMesh transformed(McMat4 matrix) {
    final Float32List out = Float32List(positions.length);
    for (int v = 0; v < vertexCount; v++) {
      final McVec3 p = matrix.transformPoint(
        McVec3(positions[v * 3], positions[v * 3 + 1], positions[v * 3 + 2]),
      );
      out[v * 3] = p.x;
      out[v * 3 + 1] = p.y;
      out[v * 3 + 2] = p.z;
    }
    return McMesh(positions: out, uvs: uvs, shades: shades, tints: tints, indices: indices);
  }
}

final class McMeshBuilder {
  final List<double> _positions = <double>[];
  final List<double> _uvs = <double>[];
  final List<double> _shades = <double>[];
  final List<double> _tints = <double>[];
  final List<int> _indices = <int>[];

  int get vertexCount => _shades.length;

  /// Four corners in winding order (CLOCKWISE seen from outside, so the
  /// geometric normal points inward), four matching `[u, v]` pairs, one shade
  /// and one tint for the whole quad. Every mesher in `lib/mc` follows this
  /// convention, so the GL pass must keep `CULL_FACE` disabled — spec 3.5
  /// wants displays two-sided anyway.
  void quad(
    List<List<double>> corners,
    List<List<double>> uv,
    double shade,
    List<double> tint,
  ) {
    final int base = vertexCount;
    for (int i = 0; i < 4; i++) {
      _positions.addAll(corners[i]);
      _uvs.addAll(uv[i]);
      _shades.add(shade);
      _tints.addAll(tint);
    }
    _indices.addAll(<int>[base, base + 1, base + 2, base, base + 2, base + 3]);
  }

  McMesh build() => McMesh(
    positions: Float32List.fromList(_positions),
    uvs: Float32List.fromList(_uvs),
    shades: Float32List.fromList(_shades),
    tints: Float32List.fromList(_tints),
    indices: Uint16List.fromList(_indices),
  );
}

/// The client's flat-item extrusion: two full faces plus side faces along the
/// alpha edge, merged into runs.
library;

import 'package:gloss_editor/mc/mesh/mc_generated_mesher.dart';
import 'package:gloss_editor/mc/mesh/mc_mesh.dart';
import 'package:test/test.dart';

const McUvRect _rect = McUvRect(0, 0, 1, 1);

List<double> _white(int? index) => const <double>[1, 1, 1];

McListPixels _square(int size, {int inset = 0}) => McListPixels(
  16,
  16,
  <int>[
    for (int y = 0; y < 16; y++)
      for (int x = 0; x < 16; x++)
        (x >= inset && x < inset + size && y >= inset && y < inset + size) ? 255 : 0,
  ],
);

void main() {
  test('an empty layer draws nothing', () {
    final McMesh mesh = mcMeshGenerated(
      <McGeneratedLayer>[McGeneratedLayer(McListPixels(16, 16, List<int>.filled(256, 0)), _rect, null)],
      tint: _white,
    );
    expect(mesh.isEmpty, isTrue);
  });

  test('a full layer is a 1/16-thick slab: front, back and four merged sides', () {
    final McMesh mesh = mcMeshGenerated(
      <McGeneratedLayer>[McGeneratedLayer(_square(16), _rect, null)],
      tint: _white,
    );
    expect(mesh.triangleCount, 12);
    double minZ = 1, maxZ = 0;
    for (int v = 0; v < mesh.vertexCount; v++) {
      final double z = mesh.positions[v * 3 + 2];
      if (z < minZ) minZ = z;
      if (z > maxZ) maxZ = z;
    }
    expect(maxZ - minZ, closeTo(mcGeneratedDepthBlocks, 1e-9));
  });

  test('an 8x8 square in the corner has sides only along its own edge', () {
    final McMesh mesh = mcMeshGenerated(
      <McGeneratedLayer>[McGeneratedLayer(_square(8, inset: 4), _rect, null)],
      tint: _white,
    );
    // front + back + 4 merged edges = 6 quads.
    expect(mesh.triangleCount, 12);
    double minX = 1, maxX = 0;
    for (int v = 0; v < mesh.vertexCount; v++) {
      final double x = mesh.positions[v * 3];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
    }
    // The front and back quads cover the whole 16x16 texture (alpha does the
    // cutout); the sides sit on the square's edge at 4/16 and 12/16.
    expect(minX, closeTo(0, 1e-9));
    expect(maxX, closeTo(1, 1e-9));
    final Set<double> sideXs = <double>{};
    for (int v = 0; v < mesh.vertexCount; v++) {
      final double x = mesh.positions[v * 3];
      if (x > 0 && x < 1) sideXs.add((x * 16).roundToDouble());
    }
    expect(sideXs, <double>{4, 12});
  });

  test('a checkerboard produces one side quad per exposed pixel edge', () {
    final McListPixels checker = McListPixels(
      16,
      16,
      <int>[
        for (int y = 0; y < 16; y++)
          for (int x = 0; x < 16; x++) (x + y).isEven ? 255 : 0,
      ],
    );
    final McMesh mesh = mcMeshGenerated(
      <McGeneratedLayer>[McGeneratedLayer(checker, _rect, null)],
      tint: _white,
    );
    // 128 opaque pixels, each with 4 exposed edges, none mergeable: 512 side
    // quads plus front and back.
    expect(mesh.triangleCount, (512 + 2) * 2);
  });

  test('layers keep their order and their tint', () {
    final McMesh mesh = mcMeshGenerated(
      <McGeneratedLayer>[
        McGeneratedLayer(_square(16), _rect, null),
        McGeneratedLayer(_square(4), _rect, 1),
      ],
      tint: (int? index) => index == 1 ? const <double>[1, 0, 0] : const <double>[1, 1, 1],
    );
    expect(mesh.tints.sublist(mesh.tints.length - 3), <double>[1, 0, 0]);
  });
}

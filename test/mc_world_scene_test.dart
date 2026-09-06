/// The authored world every stage sits in.
library;

import 'dart:convert';
import 'dart:io';

import 'package:gloss_editor/mc/assets/mc_model_resolver.dart';
import 'package:gloss_editor/mc/assets/mc_model_store.dart';
import 'package:gloss_editor/mc/assets/mc_pack_manifest.dart';
import 'package:gloss_editor/mc/mesh/mc_mesh.dart';
import 'package:gloss_editor/mc/scene/mc_world_scene.dart';
import 'package:test/test.dart';

Map<String, Object?> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

/// A [mcWorldTuftHash] step recomputed in exact arithmetic.
typedef _Reference = ({BigInt value, BigInt maxIntermediate, BigInt maxBitwiseOperand});

/// The first twelve tufts and the total, in `x` then `z` order. Locks the
/// scatter down so a change to [mcWorldTuftHash] cannot silently move the
/// grass out from under the committed `world_still.png`.
const List<String> _goldenTufts = <String>[
  '-16,-1', '-16,0', '-16,3', '-15,-10', '-15,-1', '-14,-5',
  '-14,4', '-14,8', '-14,11', '-13,-14', '-13,-5', '-13,5',
];
const int _goldenTuftCount = 85;

final BigInt _twoTo53 = BigInt.two.pow(53);
final BigInt _twoTo31 = BigInt.two.pow(31);

/// [mcWorldTuftHash] transliterated to `BigInt`, which never rounds, plus the
/// bounds every platform has to respect to agree with it.
_Reference _reference(int x, int z) {
  final BigInt mask16 = BigInt.from(0xffff);
  final BigInt mod16 = BigInt.from(0x10000);
  final BigInt mod31 = BigInt.from(0x7fffffff);
  final BigInt mixer = BigInt.from(0x27d4eb2d);
  BigInt widest = BigInt.zero;
  BigInt widestBitwise = BigInt.zero;
  BigInt product(BigInt a, BigInt b) {
    final BigInt p = a * b;
    if (p > widest) widest = p;
    return p;
  }

  BigInt bitwise(BigInt a) {
    if (a > widestBitwise) widestBitwise = a;
    return a;
  }

  final BigInt sum = product(BigInt.from(x) & mask16, BigInt.from(0x9e37)) +
      product(BigInt.from(z) & mask16, BigInt.from(0x85eb));
  if (sum > widest) widest = sum;
  BigInt h = sum % mod16;
  h = product(bitwise(h) ^ (h >> 7), mixer) % mod31;
  final BigInt reduced = (bitwise(h) ^ (h >> 15)) % mod16;
  h = product(reduced, mixer) % mod31;
  return (
    value: bitwise(h) ^ (h >> 16),
    maxIntermediate: widest,
    maxBitwiseOperand: widestBitwise,
  );
}

void main() {
  final McWorldScene world = McWorldScene.standard;

  test('the patch is grass on dirt on stone with an open near edge', () {
    expect(world.blockAt(0, 0, 0), 'grass_block');
    expect(world.blockAt(0, -1, 0), 'dirt');
    expect(world.blockAt(0, -3, 0), 'stone');
    expect(world.blockAt(0, 1, 0), isNull);
    expect(world.blockAt(0, 0, 16), isNull);
    expect(world.blockAt(0, 0, 1), 'grass_block');
    expect(world.blockAt(0, 0, 2), 'gravel');
    expect(world.blockAt(-1, 0, 8), 'gravel');
    expect(world.blockAt(-2, 0, 8), 'dirt_path');
  });

  test('the tree, flowers, torch and pool are where the spec puts them', () {
    expect(world.blockAt(-6, 1, -5), 'oak_log');
    expect(world.blockAt(-6, 5, -5), 'oak_log');
    expect(world.blockAt(-6, 6, -5), 'oak_leaves');
    expect(world.blockAt(-4, 5, -7), 'oak_leaves');
    expect(world.blockAt(-8, 7, -7), isNull, reason: 'trimmed crown corner');
    expect(world.blockAt(4, 1, -3), 'poppy');
    expect(world.blockAt(-4, 1, 3), 'dandelion');
    expect(world.blockAt(3, 1, 8), 'torch');
    expect(world.blockAt(7, 0, 5), isNull, reason: 'pool is water, drawn as a plane');
    expect(world.blockAt(7, -1, 5), 'dirt');
  });

  test('short grass is deterministic and sparse', () {
    int grass = 0, tiles = 0;
    for (int x = -16; x < 16; x++) {
      for (int z = -16; z < 16; z++) {
        if (world.blockAt(x, 0, z) != 'grass_block') continue;
        tiles++;
        if (world.blockAt(x, 1, z) == 'short_grass') grass++;
      }
    }
    expect(grass, inInclusiveRange((tiles * 0.06).floor(), (tiles * 0.14).ceil()));
  });

  test('the tuft hash matches exact arithmetic, so dart2js cannot drift', () {
    // `int` is a double on the web: a step above 2^53 rounds there and not on
    // the VM, and a bitwise operand above 2^31 is truncated to 32 bits. Both
    // bounds are checked for every cell the patch actually hashes.
    for (int x = -McWorldScene.halfExtent; x < McWorldScene.halfExtent; x++) {
      for (int z = -McWorldScene.halfExtent; z < McWorldScene.halfExtent; z++) {
        final _Reference reference = _reference(x, z);
        expect(
          BigInt.from(mcWorldTuftHash(x, z)),
          reference.value,
          reason: '$x,$z',
        );
        expect(reference.maxIntermediate < _twoTo53, isTrue, reason: '$x,$z products');
        expect(reference.maxBitwiseOperand < _twoTo31, isTrue, reason: '$x,$z bitwise');
      }
    }
  });

  test('the tufts land on a fixed set of cells', () {
    final List<String> tufts = <String>[
      for (int x = -McWorldScene.halfExtent; x < McWorldScene.halfExtent; x++)
        for (int z = -McWorldScene.halfExtent; z < McWorldScene.halfExtent; z++)
          if (world.blockAt(x, 1, z) == 'short_grass') '$x,$z',
    ];
    expect(tufts.take(12).toList(), _goldenTufts);
    expect(tufts.length, _goldenTuftCount);
  });

  test('the world meshes against the real pack with neighbour culling', () {
    final McPackManifest manifest = McPackManifest.fromJson(_json('web/assets/mc/26.2/pack.json'));
    final McModelResolver resolver = McModelResolver(
      McJsonModelStore.fromJson(_json('web/assets/mc/26.2/models.json')),
    );
    final List<McMesh> chunks = mcMeshWorldChunks(world, resolver, manifest.blocks.uv);
    expect(chunks, isNotEmpty);
    int triangles = 0;
    for (final McMesh chunk in chunks) {
      expect(chunk.vertexCount, lessThanOrEqualTo(65535));
      triangles += chunk.triangleCount;
    }
    // 32x32 top faces alone are 2048 triangles; buried faces must be culled,
    // so the total stays far below six faces per block.
    final int blocks = world.blocks.length;
    expect(triangles, greaterThan(2048));
    expect(triangles, lessThan(blocks * 12 * 0.35));
  });

  test('the surface sits at world y = 0, with the tree crown topping out at 7', () {
    final McPackManifest manifest = McPackManifest.fromJson(_json('web/assets/mc/26.2/pack.json'));
    final McModelResolver resolver = McModelResolver(
      McJsonModelStore.fromJson(_json('web/assets/mc/26.2/models.json')),
    );
    final McMesh mesh = mcMeshWorld(world, resolver, manifest.blocks.uv);

    double globalMaxY = -99;
    for (int v = 0; v < mesh.vertexCount; v++) {
      final double y = mesh.positions[v * 3 + 1];
      if (y > globalMaxY) globalMaxY = y;
    }
    expect(
      globalMaxY,
      lessThanOrEqualTo(7),
      reason: 'the tree crown (block y = 7, world y = 6..7) is the tallest thing in the patch',
    );

    // A 3x3 patch of plain grass at the origin (x, z in -1..1): far from the
    // tree (-6,-5), the torch (3,8), the pool and the path, and explicitly
    // excluded from the short-grass scatter (the tuft loop above skips
    // x.abs() <= 1 && z in -1..3). Every neighbour on every side is also an
    // opaque full block, so every side face culls and only the nine top
    // faces remain -- the surface must sit exactly at world y = 0.
    double patchMaxY = -99;
    int patchVertices = 0;
    for (int v = 0; v < mesh.vertexCount; v++) {
      final double x = mesh.positions[v * 3], y = mesh.positions[v * 3 + 1], z = mesh.positions[v * 3 + 2];
      if (x < -1 || x > 2 || z < -1 || z > 2) continue;
      patchVertices++;
      if (y > patchMaxY) patchMaxY = y;
    }
    expect(patchVertices, greaterThan(0), reason: 'the filter must actually capture the origin patch');
    expect(patchMaxY, closeTo(0, 1e-9));
  });
}

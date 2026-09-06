/// The authored 32x32 patch every stage stands in (spec 3.4).
///
/// Deterministic and small: a grass field with the ground layers cut open at
/// the near edge, a gravel path toward the camera, one oak, a few plants, a
/// torch and a pool. The subject of every stage sits near the origin, on plain
/// grass. The pool is a hole in the ground; the water surface is a scene node
/// (`McWaterNode`) drawn translucent, never a block.
///
/// Meshing culls faces against opaque neighbours (grass, dirt, stone, gravel,
/// path, log, leaves are opaque for culling; plants and the torch are not),
/// per 8x8 column group so no chunk overflows 16-bit indices.
library;

import '../assets/mc_model_json.dart';
import '../assets/mc_model_resolver.dart';
import '../assets/mc_tint.dart';
import '../mesh/mc_element_mesher.dart';
import '../mesh/mc_mesh.dart';
import 'mc_math.dart';

const McVec3 mcWorldSpawn = McVec3(0.5, 0, 0.5);

/// The pool's 7/8 water sits 1/8 below the surface (world y = 0).
const double mcWorldWaterLevel = -0.125;

/// The pool's footprint: the grass blocks removed at x 6..8, z 4..6, so its
/// water plane spans world x 6..9 and z 4..7. The renderer draws that plane
/// as part of the world; the still does not.
abstract final class McWorldPool {
  static const int minX = 6;
  static const int minZ = 4;
  static const int size = 3;
}

int mcWorldKey(int x, int y, int z) => ((x + 64) << 16) | ((y + 64) << 8) | (z + 64);

const Set<String> _opaque = <String>{
  'grass_block', 'dirt', 'stone', 'gravel', 'dirt_path', 'oak_log', 'oak_leaves', 'oak_planks', 'cobblestone',
};

final class McWorldScene {
  McWorldScene._(this.blocks);

  static const int halfExtent = 16;

  static final McWorldScene standard = _build();

  final Map<int, String> blocks;

  String? blockAt(int x, int y, int z) => blocks[mcWorldKey(x, y, z)];

  bool isOpaque(int x, int y, int z) => _opaque.contains(blockAt(x, y, z));

  static McWorldScene _build() {
    final Map<int, String> b = <int, String>{};
    void put(int x, int y, int z, String id) => b[mcWorldKey(x, y, z)] = id;
    for (int x = -halfExtent; x < halfExtent; x++) {
      for (int z = -halfExtent; z < halfExtent; z++) {
        put(x, -3, z, 'stone');
        put(x, -2, z, 'dirt');
        put(x, -1, z, 'dirt');
        put(x, 0, z, 'grass_block');
      }
    }
    // Path: gravel core, dirt_path shoulders, from just past the drop spot.
    for (int z = 2; z < halfExtent; z++) {
      for (int x = -1; x <= 1; x++) {
        put(x, 0, z, 'gravel');
      }
      put(-2, 0, z, 'dirt_path');
      put(2, 0, z, 'dirt_path');
    }
    // Pool: remove the grass; the renderer draws the water plane.
    for (int x = McWorldPool.minX; x < McWorldPool.minX + McWorldPool.size; x++) {
      for (int z = McWorldPool.minZ; z < McWorldPool.minZ + McWorldPool.size; z++) {
        b.remove(mcWorldKey(x, 0, z));
      }
    }
    // Oak: five logs, a crown of 5x4x5 with the eight outer corners trimmed.
    const int tx = -6, tz = -5;
    for (int y = 1; y <= 5; y++) {
      put(tx, y, tz, 'oak_log');
    }
    for (int y = 4; y <= 7; y++) {
      final int radius = y == 7 ? 1 : 2;
      for (int dx = -radius; dx <= radius; dx++) {
        for (int dz = -radius; dz <= radius; dz++) {
          if (dx.abs() == 2 && dz.abs() == 2 && (y == 4 || y == 6)) continue;
          if (b[mcWorldKey(tx + dx, y, tz + dz)] == 'oak_log') continue;
          put(tx + dx, y, tz + dz, 'oak_leaves');
        }
      }
    }
    // Plants by a fixed hash, plus the named flowers and the torch.
    for (int x = -halfExtent; x < halfExtent; x++) {
      for (int z = -halfExtent; z < halfExtent; z++) {
        if (b[mcWorldKey(x, 0, z)] != 'grass_block') continue;
        if (b.containsKey(mcWorldKey(x, 1, z))) continue;
        if (x.abs() <= 1 && z >= -1 && z <= 3) continue;
        if (mcWorldTuftHash(x, z) % 10 == 0) put(x, 1, z, 'short_grass');
      }
    }
    put(4, 1, -3, 'poppy');
    put(-4, 1, 3, 'dandelion');
    put(3, 1, 8, 'torch');
    return McWorldScene._(b);
  }
}

/// Scatter hash for the grass tufts: the same value on the VM and in dart2js.
///
/// Web `int` is a double, so a 64-bit mix rounds in the browser and the still
/// stops matching the live world. Every step here keeps its own bounds: the
/// inputs are masked to 16 bits, every multiplicand is under 2^16 so no
/// product passes 2^47, the wide reductions use `%` (exact on doubles) rather
/// than a mask, and every operand of `^`/`>>` is already under 2^31.
int mcWorldTuftHash(int x, int z) {
  int h = ((x & 0xffff) * 0x9e37 + (z & 0xffff) * 0x85eb) % 0x10000;
  h = ((h ^ (h >> 7)) * 0x27d4eb2d) % 0x7fffffff;
  h = ((h ^ (h >> 15)) % 0x10000 * 0x27d4eb2d) % 0x7fffffff;
  return h ^ (h >> 16);
}

McMesh mcMeshWorld(McWorldScene world, McModelResolver resolver, McUvLookup uv) =>
    McMesh.merge(mcMeshWorldChunks(world, resolver, uv));

List<McMesh> mcMeshWorldChunks(McWorldScene world, McModelResolver resolver, McUvLookup uv) {
  const int chunk = 8;
  final List<McMesh> chunks = <McMesh>[];
  final Map<String, McResolvedModel?> models = <String, McResolvedModel?>{};
  final Map<String, McBlockstateVariantJson?> variants = <String, McBlockstateVariantJson?>{};
  for (int cx = -McWorldScene.halfExtent; cx < McWorldScene.halfExtent; cx += chunk) {
    for (int cz = -McWorldScene.halfExtent; cz < McWorldScene.halfExtent; cz += chunk) {
      final McMeshBuilder builder = McMeshBuilder();
      for (final MapEntry<int, String> entry in world.blocks.entries) {
        final int x = (entry.key >> 16) - 64, y = ((entry.key >> 8) & 0xFF) - 64, z = (entry.key & 0xFF) - 64;
        if (x < cx || x >= cx + chunk || z < cz || z >= cz + chunk) continue;
        final McResolvedModel? model = models.putIfAbsent(entry.value, () => resolver.resolveBlock(entry.value));
        if (model == null) continue;
        final McBlockstateVariantJson? variant = variants.putIfAbsent(entry.value, () => resolver.blockVariant(entry.value));
        // World y = block y - 1: the block map's top grass layer (y = 0)
        // occupies world [-1, 0], so its top face is world y = 0.
        final McMat4 place = McMat4.translation(x.toDouble(), y.toDouble() - 1, z.toDouble())
            .multiply(_variantRotation(variant));
        final McMeshBuilder local = McMeshBuilder();
        for (final McResolvedElement element in model.elements) {
          mcAppendElement(
            local,
            element,
            uv: uv,
            tint: (int? index) => mcTintForBlock(entry.value, index),
            cull: (String face) => _culled(world, x, y, z, element, face),
          );
        }
        final McMesh placed = local.build().transformed(place);
        _append(builder, placed);
      }
      final McMesh mesh = builder.build();
      if (!mesh.isEmpty) chunks.add(mesh);
    }
  }
  return chunks;
}

/// Only a full-cube face touching an opaque neighbour is hidden; a face with
/// no `cullface` (plants, torch) always draws.
bool _culled(McWorldScene world, int x, int y, int z, McResolvedElement element, String face) {
  final McResolvedFace? f = element.faces[face];
  if (f == null || f.cullface == null) return false;
  return switch (f.cullface) {
    'up' => world.isOpaque(x, y + 1, z),
    'down' => world.isOpaque(x, y - 1, z),
    'north' => world.isOpaque(x, y, z - 1),
    'south' => world.isOpaque(x, y, z + 1),
    'west' => world.isOpaque(x - 1, y, z),
    'east' => world.isOpaque(x + 1, y, z),
    _ => false,
  };
}

McMat4 _variantRotation(McBlockstateVariantJson? variant) {
  if (variant == null || (variant.x == 0 && variant.y == 0)) return McMat4.identity();
  return McMat4.translation(0.5, 0.5, 0.5)
      .multiply(McMat4.rotationY(-variant.y.toDouble()))
      .multiply(McMat4.rotationX(-variant.x.toDouble()))
      .multiply(McMat4.translation(-0.5, -0.5, -0.5));
}

void _append(McMeshBuilder builder, McMesh mesh) {
  for (int q = 0; q < mesh.vertexCount; q += 4) {
    builder.quad(
      <List<double>>[
        for (int i = 0; i < 4; i++)
          <double>[mesh.positions[(q + i) * 3], mesh.positions[(q + i) * 3 + 1], mesh.positions[(q + i) * 3 + 2]],
      ],
      <List<double>>[
        for (int i = 0; i < 4; i++) <double>[mesh.uvs[(q + i) * 2], mesh.uvs[(q + i) * 2 + 1]],
      ],
      mesh.shades[q],
      <double>[mesh.tints[q * 3], mesh.tints[q * 3 + 1], mesh.tints[q * 3 + 2]],
    );
  }
}

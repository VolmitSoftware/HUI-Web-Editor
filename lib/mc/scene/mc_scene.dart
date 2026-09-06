/// What a stage asks the renderer to draw, as immutable keyed nodes.
///
/// The renderer diffs consecutive scenes by key: an unchanged node keeps its
/// GPU buffers, a changed one updates its uniforms (or re-meshes when its
/// model id changed), a removed one frees. Equality is structural, so a stage
/// may rebuild the whole list every tick without the renderer re-uploading.
library;

import 'dart:typed_data';

import '../assets/mc_display_pose.dart';
import 'mc_math.dart';

sealed class McSceneNode {
  const McSceneNode(this.key);
  final String key;
}

/// A BlockDisplay: the block's default-state model at [transform].
/// [glowArgb] 0 means no glow outline (same semantics as
/// [McItemModelNode.glowArgb]).
final class McBlockModelNode extends McSceneNode {
  const McBlockModelNode({
    required String key,
    required this.blockId,
    required this.transform,
    this.glowArgb = 0,
  }) : super(key);
  final String blockId;
  final McMat4 transform;
  final int glowArgb;

  @override
  bool operator ==(Object other) =>
      other is McBlockModelNode &&
      other.key == key &&
      other.blockId == blockId &&
      other.glowArgb == glowArgb &&
      _same(other.transform.m, transform.m);

  @override
  int get hashCode => Object.hash(key, blockId, glowArgb, _hash(transform.m));
}

/// An ItemDisplay: the item's resting model at [pose], then [transform].
/// [glowArgb] 0 means no glow outline.
final class McItemModelNode extends McSceneNode {
  const McItemModelNode({
    required String key,
    required this.itemId,
    required this.pose,
    required this.transform,
    this.glowArgb = 0,
  }) : super(key);
  final String itemId;
  final McDisplayPose pose;
  final McMat4 transform;
  final int glowArgb;

  @override
  bool operator ==(Object other) =>
      other is McItemModelNode &&
      other.key == key &&
      other.itemId == itemId &&
      other.pose == pose &&
      other.glowArgb == glowArgb &&
      _same(other.transform.m, transform.m);

  @override
  int get hashCode => Object.hash(key, itemId, pose, glowArgb, _hash(transform.m));
}

/// A box-model entity. [textureId] keys `McPackManifest.entityTextures` or is
/// `player` for the baked skin. [hurt] is 0..1 of the red overlay.
final class McRigNode extends McSceneNode {
  const McRigNode({
    required String key,
    required this.rigId,
    required this.textureId,
    required this.transform,
    required this.poseTimeMs,
    required this.hurt,
    this.capeTextureId,
    this.overlayTextureId,
  }) : super(key);
  final String rigId;
  final String textureId;
  final McMat4 transform;
  final int poseTimeMs;
  final double hurt;
  final String? capeTextureId;

  /// Sheep wool: a second texture drawn on the rig's overlay boxes.
  final String? overlayTextureId;

  @override
  bool operator ==(Object other) =>
      other is McRigNode &&
      other.key == key &&
      other.rigId == rigId &&
      other.textureId == textureId &&
      other.poseTimeMs == poseTimeMs &&
      other.hurt == hurt &&
      other.capeTextureId == capeTextureId &&
      other.overlayTextureId == overlayTextureId &&
      _same(other.transform.m, transform.m);

  @override
  int get hashCode =>
      Object.hash(key, rigId, textureId, poseTimeMs, hurt, capeTextureId, overlayTextureId, _hash(transform.m));
}

/// A camera-facing sprite (catalog entity or item sprite), bottom-centred at
/// [position].
final class McBillboardNode extends McSceneNode {
  const McBillboardNode({
    required String key,
    required this.textureUrl,
    required this.position,
    required this.widthBlocks,
    required this.heightBlocks,
  }) : super(key);
  final String textureUrl;
  final McVec3 position;
  final double widthBlocks;
  final double heightBlocks;

  @override
  bool operator ==(Object other) =>
      other is McBillboardNode &&
      other.key == key &&
      other.textureUrl == textureUrl &&
      other.position == position &&
      other.widthBlocks == widthBlocks &&
      other.heightBlocks == heightBlocks;

  @override
  int get hashCode => Object.hash(key, textureUrl, position, widthBlocks, heightBlocks);
}

final class McShadowNode extends McSceneNode {
  const McShadowNode({
    required String key,
    required this.position,
    required this.radiusBlocks,
    required this.alpha,
  }) : super(key);
  final McVec3 position;
  final double radiusBlocks;
  final double alpha;

  @override
  bool operator ==(Object other) =>
      other is McShadowNode &&
      other.key == key &&
      other.position == position &&
      other.radiusBlocks == radiusBlocks &&
      other.alpha == alpha;

  @override
  int get hashCode => Object.hash(key, position, radiusBlocks, alpha);
}

/// A translucent water plane at [levelBlocks] over the origin.
final class McWaterNode extends McSceneNode {
  const McWaterNode({required String key, required this.levelBlocks, this.halfExtentBlocks = 16})
      : super(key);
  final double levelBlocks;
  final double halfExtentBlocks;

  @override
  bool operator ==(Object other) =>
      other is McWaterNode &&
      other.key == key &&
      other.levelBlocks == levelBlocks &&
      other.halfExtentBlocks == halfExtentBlocks;

  @override
  int get hashCode => Object.hash(key, levelBlocks, halfExtentBlocks);
}

/// A camera-facing particle sprite from the environment map (crit stars).
final class McParticleNode extends McSceneNode {
  const McParticleNode({
    required String key,
    required this.textureId,
    required this.position,
    required this.sizeBlocks,
    required this.alpha,
  }) : super(key);
  final String textureId;
  final McVec3 position;
  final double sizeBlocks;
  final double alpha;

  @override
  bool operator ==(Object other) =>
      other is McParticleNode &&
      other.key == key &&
      other.textureId == textureId &&
      other.position == position &&
      other.sizeBlocks == sizeBlocks &&
      other.alpha == alpha;

  @override
  int get hashCode => Object.hash(key, textureId, position, sizeBlocks, alpha);
}

final class McSceneDiff {
  const McSceneDiff({required this.added, required this.removed, required this.changed});
  final Set<String> added;
  final Set<String> removed;
  final Set<String> changed;
  bool get isEmpty => added.isEmpty && removed.isEmpty && changed.isEmpty;
}

final class McScene {
  McScene(this.nodes, {this.worldVisible = true, this.gridVisible = false})
      : byKey = <String, McSceneNode>{} {
    for (final McSceneNode node in nodes) {
      if (byKey.containsKey(node.key)) {
        throw ArgumentError.value(node.key, 'key', 'duplicate scene node key');
      }
      byKey[node.key] = node;
    }
  }

  static final McScene empty = McScene(const <McSceneNode>[]);

  final List<McSceneNode> nodes;
  final Map<String, McSceneNode> byKey;

  /// False inside a stage that draws nothing but its subject (never used by
  /// the shipped stages; kept for the no-document empty state).
  final bool worldVisible;

  /// The block-grid overlay toggle (hologram, menu preview).
  final bool gridVisible;

  McSceneDiff diff(McScene previous) {
    final Set<String> added = <String>{};
    final Set<String> changed = <String>{};
    for (final McSceneNode node in nodes) {
      final McSceneNode? old = previous.byKey[node.key];
      if (old == null) {
        added.add(node.key);
      } else if (old != node) {
        changed.add(node.key);
      }
    }
    final Set<String> removed = <String>{
      for (final String key in previous.byKey.keys)
        if (!byKey.containsKey(key)) key,
    };
    return McSceneDiff(added: added, removed: removed, changed: changed);
  }
}

bool _same(Float64List a, Float64List b) {
  for (int i = 0; i < 16; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

int _hash(Float64List m) => Object.hashAll(m);

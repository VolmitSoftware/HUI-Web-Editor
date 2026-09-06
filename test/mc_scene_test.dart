/// What a stage hands the renderer, and how the renderer learns what moved.
library;

import 'package:gloss_editor/mc/assets/mc_display_pose.dart';
import 'package:gloss_editor/mc/scene/mc_math.dart';
import 'package:gloss_editor/mc/scene/mc_scene.dart';
import 'package:test/test.dart';

void main() {
  test('nodes are found by key', () {
    final McScene scene = McScene(<McSceneNode>[
      McItemModelNode(key: 'drop-0', itemId: 'apple', pose: McDisplayPose.fixed, transform: McMat4.identity()),
      const McShadowNode(key: 'shadow', position: McVec3.zero, radiusBlocks: 0.3, alpha: 0.4),
    ]);
    expect(scene.byKey['drop-0'], isA<McItemModelNode>());
    expect(scene.byKey['shadow'], isA<McShadowNode>());
  });

  test('a diff names added, removed and changed keys', () {
    final McScene before = McScene(<McSceneNode>[
      McItemModelNode(key: 'a', itemId: 'apple', pose: McDisplayPose.fixed, transform: McMat4.identity()),
      McItemModelNode(key: 'b', itemId: 'apple', pose: McDisplayPose.fixed, transform: McMat4.identity()),
    ]);
    final McScene after = McScene(<McSceneNode>[
      McItemModelNode(key: 'a', itemId: 'apple', pose: McDisplayPose.fixed, transform: McMat4.translation(1, 0, 0)),
      const McShadowNode(key: 'c', position: McVec3.zero, radiusBlocks: 0.3, alpha: 0.4),
    ]);
    final McSceneDiff diff = after.diff(before);
    expect(diff.added, <String>{'c'});
    expect(diff.removed, <String>{'b'});
    expect(diff.changed, <String>{'a'});
  });

  test('an identical node is not a change', () {
    final McScene scene = McScene(<McSceneNode>[
      McRigNode(key: 'p', rigId: 'player', textureId: 'player', transform: McMat4.identity(), poseTimeMs: 0, hurt: 0),
    ]);
    expect(scene.diff(scene).changed, isEmpty);
  });

  test('duplicate keys are rejected', () {
    expect(
      () => McScene(<McSceneNode>[
        const McShadowNode(key: 'x', position: McVec3.zero, radiusBlocks: 1, alpha: 1),
        const McShadowNode(key: 'x', position: McVec3.zero, radiusBlocks: 1, alpha: 1),
      ]),
      throwsArgumentError,
    );
  });

  test('a block model node treats glow like an item model node', () {
    final McBlockModelNode noGlow = McBlockModelNode(key: 'b', blockId: 'stone', transform: McMat4.identity());
    final McBlockModelNode glowing = McBlockModelNode(
      key: 'b',
      blockId: 'stone',
      transform: McMat4.identity(),
      glowArgb: 0xFFFF0000,
    );
    expect(noGlow.glowArgb, 0);
    expect(noGlow, isNot(equals(glowing)));
  });
}

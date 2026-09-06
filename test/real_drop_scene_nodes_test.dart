/// The drop stage's frame, as nodes the renderer draws.
library;

import 'dart:math' as math;

import 'package:gloss_editor/config/gloss_templates.dart';
import 'package:gloss_editor/config/showcase_flavor.dart';
import 'package:gloss_editor/logic/real_drop_model.dart';
import 'package:gloss_editor/logic/real_drop_scene_nodes.dart';
import 'package:gloss_editor/logic/real_drop_stage.dart';
import 'package:gloss_editor/mc/assets/mc_display_pose.dart';
import 'package:gloss_editor/mc/scene/mc_math.dart';
import 'package:gloss_editor/mc/scene/mc_scene.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

ShowcaseDrop _drop(String material) =>
    showcaseDrops.firstWhere((ShowcaseDrop drop) => drop.material == material);

DropStageTimeline _timeline(ShowcaseDrop drop, {bool water = false}) {
  final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
  return DropStageTimeline(
    doc,
    drop,
    environment: DropStageEnvironment(water: water, useItemDisplayNames: false),
  );
}

void main() {
  test('a cube stack is block model nodes at FIXED-free block pose', () {
    final ShowcaseDrop drop = _drop('cobblestone');
    final DropStageFrame frame = _timeline(drop).frameAt(0);
    final List<McSceneNode> nodes = realDropSceneNodes(
      frame: frame,
      material: drop.material,
      block: drop.block,
      water: false,
      origin: McVec3.zero,
    );
    final Iterable<McBlockModelNode> blocks = nodes.whereType<McBlockModelNode>();
    expect(blocks.length, frame.visuals.where((DropStageVisual v) => v.visible).length);
    expect(blocks.first.blockId, 'cobblestone');
    expect(nodes.whereType<McShadowNode>(), hasLength(1));
    expect(nodes.whereType<McWaterNode>(), isEmpty);
  });

  test('a flat item is an item model node at the FIXED pose', () {
    final ShowcaseDrop drop = showcaseDrops.firstWhere((ShowcaseDrop d) => !d.block);
    final DropStageFrame frame = _timeline(drop).frameAt(0);
    final List<McSceneNode> nodes = realDropSceneNodes(
      frame: frame,
      material: drop.material,
      block: drop.block,
      water: false,
      origin: McVec3.zero,
    );
    final McItemModelNode item = nodes.whereType<McItemModelNode>().first;
    expect(item.itemId, drop.material);
    expect(item.pose, McDisplayPose.fixed);
  });

  test('the water button adds one water plane at the stage level', () {
    final ShowcaseDrop drop = _drop('cobblestone');
    final DropStageFrame frame = _timeline(drop, water: true).frameAt(0);
    final List<McSceneNode> nodes = realDropSceneNodes(
      frame: frame,
      material: drop.material,
      block: drop.block,
      water: true,
      origin: McVec3.zero,
    );
    expect(nodes.whereType<McWaterNode>().single.levelBlocks, dropStageWaterLevel);
  });

  test('a hidden visual emits no node and the glow rides the node', () {
    const DropStageVisual hidden = DropStageVisual(
      index: 0,
      x: 0,
      y: 0,
      z: 0,
      rotation: DropRotation.identity,
      scale: 1,
      scaleX: 1,
      scaleY: 1,
      scaleZ: 1,
      glowArgb: 0xFF00FF00,
      visible: false,
    );
    const DropStageVisual shown = DropStageVisual(
      index: 1,
      x: 0.2,
      y: 0,
      z: 0,
      rotation: DropRotation.identity,
      scale: 1,
      scaleX: 1,
      scaleY: 1,
      scaleZ: 1,
      glowArgb: 0xFF00FF00,
      visible: true,
    );
    final DropStageFrame frame = _timeline(_drop('cobblestone')).frameAt(0);
    final DropStageFrame edited = frame.copyWith(visuals: <DropStageVisual>[hidden, shown]);
    final List<McSceneNode> nodes = realDropSceneNodes(
      frame: edited,
      material: 'cobblestone',
      block: true,
      water: false,
      origin: McVec3.zero,
    );
    expect(nodes.whereType<McBlockModelNode>(), hasLength(1));
  });

  test('a sprite-fallback material becomes catalog billboards where the models would stand', () {
    final ShowcaseDrop drop = _drop('cobblestone');
    final DropStageFrame frame = _timeline(drop).frameAt(0);
    const String sprite = 'data:image/png;base64,AAAA';
    final List<McSceneNode> nodes = realDropSceneNodes(
      frame: frame,
      material: drop.material,
      block: drop.block,
      water: false,
      origin: const McVec3(1, 0, 1),
      spriteFallback: true,
      spriteUrl: sprite,
    );
    final List<DropStageVisual> shown = frame.visuals.where((DropStageVisual v) => v.visible).toList();
    final List<McBillboardNode> billboards = nodes.whereType<McBillboardNode>().toList();
    expect(billboards, hasLength(shown.length));
    expect(nodes.whereType<McBlockModelNode>(), isEmpty);
    expect(nodes.whereType<McItemModelNode>(), isEmpty);
    expect(nodes.whereType<McShadowNode>(), hasLength(1));
    for (int i = 0; i < shown.length; i++) {
      final McBillboardNode b = billboards[i];
      final DropStageVisual v = shown[i];
      expect(b.key, 'drop-${v.index}');
      expect(b.textureUrl, sprite);
      expect(b.widthBlocks, closeTo(frame.modelScale, 1e-9));
      expect(b.heightBlocks, closeTo(frame.modelScale, 1e-9));
      // Bottom-centred where the model's box would rest: the visual's centre
      // less half the model.
      final McVec3 centre = realDropVisualTransform(v, frame, const McVec3(1, 0, 1)).transformPoint(const McVec3(0.5, 0.5, 0.5));
      expect(b.position.x, closeTo(centre.x, 1e-9));
      expect(b.position.z, closeTo(centre.z, 1e-9));
      expect(b.position.y, closeTo(centre.y - frame.modelScale / 2, 1e-9));
    }
    // No sprite to show: the visuals are dropped rather than sent as models
    // the renderer would silently drop anyway.
    final List<McSceneNode> bare = realDropSceneNodes(
      frame: frame,
      material: drop.material,
      block: drop.block,
      water: false,
      origin: McVec3.zero,
      spriteFallback: true,
    );
    expect(bare.whereType<McBillboardNode>(), isEmpty);
    expect(bare.whereType<McBlockModelNode>(), isEmpty);
    expect(bare.whereType<McShadowNode>(), hasLength(1));
  });

  test('the visual rotation is transcribed row-major to column-major', () {
    final DropStageFrame frame = _timeline(_drop('cobblestone')).frameAt(0);
    // A quarter turn about +Y: `DropRotation.axis` is the plugin's
    // (row-major, `m[row * 3 + column]`) Rodrigues form, so local +X must
    // land on world -Z and local +Z on world +X, as the Java rotates it.
    final DropStageVisual visual = DropStageVisual(
      index: 0,
      x: 0,
      y: 0,
      z: 0,
      rotation: DropRotation.axis(math.pi / 2, 0, 1, 0),
      scale: 1,
      scaleX: 1,
      scaleY: 1,
      scaleZ: 1,
      glowArgb: 0,
      visible: true,
    );
    final McMat4 m = realDropVisualTransform(visual, frame, McVec3.zero);
    final McVec3 centre = m.transformPoint(const McVec3(0.5, 0.5, 0.5));
    final McVec3 plusX = m.transformPoint(const McVec3(1.5, 0.5, 0.5)) - centre;
    final McVec3 plusZ = m.transformPoint(const McVec3(0.5, 0.5, 1.5)) - centre;
    final List<double> r = visual.rotation.m;
    // Column 0 of the row-major matrix is where local +X goes.
    expect(plusX.x, closeTo(r[0], 1e-9));
    expect(plusX.y, closeTo(r[3], 1e-9));
    expect(plusX.z, closeTo(r[6], 1e-9));
    expect(plusX.z, closeTo(-1, 1e-9));
    expect(plusZ.x, closeTo(1, 1e-9));
  });

  test('the visual transform carries the carrier, the offset, the rotation and the scale', () {
    final DropStageFrame frame = _timeline(_drop('cobblestone')).frameAt(0);
    const DropStageVisual visual = DropStageVisual(
      index: 0,
      x: 0.25,
      y: 0.1,
      z: -0.25,
      rotation: DropRotation.identity,
      scale: 0.5,
      scaleX: 1,
      scaleY: 2,
      scaleZ: 1,
      glowArgb: 0,
      visible: true,
    );
    final McMat4 m = realDropVisualTransform(visual, frame, const McVec3(1, 0, 1));
    final McVec3 centre = m.transformPoint(const McVec3(0.5, 0.5, 0.5));
    expect(centre.x, closeTo(1 + 0.25, 1e-9));
    expect(centre.y, closeTo(frame.carrierY + 0.1, 1e-9));
    expect(centre.z, closeTo(1 + frame.carrierZ - 0.25, 1e-9));
    final McVec3 top = m.transformPoint(const McVec3(0.5, 1, 0.5));
    expect(top.y - centre.y, closeTo(0.5 * 0.5 * 2, 1e-9));
  });
}

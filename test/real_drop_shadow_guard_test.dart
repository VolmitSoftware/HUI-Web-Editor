/// The drop stage's shadow: one disc, on the ground, under the stack, fading
/// as the stack rises. It used to be a CSS radial gradient rotated flat; it is
/// now an [McShadowNode] and the same four intents are asserted against it.
library;

import 'package:gloss_editor/config/gloss_templates.dart';
import 'package:gloss_editor/config/showcase_flavor.dart';
import 'package:gloss_editor/logic/real_drop_scene_nodes.dart';
import 'package:gloss_editor/logic/real_drop_stage.dart';
import 'package:gloss_editor/mc/scene/mc_math.dart';
import 'package:gloss_editor/mc/scene/mc_scene.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

const McVec3 _origin = McVec3(0.5, 0, 0.5);

McShadowNode _shadow(DropStageFrame frame) => realDropSceneNodes(
  frame: frame,
  material: 'cobblestone',
  block: true,
  water: false,
  origin: _origin,
).whereType<McShadowNode>().single;

void main() {
  final ShowcaseDrop drop = showcaseDrops.firstWhere(
    (ShowcaseDrop drop) => drop.material == 'cobblestone',
  );
  final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
  final DropStageTimeline timeline = DropStageTimeline(
    doc,
    drop,
    environment: const DropStageEnvironment(
      water: false,
      useItemDisplayNames: false,
    ),
  );

  test('the shadow is one disc lying on the ground plane', () {
    final McShadowNode shadow = _shadow(timeline.frameAt(0));
    expect(shadow.position.y, _origin.y);
    expect(shadow.radiusBlocks, greaterThan(0));
  });

  test('the shadow tracks the stack forward but never leaves the ground', () {
    for (int ms = 0; ms < timeline.cycleMs; ms += 100) {
      final DropStageFrame frame = timeline.frameAt(ms);
      final McShadowNode shadow = _shadow(frame);
      expect(shadow.position.y, _origin.y, reason: 'at $ms ms');
      expect(shadow.position.x, _origin.x, reason: 'at $ms ms');
      expect(shadow.position.z, _origin.z + frame.carrierZ, reason: 'at $ms ms');
    }
  });

  test('the disc is the model edge, the way the CSS gradient was', () {
    final DropStageFrame frame = timeline.frameAt(0);
    expect(_shadow(frame).radiusBlocks, frame.modelScale * 1.35 / 2);
  });

  test('the shadow fades as the stack rises off it', () {
    DropStageFrame highest = timeline.frameAt(0);
    DropStageFrame lowest = timeline.frameAt(0);
    for (int ms = 0; ms < timeline.cycleMs; ms += 50) {
      final DropStageFrame frame = timeline.frameAt(ms);
      if (frame.carrierY > highest.carrierY) highest = frame;
      if (frame.carrierY < lowest.carrierY) lowest = frame;
    }
    expect(highest.carrierY, greaterThan(lowest.carrierY));
    expect(_shadow(highest).alpha, lessThan(_shadow(lowest).alpha));
    expect(_shadow(highest).alpha, greaterThan(0));
    expect(_shadow(lowest).alpha, lessThanOrEqualTo(0.45));
  });
}

/// The drop stage's timeline: one dropped stack from throw to settle.
library;

import 'dart:convert';
import 'dart:io';

import 'package:gloss_editor/config/gloss_templates.dart';
import 'package:gloss_editor/config/showcase_flavor.dart';
import 'package:gloss_editor/logic/real_drop_model.dart';
import 'package:gloss_editor/logic/real_drop_stage.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

ShowcaseDrop _drop(String material) => showcaseDrops.firstWhere(
  (ShowcaseDrop drop) => drop.material == material,
);

void main() {
  test('every sample stack names a material the sprite catalog ships', () {
    final Map<String, dynamic> catalog =
        jsonDecode(File('web/assets/catalog/items.json').readAsStringSync())
            as Map<String, dynamic>;
    final Set<String> textured = <String>{
      for (final dynamic entry in catalog['materials'] as List<dynamic>)
        if ((entry as Map<String, dynamic>)['texture'] is String)
          entry['key'] as String,
    };
    for (final ShowcaseDrop drop in showcaseDrops) {
      expect(
        drop.material,
        drop.material.toLowerCase(),
        reason: 'registry keys are lower case',
      );
      expect(
        textured,
        contains(drop.material),
        reason:
            '${drop.material} has no sprite, so the stage would draw the '
            'missing-texture tile for it',
      );
      expect(drop.amount, greaterThan(0));
      expect(drop.amount, lessThanOrEqualTo(drop.maxStackSize));
    }
  });

  test('the sample table covers all three model families', () {
    final Set<DropModelKind> kinds = <DropModelKind>{
      for (final ShowcaseDrop drop in showcaseDrops)
        realDropModelKind(drop.registryName, block: drop.block),
    };
    expect(kinds, hasLength(DropModelKind.values.length));
  });

  test('a stack falls, tumbles, then settles into the landing pose', () {
    final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
    final DropStageTimeline stage = DropStageTimeline(doc, _drop('cherry_log'));

    final DropStageFrame thrown = stage.frameAt(0);
    expect(thrown.carrierY, greaterThan(1));
    expect(thrown.grounded, isFalse);
    expect(thrown.settled, isFalse);
    expect(thrown.interpolationTicks, doc.limits.updateIntervalTicks);

    final DropStageFrame settled = stage.frameAt(stage.cycleMs - 200);
    expect(settled.settled, isTrue);
    expect(settled.grounded, isTrue);
    expect(settled.carrierY, 0);
    expect(settled.interpolationTicks, doc.landing.transitionTicks);

    // Mid-flight the pose keeps changing; settled it does not.
    final String early = stage.frameAt(300).visuals.first.rotation
        .cssMatrix3d();
    final String later = stage.frameAt(600).visuals.first.rotation
        .cssMatrix3d();
    expect(early, isNot(later));
    expect(
      stage.frameAt(stage.cycleMs - 400).visuals.first.rotation.cssMatrix3d(),
      settled.visuals.first.rotation.cssMatrix3d(),
    );
  });

  test('the cycle repeats and replays identically', () {
    final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
    final DropStageTimeline first = DropStageTimeline(doc, _drop('feather'));
    final DropStageTimeline second = DropStageTimeline(doc, _drop('feather'));
    for (final int ms in <int>[0, 250, 900, 1800, 3300]) {
      expect(
        first.frameAt(ms).visuals.first.rotation.cssMatrix3d(),
        second.frameAt(ms).visuals.first.rotation.cssMatrix3d(),
        reason: 'at $ms ms',
      );
      expect(
        first.frameAt(ms).carrierY,
        first.frameAt(ms + first.cycleMs).carrierY,
        reason: 'the cycle wraps at $ms ms',
      );
    }
  });

  test('the document decides how many displays a stack grows', () {
    final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
    expect(DropStageTimeline(doc, _drop('sea_lantern')).visualCount, 3);
    expect(DropStageTimeline(doc, _drop('cake')).visualCount, 1);

    doc.limits.maxVisualsPerStack = 5;
    expect(DropStageTimeline(doc, _drop('sea_lantern')).visualCount, 5);
    doc.limits.maxVisualsPerStack = 1;
    expect(DropStageTimeline(doc, _drop('sea_lantern')).visualCount, 1);
  });

  test('turning the tumble off holds the model on its base pose', () {
    final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
    doc.motion.tumble = false;
    final DropStageTimeline stage = DropStageTimeline(doc, _drop('cherry_log'));
    expect(
      stage.frameAt(400).visuals.first.rotation.cssMatrix3d(),
      DropRotation.identity.cssMatrix3d(),
    );
    expect(
      stage.frameAt(900).visuals.first.rotation.cssMatrix3d(),
      DropRotation.identity.cssMatrix3d(),
    );
  });

  test('the label is the shipped name format for the stack', () {
    final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
    final ShowcaseDrop drop = _drop('cookie');
    expect(
      DropStageTimeline(doc, drop).label,
      '&7${drop.amount}x ${drop.displayName}',
    );
  });

  test('the scale family and ground clearance follow the material', () {
    final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
    final DropStageFrame cube = DropStageTimeline(
      doc,
      _drop('cherry_log'),
    ).frameAt(0);
    final DropStageFrame flat = DropStageTimeline(
      doc,
      _drop('feather'),
    ).frameAt(0);
    final DropStageFrame thin = DropStageTimeline(
      doc,
      _drop('oak_slab'),
    ).frameAt(0);
    expect(cube.modelScale, doc.scale.defaultScale);
    expect(flat.modelScale, doc.scale.flatItems);
    expect(thin.modelScale, doc.scale.thinBlocks);

    // A settled cube lifts to rest on the ground; a slab uses its authored
    // offset instead.
    final DropStageTimeline cubeStage = DropStageTimeline(
      doc,
      _drop('cherry_log'),
    );
    expect(
      cubeStage.frameAt(cubeStage.cycleMs - 200).visuals.first.y,
      greaterThan(0),
    );
    final DropStageTimeline slabStage = DropStageTimeline(
      doc,
      _drop('oak_slab'),
    );
    expect(
      slabStage.frameAt(slabStage.cycleMs - 200).visuals.first.y,
      closeTo(0.16, 1e-9),
    );
  });

  test('every sample stack plays a whole cycle without a bad number', () {
    final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
    for (final ShowcaseDrop drop in showcaseDrops) {
      final DropStageTimeline stage = DropStageTimeline(doc, drop);
      expect(stage.cycleMs, greaterThan(1000), reason: drop.material);
      for (int ms = 0; ms < stage.cycleMs; ms += 137) {
        final DropStageFrame frame = stage.frameAt(ms);
        expect(frame.carrierY.isFinite, isTrue, reason: '${drop.material} $ms');
        expect(frame.carrierY, greaterThanOrEqualTo(0));
        expect(frame.visuals, isNotEmpty);
        for (final DropStageVisual visual in frame.visuals) {
          expect(visual.scale, greaterThan(0));
          expect(visual.y.isFinite, isTrue);
          expect(
            visual.rotation.m.every((double value) => value.isFinite),
            isTrue,
            reason: '${drop.material} $ms',
          );
        }
      }
    }
  });
}

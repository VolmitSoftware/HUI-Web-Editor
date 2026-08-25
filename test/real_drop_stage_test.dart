/// The drop stage's timeline: one dropped stack from throw to settle.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

import 'package:gloss_editor/config/gloss_templates.dart';
import 'package:gloss_editor/config/showcase_flavor.dart';
import 'package:gloss_editor/logic/real_drop_model.dart';
import 'package:gloss_editor/logic/real_drop_stage.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

ShowcaseDrop _drop(String material) =>
    showcaseDrops.firstWhere((ShowcaseDrop drop) => drop.material == material);

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
      expect(drop.amount, lessThanOrEqualTo(3));
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

  test('the unattended rotation is one sample stack per model family', () {
    expect(dropStageRotation, hasLength(DropModelKind.values.length));
    final List<DropModelKind> kinds = <DropModelKind>[
      for (int cycle = 0; cycle < dropStageRotation.length; cycle++)
        realDropModelKind(
          dropStageRotationDrop(cycle).registryName,
          block: dropStageRotationDrop(cycle).block,
        ),
    ];
    expect(
      kinds.toSet(),
      DropModelKind.values.toSet(),
      reason: 'a viewer who waits out three cycles must see every shape',
    );
    for (final String material in dropStageRotation) {
      expect(
        showcaseDrops.map((ShowcaseDrop drop) => drop.material),
        contains(material),
        reason: 'the rotation names rows of the sample table, not new stacks',
      );
    }
  });

  test('one completed drop advances the rotation, and it wraps', () {
    expect(dropStageRotationDrop(0).material, dropStageRotation[0]);
    expect(dropStageRotationDrop(1).material, dropStageRotation[1]);
    expect(dropStageRotationDrop(2).material, dropStageRotation[2]);
    expect(dropStageRotationDrop(3).material, dropStageRotation[0]);
    expect(dropStageRotationDrop(97).material, dropStageRotation[97 % 3]);
  });

  test('every stack shares one cycle, which is what the rotation counts', () {
    final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
    for (final ShowcaseDrop drop in showcaseDrops) {
      expect(
        DropStageTimeline(doc, drop).cycleMs,
        dropStageCycleMs,
        reason: drop.material,
      );
    }
    doc.presentation.limits.updateIntervalTicks = 7;
    doc.presentation.landing.transitionTicks = 11;
    expect(
      DropStageTimeline(doc, showcaseDrops.first).cycleMs,
      dropStageCycleMs,
      reason: 'the ballistics are the stage\'s, so no field moves the cycle',
    );
  });

  test('the stack is thrown forward and settles nearer the camera', () {
    final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
    final DropStageTimeline stage = DropStageTimeline(
      doc,
      _drop('cobblestone'),
    );

    expect(stage.frameAt(0).carrierZ, 0, reason: 'it leaves the hand');
    expect(
      stage.frameAt(stage.cycleMs - 200).carrierZ,
      closeTo(dropStageThrowBlocks, 1e-9),
      reason: 'and settles the whole throw away',
    );

    // Forward all the way, never backward, never past the throw.
    double previous = -1;
    for (int ms = 0; ms < stage.cycleMs; ms += 23) {
      final double forward = stage.frameAt(ms).carrierZ;
      expect(forward, greaterThanOrEqualTo(previous), reason: 'at $ms ms');
      expect(forward, lessThanOrEqualTo(dropStageThrowBlocks + 1e-9));
      previous = forward;
    }
  });

  test(
    'most of the throw is spent in the air, and the rest is the bounces',
    () {
      final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
      final DropStageTimeline stage = DropStageTimeline(doc, _drop('oak_slab'));

      // `changeOnBounce` is on by default, so the revision counts ground
      // contacts — the first frame that reads 1 is the first frame after the
      // stack has landed once.
      int landedMs = 0;
      for (int ms = 0; ms < stage.cycleMs; ms += 5) {
        final DropStageFrame frame = stage.frameAt(ms);
        if (frame.bounceRevision >= 1 && !frame.settled) {
          landedMs = ms;
          break;
        }
      }
      expect(landedMs, greaterThan(0), reason: 'the stack has to land');
      final double atLanding = stage.frameAt(landedMs).carrierZ;
      expect(
        atLanding,
        greaterThan(dropStageThrowBlocks * 0.6),
        reason: 'the arc, not the bounces, is where the stack covers ground',
      );
      expect(
        atLanding,
        lessThan(dropStageThrowBlocks * 0.95),
        reason: 'but the bounces still carry it a little further',
      );
    },
  );

  test('a stack falls, tumbles, then settles into the landing pose', () {
    final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
    final DropStageTimeline stage = DropStageTimeline(doc, _drop('cherry_log'));

    final DropStageFrame thrown = stage.frameAt(0);
    expect(thrown.carrierY, greaterThan(1));
    expect(thrown.grounded, isFalse);
    expect(thrown.settled, isFalse);
    expect(
      thrown.interpolationTicks,
      doc.presentation.limits.updateIntervalTicks,
    );

    final DropStageFrame settled = stage.frameAt(stage.cycleMs - 200);
    expect(settled.settled, isTrue);
    expect(settled.grounded, isTrue);
    expect(settled.carrierY, 0);
    expect(
      settled.interpolationTicks,
      doc.presentation.landing.transitionTicks,
    );

    // Mid-flight the pose keeps changing; settled it does not.
    final String early = stage
        .frameAt(300)
        .visuals
        .first
        .rotation
        .cssMatrix3d();
    final String later = stage
        .frameAt(600)
        .visuals
        .first
        .rotation
        .cssMatrix3d();
    expect(early, isNot(later));
    expect(
      stage.frameAt(stage.cycleMs - 400).visuals.first.rotation.cssMatrix3d(),
      settled.visuals.first.rotation.cssMatrix3d(),
    );
  });

  test('the timeline exposes continuous motion phases and phase time', () {
    final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
    final DropStageTimeline stage = DropStageTimeline(
      doc,
      _drop('cobblestone'),
    );
    final Set<DropAnimationPhase> phases = <DropAnimationPhase>{};
    DropStageFrame? rolling;
    DropStageFrame? rollingNext;
    DropAnimationPhase previous = DropAnimationPhase.airborne;

    for (int ms = 0; ms < stage.cycleMs; ms += 25) {
      final DropStageFrame frame = stage.frameAt(ms);
      phases.add(frame.phase);
      if (frame.phase != previous) {
        expect(frame.phaseTimeTicks, lessThan(1));
      }
      previous = frame.phase;
      if (rolling == null && frame.phase == DropAnimationPhase.rolling) {
        final DropStageFrame candidate = stage.frameAt(ms + 50);
        if (candidate.phase == DropAnimationPhase.rolling) {
          rolling = frame;
          rollingNext = candidate;
        }
      }
    }

    expect(phases, contains(DropAnimationPhase.airborne));
    expect(phases, contains(DropAnimationPhase.rebounding));
    expect(phases, contains(DropAnimationPhase.rolling));
    expect(phases, contains(DropAnimationPhase.settling));
    expect(phases, contains(DropAnimationPhase.settled));
    expect(rolling, isNotNull);
    expect(rollingNext!.phase, DropAnimationPhase.rolling);
    expect(rollingNext.carrierZ, greaterThan(rolling!.carrierZ));
    expect(
      rollingNext.visuals.first.rotation.cssMatrix3d(),
      isNot(rolling.visuals.first.rotation.cssMatrix3d()),
      reason: 'ground travel keeps rotating the cube instead of snapping it',
    );
  });

  test('a naturally settled cube finishes flush on its nearest face', () {
    final DropStageTimeline stage = DropStageTimeline(
      buildDefaultGlossRealDrops(),
      _drop('cobblestone'),
    );
    final DropStageFrame settled = stage.frameAt(stage.cycleMs - 100);
    final DropRotation rotation = settled.visuals.first.rotation;
    final DropRotation face = realDropFaceAlignedRotation(rotation);

    expect(settled.phase, DropAnimationPhase.settled);
    expect(rotation.difference(face), lessThan(1e-6));
    expect(settled.visuals.first.y, closeTo(settled.modelScale * 0.5, 1e-6));
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
      expect(
        first.frameAt(ms).carrierZ,
        first.frameAt(ms + first.cycleMs).carrierZ,
        reason: 'the throw wraps at $ms ms',
      );
    }
  });

  test('the document decides how many displays a stack grows', () {
    final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
    expect(DropStageTimeline(doc, _drop('sea_lantern')).visualCount, 2);
    expect(DropStageTimeline(doc, _drop('cake')).visualCount, 1);

    doc.presentation.limits.maxVisualsPerStack = 5;
    expect(DropStageTimeline(doc, _drop('sea_lantern')).visualCount, 2);
    doc.presentation.limits.maxVisualsPerStack = 1;
    expect(DropStageTimeline(doc, _drop('sea_lantern')).visualCount, 1);
  });

  test('turning the tumble off holds the model on its base pose', () {
    final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
    doc.presentation.motion.tumble = false;
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

  test('single-item labels use the material name by default', () {
    final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
    final ShowcaseDrop drop = _drop('cobblestone');
    expect(DropStageTimeline(doc, drop).label, '&7cobblestone');
  });

  test('multi-item labels retain the shipped count format', () {
    final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
    final ShowcaseDrop drop = _drop('cookie');
    expect(DropStageTimeline(doc, drop).label, '&7${drop.amount}x cookie');
  });

  test('renamed item labels require explicit preview opt-in', () {
    final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
    final ShowcaseDrop drop = _drop('diamond_pickaxe');
    expect(
      DropStageTimeline(
        doc,
        drop,
        environment: const DropStageEnvironment(useItemDisplayNames: true),
      ).label,
      '&7${drop.displayName}',
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
    expect(cube.modelScale, doc.presentation.scale.defaultScale);
    expect(flat.modelScale, doc.presentation.scale.flatItems);
    expect(thin.modelScale, doc.presentation.scale.thinBlocks);

    // Every placed block model lifts by its rotated model bounds.
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
      closeTo(0.225, 1e-9),
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
        expect(frame.carrierZ.isFinite, isTrue, reason: '${drop.material} $ms');
        expect(frame.carrierZ, greaterThanOrEqualTo(0));
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

  group('the script layer rides on top of the presentation', () {
    /// A document with the script switched on and one field set. Everything
    /// else in the block stays neutral, which is what makes the assertions
    /// below about that one field.
    GlossRealDropSettingsDoc scripted(
      void Function(GlossRealDropScript s) set,
    ) {
      final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
      final GlossRealDropScript script = doc.presentation.script!
        ..enabled = true;
      set(script);
      return doc;
    }

    /// The moment mid-flight every assertion here reads, chosen once so a
    /// scripted frame and its unscripted twin are the same instant.
    const int midFlight = 400;

    test('off, the stage is exactly what it was before the block existed', () {
      final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
      final DropStageTimeline stage = DropStageTimeline(
        doc,
        _drop('cobblestone'),
      );
      expect(stage.scriptActive, isFalse);
      final DropStageFrame frame = stage.frameAt(midFlight);
      expect(frame.scriptActive, isFalse);
      expect(frame.scriptFailures, isEmpty);
      for (final DropStageVisual visual in frame.visuals) {
        expect(visual.scaleX, 1);
        expect(visual.scaleY, 1);
        expect(visual.scaleZ, 1);
        expect(visual.glowArgb, 0);
        expect(visual.visible, isTrue);
      }
    });

    test('offset adds to the model offset rather than replacing it', () {
      final DropStageTimeline plain = DropStageTimeline(
        buildDefaultGlossRealDrops(),
        _drop('cobblestone'),
      );
      final DropStageTimeline lifted = DropStageTimeline(
        scripted((GlossRealDropScript s) => s.offset.y = '0.5'),
        _drop('cobblestone'),
      );
      final List<DropStageVisual> before = plain.frameAt(midFlight).visuals;
      final List<DropStageVisual> after = lifted.frameAt(midFlight).visuals;
      expect(after, hasLength(before.length));
      for (int index = 0; index < before.length; index++) {
        expect(after[index].y, closeTo(before[index].y + 0.5, 1e-9));
        expect(after[index].x, closeTo(before[index].x, 1e-9));
      }
    });

    test('index reaches the script, so a stack can fan out', () {
      final DropStageTimeline stage = DropStageTimeline(
        scripted((GlossRealDropScript s) => s.offset.x = 'index * 0.25'),
        _drop('sea_lantern'),
      );
      final List<DropStageVisual> visuals = stage.frameAt(midFlight).visuals;
      expect(visuals.length, greaterThan(1));
      final DropStageTimeline plain = DropStageTimeline(
        buildDefaultGlossRealDrops(),
        _drop('sea_lantern'),
      );
      final List<DropStageVisual> before = plain.frameAt(midFlight).visuals;
      for (int index = 0; index < visuals.length; index++) {
        expect(
          visuals[index].x,
          closeTo(before[index].x + index * 0.25, 1e-9),
          reason: 'display $index',
        );
      }
    });

    test('scale multiplies the family, per axis, and leaves it readable', () {
      final DropStageTimeline stage = DropStageTimeline(
        scripted((GlossRealDropScript s) {
          s.scale.x = '2';
          s.scale.y = '0.5';
        }),
        _drop('cobblestone'),
      );
      final DropStageVisual visual = stage.frameAt(midFlight).visuals.first;
      expect(visual.scale, stage.modelScale, reason: 'the family is untouched');
      expect(visual.scaleX, 2);
      expect(visual.scaleY, 0.5);
      expect(visual.scaleZ, 1);
    });

    test('rotation composes onto the pose instead of replacing it', () {
      final DropStageTimeline plain = DropStageTimeline(
        buildDefaultGlossRealDrops(),
        _drop('cobblestone'),
      );
      final DropStageTimeline turned = DropStageTimeline(
        scripted((GlossRealDropScript s) => s.rotation.y = '90'),
        _drop('cobblestone'),
      );
      expect(
        turned.frameAt(midFlight).visuals.first.rotation.cssMatrix3d(),
        isNot(plain.frameAt(midFlight).visuals.first.rotation.cssMatrix3d()),
      );
      // Still tumbling underneath: two moments differ from each other, which
      // they would not if the script had overwritten the pose with a constant.
      expect(
        turned.frameAt(300).visuals.first.rotation.cssMatrix3d(),
        isNot(turned.frameAt(600).visuals.first.rotation.cssMatrix3d()),
      );
    });

    test('a scripted tilt is corrected for, not left sinking into the floor', () {
      final DropStageTimeline flat = DropStageTimeline(
        buildDefaultGlossRealDrops(),
        _drop('cobblestone'),
      );
      final DropStageTimeline tilted = DropStageTimeline(
        scripted((GlossRealDropScript s) => s.rotation.z = '45'),
        _drop('cobblestone'),
      );
      final int settledMs = flat.cycleMs - 200;
      expect(flat.frameAt(settledMs).settled, isTrue);
      expect(
        tilted.frameAt(settledMs).visuals.first.y,
        greaterThan(flat.frameAt(settledMs).visuals.first.y),
        reason:
            'a cube stood on its corner is taller, so the clearance recomputed '
            'from the final pose has to lift it further',
      );
    });

    test('glow and visible reach the display', () {
      final DropStageTimeline glowing = DropStageTimeline(
        scripted((GlossRealDropScript s) => s.glow = '#FFAA55'),
        _drop('sea_lantern'),
      );
      expect(glowing.frameAt(midFlight).visuals.first.glowArgb, 0xFFFFAA55);

      final DropStageTimeline hidden = DropStageTimeline(
        scripted((GlossRealDropScript s) => s.visible = 'index > 0'),
        _drop('sea_lantern'),
      );
      final List<DropStageVisual> visuals = hidden.frameAt(midFlight).visuals;
      expect(visuals.first.visible, isFalse);
      expect(visuals.last.visible, isTrue);
    });

    test('a material test picks out the stack it names', () {
      final GlossRealDropSettingsDoc doc = scripted(
        (GlossRealDropScript s) =>
            s.glow = "materialMatches('*_PICKAXE') ? #FFCC66 : 0",
      );
      expect(
        DropStageTimeline(
          doc,
          _drop('diamond_pickaxe'),
        ).frameAt(midFlight).visuals.first.glowArgb,
        0xFFFFCC66,
      );
      expect(
        DropStageTimeline(
          doc,
          _drop('cobblestone'),
        ).frameAt(midFlight).visuals.first.glowArgb,
        0,
      );
    });

    test('a script the server would refuse never reaches the stage', () {
      final DropStageTimeline stage = DropStageTimeline(
        scripted((GlossRealDropScript s) => s.offset.y = 'sin(t'),
        _drop('cobblestone'),
      );
      expect(stage.scriptActive, isFalse);
      final DropStageFrame frame = stage.frameAt(midFlight);
      expect(frame.scriptFailures, isEmpty);
      expect(frame.visuals.first.scaleX, 1);
    });
  });

  group('the stage says which variables it cannot observe', () {
    test('inWater follows the water toggle and nothing else', () {
      final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
      doc.presentation.script!
        ..enabled = true
        ..glow = 'inWater ? #3A8CBE : 0';

      final DropStageTimeline dry = DropStageTimeline(
        doc,
        _drop('cobblestone'),
      );
      for (int ms = 0; ms < dry.cycleMs; ms += 97) {
        expect(dry.frameAt(ms).submerged, isFalse, reason: '$ms ms');
        expect(dry.frameAt(ms).visuals.first.glowArgb, 0, reason: '$ms ms');
      }

      final DropStageTimeline wet = DropStageTimeline(
        doc,
        _drop('cobblestone'),
        environment: const DropStageEnvironment(water: true),
      );
      final bool everWet = <int>[
        for (int ms = 0; ms < wet.cycleMs; ms += 47) ms,
      ].any((int ms) => wet.frameAt(ms).visuals.first.glowArgb != 0);
      expect(
        everWet,
        isTrue,
        reason: 'the stack falls through the surface, so inWater goes true',
      );
    });

    test('lava is never simulated and the light levels are full', () {
      expect(DropStageEnvironment.inLava, isFalse);
      expect(DropStageEnvironment.blockLight, 15);
      expect(DropStageEnvironment.skyLight, 15);
      expect(
        DropStageEnvironment.simulatedVariables,
        <String>['inWater', 'inLava', 'blockLight', 'skyLight'],
        reason: 'the readout names exactly these four as simulated',
      );
    });

    test('random is fixed for a stack, so nothing built on it flickers', () {
      final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
      final DropStageTimeline first = DropStageTimeline(doc, _drop('feather'));
      final DropStageTimeline second = DropStageTimeline(doc, _drop('feather'));
      expect(first.random, second.random);
      expect(first.random, greaterThanOrEqualTo(0));
      expect(first.random, lessThan(1));
      expect(
        first.random,
        isNot(DropStageTimeline(doc, _drop('cobblestone')).random),
        reason: 'two stacks do not bob in lockstep',
      );
    });
  });

  group('the physics block reaches the stage arc', () {
    GlossRealDropSettingsDoc physical(
      void Function(GlossRealDropPhysics p) set,
    ) {
      final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
      final GlossRealDropPhysics physics = doc.presentation.physics!
        ..enabled = true;
      set(physics);
      return doc;
    }

    /// The tick the stack first touches the floor.
    double landingTick(DropStageTimeline stage) {
      for (int ms = 0; ms < stage.cycleMs; ms += 10) {
        if (stage.frameAt(ms).grounded) return ms / 50;
      }
      return double.infinity;
    }

    test('off, the cycle is the one the rotation counts', () {
      expect(
        DropStageTimeline(
          buildDefaultGlossRealDrops(),
          _drop('cobblestone'),
        ).cycleMs,
        dropStageCycleMs,
      );
      expect(
        dropStageCycleMsFor(buildDefaultGlossRealDrops()),
        dropStageCycleMs,
      );
    });

    test('heavier gravity lands the stack sooner, lighter later', () {
      final double normal = landingTick(
        DropStageTimeline(buildDefaultGlossRealDrops(), _drop('cobblestone')),
      );
      final double heavy = landingTick(
        DropStageTimeline(
          physical((GlossRealDropPhysics p) => p.gravityMultiplier = 3),
          _drop('cobblestone'),
        ),
      );
      final double light = landingTick(
        DropStageTimeline(
          physical((GlossRealDropPhysics p) => p.gravityMultiplier = 0.25),
          _drop('cobblestone'),
        ),
      );
      expect(heavy, lessThan(normal));
      expect(light, greaterThan(normal));
    });

    test('gravity 0 hangs the stack where it is, and never settles it', () {
      final DropStageTimeline stage = DropStageTimeline(
        physical((GlossRealDropPhysics p) => p.gravityMultiplier = 0),
        _drop('cobblestone'),
      );
      for (int ms = 0; ms < stage.cycleMs; ms += 211) {
        final DropStageFrame frame = stage.frameAt(ms);
        expect(frame.settled, isFalse, reason: '$ms ms');
        expect(frame.grounded, isFalse, reason: '$ms ms');
        expect(frame.carrierY, greaterThan(2), reason: '$ms ms');
      }
    });

    test('bounce replaces the stage own restitution, so 0 really sticks', () {
      final DropStageTimeline bouncy = DropStageTimeline(
        physical((GlossRealDropPhysics p) => p.bounce = 0.8),
        _drop('cobblestone'),
      );
      final DropStageTimeline dead = DropStageTimeline(
        physical((GlossRealDropPhysics p) => p.bounce = 0),
        _drop('cobblestone'),
      );
      int peak(DropStageTimeline stage) {
        int count = 0;
        for (int ms = 0; ms < stage.cycleMs; ms += 10) {
          count = math.max(count, stage.frameAt(ms).bounces);
        }
        return count;
      }

      expect(peak(bouncy), greaterThan(0));
      expect(
        peak(dead),
        0,
        reason: 'vanilla items do not bounce, and neither does bounce 0',
      );
    });

    test('buoyancy in water floats the stack instead of resting it', () {
      final GlossRealDropSettingsDoc doc = physical((GlossRealDropPhysics p) {
        p.waterBuoyancy = 0.35;
        p.waterDrag = 0.12;
      });
      final DropStageTimeline stage = DropStageTimeline(
        doc,
        _drop('cobblestone'),
        environment: const DropStageEnvironment(water: true),
      );
      double lowest = double.infinity;
      bool everSettled = false;
      for (int ms = stage.cycleMs ~/ 2; ms < stage.cycleMs; ms += 23) {
        final DropStageFrame frame = stage.frameAt(ms);
        lowest = math.min(lowest, frame.carrierY);
        everSettled |= frame.settled;
      }
      expect(everSettled, isFalse, reason: 'a buoyant item is never at rest');
      expect(
        lowest,
        greaterThan(0),
        reason: 'and buoyancy keeps it off the floor',
      );
    });

    test('water drag at full stops the stack dead the moment it is under', () {
      final GlossRealDropSettingsDoc doc = physical(
        (GlossRealDropPhysics p) => p.waterDrag = 1,
      );
      final DropStageTimeline dragged = DropStageTimeline(
        doc,
        _drop('cobblestone'),
        environment: const DropStageEnvironment(water: true),
      );
      final DropStageTimeline free = DropStageTimeline(
        doc,
        _drop('cobblestone'),
      );
      expect(landingTick(free).isFinite, isTrue);
      expect(
        landingTick(dragged),
        double.infinity,
        reason:
            'the stack stops the moment it is submerged, so it never reaches '
            'the floor at all',
      );
    });
  });
}

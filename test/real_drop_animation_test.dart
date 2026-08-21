library;

import 'dart:convert';

import 'package:gloss_editor/config/showcase_flavor.dart';
import 'package:gloss_editor/logic/real_drop_animation.dart';
import 'package:gloss_editor/logic/real_drop_stage.dart';
import 'package:gloss_editor/logic/real_drop_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/gloss_real_drop_animation.dart';
import 'package:gloss_editor/model/gloss_real_drops.dart';
import 'package:test/test.dart';

void main() {
  test('the complete animation contract round-trips without losing extras', () {
    final GlossRealDropSettingsDoc doc = decodeGlossRealDropSettingsDoc('''
{
  "schemaVersion": 1,
  "revision": 2,
  "animation": {
    "enabled": true,
    "future": 7,
    "materialProperties": {
      "lighting": {
        "TORCH": {"glow": 4294967295, "lightLevel": 15}
      }
    },
    "profiles": [{
      "id": "lights",
      "priority": 20,
      "materials": ["*_TORCH", "LANTERN"],
      "clips": [{
        "trigger": "IMPACT",
        "durationTicks": 8,
        "loop": false,
        "tracks": [
          {
            "target": "PHYSICS",
            "blend": "REPLACE",
            "keyframes": [{"tick": 0, "value": 0, "easing": "HOLD"}]
          },
          {
            "target": "LIGHT_LEVEL",
            "blend": "REPLACE",
            "keyframes": [{
              "tick": 0,
              "value": 4,
              "materialMap": "lighting",
              "easing": "BACK_OUT"
            }]
          }
        ]
      }]
    }]
  }
}
''');

    expect(
      doc.animation!.profiles.single.clips.single.tracks[0].target,
      GlossRealDropAnimationTarget.physics,
    );
    expect(
      doc.animation!.profiles.single.clips.single.tracks[1].target,
      GlossRealDropAnimationTarget.lightLevel,
    );
    final Map<String, dynamic> encoded =
        jsonDecode(encodeGlossRealDropSettingsDoc(doc)) as Map<String, dynamic>;
    expect((encoded['animation'] as Map<String, dynamic>)['future'], 7);
    expect(
      ((encoded['animation'] as Map<String, dynamic>)['profiles']
              as List<Object?>)
          .single,
      containsPair('id', 'lights'),
    );
  });

  test('priority, material globs, blends and material maps mirror Gloss', () {
    final GlossRealDropAnimation animation = GlossRealDropAnimation(
      enabled: true,
      materialProperties:
          <String, Map<String, GlossRealDropMaterialProperties>>{
            'lights': <String, GlossRealDropMaterialProperties>{
              '*_TORCH': GlossRealDropMaterialProperties(lightLevel: 14),
              '*': GlossRealDropMaterialProperties(lightLevel: 3),
            },
          },
      profiles: <GlossRealDropAnimationProfile>[
        GlossRealDropAnimationProfile(
          id: 'fallback',
          priority: 0,
          clips: <GlossRealDropAnimationClip>[],
        ),
        GlossRealDropAnimationProfile(
          id: 'torch',
          priority: 10,
          materials: <String>['*_TORCH'],
          clips: <GlossRealDropAnimationClip>[
            GlossRealDropAnimationClip(
              trigger: GlossRealDropAnimationTrigger.impact,
              durationTicks: 10,
              tracks: <GlossRealDropAnimationTrack>[
                GlossRealDropAnimationTrack(
                  target: GlossRealDropAnimationTarget.offsetY,
                  blend: GlossRealDropAnimationBlend.add,
                  keyframes: <GlossRealDropAnimationKeyframe>[
                    GlossRealDropAnimationKeyframe(tick: 0, value: 0),
                    GlossRealDropAnimationKeyframe(tick: 10, value: 2),
                  ],
                ),
                GlossRealDropAnimationTrack(
                  target: GlossRealDropAnimationTarget.lightLevel,
                  blend: GlossRealDropAnimationBlend.replace,
                  keyframes: <GlossRealDropAnimationKeyframe>[
                    GlossRealDropAnimationKeyframe(
                      tick: 0,
                      value: 1,
                      materialMap: 'lights',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final RealDropAnimationPlan plan = RealDropAnimationPlan(animation);
    final RealDropAnimationSample sample = plan.sample(
      'minecraft:redstone_torch',
      const <RealDropActiveAnimationClip>[
        RealDropActiveAnimationClip(GlossRealDropAnimationTrigger.impact, 5),
      ],
    );

    expect(sample.profileId, 'torch');
    expect(sample.offsetY, closeTo(1, 1e-12));
    expect(sample.lightLevel, 14);
    expect(plan.profileId('minecraft:stone'), 'fallback');
  });

  test('easing belongs to the destination keyframe', () {
    final GlossRealDropAnimationTrack track = GlossRealDropAnimationTrack(
      target: GlossRealDropAnimationTarget.offsetX,
      keyframes: <GlossRealDropAnimationKeyframe>[
        GlossRealDropAnimationKeyframe(tick: 0, value: 0),
        GlossRealDropAnimationKeyframe(
          tick: 10,
          value: 10,
          easing: GlossRealDropAnimationEasing.easeIn,
        ),
      ],
    );
    final RealDropAnimationPlan plan = RealDropAnimationPlan(
      GlossRealDropAnimation(
        enabled: true,
        profiles: <GlossRealDropAnimationProfile>[
          GlossRealDropAnimationProfile(
            clips: <GlossRealDropAnimationClip>[
              GlossRealDropAnimationClip(
                trigger: GlossRealDropAnimationTrigger.spawn,
                durationTicks: 10,
                tracks: <GlossRealDropAnimationTrack>[track],
              ),
            ],
          ),
        ],
      ),
    );

    expect(
      plan.sample('STONE', const <RealDropActiveAnimationClip>[
        RealDropActiveAnimationClip(GlossRealDropAnimationTrigger.spawn, 5),
      ]).offsetX,
      closeTo(1.25, 1e-12),
    );
  });

  test('validation rejects the same unsafe track combinations as Gloss', () {
    final GlossRealDropSettingsDoc doc = GlossRealDropSettingsDoc(
      animation: GlossRealDropAnimation(
        enabled: true,
        profiles: <GlossRealDropAnimationProfile>[
          GlossRealDropAnimationProfile(
            clips: <GlossRealDropAnimationClip>[
              GlossRealDropAnimationClip(
                durationTicks: 5,
                tracks: <GlossRealDropAnimationTrack>[
                  GlossRealDropAnimationTrack(
                    target: GlossRealDropAnimationTarget.physics,
                    blend: GlossRealDropAnimationBlend.add,
                    keyframes: <GlossRealDropAnimationKeyframe>[
                      GlossRealDropAnimationKeyframe(
                        tick: 6,
                        materialMap: 'missing',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    final List<HuiIssue> issues = validateRealDropSettingsDoc(doc);
    final String messages = issues
        .map((HuiIssue issue) => issue.message)
        .join('\n');

    expect(messages, contains('ADD is not valid for PHYSICS'));
    expect(messages, contains('inside the clip duration'));
    expect(messages, contains('only support GLOW and LIGHT_LEVEL'));
  });

  test('a hover freezes the carrier and releases its preserved throw', () {
    GlossRealDropAnimationTrack scale(GlossRealDropAnimationTarget target) =>
        GlossRealDropAnimationTrack(
          target: target,
          blend: GlossRealDropAnimationBlend.multiply,
          keyframes: <GlossRealDropAnimationKeyframe>[
            GlossRealDropAnimationKeyframe(tick: 0, value: 4),
            GlossRealDropAnimationKeyframe(
              tick: 6,
              value: 0.15,
              easing: GlossRealDropAnimationEasing.easeIn,
            ),
            GlossRealDropAnimationKeyframe(
              tick: 12,
              value: 4,
              easing: GlossRealDropAnimationEasing.backOut,
            ),
            GlossRealDropAnimationKeyframe(tick: 20, value: 1),
          ],
        );
    final GlossRealDropAnimationClip sequence = GlossRealDropAnimationClip(
      trigger: GlossRealDropAnimationTrigger.spawn,
      durationTicks: 60,
      tracks: <GlossRealDropAnimationTrack>[
        scale(GlossRealDropAnimationTarget.scaleX),
        scale(GlossRealDropAnimationTarget.scaleY),
        scale(GlossRealDropAnimationTarget.scaleZ),
        GlossRealDropAnimationTrack(
          target: GlossRealDropAnimationTarget.offsetY,
          blend: GlossRealDropAnimationBlend.add,
          keyframes: <GlossRealDropAnimationKeyframe>[
            GlossRealDropAnimationKeyframe(tick: 0, value: 0),
            GlossRealDropAnimationKeyframe(tick: 8, value: 2),
            GlossRealDropAnimationKeyframe(
              tick: 36,
              value: 2,
              easing: GlossRealDropAnimationEasing.hold,
            ),
            GlossRealDropAnimationKeyframe(tick: 60, value: 0),
          ],
        ),
        GlossRealDropAnimationTrack(
          target: GlossRealDropAnimationTarget.physics,
          blend: GlossRealDropAnimationBlend.replace,
          keyframes: <GlossRealDropAnimationKeyframe>[
            GlossRealDropAnimationKeyframe(
              tick: 0,
              value: 0,
              easing: GlossRealDropAnimationEasing.hold,
            ),
            GlossRealDropAnimationKeyframe(
              tick: 36,
              value: 0,
              easing: GlossRealDropAnimationEasing.hold,
            ),
            GlossRealDropAnimationKeyframe(tick: 37, value: 1),
          ],
        ),
        GlossRealDropAnimationTrack(
          target: GlossRealDropAnimationTarget.rotationX,
          blend: GlossRealDropAnimationBlend.add,
          keyframes: <GlossRealDropAnimationKeyframe>[
            GlossRealDropAnimationKeyframe(tick: 0, value: 0),
            GlossRealDropAnimationKeyframe(
              tick: 60,
              value: 1080,
              easing: GlossRealDropAnimationEasing.easeInOut,
            ),
          ],
        ),
      ],
    );
    final GlossRealDropSettingsDoc animatedDoc = GlossRealDropSettingsDoc(
      animation: GlossRealDropAnimation(
        enabled: true,
        profiles: <GlossRealDropAnimationProfile>[
          GlossRealDropAnimationProfile(
            id: 'hover-release',
            clips: <GlossRealDropAnimationClip>[sequence],
          ),
        ],
      ),
    );
    final ShowcaseDrop drop = showcaseDrops.firstWhere(
      (ShowcaseDrop candidate) => candidate.material == 'cobblestone',
    );
    final DropStageTimeline animated = DropStageTimeline(animatedDoc, drop);
    final DropStageTimeline plain = DropStageTimeline(
      GlossRealDropSettingsDoc(),
      drop,
    );
    final DropStageFrame spawned = animated.frameAt(0);

    for (final int heldMs in <int>[300, 600, 1000, 1800, 1850]) {
      final DropStageFrame held = animated.frameAt(heldMs);
      expect(held.carrierY, spawned.carrierY, reason: '$heldMs ms height');
      expect(held.carrierZ, spawned.carrierZ, reason: '$heldMs ms forward');
    }
    expect(animated.frameAt(0).visuals.first.scaleX, 4);
    expect(animated.frameAt(300).visuals.first.scaleX, closeTo(0.15, 1e-12));
    expect(animated.frameAt(600).visuals.first.scaleX, 4);
    expect(
      animated.frameAt(1000).visuals.first.rotation.cssMatrix3d(),
      isNot(spawned.visuals.first.rotation.cssMatrix3d()),
      reason: 'the authored spiral keeps advancing while physics is held',
    );
    expect(animated.frameAt(1800).animationPhysics, isFalse);
    expect(animated.frameAt(1850).animationPhysics, isTrue);

    final DropStageFrame released = animated.frameAt(1900);
    final DropStageFrame firstPlainTick = plain.frameAt(50);
    expect(released.carrierY, closeTo(firstPlainTick.carrierY, 1e-12));
    expect(released.carrierZ, closeTo(firstPlainTick.carrierZ, 1e-12));
    expect(released.carrierY, isNot(spawned.carrierY));
    expect(released.carrierZ, greaterThan(spawned.carrierZ));
  });
}

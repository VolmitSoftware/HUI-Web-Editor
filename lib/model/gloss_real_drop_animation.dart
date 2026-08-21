library;

import 'json_codec.dart';

enum GlossRealDropAnimationTrigger {
  spawn,
  airborne,
  rebounding,
  rolling,
  sliding,
  settling,
  settled,
  submerged,
  floating,
  impact,
  bounce,
  enterFluid,
  exitFluid,
  startRoll,
  settle,
  wake;

  String get wire => switch (this) {
    GlossRealDropAnimationTrigger.enterFluid => 'ENTER_FLUID',
    GlossRealDropAnimationTrigger.exitFluid => 'EXIT_FLUID',
    GlossRealDropAnimationTrigger.startRoll => 'START_ROLL',
    _ => name.toUpperCase(),
  };

  static GlossRealDropAnimationTrigger parse(String value) {
    final String normalized = value.trim().toUpperCase();
    for (final GlossRealDropAnimationTrigger trigger in values) {
      if (trigger.wire == normalized) return trigger;
    }
    return GlossRealDropAnimationTrigger.spawn;
  }
}

enum GlossRealDropAnimationTarget {
  offsetX,
  offsetY,
  offsetZ,
  rotationX,
  rotationY,
  rotationZ,
  scaleX,
  scaleY,
  scaleZ,
  glow,
  visible,
  physics,
  lightLevel;

  String get wire => switch (this) {
    GlossRealDropAnimationTarget.offsetX => 'OFFSET_X',
    GlossRealDropAnimationTarget.offsetY => 'OFFSET_Y',
    GlossRealDropAnimationTarget.offsetZ => 'OFFSET_Z',
    GlossRealDropAnimationTarget.rotationX => 'ROTATION_X',
    GlossRealDropAnimationTarget.rotationY => 'ROTATION_Y',
    GlossRealDropAnimationTarget.rotationZ => 'ROTATION_Z',
    GlossRealDropAnimationTarget.scaleX => 'SCALE_X',
    GlossRealDropAnimationTarget.scaleY => 'SCALE_Y',
    GlossRealDropAnimationTarget.scaleZ => 'SCALE_Z',
    GlossRealDropAnimationTarget.lightLevel => 'LIGHT_LEVEL',
    _ => name.toUpperCase(),
  };

  static GlossRealDropAnimationTarget parse(String value) {
    final String normalized = value.trim().toUpperCase();
    for (final GlossRealDropAnimationTarget target in values) {
      if (target.wire == normalized) return target;
    }
    return GlossRealDropAnimationTarget.offsetX;
  }
}

enum GlossRealDropAnimationBlend {
  add,
  replace,
  multiply;

  String get wire => name.toUpperCase();

  static GlossRealDropAnimationBlend parse(String value) {
    final String normalized = value.trim().toUpperCase();
    for (final GlossRealDropAnimationBlend blend in values) {
      if (blend.wire == normalized) return blend;
    }
    return GlossRealDropAnimationBlend.add;
  }
}

enum GlossRealDropAnimationEasing {
  linear,
  hold,
  easeIn,
  easeOut,
  easeInOut,
  backOut;

  String get wire => switch (this) {
    GlossRealDropAnimationEasing.easeIn => 'EASE_IN',
    GlossRealDropAnimationEasing.easeOut => 'EASE_OUT',
    GlossRealDropAnimationEasing.easeInOut => 'EASE_IN_OUT',
    GlossRealDropAnimationEasing.backOut => 'BACK_OUT',
    _ => name.toUpperCase(),
  };

  static GlossRealDropAnimationEasing parse(String value) {
    final String normalized = value.trim().toUpperCase();
    for (final GlossRealDropAnimationEasing easing in values) {
      if (easing.wire == normalized) return easing;
    }
    return GlossRealDropAnimationEasing.linear;
  }
}

final class GlossRealDropMaterialProperties {
  GlossRealDropMaterialProperties({
    this.glow = 0,
    this.lightLevel = 0,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  double glow;
  double lightLevel;
  Map<String, dynamic> extras;

  static GlossRealDropMaterialProperties fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossRealDropMaterialProperties(
      glow: huiReadDouble(map, 'glow'),
      lightLevel: huiReadDouble(map, 'lightLevel'),
      extras: huiCollectExtras(map, const <String>{'glow', 'lightLevel'}),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'glow': glow,
    'lightLevel': lightLevel,
  }, extras);
}

final class GlossRealDropAnimationKeyframe {
  GlossRealDropAnimationKeyframe({
    this.tick = 0,
    this.value = 0,
    this.materialMap = '',
    this.easing = GlossRealDropAnimationEasing.linear,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  double tick;
  double value;
  String materialMap;
  GlossRealDropAnimationEasing easing;
  Map<String, dynamic> extras;

  static GlossRealDropAnimationKeyframe fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossRealDropAnimationKeyframe(
      tick: huiReadDouble(map, 'tick'),
      value: huiReadDouble(map, 'value'),
      materialMap: huiReadString(map, 'materialMap').trim(),
      easing: GlossRealDropAnimationEasing.parse(
        huiReadString(map, 'easing', fallback: 'LINEAR'),
      ),
      extras: huiCollectExtras(map, const <String>{
        'tick',
        'value',
        'materialMap',
        'easing',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'tick': tick,
    'value': value,
    if (materialMap.isNotEmpty) 'materialMap': materialMap,
    'easing': easing.wire,
  }, extras);
}

final class GlossRealDropAnimationTrack {
  GlossRealDropAnimationTrack({
    this.target = GlossRealDropAnimationTarget.offsetX,
    this.blend = GlossRealDropAnimationBlend.add,
    List<GlossRealDropAnimationKeyframe>? keyframes,
    Map<String, dynamic>? extras,
  }) : keyframes = keyframes ?? <GlossRealDropAnimationKeyframe>[],
       extras = extras ?? <String, dynamic>{};

  GlossRealDropAnimationTarget target;
  GlossRealDropAnimationBlend blend;
  List<GlossRealDropAnimationKeyframe> keyframes;
  Map<String, dynamic> extras;

  static GlossRealDropAnimationTrack fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    final List<Object?> frames = huiReadList(map['keyframes']);
    return GlossRealDropAnimationTrack(
      target: GlossRealDropAnimationTarget.parse(
        huiReadString(map, 'target', fallback: 'OFFSET_X'),
      ),
      blend: GlossRealDropAnimationBlend.parse(
        huiReadString(map, 'blend', fallback: 'ADD'),
      ),
      keyframes: <GlossRealDropAnimationKeyframe>[
        for (int index = 0; index < frames.length; index++)
          GlossRealDropAnimationKeyframe.fromJson(
            frames[index],
            '$path.keyframes[$index]',
          ),
      ],
      extras: huiCollectExtras(map, const <String>{
        'target',
        'blend',
        'keyframes',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'target': target.wire,
    'blend': blend.wire,
    'keyframes': <Map<String, dynamic>>[
      for (final GlossRealDropAnimationKeyframe frame in keyframes)
        frame.toJson(),
    ],
  }, extras);
}

final class GlossRealDropAnimationClip {
  GlossRealDropAnimationClip({
    this.trigger = GlossRealDropAnimationTrigger.spawn,
    this.durationTicks = 0,
    this.loop = false,
    List<GlossRealDropAnimationTrack>? tracks,
    Map<String, dynamic>? extras,
  }) : tracks = tracks ?? <GlossRealDropAnimationTrack>[],
       extras = extras ?? <String, dynamic>{};

  GlossRealDropAnimationTrigger trigger;
  double durationTicks;
  bool loop;
  List<GlossRealDropAnimationTrack> tracks;
  Map<String, dynamic> extras;

  static GlossRealDropAnimationClip fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    final List<Object?> tracks = huiReadList(map['tracks']);
    return GlossRealDropAnimationClip(
      trigger: GlossRealDropAnimationTrigger.parse(
        huiReadString(map, 'trigger', fallback: 'SPAWN'),
      ),
      durationTicks: huiReadDouble(map, 'durationTicks'),
      loop: huiReadBool(map, 'loop'),
      tracks: <GlossRealDropAnimationTrack>[
        for (int index = 0; index < tracks.length; index++)
          GlossRealDropAnimationTrack.fromJson(
            tracks[index],
            '$path.tracks[$index]',
          ),
      ],
      extras: huiCollectExtras(map, const <String>{
        'trigger',
        'durationTicks',
        'loop',
        'tracks',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'trigger': trigger.wire,
    'durationTicks': durationTicks,
    'loop': loop,
    'tracks': <Map<String, dynamic>>[
      for (final GlossRealDropAnimationTrack track in tracks) track.toJson(),
    ],
  }, extras);
}

final class GlossRealDropAnimationProfile {
  GlossRealDropAnimationProfile({
    this.id = 'default',
    this.priority = 0,
    List<String>? materials,
    List<GlossRealDropAnimationClip>? clips,
    Map<String, dynamic>? extras,
  }) : materials = materials ?? <String>['*'],
       clips = clips ?? <GlossRealDropAnimationClip>[],
       extras = extras ?? <String, dynamic>{};

  String id;
  int priority;
  List<String> materials;
  List<GlossRealDropAnimationClip> clips;
  Map<String, dynamic> extras;

  static GlossRealDropAnimationProfile fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    final List<Object?> clips = huiReadList(map['clips']);
    final List<String> materials = huiReadStringList(map['materials']);
    final String id = huiReadString(map, 'id', fallback: 'default').trim();
    return GlossRealDropAnimationProfile(
      id: id.isEmpty ? 'default' : id,
      priority: huiReadInt(map, 'priority'),
      materials: materials.isEmpty ? <String>['*'] : materials,
      clips: <GlossRealDropAnimationClip>[
        for (int index = 0; index < clips.length; index++)
          GlossRealDropAnimationClip.fromJson(
            clips[index],
            '$path.clips[$index]',
          ),
      ],
      extras: huiCollectExtras(map, const <String>{
        'id',
        'priority',
        'materials',
        'clips',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'id': id,
    'priority': priority,
    'materials': List<String>.of(materials),
    'clips': <Map<String, dynamic>>[
      for (final GlossRealDropAnimationClip clip in clips) clip.toJson(),
    ],
  }, extras);
}

final class GlossRealDropAnimation {
  GlossRealDropAnimation({
    this.enabled = false,
    Map<String, Map<String, GlossRealDropMaterialProperties>>?
    materialProperties,
    List<GlossRealDropAnimationProfile>? profiles,
    Map<String, dynamic>? extras,
  }) : materialProperties =
           materialProperties ??
           <String, Map<String, GlossRealDropMaterialProperties>>{},
       profiles = profiles ?? <GlossRealDropAnimationProfile>[],
       extras = extras ?? <String, dynamic>{};

  bool enabled;
  Map<String, Map<String, GlossRealDropMaterialProperties>> materialProperties;
  List<GlossRealDropAnimationProfile> profiles;
  Map<String, dynamic> extras;

  static GlossRealDropAnimation fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$.animation');
    final Map<String, dynamic> propertyMaps = map['materialProperties'] is Map
        ? huiReadObject(
            map['materialProperties'],
            r'$.animation.materialProperties',
          )
        : <String, dynamic>{};
    final Map<String, Map<String, GlossRealDropMaterialProperties>> properties =
        <String, Map<String, GlossRealDropMaterialProperties>>{};
    propertyMaps.forEach((String mapName, Object? entriesRaw) {
      if (entriesRaw is! Map) return;
      final Map<String, dynamic> entries = huiReadObject(
        entriesRaw,
        '\$.animation.materialProperties.$mapName',
      );
      properties[mapName] = <String, GlossRealDropMaterialProperties>{
        for (final MapEntry<String, dynamic> entry in entries.entries)
          entry.key: GlossRealDropMaterialProperties.fromJson(
            entry.value,
            '\$.animation.materialProperties.$mapName.${entry.key}',
          ),
      };
    });
    final List<Object?> profiles = huiReadList(map['profiles']);
    return GlossRealDropAnimation(
      enabled: huiReadBool(map, 'enabled'),
      materialProperties: properties,
      profiles: <GlossRealDropAnimationProfile>[
        for (int index = 0; index < profiles.length; index++)
          GlossRealDropAnimationProfile.fromJson(
            profiles[index],
            '\$.animation.profiles[$index]',
          ),
      ],
      extras: huiCollectExtras(map, const <String>{
        'enabled',
        'materialProperties',
        'profiles',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'enabled': enabled,
    'materialProperties': <String, dynamic>{
      for (final MapEntry<String, Map<String, GlossRealDropMaterialProperties>>
          propertyMap
          in materialProperties.entries)
        propertyMap.key: <String, dynamic>{
          for (final MapEntry<String, GlossRealDropMaterialProperties> entry
              in propertyMap.value.entries)
            entry.key: entry.value.toJson(),
        },
    },
    'profiles': <Map<String, dynamic>>[
      for (final GlossRealDropAnimationProfile profile in profiles)
        profile.toJson(),
    ],
  }, extras);

  GlossRealDropAnimation copy() => GlossRealDropAnimation.fromJson(toJson());
}

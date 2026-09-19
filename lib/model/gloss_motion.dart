library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

const List<String> glossMotionLoops = <String>['once', 'loop', 'pingpong'];
const List<String> glossMotionChannels = <String>[
  'translation.x',
  'translation.y',
  'translation.z',
  'rotation.x',
  'rotation.y',
  'rotation.z',
  'scale.x',
  'scale.y',
  'scale.z',
  'glow',
  'visible',
  'opacity',
  'brightness',
];
const List<String> glossMotionBlends = <String>['add', 'multiply', 'replace'];
const int glossMotionDefaultFps = 20;
const String glossMotionDefaultBone = 'root';
const String glossMotionDefaultLoop = 'loop';

bool looksLikeMotionDoc(Object? json) {
  if (json is! Map || json['schemaVersion'] is! num) return false;
  if (json.containsKey('bones') || json.containsKey('parts')) return false;
  return json['tracks'] is List;
}

GlossMotionDoc decodeGlossMotionDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': e.message,
    });
  }
  return GlossMotionDoc.fromJson(raw);
}

String encodeGlossMotionDoc(GlossMotionDoc doc) => huiWriteJson(doc.toJson());

GlossMotionDoc cloneGlossMotionDoc(GlossMotionDoc doc) =>
    GlossMotionDoc.fromJson(huiDeepCopy(doc.toJson()));

const Set<String> _docKnown = <String>{
  'schemaVersion',
  'revision',
  'durationTicks',
  'loop',
  'fps',
  'tracks',
};

final class GlossMotionKeyframe {
  GlossMotionKeyframe({
    this.tick = 0,
    this.value = 0,
    this.easing,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  double tick;
  Object? value;
  String? easing;
  Map<String, dynamic> extras;

  static GlossMotionKeyframe fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossMotionKeyframe(
      tick: huiReadDouble(map, 'tick'),
      value: map['value'],
      easing: map['easing'] is String ? map['easing'] as String : null,
      extras: huiCollectExtras(map, const <String>{'tick', 'value', 'easing'}),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'tick': tick,
    'value': value,
    if (easing != null && easing!.trim().isNotEmpty) 'easing': easing,
  }, extras);

  GlossMotionKeyframe copy() => GlossMotionKeyframe(
    tick: tick,
    value: value,
    easing: easing,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossMotionTrack {
  GlossMotionTrack({
    this.bone = glossMotionDefaultBone,
    this.channel = 'translation.y',
    this.blend = 'add',
    List<GlossMotionKeyframe>? keyframes,
    Map<String, dynamic>? extras,
  }) : keyframes = keyframes ?? <GlossMotionKeyframe>[],
       extras = extras ?? <String, dynamic>{};

  String bone;
  String channel;
  String blend;
  List<GlossMotionKeyframe> keyframes;
  Map<String, dynamic> extras;

  static GlossMotionTrack fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossMotionTrack(
      bone: huiReadString(map, 'bone', fallback: glossMotionDefaultBone),
      channel: huiReadString(map, 'channel', fallback: 'translation.y'),
      blend: huiReadString(map, 'blend', fallback: 'add'),
      keyframes: <GlossMotionKeyframe>[
        for (final (int index, Object? keyframe) in huiReadList(
          map['keyframes'],
        ).indexed)
          GlossMotionKeyframe.fromJson(keyframe, '$path.keyframes[$index]'),
      ],
      extras: huiCollectExtras(map, const <String>{
        'bone',
        'channel',
        'blend',
        'keyframes',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'bone': bone,
    'channel': channel,
    'blend': blend,
    'keyframes': <Map<String, dynamic>>[
      for (final GlossMotionKeyframe keyframe in keyframes) keyframe.toJson(),
    ],
  }, extras);

  GlossMotionTrack copy() => GlossMotionTrack(
    bone: bone,
    channel: channel,
    blend: blend,
    keyframes: <GlossMotionKeyframe>[
      for (final GlossMotionKeyframe keyframe in keyframes) keyframe.copy(),
    ],
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossMotionDoc extends GlossDoc {
  GlossMotionDoc({
    super.schemaVersion = glossCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    this.durationTicks,
    this.loop = glossMotionDefaultLoop,
    this.fps = glossMotionDefaultFps,
    List<GlossMotionTrack>? tracks,
    Map<String, dynamic>? extras,
  }) : tracks = tracks ?? <GlossMotionTrack>[],
       extras = extras ?? <String, dynamic>{};

  double? durationTicks;
  String loop;
  int fps;
  List<GlossMotionTrack> tracks;
  Map<String, dynamic> extras;

  static GlossMotionDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'motion');
    return GlossMotionDoc(
      schemaVersion: glossCurrentSchemaVersion,
      revision: glossReadRevision(map),
      durationTicks: huiReadDoubleOrNull(map, 'durationTicks'),
      loop: huiReadString(map, 'loop', fallback: glossMotionDefaultLoop),
      fps: map['fps'] == null
          ? glossMotionDefaultFps
          : huiReadInt(map, 'fps', fallback: glossMotionDefaultFps),
      tracks: <GlossMotionTrack>[
        for (final (int index, Object? track) in huiReadList(
          map['tracks'],
        ).indexed)
          GlossMotionTrack.fromJson(track, 'tracks[$index]'),
      ],
      extras: huiCollectExtras(map, _docKnown),
    );
  }

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'schemaVersion': schemaVersion,
    'revision': revision,
    if (durationTicks != null) 'durationTicks': durationTicks,
    'loop': loop,
    'fps': fps,
    'tracks': <Map<String, dynamic>>[
      for (final GlossMotionTrack track in tracks) track.toJson(),
    ],
  }, extras);
}

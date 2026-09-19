library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';
import 'vec3.dart';

const List<String> glossRigPartTypes = <String>['block', 'item', 'text'];
const List<String> glossRigBillboards = <String>[
  'fixed',
  'vertical',
  'horizontal',
  'center',
];

bool looksLikeRigDoc(Object? json) {
  if (json is! Map || json['schemaVersion'] is! num) return false;
  return json['bones'] is List && json['parts'] is List;
}

GlossRigDoc decodeGlossRigDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': e.message,
    });
  }
  return GlossRigDoc.fromJson(raw);
}

String encodeGlossRigDoc(GlossRigDoc doc) => huiWriteJson(doc.toJson());

GlossRigDoc cloneGlossRigDoc(GlossRigDoc doc) =>
    GlossRigDoc.fromJson(huiDeepCopy(doc.toJson()));

Vec3 _readVec3(Object? raw, double fallback) {
  if (raw is! List || raw.length != 3) {
    return Vec3(fallback, fallback, fallback);
  }
  return Vec3(
    raw[0] is num ? (raw[0] as num).toDouble() : fallback,
    raw[1] is num ? (raw[1] as num).toDouble() : fallback,
    raw[2] is num ? (raw[2] as num).toDouble() : fallback,
  );
}

final class GlossRigTransform {
  GlossRigTransform({
    Vec3? translation,
    Vec3? rotation,
    Vec3? scale,
    Map<String, dynamic>? extras,
  }) : translation = translation ?? Vec3.zero(),
       rotation = rotation ?? Vec3.zero(),
       scale = scale ?? Vec3(1, 1, 1),
       extras = extras ?? <String, dynamic>{};

  Vec3 translation;
  Vec3 rotation;
  Vec3 scale;
  Map<String, dynamic> extras;

  static GlossRigTransform fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossRigTransform(
      translation: _readVec3(map['translation'], 0),
      rotation: _readVec3(map['rotation'], 0),
      scale: _readVec3(map['scale'], 1),
      extras: huiCollectExtras(map, const <String>{
        'translation',
        'rotation',
        'scale',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'translation': translation.toJson(),
    'rotation': rotation.toJson(),
    'scale': scale.toJson(),
  }, extras);

  GlossRigTransform copy() => GlossRigTransform(
    translation: translation.copy(),
    rotation: rotation.copy(),
    scale: scale.copy(),
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossRigBone {
  GlossRigBone({
    this.id = 'root',
    this.parent,
    GlossRigTransform? rest,
    Map<String, dynamic>? extras,
  }) : rest = rest ?? GlossRigTransform(),
       extras = extras ?? <String, dynamic>{};

  String id;
  String? parent;
  GlossRigTransform rest;
  Map<String, dynamic> extras;

  static GlossRigBone fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    final String parent = huiReadString(map, 'parent');
    return GlossRigBone(
      id: huiReadString(map, 'id', fallback: 'root'),
      parent: parent.trim().isEmpty ? null : parent,
      rest: map['rest'] == null
          ? GlossRigTransform()
          : GlossRigTransform.fromJson(map['rest'], '$path.rest'),
      extras: huiCollectExtras(map, const <String>{'id', 'parent', 'rest'}),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'id': id,
    'parent': parent,
    'rest': rest.toJson(),
  }, extras);

  GlossRigBone copy() => GlossRigBone(
    id: id,
    parent: parent,
    rest: rest.copy(),
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossRigPart {
  GlossRigPart({
    this.id = '',
    this.bone = 'root',
    this.type = 'block',
    this.block,
    Map<String, dynamic>? item,
    this.text,
    GlossRigTransform? transform,
    this.billboard,
    this.brightness,
    Map<String, dynamic>? extras,
  }) : item = item ?? <String, dynamic>{},
       transform = transform ?? GlossRigTransform(),
       extras = extras ?? <String, dynamic>{};

  String id;
  String bone;
  String type;
  String? block;
  Map<String, dynamic> item;
  String? text;
  GlossRigTransform transform;
  String? billboard;
  int? brightness;
  Map<String, dynamic> extras;

  static GlossRigPart fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossRigPart(
      id: huiReadString(map, 'id'),
      bone: huiReadString(map, 'bone', fallback: 'root'),
      type: huiReadString(map, 'type', fallback: 'block'),
      block: map['block'] is String ? map['block'] as String : null,
      item: map['item'] is Map
          ? huiDeepCopyMap(huiReadObject(map['item'], '$path.item'))
          : <String, dynamic>{},
      text: map['text'] is String ? map['text'] as String : null,
      transform: map['transform'] == null
          ? GlossRigTransform()
          : GlossRigTransform.fromJson(map['transform'], '$path.transform'),
      billboard: map['billboard'] is String
          ? map['billboard'] as String
          : null,
      brightness: map['brightness'] == null
          ? null
          : huiReadInt(map, 'brightness'),
      extras: huiCollectExtras(map, const <String>{
        'id',
        'bone',
        'type',
        'block',
        'item',
        'text',
        'transform',
        'billboard',
        'brightness',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'id': id,
    'bone': bone,
    'type': type,
    if (block != null && block!.trim().isNotEmpty) 'block': block,
    if (item.isNotEmpty) 'item': huiDeepCopyMap(item),
    if (text != null) 'text': text,
    'transform': transform.toJson(),
    if (billboard != null && billboard!.trim().isNotEmpty)
      'billboard': billboard,
    if (brightness != null) 'brightness': brightness,
  }, extras);

  GlossRigPart copy() => GlossRigPart(
    id: id,
    bone: bone,
    type: type,
    block: block,
    item: huiDeepCopyMap(item),
    text: text,
    transform: transform.copy(),
    billboard: billboard,
    brightness: brightness,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossRigClip {
  GlossRigClip({
    this.motion = '',
    this.loop,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  String motion;
  String? loop;
  Map<String, dynamic> extras;

  static GlossRigClip fromJson(Object? raw, String path) {
    if (raw is String) {
      return GlossRigClip(motion: raw);
    }
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossRigClip(
      motion: huiReadString(map, 'motion'),
      loop: map['loop'] is String ? map['loop'] as String : null,
      extras: huiCollectExtras(map, const <String>{'motion', 'loop'}),
    );
  }

  Object toJsonValue() {
    if (loop == null || loop!.trim().isEmpty) return motion;
    return huiMergeExtras(<String, dynamic>{
      'motion': motion,
      'loop': loop,
    }, extras);
  }

  GlossRigClip copy() =>
      GlossRigClip(motion: motion, loop: loop, extras: huiDeepCopyMap(extras));
}

final class GlossRigDoc extends GlossDoc {
  GlossRigDoc({
    super.schemaVersion = glossCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    List<GlossRigBone>? bones,
    List<GlossRigPart>? parts,
    Map<String, GlossRigClip>? clips,
    Map<String, dynamic>? graph,
    List<Map<String, dynamic>>? hitboxes,
    Map<String, dynamic>? lod,
    Map<String, dynamic>? audience,
    Map<String, dynamic>? extras,
  }) : bones = bones ?? <GlossRigBone>[],
       parts = parts ?? <GlossRigPart>[],
       clips = clips ?? <String, GlossRigClip>{},
       graph = graph ?? <String, dynamic>{},
       hitboxes = hitboxes ?? <Map<String, dynamic>>[],
       lod = lod ?? <String, dynamic>{},
       audience = audience ?? <String, dynamic>{},
       extras = extras ?? <String, dynamic>{};

  List<GlossRigBone> bones;
  List<GlossRigPart> parts;
  Map<String, GlossRigClip> clips;
  Map<String, dynamic> graph;
  List<Map<String, dynamic>> hitboxes;
  Map<String, dynamic> lod;
  Map<String, dynamic> audience;
  Map<String, dynamic> extras;

  static GlossRigDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'rig');
    final Map<String, GlossRigClip> clips = <String, GlossRigClip>{};
    if (map['clips'] is Map) {
      (map['clips'] as Map).forEach((Object? key, Object? value) {
        clips[key.toString()] = GlossRigClip.fromJson(
          value,
          'clips.${key.toString()}',
        );
      });
    }
    return GlossRigDoc(
      schemaVersion: glossCurrentSchemaVersion,
      revision: glossReadRevision(map),
      bones: <GlossRigBone>[
        for (final (int index, Object? bone) in huiReadList(
          map['bones'],
        ).indexed)
          GlossRigBone.fromJson(bone, 'bones[$index]'),
      ],
      parts: <GlossRigPart>[
        for (final (int index, Object? part) in huiReadList(
          map['parts'],
        ).indexed)
          GlossRigPart.fromJson(part, 'parts[$index]'),
      ],
      clips: clips,
      graph: map['graph'] is Map
          ? huiDeepCopyMap(huiReadObject(map['graph'], r'$.graph'))
          : <String, dynamic>{},
      hitboxes: <Map<String, dynamic>>[
        for (final Object? hitbox in huiReadList(map['hitboxes']))
          if (hitbox is Map)
            huiDeepCopyMap(huiReadObject(hitbox, r'$.hitboxes')),
      ],
      lod: map['lod'] is Map
          ? huiDeepCopyMap(huiReadObject(map['lod'], r'$.lod'))
          : <String, dynamic>{},
      audience: map['audience'] is Map
          ? huiDeepCopyMap(huiReadObject(map['audience'], r'$.audience'))
          : <String, dynamic>{},
      extras: huiCollectExtras(map, const <String>{
        'schemaVersion',
        'revision',
        'bones',
        'parts',
        'clips',
        'graph',
        'hitboxes',
        'lod',
        'audience',
      }),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, Object> clipsJson = <String, Object>{
      for (final MapEntry<String, GlossRigClip> entry in clips.entries)
        entry.key: entry.value.toJsonValue(),
    };
    return huiMergeExtras(<String, dynamic>{
      'schemaVersion': schemaVersion,
      'revision': revision,
      'bones': <Map<String, dynamic>>[
        for (final GlossRigBone bone in bones) bone.toJson(),
      ],
      'parts': <Map<String, dynamic>>[
        for (final GlossRigPart part in parts) part.toJson(),
      ],
      if (clipsJson.isNotEmpty) 'clips': clipsJson,
      if (graph.isNotEmpty) 'graph': huiDeepCopyMap(graph),
      if (hitboxes.isNotEmpty)
        'hitboxes': <Map<String, dynamic>>[
          for (final Map<String, dynamic> hitbox in hitboxes)
            huiDeepCopyMap(hitbox),
        ],
      if (lod.isNotEmpty) 'lod': huiDeepCopyMap(lod),
      if (audience.isNotEmpty) 'audience': huiDeepCopyMap(audience),
    }, extras);
  }
}

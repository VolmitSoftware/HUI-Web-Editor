library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

const List<String> glossNametagVisibilities = <String>[
  'always',
  'never',
  'hide_for_other_teams',
  'hide_for_own_team',
];

const List<String> glossNametagCollisions = <String>[
  'always',
  'never',
  'push_other_teams',
  'push_own_team',
];

bool looksLikeNametagDoc(Object? json) {
  if (json is! Map || json['schemaVersion'] is! num) return false;
  final Object? presentation = json['presentation'];
  if (presentation is! Map) return false;
  return presentation.containsKey('prefix') ||
      presentation.containsKey('suffix') ||
      presentation.containsKey('nameTagVisibility') ||
      presentation.containsKey('collision');
}

GlossNametagDoc decodeGlossNametagDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': e.message,
    });
  }
  return GlossNametagDoc.fromJson(raw);
}

String encodeGlossNametagDoc(GlossNametagDoc doc) => huiWriteJson(doc.toJson());

GlossNametagDoc cloneGlossNametagDoc(GlossNametagDoc doc) =>
    GlossNametagDoc.fromJson(huiDeepCopy(doc.toJson()));

const Set<String> _docKnown = <String>{
  'schemaVersion',
  'revision',
  'select',
  'presentation',
  'variants',
};

final class GlossNametagPresentation {
  GlossNametagPresentation({
    this.prefix = '',
    this.suffix = '',
    this.color = 'white',
    this.nameTagVisibility = 'always',
    this.collision = 'always',
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  String prefix;
  String suffix;
  String color;
  String nameTagVisibility;
  String collision;
  Map<String, dynamic> extras;

  static GlossNametagPresentation fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossNametagPresentation(
      prefix: huiReadString(map, 'prefix'),
      suffix: huiReadString(map, 'suffix'),
      color: huiReadString(map, 'color', fallback: 'white'),
      nameTagVisibility: huiReadString(
        map,
        'nameTagVisibility',
        fallback: 'always',
      ),
      collision: huiReadString(map, 'collision', fallback: 'always'),
      extras: huiCollectExtras(map, const <String>{
        'prefix',
        'suffix',
        'color',
        'nameTagVisibility',
        'collision',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'prefix': prefix,
    'suffix': suffix,
    'color': color,
    'nameTagVisibility': nameTagVisibility,
    'collision': collision,
  }, extras);

  GlossNametagPresentation copy() => GlossNametagPresentation(
    prefix: prefix,
    suffix: suffix,
    color: color,
    nameTagVisibility: nameTagVisibility,
    collision: collision,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossNametagVariant {
  GlossNametagVariant({
    this.id = '',
    this.priority = 0,
    this.when = 'false',
    GlossNametagPresentation? presentation,
    Map<String, dynamic>? extras,
  }) : presentation = presentation ?? GlossNametagPresentation(),
       extras = extras ?? <String, dynamic>{};

  String id;
  int priority;
  String when;
  GlossNametagPresentation presentation;
  Map<String, dynamic> extras;

  static GlossNametagVariant fromJson(Object? raw, int index) {
    final String path = r'$.variants[' + '$index]';
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossNametagVariant(
      id: huiReadString(map, 'id'),
      priority: huiReadInt(map, 'priority'),
      when: huiReadString(map, 'when', fallback: 'false'),
      presentation: GlossNametagPresentation.fromJson(
        map['presentation'],
        '$path.presentation',
      ),
      extras: huiCollectExtras(map, const <String>{
        'id',
        'priority',
        'when',
        'presentation',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'id': id,
    'priority': priority,
    'when': when,
    'presentation': presentation.toJson(),
  }, extras);

  GlossNametagVariant copy() => GlossNametagVariant(
    id: id,
    priority: priority,
    when: when,
    presentation: presentation.copy(),
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossNametagDoc extends GlossDoc {
  GlossNametagDoc({
    super.schemaVersion = glossCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    GlossPrioritySelect? select,
    GlossNametagPresentation? presentation,
    List<GlossNametagVariant>? variants,
    Map<String, dynamic>? extras,
  }) : select = select ?? GlossPrioritySelect(),
       presentation = presentation ?? GlossNametagPresentation(),
       variants = variants ?? <GlossNametagVariant>[],
       extras = extras ?? <String, dynamic>{};

  GlossPrioritySelect select;
  GlossNametagPresentation presentation;
  List<GlossNametagVariant> variants;
  Map<String, dynamic> extras;

  static GlossNametagDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'nametag');
    return GlossNametagDoc(
      schemaVersion: glossCurrentSchemaVersion,
      revision: glossReadRevision(map),
      select: map['select'] == null
          ? GlossPrioritySelect()
          : GlossPrioritySelect.fromJson(map['select']),
      presentation: GlossNametagPresentation.fromJson(
        map['presentation'],
        r'$.presentation',
      ),
      variants: <GlossNametagVariant>[
        for (final (int index, Object? variant) in huiReadList(
          map['variants'],
        ).indexed)
          GlossNametagVariant.fromJson(variant, index),
      ],
      extras: huiCollectExtras(map, _docKnown),
    );
  }

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'schemaVersion': schemaVersion,
    'revision': revision,
    'select': select.toJson(),
    'presentation': presentation.toJson(),
    'variants': <Map<String, dynamic>>[
      for (final GlossNametagVariant variant in variants) variant.toJson(),
    ],
  }, extras);
}

library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

const int glossNameplateMaxLines = 16;
const double glossNameplateDefaultOffset = 0.3;

bool looksLikeNameplateDoc(Object? json) {
  if (json is! Map || json['schemaVersion'] is! num) return false;
  if (json.containsKey('surface') || json.containsKey('anchor')) return false;
  final Object? presentation = json['presentation'];
  if (presentation is! Map) return false;
  if (presentation.containsKey('prefix') ||
      presentation.containsKey('suffix') ||
      presentation.containsKey('nameTagVisibility') ||
      presentation.containsKey('title') ||
      presentation.containsKey('hideNumbers')) {
    return false;
  }
  return presentation.containsKey('lines') ||
      presentation.containsKey('offset') ||
      presentation.containsKey('hideSneaking') ||
      presentation.containsKey('relations');
}

GlossNameplateDoc decodeGlossNameplateDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': e.message,
    });
  }
  return GlossNameplateDoc.fromJson(raw);
}

String encodeGlossNameplateDoc(GlossNameplateDoc doc) =>
    huiWriteJson(doc.toJson());

GlossNameplateDoc cloneGlossNameplateDoc(GlossNameplateDoc doc) =>
    GlossNameplateDoc.fromJson(huiDeepCopy(doc.toJson()));

const Set<String> _docKnown = <String>{
  'schemaVersion',
  'revision',
  'select',
  'presentation',
  'variants',
};

final class GlossNameplateLine {
  GlossNameplateLine({
    this.text = '',
    this.show = 'true',
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  String text;
  Object? show;
  Map<String, dynamic> extras;

  static GlossNameplateLine fromJson(Object? raw, String path) {
    if (raw is String) {
      return GlossNameplateLine(text: raw);
    }
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossNameplateLine(
      text: huiReadString(map, 'text'),
      show: map.containsKey('show') ? map['show'] : 'true',
      extras: huiCollectExtras(map, const <String>{'text', 'show'}),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'text': text,
    if (show != null) 'show': show,
  }, extras);

  GlossNameplateLine copy() => GlossNameplateLine(
    text: text,
    show: show,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossNameplateRelation {
  GlossNameplateRelation({
    this.when = 'true',
    this.color = '',
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  String when;
  String color;
  Map<String, dynamic> extras;

  static GlossNameplateRelation fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossNameplateRelation(
      when: huiReadString(map, 'when', fallback: 'true'),
      color: huiReadString(map, 'color'),
      extras: huiCollectExtras(map, const <String>{'when', 'color'}),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'when': when,
    'color': color,
  }, extras);

  GlossNameplateRelation copy() => GlossNameplateRelation(
    when: when,
    color: color,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossNameplatePresentation {
  GlossNameplatePresentation({
    List<GlossNameplateLine>? lines,
    this.offset = glossNameplateDefaultOffset,
    this.hideSneaking = true,
    List<GlossNameplateRelation>? relations,
    Map<String, dynamic>? extras,
  }) : lines = lines ?? <GlossNameplateLine>[],
       relations = relations ?? <GlossNameplateRelation>[],
       extras = extras ?? <String, dynamic>{};

  List<GlossNameplateLine> lines;
  double offset;
  bool hideSneaking;
  List<GlossNameplateRelation> relations;
  Map<String, dynamic> extras;

  static GlossNameplatePresentation fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossNameplatePresentation(
      lines: <GlossNameplateLine>[
        for (final (int index, Object? line) in huiReadList(
          map['lines'],
        ).indexed)
          GlossNameplateLine.fromJson(line, '$path.lines[$index]'),
      ],
      offset: map['offset'] == null
          ? glossNameplateDefaultOffset
          : huiReadDouble(map, 'offset', fallback: glossNameplateDefaultOffset),
      hideSneaking: map['hideSneaking'] == null
          ? true
          : huiReadBool(map, 'hideSneaking'),
      relations: <GlossNameplateRelation>[
        for (final (int index, Object? relation) in huiReadList(
          map['relations'],
        ).indexed)
          GlossNameplateRelation.fromJson(relation, '$path.relations[$index]'),
      ],
      extras: huiCollectExtras(map, const <String>{
        'lines',
        'offset',
        'hideSneaking',
        'relations',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'lines': <Map<String, dynamic>>[
      for (final GlossNameplateLine line in lines) line.toJson(),
    ],
    'offset': offset,
    'hideSneaking': hideSneaking,
    if (relations.isNotEmpty)
      'relations': <Map<String, dynamic>>[
        for (final GlossNameplateRelation relation in relations)
          relation.toJson(),
      ],
  }, extras);

  GlossNameplatePresentation copy() => GlossNameplatePresentation(
    lines: <GlossNameplateLine>[
      for (final GlossNameplateLine line in lines) line.copy(),
    ],
    offset: offset,
    hideSneaking: hideSneaking,
    relations: <GlossNameplateRelation>[
      for (final GlossNameplateRelation relation in relations) relation.copy(),
    ],
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossNameplateVariant {
  GlossNameplateVariant({
    this.id = '',
    this.priority = 0,
    this.when = 'true',
    GlossNameplatePresentation? presentation,
    Map<String, dynamic>? extras,
  }) : presentation = presentation ?? GlossNameplatePresentation(),
       extras = extras ?? <String, dynamic>{};

  String id;
  int priority;
  String when;
  GlossNameplatePresentation presentation;
  Map<String, dynamic> extras;

  static GlossNameplateVariant fromJson(Object? raw, int index) {
    final String path = r'$.variants[' + '$index]';
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossNameplateVariant(
      id: huiReadString(map, 'id'),
      priority: huiReadInt(map, 'priority'),
      when: huiReadString(map, 'when', fallback: 'true'),
      presentation: GlossNameplatePresentation.fromJson(
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

  GlossNameplateVariant copy() => GlossNameplateVariant(
    id: id,
    priority: priority,
    when: when,
    presentation: presentation.copy(),
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossNameplateDoc extends GlossDoc {
  GlossNameplateDoc({
    super.schemaVersion = glossCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    GlossPrioritySelect? select,
    GlossNameplatePresentation? presentation,
    List<GlossNameplateVariant>? variants,
    Map<String, dynamic>? extras,
  }) : select = select ?? GlossPrioritySelect(when: 'true'),
       presentation = presentation ?? GlossNameplatePresentation(),
       variants = variants ?? <GlossNameplateVariant>[],
       extras = extras ?? <String, dynamic>{};

  GlossPrioritySelect select;
  GlossNameplatePresentation presentation;
  List<GlossNameplateVariant> variants;
  Map<String, dynamic> extras;

  static GlossNameplateDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'nameplate');
    return GlossNameplateDoc(
      schemaVersion: glossCurrentSchemaVersion,
      revision: glossReadRevision(map),
      select: map['select'] == null
          ? GlossPrioritySelect(when: 'true')
          : GlossPrioritySelect.fromJson(map['select'], fallbackWhen: 'true'),
      presentation: GlossNameplatePresentation.fromJson(
        map['presentation'],
        r'$.presentation',
      ),
      variants: <GlossNameplateVariant>[
        for (final (int index, Object? variant) in huiReadList(
          map['variants'],
        ).indexed)
          GlossNameplateVariant.fromJson(variant, index),
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
      for (final GlossNameplateVariant variant in variants) variant.toJson(),
    ],
  }, extras);
}

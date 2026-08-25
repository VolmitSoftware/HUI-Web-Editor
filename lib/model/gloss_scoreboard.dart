library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

const int glossScoreboardCurrentSchemaVersion = 2;
const int glossBoardMaxLines = 15;
const int glossBoardMaxTitleLength = 32;

int glossBoardScoreForRow(int index) => glossBoardMaxLines - index;

bool looksLikeScoreboardDoc(Object? json) {
  if (json is! Map || json['schemaVersion'] is! num) return false;
  if (json.containsKey('anchor') ||
      json.containsKey('frames') ||
      json.containsKey('components') ||
      json.containsKey('elements')) {
    return false;
  }
  return json.containsKey('select') &&
      json.containsKey('presentation') &&
      json.containsKey('variants');
}

GlossScoreboardDoc decodeGlossScoreboardDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (error) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': error.message,
    });
  }
  return GlossScoreboardDoc.fromJson(raw);
}

String encodeGlossScoreboardDoc(GlossScoreboardDoc doc) =>
    huiWriteJson(doc.toJson());

GlossScoreboardDoc cloneGlossScoreboardDoc(GlossScoreboardDoc doc) =>
    GlossScoreboardDoc.fromJson(huiDeepCopy(doc.toJson()));

const Set<String> _docKnown = <String>{
  'schemaVersion',
  'revision',
  'select',
  'presentation',
  'variants',
};
const Set<String> _selectKnown = <String>{'priority', 'when'};
const Set<String> _presentationKnown = <String>{
  'title',
  'lines',
  'hideNumbers',
};
const Set<String> _variantKnown = <String>{
  'id',
  'priority',
  'when',
  'presentation',
};

final class GlossScoreboardSelect {
  GlossScoreboardSelect({
    this.priority = 0,
    this.when = 'false',
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  int priority;
  String when;
  Map<String, dynamic> extras;

  static GlossScoreboardSelect fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$.select');
    return GlossScoreboardSelect(
      priority: huiReadInt(map, 'priority'),
      when: huiReadString(map, 'when', fallback: 'false'),
      extras: huiCollectExtras(map, _selectKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'priority': priority,
    'when': when,
  }, extras);

  GlossScoreboardSelect copy() => GlossScoreboardSelect(
    priority: priority,
    when: when,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossScoreboardPresentation {
  GlossScoreboardPresentation({
    this.title = '',
    List<String>? lines,
    this.hideNumbers = false,
    Map<String, dynamic>? extras,
  }) : lines = lines ?? <String>[],
       extras = extras ?? <String, dynamic>{};

  String title;
  List<String> lines;
  bool hideNumbers;
  Map<String, dynamic> extras;

  static GlossScoreboardPresentation fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossScoreboardPresentation(
      title: huiReadString(map, 'title'),
      lines: glossReadStringList(map['lines']),
      hideNumbers: huiReadBool(map, 'hideNumbers'),
      extras: huiCollectExtras(map, _presentationKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'title': title,
    'lines': List<String>.of(lines),
    'hideNumbers': hideNumbers,
  }, extras);

  GlossScoreboardPresentation copy() => GlossScoreboardPresentation(
    title: title,
    lines: List<String>.of(lines),
    hideNumbers: hideNumbers,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossScoreboardVariant {
  GlossScoreboardVariant({
    this.id = '',
    this.priority = 0,
    this.when = 'false',
    GlossScoreboardPresentation? presentation,
    Map<String, dynamic>? extras,
  }) : presentation = presentation ?? GlossScoreboardPresentation(),
       extras = extras ?? <String, dynamic>{};

  String id;
  int priority;
  String when;
  GlossScoreboardPresentation presentation;
  Map<String, dynamic> extras;

  static GlossScoreboardVariant fromJson(Object? raw, int index) {
    final String path =
        r'$'
        '.variants['
        '$index]';
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossScoreboardVariant(
      id: huiReadString(map, 'id'),
      priority: huiReadInt(map, 'priority'),
      when: huiReadString(map, 'when', fallback: 'false'),
      presentation: GlossScoreboardPresentation.fromJson(
        map['presentation'],
        '$path.presentation',
      ),
      extras: huiCollectExtras(map, _variantKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'id': id,
    'priority': priority,
    'when': when,
    'presentation': presentation.toJson(),
  }, extras);

  GlossScoreboardVariant copy() => GlossScoreboardVariant(
    id: id,
    priority: priority,
    when: when,
    presentation: presentation.copy(),
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossScoreboardDoc extends GlossDoc {
  GlossScoreboardDoc({
    super.schemaVersion = glossScoreboardCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    GlossScoreboardSelect? select,
    GlossScoreboardPresentation? presentation,
    List<GlossScoreboardVariant>? variants,
    Map<String, dynamic>? extras,
  }) : select = select ?? GlossScoreboardSelect(),
       presentation = presentation ?? GlossScoreboardPresentation(),
       variants = variants ?? <GlossScoreboardVariant>[],
       extras = extras ?? <String, dynamic>{};

  GlossScoreboardSelect select;
  GlossScoreboardPresentation presentation;
  List<GlossScoreboardVariant> variants;
  Map<String, dynamic> extras;

  static GlossScoreboardDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(
      map,
      'scoreboard',
      expected: glossScoreboardCurrentSchemaVersion,
    );
    final List<Object?> rawVariants = huiReadList(map['variants']);
    return GlossScoreboardDoc(
      schemaVersion: glossScoreboardCurrentSchemaVersion,
      revision: glossReadRevision(map),
      select: GlossScoreboardSelect.fromJson(map['select']),
      presentation: GlossScoreboardPresentation.fromJson(
        map['presentation'],
        r'$.presentation',
      ),
      variants: <GlossScoreboardVariant>[
        for (int index = 0; index < rawVariants.length; index++)
          GlossScoreboardVariant.fromJson(rawVariants[index], index),
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
      for (final GlossScoreboardVariant variant in variants) variant.toJson(),
    ],
  }, extras);

  GlossScoreboardDoc copy() => GlossScoreboardDoc(
    schemaVersion: schemaVersion,
    revision: revision,
    select: select.copy(),
    presentation: presentation.copy(),
    variants: <GlossScoreboardVariant>[
      for (final GlossScoreboardVariant variant in variants) variant.copy(),
    ],
    extras: huiDeepCopyMap(extras),
  );
}

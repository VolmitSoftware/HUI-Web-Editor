library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

const int glossScoreboardCurrentSchemaVersion = 2;
const int glossBoardMaxLines = 15;

int glossBoardScoreForRow(int index) => glossBoardMaxLines - index;

bool looksLikeScoreboardDoc(Object? json) {
  if (json is! Map || json['schemaVersion'] is! num) return false;
  if (json.containsKey('anchor') ||
      json.containsKey('frames') ||
      json.containsKey('components') ||
      json.containsKey('elements') ||
      // A surface document carries the same select/presentation/variants
      // triple; its `surface` discriminator is what tells the two apart.
      json.containsKey('surface')) {
    return false;
  }
  if (!json.containsKey('select') ||
      !json.containsKey('presentation') ||
      !json.containsKey('variants')) {
    return false;
  }
  final Object? presentation = json['presentation'];
  if (presentation is! Map) return false;
  if (presentation.containsKey('prefix') ||
      presentation.containsKey('suffix') ||
      presentation.containsKey('nameTagVisibility') ||
      presentation.containsKey('offset') ||
      presentation.containsKey('hideSneaking') ||
      presentation.containsKey('relations')) {
    return false;
  }
  if (presentation.containsKey('title') ||
      presentation.containsKey('hideNumbers')) {
    return true;
  }
  final Object? lines = presentation['lines'];
  if (lines is! List || lines.isEmpty) return false;
  return lines.first is String ||
      json['schemaVersion'] == glossScoreboardCurrentSchemaVersion &&
          lines.first is Map;
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

final class GlossScoreboardLine {
  GlossScoreboardLine({
    this.text = '',
    this.value,
    this.format,
    this.id,
    this.show = true,
    this.section,
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};

  String text;
  String? value;
  String? format;
  String? id;
  Object show;
  String? section;
  Map<String, Object?> extras;

  static GlossScoreboardLine fromJson(Object? raw, String path) {
    if (raw == null || raw is String) {
      return GlossScoreboardLine(text: raw as String? ?? '');
    }
    final Map<String, Object?> map = huiReadObject(raw, path);
    final Object show = map['show'] ?? true;
    if (show is! bool && show is! String) {
      throw HuiFormatException(
        'Show must be a boolean or expression.',
        '$path.show',
      );
    }
    return GlossScoreboardLine(
      text: huiReadString(map, 'text'),
      value: map['value'] == null ? null : huiReadString(map, 'value'),
      format: map['format'] == null ? null : huiReadString(map, 'format'),
      id: map['id'] == null ? null : huiReadString(map, 'id'),
      show: show,
      section: map['section'] == null ? null : huiReadString(map, 'section'),
      extras: huiCollectExtras(map, const <String>{
        'text',
        'value',
        'format',
        'id',
        'show',
        'section',
      }),
    );
  }

  Object toJson() {
    if (value == null &&
        format == null &&
        id == null &&
        show == true &&
        section == null &&
        extras.isEmpty) {
      return text;
    }
    return <String, Object?>{
      if (section == null || text.isNotEmpty) 'text': text,
      if (section != null) 'section': section,
      if (value != null) 'value': value,
      if (format != null) 'format': format,
      if (id != null) 'id': id,
      if (show != true) 'show': show,
      ...extras,
    };
  }

  GlossScoreboardLine copy() =>
      GlossScoreboardLine.fromJson(huiDeepCopy(toJson()), r'$.line');
}

List<GlossScoreboardLine> glossScoreboardLines(Iterable<String> text) =>
    <GlossScoreboardLine>[
      for (final String line in text) GlossScoreboardLine(text: line),
    ];

final class GlossScoreboardPresentation {
  GlossScoreboardPresentation({
    this.title = '',
    List<GlossScoreboardLine>? lines,
    this.hideNumbers = false,
    Map<String, dynamic>? extras,
  }) : lines = lines ?? <GlossScoreboardLine>[],
       extras = extras ?? <String, dynamic>{};

  String title;
  List<GlossScoreboardLine> lines;
  bool hideNumbers;
  Map<String, dynamic> extras;

  static GlossScoreboardPresentation fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossScoreboardPresentation(
      title: huiReadString(map, 'title'),
      lines: <GlossScoreboardLine>[
        for (final (int index, Object? line) in huiReadList(
          map['lines'],
        ).indexed)
          GlossScoreboardLine.fromJson(line, '$path.lines[$index]'),
      ],
      hideNumbers: huiReadBool(map, 'hideNumbers'),
      extras: huiCollectExtras(map, _presentationKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'title': title,
    'lines': <Object>[
      for (final GlossScoreboardLine line in lines) line.toJson(),
    ],
    'hideNumbers': hideNumbers,
  }, extras);

  GlossScoreboardPresentation copy() => GlossScoreboardPresentation(
    title: title,
    lines: <GlossScoreboardLine>[
      for (final GlossScoreboardLine line in lines) line.copy(),
    ],
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

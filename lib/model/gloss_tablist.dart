library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

const int glossTablistCurrentSchemaVersion = 2;
const String glossTablistFallbackFormat = r'$player';

bool looksLikeTablistDoc(Object? json) {
  if (json is! Map || json['schemaVersion'] is! num) return false;
  if (json.containsKey('anchor') ||
      json.containsKey('frames') ||
      json.containsKey('entries') ||
      json.containsKey('emoji') ||
      json.containsKey('components') ||
      json.containsKey('elements')) {
    return false;
  }
  return json.containsKey('headerFooter') && json.containsKey('listNames');
}

GlossTablistDoc decodeGlossTablistDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (error) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': error.message,
    });
  }
  return GlossTablistDoc.fromJson(raw);
}

String encodeGlossTablistDoc(GlossTablistDoc doc) => huiWriteJson(doc.toJson());

GlossTablistDoc cloneGlossTablistDoc(GlossTablistDoc doc) =>
    GlossTablistDoc.fromJson(huiDeepCopy(doc.toJson()));

const Set<String> _docKnown = <String>{
  'schemaVersion',
  'revision',
  'headerFooter',
  'listNames',
};
const Set<String> _sectionKnown = <String>{
  'enabled',
  'presentation',
  'variants',
};
const Set<String> _variantKnown = <String>{
  'id',
  'priority',
  'when',
  'presentation',
};
const Set<String> _headerFooterPresentationKnown = <String>{'header', 'footer'};
const Set<String> _listNamePresentationKnown = <String>{'format'};

abstract interface class GlossConditionalVariant {
  String get id;
  int get priority;
  String get when;
}

final class GlossTablistHeaderFooterPresentation {
  GlossTablistHeaderFooterPresentation({
    this.header = '',
    this.footer = '',
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  String header;
  String footer;
  Map<String, dynamic> extras;

  static GlossTablistHeaderFooterPresentation fromJson(
    Object? raw,
    String path,
  ) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossTablistHeaderFooterPresentation(
      header: huiReadString(map, 'header'),
      footer: huiReadString(map, 'footer'),
      extras: huiCollectExtras(map, _headerFooterPresentationKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'header': header,
    'footer': footer,
  }, extras);

  GlossTablistHeaderFooterPresentation copy() =>
      GlossTablistHeaderFooterPresentation(
        header: header,
        footer: footer,
        extras: huiDeepCopyMap(extras),
      );
}

final class GlossTablistListNamePresentation {
  GlossTablistListNamePresentation({
    this.format = glossTablistFallbackFormat,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  String format;
  Map<String, dynamic> extras;

  static GlossTablistListNamePresentation fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossTablistListNamePresentation(
      format: huiReadString(
        map,
        'format',
        fallback: glossTablistFallbackFormat,
      ),
      extras: huiCollectExtras(map, _listNamePresentationKnown),
    );
  }

  Map<String, dynamic> toJson() =>
      huiMergeExtras(<String, dynamic>{'format': format}, extras);

  GlossTablistListNamePresentation copy() => GlossTablistListNamePresentation(
    format: format,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossTablistHeaderFooterVariant implements GlossConditionalVariant {
  GlossTablistHeaderFooterVariant({
    this.id = '',
    this.priority = 0,
    this.when = 'false',
    GlossTablistHeaderFooterPresentation? presentation,
    Map<String, dynamic>? extras,
  }) : presentation = presentation ?? GlossTablistHeaderFooterPresentation(),
       extras = extras ?? <String, dynamic>{};

  @override
  String id;
  @override
  int priority;
  @override
  String when;
  GlossTablistHeaderFooterPresentation presentation;
  Map<String, dynamic> extras;

  static GlossTablistHeaderFooterVariant fromJson(Object? raw, int index) {
    final String path =
        r'$'
        '.headerFooter.variants['
        '$index]';
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossTablistHeaderFooterVariant(
      id: huiReadString(map, 'id'),
      priority: huiReadInt(map, 'priority'),
      when: huiReadString(map, 'when', fallback: 'false'),
      presentation: GlossTablistHeaderFooterPresentation.fromJson(
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

  GlossTablistHeaderFooterVariant copy() => GlossTablistHeaderFooterVariant(
    id: id,
    priority: priority,
    when: when,
    presentation: presentation.copy(),
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossTablistListNameVariant implements GlossConditionalVariant {
  GlossTablistListNameVariant({
    this.id = '',
    this.priority = 0,
    this.when = 'false',
    GlossTablistListNamePresentation? presentation,
    Map<String, dynamic>? extras,
  }) : presentation = presentation ?? GlossTablistListNamePresentation(),
       extras = extras ?? <String, dynamic>{};

  @override
  String id;
  @override
  int priority;
  @override
  String when;
  GlossTablistListNamePresentation presentation;
  Map<String, dynamic> extras;

  static GlossTablistListNameVariant fromJson(Object? raw, int index) {
    final String path =
        r'$'
        '.listNames.variants['
        '$index]';
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossTablistListNameVariant(
      id: huiReadString(map, 'id'),
      priority: huiReadInt(map, 'priority'),
      when: huiReadString(map, 'when', fallback: 'false'),
      presentation: GlossTablistListNamePresentation.fromJson(
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

  GlossTablistListNameVariant copy() => GlossTablistListNameVariant(
    id: id,
    priority: priority,
    when: when,
    presentation: presentation.copy(),
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossTablistHeaderFooter {
  GlossTablistHeaderFooter({
    this.enabled = false,
    GlossTablistHeaderFooterPresentation? presentation,
    List<GlossTablistHeaderFooterVariant>? variants,
    Map<String, dynamic>? extras,
  }) : presentation = presentation ?? GlossTablistHeaderFooterPresentation(),
       variants = variants ?? <GlossTablistHeaderFooterVariant>[],
       extras = extras ?? <String, dynamic>{};

  bool enabled;
  GlossTablistHeaderFooterPresentation presentation;
  List<GlossTablistHeaderFooterVariant> variants;
  Map<String, dynamic> extras;

  static GlossTablistHeaderFooter fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$.headerFooter');
    final List<Object?> rawVariants = huiReadList(map['variants']);
    return GlossTablistHeaderFooter(
      enabled: huiReadBool(map, 'enabled'),
      presentation: GlossTablistHeaderFooterPresentation.fromJson(
        map['presentation'],
        r'$.headerFooter.presentation',
      ),
      variants: <GlossTablistHeaderFooterVariant>[
        for (int index = 0; index < rawVariants.length; index++)
          GlossTablistHeaderFooterVariant.fromJson(rawVariants[index], index),
      ],
      extras: huiCollectExtras(map, _sectionKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'enabled': enabled,
    'presentation': presentation.toJson(),
    'variants': <Map<String, dynamic>>[
      for (final GlossTablistHeaderFooterVariant variant in variants)
        variant.toJson(),
    ],
  }, extras);

  GlossTablistHeaderFooter copy() => GlossTablistHeaderFooter(
    enabled: enabled,
    presentation: presentation.copy(),
    variants: <GlossTablistHeaderFooterVariant>[
      for (final GlossTablistHeaderFooterVariant variant in variants)
        variant.copy(),
    ],
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossTablistListNames {
  GlossTablistListNames({
    this.enabled = false,
    GlossTablistListNamePresentation? presentation,
    List<GlossTablistListNameVariant>? variants,
    Map<String, dynamic>? extras,
  }) : presentation = presentation ?? GlossTablistListNamePresentation(),
       variants = variants ?? <GlossTablistListNameVariant>[],
       extras = extras ?? <String, dynamic>{};

  bool enabled;
  GlossTablistListNamePresentation presentation;
  List<GlossTablistListNameVariant> variants;
  Map<String, dynamic> extras;

  static GlossTablistListNames fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$.listNames');
    final List<Object?> rawVariants = huiReadList(map['variants']);
    return GlossTablistListNames(
      enabled: huiReadBool(map, 'enabled'),
      presentation: GlossTablistListNamePresentation.fromJson(
        map['presentation'],
        r'$.listNames.presentation',
      ),
      variants: <GlossTablistListNameVariant>[
        for (int index = 0; index < rawVariants.length; index++)
          GlossTablistListNameVariant.fromJson(rawVariants[index], index),
      ],
      extras: huiCollectExtras(map, _sectionKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'enabled': enabled,
    'presentation': presentation.toJson(),
    'variants': <Map<String, dynamic>>[
      for (final GlossTablistListNameVariant variant in variants)
        variant.toJson(),
    ],
  }, extras);

  GlossTablistListNames copy() => GlossTablistListNames(
    enabled: enabled,
    presentation: presentation.copy(),
    variants: <GlossTablistListNameVariant>[
      for (final GlossTablistListNameVariant variant in variants)
        variant.copy(),
    ],
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossTablistDoc extends GlossDoc {
  GlossTablistDoc({
    super.schemaVersion = glossTablistCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    GlossTablistHeaderFooter? headerFooter,
    GlossTablistListNames? listNames,
    Map<String, dynamic>? extras,
  }) : headerFooter = headerFooter ?? GlossTablistHeaderFooter(),
       listNames = listNames ?? GlossTablistListNames(),
       extras = extras ?? <String, dynamic>{};

  GlossTablistHeaderFooter headerFooter;
  GlossTablistListNames listNames;
  Map<String, dynamic> extras;

  static GlossTablistDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(
      map,
      'tablist',
      expected: glossTablistCurrentSchemaVersion,
    );
    return GlossTablistDoc(
      schemaVersion: glossTablistCurrentSchemaVersion,
      revision: glossReadRevision(map),
      headerFooter: GlossTablistHeaderFooter.fromJson(map['headerFooter']),
      listNames: GlossTablistListNames.fromJson(map['listNames']),
      extras: huiCollectExtras(map, _docKnown),
    );
  }

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'schemaVersion': schemaVersion,
    'revision': revision,
    'headerFooter': headerFooter.toJson(),
    'listNames': listNames.toJson(),
  }, extras);

  GlossTablistDoc copy() => GlossTablistDoc(
    schemaVersion: schemaVersion,
    revision: revision,
    headerFooter: headerFooter.copy(),
    listNames: listNames.copy(),
    extras: huiDeepCopyMap(extras),
  );
}

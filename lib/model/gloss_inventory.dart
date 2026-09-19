library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

const List<String> glossInventoryResolutions = <String>[
  '9x1',
  '9x2',
  '9x3',
  '9x4',
  '9x5',
  '9x6',
  '5x1',
  '3x3',
];

const String glossInventoryDefaultResolution = '9x3';

bool looksLikeInventoryDoc(Object? json) {
  if (json is! Map || json['schemaVersion'] is! num) return false;
  return json['resolution'] is String &&
      (json.containsKey('mask') ||
          json.containsKey('keys') ||
          json.containsKey('slots'));
}

GlossInventoryDoc decodeGlossInventoryDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': e.message,
    });
  }
  return GlossInventoryDoc.fromJson(raw);
}

String encodeGlossInventoryDoc(GlossInventoryDoc doc) =>
    huiWriteJson(doc.toJson());

GlossInventoryDoc cloneGlossInventoryDoc(GlossInventoryDoc doc) =>
    GlossInventoryDoc.fromJson(huiDeepCopy(doc.toJson()));

Map<String, dynamic> _readComponentMap(Object? raw) {
  if (raw is! Map) return <String, dynamic>{};
  final Map<String, dynamic> out = <String, dynamic>{};
  raw.forEach((Object? key, Object? value) {
    if (value is Map) {
      out[key.toString()] = huiDeepCopyMap(
        huiReadObject(value, 'keys.${key.toString()}'),
      );
    }
  });
  return out;
}

const Set<String> _docKnown = <String>{
  'schemaVersion',
  'revision',
  'title',
  'resolution',
  'mask',
  'keys',
  'slots',
  'list',
  'closeOnTeleport',
  'select',
  'variants',
};

final class GlossInventoryList {
  GlossInventoryList({
    this.area = '.',
    this.varName = 'entry',
    this.source = '',
    this.pageSize,
    Map<String, dynamic>? template,
    this.refreshTicks = 20,
    Map<String, dynamic>? extras,
  }) : template = template ?? <String, dynamic>{},
       extras = extras ?? <String, dynamic>{};

  String area;
  String varName;
  String source;
  int? pageSize;
  Map<String, dynamic> template;
  int refreshTicks;
  Map<String, dynamic> extras;

  static GlossInventoryList fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossInventoryList(
      area: huiReadString(map, 'area', fallback: '.'),
      varName: huiReadString(map, 'var', fallback: 'entry'),
      source: huiReadString(map, 'source'),
      pageSize: map['pageSize'] == null ? null : huiReadInt(map, 'pageSize'),
      template: map['template'] is Map
          ? huiDeepCopyMap(huiReadObject(map['template'], '$path.template'))
          : <String, dynamic>{},
      refreshTicks: map['refreshTicks'] == null
          ? 20
          : huiReadInt(map, 'refreshTicks', fallback: 20),
      extras: huiCollectExtras(map, const <String>{
        'area',
        'var',
        'source',
        'pageSize',
        'template',
        'refreshTicks',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'area': area,
    'var': varName,
    'source': source,
    if (pageSize != null) 'pageSize': pageSize,
    if (template.isNotEmpty) 'template': huiDeepCopyMap(template),
    'refreshTicks': refreshTicks,
  }, extras);

  GlossInventoryList copy() => GlossInventoryList(
    area: area,
    varName: varName,
    source: source,
    pageSize: pageSize,
    template: huiDeepCopyMap(template),
    refreshTicks: refreshTicks,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossInventoryDoc extends GlossDoc {
  GlossInventoryDoc({
    super.schemaVersion = glossCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    this.title = '',
    this.resolution = glossInventoryDefaultResolution,
    List<String>? mask,
    Map<String, dynamic>? keys,
    Map<String, dynamic>? slots,
    this.list,
    this.closeOnTeleport = true,
    GlossPrioritySelect? select,
    List<Map<String, dynamic>>? variants,
    Map<String, dynamic>? extras,
  }) : mask = mask ?? <String>[],
       keys = keys ?? <String, dynamic>{},
       slots = slots ?? <String, dynamic>{},
       variants = variants ?? <Map<String, dynamic>>[],
       select = select ?? GlossPrioritySelect(),
       extras = extras ?? <String, dynamic>{};

  String title;
  String resolution;
  List<String> mask;
  Map<String, dynamic> keys;
  Map<String, dynamic> slots;
  GlossInventoryList? list;
  bool closeOnTeleport;
  GlossPrioritySelect select;
  List<Map<String, dynamic>> variants;
  Map<String, dynamic> extras;

  int get width {
    final int cut = resolution.indexOf('x');
    if (cut <= 0) return 9;
    return int.tryParse(resolution.substring(0, cut)) ?? 9;
  }

  int get rows {
    final int cut = resolution.indexOf('x');
    if (cut < 0 || cut + 1 >= resolution.length) return 3;
    return int.tryParse(resolution.substring(cut + 1)) ?? 3;
  }

  static GlossInventoryDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'inventory');
    return GlossInventoryDoc(
      schemaVersion: glossCurrentSchemaVersion,
      revision: glossReadRevision(map),
      title: huiReadString(map, 'title'),
      resolution: huiReadString(
        map,
        'resolution',
        fallback: glossInventoryDefaultResolution,
      ),
      mask: glossReadStringList(map['mask']),
      keys: _readComponentMap(map['keys']),
      slots: _readComponentMap(map['slots']),
      list: map['list'] == null
          ? null
          : GlossInventoryList.fromJson(map['list'], r'$.list'),
      closeOnTeleport: map['closeOnTeleport'] == null
          ? true
          : huiReadBool(map, 'closeOnTeleport'),
      select: map['select'] == null
          ? GlossPrioritySelect()
          : GlossPrioritySelect.fromJson(map['select']),
      variants: <Map<String, dynamic>>[
        for (final Object? variant in huiReadList(map['variants']))
          if (variant is Map)
            huiDeepCopyMap(huiReadObject(variant, r'$.variants')),
      ],
      extras: huiCollectExtras(map, _docKnown),
    );
  }

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'schemaVersion': schemaVersion,
    'revision': revision,
    'title': title,
    'resolution': resolution,
    'mask': List<String>.of(mask),
    if (keys.isNotEmpty) 'keys': huiDeepCopyMap(keys),
    if (slots.isNotEmpty) 'slots': huiDeepCopyMap(slots),
    if (list != null) 'list': list!.toJson(),
    'closeOnTeleport': closeOnTeleport,
    'select': select.toJson(),
    'variants': <Map<String, dynamic>>[
      for (final Map<String, dynamic> variant in variants)
        huiDeepCopyMap(variant),
    ],
  }, extras);
}

import 'json_codec.dart';

int _integer(Map<String, Object?> source, String key, int fallback) {
  final Object? value = source[key];
  if (value == null) return fallback;
  if (value is! num || !value.isFinite || value != value.truncateToDouble()) {
    throw FormatException('$key must be an integer');
  }
  return value.toInt();
}

final class GlossTabSkin {
  GlossTabSkin({this.value = '', this.signature, Map<String, Object?>? extras})
    : extras = extras ?? <String, Object?>{};
  String value;
  String? signature;
  Map<String, Object?> extras;
  static GlossTabSkin fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$');
    return GlossTabSkin(
      value: huiReadString(map, 'value'),
      signature: map['signature'] as String?,
      extras: huiCollectExtras(map, <String>{'value', 'signature'}),
    );
  }

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'value': value,
    if (signature != null) 'signature': signature,
  }, extras);
  GlossTabSkin copy() => GlossTabSkin.fromJson(huiDeepCopy(toJson()));
}

final class GlossTabSlot {
  GlossTabSlot({
    this.column = 0,
    this.row = 0,
    this.text = '',
    this.skin,
    this.ping,
    this.hat = true,
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  int column;
  int row;
  String text;
  String? skin;
  int? ping;
  bool hat;
  Map<String, Object?> extras;
  static GlossTabSlot fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$');
    return GlossTabSlot(
      column: _integer(map, 'column', 0),
      row: _integer(map, 'row', 0),
      text: huiReadString(map, 'text'),
      skin: map['skin'] as String?,
      ping: map['ping'] == null ? null : _integer(map, 'ping', 0),
      hat: map['hat'] == null ? true : huiReadBool(map, 'hat'),
      extras: huiCollectExtras(map, <String>{
        'column',
        'row',
        'text',
        'skin',
        'ping',
        'hat',
      }),
    );
  }

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'column': column,
    'row': row,
    'text': text,
    if (skin != null) 'skin': skin,
    if (ping != null) 'ping': ping,
    'hat': hat,
  }, extras);
  GlossTabSlot copy() => GlossTabSlot.fromJson(huiDeepCopy(toJson()));
}

final class GlossTabSortKey {
  GlossTabSortKey({
    this.expression = 'subject.name',
    this.type = 'text',
    this.direction = 'ascending',
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  String expression;
  String type;
  String direction;
  Map<String, Object?> extras;
  static GlossTabSortKey fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$');
    return GlossTabSortKey(
      expression: huiReadString(map, 'expression', fallback: 'subject.name'),
      type: huiReadString(map, 'type', fallback: 'text'),
      direction: huiReadString(map, 'direction', fallback: 'ascending'),
      extras: huiCollectExtras(map, <String>{
        'expression',
        'type',
        'direction',
      }),
    );
  }

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'expression': expression,
    'type': type,
    'direction': direction,
  }, extras);
  GlossTabSortKey copy() => GlossTabSortKey.fromJson(huiDeepCopy(toJson()));
}

final class GlossTabSection {
  GlossTabSection({
    this.id = 'players',
    this.column = 0,
    this.row = 0,
    this.columns = 1,
    this.rows = 20,
    this.filter = 'true',
    this.format,
    this.sort = const <GlossTabSortKey>[],
    this.overflow = 'hide',
    this.overflowFormat = '+{count}',
    this.includeNpcs = false,
    this.skin,
    this.hat = true,
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  String id;
  int column;
  int row;
  int columns;
  int rows;
  String filter;
  String? format;
  List<GlossTabSortKey> sort;
  String overflow;
  String overflowFormat;
  bool includeNpcs;
  String? skin;
  bool hat;
  Map<String, Object?> extras;
  static GlossTabSection fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$');
    return GlossTabSection(
      id: huiReadString(map, 'id', fallback: 'players'),
      column: _integer(map, 'column', 0),
      row: _integer(map, 'row', 0),
      columns: _integer(map, 'columns', 1),
      rows: _integer(map, 'rows', 20),
      filter: huiReadString(map, 'filter', fallback: 'true'),
      format: map['format'] as String?,
      sort: <GlossTabSortKey>[
        for (final Object? key in huiReadList(map['sort']))
          GlossTabSortKey.fromJson(key),
      ],
      overflow: huiReadString(map, 'overflow', fallback: 'hide'),
      overflowFormat: huiReadString(
        map,
        'overflowFormat',
        fallback: '+{count}',
      ),
      includeNpcs: huiReadBool(map, 'includeNpcs'),
      skin: map['skin'] as String?,
      hat: map['hat'] == null ? true : huiReadBool(map, 'hat'),
      extras: huiCollectExtras(map, <String>{
        'id',
        'column',
        'row',
        'columns',
        'rows',
        'filter',
        'format',
        'sort',
        'overflow',
        'overflowFormat',
        'includeNpcs',
        'skin',
        'hat',
      }),
    );
  }

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'id': id,
    'column': column,
    'row': row,
    'columns': columns,
    'rows': rows,
    'filter': filter,
    if (format != null) 'format': format,
    'sort': <Map<String, Object?>>[
      for (final GlossTabSortKey key in sort) key.toJson(),
    ],
    'overflow': overflow,
    'overflowFormat': overflowFormat,
    'includeNpcs': includeNpcs,
    if (skin != null) 'skin': skin,
    'hat': hat,
  }, extras);
  GlossTabSection copy() => GlossTabSection.fromJson(huiDeepCopy(toJson()));
}

class GlossTabPresentation {
  GlossTabPresentation({
    this.entries = 20,
    List<GlossTabSlot>? slots,
    List<GlossTabSection>? sections,
    Map<String, GlossTabSkin>? skins,
    Map<String, Object?>? extras,
  }) : slots = slots ?? <GlossTabSlot>[],
       sections = sections ?? <GlossTabSection>[],
       skins = skins ?? <String, GlossTabSkin>{},
       extras = extras ?? <String, Object?>{};
  int entries;
  List<GlossTabSlot> slots;
  List<GlossTabSection> sections;
  Map<String, GlossTabSkin> skins;
  Map<String, Object?> extras;
  int get columns => (entries + 19) ~/ 20;
  int get rows => columns <= 0 ? 0 : (entries + columns - 1) ~/ columns;
  static GlossTabPresentation fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$.layout');
    final Map<String, Object?> skins = map['skins'] == null
        ? <String, Object?>{}
        : huiReadObject(map['skins'], r'$.layout.skins');
    return GlossTabPresentation(
      entries: _integer(map, 'entries', 20),
      slots: <GlossTabSlot>[
        for (final Object? slot in huiReadList(map['slots']))
          GlossTabSlot.fromJson(slot),
      ],
      sections: <GlossTabSection>[
        for (final Object? section in huiReadList(map['sections']))
          GlossTabSection.fromJson(section),
      ],
      skins: <String, GlossTabSkin>{
        for (final MapEntry<String, Object?> skin in skins.entries)
          skin.key: GlossTabSkin.fromJson(skin.value),
      },
      extras: huiCollectExtras(map, <String>{
        'entries',
        'slots',
        'sections',
        'skins',
      }),
    );
  }

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'entries': entries,
    'slots': <Map<String, Object?>>[
      for (final GlossTabSlot slot in slots) slot.toJson(),
    ],
    'sections': <Map<String, Object?>>[
      for (final GlossTabSection section in sections) section.toJson(),
    ],
    'skins': <String, Object?>{
      for (final MapEntry<String, GlossTabSkin> skin in skins.entries)
        skin.key: skin.value.toJson(),
    },
  }, extras);
  GlossTabPresentation copy() =>
      GlossTabPresentation.fromJson(huiDeepCopy(toJson()));
}

final class GlossTabLayoutVariant {
  GlossTabLayoutVariant({
    this.id = 'variant',
    this.priority = 0,
    this.when = 'false',
    GlossTabPresentation? presentation,
    Map<String, Object?>? extras,
  }) : presentation = presentation ?? GlossTabPresentation(),
       extras = extras ?? <String, Object?>{};
  String id;
  int priority;
  String when;
  GlossTabPresentation presentation;
  Map<String, Object?> extras;
  static GlossTabLayoutVariant fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$.layout.variants');
    return GlossTabLayoutVariant(
      id: huiReadString(map, 'id'),
      priority: _integer(map, 'priority', 0),
      when: huiReadString(map, 'when', fallback: 'false'),
      presentation: GlossTabPresentation.fromJson(map['presentation']),
      extras: huiCollectExtras(map, <String>{
        'id',
        'priority',
        'when',
        'presentation',
      }),
    );
  }

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'id': id,
    'priority': priority,
    'when': when,
    'presentation': presentation.toJson(),
  }, extras);
  GlossTabLayoutVariant copy() =>
      GlossTabLayoutVariant.fromJson(huiDeepCopy(toJson()));
}

final class GlossTabLayout extends GlossTabPresentation {
  GlossTabLayout({
    this.enabled = false,
    this.show = '!viewer.bedrock',
    List<GlossTabLayoutVariant>? variants,
    super.entries,
    super.slots,
    super.sections,
    super.skins,
    super.extras,
  }) : variants = variants ?? <GlossTabLayoutVariant>[];
  bool enabled;
  Object? show;
  List<GlossTabLayoutVariant> variants;
  static GlossTabLayout fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$.layout');
    final GlossTabPresentation base = GlossTabPresentation.fromJson(raw);
    return GlossTabLayout(
      enabled: huiReadBool(map, 'enabled'),
      show: map['show'] ?? '!viewer.bedrock',
      entries: base.entries,
      slots: base.slots,
      sections: base.sections,
      skins: base.skins,
      variants: <GlossTabLayoutVariant>[
        for (final Object? variant in huiReadList(map['variants']))
          GlossTabLayoutVariant.fromJson(variant),
      ],
      extras: huiCollectExtras(map, <String>{
        'enabled',
        'show',
        'entries',
        'slots',
        'sections',
        'skins',
        'variants',
      }),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'enabled': enabled,
    'show': show,
    'variants': <Map<String, Object?>>[
      for (final GlossTabLayoutVariant variant in variants) variant.toJson(),
    ],
  };
  @override
  GlossTabLayout copy() => GlossTabLayout.fromJson(huiDeepCopy(toJson()));
}

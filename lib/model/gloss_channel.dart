library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

const int glossChannelCurrentSchemaVersion = 2;

bool looksLikeChannelDoc(Object? json) =>
    json is Map &&
    json['schemaVersion'] is num &&
    json['channel'] is Map &&
    json['format'] is String;

GlossChannelDoc decodeGlossChannelDoc(String source) {
  try {
    return GlossChannelDoc.fromJson(jsonDecode(source));
  } on FormatException catch (error) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': error.message,
    });
  }
}

String encodeGlossChannelDoc(GlossChannelDoc doc) => huiWriteJson(doc.toJson());

final class GlossChannelMentions {
  GlossChannelMentions({
    this.enabled = true,
    this.pattern = '@{name}',
    this.render = '<gold><bold>@{{ mention.name }}</bold></gold>',
    this.messageFormat = '<yellow>{{ sender.name }}: {{ message }}</yellow>',
    this.sound = 'minecraft:block.note_block.bell',
    this.permission = 'gloss.chat.mention',
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};

  bool enabled;
  String pattern;
  String render;
  String messageFormat;
  String sound;
  String permission;
  Map<String, Object?> extras;

  static GlossChannelMentions fromJson(Object? raw) {
    final Map<String, Object?> map = raw == null
        ? <String, Object?>{}
        : huiReadObject(raw, r'$.mentions');
    return GlossChannelMentions(
      enabled: map['enabled'] == null || huiReadBool(map, 'enabled'),
      pattern: huiReadString(map, 'pattern', fallback: '@{name}'),
      render: huiReadString(
        map,
        'render',
        fallback: '<gold><bold>@{{ mention.name }}</bold></gold>',
      ),
      messageFormat: huiReadString(
        map,
        'messageFormat',
        fallback: '<yellow>{{ sender.name }}: {{ message }}</yellow>',
      ),
      sound: huiReadString(
        map,
        'sound',
        fallback: 'minecraft:block.note_block.bell',
      ),
      permission: huiReadString(
        map,
        'permission',
        fallback: 'gloss.chat.mention',
      ),
      extras: huiCollectExtras(map, const <String>{
        'enabled',
        'pattern',
        'render',
        'messageFormat',
        'sound',
        'permission',
      }),
    );
  }

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'enabled': enabled,
    'pattern': pattern,
    'render': render,
    'messageFormat': messageFormat,
    'sound': sound,
    'permission': permission,
  }, extras);
}

final class GlossChannelSettings {
  GlossChannelSettings({
    this.name = 'global',
    this.defaultChannel = true,
    this.scope = 'global',
    this.permission = '',
    this.radius = 0,
    this.priority = 0,
    this.cooldownTicks = 0,
    List<String>? aliases,
    Map<String, Object?>? extras,
  }) : aliases = aliases ?? <String>[],
       extras = extras ?? <String, Object?>{};

  String name;
  bool defaultChannel;
  String scope;
  String permission;
  int radius;
  int priority;
  int cooldownTicks;
  List<String> aliases;
  Map<String, Object?> extras;

  static GlossChannelSettings fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$.channel');
    return GlossChannelSettings(
      name: huiReadString(map, 'name'),
      defaultChannel: huiReadBool(map, 'default'),
      scope: huiReadString(map, 'scope', fallback: 'global'),
      permission: huiReadString(map, 'permission'),
      radius: huiReadInt(map, 'radius'),
      priority: huiReadInt(map, 'priority'),
      cooldownTicks: huiReadInt(map, 'cooldownTicks'),
      aliases: <String>[
        for (final Object? alias in huiReadList(map['aliases']))
          if (alias is String) alias,
      ],
      extras: huiCollectExtras(map, const <String>{
        'name',
        'default',
        'scope',
        'permission',
        'radius',
        'priority',
        'cooldownTicks',
        'aliases',
      }),
    );
  }

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'name': name,
    'default': defaultChannel,
    'scope': scope,
    'permission': permission,
    'radius': radius,
    'priority': priority,
    'cooldownTicks': cooldownTicks,
    'aliases': aliases,
  }, extras);
}

final class GlossChannelItems {
  GlossChannelItems({
    this.enabled = true,
    this.token = '[item]',
    this.permission = 'gloss.chat.item',
    this.render = '[{{ item.name }}]{{ item.countSuffix }}',
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  bool enabled;
  String token;
  String permission;
  String render;
  Map<String, Object?> extras;
  static GlossChannelItems fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$');
    return GlossChannelItems(
      enabled: map['enabled'] == null ? true : huiReadBool(map, 'enabled'),
      token: huiReadString(map, 'token', fallback: '[item]'),
      permission: huiReadString(map, 'permission', fallback: 'gloss.chat.item'),
      render: huiReadString(
        map,
        'render',
        fallback: '[{{ item.name }}]{{ item.countSuffix }}',
      ),
      extras: huiCollectExtras(map, <String>{
        'enabled',
        'token',
        'permission',
        'render',
      }),
    );
  }

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'enabled': enabled,
    'token': token,
    'permission': permission,
    'render': render,
  }, extras);
}

final class GlossChannelLinks {
  GlossChannelLinks({
    this.enabled = true,
    this.render = '&9&n{{ link.host }}',
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  bool enabled;
  String render;
  Map<String, Object?> extras;
  static GlossChannelLinks fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$');
    return GlossChannelLinks(
      enabled: map['enabled'] == null ? true : huiReadBool(map, 'enabled'),
      render: huiReadString(map, 'render', fallback: '&9&n{{ link.host }}'),
      extras: huiCollectExtras(map, <String>{'enabled', 'render'}),
    );
  }

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'enabled': enabled,
    'render': render,
  }, extras);
}

final class GlossChannelFilter {
  GlossChannelFilter({
    this.match = '',
    this.replace = '',
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  String match;
  String replace;
  Map<String, Object?> extras;
  static GlossChannelFilter fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$');
    return GlossChannelFilter(
      match: huiReadString(map, 'match', fallback: ''),
      replace: huiReadString(map, 'replace', fallback: ''),
      extras: huiCollectExtras(map, <String>{'match', 'replace'}),
    );
  }

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'match': match,
    'replace': replace,
  }, extras);
}

final class GlossChannelFiltering {
  GlossChannelFiltering({
    this.syntax = 're2',
    this.maxInputCharacters = 4096,
    this.maxOutputCharacters = 16384,
    this.maxPatternCharacters = 1024,
    this.maxReplacementCharacters = 4096,
    this.maxFilters = 64,
    this.maxMatches = 4096,
    this.maxProgramSize = 16384,
    this.maxNestingDepth = 32,
    this.maxWorkUnits = 2000000,
    this.budgetMicros = 2000,
    this.onLimit = 'drop',
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  String syntax;
  int maxInputCharacters;
  int maxOutputCharacters;
  int maxPatternCharacters;
  int maxReplacementCharacters;
  int maxFilters;
  int maxMatches;
  int maxProgramSize;
  int maxNestingDepth;
  int maxWorkUnits;
  int budgetMicros;
  String onLimit;
  Map<String, Object?> extras;
  static GlossChannelFiltering fromJson(Object? raw) {
    final Map<String, Object?> map = raw == null
        ? <String, Object?>{}
        : huiReadObject(raw, r'$.filtering');
    return GlossChannelFiltering(
      syntax: huiReadString(map, 'syntax', fallback: 're2'),
      maxInputCharacters: huiReadInt(map, 'maxInputCharacters', fallback: 4096),
      maxOutputCharacters: huiReadInt(
        map,
        'maxOutputCharacters',
        fallback: 16384,
      ),
      maxPatternCharacters: huiReadInt(
        map,
        'maxPatternCharacters',
        fallback: 1024,
      ),
      maxReplacementCharacters: huiReadInt(
        map,
        'maxReplacementCharacters',
        fallback: 4096,
      ),
      maxFilters: huiReadInt(map, 'maxFilters', fallback: 64),
      maxMatches: huiReadInt(map, 'maxMatches', fallback: 4096),
      maxProgramSize: huiReadInt(map, 'maxProgramSize', fallback: 16384),
      maxNestingDepth: huiReadInt(map, 'maxNestingDepth', fallback: 32),
      maxWorkUnits: huiReadInt(map, 'maxWorkUnits', fallback: 2000000),
      budgetMicros: huiReadInt(map, 'budgetMicros', fallback: 2000),
      onLimit: huiReadString(map, 'onLimit', fallback: 'drop'),
      extras: huiCollectExtras(map, <String>{
        'syntax',
        'onLimit',
        'maxInputCharacters',
        'maxOutputCharacters',
        'maxPatternCharacters',
        'maxReplacementCharacters',
        'maxFilters',
        'maxMatches',
        'maxProgramSize',
        'maxNestingDepth',
        'maxWorkUnits',
        'budgetMicros',
      }),
    );
  }

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'syntax': syntax,
    'maxInputCharacters': maxInputCharacters,
    'maxOutputCharacters': maxOutputCharacters,
    'maxPatternCharacters': maxPatternCharacters,
    'maxReplacementCharacters': maxReplacementCharacters,
    'maxFilters': maxFilters,
    'maxMatches': maxMatches,
    'maxProgramSize': maxProgramSize,
    'maxNestingDepth': maxNestingDepth,
    'maxWorkUnits': maxWorkUnits,
    'budgetMicros': budgetMicros,
    'onLimit': onLimit,
  }, extras);
}

final class GlossChannelThrottle {
  GlossChannelThrottle({
    this.repeatWindowTicks = 100,
    this.maxRepeats = 1,
    this.minIntervalTicks = 10,
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  int repeatWindowTicks;
  int maxRepeats;
  int minIntervalTicks;
  Map<String, Object?> extras;
  static GlossChannelThrottle fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$');
    return GlossChannelThrottle(
      repeatWindowTicks: huiReadInt(map, 'repeatWindowTicks', fallback: 100),
      maxRepeats: huiReadInt(map, 'maxRepeats', fallback: 1),
      minIntervalTicks: huiReadInt(map, 'minIntervalTicks', fallback: 10),
      extras: huiCollectExtras(map, <String>{
        'repeatWindowTicks',
        'maxRepeats',
        'minIntervalTicks',
      }),
    );
  }

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'repeatWindowTicks': repeatWindowTicks,
    'maxRepeats': maxRepeats,
    'minIntervalTicks': minIntervalTicks,
  }, extras);
}

final class GlossChannelVariant {
  GlossChannelVariant({
    this.id = '',
    this.priority = 0,
    this.when = 'true',
    this.format,
    this.card,
    this.mentions,
    this.items,
    this.links,
    this.filters,
    this.throttle,
    this.filtering,
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  String id;
  int priority;
  String when;
  String? format;
  List<String>? card;
  GlossChannelMentions? mentions;
  GlossChannelItems? items;
  GlossChannelLinks? links;
  List<GlossChannelFilter>? filters;
  GlossChannelThrottle? throttle;
  GlossChannelFiltering? filtering;
  Map<String, Object?> extras;

  static GlossChannelVariant fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$');
    return GlossChannelVariant(
      id: huiReadString(map, 'id'),
      priority: huiReadInt(map, 'priority'),
      when: huiReadString(map, 'when'),
      format: map['format'] is String ? map['format'] as String : null,
      card: map['card'] == null
          ? null
          : <String>[
              for (final Object? line in huiReadList(map['card']))
                if (line is String) line,
            ],
      mentions: map['mentions'] == null
          ? null
          : GlossChannelMentions.fromJson(map['mentions']),
      items: map['items'] == null
          ? null
          : GlossChannelItems.fromJson(map['items']),
      links: map['links'] == null
          ? null
          : GlossChannelLinks.fromJson(map['links']),
      filters: map['filters'] == null
          ? null
          : <GlossChannelFilter>[
              for (final Object? filter in huiReadList(map['filters']))
                GlossChannelFilter.fromJson(filter),
            ],
      filtering: map['filtering'] == null
          ? null
          : GlossChannelFiltering.fromJson(map['filtering']),
      throttle: map['throttle'] == null
          ? null
          : GlossChannelThrottle.fromJson(map['throttle']),
      extras: huiCollectExtras(map, <String>{
        'id',
        'priority',
        'when',
        'format',
        'card',
        'mentions',
        'items',
        'links',
        'filters',
        'throttle',
        'filtering',
      }),
    );
  }

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'id': id,
    'priority': priority,
    'when': when,
    if (format != null) 'format': format,
    if (card != null) 'card': card,
    if (mentions != null) 'mentions': mentions!.toJson(),
    if (items != null) 'items': items!.toJson(),
    if (links != null) 'links': links!.toJson(),
    if (filters != null)
      'filters': <Map<String, Object?>>[
        for (final GlossChannelFilter filter in filters!) filter.toJson(),
      ],
    if (throttle != null) 'throttle': throttle!.toJson(),
    if (filtering != null) 'filtering': filtering!.toJson(),
  }, extras);

  GlossChannelDoc apply(GlossChannelDoc base) => GlossChannelDoc(
    schemaVersion: base.schemaVersion,
    revision: base.revision,
    show: base.show,
    channel: base.channel,
    format: format ?? base.format,
    card: card ?? base.card,
    mentions: mentions ?? base.mentions,
    items: items ?? base.items,
    links: links ?? base.links,
    filters: filters ?? base.filters,
    throttle: throttle ?? base.throttle,
    filtering: filtering ?? base.filtering,
  );
}

final class GlossChannelDoc extends GlossDoc {
  GlossChannelDoc({
    super.schemaVersion = glossChannelCurrentSchemaVersion,
    super.revision = 1,
    this.show = 'true',
    this.format = '&f{{ sender.name }}&8: &f{{ message }}',
    GlossChannelSettings? channel,
    GlossChannelMentions? mentions,
    List<String>? card,
    this.items,
    this.links,
    this.throttle,
    this.filtering,
    List<GlossChannelFilter>? filters,
    List<GlossChannelVariant>? variants,
    Map<String, Object?>? extras,
  }) : channel = channel ?? GlossChannelSettings(),
       mentions = mentions ?? GlossChannelMentions(),
       card = card ?? <String>[],
       filters = filters ?? <GlossChannelFilter>[],
       variants = variants ?? <GlossChannelVariant>[],
       extras = extras ?? <String, Object?>{};

  Object? show;
  String format;
  GlossChannelSettings channel;
  GlossChannelMentions mentions;
  List<String> card;
  GlossChannelItems? items;
  GlossChannelLinks? links;
  GlossChannelThrottle? throttle;
  GlossChannelFiltering? filtering;
  List<GlossChannelFilter> filters;
  List<GlossChannelVariant> variants;
  Map<String, Object?> extras;

  static GlossChannelDoc fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(
      map,
      'channel',
      expected: glossChannelCurrentSchemaVersion,
    );
    if (map['schemaVersion'] != glossChannelCurrentSchemaVersion) {
      throw const HuiFormatException(
        'Channel schemaVersion must be 2.',
        r'$.schemaVersion',
      );
    }
    return GlossChannelDoc(
      revision: glossReadRevision(map),
      show: map['show'] ?? 'true',
      format: huiReadString(map, 'format'),
      channel: GlossChannelSettings.fromJson(map['channel']),
      mentions: GlossChannelMentions.fromJson(map['mentions']),
      items: map['items'] == null
          ? null
          : GlossChannelItems.fromJson(map['items']),
      links: map['links'] == null
          ? null
          : GlossChannelLinks.fromJson(map['links']),
      filtering: map['filtering'] == null
          ? null
          : GlossChannelFiltering.fromJson(map['filtering']),
      throttle: map['throttle'] == null
          ? null
          : GlossChannelThrottle.fromJson(map['throttle']),
      filters: <GlossChannelFilter>[
        for (final Object? filter in huiReadList(map['filters']))
          GlossChannelFilter.fromJson(filter),
      ],
      variants: <GlossChannelVariant>[
        for (final Object? variant in huiReadList(map['variants']))
          GlossChannelVariant.fromJson(variant),
      ],
      card: <String>[
        for (final Object? line in huiReadList(map['card']))
          if (line is String) line,
      ],
      extras: huiCollectExtras(map, const <String>{
        'schemaVersion',
        'revision',
        'show',
        'format',
        'channel',
        'mentions',
        'card',
        'items',
        'links',
        'filters',
        'throttle',
        'filtering',
        'variants',
      }),
    );
  }

  @override
  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'schemaVersion': schemaVersion,
    'revision': revision,
    'show': show,
    'channel': channel.toJson(),
    'format': format,
    'card': card,
    'mentions': mentions.toJson(),
    if (items != null) 'items': items!.toJson(),
    if (links != null) 'links': links!.toJson(),
    if (throttle != null) 'throttle': throttle!.toJson(),
    if (filtering != null) 'filtering': filtering!.toJson(),
    if (filters.isNotEmpty)
      'filters': <Map<String, Object?>>[
        for (final GlossChannelFilter filter in filters) filter.toJson(),
      ],
    if (variants.isNotEmpty)
      'variants': <Map<String, Object?>>[
        for (final GlossChannelVariant variant in variants) variant.toJson(),
      ],
  }, extras);
}

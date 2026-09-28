library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

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

final class GlossChannelDoc extends GlossDoc {
  GlossChannelDoc({
    super.schemaVersion = 1,
    super.revision = 1,
    this.show = 'true',
    this.format = '&f{{ sender.name }}&8: &f{{ message }}',
    GlossChannelSettings? channel,
    GlossChannelMentions? mentions,
    List<String>? card,
    Map<String, Object?>? extras,
  }) : channel = channel ?? GlossChannelSettings(),
       mentions = mentions ?? GlossChannelMentions(),
       card = card ?? <String>[],
       extras = extras ?? <String, Object?>{};

  Object? show;
  String format;
  GlossChannelSettings channel;
  GlossChannelMentions mentions;
  List<String> card;
  Map<String, Object?> extras;

  static GlossChannelDoc fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'channel');
    return GlossChannelDoc(
      revision: glossReadRevision(map),
      show: map['show'] ?? 'true',
      format: huiReadString(map, 'format'),
      channel: GlossChannelSettings.fromJson(map['channel']),
      mentions: GlossChannelMentions.fromJson(map['mentions']),
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
  }, extras);
}

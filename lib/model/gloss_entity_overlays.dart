library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

const int glossEntityOverlaysCurrentSchemaVersion = 1;
const String glossEntityOverlaysDefaultId = 'default';

bool looksLikeEntityOverlaysDoc(Object? raw) =>
    raw is Map &&
    raw['schemaVersion'] is num &&
    raw.containsKey('healthSegments');

GlossEntityOverlaysDoc decodeGlossEntityOverlaysDoc(String json) {
  try {
    return GlossEntityOverlaysDoc.fromJson(jsonDecode(json));
  } on FormatException catch (error) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': error.message,
    });
  }
}

String encodeGlossEntityOverlaysDoc(GlossEntityOverlaysDoc doc) =>
    huiWriteJson(doc.toJson());

final class GlossEntityOverlaysDoc extends GlossDoc {
  GlossEntityOverlaysDoc({
    super.schemaVersion = glossEntityOverlaysCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    this.enabled = true,
    this.range = 16,
    this.updateIntervalTicks = 5,
    this.maxEntitiesPerViewer = 64,
    this.includePlayers = true,
    this.verticalOffset = 0.35,
    this.scale = 0.75,
    this.healthSegments = 10,
    this.showHealthNumbers = true,
    this.showNames = true,
    this.showCombatStats = true,
    this.hitHighlightMs = 750,
    List<String>? blacklistWorlds,
    List<String>? excludedEntityTypes,
    this.nameFormat = '&f{name}',
    this.healthFormat = '{bar} &f{health}&7/{max_health}',
    this.stackFormat = ' &7x{count}',
    this.statsFormat = '&7ATK &f{attack} &8| &7ARM &f{armor}',
    this.damageFormat = '&c-{damage}',
    Map<String, Object?>? extras,
  }) : blacklistWorlds = blacklistWorlds ?? <String>[],
       excludedEntityTypes = excludedEntityTypes ?? <String>['ARMOR_STAND'],
       extras = extras ?? <String, Object?>{};

  bool enabled;
  double range;
  int updateIntervalTicks;
  int maxEntitiesPerViewer;
  bool includePlayers;
  double verticalOffset;
  double scale;
  int healthSegments;
  bool showHealthNumbers;
  bool showNames;
  bool showCombatStats;
  int hitHighlightMs;
  List<String> blacklistWorlds;
  List<String> excludedEntityTypes;
  String nameFormat;
  String healthFormat;
  String stackFormat;
  String statsFormat;
  String damageFormat;
  Map<String, Object?> extras;

  static GlossEntityOverlaysDoc fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'entity-overlays');
    return GlossEntityOverlaysDoc(
      revision: glossReadRevision(map),
      enabled: map['enabled'] == null || huiReadBool(map, 'enabled'),
      range: huiReadDouble(map, 'range', fallback: 16),
      updateIntervalTicks: huiReadInt(map, 'updateIntervalTicks', fallback: 5),
      maxEntitiesPerViewer: huiReadInt(
        map,
        'maxEntitiesPerViewer',
        fallback: 64,
      ),
      includePlayers:
          map['includePlayers'] == null || huiReadBool(map, 'includePlayers'),
      verticalOffset: huiReadDouble(map, 'verticalOffset', fallback: 0.35),
      scale: huiReadDouble(map, 'scale', fallback: 0.75),
      healthSegments: huiReadInt(map, 'healthSegments', fallback: 10),
      showHealthNumbers:
          map['showHealthNumbers'] == null ||
          huiReadBool(map, 'showHealthNumbers'),
      showNames: map['showNames'] == null || huiReadBool(map, 'showNames'),
      showCombatStats:
          map['showCombatStats'] == null || huiReadBool(map, 'showCombatStats'),
      hitHighlightMs: huiReadInt(map, 'hitHighlightMs', fallback: 750),
      blacklistWorlds: _strings(
        map['blacklistWorlds'],
        const <String>[],
        r'$.blacklistWorlds',
      ),
      excludedEntityTypes: _strings(map['excludedEntityTypes'], const <String>[
        'ARMOR_STAND',
      ], r'$.excludedEntityTypes'),
      nameFormat: huiReadString(map, 'nameFormat', fallback: '&f{name}'),
      healthFormat: huiReadString(
        map,
        'healthFormat',
        fallback: '{bar} &f{health}&7/{max_health}',
      ),
      stackFormat: huiReadString(map, 'stackFormat', fallback: ' &7x{count}'),
      statsFormat: huiReadString(
        map,
        'statsFormat',
        fallback: '&7ATK &f{attack} &8| &7ARM &f{armor}',
      ),
      damageFormat: huiReadString(map, 'damageFormat', fallback: '&c-{damage}'),
      extras: huiCollectExtras(map, <String>{
        ...GlossEntityOverlaysDoc().toJson().keys,
      }),
    );
  }

  static List<String> _strings(
    Object? raw,
    List<String> fallback,
    String path,
  ) {
    if (raw == null) return List<String>.of(fallback);
    if (raw is! List || raw.any((Object? value) => value is! String)) {
      throw HuiFormatException('Expected a JSON array of strings', path);
    }
    return raw.cast<String>().toList();
  }

  @override
  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'schemaVersion': schemaVersion,
    'revision': revision,
    'enabled': enabled,
    'range': range,
    'updateIntervalTicks': updateIntervalTicks,
    'maxEntitiesPerViewer': maxEntitiesPerViewer,
    'includePlayers': includePlayers,
    'verticalOffset': verticalOffset,
    'scale': scale,
    'healthSegments': healthSegments,
    'showHealthNumbers': showHealthNumbers,
    'showNames': showNames,
    'showCombatStats': showCombatStats,
    'hitHighlightMs': hitHighlightMs,
    'blacklistWorlds': blacklistWorlds,
    'excludedEntityTypes': excludedEntityTypes,
    'nameFormat': nameFormat,
    'healthFormat': healthFormat,
    'stackFormat': stackFormat,
    'statsFormat': statsFormat,
    'damageFormat': damageFormat,
  }, extras);

  GlossEntityOverlaysDoc copy() => GlossEntityOverlaysDoc.fromJson(toJson());
}

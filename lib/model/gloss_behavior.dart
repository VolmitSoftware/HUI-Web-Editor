import 'dart:convert';
import 'gloss_doc.dart';
import 'json_codec.dart';

bool looksLikeBehaviorDoc(Object? raw) =>
    raw is Map &&
    raw['schemaVersion'] is num &&
    !raw.containsKey('surface') &&
    (raw.containsKey('on') ||
        raw.containsKey('matching') ||
        raw.containsKey('allowServerCommands'));
GlossBehaviorDoc decodeGlossBehaviorDoc(String source) =>
    GlossBehaviorDoc.fromJson(jsonDecode(source));
String encodeGlossBehaviorDoc(GlossBehaviorDoc doc) =>
    huiWriteJson(doc.toJson());

final class GlossBehaviorDoc extends GlossDoc {
  GlossBehaviorDoc({
    super.schemaVersion = 2,
    super.revision = glossInitialRevision,
    this.enabled = true,
    this.allowServerCommands = false,
    GlossBehaviorMatching? matching,
    List<GlossBehaviorEntry>? on,
    Map<String, Object?>? state,
    Map<String, Object?>? extras,
  }) : matching = matching ?? GlossBehaviorMatching(),
       on = on ?? <GlossBehaviorEntry>[],
       state = state ?? <String, Object?>{},
       extras = extras ?? <String, Object?>{};
  bool enabled;
  bool allowServerCommands;
  GlossBehaviorMatching matching;
  List<GlossBehaviorEntry> on;
  Map<String, Object?> state;
  final Map<String, Object?> extras;
  static GlossBehaviorDoc fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'behaviors', expected: 2);
    return GlossBehaviorDoc(
      revision: glossReadRevision(map),
      enabled: map['enabled'] != false,
      allowServerCommands: map['allowServerCommands'] == true,
      matching: GlossBehaviorMatching.fromJson(map['matching']),
      state: map['state'] == null
          ? <String, Object?>{}
          : huiDeepCopyMap(huiReadObject(map['state'], r'$.state')),
      on: <GlossBehaviorEntry>[
        for (final Object? entry in huiReadList(map['on']))
          GlossBehaviorEntry.fromJson(entry),
      ],
      extras: huiCollectExtras(map, const <String>{
        'schemaVersion',
        'revision',
        'enabled',
        'allowServerCommands',
        'matching',
        'on',
        'state',
      }),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...huiDeepCopyMap(extras),
    'schemaVersion': schemaVersion,
    'revision': revision,
    'enabled': enabled,
    'allowServerCommands': allowServerCommands,
    'matching': matching.toJson(),
    'state': huiDeepCopyMap(state),
    'on': <Object?>[for (final GlossBehaviorEntry entry in on) entry.toJson()],
  };
}

final class GlossBehaviorMatching {
  GlossBehaviorMatching({
    this.syntax = 're2',
    this.maxInputCharacters = 4096,
    this.maxPatternCharacters = 1024,
    this.maxProgramSize = 16384,
    this.maxNestingDepth = 32,
    this.maxWorkUnits = 2000000,
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  String syntax;
  int maxInputCharacters;
  int maxPatternCharacters;
  int maxProgramSize;
  int maxNestingDepth;
  int maxWorkUnits;
  final Map<String, Object?> extras;
  static GlossBehaviorMatching fromJson(Object? raw) {
    final Map<String, Object?> map = raw == null
        ? <String, Object?>{}
        : huiReadObject(raw, r'$.matching');
    return GlossBehaviorMatching(
      syntax: huiReadString(map, 'syntax', fallback: 're2'),
      maxInputCharacters: _integer(map, 'maxInputCharacters', 4096),
      maxPatternCharacters: _integer(map, 'maxPatternCharacters', 1024),
      maxProgramSize: _integer(map, 'maxProgramSize', 16384),
      maxNestingDepth: _integer(map, 'maxNestingDepth', 32),
      maxWorkUnits: _integer(map, 'maxWorkUnits', 2000000),
      extras: huiCollectExtras(map, const <String>{
        'syntax',
        'maxInputCharacters',
        'maxPatternCharacters',
        'maxProgramSize',
        'maxNestingDepth',
        'maxWorkUnits',
      }),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    ...huiDeepCopyMap(extras),
    'syntax': syntax,
    'maxInputCharacters': maxInputCharacters,
    'maxPatternCharacters': maxPatternCharacters,
    'maxProgramSize': maxProgramSize,
    'maxNestingDepth': maxNestingDepth,
    'maxWorkUnits': maxWorkUnits,
  };
}

int _integer(Map<String, Object?> source, String key, int fallback) {
  final Object? value = source[key];
  if (value == null) return fallback;
  if (value is! num || !value.isFinite || value % 1 != 0) {
    throw HuiFormatException('$key requires an integer.', key);
  }
  return value.toInt();
}

final class GlossBehaviorEntry {
  GlossBehaviorEntry({
    this.trigger = 'join',
    this.pattern,
    this.name,
    this.region,
    this.material,
    this.menu,
    this.component,
    this.scope,
    this.when,
    this.permission,
    this.everyTicks,
    List<Map<String, Object?>>? actions,
    Map<String, Object?>? extras,
  }) : actions = actions ?? <Map<String, Object?>>[],
       extras = extras ?? <String, Object?>{};
  String trigger;
  String? pattern;
  String? name;
  String? region;
  String? material;
  String? menu;
  String? component;
  String? scope;
  String? when;
  String? permission;
  int? everyTicks;
  List<Map<String, Object?>> actions;
  final Map<String, Object?> extras;
  static GlossBehaviorEntry fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$.on[]');
    return GlossBehaviorEntry(
      trigger: huiReadString(map, 'trigger'),
      pattern: map['pattern'] == null ? null : huiReadString(map, 'pattern'),
      name: map['name'] == null ? null : huiReadString(map, 'name'),
      region: map['region'] == null ? null : huiReadString(map, 'region'),
      material: map['material'] == null ? null : huiReadString(map, 'material'),
      menu: map['menu'] == null ? null : huiReadString(map, 'menu'),
      component: map['component'] == null
          ? null
          : huiReadString(map, 'component'),
      scope: map['scope'] == null ? null : huiReadString(map, 'scope'),
      when: map['when'] == null ? null : huiReadString(map, 'when'),
      permission: map['permission'] == null
          ? null
          : huiReadString(map, 'permission'),
      everyTicks: map['everyTicks'] == null
          ? null
          : _integer(map, 'everyTicks', 0),
      actions: <Map<String, Object?>>[
        for (final Object? action in huiReadList(map['do']))
          huiDeepCopyMap(huiReadObject(action, r'$.on[].do[]')),
      ],
      extras: huiCollectExtras(map, const <String>{
        'trigger',
        'everyTicks',
        'do',
        'pattern',
        'name',
        'region',
        'material',
        'menu',
        'component',
        'scope',
        'when',
        'permission',
      }),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    ...huiDeepCopyMap(extras),
    'trigger': trigger,
    if (pattern != null) 'pattern': pattern,
    if (name != null) 'name': name,
    if (region != null) 'region': region,
    if (material != null) 'material': material,
    if (menu != null) 'menu': menu,
    if (component != null) 'component': component,
    if (scope != null) 'scope': scope,
    if (when != null) 'when': when,
    if (permission != null) 'permission': permission,
    if (everyTicks != null) 'everyTicks': everyTicks,
    'do': <Object?>[
      for (final Map<String, Object?> action in actions) huiDeepCopyMap(action),
    ],
  };
}

library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';
import 'vec3.dart';

const int glossDamageIndicatorsCurrentSchemaVersion = 1;
const String glossDamageIndicatorsDefaultId = 'default';
const String glossDamageAmountToken = '{amount}';

bool looksLikeDamageIndicatorsDoc(Object? json) {
  if (json is! Map || json['schemaVersion'] is! num) return false;
  return json.containsKey('limits') &&
      json.containsKey('damage') &&
      json.containsKey('healing') &&
      json.containsKey('filters');
}

GlossDamageIndicatorsDoc decodeGlossDamageIndicatorsDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (error) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': error.message,
    });
  }
  return GlossDamageIndicatorsDoc.fromJson(raw);
}

String encodeGlossDamageIndicatorsDoc(GlossDamageIndicatorsDoc doc) =>
    huiWriteJson(doc.toJson());

const Set<String> _docKnown = <String>{
  'schemaVersion',
  'revision',
  'limits',
  'damage',
  'healing',
  'filters',
};
const Set<String> _limitsKnown = <String>{
  'maxPerSecond',
  'lifetimeMs',
  'minimumDelta',
  'decimals',
};
const Set<String> _styleKnown = <String>{
  'enabled',
  'format',
  'offset',
  'motion',
  'presentation',
};
const Set<String> _motionKnown = <String>{
  'horizontalSpeed',
  'verticalSpeed',
  'verticalAcceleration',
  'spinDegreesPerSecond',
};
const Set<String> _presentationKnown = <String>{
  'startScale',
  'endScale',
  'fadeStartFraction',
};
const Set<String> _filtersKnown = <String>{'disabledWorlds'};

final class GlossDamageIndicatorLimits {
  GlossDamageIndicatorLimits({
    this.maxPerSecond = 40,
    this.lifetimeMs = 3000,
    this.minimumDelta = 0.009,
    this.decimals = 0,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  int maxPerSecond;
  int lifetimeMs;
  double minimumDelta;
  int decimals;
  Map<String, dynamic> extras;

  static GlossDamageIndicatorLimits fromJson(Object? raw) {
    if (raw == null) return GlossDamageIndicatorLimits();
    final Map<String, dynamic> map = huiReadObject(raw, r'$.limits');
    return GlossDamageIndicatorLimits(
      maxPerSecond: huiReadInt(map, 'maxPerSecond', fallback: 40),
      lifetimeMs: huiReadInt(map, 'lifetimeMs', fallback: 3000),
      minimumDelta: huiReadDouble(map, 'minimumDelta', fallback: 0.009),
      decimals: huiReadInt(map, 'decimals'),
      extras: huiCollectExtras(map, _limitsKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'maxPerSecond': maxPerSecond,
    'lifetimeMs': lifetimeMs,
    'minimumDelta': minimumDelta,
    'decimals': decimals,
  }, extras);

  GlossDamageIndicatorLimits copy() =>
      GlossDamageIndicatorLimits.fromJson(toJson());
}

final class GlossDamageIndicatorMotion {
  GlossDamageIndicatorMotion({
    required this.horizontalSpeed,
    required this.verticalSpeed,
    required this.verticalAcceleration,
    this.spinDegreesPerSecond = 0,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  double horizontalSpeed;
  double verticalSpeed;
  double verticalAcceleration;
  double spinDegreesPerSecond;
  Map<String, dynamic> extras;

  static GlossDamageIndicatorMotion fromJson(
    Object? raw, {
    required GlossDamageIndicatorMotion fallback,
    required String path,
  }) {
    if (raw == null) return fallback.copy();
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossDamageIndicatorMotion(
      horizontalSpeed: huiReadDouble(
        map,
        'horizontalSpeed',
        fallback: fallback.horizontalSpeed,
      ),
      verticalSpeed: huiReadDouble(
        map,
        'verticalSpeed',
        fallback: fallback.verticalSpeed,
      ),
      verticalAcceleration: huiReadDouble(
        map,
        'verticalAcceleration',
        fallback: fallback.verticalAcceleration,
      ),
      spinDegreesPerSecond: huiReadDouble(
        map,
        'spinDegreesPerSecond',
        fallback: fallback.spinDegreesPerSecond,
      ),
      extras: huiCollectExtras(map, _motionKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'horizontalSpeed': horizontalSpeed,
    'verticalSpeed': verticalSpeed,
    'verticalAcceleration': verticalAcceleration,
    'spinDegreesPerSecond': spinDegreesPerSecond,
  }, extras);

  GlossDamageIndicatorMotion copy() => GlossDamageIndicatorMotion(
    horizontalSpeed: horizontalSpeed,
    verticalSpeed: verticalSpeed,
    verticalAcceleration: verticalAcceleration,
    spinDegreesPerSecond: spinDegreesPerSecond,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossDamageIndicatorPresentation {
  GlossDamageIndicatorPresentation({
    required this.startScale,
    required this.endScale,
    required this.fadeStartFraction,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  double startScale;
  double endScale;
  double fadeStartFraction;
  Map<String, dynamic> extras;

  static GlossDamageIndicatorPresentation fromJson(
    Object? raw, {
    required GlossDamageIndicatorPresentation fallback,
    required String path,
  }) {
    if (raw == null) return fallback.copy();
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossDamageIndicatorPresentation(
      startScale: huiReadDouble(
        map,
        'startScale',
        fallback: fallback.startScale,
      ),
      endScale: huiReadDouble(map, 'endScale', fallback: fallback.endScale),
      fadeStartFraction: huiReadDouble(
        map,
        'fadeStartFraction',
        fallback: fallback.fadeStartFraction,
      ),
      extras: huiCollectExtras(map, _presentationKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'startScale': startScale,
    'endScale': endScale,
    'fadeStartFraction': fadeStartFraction,
  }, extras);

  GlossDamageIndicatorPresentation copy() => GlossDamageIndicatorPresentation(
    startScale: startScale,
    endScale: endScale,
    fadeStartFraction: fadeStartFraction,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossDamageIndicatorStyle {
  GlossDamageIndicatorStyle({
    required this.enabled,
    required this.format,
    required this.offset,
    required this.motion,
    required this.presentation,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  bool enabled;
  String format;
  Vec3 offset;
  GlossDamageIndicatorMotion motion;
  GlossDamageIndicatorPresentation presentation;
  Map<String, dynamic> extras;

  static GlossDamageIndicatorStyle damageDefaults() =>
      GlossDamageIndicatorStyle(
        enabled: true,
        format: '&c&l{amount}',
        offset: Vec3(0, 0.7, 0),
        motion: GlossDamageIndicatorMotion(
          horizontalSpeed: 0.8,
          verticalSpeed: 1.3,
          verticalAcceleration: -0.93,
        ),
        presentation: GlossDamageIndicatorPresentation(
          startScale: 1,
          endScale: 0.82,
          fadeStartFraction: 0.68,
        ),
      );

  static GlossDamageIndicatorStyle healingDefaults() =>
      GlossDamageIndicatorStyle(
        enabled: true,
        format: '&a&l{amount}',
        offset: Vec3(0, -0.1, 0),
        motion: GlossDamageIndicatorMotion(
          horizontalSpeed: 0.45,
          verticalSpeed: 0.65,
          verticalAcceleration: 0.05,
        ),
        presentation: GlossDamageIndicatorPresentation(
          startScale: 1,
          endScale: 1.1,
          fadeStartFraction: 0.62,
        ),
      );

  static GlossDamageIndicatorStyle fromJson(
    Object? raw, {
    required GlossDamageIndicatorStyle fallback,
    required String path,
  }) {
    if (raw == null) return fallback.copy();
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossDamageIndicatorStyle(
      enabled: map['enabled'] == null
          ? fallback.enabled
          : huiReadBool(map, 'enabled'),
      format: huiReadString(map, 'format', fallback: fallback.format),
      offset: map['offset'] == null
          ? fallback.offset.copy()
          : Vec3.fromJson(map['offset'], path: '$path.offset'),
      motion: GlossDamageIndicatorMotion.fromJson(
        map['motion'],
        fallback: fallback.motion,
        path: '$path.motion',
      ),
      presentation: GlossDamageIndicatorPresentation.fromJson(
        map['presentation'],
        fallback: fallback.presentation,
        path: '$path.presentation',
      ),
      extras: huiCollectExtras(map, _styleKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'enabled': enabled,
    'format': format,
    'offset': offset.toJson(),
    'motion': motion.toJson(),
    'presentation': presentation.toJson(),
  }, extras);

  GlossDamageIndicatorStyle copy() => GlossDamageIndicatorStyle(
    enabled: enabled,
    format: format,
    offset: offset.copy(),
    motion: motion.copy(),
    presentation: presentation.copy(),
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossDamageIndicatorFilters {
  GlossDamageIndicatorFilters({
    List<String>? disabledWorlds,
    Map<String, dynamic>? extras,
  }) : disabledWorlds = disabledWorlds ?? <String>[],
       extras = extras ?? <String, dynamic>{};

  List<String> disabledWorlds;
  Map<String, dynamic> extras;

  static GlossDamageIndicatorFilters fromJson(Object? raw) {
    if (raw == null) return GlossDamageIndicatorFilters();
    final Map<String, dynamic> map = huiReadObject(raw, r'$.filters');
    return GlossDamageIndicatorFilters(
      disabledWorlds: glossReadStringList(map['disabledWorlds']),
      extras: huiCollectExtras(map, _filtersKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'disabledWorlds': List<String>.of(disabledWorlds),
  }, extras);

  GlossDamageIndicatorFilters copy() =>
      GlossDamageIndicatorFilters.fromJson(toJson());
}

final class GlossDamageIndicatorsDoc extends GlossDoc {
  GlossDamageIndicatorsDoc({
    super.schemaVersion = glossDamageIndicatorsCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    GlossDamageIndicatorLimits? limits,
    GlossDamageIndicatorStyle? damage,
    GlossDamageIndicatorStyle? healing,
    GlossDamageIndicatorFilters? filters,
    Map<String, dynamic>? extras,
  }) : limits = limits ?? GlossDamageIndicatorLimits(),
       damage = damage ?? GlossDamageIndicatorStyle.damageDefaults(),
       healing = healing ?? GlossDamageIndicatorStyle.healingDefaults(),
       filters = filters ?? GlossDamageIndicatorFilters(),
       extras = extras ?? <String, dynamic>{};

  GlossDamageIndicatorLimits limits;
  GlossDamageIndicatorStyle damage;
  GlossDamageIndicatorStyle healing;
  GlossDamageIndicatorFilters filters;
  Map<String, dynamic> extras;

  static GlossDamageIndicatorsDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(
      map,
      'damage-indicators',
      expected: glossDamageIndicatorsCurrentSchemaVersion,
    );
    return GlossDamageIndicatorsDoc(
      revision: glossReadRevision(map),
      limits: GlossDamageIndicatorLimits.fromJson(map['limits']),
      damage: GlossDamageIndicatorStyle.fromJson(
        map['damage'],
        fallback: GlossDamageIndicatorStyle.damageDefaults(),
        path: r'$.damage',
      ),
      healing: GlossDamageIndicatorStyle.fromJson(
        map['healing'],
        fallback: GlossDamageIndicatorStyle.healingDefaults(),
        path: r'$.healing',
      ),
      filters: GlossDamageIndicatorFilters.fromJson(map['filters']),
      extras: huiCollectExtras(map, _docKnown),
    );
  }

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'schemaVersion': schemaVersion,
    'revision': revision,
    'limits': limits.toJson(),
    'damage': damage.toJson(),
    'healing': healing.toJson(),
    'filters': filters.toJson(),
  }, extras);

  GlossDamageIndicatorsDoc copy() =>
      GlossDamageIndicatorsDoc.fromJson(toJson());
}

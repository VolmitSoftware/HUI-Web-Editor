library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';
import 'vec3.dart';

const int glossDamageIndicatorsCurrentSchemaVersion = 2;
const String glossDamageIndicatorsDefaultId = 'default';
const String glossDamageAmountToken = '{amount}';

bool looksLikeDamageIndicatorsDoc(Object? json) {
  if (json is! Map || json['schemaVersion'] is! num) return false;
  return json.containsKey('limits') &&
      json.containsKey('damage') &&
      json.containsKey('healing') &&
      json.containsKey('audience');
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
  'audience',
};
const Set<String> _limitsKnown = <String>{
  'maxPerSecond',
  'lifetimeMs',
  'minimumDelta',
  'decimals',
};
const Set<String> _styleKnown = <String>{'when', 'presentation', 'variants'};
const Set<String> _variantKnown = <String>{
  'id',
  'priority',
  'when',
  'presentation',
};
const Set<String> _indicatorPresentationKnown = <String>{
  'format',
  'offset',
  'motion',
  'transform',
};
const Set<String> _motionKnown = <String>{
  'horizontalSpeed',
  'verticalSpeed',
  'verticalAcceleration',
  'spinDegreesPerSecond',
};
const Set<String> _transformKnown = <String>{
  'startScale',
  'endScale',
  'fadeStartFraction',
};
const Set<String> _audienceKnown = <String>{'when'};

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
    bool requireComplete = false,
  }) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    if (requireComplete) _requireKeys(map, _motionKnown, path);
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

final class GlossDamageIndicatorTransform {
  GlossDamageIndicatorTransform({
    required this.startScale,
    required this.endScale,
    required this.fadeStartFraction,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  double startScale;
  double endScale;
  double fadeStartFraction;
  Map<String, dynamic> extras;

  static GlossDamageIndicatorTransform fromJson(
    Object? raw, {
    required GlossDamageIndicatorTransform fallback,
    required String path,
    bool requireComplete = false,
  }) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    if (requireComplete) _requireKeys(map, _transformKnown, path);
    return GlossDamageIndicatorTransform(
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
      extras: huiCollectExtras(map, _transformKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'startScale': startScale,
    'endScale': endScale,
    'fadeStartFraction': fadeStartFraction,
  }, extras);

  GlossDamageIndicatorTransform copy() => GlossDamageIndicatorTransform(
    startScale: startScale,
    endScale: endScale,
    fadeStartFraction: fadeStartFraction,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossDamageIndicatorPresentation {
  GlossDamageIndicatorPresentation({
    required this.format,
    required this.offset,
    required this.motion,
    required this.transform,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  String format;
  Vec3 offset;
  GlossDamageIndicatorMotion motion;
  GlossDamageIndicatorTransform transform;
  Map<String, dynamic> extras;

  static GlossDamageIndicatorPresentation damageDefaults() =>
      GlossDamageIndicatorPresentation(
        format: '&c&l{amount}',
        offset: Vec3(0, 0.7, 0),
        motion: GlossDamageIndicatorMotion(
          horizontalSpeed: 0.8,
          verticalSpeed: 1.3,
          verticalAcceleration: -0.93,
        ),
        transform: GlossDamageIndicatorTransform(
          startScale: 1,
          endScale: 0.82,
          fadeStartFraction: 0.68,
        ),
      );

  static GlossDamageIndicatorPresentation healingDefaults() =>
      GlossDamageIndicatorPresentation(
        format: '&a&l{amount}',
        offset: Vec3(0, -0.1, 0),
        motion: GlossDamageIndicatorMotion(
          horizontalSpeed: 0.45,
          verticalSpeed: 0.65,
          verticalAcceleration: 0.05,
        ),
        transform: GlossDamageIndicatorTransform(
          startScale: 1,
          endScale: 1.1,
          fadeStartFraction: 0.62,
        ),
      );

  static GlossDamageIndicatorPresentation fromJson(
    Object? raw, {
    required GlossDamageIndicatorPresentation fallback,
    required String path,
    bool requireComplete = false,
  }) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    if (requireComplete) _requireKeys(map, _indicatorPresentationKnown, path);
    return GlossDamageIndicatorPresentation(
      format: huiReadString(map, 'format', fallback: fallback.format),
      offset: map['offset'] == null
          ? fallback.offset.copy()
          : Vec3.fromJson(map['offset'], path: '$path.offset'),
      motion: GlossDamageIndicatorMotion.fromJson(
        map['motion'],
        fallback: fallback.motion,
        path: '$path.motion',
        requireComplete: requireComplete,
      ),
      transform: GlossDamageIndicatorTransform.fromJson(
        map['transform'],
        fallback: fallback.transform,
        path: '$path.transform',
        requireComplete: requireComplete,
      ),
      extras: huiCollectExtras(map, _indicatorPresentationKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'format': format,
    'offset': offset.toJson(),
    'motion': motion.toJson(),
    'transform': transform.toJson(),
  }, extras);

  GlossDamageIndicatorPresentation copy() => GlossDamageIndicatorPresentation(
    format: format,
    offset: offset.copy(),
    motion: motion.copy(),
    transform: transform.copy(),
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossDamageIndicatorVariant {
  GlossDamageIndicatorVariant({
    this.id = '',
    this.priority = 0,
    this.when = 'false',
    GlossDamageIndicatorPresentation? presentation,
    Map<String, dynamic>? extras,
  }) : presentation =
           presentation ?? GlossDamageIndicatorPresentation.damageDefaults(),
       extras = extras ?? <String, dynamic>{};

  String id;
  int priority;
  String when;
  GlossDamageIndicatorPresentation presentation;
  Map<String, dynamic> extras;

  static GlossDamageIndicatorVariant fromJson(
    Object? raw,
    int index, {
    required String stylePath,
    required GlossDamageIndicatorPresentation fallback,
  }) {
    final String path = '$stylePath.variants[$index]';
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossDamageIndicatorVariant(
      id: huiReadString(map, 'id'),
      priority: huiReadInt(map, 'priority'),
      when: huiReadString(map, 'when'),
      presentation: GlossDamageIndicatorPresentation.fromJson(
        map['presentation'],
        fallback: fallback,
        path: '$path.presentation',
        requireComplete: true,
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

  GlossDamageIndicatorVariant copy() => GlossDamageIndicatorVariant(
    id: id,
    priority: priority,
    when: when,
    presentation: presentation.copy(),
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossDamageIndicatorStyle {
  GlossDamageIndicatorStyle({
    this.when = 'true',
    required this.presentation,
    List<GlossDamageIndicatorVariant>? variants,
    Map<String, dynamic>? extras,
  }) : variants = variants ?? <GlossDamageIndicatorVariant>[],
       extras = extras ?? <String, dynamic>{};

  String when;
  GlossDamageIndicatorPresentation presentation;
  List<GlossDamageIndicatorVariant> variants;
  Map<String, dynamic> extras;

  static GlossDamageIndicatorStyle damageDefaults() =>
      GlossDamageIndicatorStyle(
        presentation: GlossDamageIndicatorPresentation.damageDefaults(),
      );

  static GlossDamageIndicatorStyle healingDefaults() =>
      GlossDamageIndicatorStyle(
        presentation: GlossDamageIndicatorPresentation.healingDefaults(),
      );

  static GlossDamageIndicatorStyle fromJson(
    Object? raw, {
    required GlossDamageIndicatorStyle fallback,
    required String path,
  }) {
    if (raw == null) return fallback.copy();
    final Map<String, dynamic> map = huiReadObject(raw, path);
    final List<Object?> rawVariants = huiReadList(map['variants']);
    return GlossDamageIndicatorStyle(
      when: huiReadString(map, 'when', fallback: fallback.when),
      presentation: GlossDamageIndicatorPresentation.fromJson(
        map['presentation'],
        fallback: fallback.presentation,
        path: '$path.presentation',
      ),
      variants: <GlossDamageIndicatorVariant>[
        for (int index = 0; index < rawVariants.length; index++)
          GlossDamageIndicatorVariant.fromJson(
            rawVariants[index],
            index,
            stylePath: path,
            fallback: fallback.presentation,
          ),
      ],
      extras: huiCollectExtras(map, _styleKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'when': when,
    'presentation': presentation.toJson(),
    'variants': <Map<String, dynamic>>[
      for (final GlossDamageIndicatorVariant variant in variants)
        variant.toJson(),
    ],
  }, extras);

  GlossDamageIndicatorStyle copy() => GlossDamageIndicatorStyle(
    when: when,
    presentation: presentation.copy(),
    variants: <GlossDamageIndicatorVariant>[
      for (final GlossDamageIndicatorVariant variant in variants)
        variant.copy(),
    ],
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossDamageIndicatorAudience {
  GlossDamageIndicatorAudience({
    this.when = "hasPermission('viewer', 'gloss.indicators.show')",
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  String when;
  Map<String, dynamic> extras;

  static GlossDamageIndicatorAudience fromJson(Object? raw) {
    if (raw == null) return GlossDamageIndicatorAudience();
    final Map<String, dynamic> map = huiReadObject(raw, r'$.audience');
    return GlossDamageIndicatorAudience(
      when: huiReadString(
        map,
        'when',
        fallback: "hasPermission('viewer', 'gloss.indicators.show')",
      ),
      extras: huiCollectExtras(map, _audienceKnown),
    );
  }

  Map<String, dynamic> toJson() =>
      huiMergeExtras(<String, dynamic>{'when': when}, extras);

  GlossDamageIndicatorAudience copy() =>
      GlossDamageIndicatorAudience(when: when, extras: huiDeepCopyMap(extras));
}

final class GlossDamageIndicatorsDoc extends GlossDoc {
  GlossDamageIndicatorsDoc({
    super.schemaVersion = glossDamageIndicatorsCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    GlossDamageIndicatorLimits? limits,
    GlossDamageIndicatorStyle? damage,
    GlossDamageIndicatorStyle? healing,
    GlossDamageIndicatorAudience? audience,
    Map<String, dynamic>? extras,
  }) : limits = limits ?? GlossDamageIndicatorLimits(),
       damage = damage ?? GlossDamageIndicatorStyle.damageDefaults(),
       healing = healing ?? GlossDamageIndicatorStyle.healingDefaults(),
       audience = audience ?? GlossDamageIndicatorAudience(),
       extras = extras ?? <String, dynamic>{};

  GlossDamageIndicatorLimits limits;
  GlossDamageIndicatorStyle damage;
  GlossDamageIndicatorStyle healing;
  GlossDamageIndicatorAudience audience;
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
      audience: GlossDamageIndicatorAudience.fromJson(map['audience']),
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
    'audience': audience.toJson(),
  }, extras);

  GlossDamageIndicatorsDoc copy() => GlossDamageIndicatorsDoc(
    schemaVersion: schemaVersion,
    revision: revision,
    limits: limits.copy(),
    damage: damage.copy(),
    healing: healing.copy(),
    audience: audience.copy(),
    extras: huiDeepCopyMap(extras),
  );
}

void _requireKeys(Map<String, dynamic> map, Set<String> keys, String path) {
  for (final String key in keys) {
    if (!map.containsKey(key) || map[key] == null) {
      throw HuiFormatException(
        'Conditional damage-indicator presentations must be complete.',
        '$path.$key',
      );
    }
  }
}

/// Mirror of Gloss `BubbleStyleDoc.java` — one chat-bubble style per file:
///
/// ```json
/// {
///   "schemaVersion": 3,
///   "revision": 1,
///   "prefix": "&7",
///   "offset": [0.0, 0.3, 0.0],
///   "wordWrapChars": 32,
///   "maxAliveMs": 5000,
///   "motion": {
///     "translation": {"x": "0", "y": "8 * t", "z": "0"},
///     "scale": {"x": "1", "y": "1", "z": "1"},
///     "rotation": {"x": "0", "y": "0", "z": "0"},
///     "opacity": "1"
///   },
///   "shimmer": {
///     "spawn": true,
///     "flyAway": true,
///     "color": "#ffffff",
///     "width": 3,
///     "durationMs": 700,
///     "spawnDelayMs": 400,
///     "flyAwayLeadMs": 700
///   },
///   "followPlayer": true,
///   "hideOwn": true,
///   "select": {"priority": 10, "when": "viewer.world == 'world'"}
/// }
/// ```
///
/// The document id is the file path under `plugins/Gloss/bubbles/`. The Java
/// record fixes almost everything SILENTLY (`BubbleStyleDoc.java:21-28`): a
/// null prefix becomes `&7`, a null offset becomes `(0, 1, 0)`,
/// `wordWrapChars` clamps into 8..128 and `maxAliveMs` into 500..60000 — the
/// editor preserves what was written and
/// exposes the effective forms, so validation can warn with the value the
/// server will actually run. `select` is genuinely optional (null skips
/// auto-matching entirely, `BubbleStyles.resolveStyleId`). The offset itself
/// parses through the strict
/// `[x, y, z]` Vector adapter — a present-but-malformed one kills the file,
/// exactly like a hologram anchor position.
library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';
import 'particle_layer.dart';

/// `BubbleStyleDoc` clamp bounds.
const int glossBubbleMinWordWrapChars = 8;
const int glossBubbleMaxWordWrapChars = 128;
const int glossBubbleMinMaxAliveMs = 500;
const int glossBubbleMaxMaxAliveMs = 60000;
const int glossBubbleMinShimmerWidth = 1;
const int glossBubbleMaxShimmerWidth = 16;
const int glossBubbleMinShimmerDurationMs = 100;
const int glossBubbleMaxShimmerDurationMs = 10000;
const int glossBubbleMaxShimmerOffsetMs = 60000;

/// Shipped two-pass shimmer timing from `BubbleShimmerPlan`.
const int glossBubbleShimmerDefaultDurationMs = 700;
const int glossBubbleShimmerDefaultSpawnDelayMs = 400;
const int glossBubbleShimmerDefaultFlyAwayLeadMs = 700;

/// `BubbleStyleDoc.Shimmer.DEFAULT_COLOR` — the solid shimmer band color.
const String glossBubbleShimmerDefaultColor = '#ffffff';

const int glossBubbleCurrentSchemaVersion = 4;

const String glossBubbleDefaultTranslationY =
    '10 * pow(clamp((ageMs - lifetimeMs + 2000) / 2000, 0, 1), 16)';

/// `BubbleStyleDoc.DEFAULTS` prefix, applied when the file carries none.
const String glossBubbleDefaultPrefix = '&7';

/// `BubbleStyles.DEFAULT_STYLE_ID` — the fallback style when nothing
/// matches; `BubbleStyles.STYLE_PERMISSION_PREFIX` gates explicit choices.
const String glossBubbleDefaultStyleId = 'default';
const String glossBubbleStylePermissionPrefix = 'gloss.bubbles.style.';

/// True when [json] has the shape of a Gloss bubble style: the versioned
/// envelope plus bubble keys no other kind carries. Routing only — full
/// checking is `validateBubbleStyleDoc`'s job.
bool looksLikeBubbleStyleDoc(Object? json) {
  if (json is! Map) return false;
  if (json['schemaVersion'] is! num) return false;
  if (json.containsKey('anchor') ||
      json.containsKey('frames') ||
      json.containsKey('entries') ||
      json.containsKey('emoji') ||
      json.containsKey('components') ||
      json.containsKey('elements')) {
    return false;
  }
  return json.containsKey('wordWrapChars') ||
      json.containsKey('maxAliveMs') ||
      json.containsKey('motion') ||
      json.containsKey('shimmer') ||
      json.containsKey('followPlayer') ||
      json.containsKey('hideOwn');
}

GlossBubbleStyleDoc decodeGlossBubbleStyleDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': e.message,
    });
  }
  return GlossBubbleStyleDoc.fromJson(raw);
}

String encodeGlossBubbleStyleDoc(GlossBubbleStyleDoc doc) =>
    huiWriteJson(doc.toJson());

GlossBubbleStyleDoc cloneGlossBubbleStyleDoc(GlossBubbleStyleDoc doc) =>
    GlossBubbleStyleDoc.fromJson(huiDeepCopy(doc.toJson()));

const Set<String> _docKnown = <String>{
  'schemaVersion',
  'revision',
  'prefix',
  'offset',
  'wordWrapChars',
  'maxAliveMs',
  'motion',
  'shimmer',
  'followPlayer',
  'hideOwn',
  'select',
  'particleLayers',
};

const Set<String> _selectKnown = <String>{'priority', 'when'};
const Set<String> _motionKnown = <String>{
  'translation',
  'scale',
  'rotation',
  'opacity',
};
const Set<String> _motionVectorKnown = <String>{'x', 'y', 'z'};
const Set<String> _shimmerKnown = <String>{
  'spawn',
  'flyAway',
  'color',
  'width',
  'durationMs',
  'spawnDelayMs',
  'flyAwayLeadMs',
};

/// `BubbleStyleDoc.Select` — the auto-match rule. A style without one never
/// auto-matches and is only reachable by explicit player choice (or as the
/// `default` fallback).
final class GlossBubbleSelect {
  GlossBubbleSelect({
    this.priority = 0,
    this.when = 'false',
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  /// Highest matching priority wins; ties break to the lexicographically
  /// smaller style id (`BubbleStyles.resolveStyleId`).
  int priority;
  String when;

  Map<String, dynamic> extras;

  static GlossBubbleSelect fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$.select');
    return GlossBubbleSelect(
      priority: huiReadInt(map, 'priority'),
      when: huiReadString(map, 'when'),
      extras: huiCollectExtras(map, _selectKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'priority': priority,
    'when': when,
  }, extras);

  GlossBubbleSelect copy() => GlossBubbleSelect(
    priority: priority,
    when: when,
    extras: huiDeepCopyMap(extras),
  );
}

String _readBubbleMotionValue(
  Map<String, dynamic> map,
  String key,
  String fallback,
  String path,
) {
  final Object? value = map[key];
  if (value == null) return fallback;
  if (value is String) return value;
  throw HuiFormatException(
    'Bubble motion values must be expression strings.',
    '$path.$key',
  );
}

final class GlossBubbleMotionVector {
  GlossBubbleMotionVector({
    required this.x,
    required this.y,
    required this.z,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  String x;
  String y;
  String z;
  Map<String, dynamic> extras;

  static GlossBubbleMotionVector translationDefaults() =>
      GlossBubbleMotionVector(
        x: '0',
        y: glossBubbleDefaultTranslationY,
        z: '0',
      );

  static GlossBubbleMotionVector scaleDefaults() =>
      GlossBubbleMotionVector(x: '1', y: '1', z: '1');

  static GlossBubbleMotionVector rotationDefaults() =>
      GlossBubbleMotionVector(x: '0', y: '0', z: '0');

  static GlossBubbleMotionVector fromJson(
    Object? raw, {
    required GlossBubbleMotionVector defaults,
    required String path,
  }) {
    if (raw == null) return defaults.copy();
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossBubbleMotionVector(
      x: _readBubbleMotionValue(map, 'x', defaults.x, path),
      y: _readBubbleMotionValue(map, 'y', defaults.y, path),
      z: _readBubbleMotionValue(map, 'z', defaults.z, path),
      extras: huiCollectExtras(map, _motionVectorKnown),
    );
  }

  Map<String, dynamic> toJson() =>
      huiMergeExtras(<String, dynamic>{'x': x, 'y': y, 'z': z}, extras);

  GlossBubbleMotionVector copy() =>
      GlossBubbleMotionVector(x: x, y: y, z: z, extras: huiDeepCopyMap(extras));
}

final class GlossBubbleMotion {
  GlossBubbleMotion({
    required this.translation,
    required this.scale,
    required this.rotation,
    required this.opacity,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  GlossBubbleMotionVector translation;
  GlossBubbleMotionVector scale;
  GlossBubbleMotionVector rotation;
  String opacity;
  Map<String, dynamic> extras;

  factory GlossBubbleMotion.runtimeDefaults() => GlossBubbleMotion(
    translation: GlossBubbleMotionVector.translationDefaults(),
    scale: GlossBubbleMotionVector.scaleDefaults(),
    rotation: GlossBubbleMotionVector.rotationDefaults(),
    opacity: '1',
  );

  factory GlossBubbleMotion.identity() => GlossBubbleMotion(
    translation: GlossBubbleMotionVector(x: '0', y: '0', z: '0'),
    scale: GlossBubbleMotionVector.scaleDefaults(),
    rotation: GlossBubbleMotionVector.rotationDefaults(),
    opacity: '1',
  );

  static GlossBubbleMotion fromJson(Object? raw) {
    final GlossBubbleMotion defaults = GlossBubbleMotion.runtimeDefaults();
    if (raw == null) return defaults;
    final Map<String, dynamic> map = huiReadObject(raw, r'$.motion');
    return GlossBubbleMotion(
      translation: GlossBubbleMotionVector.fromJson(
        map['translation'],
        defaults: defaults.translation,
        path: r'$.motion.translation',
      ),
      scale: GlossBubbleMotionVector.fromJson(
        map['scale'],
        defaults: defaults.scale,
        path: r'$.motion.scale',
      ),
      rotation: GlossBubbleMotionVector.fromJson(
        map['rotation'],
        defaults: defaults.rotation,
        path: r'$.motion.rotation',
      ),
      opacity: _readBubbleMotionValue(
        map,
        'opacity',
        defaults.opacity,
        r'$.motion',
      ),
      extras: huiCollectExtras(map, _motionKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'translation': translation.toJson(),
    'scale': scale.toJson(),
    'rotation': rotation.toJson(),
    'opacity': opacity,
  }, extras);

  GlossBubbleMotion copy() => GlossBubbleMotion(
    translation: translation.copy(),
    scale: scale.copy(),
    rotation: rotation.copy(),
    opacity: opacity,
    extras: huiDeepCopyMap(extras),
  );
}

/// `BubbleStyleDoc.Shimmer` — the Gloss shine band.
///
/// `spawn` enables one bounded sweep after `spawnDelayMs`. `flyAway` enables a
/// second bounded sweep beginning `flyAwayLeadMs` before expiry. Each pass
/// takes `durationMs`, and one band crosses the complete multiline block.
///
/// Every lit glyph uses `color`; the shipped three-glyph band is solid white,
/// matching the original Gloss special-colour filter.
final class GlossBubbleShimmer {
  GlossBubbleShimmer({
    this.spawn = true,
    this.flyAway = true,
    this.color = glossBubbleShimmerDefaultColor,
    this.width = 3,
    this.durationMs = glossBubbleShimmerDefaultDurationMs,
    this.spawnDelayMs = glossBubbleShimmerDefaultSpawnDelayMs,
    this.flyAwayLeadMs = glossBubbleShimmerDefaultFlyAwayLeadMs,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  bool spawn;
  bool flyAway;

  /// The color applied to every lit glyph in the band.
  String color;

  int width;
  int durationMs;
  int spawnDelayMs;
  int flyAwayLeadMs;
  Map<String, dynamic> extras;

  int get effectiveWidth =>
      width.clamp(glossBubbleMinShimmerWidth, glossBubbleMaxShimmerWidth);

  int get effectiveDurationMs => durationMs.clamp(
    glossBubbleMinShimmerDurationMs,
    glossBubbleMaxShimmerDurationMs,
  );

  int get effectiveSpawnDelayMs =>
      spawnDelayMs.clamp(0, glossBubbleMaxShimmerOffsetMs);

  int get effectiveFlyAwayLeadMs =>
      flyAwayLeadMs.clamp(0, glossBubbleMaxShimmerOffsetMs);

  static final RegExp _rgb = RegExp(r'^#[0-9a-fA-F]{6}$');

  bool get colorIsValid => _rgb.hasMatch(color.trim());

  String get effectiveColor => colorIsValid
      ? color.trim().toLowerCase()
      : glossBubbleShimmerDefaultColor;

  static GlossBubbleShimmer fromJson(Object? raw) {
    if (raw == null) return GlossBubbleShimmer();
    final Map<String, dynamic> map = huiReadObject(raw, r'$.shimmer');
    return GlossBubbleShimmer(
      spawn: map.containsKey('spawn') ? huiReadBool(map, 'spawn') : true,
      flyAway: map.containsKey('flyAway') ? huiReadBool(map, 'flyAway') : true,
      color: map.containsKey('color')
          ? huiReadString(map, 'color')
          : glossBubbleShimmerDefaultColor,
      width: map.containsKey('width') ? huiReadInt(map, 'width') : 3,
      durationMs: map.containsKey('durationMs')
          ? huiReadInt(map, 'durationMs')
          : glossBubbleShimmerDefaultDurationMs,
      spawnDelayMs: map.containsKey('spawnDelayMs')
          ? huiReadInt(map, 'spawnDelayMs')
          : glossBubbleShimmerDefaultSpawnDelayMs,
      flyAwayLeadMs: map.containsKey('flyAwayLeadMs')
          ? huiReadInt(map, 'flyAwayLeadMs')
          : glossBubbleShimmerDefaultFlyAwayLeadMs,
      extras: huiCollectExtras(map, _shimmerKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'spawn': spawn,
    'flyAway': flyAway,
    'color': color,
    'width': width,
    'durationMs': durationMs,
    'spawnDelayMs': spawnDelayMs,
    'flyAwayLeadMs': flyAwayLeadMs,
  }, extras);

  GlossBubbleShimmer copy() => GlossBubbleShimmer(
    spawn: spawn,
    flyAway: flyAway,
    color: color,
    width: width,
    durationMs: durationMs,
    spawnDelayMs: spawnDelayMs,
    flyAwayLeadMs: flyAwayLeadMs,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossBubbleStyleDoc extends GlossDoc {
  GlossBubbleStyleDoc({
    super.schemaVersion = glossBubbleCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    this.prefix = '',
    this.offsetRaw,
    this.wordWrapChars = 0,
    this.maxAliveMs = 0,
    GlossBubbleMotion? motion,
    GlossBubbleShimmer? shimmer,
    this.followPlayer = false,
    this.hideOwn = false,
    this.select,
    List<GlossParticleLayer>? particleLayers,
    Map<String, dynamic>? extras,
    Set<String>? absentKeys,
  }) : motion = motion ?? GlossBubbleMotion.runtimeDefaults(),
       shimmer = shimmer ?? GlossBubbleShimmer(),
       particleLayers = particleLayers ?? <GlossParticleLayer>[],
       extras = extras ?? <String, dynamic>{},
       absentKeys = absentKeys ?? <String>{};

  /// Colour prefix prepended to every bubble line, as written. Only a
  /// MISSING key falls to `&7` — an explicit `""` stays empty
  /// (`prefix == null` is the Java guard).
  String prefix;

  /// Whatever JSON value the `offset` slot carried, re-emitted verbatim.
  /// Null when the key was absent (the plugin then uses `(0, 1, 0)`).
  Object? offsetRaw;

  /// As written; see the `effective*` getters for the silent clamps.
  int wordWrapChars;
  int maxAliveMs;

  GlossBubbleMotion motion;
  GlossBubbleShimmer shimmer;
  bool followPlayer;
  bool hideOwn;

  /// Null when the file has no `select` — the style never auto-matches.
  GlossBubbleSelect? select;
  List<GlossParticleLayer> particleLayers;
  bool particleLayersPresent = false;

  Map<String, dynamic> extras;
  Set<String> absentKeys;

  /// The prefix the server runs: the written one, or `&7` when the key was
  /// absent.
  String get effectivePrefix =>
      absentKeys.contains('prefix') ? glossBubbleDefaultPrefix : prefix;

  /// The offset as a length-3 triple: the written numbers, or the plugin's
  /// `(0, 1, 0)` default when the key was absent. Zero-padded when the raw
  /// shape is not a triple — the renderable reading, never a replacement.
  List<double> get offset {
    final Object? raw = offsetRaw;
    if (raw == null) return const <double>[0, 0.3, 0];
    final List<Object?> entries = raw is List ? raw : const <Object?>[];
    return List<double>.generate(3, (int axis) {
      if (axis >= entries.length) return 0;
      final Object? value = entries[axis];
      final double parsed = value is num
          ? value.toDouble()
          : value is String
          ? double.tryParse(value) ?? 0
          : 0;
      return parsed.isFinite ? parsed : 0;
    });
  }

  /// True when [offsetRaw] would pass the strict vector adapter: absent, or
  /// exactly three finite numbers.
  bool get offsetIsValidTriple {
    final Object? raw = offsetRaw;
    if (raw == null) return true;
    if (raw is! List || raw.length != 3) return false;
    for (final Object? value in raw) {
      if (value is! num || !value.toDouble().isFinite) return false;
    }
    return true;
  }

  void setOffset(double x, double y, double z) {
    offsetRaw = <num>[x, y, z];
    absentKeys.remove('offset');
  }

  int get effectiveWordWrapChars => wordWrapChars.clamp(
    glossBubbleMinWordWrapChars,
    glossBubbleMaxWordWrapChars,
  );

  int get effectiveMaxAliveMs =>
      maxAliveMs.clamp(glossBubbleMinMaxAliveMs, glossBubbleMaxMaxAliveMs);

  static GlossBubbleStyleDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(
      map,
      'bubbles',
      expected: glossBubbleCurrentSchemaVersion,
    );
    final GlossBubbleStyleDoc doc = GlossBubbleStyleDoc(
      schemaVersion: glossBubbleCurrentSchemaVersion,
      revision: glossReadRevision(map),
      prefix: huiReadString(map, 'prefix'),
      offsetRaw: huiDeepCopy(map['offset']),
      wordWrapChars: huiReadInt(map, 'wordWrapChars'),
      maxAliveMs: huiReadInt(map, 'maxAliveMs'),
      motion: GlossBubbleMotion.fromJson(map['motion']),
      shimmer: GlossBubbleShimmer.fromJson(map['shimmer']),
      followPlayer: huiReadBool(map, 'followPlayer'),
      hideOwn: huiReadBool(map, 'hideOwn'),
      select: map['select'] == null
          ? null
          : GlossBubbleSelect.fromJson(map['select']),
      particleLayers: glossReadParticleLayers(map['particleLayers']),
      extras: huiCollectExtras(map, _docKnown),
      absentKeys: <String>{
        if (map['revision'] == null) 'revision',
        if (map['prefix'] == null) 'prefix',
        if (map['offset'] == null) 'offset',
        if (map['wordWrapChars'] == null) 'wordWrapChars',
        if (map['maxAliveMs'] == null) 'maxAliveMs',
        if (map['followPlayer'] == null) 'followPlayer',
        if (map['hideOwn'] == null) 'hideOwn',
      },
    );
    doc.particleLayersPresent = map.containsKey('particleLayers');
    return doc;
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{
      'schemaVersion': schemaVersion,
      if (!absentKeys.contains('revision')) 'revision': revision,
      if (!absentKeys.contains('prefix') || prefix.isNotEmpty) 'prefix': prefix,
      if (offsetRaw != null) 'offset': huiDeepCopy(offsetRaw),
      if (!absentKeys.contains('wordWrapChars') || wordWrapChars != 0)
        'wordWrapChars': wordWrapChars,
      if (!absentKeys.contains('maxAliveMs') || maxAliveMs != 0)
        'maxAliveMs': maxAliveMs,
      'motion': motion.toJson(),
      'shimmer': shimmer.toJson(),
      if (!absentKeys.contains('followPlayer') || followPlayer)
        'followPlayer': followPlayer,
      if (!absentKeys.contains('hideOwn') || hideOwn) 'hideOwn': hideOwn,
      if (select != null) 'select': select!.toJson(),
      if (particleLayersPresent || particleLayers.isNotEmpty)
        'particleLayers': glossWriteParticleLayers(particleLayers),
    };
    return huiMergeExtras(out, extras);
  }

  GlossBubbleStyleDoc copy() {
    final GlossBubbleStyleDoc copied = GlossBubbleStyleDoc(
      schemaVersion: schemaVersion,
      revision: revision,
      prefix: prefix,
      offsetRaw: huiDeepCopy(offsetRaw),
      wordWrapChars: wordWrapChars,
      maxAliveMs: maxAliveMs,
      motion: motion.copy(),
      shimmer: shimmer.copy(),
      followPlayer: followPlayer,
      hideOwn: hideOwn,
      select: select?.copy(),
      particleLayers: glossCopyParticleLayers(particleLayers),
      extras: huiDeepCopyMap(extras),
      absentKeys: Set<String>.of(absentKeys),
    );
    copied.particleLayersPresent = particleLayersPresent;
    return copied;
  }
}

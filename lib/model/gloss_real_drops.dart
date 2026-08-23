library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'gloss_real_drop_animation.dart';
import 'json_codec.dart';

const int glossRealDropsCurrentSchemaVersion = 1;

/// Whether [json] is a real-drops settings document.
///
/// Two shapes count. The first is the shipped one: every presentation block
/// present, which is what the plugin writes and what the editor exports. The
/// second is a document that carries `physics` or `script` — the two blocks no
/// other Gloss kind has a key for — because the plugin accepts a file made of
/// nothing but `schemaVersion`, `revision` and one of those blocks, and every
/// worked example in `DROP_SCRIPT_FORMAT.md` is written that way. Refusing them
/// would mean the editor rejects documents the server loads.
bool looksLikeRealDropSettingsDoc(Object? json) {
  if (json is! Map || json['schemaVersion'] is! num) return false;
  if (json.containsKey('physics') ||
      json.containsKey('script') ||
      json.containsKey('animation')) {
    return true;
  }
  return json.containsKey('limits') &&
      json.containsKey('scale') &&
      json.containsKey('motion') &&
      json.containsKey('landing') &&
      json.containsKey('labels') &&
      json.containsKey('filters');
}

GlossRealDropSettingsDoc decodeGlossRealDropSettingsDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': e.message,
    });
  }
  return GlossRealDropSettingsDoc.fromJson(raw);
}

String encodeGlossRealDropSettingsDoc(GlossRealDropSettingsDoc doc) =>
    huiWriteJson(doc.toJson());

const Set<String> _docKnown = <String>{
  'schemaVersion',
  'revision',
  'limits',
  'scale',
  'motion',
  'landing',
  'labels',
  'filters',
  'physics',
  'script',
  'animation',
};

final class GlossRealDropLimits {
  GlossRealDropLimits({
    this.updateIntervalTicks = 2,
    this.settledPollIntervalTicks = 20,
    this.maxVisualsPerStack = 3,
    this.maxVisualsPerChunk = 128,
    this.viewRange = 32,
    this.spread = 0.18,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  int updateIntervalTicks;
  int settledPollIntervalTicks;
  int maxVisualsPerStack;
  int maxVisualsPerChunk;
  double viewRange;
  double spread;
  Map<String, dynamic> extras;

  static GlossRealDropLimits fromJson(Object? raw) {
    if (raw == null) return GlossRealDropLimits();
    final Map<String, dynamic> map = huiReadObject(raw, r'$.limits');
    return GlossRealDropLimits(
      updateIntervalTicks: huiReadInt(map, 'updateIntervalTicks', fallback: 2),
      settledPollIntervalTicks: huiReadInt(
        map,
        'settledPollIntervalTicks',
        fallback: 20,
      ),
      maxVisualsPerStack: huiReadInt(map, 'maxVisualsPerStack', fallback: 3),
      maxVisualsPerChunk: huiReadInt(map, 'maxVisualsPerChunk', fallback: 128),
      viewRange: huiReadDouble(map, 'viewRange', fallback: 32),
      spread: huiReadDouble(map, 'spread', fallback: 0.18),
      extras: huiCollectExtras(map, const <String>{
        'updateIntervalTicks',
        'settledPollIntervalTicks',
        'maxVisualsPerStack',
        'maxVisualsPerChunk',
        'viewRange',
        'spread',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'updateIntervalTicks': updateIntervalTicks,
    'settledPollIntervalTicks': settledPollIntervalTicks,
    'maxVisualsPerStack': maxVisualsPerStack,
    'maxVisualsPerChunk': maxVisualsPerChunk,
    'viewRange': viewRange,
    'spread': spread,
  }, extras);

  GlossRealDropLimits copy() => GlossRealDropLimits.fromJson(toJson());
}

final class GlossRealDropScale {
  GlossRealDropScale({
    this.defaultScale = 0.4,
    this.flatItems = 0.65,
    this.thinBlocks = 0.45,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  double defaultScale;
  double flatItems;
  double thinBlocks;
  Map<String, dynamic> extras;

  static GlossRealDropScale fromJson(Object? raw) {
    if (raw == null) return GlossRealDropScale();
    final Map<String, dynamic> map = huiReadObject(raw, r'$.scale');
    return GlossRealDropScale(
      defaultScale: huiReadDouble(map, 'defaultScale', fallback: 0.4),
      flatItems: huiReadDouble(map, 'flatItems', fallback: 0.65),
      thinBlocks: huiReadDouble(map, 'thinBlocks', fallback: 0.45),
      extras: huiCollectExtras(map, const <String>{
        'defaultScale',
        'flatItems',
        'thinBlocks',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'defaultScale': defaultScale,
    'flatItems': flatItems,
    'thinBlocks': thinBlocks,
  }, extras);

  GlossRealDropScale copy() => GlossRealDropScale.fromJson(toJson());
}

final class GlossRealDropMotion {
  GlossRealDropMotion({
    this.tumble = true,
    this.speedMultiplier = 1.35,
    this.degreesPerSecondX = 160,
    this.degreesPerSecondY = 120,
    this.degreesPerSecondZ = 100,
    this.variance = 0.2,
    this.changeOnBounce = true,
    this.velocityInfluence = 0.35,
    this.submergedSpinMultiplier = 0.35,
    this.groundRollMultiplier = 1,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  bool tumble;
  double speedMultiplier;
  double degreesPerSecondX;
  double degreesPerSecondY;
  double degreesPerSecondZ;
  double variance;
  bool changeOnBounce;
  double velocityInfluence;
  double submergedSpinMultiplier;
  double groundRollMultiplier;
  Map<String, dynamic> extras;

  static GlossRealDropMotion fromJson(Object? raw) {
    if (raw == null) return GlossRealDropMotion();
    final Map<String, dynamic> map = huiReadObject(raw, r'$.motion');
    return GlossRealDropMotion(
      tumble: map['tumble'] == null ? true : huiReadBool(map, 'tumble'),
      speedMultiplier: huiReadDouble(map, 'speedMultiplier', fallback: 1.35),
      degreesPerSecondX: huiReadDouble(map, 'degreesPerSecondX', fallback: 160),
      degreesPerSecondY: huiReadDouble(map, 'degreesPerSecondY', fallback: 120),
      degreesPerSecondZ: huiReadDouble(map, 'degreesPerSecondZ', fallback: 100),
      variance: huiReadDouble(map, 'variance', fallback: 0.2),
      changeOnBounce: map['changeOnBounce'] == null
          ? true
          : huiReadBool(map, 'changeOnBounce'),
      velocityInfluence: huiReadDouble(
        map,
        'velocityInfluence',
        fallback: 0.35,
      ),
      submergedSpinMultiplier: huiReadDouble(
        map,
        'submergedSpinMultiplier',
        fallback: 0.35,
      ),
      groundRollMultiplier: huiReadDouble(
        map,
        'groundRollMultiplier',
        fallback: 1,
      ),
      extras: huiCollectExtras(map, const <String>{
        'tumble',
        'speedMultiplier',
        'degreesPerSecondX',
        'degreesPerSecondY',
        'degreesPerSecondZ',
        'variance',
        'changeOnBounce',
        'velocityInfluence',
        'submergedSpinMultiplier',
        'groundRollMultiplier',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'tumble': tumble,
    'speedMultiplier': speedMultiplier,
    'degreesPerSecondX': degreesPerSecondX,
    'degreesPerSecondY': degreesPerSecondY,
    'degreesPerSecondZ': degreesPerSecondZ,
    'variance': variance,
    'changeOnBounce': changeOnBounce,
    'velocityInfluence': velocityInfluence,
    'submergedSpinMultiplier': submergedSpinMultiplier,
    'groundRollMultiplier': groundRollMultiplier,
  }, extras);

  GlossRealDropMotion copy() => GlossRealDropMotion.fromJson(toJson());
}

final class GlossRealDropLanding {
  GlossRealDropLanding({
    this.mode = 'NATURAL',
    this.tiltDegrees = 10,
    this.randomYaw = true,
    this.transitionTicks = 4,
    this.faceAttraction = 0.55,
    this.movingFaceAttraction = 0.15,
    this.alignmentDegrees = 0.5,
    this.settleDelayTicks = 4,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  String mode;
  double tiltDegrees;
  bool randomYaw;
  int transitionTicks;
  double faceAttraction;
  double movingFaceAttraction;
  double alignmentDegrees;
  int settleDelayTicks;
  Map<String, dynamic> extras;

  static GlossRealDropLanding fromJson(Object? raw) {
    if (raw == null) return GlossRealDropLanding();
    final Map<String, dynamic> map = huiReadObject(raw, r'$.landing');
    return GlossRealDropLanding(
      mode: huiReadString(map, 'mode', fallback: 'NATURAL').toUpperCase(),
      tiltDegrees: huiReadDouble(map, 'tiltDegrees', fallback: 10),
      randomYaw: map['randomYaw'] == null
          ? true
          : huiReadBool(map, 'randomYaw'),
      transitionTicks: huiReadInt(map, 'transitionTicks', fallback: 4),
      faceAttraction: huiReadDouble(map, 'faceAttraction', fallback: 0.55),
      movingFaceAttraction: huiReadDouble(
        map,
        'movingFaceAttraction',
        fallback: 0.15,
      ),
      alignmentDegrees: huiReadDouble(map, 'alignmentDegrees', fallback: 0.5),
      settleDelayTicks: huiReadInt(map, 'settleDelayTicks', fallback: 4),
      extras: huiCollectExtras(map, const <String>{
        'mode',
        'tiltDegrees',
        'randomYaw',
        'transitionTicks',
        'faceAttraction',
        'movingFaceAttraction',
        'alignmentDegrees',
        'settleDelayTicks',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'mode': mode,
    'tiltDegrees': tiltDegrees,
    'randomYaw': randomYaw,
    'transitionTicks': transitionTicks,
    'faceAttraction': faceAttraction,
    'movingFaceAttraction': movingFaceAttraction,
    'alignmentDegrees': alignmentDegrees,
    'settleDelayTicks': settleDelayTicks,
  }, extras);

  GlossRealDropLanding copy() => GlossRealDropLanding.fromJson(toJson());
}

final class GlossRealDropLabels {
  GlossRealDropLabels({
    this.enabled = true,
    this.yOffset = 0.55,
    this.scale = 0.85,
    this.viewRange = 32,
    this.billboard = 'CENTER',
    this.seeThrough = true,
    this.shadow = true,
    this.background = true,
    this.backgroundRed = 0,
    this.backgroundGreen = 0,
    this.backgroundBlue = 0,
    this.backgroundAlpha = 80,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  bool enabled;
  double yOffset;
  double scale;
  double viewRange;
  String billboard;
  bool seeThrough;
  bool shadow;
  bool background;
  int backgroundRed;
  int backgroundGreen;
  int backgroundBlue;
  int backgroundAlpha;
  Map<String, dynamic> extras;

  static GlossRealDropLabels fromJson(Object? raw) {
    if (raw == null) return GlossRealDropLabels();
    final Map<String, dynamic> map = huiReadObject(raw, r'$.labels');
    return GlossRealDropLabels(
      enabled: map['enabled'] == null ? true : huiReadBool(map, 'enabled'),
      yOffset: huiReadDouble(map, 'yOffset', fallback: 0.55),
      scale: huiReadDouble(map, 'scale', fallback: 0.85),
      viewRange: huiReadDouble(map, 'viewRange', fallback: 32),
      billboard: huiReadString(
        map,
        'billboard',
        fallback: 'CENTER',
      ).toUpperCase(),
      seeThrough: map['seeThrough'] == null
          ? true
          : huiReadBool(map, 'seeThrough'),
      shadow: map['shadow'] == null ? true : huiReadBool(map, 'shadow'),
      background: map['background'] == null
          ? true
          : huiReadBool(map, 'background'),
      backgroundRed: huiReadInt(map, 'backgroundRed'),
      backgroundGreen: huiReadInt(map, 'backgroundGreen'),
      backgroundBlue: huiReadInt(map, 'backgroundBlue'),
      backgroundAlpha: huiReadInt(map, 'backgroundAlpha', fallback: 80),
      extras: huiCollectExtras(map, const <String>{
        'enabled',
        'yOffset',
        'scale',
        'viewRange',
        'billboard',
        'seeThrough',
        'shadow',
        'background',
        'backgroundRed',
        'backgroundGreen',
        'backgroundBlue',
        'backgroundAlpha',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'enabled': enabled,
    'yOffset': yOffset,
    'scale': scale,
    'viewRange': viewRange,
    'billboard': billboard,
    'seeThrough': seeThrough,
    'shadow': shadow,
    'background': background,
    'backgroundRed': backgroundRed,
    'backgroundGreen': backgroundGreen,
    'backgroundBlue': backgroundBlue,
    'backgroundAlpha': backgroundAlpha,
  }, extras);

  GlossRealDropLabels copy() => GlossRealDropLabels.fromJson(toJson());
}

final class GlossRealDropFilters {
  GlossRealDropFilters({
    List<String>? disabledWorlds,
    List<String>? materialBlacklist,
    this.onlyPlayerDrops = false,
    Map<String, dynamic>? extras,
  }) : disabledWorlds = disabledWorlds ?? <String>[],
       materialBlacklist = materialBlacklist ?? <String>['BEDROCK', 'BARRIER'],
       extras = extras ?? <String, dynamic>{};

  List<String> disabledWorlds;
  List<String> materialBlacklist;
  bool onlyPlayerDrops;
  Map<String, dynamic> extras;

  static GlossRealDropFilters fromJson(Object? raw) {
    if (raw == null) return GlossRealDropFilters();
    final Map<String, dynamic> map = huiReadObject(raw, r'$.filters');
    return GlossRealDropFilters(
      disabledWorlds: huiReadStringList(map['disabledWorlds']),
      materialBlacklist: map['materialBlacklist'] == null
          ? <String>['BEDROCK', 'BARRIER']
          : huiReadStringList(map['materialBlacklist']),
      onlyPlayerDrops: huiReadBool(map, 'onlyPlayerDrops'),
      extras: huiCollectExtras(map, const <String>{
        'disabledWorlds',
        'materialBlacklist',
        'onlyPlayerDrops',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'disabledWorlds': List<String>.of(disabledWorlds),
    'materialBlacklist': List<String>.of(materialBlacklist),
    'onlyPlayerDrops': onlyPlayerDrops,
  }, extras);

  GlossRealDropFilters copy() => GlossRealDropFilters.fromJson(toJson());
}

final class GlossRealDropSettingsDoc extends GlossDoc {
  GlossRealDropSettingsDoc({
    super.schemaVersion = glossRealDropsCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    GlossRealDropLimits? limits,
    GlossRealDropScale? scale,
    GlossRealDropMotion? motion,
    GlossRealDropLanding? landing,
    GlossRealDropLabels? labels,
    GlossRealDropFilters? filters,
    this.physics,
    this.script,
    this.animation,
    Map<String, dynamic>? extras,
  }) : limits = limits ?? GlossRealDropLimits(),
       scale = scale ?? GlossRealDropScale(),
       motion = motion ?? GlossRealDropMotion(),
       landing = landing ?? GlossRealDropLanding(),
       labels = labels ?? GlossRealDropLabels(),
       filters = filters ?? GlossRealDropFilters(),
       extras = extras ?? <String, dynamic>{};

  GlossRealDropLimits limits;
  GlossRealDropScale scale;
  GlossRealDropMotion motion;
  GlossRealDropLanding landing;
  GlossRealDropLabels labels;
  GlossRealDropFilters filters;

  /// Null while the document has no `physics` key at all, which is how a file
  /// written before the block existed round-trips byte for byte. The inspector
  /// creates the block the first time somebody touches one of its controls.
  GlossRealDropPhysics? physics;

  /// Null while the document has no `script` key at all, on the same terms as
  /// [physics].
  GlossRealDropScript? script;

  GlossRealDropAnimation? animation;

  Map<String, dynamic> extras;

  static GlossRealDropSettingsDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'real-drop settings');
    return GlossRealDropSettingsDoc(
      schemaVersion: glossRealDropsCurrentSchemaVersion,
      revision: glossReadRevision(map),
      limits: GlossRealDropLimits.fromJson(map['limits']),
      scale: GlossRealDropScale.fromJson(map['scale']),
      motion: GlossRealDropMotion.fromJson(map['motion']),
      landing: GlossRealDropLanding.fromJson(map['landing']),
      labels: GlossRealDropLabels.fromJson(map['labels']),
      filters: GlossRealDropFilters.fromJson(map['filters']),
      // Absent stays absent: the two optional blocks are only materialised
      // when the file actually carries them.
      physics: map['physics'] == null
          ? null
          : GlossRealDropPhysics.fromJson(map['physics']),
      script: map['script'] == null
          ? null
          : GlossRealDropScript.fromJson(map['script']),
      animation: map['animation'] == null
          ? null
          : GlossRealDropAnimation.fromJson(map['animation']),
      extras: huiCollectExtras(map, _docKnown),
    );
  }

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'schemaVersion': schemaVersion,
    'revision': revision,
    'limits': limits.toJson(),
    'scale': scale.toJson(),
    'motion': motion.toJson(),
    'landing': landing.toJson(),
    'labels': labels.toJson(),
    'filters': filters.toJson(),
    if (physics != null) 'physics': physics!.toJson(),
    if (script != null) 'script': script!.toJson(),
    if (animation != null) 'animation': animation!.toJson(),
  }, extras);

  GlossRealDropSettingsDoc copy() =>
      GlossRealDropSettingsDoc.fromJson(toJson());
}

/// `RealDropSettingsDoc.Physics`: real changes to how the dropped `Item` entity
/// moves, as opposed to how it is drawn.
///
/// Gloss writes these to the entity's velocity and gravity flag through Bukkit
/// (`RealDropService.applyPhysics`), so the item's real position, its collision
/// and its pickup radius all follow. Absent from a document, the whole block is
/// absent from this model too — see [GlossRealDropSettingsDoc.physics].
///
/// Every number here is clamped by the server after the document loads
/// (`RealDropSettingsDoc.Physics` compact constructor). The editor stores what
/// the author typed and warns about the range instead of clamping it, so the
/// file the editor writes is the file the author meant.
final class GlossRealDropPhysics {
  GlossRealDropPhysics({
    this.enabled = false,
    this.gravityMultiplier = 1,
    this.bounce = 0,
    this.waterBuoyancy = 0,
    this.waterDrag = 0,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  /// While false Gloss never touches the item's velocity or gravity flag.
  bool enabled;

  /// Scales how hard the item falls. Clamped to 0..4; exactly 0 clears the
  /// entity's gravity flag and the item hangs where it is.
  double gravityMultiplier;

  /// Restitution on landing, clamped to 0..0.9. Vanilla items do not bounce at
  /// all, so 0 is genuinely no bounce rather than "vanilla bounce".
  double bounce;

  /// Upward velocity added per update while submerged. Clamped to 0..1.
  double waterBuoyancy;

  /// Fraction of the velocity removed per update while submerged. Clamped to
  /// 0..1; at 1 the item stops dead on entering water.
  double waterDrag;

  Map<String, dynamic> extras;

  static GlossRealDropPhysics fromJson(Object? raw) {
    if (raw == null) return GlossRealDropPhysics();
    final Map<String, dynamic> map = huiReadObject(raw, r'$.physics');
    return GlossRealDropPhysics(
      enabled: huiReadBool(map, 'enabled'),
      gravityMultiplier: huiReadDouble(map, 'gravityMultiplier', fallback: 1),
      bounce: huiReadDouble(map, 'bounce'),
      waterBuoyancy: huiReadDouble(map, 'waterBuoyancy'),
      waterDrag: huiReadDouble(map, 'waterDrag'),
      extras: huiCollectExtras(map, const <String>{
        'enabled',
        'gravityMultiplier',
        'bounce',
        'waterBuoyancy',
        'waterDrag',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'enabled': enabled,
    'gravityMultiplier': gravityMultiplier,
    'bounce': bounce,
    'waterBuoyancy': waterBuoyancy,
    'waterDrag': waterDrag,
  }, extras);

  GlossRealDropPhysics copy() => GlossRealDropPhysics.fromJson(toJson());
}

/// One `script` axis object: three expression sources, one per world axis.
///
/// The server reads a missing or blank axis as the block's neutral value —
/// `"0"` for `offset` and `rotation`, `"1"` for `scale`
/// (`RealDropSettingsDoc.Axis.withDefaults`). This model resolves that on read,
/// so an author who wrote only `{"y": "bob"}` gets the same three fields the
/// server compiled and the same presentation back out.
final class GlossRealDropScriptAxis {
  GlossRealDropScriptAxis({
    required this.neutral,
    String? x,
    String? y,
    String? z,
    Map<String, dynamic>? extras,
  }) : x = _axisOr(x, neutral),
       y = _axisOr(y, neutral),
       z = _axisOr(z, neutral),
       extras = extras ?? <String, dynamic>{};

  /// `"0"` for offset and rotation, `"1"` for scale. What a blank axis means.
  final String neutral;

  /// East, up and south in world space, as expression sources.
  String x;
  String y;
  String z;
  Map<String, dynamic> extras;

  static String _axisOr(String? value, String neutral) =>
      value == null || value.trim().isEmpty ? neutral : value.trim();

  static GlossRealDropScriptAxis fromJson(
    Object? raw,
    String path,
    String neutral,
  ) {
    if (raw == null) return GlossRealDropScriptAxis(neutral: neutral);
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossRealDropScriptAxis(
      neutral: neutral,
      x: map['x'] as String?,
      y: map['y'] as String?,
      z: map['z'] as String?,
      extras: huiCollectExtras(map, const <String>{'x', 'y', 'z'}),
    );
  }

  Map<String, dynamic> toJson() =>
      huiMergeExtras(<String, dynamic>{'x': x, 'y': y, 'z': z}, extras);

  /// True when nothing on this axis moves anything — the three neutral
  /// sources the compiler folds away.
  bool get isNeutral => x == neutral && y == neutral && z == neutral;

  GlossRealDropScriptAxis copy() =>
      GlossRealDropScriptAxis.fromJson(toJson(), r'$.script', neutral);
}

/// One `script.vars` entry: an author-defined intermediate.
///
/// A list entry rather than a map one because declaration order is
/// semantically significant — a var may read every var declared before it and
/// none declared after — and a `List` is the only shape that survives an
/// editor's add, remove and reorder without a sort ever creeping in. The JSON
/// is still an object; [GlossRealDropScript.toJson] writes it in list order,
/// which is the order the server's `LinkedHashMap` reads back.
final class GlossRealDropScriptVar {
  GlossRealDropScriptVar({required this.name, required this.expression});

  /// A plain identifier that does not shadow a built-in variable.
  String name;

  /// The expression source. Must evaluate to a number.
  String expression;

  GlossRealDropScriptVar copy() =>
      GlossRealDropScriptVar(name: name, expression: expression);
}

/// `RealDropSettingsDoc.Script`: the scripted presentation layer.
///
/// These move the `ItemDisplay` entities that stand in for the item and
/// nothing else. The item entity, its collision and its pickup radius stay
/// where Minecraft put them — `visible: false` drives a display's view range to
/// zero rather than removing the drop. Use [GlossRealDropPhysics] when the item
/// itself has to move.
///
/// Every expression here is compiled and type-checked when the document loads
/// whether or not [enabled] is set, so a broken expression is reported
/// immediately rather than when the switch is flipped.
final class GlossRealDropScript {
  GlossRealDropScript({
    this.enabled = false,
    List<GlossRealDropScriptVar>? vars,
    GlossRealDropScriptAxis? offset,
    GlossRealDropScriptAxis? rotation,
    GlossRealDropScriptAxis? scale,
    this.glow = '',
    String? visible,
    Map<String, dynamic>? extras,
  }) : vars = vars ?? <GlossRealDropScriptVar>[],
       offset = offset ?? GlossRealDropScriptAxis(neutral: '0'),
       rotation = rotation ?? GlossRealDropScriptAxis(neutral: '0'),
       scale = scale ?? GlossRealDropScriptAxis(neutral: '1'),
       visible = visible == null || visible.trim().isEmpty
           ? 'true'
           : visible.trim(),
       extras = extras ?? <String, dynamic>{};

  /// Master switch for evaluation, not for compilation.
  bool enabled;

  /// Declaration order is the evaluation order. Never sorted.
  List<GlossRealDropScriptVar> vars;

  /// Extra display displacement in blocks, added to the offset the document
  /// already computed. Clamped by the server to -16..16 per axis.
  GlossRealDropScriptAxis offset;

  /// Extra rotation in degrees, composed onto the existing pose in X then Y
  /// then Z order. Clamped by the server to -3600..3600 per axis.
  GlossRealDropScriptAxis rotation;

  /// Per-axis multiplier on the resolved scale family. Clamped to 0..16.
  GlossRealDropScriptAxis scale;

  /// Glow colour. An empty source turns the feature off entirely, which is why
  /// this is the one expression the server leaves uncompiled when it is blank.
  String glow;

  /// Boolean gate. Must produce `true`/`false`, never a number.
  String visible;

  Map<String, dynamic> extras;

  /// The upper bound the server refuses a document over.
  static const int maxVars = 32;

  /// The character cap on one expression source.
  static const int maxSourceLength = 512;

  static GlossRealDropScript fromJson(Object? raw) {
    if (raw == null) return GlossRealDropScript();
    final Map<String, dynamic> map = huiReadObject(raw, r'$.script');
    return GlossRealDropScript(
      enabled: huiReadBool(map, 'enabled'),
      vars: _readVars(map['vars']),
      offset: GlossRealDropScriptAxis.fromJson(
        map['offset'],
        r'$.script.offset',
        '0',
      ),
      rotation: GlossRealDropScriptAxis.fromJson(
        map['rotation'],
        r'$.script.rotation',
        '0',
      ),
      scale: GlossRealDropScriptAxis.fromJson(
        map['scale'],
        r'$.script.scale',
        '1',
      ),
      glow: huiReadString(map, 'glow').trim(),
      visible: map['visible'] as String?,
      extras: huiCollectExtras(map, const <String>{
        'enabled',
        'vars',
        'offset',
        'rotation',
        'scale',
        'glow',
        'visible',
      }),
    );
  }

  /// Reads the JSON object in the order its keys appear. `jsonDecode` hands
  /// back an insertion-ordered map, so file order survives the decode; nothing
  /// here re-sorts it.
  static List<GlossRealDropScriptVar> _readVars(Object? raw) {
    if (raw == null) return <GlossRealDropScriptVar>[];
    final Map<String, dynamic> map = huiReadObject(raw, r'$.script.vars');
    return <GlossRealDropScriptVar>[
      for (final MapEntry<String, dynamic> entry in map.entries)
        GlossRealDropScriptVar(
          name: entry.key.trim(),
          expression: entry.value is String
              ? (entry.value as String).trim()
              : '${entry.value ?? ''}'.trim(),
        ),
    ];
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'enabled': enabled,
    'vars': <String, dynamic>{
      for (final GlossRealDropScriptVar entry in vars)
        entry.name: entry.expression,
    },
    'offset': offset.toJson(),
    'rotation': rotation.toJson(),
    'scale': scale.toJson(),
    'glow': glow,
    'visible': visible,
  }, extras);

  GlossRealDropScript copy() => GlossRealDropScript.fromJson(toJson());
}

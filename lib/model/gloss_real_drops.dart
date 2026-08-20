library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

const int glossRealDropsCurrentSchemaVersion = 1;

bool looksLikeRealDropSettingsDoc(Object? json) {
  if (json is! Map || json['schemaVersion'] is! num) return false;
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
    throw HuiFormatException('Invalid JSON: ${e.message}', r'$');
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
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  bool tumble;
  double speedMultiplier;
  double degreesPerSecondX;
  double degreesPerSecondY;
  double degreesPerSecondZ;
  double variance;
  bool changeOnBounce;
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
      extras: huiCollectExtras(map, const <String>{
        'tumble',
        'speedMultiplier',
        'degreesPerSecondX',
        'degreesPerSecondY',
        'degreesPerSecondZ',
        'variance',
        'changeOnBounce',
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
  }, extras);

  GlossRealDropMotion copy() => GlossRealDropMotion.fromJson(toJson());
}

final class GlossRealDropLanding {
  GlossRealDropLanding({
    this.mode = 'NATURAL',
    this.tiltDegrees = 10,
    this.randomYaw = true,
    this.transitionTicks = 4,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  String mode;
  double tiltDegrees;
  bool randomYaw;
  int transitionTicks;
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
      extras: huiCollectExtras(map, const <String>{
        'mode',
        'tiltDegrees',
        'randomYaw',
        'transitionTicks',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'mode': mode,
    'tiltDegrees': tiltDegrees,
    'randomYaw': randomYaw,
    'transitionTicks': transitionTicks,
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
  }, extras);

  GlossRealDropSettingsDoc copy() =>
      GlossRealDropSettingsDoc.fromJson(toJson());
}

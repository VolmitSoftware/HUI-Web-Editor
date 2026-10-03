library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'hui_icons.dart';
import 'gloss_hologram_box.dart';
import 'json_codec.dart';

const double glossMarkerDefaultMaxDistance = 256;

bool looksLikeMarkerDoc(Object? json) {
  if (json is! Map || json['schemaVersion'] is! num) return false;
  if (json.containsKey('lines') || json.containsKey('components')) return false;
  final Object? anchor = json['anchor'];
  if (anchor is! Map) return false;
  return anchor.containsKey('x') ||
      anchor.containsKey('entity') ||
      anchor.containsKey('player') ||
      json.containsKey('beam') ||
      json.containsKey('waypoint') ||
      json.containsKey('hideWithin');
}

GlossMarkerDoc decodeGlossMarkerDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': e.message,
    });
  }
  return GlossMarkerDoc.fromJson(raw);
}

String encodeGlossMarkerDoc(GlossMarkerDoc doc) => huiWriteJson(doc.toJson());

GlossMarkerDoc cloneGlossMarkerDoc(GlossMarkerDoc doc) =>
    GlossMarkerDoc.fromJson(huiDeepCopy(doc.toJson()));

final class GlossMarkerAnchor {
  GlossMarkerAnchor({
    this.world,
    this.x,
    this.y,
    this.z,
    this.entity,
    this.player,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  String? world;
  double? x;
  double? y;
  double? z;
  String? entity;
  String? player;
  Map<String, dynamic> extras;

  bool get isPosition => world != null && world!.trim().isNotEmpty;

  static GlossMarkerAnchor fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossMarkerAnchor(
      world: map['world'] is String ? map['world'] as String : null,
      x: huiReadDoubleOrNull(map, 'x'),
      y: huiReadDoubleOrNull(map, 'y'),
      z: huiReadDoubleOrNull(map, 'z'),
      entity: map['entity'] is String ? map['entity'] as String : null,
      player: map['player'] is String ? map['player'] as String : null,
      extras: huiCollectExtras(map, const <String>{
        'world',
        'x',
        'y',
        'z',
        'entity',
        'player',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    if (world != null && world!.trim().isNotEmpty) 'world': world,
    if (x != null) 'x': x,
    if (y != null) 'y': y,
    if (z != null) 'z': z,
    if (entity != null && entity!.trim().isNotEmpty) 'entity': entity,
    if (player != null && player!.trim().isNotEmpty) 'player': player,
  }, extras);

  GlossMarkerAnchor copy() => GlossMarkerAnchor(
    world: world,
    x: x,
    y: y,
    z: z,
    entity: entity,
    player: player,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossMarkerBeam {
  GlossMarkerBeam({
    this.enabled = false,
    this.glowColor,
    this.height = 48,
    this.width = 0.25,
    this.material = 'minecraft:white_stained_glass',
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  bool enabled;
  String? glowColor;
  double height;
  double width;
  String material;
  Map<String, dynamic> extras;

  static GlossMarkerBeam fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossMarkerBeam(
      glowColor: map['glowColor'] as String?,
      enabled: huiReadBool(map, 'enabled'),
      height: map['height'] == null ? 48 : huiReadDouble(map, 'height', fallback: 48),
      width: map['width'] == null ? 0.25 : huiReadDouble(map, 'width', fallback: 0.25),
      material: huiReadString(
        map,
        'material',
        fallback: 'minecraft:white_stained_glass',
      ),
      extras: huiCollectExtras(map, const <String>{
        'enabled', 'glowColor',
        'height',
        'width',
        'material',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    if (glowColor != null) 'glowColor': glowColor,
    'enabled': enabled,
    'height': height,
    'width': width,
    'material': material,
  }, extras);

  GlossMarkerBeam copy() => GlossMarkerBeam(
    glowColor: glowColor,
    enabled: enabled,
    height: height,
    width: width,
    material: material,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossMarkerEdge {
  GlossMarkerEdge({
    this.enabled = false,
    this.margin = 0.8,
    this.arrow = '&f>',
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  bool enabled;
  double margin;
  String arrow;
  Map<String, dynamic> extras;

  static GlossMarkerEdge fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossMarkerEdge(
      enabled: huiReadBool(map, 'enabled'),
      margin: map['margin'] == null
          ? 0.8
          : huiReadDouble(map, 'margin', fallback: 0.8),
      arrow: huiReadString(map, 'arrow', fallback: '&f>'),
      extras: huiCollectExtras(map, const <String>{
        'enabled',
        'margin',
        'arrow',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'enabled': enabled,
    'margin': margin,
    'arrow': arrow,
  }, extras);

  GlossMarkerEdge copy() => GlossMarkerEdge(
    enabled: enabled,
    margin: margin,
    arrow: arrow,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossMarkerTrail {
  GlossMarkerTrail({
    this.enabled = false,
    this.color = '#ffffff',
    this.particle = 'minecraft:end_rod',
    this.spacing = 2,
    this.maxPoints = 48,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  bool enabled;
  String color;
  String particle;
  double spacing;
  int maxPoints;
  Map<String, dynamic> extras;

  static GlossMarkerTrail fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossMarkerTrail(
      color: huiReadString(map, 'color', fallback: '#ffffff'),
      enabled: huiReadBool(map, 'enabled'),
      particle: huiReadString(
        map,
        'particle',
        fallback: 'minecraft:end_rod',
      ),
      spacing: map['spacing'] == null
          ? 2
          : huiReadDouble(map, 'spacing', fallback: 2),
      maxPoints: map['maxPoints'] == null
          ? 48
          : huiReadInt(map, 'maxPoints', fallback: 48),
      extras: huiCollectExtras(map, const <String>{
        'enabled', 'color',
        'particle',
        'spacing',
        'maxPoints',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'color': color,
    'enabled': enabled,
    'particle': particle,
    'spacing': spacing,
    'maxPoints': maxPoints,
  }, extras);

  GlossMarkerTrail copy() => GlossMarkerTrail(
    color: color,
    enabled: enabled,
    particle: particle,
    spacing: spacing,
    maxPoints: maxPoints,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossMarkerDoc extends GlossDoc {
  GlossMarkerDoc({
    super.schemaVersion = glossCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    GlossMarkerAnchor? anchor,
    this.label = '',
    HuiIconStyle? style,
    GlossHologramBox? box,
    this.color = '#FFFFFF',
    this.distanceScale,
    this.hideWithin = 0,
    this.maxDistance = glossMarkerDefaultMaxDistance,
    GlossMarkerBeam? beam,
    GlossMarkerEdge? edge,
    GlossMarkerTrail? trail,
    this.lifetimeTicks = 0,
    this.waypoint = false,
    Map<String, dynamic>? extras,
  }) : style = style ?? defaultHologramDisplayStyle(),
       box = box ?? GlossHologramBox(),
       anchor = anchor ?? GlossMarkerAnchor(world: 'world', x: 0, y: 64, z: 0),
       beam = beam ?? GlossMarkerBeam(),
       edge = edge ?? GlossMarkerEdge(),
       trail = trail ?? GlossMarkerTrail(),
       extras = extras ?? <String, dynamic>{};

  GlossMarkerAnchor anchor;
  String label;
  HuiIconStyle style;
  GlossHologramBox box;
  String color;
  String? distanceScale;
  double hideWithin;
  double maxDistance;
  GlossMarkerBeam beam;
  GlossMarkerEdge edge;
  GlossMarkerTrail trail;
  int lifetimeTicks;
  bool waypoint;
  Map<String, dynamic> extras;

  static GlossMarkerDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'marker');
    return GlossMarkerDoc(
      schemaVersion: glossCurrentSchemaVersion,
      revision: glossReadRevision(map),
      anchor: GlossMarkerAnchor.fromJson(map['anchor'], r'$.anchor'),
      label: huiReadString(map, 'label'),
      style: HuiIconStyle.fromJsonOrNull(map['style']),
      box: GlossHologramBox.fromJson(map['box']),
      color: huiReadString(map, 'color', fallback: '#FFFFFF'),
      distanceScale: map['distanceScale'] is String
          ? map['distanceScale'] as String
          : null,
      hideWithin: huiReadDouble(map, 'hideWithin'),
      maxDistance: map['maxDistance'] == null
          ? glossMarkerDefaultMaxDistance
          : huiReadDouble(
              map,
              'maxDistance',
              fallback: glossMarkerDefaultMaxDistance,
            ),
      beam: map['beam'] == null
          ? GlossMarkerBeam()
          : GlossMarkerBeam.fromJson(map['beam'], r'$.beam'),
      edge: map['edge'] == null
          ? GlossMarkerEdge()
          : GlossMarkerEdge.fromJson(map['edge'], r'$.edge'),
      trail: map['trail'] == null
          ? GlossMarkerTrail()
          : GlossMarkerTrail.fromJson(map['trail'], r'$.trail'),
      lifetimeTicks: huiReadInt(map, 'lifetimeTicks'),
      waypoint: huiReadBool(map, 'waypoint'),
      extras: huiCollectExtras(map, const <String>{
        'schemaVersion',
        'revision',
        'anchor',
        'label', 'style', 'box',
        'color',
        'distanceScale',
        'hideWithin',
        'maxDistance',
        'beam',
        'edge',
        'trail',
        'lifetimeTicks',
        'waypoint',
      }),
    );
  }

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'schemaVersion': schemaVersion,
    'revision': revision,
    'anchor': anchor.toJson(),
    'label': label,
    'style': style.toJson(),
    'box': box.toJson(),
    'color': color,
    if (distanceScale != null && distanceScale!.trim().isNotEmpty)
      'distanceScale': distanceScale,
    'hideWithin': hideWithin,
    'maxDistance': maxDistance,
    'beam': beam.toJson(),
    'edge': edge.toJson(),
    'trail': trail.toJson(),
    'lifetimeTicks': lifetimeTicks,
    'waypoint': waypoint,
  }, extras);
}

library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

const List<String> glossZoneShapeTypes = <String>[
  'cuboid',
  'cylinder',
  'polygon',
  'region',
];
const List<String> glossZoneRenderModes = <String>[
  'particles',
  'walls',
  'hybrid',
];
const String glossZoneDefaultToggle = 'gloss.zones.toggle';

bool looksLikeZoneDoc(Object? json) {
  if (json is! Map || json['schemaVersion'] is! num) return false;
  final Object? shape = json['shape'];
  if (shape is! Map) return false;
  final Object? type = shape['type'];
  return type is String && glossZoneShapeTypes.contains(type);
}

GlossZoneDoc decodeGlossZoneDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': e.message,
    });
  }
  return GlossZoneDoc.fromJson(raw);
}

String encodeGlossZoneDoc(GlossZoneDoc doc) => huiWriteJson(doc.toJson());

GlossZoneDoc cloneGlossZoneDoc(GlossZoneDoc doc) =>
    GlossZoneDoc.fromJson(huiDeepCopy(doc.toJson()));

List<double> _readNumberList(Object? raw, int length, double fallback) {
  if (raw is! List) {
    return List<double>.filled(length, fallback);
  }
  return <double>[
    for (int index = 0; index < length; index++)
      index < raw.length && raw[index] is num
          ? (raw[index] as num).toDouble()
          : fallback,
  ];
}

final class GlossZoneShape {
  GlossZoneShape({
    this.type = 'cuboid',
    this.world = 'world',
    List<double>? min,
    List<double>? max,
    List<double>? center,
    this.radius,
    this.minY,
    this.maxY,
    List<List<double>>? points,
    this.plugin,
    this.id,
    Map<String, dynamic>? extras,
  }) : min = min ?? <double>[0, 64, 0],
       max = max ?? <double>[16, 80, 16],
       center = center ?? <double>[0, 0],
       points = points ?? <List<double>>[],
       extras = extras ?? <String, dynamic>{};

  String type;
  String world;
  List<double> min;
  List<double> max;
  List<double> center;
  double? radius;
  double? minY;
  double? maxY;
  List<List<double>> points;
  String? plugin;
  String? id;
  Map<String, dynamic> extras;

  static GlossZoneShape fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossZoneShape(
      type: huiReadString(map, 'type', fallback: 'cuboid'),
      world: huiReadString(map, 'world', fallback: 'world'),
      min: _readNumberList(map['min'], 3, 0),
      max: _readNumberList(map['max'], 3, 16),
      center: _readNumberList(map['center'], 2, 0),
      radius: huiReadDoubleOrNull(map, 'radius'),
      minY: huiReadDoubleOrNull(map, 'minY'),
      maxY: huiReadDoubleOrNull(map, 'maxY'),
      points: <List<double>>[
        for (final Object? point in huiReadList(map['points']))
          if (point is List)
            <double>[
              for (final Object? value in point)
                value is num ? value.toDouble() : 0,
            ],
      ],
      plugin: map['plugin'] is String ? map['plugin'] as String : null,
      id: map['id'] is String ? map['id'] as String : null,
      extras: huiCollectExtras(map, const <String>{
        'type',
        'world',
        'min',
        'max',
        'center',
        'radius',
        'minY',
        'maxY',
        'points',
        'plugin',
        'id',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'type': type,
    if (world.trim().isNotEmpty) 'world': world,
    if (type == 'cuboid') ...<String, Object>{
      'min': List<double>.of(min),
      'max': List<double>.of(max),
    },
    if (type == 'cylinder') ...<String, Object?>{
      'center': List<double>.of(center),
      'radius': radius ?? 8,
      'minY': minY ?? 64,
      'maxY': maxY ?? 80,
    },
    if (type == 'polygon') ...<String, Object?>{
      'points': <List<double>>[
        for (final List<double> point in points) List<double>.of(point),
      ],
      'minY': minY ?? 64,
      'maxY': maxY ?? 80,
    },
    if (type == 'region') ...<String, Object?>{
      if (plugin != null) 'plugin': plugin,
      if (id != null) 'id': id,
    },
  }, extras);

  GlossZoneShape copy() => GlossZoneShape(
    type: type,
    world: world,
    min: List<double>.of(min),
    max: List<double>.of(max),
    center: List<double>.of(center),
    radius: radius,
    minY: minY,
    maxY: maxY,
    points: <List<double>>[
      for (final List<double> point in points) List<double>.of(point),
    ],
    plugin: plugin,
    id: id,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossZoneRender {
  GlossZoneRender({
    this.mode = 'particles',
    this.particle = 'minecraft:dust',
    this.color = '#FFFFFF',
    this.spacing = 0.75,
    this.wallMaterial = 'minecraft:white_stained_glass',
    this.facingOnly = true,
    this.edgesOnly = false,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  String mode;
  String particle;
  String color;
  double spacing;
  String wallMaterial;
  bool facingOnly;
  bool edgesOnly;
  Map<String, dynamic> extras;

  static GlossZoneRender fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossZoneRender(
      mode: huiReadString(map, 'mode', fallback: 'particles'),
      particle: huiReadString(map, 'particle', fallback: 'minecraft:dust'),
      color: huiReadString(map, 'color', fallback: '#FFFFFF'),
      spacing: map['spacing'] == null
          ? 0.75
          : huiReadDouble(map, 'spacing', fallback: 0.75),
      wallMaterial: huiReadString(
        map,
        'wallMaterial',
        fallback: 'minecraft:white_stained_glass',
      ),
      facingOnly: map['facingOnly'] == null
          ? true
          : huiReadBool(map, 'facingOnly'),
      edgesOnly: huiReadBool(map, 'edgesOnly'),
      extras: huiCollectExtras(map, const <String>{
        'mode',
        'particle',
        'color',
        'spacing',
        'wallMaterial',
        'facingOnly',
        'edgesOnly',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'mode': mode,
    'particle': particle,
    'color': color,
    'spacing': spacing,
    'wallMaterial': wallMaterial,
    'facingOnly': facingOnly,
    'edgesOnly': edgesOnly,
  }, extras);

  GlossZoneRender copy() => GlossZoneRender(
    mode: mode,
    particle: particle,
    color: color,
    spacing: spacing,
    wallMaterial: wallMaterial,
    facingOnly: facingOnly,
    edgesOnly: edgesOnly,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossZoneAmbience {
  GlossZoneAmbience({
    this.enabled = false,
    this.particle = 'minecraft:ash',
    this.perViewerPerTick = 4,
    this.radius = 12,
    this.when = 'true',
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  bool enabled;
  String particle;
  int perViewerPerTick;
  double radius;
  String when;
  Map<String, dynamic> extras;

  static GlossZoneAmbience fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossZoneAmbience(
      enabled: huiReadBool(map, 'enabled'),
      particle: huiReadString(map, 'particle', fallback: 'minecraft:ash'),
      perViewerPerTick: map['perViewerPerTick'] == null
          ? 4
          : huiReadInt(map, 'perViewerPerTick', fallback: 4),
      radius: map['radius'] == null
          ? 12
          : huiReadDouble(map, 'radius', fallback: 12),
      when: huiReadString(map, 'when', fallback: 'true'),
      extras: huiCollectExtras(map, const <String>{
        'enabled',
        'particle',
        'perViewerPerTick',
        'radius',
        'when',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'enabled': enabled,
    'particle': particle,
    'perViewerPerTick': perViewerPerTick,
    'radius': radius,
    'when': when,
  }, extras);

  GlossZoneAmbience copy() => GlossZoneAmbience(
    enabled: enabled,
    particle: particle,
    perViewerPerTick: perViewerPerTick,
    radius: radius,
    when: when,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossZoneDoc extends GlossDoc {
  GlossZoneDoc({
    super.schemaVersion = glossCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    GlossZoneShape? shape,
    GlossZoneRender? render,
    GlossZoneAmbience? ambience,
    this.toggle = glossZoneDefaultToggle,
    Map<String, dynamic>? extras,
  }) : shape = shape ?? GlossZoneShape(),
       render = render ?? GlossZoneRender(),
       ambience = ambience ?? GlossZoneAmbience(),
       extras = extras ?? <String, dynamic>{};

  GlossZoneShape shape;
  GlossZoneRender render;
  GlossZoneAmbience ambience;
  String toggle;
  Map<String, dynamic> extras;

  static GlossZoneDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'zone');
    return GlossZoneDoc(
      schemaVersion: glossCurrentSchemaVersion,
      revision: glossReadRevision(map),
      shape: GlossZoneShape.fromJson(map['shape'], r'$.shape'),
      render: map['render'] == null
          ? GlossZoneRender()
          : GlossZoneRender.fromJson(map['render'], r'$.render'),
      ambience: map['ambience'] == null
          ? GlossZoneAmbience()
          : GlossZoneAmbience.fromJson(map['ambience'], r'$.ambience'),
      toggle: huiReadString(map, 'toggle', fallback: glossZoneDefaultToggle),
      extras: huiCollectExtras(map, const <String>{
        'schemaVersion',
        'revision',
        'shape',
        'render',
        'ambience',
        'toggle',
      }),
    );
  }

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'schemaVersion': schemaVersion,
    'revision': revision,
    'shape': shape.toJson(),
    'render': render.toJson(),
    'ambience': ambience.toJson(),
    'toggle': toggle,
  }, extras);
}

library;

import 'json_codec.dart';
import 'vec3.dart';

const int glossParticleMaxLayers = 64;
const List<String> glossParticleTargetScopes = <String>[
  'projection',
  'component',
  'text',
  'line',
  'span',
  'label',
  'model',
  'local',
];
const List<String> glossParticleGeometryTypes = <String>[
  'point',
  'line',
  'polyline',
  'outline',
  'filledPlane',
  'cuboid',
  'letterBounds',
  'glyphOutline',
  'glyphFill',
];
const List<String> glossParticlePlacementLayers = <String>[
  'behind',
  'front',
  'center',
];
const List<String> glossParticleEmissionPatterns = <String>[
  'steady',
  'chase',
  'pulse',
  'twinkle',
  'scan',
  'corners',
];

const Set<String> _layerKnown = <String>{
  'id',
  'target',
  'geometry',
  'placement',
  'particle',
  'emission',
  'priority',
};
const Set<String> _targetKnown = <String>{'scope', 'name', 'component', 'line'};
const Set<String> _geometryKnown = <String>{
  'type',
  'from',
  'to',
  'points',
  'width',
  'height',
  'depth',
  'padding',
  'spacing',
};
const Set<String> _placementKnown = <String>{'layer', 'depth', 'offset'};
const Set<String> _particleKnown = <String>{'key', 'color', 'size'};
const Set<String> _emissionKnown = <String>{
  'intervalTicks',
  'pattern',
  'periodTicks',
  'seed',
};

final class GlossParticleTarget {
  GlossParticleTarget({
    this.scope = 'projection',
    this.name,
    this.component,
    this.line,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  String scope;
  String? name;
  String? component;
  int? line;
  Map<String, dynamic> extras;

  static GlossParticleTarget fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(
      raw ?? <String, dynamic>{},
      path,
    );
    return GlossParticleTarget(
      scope: huiReadString(map, 'scope'),
      name: map['name'] == null ? null : huiReadString(map, 'name'),
      component: map['component'] == null
          ? null
          : huiReadString(map, 'component'),
      line: map['line'] == null ? null : huiReadInt(map, 'line'),
      extras: huiCollectExtras(map, _targetKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'scope': scope,
    if (name != null) 'name': name,
    if (component != null) 'component': component,
    if (line != null) 'line': line,
  }, extras);

  GlossParticleTarget copy() => GlossParticleTarget(
    scope: scope,
    name: name,
    component: component,
    line: line,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossParticleGeometry {
  GlossParticleGeometry({
    this.type = 'outline',
    this.from,
    this.to,
    List<Vec3>? points,
    this.width,
    this.height,
    this.depth,
    this.padding = 0,
    this.spacing = 0.15,
    Map<String, dynamic>? extras,
  }) : points = points ?? <Vec3>[],
       extras = extras ?? <String, dynamic>{};

  String type;
  Vec3? from;
  Vec3? to;
  List<Vec3> points;
  double? width;
  double? height;
  double? depth;
  double padding;
  double spacing;
  Map<String, dynamic> extras;

  static GlossParticleGeometry fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(
      raw ?? <String, dynamic>{},
      path,
    );
    final List<Object?> rawPoints = huiReadList(map['points']);
    return GlossParticleGeometry(
      type: huiReadString(map, 'type'),
      from: map['from'] == null
          ? null
          : Vec3.fromJson(map['from'], path: '$path.from'),
      to: map['to'] == null ? null : Vec3.fromJson(map['to'], path: '$path.to'),
      points: <Vec3>[
        for (int index = 0; index < rawPoints.length; index++)
          Vec3.fromJson(rawPoints[index], path: '$path.points[$index]'),
      ],
      width: huiReadDoubleOrNull(map, 'width'),
      height: huiReadDoubleOrNull(map, 'height'),
      depth: huiReadDoubleOrNull(map, 'depth'),
      padding: huiReadDouble(map, 'padding'),
      spacing: huiReadDouble(map, 'spacing', fallback: 0.15),
      extras: huiCollectExtras(map, _geometryKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'type': type,
    if (from != null) 'from': from!.toJson(),
    if (to != null) 'to': to!.toJson(),
    if (points.isNotEmpty)
      'points': <List<double>>[for (final Vec3 point in points) point.toJson()],
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (depth != null) 'depth': depth,
    'padding': padding,
    'spacing': spacing,
  }, extras);

  GlossParticleGeometry copy() => GlossParticleGeometry(
    type: type,
    from: from?.copy(),
    to: to?.copy(),
    points: <Vec3>[for (final Vec3 point in points) point.copy()],
    width: width,
    height: height,
    depth: depth,
    padding: padding,
    spacing: spacing,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossParticlePlacement {
  GlossParticlePlacement({
    this.layer = 'behind',
    this.depth = 0.04,
    Vec3? offset,
    Map<String, dynamic>? extras,
  }) : offset = offset ?? Vec3.zero(),
       extras = extras ?? <String, dynamic>{};

  String layer;
  double depth;
  Vec3 offset;
  Map<String, dynamic> extras;

  double get signedDepth => switch (layer) {
    'behind' => depth,
    'front' => -depth,
    _ => 0,
  };

  static GlossParticlePlacement fromJson(Object? raw, String path) {
    if (raw == null) return GlossParticlePlacement();
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossParticlePlacement(
      layer: huiReadString(map, 'layer'),
      depth: huiReadDouble(map, 'depth'),
      offset: Vec3.fromJson(map['offset'], path: '$path.offset'),
      extras: huiCollectExtras(map, _placementKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'layer': layer,
    'depth': depth,
    'offset': offset.toJson(),
  }, extras);

  GlossParticlePlacement copy() => GlossParticlePlacement(
    layer: layer,
    depth: depth,
    offset: offset.copy(),
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossParticleSpec {
  GlossParticleSpec({
    this.key = 'minecraft:dust',
    this.color = '#ffffff',
    this.size = 1,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  String key;
  String? color;
  double? size;
  Map<String, dynamic> extras;

  static GlossParticleSpec fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(
      raw ?? <String, dynamic>{},
      path,
    );
    final String key = huiReadString(map, 'key');
    final bool dust = key.trim().toLowerCase() == 'minecraft:dust';
    return GlossParticleSpec(
      key: key,
      color: map['color'] == null
          ? dust
                ? '#ffffff'
                : null
          : huiReadString(map, 'color'),
      size: map['size'] == null
          ? dust
                ? 1
                : null
          : huiReadDoubleOrNull(map, 'size'),
      extras: huiCollectExtras(map, _particleKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'key': key,
    if (color != null) 'color': color,
    if (size != null) 'size': size,
  }, extras);

  GlossParticleSpec copy() => GlossParticleSpec(
    key: key,
    color: color,
    size: size,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossParticleEmission {
  GlossParticleEmission({
    this.intervalTicks = 4,
    this.pattern = 'steady',
    this.periodTicks = 40,
    this.seed = 0,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  int intervalTicks;
  String pattern;
  int periodTicks;
  int seed;
  Map<String, dynamic> extras;

  static GlossParticleEmission fromJson(Object? raw, String path) {
    if (raw == null) return GlossParticleEmission();
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossParticleEmission(
      intervalTicks: huiReadInt(map, 'intervalTicks', fallback: 4),
      pattern: huiReadString(map, 'pattern', fallback: 'steady'),
      periodTicks: huiReadInt(map, 'periodTicks', fallback: 40),
      seed: huiReadInt(map, 'seed'),
      extras: huiCollectExtras(map, _emissionKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'intervalTicks': intervalTicks,
    'pattern': pattern,
    'periodTicks': periodTicks,
    'seed': seed,
  }, extras);

  GlossParticleEmission copy() => GlossParticleEmission(
    intervalTicks: intervalTicks,
    pattern: pattern,
    periodTicks: periodTicks,
    seed: seed,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossParticleLayer {
  GlossParticleLayer({
    this.id = '',
    GlossParticleTarget? target,
    GlossParticleGeometry? geometry,
    GlossParticlePlacement? placement,
    GlossParticleSpec? particle,
    GlossParticleEmission? emission,
    this.priority = 0,
    Map<String, dynamic>? extras,
  }) : target = target ?? GlossParticleTarget(),
       geometry = geometry ?? GlossParticleGeometry(),
       placement = placement ?? GlossParticlePlacement(),
       particle = particle ?? GlossParticleSpec(),
       emission = emission ?? GlossParticleEmission(),
       extras = extras ?? <String, dynamic>{};

  String id;
  GlossParticleTarget target;
  GlossParticleGeometry geometry;
  GlossParticlePlacement placement;
  GlossParticleSpec particle;
  GlossParticleEmission emission;
  int priority;
  Map<String, dynamic> extras;

  static GlossParticleLayer fromJson(Object? raw, int index) {
    final String path = 'particleLayers[$index]';
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossParticleLayer(
      id: huiReadString(map, 'id'),
      target: GlossParticleTarget.fromJson(map['target'], '$path.target'),
      geometry: GlossParticleGeometry.fromJson(
        map['geometry'],
        '$path.geometry',
      ),
      placement: GlossParticlePlacement.fromJson(
        map['placement'],
        '$path.placement',
      ),
      particle: GlossParticleSpec.fromJson(map['particle'], '$path.particle'),
      emission: GlossParticleEmission.fromJson(
        map['emission'],
        '$path.emission',
      ),
      priority: huiReadInt(map, 'priority'),
      extras: huiCollectExtras(map, _layerKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'id': id,
    'target': target.toJson(),
    'geometry': geometry.toJson(),
    'placement': placement.toJson(),
    'particle': particle.toJson(),
    'emission': emission.toJson(),
    'priority': priority,
  }, extras);

  GlossParticleLayer copy() => GlossParticleLayer(
    id: id,
    target: target.copy(),
    geometry: geometry.copy(),
    placement: placement.copy(),
    particle: particle.copy(),
    emission: emission.copy(),
    priority: priority,
    extras: huiDeepCopyMap(extras),
  );
}

List<GlossParticleLayer> glossReadParticleLayers(Object? raw) {
  final List<Object?> entries = huiReadList(raw);
  return <GlossParticleLayer>[
    for (int index = 0; index < entries.length; index++)
      GlossParticleLayer.fromJson(entries[index], index),
  ];
}

List<Map<String, dynamic>> glossWriteParticleLayers(
  List<GlossParticleLayer> layers,
) => <Map<String, dynamic>>[
  for (final GlossParticleLayer layer in layers) layer.toJson(),
];

List<GlossParticleLayer> glossCopyParticleLayers(
  List<GlossParticleLayer> layers,
) => <GlossParticleLayer>[
  for (final GlossParticleLayer layer in layers) layer.copy(),
];

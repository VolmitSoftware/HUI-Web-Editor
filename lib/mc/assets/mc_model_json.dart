/// Typed views over the client's model JSON: `models/{block,item}/*.json`,
/// `items/*.json` item definitions and `blockstates/*.json`.
///
/// Parsing only. Parent chains, texture variables and dispatch are the
/// resolver's job (`mc_model_resolver.dart`). Every number is a double because
/// the jar writes `16` and `7.5` interchangeably.
library;

import 'mc_ids.dart';

List<double> _doubles(Object? value, List<double> fallback) {
  if (value is! List<Object?>) return fallback;
  return <double>[for (final Object? v in value) (v as num).toDouble()];
}

Map<String, Object?> _map(Object? value) =>
    value is Map<String, Object?> ? value : const <String, Object?>{};

final class McFaceJson {
  const McFaceJson({
    required this.texture,
    this.uv,
    this.cullface,
    this.rotation = 0,
    this.tintIndex,
  });

  factory McFaceJson.fromJson(Map<String, Object?> json) => McFaceJson(
    texture: mcTextureId(json['texture'] as String? ?? '#missing'),
    uv: json['uv'] == null ? null : _doubles(json['uv'], const <double>[]),
    cullface: json['cullface'] as String?,
    rotation: (json['rotation'] as num?)?.toInt() ?? 0,
    tintIndex: (json['tintindex'] as num?)?.toInt(),
  );

  /// `#variable` or a folder-qualified texture id.
  final String texture;

  /// `[u1, v1, u2, v2]` in texture pixels, or null for the element default.
  final List<double>? uv;
  final String? cullface;

  /// 0, 90, 180 or 270.
  final int rotation;
  final int? tintIndex;
}

final class McRotationJson {
  const McRotationJson({
    required this.origin,
    required this.axis,
    required this.angle,
    this.rescale = false,
  });

  factory McRotationJson.fromJson(Map<String, Object?> json) => McRotationJson(
    origin: _doubles(json['origin'], const <double>[8, 8, 8]),
    axis: json['axis'] as String? ?? 'y',
    angle: (json['angle'] as num?)?.toDouble() ?? 0,
    rescale: json['rescale'] as bool? ?? false,
  );

  final List<double> origin;
  final String axis;
  final double angle;
  final bool rescale;
}

final class McElementJson {
  const McElementJson({
    required this.from,
    required this.to,
    required this.faces,
    this.rotation,
    this.shade = true,
  });

  factory McElementJson.fromJson(Map<String, Object?> json) => McElementJson(
    from: _doubles(json['from'], const <double>[0, 0, 0]),
    to: _doubles(json['to'], const <double>[16, 16, 16]),
    rotation: json['rotation'] == null
        ? null
        : McRotationJson.fromJson(_map(json['rotation'])),
    shade: json['shade'] as bool? ?? true,
    faces: <String, McFaceJson>{
      for (final MapEntry<String, Object?> entry in _map(json['faces']).entries)
        entry.key: McFaceJson.fromJson(_map(entry.value)),
    },
  );

  final List<double> from;
  final List<double> to;
  final McRotationJson? rotation;
  final bool shade;

  /// Keyed by `down`, `up`, `north`, `south`, `west`, `east`.
  final Map<String, McFaceJson> faces;
}

final class McDisplayTransformJson {
  const McDisplayTransformJson({
    this.rotation = const <double>[0, 0, 0],
    this.translation = const <double>[0, 0, 0],
    this.scale = const <double>[1, 1, 1],
  });

  factory McDisplayTransformJson.fromJson(Map<String, Object?> json) =>
      McDisplayTransformJson(
        rotation: _doubles(json['rotation'], const <double>[0, 0, 0]),
        translation: _doubles(json['translation'], const <double>[0, 0, 0]),
        scale: _doubles(json['scale'], const <double>[1, 1, 1]),
      );

  final List<double> rotation;
  final List<double> translation;
  final List<double> scale;
}

final class McModelJson {
  const McModelJson({
    required this.textures,
    required this.elements,
    required this.display,
    this.parent,
    this.guiLight,
  });

  factory McModelJson.fromJson(Map<String, Object?> json) => McModelJson(
    parent: json['parent'] == null ? null : mcModelId(json['parent'] as String),
    textures: <String, String>{
      for (final MapEntry<String, Object?> entry in _map(
        json['textures'],
      ).entries)
        entry.key: mcTextureId(entry.value as String),
    },
    elements: <McElementJson>[
      for (final Object? raw
          in (json['elements'] as List<Object?>?) ?? const <Object?>[])
        McElementJson.fromJson(_map(raw)),
    ],
    display: <String, McDisplayTransformJson>{
      for (final MapEntry<String, Object?> entry in _map(
        json['display'],
      ).entries)
        entry.key: McDisplayTransformJson.fromJson(_map(entry.value)),
    },
    guiLight: json['gui_light'] as String?,
  );

  final String? parent;
  final Map<String, String> textures;

  /// Empty when the model inherits its parent's elements.
  final List<McElementJson> elements;
  final Map<String, McDisplayTransformJson> display;
  final String? guiLight;

  /// True when this file supplies geometry, which stops inheritance. Vanilla
  /// lets an empty or missing `elements` fall through to the parent.
  bool get declaresElements => elements.isNotEmpty;
}

final class McTintJson {
  const McTintJson({required this.type, this.defaultArgb});

  /// `constant` tints write `value`; every other type writes `default`.
  factory McTintJson.fromJson(Map<String, Object?> json) => McTintJson(
    type: mcStrip(json['type'] as String? ?? ''),
    defaultArgb: ((json['default'] ?? json['value']) as num?)?.toInt(),
  );

  /// `grass`, `foliage`, `constant`, `dye`, `potion`, `map_color`, ...
  final String type;
  final int? defaultArgb;
}

/// One node of an `items/<id>.json` definition tree.
sealed class McItemDefinitionNode {
  const McItemDefinitionNode();

  factory McItemDefinitionNode.fromJson(Map<String, Object?> json) {
    final String type = mcStrip(json['type'] as String? ?? '');
    switch (type) {
      case 'model':
        return McItemModelNode(
          model: mcModelId(json['model'] as String),
          tints: <McTintJson>[
            for (final Object? raw
                in (json['tints'] as List<Object?>?) ?? const <Object?>[])
              McTintJson.fromJson(_map(raw)),
          ],
        );
      case 'condition':
        return McItemConditionNode(
          property: mcStrip(json['property'] as String? ?? ''),
          onTrue: McItemDefinitionNode.fromJson(_map(json['on_true'])),
          onFalse: McItemDefinitionNode.fromJson(_map(json['on_false'])),
        );
      case 'select':
        return McItemSelectNode(
          cases: <McItemDefinitionNode>[
            for (final Object? raw
                in (json['cases'] as List<Object?>?) ?? const <Object?>[])
              McItemDefinitionNode.fromJson(_map(_map(raw)['model'])),
          ],
          fallback: json['fallback'] == null
              ? null
              : McItemDefinitionNode.fromJson(_map(json['fallback'])),
        );
      case 'range_dispatch':
        return McItemRangeDispatchNode(
          entries: <McItemDefinitionNode>[
            for (final Object? raw
                in (json['entries'] as List<Object?>?) ?? const <Object?>[])
              McItemDefinitionNode.fromJson(_map(_map(raw)['model'])),
          ],
          fallback: json['fallback'] == null
              ? null
              : McItemDefinitionNode.fromJson(_map(json['fallback'])),
        );
      case 'composite':
        return McItemCompositeNode(
          models: <McItemDefinitionNode>[
            for (final Object? raw
                in (json['models'] as List<Object?>?) ?? const <Object?>[])
              McItemDefinitionNode.fromJson(_map(raw)),
          ],
        );
      case 'special':
        return McItemSpecialNode(
          specialType: mcStrip(_map(json['model'])['type'] as String? ?? ''),
          base: mcModelId(json['base'] as String? ?? ''),
        );
      case 'empty':
        return const McItemEmptyNode();
      default:
        return McItemUnknownNode(type);
    }
  }
}

final class McItemModelNode extends McItemDefinitionNode {
  const McItemModelNode({
    required this.model,
    this.tints = const <McTintJson>[],
  });
  final String model;
  final List<McTintJson> tints;
}

final class McItemConditionNode extends McItemDefinitionNode {
  const McItemConditionNode({
    required this.property,
    required this.onTrue,
    required this.onFalse,
  });
  final String property;
  final McItemDefinitionNode onTrue;
  final McItemDefinitionNode onFalse;
}

final class McItemSelectNode extends McItemDefinitionNode {
  const McItemSelectNode({required this.cases, this.fallback});
  final List<McItemDefinitionNode> cases;
  final McItemDefinitionNode? fallback;
}

final class McItemRangeDispatchNode extends McItemDefinitionNode {
  const McItemRangeDispatchNode({required this.entries, this.fallback});
  final List<McItemDefinitionNode> entries;
  final McItemDefinitionNode? fallback;
}

final class McItemCompositeNode extends McItemDefinitionNode {
  const McItemCompositeNode({required this.models});
  final List<McItemDefinitionNode> models;
}

/// Chests, banners, heads, beds, shulker boxes, signs, decorated pots,
/// tridents, conduits: block-entity renderers with no JSON geometry.
final class McItemSpecialNode extends McItemDefinitionNode {
  const McItemSpecialNode({required this.specialType, required this.base});
  final String specialType;
  final String base;
}

final class McItemEmptyNode extends McItemDefinitionNode {
  const McItemEmptyNode();
}

/// `bundle/selected_item`, `player_head` and whatever a later version adds.
final class McItemUnknownNode extends McItemDefinitionNode {
  const McItemUnknownNode(this.type);
  final String type;
}

final class McBlockstateVariantJson {
  const McBlockstateVariantJson({
    required this.model,
    this.x = 0,
    this.y = 0,
    this.uvlock = false,
  });

  factory McBlockstateVariantJson.fromJson(Map<String, Object?> json) =>
      McBlockstateVariantJson(
        model: mcModelId(json['model'] as String),
        x: (json['x'] as num?)?.toInt() ?? 0,
        y: (json['y'] as num?)?.toInt() ?? 0,
        uvlock: json['uvlock'] as bool? ?? false,
      );

  final String model;

  /// Degrees about X and Y, multiples of 90.
  final int x;
  final int y;
  final bool uvlock;

  bool get rotated => x != 0 || y != 0;
}

final class McBlockstateJson {
  const McBlockstateJson({
    required this.multipartUnconditional,
    this.defaultVariant,
  });

  factory McBlockstateJson.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> variants = _map(json['variants']);
    if (variants.isNotEmpty) {
      return McBlockstateJson(
        defaultVariant: _defaultOf(variants),
        multipartUnconditional: const <McBlockstateVariantJson>[],
      );
    }
    final List<McBlockstateVariantJson> parts = <McBlockstateVariantJson>[];
    for (final Object? raw
        in (json['multipart'] as List<Object?>?) ?? const <Object?>[]) {
      final Map<String, Object?> part = _map(raw);
      if (part.containsKey('when')) continue;
      parts.add(_first(part['apply']));
    }
    return McBlockstateJson(
      defaultVariant: parts.isEmpty ? null : parts.first,
      multipartUnconditional: parts,
    );
  }

  /// The `""` variant when the block has no properties. Otherwise the file
  /// does not say which state is the default, so the first unrotated variant
  /// stands in: vanilla authors the canonical orientation (`axis=y`,
  /// `type=bottom`, `snowy=false`) without `x`/`y` and rotates the others.
  static McBlockstateVariantJson _defaultOf(Map<String, Object?> variants) {
    final Object? bare = variants[''];
    if (bare != null) return _first(bare);
    final List<McBlockstateVariantJson> candidates = <McBlockstateVariantJson>[
      for (final Object? raw in variants.values) _first(raw),
    ];
    for (final McBlockstateVariantJson candidate in candidates) {
      if (!candidate.rotated) return candidate;
    }
    return candidates.first;
  }

  /// A variant is one object or a weighted list; the first entry wins.
  static McBlockstateVariantJson _first(Object? raw) =>
      McBlockstateVariantJson.fromJson(
        raw is List<Object?> ? _map(raw.first) : _map(raw),
      );

  /// The `""` variant, else the first unrotated variant, else the first
  /// variant, else the first unconditional multipart entry.
  final McBlockstateVariantJson? defaultVariant;

  /// Every multipart entry without a `when`: a fence's post, never its arms.
  final List<McBlockstateVariantJson> multipartUnconditional;
}

/// Turns model ids into flat, texture-resolved geometry.
///
/// A model inherits from its `parent` until a root is reached: textures merge
/// child-over-parent, `display` merges per key, `elements` come from the
/// nearest ancestor that declares them, `gui_light` from the nearest that sets
/// it. `#name` texture references chase the merged map (bounded, because the
/// jar has `#all -> #texture` style chains). Two parents are sentinels:
/// `builtin/generated` (a flat item: `layer0..layerN` become the extrusion
/// mesher's input) and `builtin/entity` (a block-entity renderer, drawn by the
/// stages as a catalog sprite).
///
/// Item definitions (`items/<id>.json`) pick a model per runtime state; the
/// editor has no runtime state, so dispatch takes the resting branch: a
/// condition's `on_false`, a select's `fallback` else first case, a range
/// dispatch's `fallback` else first entry, a composite's every child (merged
/// as one model), and `special` or unknown nodes hand back the sprite
/// fallback with a reason the stage readouts print.
library;

import 'mc_ids.dart';
import 'mc_model_json.dart';
import 'mc_model_store.dart';

const String mcBuiltinGenerated = 'builtin/generated';
const String mcBuiltinEntity = 'builtin/entity';

/// Texture id the mesher draws as the magenta checker.
const String mcMissingTexture = 'missing';
const int _maxParentDepth = 16;

final class McAabb {
  const McAabb(this.min, this.max);

  /// Blocks, `[x, y, z]`.
  final List<double> min;
  final List<double> max;

  double get width => max[0] - min[0];
  double get height => max[1] - min[1];
  double get depth => max[2] - min[2];

  static const McAabb unit = McAabb(<double>[0, 0, 0], <double>[1, 1, 1]);

  /// A `builtin/generated` item: a 16x16 sheet one pixel thick at z = 8.
  static const McAabb generatedSheet = McAabb(
    <double>[0, 0, 7.5 / 16],
    <double>[1, 1, 8.5 / 16],
  );
}

final class McResolvedFace {
  const McResolvedFace({
    required this.texture,
    required this.uv,
    required this.rotation,
    this.cullface,
    this.tintIndex,
  });

  /// Folder-qualified texture id, never a `#variable`.
  final String texture;

  /// `[u1, v1, u2, v2]` in texture pixels, defaulted from the element bounds.
  final List<double> uv;
  final int rotation;
  final String? cullface;
  final int? tintIndex;
}

final class McResolvedElement {
  const McResolvedElement({
    required this.from,
    required this.to,
    required this.faces,
    required this.shade,
    this.rotation,
  });

  /// Model pixels (0..16).
  final List<double> from;
  final List<double> to;
  final Map<String, McResolvedFace> faces;
  final bool shade;
  final McRotationJson? rotation;
}

final class McResolvedModel {
  const McResolvedModel({
    required this.id,
    required this.elements,
    required this.textures,
    required this.display,
    required this.generated,
    required this.entityBuiltin,
    required this.layers,
    this.guiLight,
  });

  final String id;
  final List<McResolvedElement> elements;

  /// The merged texture map as written, `#variable` values included.
  final Map<String, String> textures;
  final Map<String, McDisplayTransformJson> display;

  /// `builtin/generated` ancestry: draw [layers] with the extrusion mesher.
  final bool generated;

  /// `builtin/entity` ancestry: no geometry here; the stage billboards a sprite.
  final bool entityBuiltin;

  /// `layer0`, `layer1`, ... texture ids in order.
  final List<String> layers;
  final String? guiLight;

  /// Element bounds in blocks (rotation ignored; a rotated cross still reports
  /// its unrotated box, which is what the drops readout needs).
  McAabb get aabb {
    if (elements.isEmpty) {
      return generated ? McAabb.generatedSheet : McAabb.unit;
    }
    final List<double> min = <double>[16, 16, 16];
    final List<double> max = <double>[0, 0, 0];
    for (final McResolvedElement element in elements) {
      for (int axis = 0; axis < 3; axis++) {
        if (element.from[axis] < min[axis]) min[axis] = element.from[axis];
        if (element.to[axis] > max[axis]) max[axis] = element.to[axis];
      }
    }
    return McAabb(
      <double>[for (final double v in min) v / 16],
      <double>[for (final double v in max) v / 16],
    );
  }
}

/// Which atlas an item drawable binds: the items sheet for a generated model
/// (the pack copies a generated layer's `block/` texture into `items.png`
/// under its `block/` id, so every layer is there) and for an element model
/// whose every face reads an `item/` texture; the blocks sheet otherwise.
///
/// The model's id folder is not the rule: `item/big_dripleaf` and
/// `item/small_dripleaf` are `item/` ids whose elements read `block/`
/// textures (2 of 753 element items in the 26.2 pack), while no element model
/// mixes folders across its faces. The renderer and the pack's pin test share
/// this so the mesh's UVs and the bound texture can never disagree.
bool mcUsesItemAtlas(McResolvedModel model) {
  if (model.generated) return true;
  bool any = false;
  for (final McResolvedElement element in model.elements) {
    for (final McResolvedFace face in element.faces.values) {
      any = true;
      if (!face.texture.startsWith('item/')) return false;
    }
  }
  return any;
}

sealed class McItemModelResult {
  const McItemModelResult();
}

final class McItemModelResolved extends McItemModelResult {
  const McItemModelResolved(this.model, this.tints);
  final McResolvedModel model;
  final List<McTintJson> tints;
}

/// No JSON geometry for this item; draw the catalog sprite and say why.
final class McItemModelSprite extends McItemModelResult {
  const McItemModelSprite(this.reason);
  final String reason;
}

/// Accumulator for one parent walk, child first.
final class _Chain {
  final Map<String, String> textures = <String, String>{};
  final Map<String, McDisplayTransformJson> display =
      <String, McDisplayTransformJson>{};
  List<McElementJson> elements = const <McElementJson>[];
  bool elementsDeclared = false;
  bool generated = false;
  bool entityBuiltin = false;
  String? guiLight;
}

final class McModelResolver {
  McModelResolver(this.store);

  final McModelStore store;
  final Map<String, McResolvedModel?> _cache = <String, McResolvedModel?>{};

  /// Null when [modelId] or any ancestor is missing from the store.
  McResolvedModel? resolveModel(String modelId) {
    final String id = mcModelId(modelId);
    if (_cache.containsKey(id)) return _cache[id];
    final _Chain? chain = _walk(id);
    if (chain == null) return _cache[id] = null;
    final List<McResolvedElement> elements = <McResolvedElement>[
      for (final McElementJson element in chain.elements)
        McResolvedElement(
          from: element.from,
          to: element.to,
          shade: element.shade,
          rotation: element.rotation,
          faces: <String, McResolvedFace>{
            for (final MapEntry<String, McFaceJson> face
                in element.faces.entries)
              face.key: McResolvedFace(
                texture: _faceTexture(chain.textures, face.value.texture),
                uv:
                    face.value.uv ??
                    _defaultUv(face.key, element.from, element.to),
                rotation: face.value.rotation,
                cullface: face.value.cullface,
                tintIndex: face.value.tintIndex,
              ),
          },
        ),
    ];
    final List<String> layers = <String>[];
    for (int i = 0; chain.textures.containsKey('layer$i'); i++) {
      layers.add(_texture(chain.textures, chain.textures['layer$i']!));
    }
    return _cache[id] = McResolvedModel(
      id: id,
      elements: elements,
      textures: chain.textures,
      display: chain.display,
      generated: chain.generated,
      entityBuiltin: chain.entityBuiltin,
      layers: layers,
      guiLight: chain.guiLight,
    );
  }

  /// The resting model for an item key (`diamond_sword`, `grass_block`).
  McItemModelResult resolveItem(String itemKey) {
    final String id = mcItemId(itemKey);
    final McItemDefinitionNode? root = store.item(id);
    if (root == null) return McItemModelSprite('no item definition for $id');
    return _dispatch(root, id);
  }

  /// The default blockstate model for a block key, or null when unknown.
  McResolvedModel? resolveBlock(String blockKey) {
    final McBlockstateVariantJson? variant = blockVariant(blockKey);
    if (variant == null) return null;
    return resolveModel(variant.model);
  }

  /// The blockstate rotation a world block is placed with.
  McBlockstateVariantJson? blockVariant(String blockKey) =>
      store.blockstate(mcBlockId(blockKey))?.defaultVariant;

  McItemModelResult _dispatch(McItemDefinitionNode node, String id) =>
      switch (node) {
        McItemModelNode(:final String model, :final List<McTintJson> tints) =>
          _resolvedOrSprite(model, tints, id),
        McItemConditionNode(:final McItemDefinitionNode onFalse) => _dispatch(
          onFalse,
          id,
        ),
        McItemSelectNode(
          :final List<McItemDefinitionNode> cases,
          :final McItemDefinitionNode? fallback,
        ) =>
          fallback != null
              ? _dispatch(fallback, id)
              : cases.isEmpty
              ? McItemModelSprite('empty select for $id')
              : _dispatch(cases.first, id),
        McItemRangeDispatchNode(
          :final List<McItemDefinitionNode> entries,
          :final McItemDefinitionNode? fallback,
        ) =>
          fallback != null
              ? _dispatch(fallback, id)
              : entries.isEmpty
              ? McItemModelSprite('empty range dispatch for $id')
              : _dispatch(entries.first, id),
        McItemCompositeNode(:final List<McItemDefinitionNode> models) =>
          _composite(models, id),
        McItemSpecialNode(:final String specialType) => McItemModelSprite(
          'special renderer $specialType for $id',
        ),
        McItemEmptyNode() => McItemModelSprite('empty model for $id'),
        McItemUnknownNode(:final String type) => McItemModelSprite(
          'unsupported definition $type for $id',
        ),
      };

  McItemModelResult _resolvedOrSprite(
    String modelId,
    List<McTintJson> tints,
    String id,
  ) {
    final McResolvedModel? model = resolveModel(modelId);
    if (model == null) {
      return McItemModelSprite('missing model $modelId for $id');
    }
    if (model.entityBuiltin) {
      return McItemModelSprite('builtin/entity model $modelId for $id');
    }
    if (!model.generated && model.elements.isEmpty) {
      return McItemModelSprite('no elements in $modelId for $id');
    }
    return McItemModelResolved(model, tints);
  }

  /// Every child that resolves, merged into one model under the first's id.
  McItemModelResult _composite(List<McItemDefinitionNode> models, String id) {
    final List<McResolvedModel> resolved = <McResolvedModel>[];
    final List<McTintJson> tints = <McTintJson>[];
    for (final McItemDefinitionNode child in models) {
      final McItemModelResult result = _dispatch(child, id);
      if (result is McItemModelResolved) {
        resolved.add(result.model);
        tints.addAll(result.tints);
      }
    }
    if (resolved.isEmpty) return McItemModelSprite('empty composite for $id');
    if (resolved.length == 1) {
      return McItemModelResolved(resolved.single, tints);
    }
    final McResolvedModel first = resolved.first;
    return McItemModelResolved(
      McResolvedModel(
        id: first.id,
        elements: <McResolvedElement>[
          for (final McResolvedModel model in resolved) ...model.elements,
        ],
        textures: first.textures,
        display: first.display,
        generated: resolved.any((McResolvedModel model) => model.generated),
        entityBuiltin: false,
        layers: <String>[
          for (final McResolvedModel model in resolved) ...model.layers,
        ],
        guiLight: first.guiLight,
      ),
      tints,
    );
  }

  _Chain? _walk(String id) {
    final _Chain chain = _Chain();
    String? current = id;
    int depth = 0;
    while (current != null) {
      if (current == mcBuiltinGenerated) {
        chain.generated = true;
        break;
      }
      if (current == mcBuiltinEntity) {
        chain.entityBuiltin = true;
        break;
      }
      final McModelJson? model = store.model(current);
      if (model == null) return null;
      for (final MapEntry<String, String> entry in model.textures.entries) {
        chain.textures.putIfAbsent(entry.key, () => entry.value);
      }
      for (final MapEntry<String, McDisplayTransformJson> entry
          in model.display.entries) {
        chain.display.putIfAbsent(entry.key, () => entry.value);
      }
      if (!chain.elementsDeclared && model.declaresElements) {
        chain.elements = model.elements;
        chain.elementsDeclared = true;
      }
      chain.guiLight ??= model.guiLight;
      current = model.parent;
      if (++depth > _maxParentDepth) return null;
    }
    return chain;
  }

  /// A face's `texture` is always a slot name: the client
  /// (`BlockModel.getMaterial`) strips an optional `#` and looks the slot up,
  /// so `block/heavy_core.json`'s bare `"texture": "all"` reads the `all`
  /// slot like `#all` would. An unknown slot is the missing texture.
  static String _faceTexture(Map<String, String> textures, String reference) {
    final String slot = reference.startsWith('#') ? reference.substring(1) : reference;
    final String? value = textures[slot];
    return value == null ? mcMissingTexture : _texture(textures, value);
  }

  /// Chases `#a -> #b -> block/x`; an unresolved variable becomes the missing
  /// texture id so the mesher draws the magenta checker instead of throwing.
  static String _texture(Map<String, String> textures, String reference) {
    String value = reference;
    for (int hop = 0; hop < _maxParentDepth && value.startsWith('#'); hop++) {
      final String? next = textures[value.substring(1)];
      if (next == null) return mcMissingTexture;
      value = next;
    }
    return value.startsWith('#') ? mcMissingTexture : value;
  }

  /// Vanilla's per-face default UV from the element bounds.
  static List<double> _defaultUv(
    String face,
    List<double> from,
    List<double> to,
  ) => switch (face) {
    'down' => <double>[from[0], 16 - to[2], to[0], 16 - from[2]],
    'up' => <double>[from[0], from[2], to[0], to[2]],
    'north' => <double>[16 - to[0], 16 - to[1], 16 - from[0], 16 - from[1]],
    'south' => <double>[from[0], 16 - to[1], to[0], 16 - from[1]],
    'west' => <double>[from[2], 16 - to[1], to[2], 16 - from[1]],
    'east' => <double>[16 - to[2], 16 - to[1], 16 - from[2], 16 - from[1]],
    _ => <double>[0, 0, 16, 16],
  };
}

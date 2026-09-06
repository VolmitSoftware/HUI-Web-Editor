/// Writes `web/assets/mc/<version>/` from a jar and a resolved skin.
///
/// Textures: every `textures/block/*.png` into `blocks.png`, every
/// `textures/item/*.png` into `items.png` together with every `block/`
/// texture a generated item model names as a `layerN` (flowers, saplings,
/// torches, rails, panes: ~112 tiles, keyed by their `block/` id) so an item
/// drawable binds one atlas (`mcUsesItemAtlas`); a `.png.mcmeta` sibling
/// marks an animation, whose frame count is `height / width` and of which
/// only frame 0 is packed. Models: every `models/block`, `models/item` and
/// `items/` definition verbatim, plus every blockstate reduced to its default
/// variant, in one `models.json`. The manifest records which item
/// definitions resolve to a sprite fallback so the count is visible and
/// pinned.
///
/// HUD and environment sprites are written under the map key, not the jar
/// file name (`hud/heart_full.png`, `environment/sun.png`), since several jar
/// paths collapse to the same basename (`heart/full.png`, `food_full.png`).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:gloss_editor/mc/assets/mc_model_json.dart';
import 'package:gloss_editor/mc/assets/mc_model_resolver.dart';
import 'package:gloss_editor/mc/assets/mc_model_store.dart';
import 'package:gloss_editor/mc/assets/mc_pack_manifest.dart';
import 'package:image/image.dart' as img;

import 'atlas_packer.dart';
import 'jar_assets.dart';
import 'skin_resolver.dart';

const String _base = 'assets/minecraft';

final class PackWriter {
  const PackWriter({
    required this.jar,
    required this.version,
    required this.jarSha256,
    required this.skin,
    required this.generatedAt,
    required this.entityTextures,
    required this.hudSprites,
    required this.environment,
  });

  final JarAssets jar;
  final String version;
  final String jarSha256;
  final ResolvedSkin skin;
  final String generatedAt;

  /// Rig id to jar path under `textures/`.
  final Map<String, String> entityTextures;

  /// HUD key to jar path under `textures/`.
  final Map<String, String> hudSprites;

  /// Environment key to jar path under `textures/`.
  final Map<String, String> environment;

  Future<void> write(Directory output) async {
    output.createSync(recursive: true);
    final Map<String, Object?> models = _models();
    final McJsonModelStore store = McJsonModelStore.fromJson(models);
    final McModelResolver resolver = McModelResolver(store);
    final List<AtlasTile> itemBlockLayers = _itemBlockLayers(models, resolver);
    final PackedAtlas blocks = packAtlas(_tiles('block'));
    final PackedAtlas items = packAtlas(<AtlasTile>[..._tiles('item'), ...itemBlockLayers]);
    _writePng(output, 'blocks.png', blocks.image);
    _writePng(output, 'items.png', items.image);
    File('${output.path}/models.json').writeAsStringSync(jsonEncode(models));

    final Map<String, String> entityOut = <String, String>{};
    for (final MapEntry<String, String> entry in entityTextures.entries) {
      entityOut[entry.key] = _copy(output, entry.value, entry.value);
    }
    final Map<String, String> hudOut = <String, String>{};
    for (final MapEntry<String, String> entry in hudSprites.entries) {
      hudOut[entry.key] = _copy(output, entry.value, 'hud/${entry.key}.png');
    }
    final Map<String, String> environmentOut = <String, String>{};
    for (final MapEntry<String, String> entry in environment.entries) {
      environmentOut[entry.key] = _copy(output, entry.value, 'environment/${entry.key}.png');
    }

    final McPlayerMeta player = McPlayerMeta(
      name: skin.username,
      uuid: skin.uuid,
      slim: skin.slim,
      cape: skin.capePng != null,
    );
    _writeBytes(output, player.skinPath, skin.skinPng);
    if (skin.capePng != null) _writeBytes(output, player.capePath, skin.capePng!);

    final List<String> fallbacks = <String>[
      for (final String id in store.itemIds)
        if (resolver.resolveItem(id) is McItemModelSprite) id,
    ]..sort();

    final McPackManifest manifest = McPackManifest(
      version: version,
      jarSha256: jarSha256,
      generatedAt: generatedAt,
      blocks: McAtlas(image: 'blocks.png', width: blocks.image.width, height: blocks.image.height, entries: blocks.entries),
      items: McAtlas(image: 'items.png', width: items.image.width, height: items.image.height, entries: items.entries),
      entityTextures: entityOut,
      hud: hudOut,
      environment: environmentOut,
      player: player,
      counts: <String, int>{
        'models': store.modelCount,
        'items': store.itemCount,
        'blockstates': store.blockstateCount,
        'blockTextures': blocks.entries.length - 1,
        'itemTextures': items.entries.length - 1 - itemBlockLayers.length,
        'itemBlockLayers': itemBlockLayers.length,
        'spriteFallbacks': fallbacks.length,
      },
      spriteFallbacks: fallbacks,
    );
    File('${output.path}/pack.json').writeAsStringSync(jsonEncode(manifest.toJson()));
  }

  /// Spec 4: an animated texture (a `.png.mcmeta` sibling) contributes frame 0
  /// only. The strip is cropped to its first `height / frames` rows before
  /// packing, and the entry is recorded as a one-frame tile so `McAtlas.uv`
  /// (which divides the entry height by `frames`) still returns that frame's
  /// rect. Uncropped, 54 block strips up to 1024 px tall tripled the sheet.
  List<AtlasTile> _tiles(String folder) {
    final String prefix = '$_base/textures/$folder/';
    return <AtlasTile>[
      for (final String path in jar.paths(prefix, '.png'))
        ?_tile('$folder/${path.substring(prefix.length, path.length - 4)}'),
    ];
  }

  /// One tile by texture id (`block/poppy`), or null when the jar has no such
  /// PNG or it does not decode.
  AtlasTile? _tile(String id) {
    final String path = '$_base/textures/$id.png';
    final Uint8List? bytes = jar.bytes(path);
    final img.Image? decoded = bytes == null ? null : img.decodePng(bytes);
    if (decoded == null) return null;
    final bool animated = jar.bytes('$path.mcmeta') != null;
    final int frames = animated && decoded.height > decoded.width
        ? decoded.height ~/ decoded.width
        : 1;
    // Normalise before cropping: `copyCrop` on a paletted source hands back
    // an image whose palette `convert` cannot read.
    final img.Image rgba = _rgba(decoded);
    final img.Image frame0 = frames > 1
        ? img.copyCrop(rgba, x: 0, y: 0, width: rgba.width, height: rgba.height ~/ frames)
        : rgba;
    return AtlasTile(id, frame0, 1);
  }

  /// Every `block/` texture some `models/item/*` model with `builtin/generated`
  /// ancestry names as a `layerN`, as items-atlas tiles under the same id.
  /// The renderer meshes a generated item from the items atlas alone
  /// (`mcUsesItemAtlas`), so the layer has to be there; the blocks atlas keeps
  /// its own copy for the world.
  List<AtlasTile> _itemBlockLayers(Map<String, Object?> models, McModelResolver resolver) {
    final Set<String> ids = <String>{};
    for (final String id in (models['models'] as Map<String, Object?>).keys) {
      if (!id.startsWith('item/')) continue;
      final McResolvedModel? model = resolver.resolveModel(id);
      if (model == null || !model.generated) continue;
      for (final String layer in model.layers) {
        if (layer.startsWith('block/')) ids.add(layer);
      }
    }
    return <AtlasTile>[for (final String id in ids.toList()..sort()) ?_tile(id)];
  }

  /// Vanilla ships many textures as grayscale (colour type 0) or paletted
  /// (colour type 3, no alpha) PNGs. `img.decodePng` keeps the source's
  /// native channel count, so a bare `Pixel.g`/`Pixel.b`/`Pixel.a` read (as
  /// `compositeImage` and any GL/raster consumer does) silently returns 0 for
  /// a missing channel instead of the intended value: grayscale tiles bake
  /// into the atlas as pure red, and alpha-less paletted tiles as fully
  /// transparent. Normalise every tile to true RGBA8 once, here, so the
  /// composited atlas always carries real colour and opacity.
  static img.Image _rgba(img.Image image) =>
      image.numChannels == 4 && image.format == img.Format.uint8
          ? image
          : image.convert(numChannels: 4, format: img.Format.uint8);

  Map<String, Object?> _models() {
    Map<String, Object?> folder(
      String sub,
      String Function(String path) key, {
      bool normalizeModel = false,
    }) {
      final String base = '$_base/$sub/';
      return <String, Object?>{
        for (final String path in jar.paths(base, '.json'))
          key(path.substring(base.length, path.length - 5)): normalizeModel
              ? _normalizeModelJson(jsonDecode(jar.text(path)!))
              : jsonDecode(jar.text(path)!),
      };
    }

    final Map<String, Object?> blockstates = <String, Object?>{};
    const String statesBase = '$_base/blockstates/';
    for (final String path in jar.paths(statesBase, '.json')) {
      final Map<String, Object?>? reduced = _defaultVariantJson(jar.text(path)!);
      if (reduced == null) continue;
      blockstates[path.substring(statesBase.length, path.length - 5)] = reduced;
    }
    return <String, Object?>{
      'models': <String, Object?>{
        ...folder('models/block', (String p) => 'block/$p', normalizeModel: true),
        ...folder('models/item', (String p) => 'item/$p', normalizeModel: true),
      },
      'items': folder('items', (String p) => p),
      'blockstates': blockstates,
    };
  }

  /// Spec 4: `models.json` carries a blockstate's default variant, not the
  /// whole file. The reduction runs the pack's own parser
  /// ([McBlockstateJson.fromJson]) and writes the result back in the shape
  /// that parser reads, so the resolver is untouched and the multipart
  /// monsters (`redstone_wire`, every fence and wall family) stop shipping.
  /// A blockstate with no default variant is dropped.
  static Map<String, Object?>? _defaultVariantJson(String raw) {
    final McBlockstateVariantJson? variant =
        McBlockstateJson.fromJson(jsonDecode(raw) as Map<String, Object?>).defaultVariant;
    if (variant == null) return null;
    return <String, Object?>{
      'variants': <String, Object?>{
        '': <String, Object?>{
          'model': variant.model,
          if (variant.x != 0) 'x': variant.x,
          if (variant.y != 0) 'y': variant.y,
          if (variant.uvlock) 'uvlock': true,
        },
      },
    };
  }

  /// 26.2 lets a model's `textures` value be a render-hint object
  /// (`{"sprite": "...", "force_translucent": true}`) instead of a bare
  /// string. `McModelJson.fromJson` (Task 2/3, out of this tool's scope) only
  /// understands the string form, so the extractor flattens it here to the
  /// `sprite` field before the model JSON is written to the pack.
  static Map<String, Object?> _normalizeModelJson(Object? raw) {
    final Map<String, Object?> json = raw as Map<String, Object?>;
    final Object? textures = json['textures'];
    if (textures is! Map<String, Object?>) return json;
    return <String, Object?>{
      ...json,
      'textures': <String, Object?>{
        for (final MapEntry<String, Object?> entry in textures.entries)
          entry.key: entry.value is Map<String, Object?>
              ? (entry.value as Map<String, Object?>)['sprite'] as String
              : entry.value,
      },
    };
  }

  String _copy(Directory output, String jarRelative, String packRelative) {
    final Uint8List? bytes = jar.bytes('$_base/textures/$jarRelative');
    if (bytes == null) throw StateError('missing texture $jarRelative in the jar');
    _writeBytes(output, packRelative, bytes);
    return packRelative;
  }

  void _writePng(Directory output, String name, img.Image image) =>
      _writeBytes(output, name, Uint8List.fromList(img.encodePng(image, level: 9)));

  void _writeBytes(Directory output, String relative, Uint8List bytes) {
    final File file = File('${output.path}/$relative');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
  }
}

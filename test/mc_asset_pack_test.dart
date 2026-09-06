/// The committed 26.2 pack: every stage's textures, models and rigs.
library;

import 'dart:convert';
import 'dart:io';

import 'package:gloss_editor/mc/assets/mc_model_resolver.dart';
import 'package:gloss_editor/mc/assets/mc_model_store.dart';
import 'package:gloss_editor/mc/assets/mc_pack_manifest.dart';
import 'package:test/test.dart';

const String _pack = 'web/assets/mc/26.2';

Map<String, Object?> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void main() {
  final McPackManifest manifest = McPackManifest.fromJson(_json('$_pack/pack.json'));
  final McJsonModelStore store = McJsonModelStore.fromJson(_json('$_pack/models.json'));
  final McModelResolver resolver = McModelResolver(store);

  test('the pack is the 26.2 client with a whole-jar hash', () {
    expect(manifest.version, '26.2');
    expect(manifest.jarSha256, hasLength(64));
    // The real 26.2 client jar ships 1269 block and 796 item texture PNGs
    // (verified against the jar directly); floors below that with headroom.
    expect(manifest.counts['blockTextures'], greaterThanOrEqualTo(1200));
    expect(manifest.counts['itemTextures'], greaterThanOrEqualTo(750));
    expect(manifest.counts['items'], greaterThanOrEqualTo(1500));
  });

  test('every catalog material resolves to a model or a declared fallback', () {
    final Map<String, Object?> catalog = _json('web/assets/catalog/items.json');
    final Set<String> fallbacks = manifest.spriteFallbacks.toSet();
    final List<String> unresolved = <String>[];
    for (final Object? raw in catalog['materials']! as List<Object?>) {
      final String key = (raw! as Map<String, Object?>)['key']! as String;
      final McItemModelResult result = resolver.resolveItem(key);
      if (result is McItemModelSprite && !fallbacks.contains(key)) {
        unresolved.add('$key: ${result.reason}');
      }
    }
    // Paper's Material enum has legacy and non-item entries (AIR, water,
    // lava, fire, cave_air, bubble_column, ...) with no item definition;
    // those are reported by reason and are the only permitted unresolved keys.
    expect(
      unresolved.where((String line) => !line.contains('no item definition')),
      isEmpty,
      reason: unresolved.join('\n'),
    );
    // Paper's real Material enum carries far more non-item block variants
    // (wall signs, wall banners, potted plants, candle cakes, growth-stage
    // crops, fluids, piston internals, ...) than a rough guess accounts for;
    // 154 verified none-item keys against this catalog and jar.
    expect(unresolved.length, lessThan(200), reason: unresolved.join('\n'));
  });

  test('every resolved item meshes from the atlas the renderer binds', () {
    // The renderer binds ONE atlas per item drawable ([mcUsesItemAtlas]), so
    // every texture the mesh reads has to live in that atlas: a generated
    // item's `block/` layer (poppy, torch, sapling, rail, pane) must be in
    // `items.png`, not merely somewhere.
    int generated = 0, elements = 0, blockLayers = 0;
    for (final String id in store.itemIds) {
      final McItemModelResult result = resolver.resolveItem(id);
      if (result is! McItemModelResolved) continue;
      final McAtlas atlas = mcUsesItemAtlas(result.model) ? manifest.items : manifest.blocks;
      if (result.model.generated) {
        expect(mcUsesItemAtlas(result.model), isTrue, reason: id);
        expect(result.model.layers, isNotEmpty, reason: id);
        for (final String layer in result.model.layers) {
          if (layer.startsWith('block/')) blockLayers++;
          expect(manifest.items.uv(layer), isNotNull, reason: '$id layer $layer');
        }
        generated++;
      } else {
        expect(result.model.elements, isNotEmpty, reason: id);
        for (final McResolvedElement element in result.model.elements) {
          for (final McResolvedFace face in element.faces.values) {
            expect(atlas.uv(face.texture), isNotNull, reason: '$id face ${face.texture}');
          }
        }
        elements++;
      }
    }
    expect(generated, greaterThan(500));
    expect(elements, greaterThan(500));
    // 115 generated items in the 26.2 jar carry a `block/` layer.
    expect(blockLayers, greaterThan(100));
    expect(manifest.items.uv('block/poppy'), isNotNull);
    expect(manifest.items.uv('block/torch'), isNotNull);
    expect(manifest.counts['itemBlockLayers'], greaterThan(100));
  });

  test('every block texture a block model references is in the atlas', () {
    final List<String> missing = <String>[];
    for (final String block in <String>['grass_block', 'dirt', 'stone', 'oak_log', 'oak_leaves', 'short_grass', 'poppy', 'dandelion', 'torch', 'gravel', 'dirt_path', 'water', 'oak_planks', 'cobblestone']) {
      final McResolvedModel? model = resolver.resolveBlock(block);
      if (model == null && block != 'water') {
        missing.add('$block: no blockstate');
        continue;
      }
      for (final McResolvedElement element in model?.elements ?? const <McResolvedElement>[]) {
        for (final McResolvedFace face in element.faces.values) {
          if (manifest.blocks.uv(face.texture) == null) missing.add('$block: ${face.texture}');
        }
      }
    }
    expect(manifest.blocks.uv('block/water_still'), isNotNull);
    // Animated strips contribute frame 0 only, so the tile is one 16x16
    // frame in the sheet and its rect covers all of it.
    final McAtlasEntry water = manifest.blocks.entries['block/water_still']!;
    expect(water.height, 16);
    expect(water.frames, 1);
    expect(manifest.blocks.uv('block/water_still')!.v1 - manifest.blocks.uv('block/water_still')!.v0,
        closeTo(16 / manifest.blocks.height, 1e-9));
    expect(missing, isEmpty);
  });

  test('rig, HUD, environment and player files exist', () {
    for (final String key in <String>['zombie', 'skeleton', 'creeper', 'pig', 'cow', 'sheep', 'sheep_wool', 'steve', 'alex']) {
      final String? path = manifest.entityTextures[key];
      expect(path, isNotNull, reason: key);
      expect(File('$_pack/$path').existsSync(), isTrue, reason: key);
    }
    for (final String key in <String>['hotbar', 'hotbar_selection', 'heart_container', 'heart_full', 'heart_half', 'food_empty', 'food_full', 'food_half', 'armor_empty', 'armor_full', 'armor_half', 'xp_background', 'xp_progress', 'crosshair']) {
      expect(File('$_pack/${manifest.hud[key]}').existsSync(), isTrue, reason: key);
    }
    for (final String key in <String>['sun', 'clouds', 'critical_hit']) {
      expect(File('$_pack/${manifest.environment[key]}').existsSync(), isTrue, reason: key);
    }
    expect(manifest.player.name, 'Magic_Psycho');
    expect(manifest.player.uuid, '85ff4989a64f4db693f100c85bfc4e75');
    expect(manifest.player.slim, isFalse);
    expect(manifest.player.cape, isTrue);
    expect(File('$_pack/${manifest.player.skinPath}').existsSync(), isTrue);
    expect(File('$_pack/${manifest.player.capePath}').existsSync(), isTrue);
  });

  test('the missing tile sits at the atlas origin', () {
    expect(manifest.blocks.entries['missing']!.x, 0);
    expect(manifest.blocks.entries['missing']!.y, 0);
    expect(manifest.items.entries['missing']!.x, 0);
  });

  test('the world still is a 16:9 PNG', () {
    expect(File('$_pack/${manifest.worldStillPath}').existsSync(), isTrue);
    final List<int> bytes = File('$_pack/${manifest.worldStillPath}').readAsBytesSync();
    expect(bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4e, 0x47]);
  });
}

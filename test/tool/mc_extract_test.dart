/// The extraction tool against a synthetic jar and a fake Mojang.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:gloss_editor/mc/assets/mc_pack_manifest.dart';
import 'package:gloss_editor/mc/mesh/mc_mesh.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import '../../tool/mc_extract/atlas_packer.dart';
import '../../tool/mc_extract/jar_assets.dart';
import '../../tool/mc_extract/pack_writer.dart';
import '../../tool/mc_extract/skin_resolver.dart';

Uint8List _png(int width, int height, {int alpha = 255}) {
  final img.Image image = img.Image(width: width, height: height, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(200, 100, 50, alpha));
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _jar() {
  final Archive archive = Archive();
  void add(String path, List<int> bytes) =>
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
  void addText(String path, String text) => add(path, utf8.encode(text));
  const String base = 'assets/minecraft';
  addText('$base/models/block/cube_all.json', '{"parent":"block/cube","textures":{"particle":"#all","down":"#all","up":"#all","north":"#all","east":"#all","south":"#all","west":"#all"}}');
  addText('$base/models/block/cube.json', '{"parent":"block/block","elements":[{"from":[0,0,0],"to":[16,16,16],"faces":{"down":{"texture":"#down","cullface":"down"},"up":{"texture":"#up","cullface":"up"},"north":{"texture":"#north","cullface":"north"},"south":{"texture":"#south","cullface":"south"},"west":{"texture":"#west","cullface":"west"},"east":{"texture":"#east","cullface":"east"}}}]}');
  addText('$base/models/block/block.json', '{"display":{"fixed":{"scale":[0.5,0.5,0.5]}}}');
  addText('$base/models/block/stone.json', '{"parent":"minecraft:block/cube_all","textures":{"all":"minecraft:block/stone"}}');
  addText('$base/models/item/generated.json', '{"parent":"builtin/generated","display":{"fixed":{"rotation":[0,180,0]}}}');
  addText('$base/models/item/apple.json', '{"parent":"minecraft:item/generated","textures":{"layer0":"minecraft:item/apple"}}');
  addText('$base/models/item/chest.json', '{"parent":"builtin/entity"}');
  // A flat block item: generated, but its layer is a `block/` texture.
  addText('$base/models/item/torch.json', '{"parent":"minecraft:item/generated","textures":{"layer0":"minecraft:block/torch"}}');
  addText('$base/items/stone.json', '{"model":{"type":"minecraft:model","model":"minecraft:block/stone"}}');
  addText('$base/items/apple.json', '{"model":{"type":"minecraft:model","model":"minecraft:item/apple"}}');
  addText('$base/items/chest.json', '{"model":{"type":"minecraft:special","base":"minecraft:item/chest","model":{"type":"minecraft:chest","texture":"minecraft:normal"}}}');
  addText('$base/items/torch.json', '{"model":{"type":"minecraft:model","model":"minecraft:item/torch"}}');
  addText('$base/blockstates/stone.json', '{"variants":{"":{"model":"minecraft:block/stone"}}}');
  add('$base/textures/block/stone.png', _png(16, 16));
  add('$base/textures/block/torch.png', _png(16, 16));
  add('$base/textures/block/water_still.png', _png(16, 32));
  addText('$base/textures/block/water_still.png.mcmeta', '{"animation":{}}');
  add('$base/textures/item/apple.png', _png(16, 16));
  add('$base/textures/entity/zombie/zombie.png', _png(64, 64));
  add('$base/textures/entity/player/wide/steve.png', _png(64, 64));
  add('$base/textures/gui/sprites/hud/hotbar.png', _png(182, 22));
  add('$base/textures/environment/sun.png', _png(32, 32));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

http.Client _mojang({bool slim = false, bool cape = true}) => MockClient((http.Request request) async {
  final String url = request.url.toString();
  if (url == 'https://api.mojang.com/users/profiles/minecraft/Magic_Psycho') {
    return http.Response('{"id":"85ff4989a64f4db693f100c85bfc4e75","name":"Magic_Psycho"}', 200);
  }
  if (url.startsWith('https://sessionserver.mojang.com/session/minecraft/profile/')) {
    final Map<String, Object?> textures = <String, Object?>{
      'textures': <String, Object?>{
        'SKIN': <String, Object?>{
          'url': 'http://textures.minecraft.net/texture/skin',
          if (slim) 'metadata': <String, Object?>{'model': 'slim'},
        },
        if (cape) 'CAPE': <String, Object?>{'url': 'http://textures.minecraft.net/texture/cape'},
      },
    };
    final String value = base64.encode(utf8.encode(jsonEncode(textures)));
    return http.Response('{"id":"85ff4989a64f4db693f100c85bfc4e75","name":"Magic_Psycho","properties":[{"name":"textures","value":"$value"}]}', 200);
  }
  if (url == 'http://textures.minecraft.net/texture/skin') {
    return http.Response.bytes(_png(64, 64), 200);
  }
  if (url == 'http://textures.minecraft.net/texture/cape') {
    return http.Response.bytes(_png(64, 32), 200);
  }
  return http.Response('not found', 404);
});

void main() {
  test('jar assets list and read entries under a prefix', () {
    final JarAssets jar = JarAssets.fromBytes(_jar());
    expect(jar.paths('assets/minecraft/textures/block/', '.png').toList(), hasLength(3));
    expect(jar.text('assets/minecraft/blockstates/stone.json'), contains('block/stone'));
    expect(jar.bytes('assets/minecraft/missing.png'), isNull);
  });

  test('the atlas packer places tiles on a grid and reserves the missing tile', () {
    final PackedAtlas atlas = packAtlas(<AtlasTile>[
      AtlasTile('block/stone', img.decodePng(_png(16, 16))!, 1),
      AtlasTile('block/water_still', img.decodePng(_png(16, 32))!, 2),
    ]);
    expect(atlas.entries['block/stone']!.width, 16);
    expect(atlas.entries['block/water_still']!.frames, 2);
    expect(atlas.entries['block/water_still']!.height, 32);
    // The origin tile is the magenta checker; nothing else may sit there.
    for (final McAtlasEntry entry in atlas.entries.values) {
      if (entry.id == 'missing') continue;
      expect(entry.x == 0 && entry.y == 0, isFalse, reason: entry.id);
    }
    expect(atlas.image.getPixel(0, 0).r, 0xF8);
    expect(atlas.image.width % 16, 0);
  });

  test('the skin resolver reads uuid, model and cape through the profile chain', () async {
    final ResolvedSkin skin = await resolveSkin('Magic_Psycho', _mojang());
    expect(skin.uuid, '85ff4989a64f4db693f100c85bfc4e75');
    expect(skin.slim, isFalse);
    expect(skin.capePng, isNotNull);
    final ResolvedSkin slim = await resolveSkin('Magic_Psycho', _mojang(slim: true, cape: false));
    expect(slim.slim, isTrue);
    expect(slim.capePng, isNull);
  });

  test('the pack writer emits every file the manifest names', () async {
    final Directory output = Directory.systemTemp.createTempSync('mc_pack');
    addTearDown(() => output.deleteSync(recursive: true));
    await PackWriter(
      jar: JarAssets.fromBytes(_jar()),
      version: '26.2',
      jarSha256: 'deadbeef',
      skin: await resolveSkin('Magic_Psycho', _mojang()),
      generatedAt: '2026-09-05T00:00:00Z',
      entityTextures: const <String, String>{'zombie': 'entity/zombie/zombie.png'},
      hudSprites: const <String, String>{'hotbar': 'gui/sprites/hud/hotbar.png'},
      environment: const <String, String>{'sun': 'environment/sun.png'},
    ).write(output);
    final McPackManifest manifest = McPackManifest.fromJson(
      jsonDecode(File('${output.path}/pack.json').readAsStringSync()) as Map<String, Object?>,
    );
    expect(manifest.version, '26.2');
    // block/{cube_all,cube,block,stone} + item/{generated,apple,chest,torch} = 8.
    expect(manifest.counts['models'], 8);
    expect(manifest.counts['items'], 4);
    expect(manifest.counts['blockstates'], 1);
    expect(manifest.spriteFallbacks, <String>['chest']);
    expect(manifest.blocks.uv('block/stone'), isNotNull);
    expect(manifest.items.uv('item/apple'), isNotNull);
    // The torch is a generated item drawn from the items atlas, so its
    // `block/` layer is packed there too, under its `block/` id, while the
    // blocks atlas keeps its own copy for the world.
    expect(manifest.items.uv('block/torch'), isNotNull);
    expect(manifest.blocks.uv('block/torch'), isNotNull);
    expect(manifest.items.uv('block/stone'), isNull);
    expect(manifest.counts['itemBlockLayers'], 1);
    // `itemTextures` stays the `item/` count; the layer copies are counted apart.
    expect(manifest.counts['itemTextures'], 1);
    expect(manifest.player.name, 'Magic_Psycho');
    for (final String path in <String>[
      'blocks.png',
      'items.png',
      'models.json',
      'entity/zombie/zombie.png',
      'hud/hotbar.png',
      'environment/sun.png',
      'player/magic_psycho.png',
      'player/magic_psycho_cape.png',
    ]) {
      expect(File('${output.path}/$path').existsSync(), isTrue, reason: path);
    }
    final Map<String, Object?> models = jsonDecode(File('${output.path}/models.json').readAsStringSync()) as Map<String, Object?>;
    expect((models['models'] as Map<String, Object?>).keys, contains('block/stone'));
    // Blockstates ship pre-reduced to the default variant in the parser's own
    // shape, not the raw file: `{"variants": {"": {"model": ...}}}`.
    expect(
      (models['blockstates'] as Map<String, Object?>)['stone'],
      <String, Object?>{
        'variants': <String, Object?>{
          '': <String, Object?>{'model': 'block/stone'},
        },
      },
    );
    // The animated water strip contributes frame 0 only: the 16x32 source is
    // cropped to one 16x16 tile, so the atlas rect is a whole tile.
    final McAtlasEntry water = manifest.blocks.entries['block/water_still']!;
    expect(water.height, 16);
    expect(water.frames, 1);
    final McUvRect rect = manifest.blocks.uv('block/water_still')!;
    expect((rect.v1 - rect.v0) * manifest.blocks.height, closeTo(16, 1e-9));
    expect((rect.u1 - rect.u0) * manifest.blocks.width, closeTo(16, 1e-9));
  });
}

/// Extracts the textures and model JSON the 3D stages draw from a client jar.
///
/// Usage:
///   dart run tool/extract_minecraft_world_assets.dart \
///     --jar="/path/to/minecraft-26.2-client.jar" --version=26.2 \
///     --player=Magic_Psycho [--output=web/assets/mc]
///
/// Offline except for the player skin (Mojang profile API). Re-run whenever
/// the jar version changes; the output folder is versioned so an old pack is
/// never overwritten in place.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:gloss_editor/mc/assets/mc_model_resolver.dart';
import 'package:gloss_editor/mc/assets/mc_model_store.dart';
import 'package:gloss_editor/mc/assets/mc_pack_manifest.dart';
import 'package:gloss_editor/mc/raster/mc_software_raster.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'mc_extract/jar_assets.dart';
import 'mc_extract/pack_writer.dart';
import 'mc_extract/skin_resolver.dart';

/// Rig id to `textures/` path. Only rigged mobs ship; everything else is a
/// catalog sprite (spec 3.3).
const Map<String, String> entityTextures = <String, String>{
  'zombie': 'entity/zombie/zombie.png',
  'skeleton': 'entity/skeleton/skeleton.png',
  'creeper': 'entity/creeper/creeper.png',
  'pig': 'entity/pig/pig_temperate.png',
  'cow': 'entity/cow/cow_temperate.png',
  'sheep': 'entity/sheep/sheep.png',
  'sheep_wool': 'entity/sheep/sheep_wool.png',
  'steve': 'entity/player/wide/steve.png',
  'alex': 'entity/player/slim/alex.png',
};

const Map<String, String> hudSprites = <String, String>{
  'hotbar': 'gui/sprites/hud/hotbar.png',
  'hotbar_selection': 'gui/sprites/hud/hotbar_selection.png',
  'heart_container': 'gui/sprites/hud/heart/container.png',
  'heart_full': 'gui/sprites/hud/heart/full.png',
  'heart_half': 'gui/sprites/hud/heart/half.png',
  'food_empty': 'gui/sprites/hud/food_empty.png',
  'food_full': 'gui/sprites/hud/food_full.png',
  'food_half': 'gui/sprites/hud/food_half.png',
  'armor_empty': 'gui/sprites/hud/armor_empty.png',
  'armor_full': 'gui/sprites/hud/armor_full.png',
  'armor_half': 'gui/sprites/hud/armor_half.png',
  'xp_background': 'gui/sprites/hud/experience_bar_background.png',
  'xp_progress': 'gui/sprites/hud/experience_bar_progress.png',
  'crosshair': 'gui/sprites/hud/crosshair.png',
};

const Map<String, String> environmentTextures = <String, String>{
  'sun': 'environment/celestial/sun.png',
  'clouds': 'environment/clouds.png',
  'critical_hit': 'particle/critical_hit.png',
};

Future<void> main(List<String> arguments) async {
  final Map<String, String> options = _options(arguments);
  final File jarFile = File(_required(options, 'jar'));
  final String version = _required(options, 'version');
  final String player = _required(options, 'player');
  final Directory output = Directory('${options['output'] ?? 'web/assets/mc'}/$version');
  if (!jarFile.existsSync()) {
    stderr.writeln('No jar at ${jarFile.path}');
    exitCode = 66;
    return;
  }
  final String sha = sha256.convert(jarFile.readAsBytesSync()).toString();
  final JarAssets jar = JarAssets.fromFile(jarFile);
  final http.Client client = http.Client();
  try {
    final ResolvedSkin skin = await resolveSkin(player, client);
    await PackWriter(
      jar: jar,
      version: version,
      jarSha256: sha,
      skin: skin,
      generatedAt: DateTime.now().toUtc().toIso8601String(),
      entityTextures: entityTextures,
      hudSprites: hudSprites,
      environment: environmentTextures,
    ).write(output);
  } finally {
    client.close();
  }
  final McPackManifest manifest = McPackManifest.fromJson(
    jsonDecode(File('${output.path}/pack.json').readAsStringSync()) as Map<String, Object?>,
  );
  final McModelResolver resolver = McModelResolver(
    McJsonModelStore.fromJson(
      jsonDecode(File('${output.path}/models.json').readAsStringSync()) as Map<String, Object?>,
    ),
  );
  final img.Image atlas = img.decodePng(File('${output.path}/blocks.png').readAsBytesSync())!;
  final img.Image still = mcRenderWorldStill(
    manifest: manifest,
    resolver: resolver,
    blocksAtlas: atlas,
    width: 1280,
    height: 720,
  );
  File('${output.path}/${manifest.worldStillPath}').writeAsBytesSync(img.encodePng(still, level: 9));
  stdout.writeln('Wrote ${output.path}');
}

Map<String, String> _options(List<String> arguments) {
  final Map<String, String> options = <String, String>{};
  for (final String argument in arguments) {
    if (!argument.startsWith('--') || !argument.contains('=')) {
      throw ArgumentError('Expected --name=value, got $argument');
    }
    final int separator = argument.indexOf('=');
    options[argument.substring(2, separator)] = argument.substring(separator + 1);
  }
  return options;
}

String _required(Map<String, String> options, String key) {
  final String? value = options[key];
  if (value == null || value.isEmpty) throw ArgumentError('Missing --$key=value');
  return value;
}

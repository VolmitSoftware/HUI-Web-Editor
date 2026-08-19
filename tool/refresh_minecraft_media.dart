import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as image;

void main(List<String> arguments) {
  final Map<String, String> options = _options(arguments);
  final String version = _required(options, 'version');
  final File atlasFile = File(_required(options, 'atlas'));
  final File atlasJsonFile = File(_required(options, 'atlas-json'));
  final Directory entityDirectory = Directory(_required(options, 'entities'));
  final File mannequinFile = File(_required(options, 'mannequin'));
  final File paperSources = File(_required(options, 'paper-sources'));
  final String rendererRevision = _required(options, 'renderer-revision');
  final File itemsOutput = File(
    options['items-output'] ?? 'web/assets/catalog/items.json',
  );
  final File entitiesOutput = File(
    options['entities-output'] ?? 'web/assets/catalog/entities.json',
  );

  final image.Image atlas =
      image.decodePng(atlasFile.readAsBytesSync()) ??
      (throw StateError('Could not decode ${atlasFile.path}'));
  final Map<String, dynamic> sidecar =
      jsonDecode(atlasJsonFile.readAsStringSync()) as Map<String, dynamic>;
  final Map<String, Map<String, dynamic>> itemTiles =
      <String, Map<String, dynamic>>{};
  final Map<String, Map<String, dynamic>> blockTiles =
      <String, Map<String, dynamic>>{};
  for (final Object? raw in sidecar['tiles'] as List<Object?>) {
    final Map<String, dynamic> tile = raw as Map<String, dynamic>;
    final String id = tile['id'] as String;
    final String key = id.startsWith('minecraft:')
        ? id.substring('minecraft:'.length)
        : id;
    if (tile['kind'] == 'item') {
      itemTiles[key] = tile;
    } else if (tile['kind'] == 'block') {
      blockTiles[key] = tile;
    }
  }

  final Map<String, String?> previous = _previousTextures(itemsOutput);
  final List<String> materialKeys = _paperMaterialKeys(paperSources);
  final List<Map<String, Object?>> materials = <Map<String, Object?>>[];
  for (final String key in materialKeys) {
    final Map<String, dynamic>? tile = itemTiles[key] ?? blockTiles[key];
    final String? texture = tile == null
        ? previous[key]
        : _tileDataUri(atlas, tile);
    materials.add(<String, Object?>{'key': key, 'texture': ?texture});
  }
  itemsOutput.writeAsStringSync(
    jsonEncode(<String, Object?>{
      'version': version,
      'renderer': 'minecraft-library/asset-renderer@$rendererRevision',
      'materials': materials,
    }),
  );

  final List<String> entityKeys = _entityKeys(
    File(options['entity-source'] ?? 'lib/model/hui_icons.dart'),
  );
  final List<Map<String, Object?>> entities = <Map<String, Object?>>[];
  for (final String key in entityKeys) {
    final String path = key.substring('minecraft:'.length);
    final File source = path == 'mannequin'
        ? mannequinFile
        : File('${entityDirectory.path}/minecraft_$path.png');
    if (!source.existsSync()) {
      throw StateError(
        'Missing rendered entity media for $key at ${source.path}',
      );
    }
    final image.Image decoded =
        image.decodePng(source.readAsBytesSync()) ??
        (throw StateError('Could not decode ${source.path}'));
    entities.add(<String, Object?>{
      'key': key,
      'texture': _dataUri(_trim(decoded)),
    });
  }
  entitiesOutput.writeAsStringSync(
    jsonEncode(<String, Object?>{
      'version': version,
      'geometryVersion': '26.1',
      'renderer': 'minecraft-library/asset-renderer@$rendererRevision',
      'entities': entities,
    }),
  );

  stdout.writeln(
    'Wrote ${materials.length} materials and ${entities.length} entities for Minecraft $version.',
  );
}

Map<String, String> _options(List<String> arguments) {
  final Map<String, String> options = <String, String>{};
  for (final String argument in arguments) {
    if (!argument.startsWith('--') || !argument.contains('=')) {
      throw ArgumentError('Expected --name=value, got $argument');
    }
    final int separator = argument.indexOf('=');
    options[argument.substring(2, separator)] = argument.substring(
      separator + 1,
    );
  }
  return options;
}

String _required(Map<String, String> options, String key) {
  final String? value = options[key];
  if (value == null || value.isEmpty) {
    throw ArgumentError('Missing --$key=value');
  }
  return value;
}

Map<String, String?> _previousTextures(File file) {
  if (!file.existsSync()) return <String, String?>{};
  final Map<String, dynamic> root =
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final Map<String, String?> textures = <String, String?>{};
  for (final Object? raw in root['materials'] as List<Object?>) {
    final Map<String, dynamic> entry = raw as Map<String, dynamic>;
    final Object? texture = entry['texture'];
    textures[entry['key'] as String] = texture is String ? texture : null;
  }
  return textures;
}

List<String> _paperMaterialKeys(File sourcesJar) {
  final Archive archive = ZipDecoder().decodeBytes(
    sourcesJar.readAsBytesSync(),
  );
  final ArchiveFile source =
      archive.findFile('org/bukkit/Material.java') ??
      (throw StateError('Material.java is missing from ${sourcesJar.path}'));
  final String text = utf8.decode(source.content as List<int>);
  final int start = text.indexOf('public enum Material');
  final int end = text.indexOf(';', start);
  if (start < 0 || end < 0) throw StateError('Could not parse Material.java');
  final String body = text.substring(start, end);
  final List<String> keys =
      RegExp(r'^\s{4}([A-Z][A-Z0-9_]*)\s*\(', multiLine: true)
          .allMatches(body)
          .map((RegExpMatch match) => match.group(1)!.toLowerCase())
          .where((String key) => !key.startsWith('legacy_'))
          .toList()
        ..sort();
  return keys;
}

List<String> _entityKeys(File source) {
  final String text = source.readAsStringSync();
  final int start = text.indexOf('huiSpawnableLivingEntityTypes');
  final int end = text.indexOf('class HuiIconStyle', start);
  if (start < 0 || end < 0) {
    throw StateError(
      'Could not find the living entity registry in ${source.path}',
    );
  }
  return RegExp(r"'minecraft:[a-z0-9_]+'")
      .allMatches(text.substring(start, end))
      .map(
        (RegExpMatch match) =>
            match.group(0)!.substring(1, match.group(0)!.length - 1),
      )
      .toList();
}

String _tileDataUri(image.Image atlas, Map<String, dynamic> tile) {
  final image.Image crop = image.copyCrop(
    atlas,
    x: tile['x'] as int,
    y: tile['y'] as int,
    width: tile['width'] as int,
    height: tile['height'] as int,
  );
  return _dataUri(crop);
}

String _dataUri(image.Image value) =>
    'data:image/png;base64,${base64Encode(image.encodePng(value, level: 9))}';

image.Image _trim(image.Image source) {
  int left = source.width;
  int top = source.height;
  int right = -1;
  int bottom = -1;
  for (int y = 0; y < source.height; y++) {
    for (int x = 0; x < source.width; x++) {
      if (source.getPixel(x, y).a.toInt() == 0) continue;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }
  if (right < left || bottom < top) return source;
  const int padding = 2;
  left = (left - padding).clamp(0, source.width - 1);
  top = (top - padding).clamp(0, source.height - 1);
  right = (right + padding).clamp(0, source.width - 1);
  bottom = (bottom + padding).clamp(0, source.height - 1);
  return image.copyCrop(
    source,
    x: left,
    y: top,
    width: right - left + 1,
    height: bottom - top + 1,
  );
}

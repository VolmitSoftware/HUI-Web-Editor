import 'dart:convert';
import 'dart:io';

import 'package:gloss_editor/model/hui_icons.dart';
import 'package:test/test.dart';

void main() {
  test('26.2 material catalog contains current gameplay media', () {
    final Map<String, Object?> root = _read('web/assets/catalog/items.json');
    expect(root['version'], '26.2');
    final List<Object?> materials = root['materials']! as List<Object?>;
    expect(materials.length, 1691);
    final Map<String, String?> textures = <String, String?>{};
    for (final Object? raw in materials) {
      final Map<String, Object?> entry = raw! as Map<String, Object?>;
      textures[entry['key']! as String] = entry['texture'] as String?;
    }
    expect(
      textures.values.whereType<String>().length,
      greaterThanOrEqualTo(1640),
    );
    for (final String key in <String>[
      'sulfur',
      'cinnabar',
      'potent_sulfur',
      'sulfur_cube_spawn_egg',
    ]) {
      expect(_isPng(textures[key]), isTrue, reason: key);
    }
  });

  test('26.2 entity catalog covers every supported living entity', () {
    final Map<String, Object?> root = _read('web/assets/catalog/entities.json');
    expect(root['version'], '26.2');
    expect(root['geometryVersion'], '26.1');
    final List<Object?> entities = root['entities']! as List<Object?>;
    final Map<String, String> textures = <String, String>{};
    for (final Object? raw in entities) {
      final Map<String, Object?> entry = raw! as Map<String, Object?>;
      textures[entry['key']! as String] = entry['texture']! as String;
    }
    expect(textures.length, huiSpawnableLivingEntityTypes.length);
    for (final String type in huiSpawnableLivingEntityTypes) {
      expect(_isPng(textures[type]), isTrue, reason: type);
    }
  });
}

Map<String, Object?> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

bool _isPng(String? dataUri) {
  if (dataUri == null || !dataUri.startsWith('data:image/png;base64,')) {
    return false;
  }
  final List<int> bytes = base64Decode(
    dataUri.substring(dataUri.indexOf(',') + 1),
  );
  return bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47;
}

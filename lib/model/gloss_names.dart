import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

enum GlossNameCategory {
  materials,
  entities,
  worlds,
  gameModes,
  dimensions,
  damageCauses,
  effects,
  groups;

  String normalize(String value) {
    final String trimmed = value.trim();
    if (this == worlds) return trimmed;
    String key = trimmed.toLowerCase();
    if (key.startsWith('minecraft:')) key = key.substring(10);
    if (this == dimensions) {
      key = switch (key) {
        'normal' => 'overworld',
        'nether' => 'the_nether',
        _ => key,
      };
    }
    return key;
  }
}

const Map<String, String> glossDefaultMaterialNames = <String, String>{
  'jack_o_lantern': "Jack o'Lantern",
};

const Map<String, String> glossDefaultDimensionNames = <String, String>{
  'overworld': 'Overworld',
  'the_nether': 'The Nether',
  'the_end': 'The End',
};

final class GlossNamesCatalog {
  const GlossNamesCatalog({
    this.categories = const <GlossNameCategory, Map<String, String>>{
      GlossNameCategory.materials: glossDefaultMaterialNames,
      GlossNameCategory.dimensions: glossDefaultDimensionNames,
    },
  });

  final Map<GlossNameCategory, Map<String, String>> categories;

  String name(GlossNameCategory category, String key) {
    final String normalized = category.normalize(key);
    if (normalized.isEmpty) return '';
    return categories[category]?[normalized] ?? glossReadableName(normalized);
  }
}

String glossReadableName(String value) {
  final String trimmed = value.trim();
  final int namespace = trimmed.indexOf(':');
  final String bare = trimmed.substring(namespace + 1).toLowerCase();
  final Iterable<String> words = bare
      .split(RegExp(r'[_\s-]+'))
      .where((String word) => word.isNotEmpty);
  final StringBuffer result = StringBuffer();
  for (final String word in words) {
    final bool first = result.isEmpty;
    if (!first) result.write(' ');
    result.write(
      !first &&
              const <String>{
                'a',
                'an',
                'and',
                'in',
                'o',
                'of',
                'on',
                'the',
                'with',
              }.contains(word)
          ? word
          : '${word[0].toUpperCase()}${word.substring(1)}',
    );
  }
  return result.toString();
}

bool looksLikeNamesDoc(Object? raw) =>
    raw is Map &&
    raw['schemaVersion'] is num &&
    GlossNameCategory.values.any(
      (GlossNameCategory category) => raw[category.name] is Map,
    ) &&
    !raw.containsKey('components') &&
    !raw.containsKey('presentation');

GlossNamesDoc decodeGlossNamesDoc(String source) =>
    GlossNamesDoc.fromJson(jsonDecode(source));

String encodeGlossNamesDoc(GlossNamesDoc doc) => huiWriteJson(doc.toJson());

final class GlossNamesDoc extends GlossDoc {
  GlossNamesDoc({
    super.schemaVersion = 1,
    super.revision = glossInitialRevision,
    Map<GlossNameCategory, Map<String, String>>? categories,
    Map<String, Object?>? extras,
  }) : categories =
           categories ??
           <GlossNameCategory, Map<String, String>>{
             for (final GlossNameCategory category in GlossNameCategory.values)
               category: category == GlossNameCategory.materials
                   ? Map<String, String>.of(glossDefaultMaterialNames)
                   : category == GlossNameCategory.dimensions
                   ? Map<String, String>.of(glossDefaultDimensionNames)
                   : <String, String>{},
           },
       extras = extras ?? <String, Object?>{};

  final Map<GlossNameCategory, Map<String, String>> categories;
  final Map<String, Object?> extras;

  GlossNamesCatalog get catalog => GlossNamesCatalog(
    categories: <GlossNameCategory, Map<String, String>>{
      for (final MapEntry<GlossNameCategory, Map<String, String>> category
          in categories.entries)
        category.key: <String, String>{
          for (final MapEntry<String, String> entry in category.value.entries)
            category.key.normalize(entry.key): entry.value,
        },
    },
  );

  static GlossNamesDoc fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'names');
    return GlossNamesDoc(
      revision: glossReadRevision(map),
      categories: <GlossNameCategory, Map<String, String>>{
        for (final GlossNameCategory category in GlossNameCategory.values)
          if (map.containsKey(category.name))
            category: readNames(map[category.name], '\$.${category.name}'),
      },
      extras: huiCollectExtras(map, <String>{
        'schemaVersion',
        'revision',
        ...GlossNameCategory.values.map(
          (GlossNameCategory category) => category.name,
        ),
      }),
    );
  }

  static Map<String, String> readNames(Object? raw, String path) {
    final Map<String, Object?> entries = huiReadObject(raw, path);
    final Map<String, String> result = <String, String>{};
    for (final MapEntry<String, Object?> entry in entries.entries) {
      final Object? value = entry.value;
      if (value is! String) {
        throw HuiFormatException(
          'Expected a JSON string',
          '$path.${entry.key}',
        );
      }
      result[entry.key] = value;
    }
    return result;
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...huiDeepCopyMap(extras),
    'schemaVersion': schemaVersion,
    'revision': revision,
    for (final MapEntry<GlossNameCategory, Map<String, String>> entry
        in categories.entries)
      entry.key.name: Map<String, String>.of(entry.value),
  };

  GlossNamesDoc copy() => GlossNamesDoc.fromJson(toJson());
}

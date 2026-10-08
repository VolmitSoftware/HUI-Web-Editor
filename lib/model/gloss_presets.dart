import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

bool looksLikePresetsDoc(Object? value) =>
    value is Map &&
    value['schemaVersion'] is num &&
    (value.containsKey('defaults') || value.containsKey('presets'));

GlossPresetsDoc decodeGlossPresetsDoc(String source) =>
    GlossPresetsDoc.fromJson(jsonDecode(source));

String encodeGlossPresetsDoc(GlossPresetsDoc doc) => huiWriteJson(doc.toJson());

final class GlossPresetsDoc extends GlossDoc {
  GlossPresetsDoc({
    super.schemaVersion = 1,
    super.revision = glossInitialRevision,
    Map<String, Object?>? defaults,
    Map<String, Object?>? presets,
    Map<String, Object?>? extras,
  }) : defaults = defaults ?? <String, Object?>{},
       presets = presets ?? <String, Object?>{},
       extras = extras ?? <String, Object?>{};

  final Map<String, Object?> defaults;
  final Map<String, Object?> presets;
  final Map<String, Object?> extras;

  static GlossPresetsDoc fromJson(Object? value) {
    final Map<String, Object?> root = huiReadObject(value, r'$');
    final int version = glossReadSchemaVersion(root, 'presets');
    return GlossPresetsDoc(
      schemaVersion: version,
      revision: glossReadRevision(root),
      defaults: huiDeepCopyMap(huiReadObject(root['defaults'], r'$.defaults')),
      presets: huiDeepCopyMap(huiReadObject(root['presets'], r'$.presets')),
      extras: huiCollectExtras(root, const <String>{
        'schemaVersion',
        'revision',
        'defaults',
        'presets',
      }),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...huiDeepCopyMap(extras),
    'schemaVersion': schemaVersion,
    'revision': revision,
    'defaults': huiDeepCopyMap(defaults),
    'presets': huiDeepCopyMap(presets),
  };
}

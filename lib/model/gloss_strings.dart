import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

bool looksLikeStringsDoc(Object? raw) =>
    raw is Map &&
    raw['schemaVersion'] is num &&
    raw['locale'] is String &&
    (raw['entries'] == null || raw['entries'] is Map);

GlossStringsDoc decodeGlossStringsDoc(String source) =>
    GlossStringsDoc.fromJson(jsonDecode(source));
String encodeGlossStringsDoc(GlossStringsDoc doc) => huiWriteJson(doc.toJson());

final class GlossStringsDoc extends GlossDoc {
  GlossStringsDoc({
    super.schemaVersion = 1,
    super.revision = glossInitialRevision,
    this.locale = 'en_US',
    this.fallback = '',
    Map<String, String>? entries,
    Map<String, Object?>? extras,
  }) : entries = entries ?? <String, String>{},
       extras = extras ?? <String, Object?>{};

  String locale;
  String fallback;
  Map<String, String> entries;
  final Map<String, Object?> extras;

  static GlossStringsDoc fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'strings');
    final Map<String, Object?> values = map['entries'] == null
        ? <String, Object?>{}
        : huiReadObject(map['entries'], r'$.entries');
    final Map<String, String> entries = <String, String>{};
    for (final MapEntry<String, Object?> entry in values.entries) {
      if (entry.value is! String) {
        throw HuiFormatException(
          'Expected a JSON string',
          '\$.entries.${entry.key}',
        );
      }
      entries[entry.key] = entry.value as String;
    }
    return GlossStringsDoc(
      revision: glossReadRevision(map),
      locale: huiReadString(map, 'locale'),
      fallback: huiReadString(map, 'fallback'),
      entries: entries,
      extras: huiCollectExtras(map, const <String>{
        'schemaVersion',
        'revision',
        'locale',
        'fallback',
        'entries',
      }),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...huiDeepCopyMap(extras),
    'schemaVersion': schemaVersion,
    'revision': revision,
    'locale': locale,
    'fallback': fallback,
    'entries': Map<String, String>.of(entries),
  };
}

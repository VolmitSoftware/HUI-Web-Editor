/// Mirror of Gloss `TablistDoc.java` — the tab-screen document:
///
/// ```json
/// {
///   "schemaVersion": 1,
///   "revision": 1,
///   "useHeaderFooter": true,
///   "header": "&d&lGloss",
///   "footer": "&7VolmitSoftware.com",
///   "groupListNames": true,
///   "nameFormats": {
///     "default": "$player",
///     "_op": "&6$player"
///   }
/// }
/// ```
///
/// The plugin keeps exactly one file (`plugins/Gloss/tablist.json`). Null
/// header/footer become `""`; `nameFormats` keys are trimmed, lowercased and
/// blank keys dropped SILENTLY on load (`TablistDoc.copyFormats`) — the
/// editor preserves what was written and exposes [effectiveNameFormats].
/// `_op` and `default` are reserved keys (`OP_GROUP_KEY`,
/// `DEFAULT_GROUP_KEY`), and the resolution order lives in
/// `logic/tablist_selection.dart`.
library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

/// `TablistDoc.OP_GROUP_KEY` — the format operators get first.
const String glossTablistOpGroupKey = '_op';

/// `TablistDoc.DEFAULT_GROUP_KEY` — the fallback format key.
const String glossTablistDefaultGroupKey = 'default';

/// `TablistDoc.FALLBACK_FORMAT` — used when not even `default` exists.
const String glossTablistFallbackFormat = r'$player';

/// True when [json] has the shape of a Gloss tablist document: the versioned
/// envelope plus tab keys no other kind carries. Routing only — full
/// checking is `validateTablistDoc`'s job.
bool looksLikeTablistDoc(Object? json) {
  if (json is! Map) return false;
  if (json['schemaVersion'] is! num) return false;
  if (json.containsKey('anchor') ||
      json.containsKey('frames') ||
      json.containsKey('entries') ||
      json.containsKey('emoji') ||
      json.containsKey('components') ||
      json.containsKey('elements')) {
    return false;
  }
  return json.containsKey('useHeaderFooter') ||
      json.containsKey('nameFormats') ||
      json.containsKey('groupListNames') ||
      (json.containsKey('header') && json.containsKey('footer'));
}

GlossTablistDoc decodeGlossTablistDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    throw HuiFormatException('Invalid JSON: ${e.message}', r'$');
  }
  return GlossTablistDoc.fromJson(raw);
}

String encodeGlossTablistDoc(GlossTablistDoc doc) => huiWriteJson(doc.toJson());

GlossTablistDoc cloneGlossTablistDoc(GlossTablistDoc doc) =>
    GlossTablistDoc.fromJson(huiDeepCopy(doc.toJson()));

const Set<String> _docKnown = <String>{
  'schemaVersion',
  'revision',
  'useHeaderFooter',
  'header',
  'footer',
  'groupListNames',
  'nameFormats',
};

final class GlossTablistDoc extends GlossDoc {
  GlossTablistDoc({
    super.schemaVersion = glossCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    this.useHeaderFooter = false,
    this.header = '',
    this.footer = '',
    this.groupListNames = false,
    Map<String, String>? nameFormats,
    Map<String, dynamic>? extras,
    Set<String>? absentKeys,
  }) : nameFormats = nameFormats ?? <String, String>{},
       extras = extras ?? <String, dynamic>{},
       absentKeys = absentKeys ?? <String>{};

  /// When false the plugin clears any header/footer it applied and leaves
  /// the tab screen alone.
  bool useHeaderFooter;

  /// Rendered through the text pipeline per viewer, per update tick.
  String header;
  String footer;

  /// When false list names reset to vanilla and [nameFormats] goes unused.
  bool groupListNames;

  /// As written, insertion-ordered; see [effectiveNameFormats].
  Map<String, String> nameFormats;

  Map<String, dynamic> extras;
  Set<String> absentKeys;

  /// `TablistDoc.copyFormats`: keys trimmed and lowercased, blank keys
  /// dropped, null values `""`, later duplicates overwriting earlier ones in
  /// first-seen position (LinkedHashMap semantics).
  Map<String, String> get effectiveNameFormats {
    final Map<String, String> out = <String, String>{};
    for (final MapEntry<String, String> entry in nameFormats.entries) {
      final String key = entry.key.trim().toLowerCase();
      if (key.isEmpty) continue;
      out[key] = entry.value;
    }
    return out;
  }

  static GlossTablistDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'tablist');
    final Object? formats = map['nameFormats'];
    return GlossTablistDoc(
      schemaVersion: glossCurrentSchemaVersion,
      revision: glossReadRevision(map),
      useHeaderFooter: huiReadBool(map, 'useHeaderFooter'),
      header: huiReadString(map, 'header'),
      footer: huiReadString(map, 'footer'),
      groupListNames: huiReadBool(map, 'groupListNames'),
      nameFormats: <String, String>{
        if (formats is Map)
          for (final MapEntry<Object?, Object?> entry in formats.entries)
            entry.key.toString(): entry.value == null
                ? ''
                : entry.value is String
                ? entry.value! as String
                : entry.value.toString(),
      },
      extras: huiCollectExtras(map, _docKnown),
      absentKeys: <String>{
        if (map['revision'] == null) 'revision',
        if (map['useHeaderFooter'] == null) 'useHeaderFooter',
        if (map['header'] == null) 'header',
        if (map['footer'] == null) 'footer',
        if (map['groupListNames'] == null) 'groupListNames',
        if (map['nameFormats'] == null) 'nameFormats',
      },
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{
      'schemaVersion': schemaVersion,
      if (!absentKeys.contains('revision')) 'revision': revision,
      if (!absentKeys.contains('useHeaderFooter') || useHeaderFooter)
        'useHeaderFooter': useHeaderFooter,
      if (!absentKeys.contains('header') || header.isNotEmpty)
        'header': header,
      if (!absentKeys.contains('footer') || footer.isNotEmpty)
        'footer': footer,
      if (!absentKeys.contains('groupListNames') || groupListNames)
        'groupListNames': groupListNames,
      if (!absentKeys.contains('nameFormats') || nameFormats.isNotEmpty)
        'nameFormats': Map<String, String>.of(nameFormats),
    };
    return huiMergeExtras(out, extras);
  }

  GlossTablistDoc copy() => GlossTablistDoc(
    schemaVersion: schemaVersion,
    revision: revision,
    useHeaderFooter: useHeaderFooter,
    header: header,
    footer: footer,
    groupListNames: groupListNames,
    nameFormats: Map<String, String>.of(nameFormats),
    extras: huiDeepCopyMap(extras),
    absentKeys: Set<String>.of(absentKeys),
  );
}

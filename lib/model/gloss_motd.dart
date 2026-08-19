/// Mirror of Gloss `MotdDoc.java` — the server-list MOTD document:
///
/// ```json
/// {
///   "schemaVersion": 1,
///   "revision": 1,
///   "entries": [
///     {"lines": ["&dA glossy server"]}
///   ]
/// }
/// ```
///
/// The plugin keeps exactly one file (`plugins/Gloss/motd.json`) and picks a
/// random entry per server-list ping (`MotdService.handlePing`), rendering the
/// joined lines through `renderStatic` — text functions and colours apply, but
/// PlaceholderAPI tokens stay literal because a ping has no viewer. The Java
/// record rejects a document without entries and an entry whose line count is
/// outside 1..`MAX_LINES_PER_ENTRY` (`MotdDoc.java:20-37`); this model decodes
/// both leniently and leaves the rejection report to `validateMotdDoc`, per
/// the shared envelope rule in `gloss_doc.dart`.
library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

/// `MotdDoc.MAX_LINES_PER_ENTRY` — the server list shows at most two lines.
const int glossMotdMaxLinesPerEntry = 2;

/// True when [json] has the shape of a Gloss MOTD document: the versioned
/// envelope plus the `entries` list no other kind carries. Routing only —
/// full checking is `validateMotdDoc`'s job.
bool looksLikeMotdDoc(Object? json) {
  if (json is! Map) return false;
  return json['schemaVersion'] is num &&
      json.containsKey('entries') &&
      !json.containsKey('anchor') &&
      !json.containsKey('frames') &&
      !json.containsKey('components') &&
      !json.containsKey('elements');
}

GlossMotdDoc decodeGlossMotdDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    throw HuiFormatException('Invalid JSON: ${e.message}', r'$');
  }
  return GlossMotdDoc.fromJson(raw);
}

String encodeGlossMotdDoc(GlossMotdDoc doc) => huiWriteJson(doc.toJson());

GlossMotdDoc cloneGlossMotdDoc(GlossMotdDoc doc) =>
    GlossMotdDoc.fromJson(huiDeepCopy(doc.toJson()));

const Set<String> _docKnown = <String>{'schemaVersion', 'revision', 'entries'};

const Set<String> _entryKnown = <String>{'lines'};

/// One MOTD candidate: 1..2 lines shown together in the server list.
/// Mirrors `MotdDoc.MotdEntry`, which maps a null line to `""` rather than
/// dropping it — [glossReadStringList] does the same.
final class GlossMotdEntry {
  GlossMotdEntry({List<String>? lines, Map<String, dynamic>? extras})
    : lines = lines ?? <String>[],
      extras = extras ?? <String, dynamic>{};

  List<String> lines;
  Map<String, dynamic> extras;

  /// `MotdEntry.joined` — what one ping actually renders.
  String get joined => lines.join('\n');

  static GlossMotdEntry fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossMotdEntry(
      lines: glossReadStringList(map['lines']),
      extras: huiCollectExtras(map, _entryKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'lines': List<String>.of(lines),
  }, extras);

  GlossMotdEntry copy() => GlossMotdEntry(
    lines: List<String>.of(lines),
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossMotdDoc extends GlossDoc {
  GlossMotdDoc({
    super.schemaVersion = glossCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    List<GlossMotdEntry>? entries,
    Map<String, dynamic>? extras,
    Set<String>? absentKeys,
  }) : entries = entries ?? <GlossMotdEntry>[],
       extras = extras ?? <String, dynamic>{},
       absentKeys = absentKeys ?? <String>{};

  /// The random-pick pool. The plugin requires at least one entry
  /// (`MotdDoc.java:20-23`); an empty list here is a validation error, not a
  /// decode failure.
  List<GlossMotdEntry> entries;

  Map<String, dynamic> extras;
  Set<String> absentKeys;

  static GlossMotdDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'motd');
    return GlossMotdDoc(
      schemaVersion: glossCurrentSchemaVersion,
      revision: glossReadRevision(map),
      entries: <GlossMotdEntry>[
        for (final (int index, Object? entry)
            in huiReadList(map['entries']).indexed)
          GlossMotdEntry.fromJson(entry, 'entries[$index]'),
      ],
      extras: huiCollectExtras(map, _docKnown),
      absentKeys: <String>{
        if (map['revision'] == null) 'revision',
        if (map['entries'] == null) 'entries',
      },
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{
      'schemaVersion': schemaVersion,
      if (!absentKeys.contains('revision')) 'revision': revision,
      if (!absentKeys.contains('entries') || entries.isNotEmpty)
        'entries': <Map<String, dynamic>>[
          for (final GlossMotdEntry entry in entries) entry.toJson(),
        ],
    };
    return huiMergeExtras(out, extras);
  }

  GlossMotdDoc copy() => GlossMotdDoc(
    schemaVersion: schemaVersion,
    revision: revision,
    entries: <GlossMotdEntry>[
      for (final GlossMotdEntry entry in entries) entry.copy(),
    ],
    extras: huiDeepCopyMap(extras),
    absentKeys: Set<String>.of(absentKeys),
  );
}

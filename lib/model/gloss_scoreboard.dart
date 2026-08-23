/// Mirror of Gloss `BoardDoc.java` — the sidebar scoreboard document (kind
/// slug `scoreboard`; distinct from the editor's world-panel kind):
///
/// ```json
/// {
///   "schemaVersion": 1,
///   "revision": 1,
///   "title": "&d&lGloss",
///   "lines": ["&fWelcome!"],
///   "primary": false,
///   "hideNumbers": false,
///   "permission": "default",
///   "groups": []
/// }
/// ```
///
/// The Java record normalizes silently rather than rejecting: a null title
/// becomes `""`, the permission is trimmed/lowercased with `""` mapping to
/// `default` (`BoardDoc.normalizePermission`), and groups are trimmed,
/// lowercased, blank-dropped and deduplicated (`BoardDoc.normalizeGroups`).
/// The editor preserves what was written and exposes the effective forms as
/// derived accessors, so validation can say what the server will actually
/// use without rewriting the author's file.
library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

/// `GlossBoardMeta.UNRESTRICTED_PERMISSION`.
const String glossBoardUnrestrictedPermission = 'default';

/// `GlossBoardMeta.PERMISSION_NODE_PREFIX`.
const String glossBoardPermissionNodePrefix = 'gloss.board.';

/// `BoardService.MAX_LINES` — lines past this render never reach the client.
const int glossBoardMaxLines = 15;

/// The VolmLib board driver's rendered-title cap, colour codes included.
const int glossBoardMaxTitleLength = 32;

int glossBoardScoreForRow(int index) => glossBoardMaxLines - index;

/// True when [json] has the shape of a Gloss scoreboard document: the
/// versioned envelope, board keys, and none of the other kinds' markers.
bool looksLikeScoreboardDoc(Object? json) {
  if (json is! Map) return false;
  if (json['schemaVersion'] is! num) return false;
  if (json.containsKey('anchor') ||
      json.containsKey('frames') ||
      json.containsKey('components') ||
      json.containsKey('elements')) {
    return false;
  }
  return json.containsKey('title') ||
      json.containsKey('primary') ||
      json.containsKey('permission') ||
      json.containsKey('groups');
}

GlossScoreboardDoc decodeGlossScoreboardDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': e.message,
    });
  }
  return GlossScoreboardDoc.fromJson(raw);
}

String encodeGlossScoreboardDoc(GlossScoreboardDoc doc) =>
    huiWriteJson(doc.toJson());

GlossScoreboardDoc cloneGlossScoreboardDoc(GlossScoreboardDoc doc) =>
    GlossScoreboardDoc.fromJson(huiDeepCopy(doc.toJson()));

const Set<String> _docKnown = <String>{
  'schemaVersion',
  'revision',
  'title',
  'lines',
  'primary',
  'hideNumbers',
  'permission',
  'groups',
};

final class GlossScoreboardDoc extends GlossDoc {
  GlossScoreboardDoc({
    super.schemaVersion = glossCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    this.title = '',
    List<String>? lines,
    this.primary = false,
    this.hideNumbers = false,
    this.permission = glossBoardUnrestrictedPermission,
    List<String>? groups,
    Map<String, dynamic>? extras,
    Set<String>? absentKeys,
  }) : lines = lines ?? <String>[],
       groups = groups ?? <String>[],
       extras = extras ?? <String, dynamic>{},
       absentKeys = absentKeys ?? <String>{};

  String title;

  /// Sidebar lines, top first. Gloss renders at most [glossBoardMaxLines].
  List<String> lines;

  /// Whether this board volunteers as the default selection for players no
  /// group or permission steers elsewhere.
  bool primary;

  /// Uses Minecraft's blank score number format on 1.20.3+ clients.
  bool hideNumbers;

  /// As written; [effectivePermission] is what the server runs.
  String permission;

  /// As written; [effectiveGroups] is what the server runs.
  List<String> groups;

  Map<String, dynamic> extras;
  Set<String> absentKeys;

  /// `GlossBoardMeta.fromDoc` (GlossBoardMeta.java:40): an empty title falls
  /// back to the board id, so a blank `title` shows the file name in game
  /// rather than an empty sidebar header. The test is `String.isEmpty`, not a
  /// trim — a title of one space stays one space.
  String effectiveTitle(String boardId) => title.isEmpty ? boardId : title;

  /// `BoardDoc.normalizePermission`: trimmed, lowercased, empty maps to
  /// `default` (unrestricted).
  String get effectivePermission {
    final String normalized = permission.trim().toLowerCase();
    return normalized.isEmpty ? glossBoardUnrestrictedPermission : normalized;
  }

  /// Whether [effectivePermission] gates the board behind
  /// `gloss.board.<permission>` (`GlossBoardMeta.permissionGated`).
  bool get permissionGated =>
      effectivePermission != glossBoardUnrestrictedPermission;

  /// `BoardDoc.normalizeGroups`: trimmed, lowercased, blanks dropped,
  /// duplicates removed in first-seen order.
  List<String> get effectiveGroups {
    final List<String> out = <String>[];
    for (final String group in groups) {
      final String normalized = group.trim().toLowerCase();
      if (normalized.isEmpty || out.contains(normalized)) continue;
      out.add(normalized);
    }
    return out;
  }

  static GlossScoreboardDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'scoreboard');
    return GlossScoreboardDoc(
      schemaVersion: glossCurrentSchemaVersion,
      revision: glossReadRevision(map),
      title: huiReadString(map, 'title'),
      lines: glossReadStringList(map['lines']),
      primary: huiReadBool(map, 'primary'),
      hideNumbers: huiReadBool(map, 'hideNumbers'),
      permission: huiReadString(map, 'permission'),
      groups: glossReadStringList(map['groups']),
      extras: huiCollectExtras(map, _docKnown),
      absentKeys: <String>{
        if (map['revision'] == null) 'revision',
        if (map['title'] == null) 'title',
        if (map['lines'] == null) 'lines',
        if (map['primary'] == null) 'primary',
        if (map['hideNumbers'] == null) 'hideNumbers',
        if (map['permission'] == null) 'permission',
        if (map['groups'] == null) 'groups',
      },
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{
      'schemaVersion': schemaVersion,
      if (!absentKeys.contains('revision')) 'revision': revision,
      if (!absentKeys.contains('title') || title.isNotEmpty) 'title': title,
      if (!absentKeys.contains('lines') || lines.isNotEmpty)
        'lines': List<String>.of(lines),
      if (!absentKeys.contains('primary') || primary) 'primary': primary,
      if (!absentKeys.contains('hideNumbers') || hideNumbers)
        'hideNumbers': hideNumbers,
      if (!absentKeys.contains('permission') || permission.isNotEmpty)
        'permission': permission,
      if (!absentKeys.contains('groups') || groups.isNotEmpty)
        'groups': List<String>.of(groups),
    };
    return huiMergeExtras(out, extras);
  }

  GlossScoreboardDoc copy() => GlossScoreboardDoc(
    schemaVersion: schemaVersion,
    revision: revision,
    title: title,
    lines: List<String>.of(lines),
    primary: primary,
    hideNumbers: hideNumbers,
    permission: permission,
    groups: List<String>.of(groups),
    extras: huiDeepCopyMap(extras),
    absentKeys: Set<String>.of(absentKeys),
  );
}

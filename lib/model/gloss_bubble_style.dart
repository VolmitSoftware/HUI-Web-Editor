/// Mirror of Gloss `BubbleStyleDoc.java` — one chat-bubble style per file:
///
/// ```json
/// {
///   "schemaVersion": 1,
///   "revision": 1,
///   "prefix": "&7",
///   "offset": [0.0, 1.0, 0.0],
///   "wordWrapChars": 32,
///   "lineStaggerTicks": 5,
///   "maxAliveMs": 5000,
///   "flyAway": true,
///   "followPlayer": true,
///   "hideOwn": true,
///   "select": {"worlds": ["world*"], "groups": ["vip"], "priority": 10}
/// }
/// ```
///
/// The document id is the file path under `plugins/Gloss/bubbles/`. The Java
/// record fixes almost everything SILENTLY (`BubbleStyleDoc.java:21-28`): a
/// null prefix becomes `&7`, a null offset becomes `(0, 1, 0)`,
/// `wordWrapChars` clamps into 8..128, `lineStaggerTicks` into 0..40 and
/// `maxAliveMs` into 500..60000 — the editor preserves what was written and
/// exposes the effective forms, so validation can warn with the value the
/// server will actually run. `select` is genuinely optional (null skips
/// auto-matching entirely, `BubbleStyles.resolveStyleId`); its `worlds` are
/// trimmed with blanks dropped, its `groups` additionally lowercased
/// (`Select.cleanStrings`). The offset itself parses through the strict
/// `[x, y, z]` Vector adapter — a present-but-malformed one kills the file,
/// exactly like a hologram anchor position.
library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

/// `BubbleStyleDoc` clamp bounds.
const int glossBubbleMinWordWrapChars = 8;
const int glossBubbleMaxWordWrapChars = 128;
const int glossBubbleMinLineStaggerTicks = 0;
const int glossBubbleMaxLineStaggerTicks = 40;
const int glossBubbleMinMaxAliveMs = 500;
const int glossBubbleMaxMaxAliveMs = 60000;

/// `BubbleStyleDoc.DEFAULTS` prefix, applied when the file carries none.
const String glossBubbleDefaultPrefix = '&7';

/// `BubbleStyles.DEFAULT_STYLE_ID` — the fallback style when nothing
/// matches; `BubbleStyles.STYLE_PERMISSION_PREFIX` gates explicit choices.
const String glossBubbleDefaultStyleId = 'default';
const String glossBubbleStylePermissionPrefix = 'gloss.bubbles.style.';

/// True when [json] has the shape of a Gloss bubble style: the versioned
/// envelope plus bubble keys no other kind carries. Routing only — full
/// checking is `validateBubbleStyleDoc`'s job.
bool looksLikeBubbleStyleDoc(Object? json) {
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
  return json.containsKey('wordWrapChars') ||
      json.containsKey('maxAliveMs') ||
      json.containsKey('lineStaggerTicks') ||
      json.containsKey('flyAway') ||
      json.containsKey('followPlayer') ||
      json.containsKey('hideOwn');
}

GlossBubbleStyleDoc decodeGlossBubbleStyleDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    throw HuiFormatException('Invalid JSON: ${e.message}', r'$');
  }
  return GlossBubbleStyleDoc.fromJson(raw);
}

String encodeGlossBubbleStyleDoc(GlossBubbleStyleDoc doc) =>
    huiWriteJson(doc.toJson());

GlossBubbleStyleDoc cloneGlossBubbleStyleDoc(GlossBubbleStyleDoc doc) =>
    GlossBubbleStyleDoc.fromJson(huiDeepCopy(doc.toJson()));

const Set<String> _docKnown = <String>{
  'schemaVersion',
  'revision',
  'prefix',
  'offset',
  'wordWrapChars',
  'lineStaggerTicks',
  'maxAliveMs',
  'flyAway',
  'followPlayer',
  'hideOwn',
  'select',
};

const Set<String> _selectKnown = <String>{'worlds', 'groups', 'priority'};

/// `BubbleStyleDoc.Select` — the auto-match rule. A style without one never
/// auto-matches and is only reachable by explicit player choice (or as the
/// `default` fallback).
final class GlossBubbleSelect {
  GlossBubbleSelect({
    List<String>? worlds,
    List<String>? groups,
    this.priority = 0,
    Map<String, dynamic>? extras,
    Set<String>? absentKeys,
  }) : worlds = worlds ?? <String>[],
       groups = groups ?? <String>[],
       extras = extras ?? <String, dynamic>{},
       absentKeys = absentKeys ?? <String>{};

  /// World-name globs (`*`/`?`), as written; see [effectiveWorlds].
  List<String> worlds;

  /// Vault group names, as written; see [effectiveGroups].
  List<String> groups;

  /// Highest matching priority wins; ties break to the lexicographically
  /// smaller style id (`BubbleStyles.resolveStyleId`).
  int priority;

  Map<String, dynamic> extras;
  Set<String> absentKeys;

  /// `Select.cleanStrings(worlds, false)`: trimmed, blanks dropped, case
  /// kept.
  List<String> get effectiveWorlds => <String>[
    for (final String world in worlds)
      if (world.trim().isNotEmpty) world.trim(),
  ];

  /// `Select.cleanStrings(groups, true)`: trimmed, blanks dropped,
  /// lowercased.
  List<String> get effectiveGroups => <String>[
    for (final String group in groups)
      if (group.trim().isNotEmpty) group.trim().toLowerCase(),
  ];

  static GlossBubbleSelect fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$.select');
    return GlossBubbleSelect(
      worlds: glossReadStringList(map['worlds']),
      groups: glossReadStringList(map['groups']),
      priority: huiReadInt(map, 'priority'),
      extras: huiCollectExtras(map, _selectKnown),
      absentKeys: <String>{
        if (map['worlds'] == null) 'worlds',
        if (map['groups'] == null) 'groups',
        if (map['priority'] == null) 'priority',
      },
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    if (!absentKeys.contains('worlds') || worlds.isNotEmpty)
      'worlds': List<String>.of(worlds),
    if (!absentKeys.contains('groups') || groups.isNotEmpty)
      'groups': List<String>.of(groups),
    if (!absentKeys.contains('priority') || priority != 0)
      'priority': priority,
  }, extras);

  GlossBubbleSelect copy() => GlossBubbleSelect(
    worlds: List<String>.of(worlds),
    groups: List<String>.of(groups),
    priority: priority,
    extras: huiDeepCopyMap(extras),
    absentKeys: Set<String>.of(absentKeys),
  );
}

final class GlossBubbleStyleDoc extends GlossDoc {
  GlossBubbleStyleDoc({
    super.schemaVersion = glossCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    this.prefix = '',
    this.offsetRaw,
    this.wordWrapChars = 0,
    this.lineStaggerTicks = 0,
    this.maxAliveMs = 0,
    this.flyAway = false,
    this.followPlayer = false,
    this.hideOwn = false,
    this.select,
    Map<String, dynamic>? extras,
    Set<String>? absentKeys,
  }) : extras = extras ?? <String, dynamic>{},
       absentKeys = absentKeys ?? <String>{};

  /// Colour prefix prepended to every bubble line, as written. Only a
  /// MISSING key falls to `&7` — an explicit `""` stays empty
  /// (`prefix == null` is the Java guard).
  String prefix;

  /// Whatever JSON value the `offset` slot carried, re-emitted verbatim.
  /// Null when the key was absent (the plugin then uses `(0, 1, 0)`).
  Object? offsetRaw;

  /// As written; see the `effective*` getters for the silent clamps.
  int wordWrapChars;
  int lineStaggerTicks;
  int maxAliveMs;

  bool flyAway;
  bool followPlayer;
  bool hideOwn;

  /// Null when the file has no `select` — the style never auto-matches.
  GlossBubbleSelect? select;

  Map<String, dynamic> extras;
  Set<String> absentKeys;

  /// The prefix the server runs: the written one, or `&7` when the key was
  /// absent.
  String get effectivePrefix =>
      absentKeys.contains('prefix') ? glossBubbleDefaultPrefix : prefix;

  /// The offset as a length-3 triple: the written numbers, or the plugin's
  /// `(0, 1, 0)` default when the key was absent. Zero-padded when the raw
  /// shape is not a triple — the renderable reading, never a replacement.
  List<double> get offset {
    final Object? raw = offsetRaw;
    if (raw == null) return const <double>[0, 1, 0];
    final List<Object?> entries = raw is List ? raw : const <Object?>[];
    return List<double>.generate(3, (int axis) {
      if (axis >= entries.length) return 0;
      final Object? value = entries[axis];
      final double parsed = value is num
          ? value.toDouble()
          : value is String
          ? double.tryParse(value) ?? 0
          : 0;
      return parsed.isFinite ? parsed : 0;
    });
  }

  /// True when [offsetRaw] would pass the strict vector adapter: absent, or
  /// exactly three finite numbers.
  bool get offsetIsValidTriple {
    final Object? raw = offsetRaw;
    if (raw == null) return true;
    if (raw is! List || raw.length != 3) return false;
    for (final Object? value in raw) {
      if (value is! num || !value.toDouble().isFinite) return false;
    }
    return true;
  }

  void setOffset(double x, double y, double z) {
    offsetRaw = <num>[x, y, z];
    absentKeys.remove('offset');
  }

  int get effectiveWordWrapChars => wordWrapChars.clamp(
    glossBubbleMinWordWrapChars,
    glossBubbleMaxWordWrapChars,
  );

  int get effectiveLineStaggerTicks => lineStaggerTicks.clamp(
    glossBubbleMinLineStaggerTicks,
    glossBubbleMaxLineStaggerTicks,
  );

  int get effectiveMaxAliveMs =>
      maxAliveMs.clamp(glossBubbleMinMaxAliveMs, glossBubbleMaxMaxAliveMs);

  static GlossBubbleStyleDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'bubbles');
    return GlossBubbleStyleDoc(
      schemaVersion: glossCurrentSchemaVersion,
      revision: glossReadRevision(map),
      prefix: huiReadString(map, 'prefix'),
      offsetRaw: huiDeepCopy(map['offset']),
      wordWrapChars: huiReadInt(map, 'wordWrapChars'),
      lineStaggerTicks: huiReadInt(map, 'lineStaggerTicks'),
      maxAliveMs: huiReadInt(map, 'maxAliveMs'),
      flyAway: huiReadBool(map, 'flyAway'),
      followPlayer: huiReadBool(map, 'followPlayer'),
      hideOwn: huiReadBool(map, 'hideOwn'),
      select: map['select'] == null
          ? null
          : GlossBubbleSelect.fromJson(map['select']),
      extras: huiCollectExtras(map, _docKnown),
      absentKeys: <String>{
        if (map['revision'] == null) 'revision',
        if (map['prefix'] == null) 'prefix',
        if (map['offset'] == null) 'offset',
        if (map['wordWrapChars'] == null) 'wordWrapChars',
        if (map['lineStaggerTicks'] == null) 'lineStaggerTicks',
        if (map['maxAliveMs'] == null) 'maxAliveMs',
        if (map['flyAway'] == null) 'flyAway',
        if (map['followPlayer'] == null) 'followPlayer',
        if (map['hideOwn'] == null) 'hideOwn',
      },
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{
      'schemaVersion': schemaVersion,
      if (!absentKeys.contains('revision')) 'revision': revision,
      if (!absentKeys.contains('prefix') || prefix.isNotEmpty)
        'prefix': prefix,
      if (offsetRaw != null) 'offset': huiDeepCopy(offsetRaw),
      if (!absentKeys.contains('wordWrapChars') || wordWrapChars != 0)
        'wordWrapChars': wordWrapChars,
      if (!absentKeys.contains('lineStaggerTicks') || lineStaggerTicks != 0)
        'lineStaggerTicks': lineStaggerTicks,
      if (!absentKeys.contains('maxAliveMs') || maxAliveMs != 0)
        'maxAliveMs': maxAliveMs,
      if (!absentKeys.contains('flyAway') || flyAway) 'flyAway': flyAway,
      if (!absentKeys.contains('followPlayer') || followPlayer)
        'followPlayer': followPlayer,
      if (!absentKeys.contains('hideOwn') || hideOwn) 'hideOwn': hideOwn,
      if (select != null) 'select': select!.toJson(),
    };
    return huiMergeExtras(out, extras);
  }

  GlossBubbleStyleDoc copy() => GlossBubbleStyleDoc(
    schemaVersion: schemaVersion,
    revision: revision,
    prefix: prefix,
    offsetRaw: huiDeepCopy(offsetRaw),
    wordWrapChars: wordWrapChars,
    lineStaggerTicks: lineStaggerTicks,
    maxAliveMs: maxAliveMs,
    flyAway: flyAway,
    followPlayer: followPlayer,
    hideOwn: hideOwn,
    select: select?.copy(),
    extras: huiDeepCopyMap(extras),
    absentKeys: Set<String>.of(absentKeys),
  );
}

/// `BubbleStyles.globMatches`: `*` and `?` wildcards, everything else
/// literal, anchored over the whole value.
bool glossBubbleGlobMatches(String pattern, String value) {
  final StringBuffer regex = StringBuffer('^');
  final StringBuffer literal = StringBuffer();
  void flushLiteral() {
    if (literal.isEmpty) return;
    regex.write(RegExp.escape(literal.toString()));
    literal.clear();
  }

  for (int i = 0; i < pattern.length; i++) {
    final String current = pattern[i];
    if (current == '*' || current == '?') {
      flushLiteral();
      regex.write(current == '*' ? '.*' : '.');
      continue;
    }
    literal.write(current);
  }
  flushLiteral();
  regex.write(r'$');
  // No dotAll: Java's Pattern leaves `.` blind to line terminators too.
  return RegExp(regex.toString()).hasMatch(value);
}

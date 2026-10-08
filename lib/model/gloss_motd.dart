/// Mirror of Gloss `MotdDoc.java` — the server-list MOTD document:
///
/// ```json
/// {
///   "schemaVersion": 1,
///   "revision": 1,
///   "favicon": "server.png",
///   "entries": [
///     {"lines": ["&dA glossy server"], "favicon": "event.png"}
///   ],
///   "links": [
///     {"type": "website", "url": "https://example.net"}
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
///
/// `links` is the pause-menu server-link list (`MotdDoc.MotdLink`), published
/// once per document revision rather than per ping
/// (`MotdService.publishLinks`). The per-entry `sample`, `online`, `max` and
/// `version` are the rest of the ping: `MotdService.applyExtras` sends them
/// through Paper's ping event, except `max`, which is plain Bukkit.
library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

/// `MotdDoc.MAX_LINES_PER_ENTRY` — the server list shows at most two lines.
const int glossMotdMaxLinesPerEntry = 2;

/// `MotdDoc.MAX_SAMPLE_LINES` — the hover list under the player count.
const int glossMotdMaxSampleLines = 12;

/// `MotdDoc.MAX_LINKS` — the pause menu takes no more than this many.
const int glossMotdMaxLinks = 16;

/// `MotdDoc.LINK_TYPES` — the link kinds the client already has a label for.
/// The Java set is unordered; this list fixes the order the editor offers
/// them in, which is the order the Java source declares.
const List<String> glossMotdLinkTypes = <String>[
  'report_bug',
  'community_guidelines',
  'support',
  'status',
  'feedback',
  'community',
  'website',
  'forums',
  'news',
  'announcements',
];

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
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': e.message,
    });
  }
  return GlossMotdDoc.fromJson(raw);
}

String encodeGlossMotdDoc(GlossMotdDoc doc) => huiWriteJson(doc.toJson());

GlossMotdDoc cloneGlossMotdDoc(GlossMotdDoc doc) =>
    GlossMotdDoc.fromJson(huiDeepCopy(doc.toJson()));

const Set<String> _docKnown = <String>{
  'schemaVersion',
  'revision',
  'favicon',
  'entries',
  'links',
  'rotation',
  'icons',
  'state',
  'serverLinks',
};

const Set<String> _entryKnown = <String>{
  'lines',
  'favicon',
  'sample',
  'online',
  'max',
  'version',
  'show',
  'weight',
  'select',
  'icons',
  'counts',
  'sampleMode',
};

const Set<String> _linkKnown = <String>{'type', 'label', 'url'};

/// `MotdDoc.trimToNull` — a value that is absent, non-textual or blank is no
/// value at all. The raw string is kept so the encoder can drop the key
/// rather than write an empty string the plugin would only trim away again.
String? _readTrimmable(Object? value) => value is String ? value : null;

/// `MotdLink.normalizeType` — a known type is stored lowercase. A blank one
/// is kept verbatim so [_emitTrimmable] drops it instead of writing `""`.
String? _readLinkType(Object? value) {
  if (value is! String) return null;
  final String trimmed = value.trim();
  return trimmed.isEmpty ? value : trimmed.toLowerCase();
}

/// True when [value] is worth writing: the plugin trims blank to null, so an
/// empty field is an absent key, not an empty value.
bool _emitTrimmable(String? value) => value != null && value.trim().isNotEmpty;

/// One pause-menu server link (`MotdDoc.MotdLink`). A known [type] maps onto
/// the client's own label; a [label] publishes a custom one. Either is
/// required and the [url] must be an http or https address with a host —
/// all three rejections happen at parse in Java, so they are
/// `validateMotdDoc`'s to report here.
final class GlossMotdLink {
  GlossMotdLink({
    this.type,
    this.label,
    this.url = '',
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  /// One of [glossMotdLinkTypes], lowercase. Null means the link carries its
  /// own [label] instead.
  String? type;

  /// The custom label, rendered through the text pipeline for each viewer.
  String? label;

  String url;

  Map<String, dynamic> extras;

  /// `MotdLink.isLabelled` — the client draws its own wording for a typed
  /// link, so a label is only read when no type is set.
  bool get isLabelled => !_emitTrimmable(type);

  static GlossMotdLink fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossMotdLink(
      type: _readLinkType(map['type']),
      label: _readTrimmable(map['label']),
      url: huiReadString(map, 'url'),
      extras: huiCollectExtras(map, _linkKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    if (_emitTrimmable(type)) 'type': type,
    if (_emitTrimmable(label)) 'label': label,
    'url': url,
  }, extras);

  GlossMotdLink copy() => GlossMotdLink(
    type: type,
    label: label,
    url: url,
    extras: huiDeepCopyMap(extras),
  );
}

/// One MOTD candidate: 1..2 lines shown together in the server list.
/// Mirrors `MotdDoc.MotdEntry`, which maps a null line to `""` rather than
/// dropping it — [glossReadStringList] does the same, for [lines] and for
/// [sample] both.
final class GlossMotdEntry {
  GlossMotdEntry({
    List<String>? lines,
    this.favicon,
    List<String>? sample,
    this.online,
    this.max,
    this.version,
    this.show = true,
    this.weight = 1,
    this.select,
    this.icons,
    this.counts,
    this.sampleMode,
    Map<String, dynamic>? extras,
  }) : lines = lines ?? <String>[],
       sample = sample ?? <String>[],
       extras = extras ?? <String, dynamic>{};

  List<String> lines;

  /// This entry's own server-list icon, overriding the document's for the
  /// ping that picks this entry. Null means the document icon stands.
  String? favicon;

  /// The hover list under the player count — at most
  /// [glossMotdMaxSampleLines] lines, each rendered through `renderStatic`.
  List<String> sample;

  /// The player count the ping reports, as authored text. Whatever it renders
  /// to must read as a number or `MotdService.number` drops it with a warning.
  String? online;

  /// The slot count the ping reports, same rule as [online].
  String? max;

  /// The version label shown when the client protocol does not match.
  String? version;
  Object? show;
  int weight;
  GlossMotdSelector? select;
  List<String>? icons;
  GlossMotdCounts? counts;
  String? sampleMode;

  String get effectiveSampleMode =>
      sampleMode ?? (sample.isEmpty ? 'inherit' : 'replace');

  Map<String, dynamic> extras;

  /// `MotdEntry.joined` — what one ping actually renders.
  String get joined => lines.join('\n');

  static GlossMotdEntry fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossMotdEntry(
      lines: glossReadStringList(map['lines']),
      favicon: _readTrimmable(map['favicon']),
      sample: glossReadStringList(map['sample']),
      online: _readTrimmable(map['online']),
      max: _readTrimmable(map['max']),
      version: _readTrimmable(map['version']),
      show: map['show'] ?? true,
      weight: huiReadInt(map, 'weight', fallback: 1),
      select: map['select'] == null
          ? null
          : GlossMotdSelector.fromJson(map['select'], '$path.select'),
      icons: _motdStrings(map['icons'], '$path.icons'),
      counts: map['counts'] == null
          ? null
          : GlossMotdCounts.fromJson(map['counts'], '$path.counts'),
      sampleMode: _motdString(map['sampleMode'], '$path.sampleMode'),
      extras: huiCollectExtras(map, _entryKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'lines': List<String>.of(lines),
    if (_emitTrimmable(favicon)) 'favicon': favicon,
    if (sample.isNotEmpty) 'sample': List<String>.of(sample),
    if (_emitTrimmable(online)) 'online': online,
    if (_emitTrimmable(max)) 'max': max,
    if (_emitTrimmable(version)) 'version': version,
    if (show != true) 'show': show,
    if (weight != 1) 'weight': weight,
    if (select != null) 'select': select!.toJson(),
    if (icons != null) 'icons': List<String>.of(icons!),
    if (counts != null) 'counts': counts!.toJson(),
    if (sampleMode != null) 'sampleMode': sampleMode,
  }, extras);

  GlossMotdEntry copy() => GlossMotdEntry(
    lines: List<String>.of(lines),
    favicon: favicon,
    sample: List<String>.of(sample),
    online: online,
    max: max,
    version: version,
    show: show,
    weight: weight,
    select: select?.copy(),
    icons: icons == null ? null : List<String>.of(icons!),
    counts: counts?.copy(),
    sampleMode: sampleMode,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossMotdDoc extends GlossDoc {
  GlossMotdDoc({
    super.schemaVersion = glossCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    this.favicon,
    this.rotation,
    this.icons,
    this.state,
    this.serverLinks,
    List<GlossMotdEntry>? entries,
    List<GlossMotdLink>? links,
    Map<String, dynamic>? extras,
    Set<String>? absentKeys,
  }) : entries = entries ?? <GlossMotdEntry>[],
       links = links ?? <GlossMotdLink>[],
       extras = extras ?? <String, dynamic>{},
       absentKeys = absentKeys ?? <String>{};

  /// The random-pick pool. The plugin requires at least one entry
  /// (`MotdDoc.java:20-23`); an empty list here is a validation error, not a
  /// decode failure.
  List<GlossMotdEntry> entries;

  /// The pause-menu server links, in the order the client lists them. Empty
  /// is the normal state and publishes nothing.
  List<GlossMotdLink> links;

  /// The server-list icon every entry uses unless it names its own. Null or
  /// blank leaves the server's own `server-icon.png` in place.
  String? favicon;
  GlossMotdRotation? rotation;
  List<String>? icons;
  String? state;
  GlossMotdServerLinks? serverLinks;

  String get effectiveState => state ?? 'normal';
  List<GlossMotdLink> enabledLinks(bool motdEnabled) => serverLinks == null
      ? (motdEnabled ? links : const <GlossMotdLink>[])
      : serverLinks!.enabled != false
      ? serverLinks!.links ?? const <GlossMotdLink>[]
      : const <GlossMotdLink>[];

  List<String> iconsFor(GlossMotdEntry entry) {
    if (entry.icons?.isNotEmpty ?? false) return entry.icons!;
    if (_emitTrimmable(entry.favicon)) return <String>[entry.favicon!.trim()];
    if (icons?.isNotEmpty ?? false) return icons!;
    return _emitTrimmable(favicon)
        ? <String>[favicon!.trim()]
        : const <String>[];
  }

  Map<String, dynamic> extras;
  Set<String> absentKeys;

  static GlossMotdDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'motd');
    return GlossMotdDoc(
      schemaVersion: glossCurrentSchemaVersion,
      revision: glossReadRevision(map),
      favicon: _readTrimmable(map['favicon']),
      rotation: map['rotation'] == null
          ? null
          : GlossMotdRotation.fromJson(map['rotation'], r'$.rotation'),
      icons: _motdStrings(map['icons'], r'$.icons'),
      state: _motdString(map['state'], r'$.state'),
      serverLinks: map['serverLinks'] == null
          ? null
          : GlossMotdServerLinks.fromJson(map['serverLinks'], r'$.serverLinks'),
      entries: <GlossMotdEntry>[
        for (final (int index, Object? entry) in huiReadList(
          map['entries'],
        ).indexed)
          GlossMotdEntry.fromJson(entry, 'entries[$index]'),
      ],
      links: <GlossMotdLink>[
        for (final (int index, Object? link) in huiReadList(
          map['links'],
        ).indexed)
          GlossMotdLink.fromJson(link, 'links[$index]'),
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
      if (_emitTrimmable(favicon)) 'favicon': favicon,
      if (rotation != null) 'rotation': rotation!.toJson(),
      if (icons != null) 'icons': List<String>.of(icons!),
      if (state != null) 'state': state,
      if (serverLinks != null) 'serverLinks': serverLinks!.toJson(),
      if (!absentKeys.contains('entries') || entries.isNotEmpty)
        'entries': <Map<String, dynamic>>[
          for (final GlossMotdEntry entry in entries) entry.toJson(),
        ],
      if (links.isNotEmpty)
        'links': <Map<String, dynamic>>[
          for (final GlossMotdLink link in links) link.toJson(),
        ],
    };
    return huiMergeExtras(out, extras);
  }

  /// `MotdDoc.faviconFor` — the icon a ping that picked [entry] would send:
  /// the entry's own when it names one, the document's otherwise. Null when
  /// neither names a file, which leaves the server's `server-icon.png` alone.
  String? faviconFor(GlossMotdEntry entry) {
    if (_emitTrimmable(entry.favicon)) return entry.favicon;
    if (_emitTrimmable(favicon)) return favicon;
    return null;
  }

  GlossMotdDoc copy() => GlossMotdDoc(
    schemaVersion: schemaVersion,
    revision: revision,
    favicon: favicon,
    rotation: rotation?.copy(),
    icons: icons == null ? null : List<String>.of(icons!),
    state: state,
    serverLinks: serverLinks?.copy(),
    entries: <GlossMotdEntry>[
      for (final GlossMotdEntry entry in entries) entry.copy(),
    ],
    links: <GlossMotdLink>[for (final GlossMotdLink link in links) link.copy()],
    extras: huiDeepCopyMap(extras),
    absentKeys: Set<String>.of(absentKeys),
  );
}

final class GlossMotdRotation {
  GlossMotdRotation({
    this.mode,
    this.intervalSeconds,
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  String? mode;
  int? intervalSeconds;
  Map<String, Object?> extras;
  String get effectiveMode => mode ?? 'weighted';
  int get effectiveIntervalSeconds => intervalSeconds ?? 60;
  static GlossMotdRotation fromJson(Object? raw, String path) {
    final Map<String, Object?> map = huiReadObject(raw, path);
    return GlossMotdRotation(
      mode: _motdString(map['mode'], '$path.mode'),
      intervalSeconds: _motdInt(
        map['intervalSeconds'],
        '$path.intervalSeconds',
      ),
      extras: huiCollectExtras(map, const <String>{'mode', 'intervalSeconds'}),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    ...extras,
    if (mode != null) 'mode': mode,
    if (intervalSeconds != null) 'intervalSeconds': intervalSeconds,
  };
  GlossMotdRotation copy() => fromJson(huiDeepCopy(toJson()), r'$.rotation');
}

final class GlossMotdCounts {
  GlossMotdCounts({
    this.onlineMode,
    this.onlineValue,
    this.maximumMode,
    this.maximumValue,
    this.hide,
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  String? onlineMode;
  int? onlineValue;
  String? maximumMode;
  int? maximumValue;
  bool? hide;
  Map<String, Object?> extras;
  static GlossMotdCounts fromJson(Object? raw, String path) {
    final Map<String, Object?> map = huiReadObject(raw, path);
    return GlossMotdCounts(
      onlineMode: _motdString(map['onlineMode'], '$path.onlineMode'),
      onlineValue: _motdInt(map['onlineValue'], '$path.onlineValue'),
      maximumMode: _motdString(map['maximumMode'], '$path.maximumMode'),
      maximumValue: _motdInt(map['maximumValue'], '$path.maximumValue'),
      hide: _motdBool(map['hide'], '$path.hide'),
      extras: huiCollectExtras(map, const <String>{
        'onlineMode',
        'onlineValue',
        'maximumMode',
        'maximumValue',
        'hide',
      }),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    ...extras,
    if (onlineMode != null) 'onlineMode': onlineMode,
    if (onlineValue != null) 'onlineValue': onlineValue,
    if (maximumMode != null) 'maximumMode': maximumMode,
    if (maximumValue != null) 'maximumValue': maximumValue,
    if (hide != null) 'hide': hide,
  };
  GlossMotdCounts copy() => fromJson(huiDeepCopy(toJson()), r'$.counts');
}

final class GlossMotdSelector {
  GlossMotdSelector({
    this.hostnames,
    this.minProtocol,
    this.maxProtocol,
    this.zone,
    this.startTime,
    this.endTime,
    this.days,
    this.states,
    this.minOnline,
    this.maxOnline,
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  List<String>? hostnames;
  int? minProtocol;
  int? maxProtocol;
  String? zone;
  String? startTime;
  String? endTime;
  List<int>? days;
  List<String>? states;
  int? minOnline;
  int? maxOnline;
  Map<String, Object?> extras;
  static GlossMotdSelector fromJson(Object? raw, String path) {
    final Map<String, Object?> map = huiReadObject(raw, path);
    final Object? rawDays = map['days'];
    if (rawDays != null && rawDays is! List) {
      throw HuiFormatException('Expected an array', '$path.days');
    }
    return GlossMotdSelector(
      hostnames: _motdStrings(map['hostnames'], '$path.hostnames'),
      minProtocol: _motdInt(map['minProtocol'], '$path.minProtocol'),
      maxProtocol: _motdInt(map['maxProtocol'], '$path.maxProtocol'),
      zone: _motdString(map['zone'], '$path.zone'),
      startTime: _motdString(map['startTime'], '$path.startTime'),
      endTime: _motdString(map['endTime'], '$path.endTime'),
      days: rawDays == null
          ? null
          : <int>[
              for (final (int index, Object? value)
                  in (rawDays as List<Object?>).indexed)
                _motdInt(value, '$path.days[$index]') ??
                    (throw HuiFormatException(
                      'Expected an integer',
                      '$path.days[$index]',
                    )),
            ],
      states: _motdStrings(map['states'], '$path.states'),
      minOnline: _motdInt(map['minOnline'], '$path.minOnline'),
      maxOnline: _motdInt(map['maxOnline'], '$path.maxOnline'),
      extras: huiCollectExtras(map, const <String>{
        'hostnames',
        'minProtocol',
        'maxProtocol',
        'zone',
        'startTime',
        'endTime',
        'days',
        'states',
        'minOnline',
        'maxOnline',
      }),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    ...extras,
    if (hostnames != null) 'hostnames': List<String>.of(hostnames!),
    if (minProtocol != null) 'minProtocol': minProtocol,
    if (maxProtocol != null) 'maxProtocol': maxProtocol,
    if (zone != null) 'zone': zone,
    if (startTime != null) 'startTime': startTime,
    if (endTime != null) 'endTime': endTime,
    if (days != null) 'days': List<int>.of(days!),
    if (states != null) 'states': List<String>.of(states!),
    if (minOnline != null) 'minOnline': minOnline,
    if (maxOnline != null) 'maxOnline': maxOnline,
  };
  GlossMotdSelector copy() => fromJson(huiDeepCopy(toJson()), r'$.select');
}

final class GlossMotdServerLinks {
  GlossMotdServerLinks({this.enabled, this.links, Map<String, Object?>? extras})
    : extras = extras ?? <String, Object?>{};
  bool? enabled;
  List<GlossMotdLink>? links;
  Map<String, Object?> extras;
  static GlossMotdServerLinks fromJson(Object? raw, String path) {
    final Map<String, Object?> map = huiReadObject(raw, path);
    final Object? rawLinks = map['links'];
    if (rawLinks != null && rawLinks is! List) {
      throw HuiFormatException('Expected an array', '$path.links');
    }
    return GlossMotdServerLinks(
      enabled: _motdBool(map['enabled'], '$path.enabled'),
      links: rawLinks == null
          ? null
          : <GlossMotdLink>[
              for (final (int index, Object? value)
                  in (rawLinks as List<Object?>).indexed)
                GlossMotdLink.fromJson(value, '$path.links[$index]'),
            ],
      extras: huiCollectExtras(map, const <String>{'enabled', 'links'}),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    ...extras,
    if (enabled != null) 'enabled': enabled,
    if (links != null)
      'links': <Map<String, dynamic>>[
        for (final GlossMotdLink link in links!) link.toJson(),
      ],
  };
  GlossMotdServerLinks copy() =>
      fromJson(huiDeepCopy(toJson()), r'$.serverLinks');
}

String? _motdString(Object? raw, String path) {
  if (raw == null || raw is String) return raw as String?;
  throw HuiFormatException('Expected a string', path);
}

int? _motdInt(Object? raw, String path) {
  if (raw == null) return null;
  if (raw is num &&
      raw.isFinite &&
      raw == raw.truncateToDouble() &&
      raw >= -2147483648 &&
      raw <= 2147483647) {
    return raw.toInt();
  }
  throw HuiFormatException('Expected a 32-bit integer', path);
}

bool? _motdBool(Object? raw, String path) {
  if (raw == null || raw is bool) return raw as bool?;
  throw HuiFormatException('Expected a boolean', path);
}

List<String>? _motdStrings(Object? raw, String path) {
  if (raw == null) return null;
  if (raw is! List) throw HuiFormatException('Expected an array', path);
  return <String>[
    for (final (int index, Object? value) in raw.indexed)
      _motdString(value, '$path[$index]') ??
          (throw HuiFormatException('Expected a string', '$path[$index]')),
  ];
}

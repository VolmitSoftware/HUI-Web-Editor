/// Mirror of `ConnectionsDoc.java` — the server edition of
/// `plugins/Gloss/connections.json`:
///
/// ```json
/// {
///   "schemaVersion": 1,
///   "revision": 1,
///   "show": true,
///   "join": {
///     "enabled": true,
///     "show": true,
///     "audience": "network",
///     "presentation": {"text": "&a+ &f{{ subject.name }} &7joined"},
///     "variants": []
///   },
///   "leave": { ... }
/// }
/// ```
///
/// The file is the proxy's file as well, so a `switch` block and the
/// per-section `audience` parse without complaint and mean nothing on a
/// standalone server (`ConnectionsDoc.java:14-19`): one server is the whole
/// network, and a backend never sees a switch. `switch` is not a key this
/// model knows, so it rides through [extras] untouched.
///
/// A section that is present is on unless it says otherwise, and a section the
/// file leaves out is off entirely (`Section.DISABLED`), so [absentKeys]
/// carries the difference rather than defaulting an absent block into an
/// active one.
library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

/// `ConnectionsDoc.AUDIENCE_NETWORK`.
const String glossConnectionsAudienceNetwork = 'network';

/// `ConnectionsDoc.AUDIENCE_SERVER`.
const String glossConnectionsAudienceServer = 'server';

/// `ConnectionsDoc.AUDIENCES`.
const List<String> glossConnectionsAudiences = <String>[
  glossConnectionsAudienceNetwork,
  glossConnectionsAudienceServer,
];

/// The two sections a standalone server broadcasts, in file order.
const List<String> glossConnectionsSectionKeys = <String>['join', 'leave'];

/// True when [json] has the shape of a connections document. Routing only —
/// full checking is `validateConnectionsDoc`'s job.
bool looksLikeConnectionsDoc(Object? json) {
  if (json is! Map || json['schemaVersion'] is! num) return false;
  if (json.containsKey('entries') ||
      json.containsKey('anchor') ||
      json.containsKey('frames') ||
      json.containsKey('headerFooter') ||
      json.containsKey('listNames') ||
      json.containsKey('presentation') ||
      json.containsKey('components') ||
      json.containsKey('elements')) {
    return false;
  }
  return json.containsKey('join') ||
      json.containsKey('leave') ||
      json.containsKey('switch');
}

GlossConnectionsDoc decodeGlossConnectionsDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': e.message,
    });
  }
  return GlossConnectionsDoc.fromJson(raw);
}

String encodeGlossConnectionsDoc(GlossConnectionsDoc doc) =>
    huiWriteJson(doc.toJson());

GlossConnectionsDoc cloneGlossConnectionsDoc(GlossConnectionsDoc doc) =>
    GlossConnectionsDoc.fromJson(huiDeepCopy(doc.toJson()));

const Set<String> _docKnown = <String>{
  'schemaVersion',
  'revision',
  'join',
  'leave',
};

const Set<String> _sectionKnown = <String>{
  'enabled',
  'audience',
  'presentation',
  'variants',
};

const Set<String> _presentationKnown = <String>{'text'};

const Set<String> _variantKnown = <String>{'priority', 'when', 'presentation'};

/// `ConnectionsDoc.Presentation` — one line of chat, rendered per recipient.
final class GlossConnectionsPresentation {
  GlossConnectionsPresentation({this.text = '', Map<String, dynamic>? extras})
    : extras = extras ?? <String, dynamic>{};

  String text;
  Map<String, dynamic> extras;

  static GlossConnectionsPresentation fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossConnectionsPresentation(
      text: huiReadString(map, 'text'),
      extras: huiCollectExtras(map, _presentationKnown),
    );
  }

  Map<String, dynamic> toJson() =>
      huiMergeExtras(<String, dynamic>{'text': text}, extras);

  GlossConnectionsPresentation copy() =>
      GlossConnectionsPresentation(text: text, extras: huiDeepCopyMap(extras));
}

/// `ConnectionsDoc.Variant` — the highest-priority variant whose condition
/// holds for the recipient replaces the base text. Unlike a surface or
/// tablist variant this one carries no id; priority and the condition are the
/// whole of it.
final class GlossConnectionsVariant {
  GlossConnectionsVariant({
    this.priority = 0,
    this.when = '',
    GlossConnectionsPresentation? presentation,
    Map<String, dynamic>? extras,
  }) : presentation = presentation ?? GlossConnectionsPresentation(),
       extras = extras ?? <String, dynamic>{};

  int priority;
  String when;
  GlossConnectionsPresentation presentation;
  Map<String, dynamic> extras;

  static GlossConnectionsVariant fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossConnectionsVariant(
      priority: huiReadInt(map, 'priority'),
      when: huiReadString(map, 'when'),
      presentation: GlossConnectionsPresentation.fromJson(
        map['presentation'],
        '$path.presentation',
      ),
      extras: huiCollectExtras(map, _variantKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'priority': priority,
    'when': when,
    'presentation': presentation.toJson(),
  }, extras);

  GlossConnectionsVariant copy() => GlossConnectionsVariant(
    priority: priority,
    when: when,
    presentation: presentation.copy(),
    extras: huiDeepCopyMap(extras),
  );
}

/// `ConnectionsDoc.Section` — one announcement.
final class GlossConnectionsSection {
  GlossConnectionsSection({
    this.enabled = true,
    this.audience = glossConnectionsAudienceNetwork,
    GlossConnectionsPresentation? presentation,
    List<GlossConnectionsVariant>? variants,
    Map<String, dynamic>? extras,
    this.present = true,
  }) : presentation = presentation ?? GlossConnectionsPresentation(),
       variants = variants ?? <GlossConnectionsVariant>[],
       extras = extras ?? <String, dynamic>{};

  /// `Section.active()`. A present block with no `enabled` key is on.
  bool enabled;

  /// Read and ignored on a standalone server, where one server is the whole
  /// network. Kept verbatim, including a spelling the enum does not list, so
  /// validation can name it instead of the decoder silently repairing it.
  String audience;

  GlossConnectionsPresentation presentation;
  List<GlossConnectionsVariant> variants;
  Map<String, dynamic> extras;

  /// False when the file carried no block at all, which `Section.DISABLED`
  /// makes an off switch rather than a default.
  bool present;

  /// The off section an absent block decodes to.
  static GlossConnectionsSection absent() =>
      GlossConnectionsSection(enabled: false, present: false);

  static GlossConnectionsSection fromJson(Object? raw, String path) {
    if (raw == null) return GlossConnectionsSection.absent();
    final Map<String, dynamic> map = huiReadObject(raw, path);
    final List<Object?> rawVariants = huiReadList(map['variants']);
    final String audience = huiReadString(map, 'audience');
    return GlossConnectionsSection(
      enabled: map['enabled'] == null ? true : huiReadBool(map, 'enabled'),
      audience: audience.trim().isEmpty
          ? glossConnectionsAudienceNetwork
          : audience,
      presentation: GlossConnectionsPresentation.fromJson(
        map['presentation'],
        '$path.presentation',
      ),
      variants: <GlossConnectionsVariant>[
        for (int index = 0; index < rawVariants.length; index++)
          GlossConnectionsVariant.fromJson(
            rawVariants[index],
            '$path.variants[$index]',
          ),
      ],
      extras: huiCollectExtras(map, _sectionKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'enabled': enabled,
    'audience': audience,
    'presentation': presentation.toJson(),
    'variants': <Map<String, dynamic>>[
      for (final GlossConnectionsVariant variant in variants) variant.toJson(),
    ],
  }, extras);

  GlossConnectionsSection copy() => GlossConnectionsSection(
    enabled: enabled,
    audience: audience,
    presentation: presentation.copy(),
    variants: <GlossConnectionsVariant>[
      for (final GlossConnectionsVariant variant in variants) variant.copy(),
    ],
    extras: huiDeepCopyMap(extras),
    present: present,
  );
}

final class GlossConnectionsDoc extends GlossDoc {
  GlossConnectionsDoc({
    super.schemaVersion = glossCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    GlossConnectionsSection? join,
    GlossConnectionsSection? leave,
    Map<String, dynamic>? extras,
    Set<String>? absentKeys,
  }) : join = join ?? GlossConnectionsSection(),
       leave = leave ?? GlossConnectionsSection(),
       extras = extras ?? <String, dynamic>{},
       absentKeys = absentKeys ?? <String>{};

  GlossConnectionsSection join;
  GlossConnectionsSection leave;

  /// Carries the document `show` the way every other Gloss kind does, plus
  /// the proxy's `switch` block.
  Map<String, dynamic> extras;

  Set<String> absentKeys;

  /// The section named by [key], for the inspector and the preview.
  GlossConnectionsSection section(String key) => key == 'leave' ? leave : join;

  static GlossConnectionsDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'connections');
    return GlossConnectionsDoc(
      schemaVersion: glossCurrentSchemaVersion,
      revision: glossReadRevision(map),
      join: GlossConnectionsSection.fromJson(map['join'], r'$.join'),
      leave: GlossConnectionsSection.fromJson(map['leave'], r'$.leave'),
      extras: huiCollectExtras(map, _docKnown),
      absentKeys: <String>{if (map['revision'] == null) 'revision'},
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{
      'schemaVersion': schemaVersion,
      if (!absentKeys.contains('revision')) 'revision': revision,
      if (join.present) 'join': join.toJson(),
      if (leave.present) 'leave': leave.toJson(),
    };
    return huiMergeExtras(out, extras);
  }

  GlossConnectionsDoc copy() => GlossConnectionsDoc(
    schemaVersion: schemaVersion,
    revision: revision,
    join: join.copy(),
    leave: leave.copy(),
    extras: huiDeepCopyMap(extras),
    absentKeys: Set<String>.of(absentKeys),
  );
}

/// Mirror of `SurfaceDoc.java` — one file per document under
/// `plugins/Gloss/surfaces/`:
///
/// ```json
/// {
///   "schemaVersion": 1,
///   "revision": 1,
///   "surface": "actionbar",
///   "show": "true",
///   "select": { "priority": 0, "when": "false" },
///   "presentation": { "text": "&7Welcome, &f{{ player.name }}" },
///   "variants": []
/// }
/// ```
///
/// `surface` picks which presentation fields the server keeps:
/// `Presentation.forKind` rebuilds the record with that kind's fields alone
/// and DROPS the rest without complaint. The editor keeps everything the file
/// carried so the author can see what the server is about to throw away, and
/// [glossSurfaceEffective] is the read-only view of what survives.
///
/// The numeric knobs are clamped rather than refused (`Presentation.clamp`),
/// so an out-of-range tick count is a value the server quietly changes, not a
/// file it rejects.
library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

/// `SurfaceKind.ACTIONBAR`.
const String glossSurfaceKindActionbar = 'actionbar';

/// `SurfaceKind.BOSSBAR`.
const String glossSurfaceKindBossbar = 'bossbar';

/// `SurfaceKind.TITLE`.
const String glossSurfaceKindTitle = 'title';

/// `SurfaceKind` in wire order.
const List<String> glossSurfaceKinds = <String>[
  glossSurfaceKindActionbar,
  glossSurfaceKindBossbar,
  glossSurfaceKindTitle,
];

/// `HudSlot` codes a surface may claim.
const List<String> glossSurfaceSlots = <String>['left', 'center', 'right'];

/// `SurfaceDoc.COLORS` — the boss-bar colours Bukkit exposes.
const List<String> glossSurfaceColors = <String>[
  'pink',
  'blue',
  'red',
  'green',
  'yellow',
  'purple',
  'white',
];

/// `SurfaceDoc.STYLES` — the boss-bar notch divisions.
const List<String> glossSurfaceStyles = <String>[
  'solid',
  'segmented_6',
  'segmented_10',
  'segmented_12',
  'segmented_20',
];

/// `SurfaceDoc.TRIGGERS` — when a title surface replays.
const List<String> glossSurfaceTriggers = <String>['select', 'once', 'repeat'];

/// `SurfacePriorities.NAMES` — the compositor lanes, lowest band first.
const List<String> glossSurfacePriorities = <String>[
  'ambient',
  'notice',
  'status',
  'progress',
  'interactive',
  'modal',
  'pinned',
];

/// `SurfacePriorities.DEFAULT_NAME`.
const String glossSurfaceDefaultPriority = 'status';

/// `SurfaceDoc.DEFAULT_TRIGGER`.
const String glossSurfaceDefaultTrigger = 'select';

/// The boss-bar fill an omitted `progress` resolves to.
const String glossSurfaceDefaultProgress = '1';

/// The boss-bar colour an omitted `color` resolves to.
const String glossSurfaceDefaultColor = 'white';

/// The boss-bar notch style an omitted `style` resolves to.
const String glossSurfaceDefaultStyle = 'solid';

const int glossSurfaceMinTtlTicks = 1;

/// `SurfaceDoc.MAX_TTL_TICKS`.
const int glossSurfaceMaxTtlTicks = 1200;

const int glossSurfaceMinFadeTicks = 0;

/// `SurfaceDoc.MAX_FADE_TICKS`.
const int glossSurfaceMaxFadeTicks = 1200;

const int glossSurfaceMinRepeatTicks = 1;

/// `SurfaceDoc.MAX_REPEAT_TICKS` — an hour of ticks.
const int glossSurfaceMaxRepeatTicks = 72000;

/// `SurfaceDoc.DEFAULT_FADE_IN_TICKS`.
const int glossSurfaceDefaultFadeInTicks = 10;

/// `SurfaceDoc.DEFAULT_STAY_TICKS`.
const int glossSurfaceDefaultStayTicks = 40;

/// `SurfaceDoc.DEFAULT_FADE_OUT_TICKS`.
const int glossSurfaceDefaultFadeOutTicks = 10;

/// `Selection.NEVER.when` — a document with no condition never shows.
const String glossSurfaceNeverCondition = 'false';

/// The presentation keys `Presentation.forKind` keeps, per surface kind.
/// Everything else the file carried is dropped before the runtime sees it.
const Map<String, Set<String>> glossSurfaceKindFields = <String, Set<String>>{
  glossSurfaceKindActionbar: <String>{
    'text',
    'slots',
    'priority',
    'ttlTicks',
  },
  glossSurfaceKindBossbar: <String>{
    'title',
    'slots',
    'progress',
    'color',
    'style',
    'priority',
    'ttlTicks',
  },
  glossSurfaceKindTitle: <String>{
    'title',
    'subtitle',
    'slots',
    'priority',
    'ttlTicks',
    'fadeInTicks',
    'stayTicks',
    'fadeOutTicks',
    'trigger',
    'repeatTicks',
  },
};

/// The presentation key a surface kind cannot open without.
const Map<String, String> glossSurfaceRequiredField = <String, String>{
  glossSurfaceKindActionbar: 'text',
  glossSurfaceKindBossbar: 'title',
  glossSurfaceKindTitle: 'title',
};

/// True when [json] has the shape of a surface document. Routing only — full
/// checking is `validateSurfaceDoc`'s job.
bool looksLikeSurfaceDoc(Object? json) {
  if (json is! Map || json['schemaVersion'] is! num) return false;
  if (json['surface'] is! String) return false;
  return json.containsKey('presentation');
}

GlossSurfaceDoc decodeGlossSurfaceDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (error) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': error.message,
    });
  }
  return GlossSurfaceDoc.fromJson(raw);
}

String encodeGlossSurfaceDoc(GlossSurfaceDoc doc) => huiWriteJson(doc.toJson());

GlossSurfaceDoc cloneGlossSurfaceDoc(GlossSurfaceDoc doc) =>
    GlossSurfaceDoc.fromJson(huiDeepCopy(doc.toJson()));

const Set<String> _docKnown = <String>{
  'schemaVersion',
  'revision',
  'surface',
  'select',
  'presentation',
  'variants',
};

const Set<String> _selectKnown = <String>{'priority', 'when'};

const Set<String> _presentationKnown = <String>{
  'text',
  'slots',
  'title',
  'subtitle',
  'progress',
  'color',
  'style',
  'priority',
  'ttlTicks',
  'fadeInTicks',
  'stayTicks',
  'fadeOutTicks',
  'trigger',
  'repeatTicks',
};

const Set<String> _variantKnown = <String>{
  'id',
  'priority',
  'when',
  'presentation',
};

/// A string key the file carried, or null when it carried none. Distinguishing
/// the two is the whole point: an absent field takes the runtime's default, a
/// present blank one is an authoring mistake the validator names.
String? _readStringOrNull(Map<String, dynamic> raw, String key) {
  final Object? value = raw[key];
  if (value == null) return null;
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return null;
}

int? _readIntOrNull(Map<String, dynamic> raw, String key) {
  final Object? value = raw[key];
  if (value is num) return value.toInt();
  if (value is String) {
    final double? parsed = double.tryParse(value);
    if (parsed != null) return parsed.toInt();
  }
  return null;
}

List<String>? _readSlotsOrNull(Map<String, dynamic> raw) {
  final Object? value = raw['slots'];
  if (value == null) return null;
  return glossReadStringList(value);
}

int _clampTicks(int value, int minimum, int maximum) =>
    value < minimum ? minimum : (value > maximum ? maximum : value);

/// `SurfaceDoc.Selection` — the document-level lane and eligibility test.
final class GlossSurfaceSelect {
  GlossSurfaceSelect({
    this.priority = 0,
    this.when = glossSurfaceNeverCondition,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  int priority;
  String when;
  Map<String, dynamic> extras;

  static GlossSurfaceSelect fromJson(Object? raw) {
    if (raw == null) return GlossSurfaceSelect();
    final Map<String, dynamic> map = huiReadObject(raw, r'$.select');
    return GlossSurfaceSelect(
      priority: huiReadInt(map, 'priority'),
      when: huiReadString(map, 'when', fallback: glossSurfaceNeverCondition),
      extras: huiCollectExtras(map, _selectKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'priority': priority,
    'when': when,
  }, extras);

  GlossSurfaceSelect copy() => GlossSurfaceSelect(
    priority: priority,
    when: when,
    extras: huiDeepCopyMap(extras),
  );
}

/// `SurfaceDoc.Presentation` — every field of all three shapes, because the
/// file may carry any of them and the editor never silently deletes one.
final class GlossSurfacePresentation {
  GlossSurfacePresentation({
    this.text,
    this.slots,
    this.title,
    this.subtitle,
    this.progress,
    this.color,
    this.style,
    this.priority,
    this.ttlTicks,
    this.fadeInTicks,
    this.stayTicks,
    this.fadeOutTicks,
    this.trigger,
    this.repeatTicks,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  /// The action-bar line.
  String? text;

  /// Which HUD lanes the line claims; null takes `["center"]`.
  List<String>? slots;

  /// The boss-bar or title line.
  String? title;

  /// The title surface's second line.
  String? subtitle;

  /// Boss-bar fill, an expression in 0..1; null takes `"1"`.
  String? progress;

  String? color;
  String? style;

  /// A `SurfacePriorities` name; null takes `status`.
  String? priority;

  int? ttlTicks;
  int? fadeInTicks;
  int? stayTicks;
  int? fadeOutTicks;
  String? trigger;
  int? repeatTicks;

  Map<String, dynamic> extras;

  /// The keys this presentation actually carries, used by validation to tell
  /// a dropped field from one that was never written.
  Set<String> get authoredFields => <String>{
    if (text != null) 'text',
    if (slots != null) 'slots',
    if (title != null) 'title',
    if (subtitle != null) 'subtitle',
    if (progress != null) 'progress',
    if (color != null) 'color',
    if (style != null) 'style',
    if (priority != null) 'priority',
    if (ttlTicks != null) 'ttlTicks',
    if (fadeInTicks != null) 'fadeInTicks',
    if (stayTicks != null) 'stayTicks',
    if (fadeOutTicks != null) 'fadeOutTicks',
    if (trigger != null) 'trigger',
    if (repeatTicks != null) 'repeatTicks',
  };

  static GlossSurfacePresentation fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossSurfacePresentation(
      text: _readStringOrNull(map, 'text'),
      slots: _readSlotsOrNull(map),
      title: _readStringOrNull(map, 'title'),
      subtitle: _readStringOrNull(map, 'subtitle'),
      progress: _readStringOrNull(map, 'progress'),
      color: _readStringOrNull(map, 'color'),
      style: _readStringOrNull(map, 'style'),
      priority: _readStringOrNull(map, 'priority'),
      ttlTicks: _readIntOrNull(map, 'ttlTicks'),
      fadeInTicks: _readIntOrNull(map, 'fadeInTicks'),
      stayTicks: _readIntOrNull(map, 'stayTicks'),
      fadeOutTicks: _readIntOrNull(map, 'fadeOutTicks'),
      trigger: _readStringOrNull(map, 'trigger'),
      repeatTicks: _readIntOrNull(map, 'repeatTicks'),
      extras: huiCollectExtras(map, _presentationKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    if (text != null) 'text': text,
    if (slots != null) 'slots': List<String>.of(slots!),
    if (title != null) 'title': title,
    if (subtitle != null) 'subtitle': subtitle,
    if (progress != null) 'progress': progress,
    if (color != null) 'color': color,
    if (style != null) 'style': style,
    if (priority != null) 'priority': priority,
    if (ttlTicks != null) 'ttlTicks': ttlTicks,
    if (fadeInTicks != null) 'fadeInTicks': fadeInTicks,
    if (stayTicks != null) 'stayTicks': stayTicks,
    if (fadeOutTicks != null) 'fadeOutTicks': fadeOutTicks,
    if (trigger != null) 'trigger': trigger,
    if (repeatTicks != null) 'repeatTicks': repeatTicks,
  }, extras);

  GlossSurfacePresentation copy() => GlossSurfacePresentation(
    text: text,
    slots: slots == null ? null : List<String>.of(slots!),
    title: title,
    subtitle: subtitle,
    progress: progress,
    color: color,
    style: style,
    priority: priority,
    ttlTicks: ttlTicks,
    fadeInTicks: fadeInTicks,
    stayTicks: stayTicks,
    fadeOutTicks: fadeOutTicks,
    trigger: trigger,
    repeatTicks: repeatTicks,
    extras: huiDeepCopyMap(extras),
  );
}

/// `SurfaceDoc.Variant` — a complete replacement presentation with its own id,
/// lane and condition.
final class GlossSurfaceVariant {
  GlossSurfaceVariant({
    this.id = '',
    this.priority = 0,
    this.when = glossSurfaceNeverCondition,
    GlossSurfacePresentation? presentation,
    Map<String, dynamic>? extras,
  }) : presentation = presentation ?? GlossSurfacePresentation(),
       extras = extras ?? <String, dynamic>{};

  String id;
  int priority;
  String when;
  GlossSurfacePresentation presentation;
  Map<String, dynamic> extras;

  static GlossSurfaceVariant fromJson(Object? raw, int index) {
    final String path =
        r'$'
        '.variants['
        '$index]';
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossSurfaceVariant(
      id: huiReadString(map, 'id'),
      priority: huiReadInt(map, 'priority'),
      when: huiReadString(map, 'when', fallback: glossSurfaceNeverCondition),
      presentation: GlossSurfacePresentation.fromJson(
        map['presentation'],
        '$path.presentation',
      ),
      extras: huiCollectExtras(map, _variantKnown),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'id': id,
    'priority': priority,
    'when': when,
    'presentation': presentation.toJson(),
  }, extras);

  GlossSurfaceVariant copy() => GlossSurfaceVariant(
    id: id,
    priority: priority,
    when: when,
    presentation: presentation.copy(),
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossSurfaceDoc extends GlossDoc {
  GlossSurfaceDoc({
    super.schemaVersion = glossCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    this.surface = glossSurfaceKindActionbar,
    GlossSurfaceSelect? select,
    GlossSurfacePresentation? presentation,
    List<GlossSurfaceVariant>? variants,
    Map<String, dynamic>? extras,
  }) : select = select ?? GlossSurfaceSelect(),
       presentation = presentation ?? GlossSurfacePresentation(),
       variants = variants ?? <GlossSurfaceVariant>[],
       extras = extras ?? <String, dynamic>{};

  /// Kept verbatim, including a spelling `SurfaceKind.of` would refuse, so
  /// validation can name it instead of the decoder repairing it.
  String surface;

  GlossSurfaceSelect select;
  GlossSurfacePresentation presentation;
  List<GlossSurfaceVariant> variants;

  /// Carries the document `show` the way every other Gloss kind does.
  Map<String, dynamic> extras;

  /// True when [surface] is a kind `SurfaceKind.of` accepts.
  bool get hasKnownSurface => glossSurfaceKinds.contains(surface);

  /// The kind the editor draws for. An unknown spelling falls back to the
  /// action bar so the surface still renders something to correct.
  String get resolvedSurface =>
      hasKnownSurface ? surface : glossSurfaceKindActionbar;

  static GlossSurfaceDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'surface');
    final List<Object?> rawVariants = huiReadList(map['variants']);
    return GlossSurfaceDoc(
      schemaVersion: glossCurrentSchemaVersion,
      revision: glossReadRevision(map),
      surface: huiReadString(map, 'surface'),
      select: GlossSurfaceSelect.fromJson(map['select']),
      presentation: GlossSurfacePresentation.fromJson(
        map['presentation'],
        r'$.presentation',
      ),
      variants: <GlossSurfaceVariant>[
        for (int index = 0; index < rawVariants.length; index++)
          GlossSurfaceVariant.fromJson(rawVariants[index], index),
      ],
      extras: huiCollectExtras(map, _docKnown),
    );
  }

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'schemaVersion': schemaVersion,
    'revision': revision,
    'surface': surface,
    'select': select.toJson(),
    'presentation': presentation.toJson(),
    'variants': <Map<String, dynamic>>[
      for (final GlossSurfaceVariant variant in variants) variant.toJson(),
    ],
  }, extras);

  GlossSurfaceDoc copy() => GlossSurfaceDoc(
    schemaVersion: schemaVersion,
    revision: revision,
    surface: surface,
    select: select.copy(),
    presentation: presentation.copy(),
    variants: <GlossSurfaceVariant>[
      for (final GlossSurfaceVariant variant in variants) variant.copy(),
    ],
    extras: huiDeepCopyMap(extras),
  );
}

/// What the runtime actually holds after `Presentation.forKind` — the kind's
/// own fields, clamped, with the omitted ones filled in and every foreign
/// field dropped. The preview and the fidelity notes read this, never the
/// authored record.
GlossSurfacePresentation glossSurfaceEffective(
  String surface,
  GlossSurfacePresentation authored,
) {
  final List<String> slots = glossSurfaceEffectiveSlots(authored.slots);
  final String priority = glossSurfaceEffectivePriority(authored.priority);
  final int? ttlTicks = authored.ttlTicks == null
      ? null
      : _clampTicks(
          authored.ttlTicks!,
          glossSurfaceMinTtlTicks,
          glossSurfaceMaxTtlTicks,
        );
  switch (surface) {
    case glossSurfaceKindBossbar:
      return GlossSurfacePresentation(
        title: authored.title,
        slots: slots,
        progress:
            glossSurfaceProgressSource(authored.progress) ??
            glossSurfaceDefaultProgress,
        color: _effectiveName(
          authored.color,
          glossSurfaceColors,
          glossSurfaceDefaultColor,
        ),
        style: _effectiveName(
          authored.style,
          glossSurfaceStyles,
          glossSurfaceDefaultStyle,
        ),
        priority: priority,
        ttlTicks: ttlTicks,
      );
    case glossSurfaceKindTitle:
      final String trigger =
          _effectiveName(
            authored.trigger,
            glossSurfaceTriggers,
            glossSurfaceDefaultTrigger,
          )!;
      final int stay = authored.stayTicks == null
          ? glossSurfaceDefaultStayTicks
          : _clampTicks(
              authored.stayTicks!,
              glossSurfaceMinFadeTicks,
              glossSurfaceMaxFadeTicks,
            );
      final int? repeat = authored.repeatTicks == null
          ? null
          : _clampTicks(
              authored.repeatTicks!,
              glossSurfaceMinRepeatTicks,
              glossSurfaceMaxRepeatTicks,
            );
      return GlossSurfacePresentation(
        title: authored.title,
        subtitle: authored.subtitle ?? '',
        slots: slots,
        priority: priority,
        ttlTicks: ttlTicks,
        fadeInTicks: authored.fadeInTicks == null
            ? glossSurfaceDefaultFadeInTicks
            : _clampTicks(
                authored.fadeInTicks!,
                glossSurfaceMinFadeTicks,
                glossSurfaceMaxFadeTicks,
              ),
        stayTicks: stay,
        fadeOutTicks: authored.fadeOutTicks == null
            ? glossSurfaceDefaultFadeOutTicks
            : _clampTicks(
                authored.fadeOutTicks!,
                glossSurfaceMinFadeTicks,
                glossSurfaceMaxFadeTicks,
              ),
        trigger: trigger,
        repeatTicks: trigger == 'repeat'
            ? (repeat == null || repeat < stay ? stay : repeat)
            : repeat,
      );
    default:
      return GlossSurfacePresentation(
        text: authored.text,
        slots: slots,
        priority: priority,
        ttlTicks: ttlTicks,
      );
  }
}

/// `Presentation.copySlots` — trimmed, lower-cased, deduplicated, and
/// `["center"]` when the file named none.
List<String> glossSurfaceEffectiveSlots(List<String>? authored) {
  if (authored == null || authored.isEmpty) return const <String>['center'];
  final List<String> resolved = <String>[];
  for (final String slot in authored) {
    final String normalized = slot.trim().toLowerCase();
    if (!glossSurfaceSlots.contains(normalized)) continue;
    if (!resolved.contains(normalized)) resolved.add(normalized);
  }
  return resolved.isEmpty ? const <String>['center'] : resolved;
}

/// `SurfacePriorities.name` — blank and absent both mean `status`.
String glossSurfaceEffectivePriority(String? authored) {
  final String normalized = (authored ?? '').trim().toLowerCase();
  if (normalized.isEmpty) return glossSurfaceDefaultPriority;
  return glossSurfacePriorities.contains(normalized)
      ? normalized
      : glossSurfaceDefaultPriority;
}

/// `Presentation.normalizeProgress` — the expression with its optional
/// `{{ }}` wrapper removed, or null when the file named none.
String? glossSurfaceProgressSource(String? authored) {
  final String normalized = (authored ?? '').trim();
  if (normalized.isEmpty) return null;
  if (normalized.startsWith('{{') && normalized.endsWith('}}')) {
    final String inner = normalized
        .substring(2, normalized.length - 2)
        .trim();
    return inner.isEmpty ? '' : inner;
  }
  return normalized;
}

String? _effectiveName(String? authored, List<String> allowed, String fallback) {
  final String normalized = (authored ?? '').trim().toLowerCase();
  if (normalized.isEmpty) return fallback;
  return allowed.contains(normalized) ? normalized : fallback;
}

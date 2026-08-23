/// Mirror of Gloss `HologramDoc.java` — the world-anchored hologram document:
///
/// ```json
/// {
///   "schemaVersion": 1,
///   "revision": 1,
///   "anchor": {"world": "world", "position": [0.0, 0.0, 0.0]},
///   "lines": ["&dNew hologram"],
///   "seeThrough": true,
///   "billboard": "CENTER",
///   "yaw": 0.0,
///   "pitch": 0.0
/// }
/// ```
///
/// `billboard`, `yaw` and `pitch` are optional and default to `CENTER`, 0 and
/// 0, which is exactly what the plugin did before they existed
/// (`HologramDoc.java:41-43`), so a file written without them keeps rendering
/// the way it does now and this model re-emits it unchanged.
///
/// The Java side parses through `BukkitJson.GSON` (lenient, serializeNulls,
/// `Vector` as a strict `[x, y, z]` array, `SingleCollectionTypeFactory`); the
/// document id is the file path under `plugins/Gloss/holograms/` and never a
/// JSON key. Unknown keys are preserved through `extras` + `absentKeys` like
/// every other model in this directory, so a round-trip never drops what a
/// newer plugin build may have written.
library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

/// True when [json] has the shape of a Gloss hologram document: the versioned
/// envelope plus the `anchor` object no other kind carries. Routing only —
/// full checking is `validateHologramDoc`'s job.
bool looksLikeHologramDoc(Object? json) {
  if (json is! Map) return false;
  return json['schemaVersion'] is num &&
      json['anchor'] is Map &&
      !json.containsKey('components') &&
      !json.containsKey('elements');
}

GlossHologramDoc decodeGlossHologramDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': e.message,
    });
  }
  return GlossHologramDoc.fromJson(raw);
}

String encodeGlossHologramDoc(GlossHologramDoc doc) =>
    huiWriteJson(doc.toJson());

GlossHologramDoc cloneGlossHologramDoc(GlossHologramDoc doc) =>
    GlossHologramDoc.fromJson(huiDeepCopy(doc.toJson()));

const Set<String> _docKnown = <String>{
  'schemaVersion',
  'revision',
  'anchor',
  'lines',
  'seeThrough',
  'billboard',
  'yaw',
  'pitch',
};

/// The four `Display.Billboard` names `HologramDoc` accepts, in the uppercase
/// spelling its constructor normalises to; anything else makes the plugin
/// reject the whole file (`HologramDoc.java:16,63-70`).
const List<String> glossHologramBillboards = <String>[
  'CENTER',
  'FIXED',
  'HORIZONTAL',
  'VERTICAL',
];

/// What a document without a `billboard` key gets, and what every hologram
/// rendered before the key existed used.
const String glossHologramDefaultBillboard = 'CENTER';

/// `HologramDoc.MAX_YAW_DEGREES` (`HologramDoc.java:18`).
const double glossHologramMaxYawDegrees = 180;

/// `HologramDoc.MAX_PITCH_DEGREES` (`HologramDoc.java:19`).
const double glossHologramMaxPitchDegrees = 90;

const Set<String> _anchorKnown = <String>{'world', 'position'};

/// `HologramDoc.Anchor`: the world name plus the `[x, y, z]` position.
///
/// [positionRaw] is whatever JSON value the document carried, re-emitted
/// verbatim so an invalid shape (which the plugin would reject —
/// `BukkitTypeAdapters.VECTOR` reads exactly three doubles) survives the
/// round-trip for the author to fix. [setPosition] writes the canonical
/// triple.
final class GlossHologramAnchor {
  GlossHologramAnchor({
    this.world = '',
    Object? positionRaw,
    Map<String, dynamic>? extras,
    Set<String>? absentKeys,
  }) : positionRaw = positionRaw ?? const <num>[0, 0, 0],
       extras = extras ?? <String, dynamic>{},
       absentKeys = absentKeys ?? <String>{};

  String world;
  Object? positionRaw;
  Map<String, dynamic> extras;
  Set<String> absentKeys;

  /// The anchor as a length-3 triple, zero-padded when the raw shape is not
  /// one — the renderable reading of [positionRaw], never its replacement.
  List<double> get position {
    final Object? raw = positionRaw;
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

  /// True when [positionRaw] would pass the plugin's strict vector adapter:
  /// exactly three finite numbers.
  bool get positionIsValidTriple {
    final Object? raw = positionRaw;
    if (raw is! List || raw.length != 3) return false;
    for (final Object? value in raw) {
      if (value is! num || !value.toDouble().isFinite) return false;
    }
    return true;
  }

  void setPosition(double x, double y, double z) {
    positionRaw = <num>[x, y, z];
    absentKeys.remove('position');
  }

  static GlossHologramAnchor fromJson(Object? raw) {
    if (raw is! Map) {
      return GlossHologramAnchor(absentKeys: <String>{'world', 'position'});
    }
    final Map<String, dynamic> map = huiReadObject(raw, r'$.anchor');
    return GlossHologramAnchor(
      world: huiReadString(map, 'world'),
      positionRaw: huiDeepCopy(map['position']),
      extras: huiCollectExtras(map, _anchorKnown),
      absentKeys: <String>{
        if (map['world'] == null) 'world',
        if (map['position'] == null) 'position',
      },
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{};
    if (!absentKeys.contains('world') || world.isNotEmpty) {
      out['world'] = world;
    }
    if (!absentKeys.contains('position') || positionRaw != null) {
      out['position'] = huiDeepCopy(positionRaw);
    }
    return huiMergeExtras(out, extras);
  }

  GlossHologramAnchor copy() => GlossHologramAnchor(
    world: world,
    positionRaw: huiDeepCopy(positionRaw),
    extras: huiDeepCopyMap(extras),
    absentKeys: Set<String>.of(absentKeys),
  );
}

final class GlossHologramDoc extends GlossDoc {
  GlossHologramDoc({
    super.schemaVersion = glossCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    GlossHologramAnchor? anchor,
    List<String>? lines,
    this.seeThrough = true,
    this.billboard = glossHologramDefaultBillboard,
    this.yaw = 0,
    this.pitch = 0,
    Map<String, dynamic>? extras,
    Set<String>? absentKeys,
  }) : anchor = anchor ?? GlossHologramAnchor(),
       lines = lines ?? <String>[],
       extras = extras ?? <String, dynamic>{},
       absentKeys = absentKeys ?? <String>{};

  GlossHologramAnchor anchor;

  /// Hologram text, one entry per line. The plugin joins them with `\n` into
  /// a single `TextDisplay` (`PersistentHologram.java:594-609`) after running
  /// each through the text pipeline. May legally be empty
  /// (`HologramDoc.copyLines` accepts null as an empty list).
  List<String> lines;
  bool seeThrough;

  /// Which axes the entity is allowed to turn on to face a viewer, uppercased
  /// on read the way `HologramDoc.requireBillboard` uppercases it. Only
  /// `FIXED` leaves BOTH axes alone, and only then do [yaw] and [pitch]
  /// decide the whole pose; `VERTICAL` keeps [pitch], `HORIZONTAL` keeps
  /// [yaw], and `CENTER` keeps neither.
  String billboard;

  /// Entity yaw in degrees, -180 to 180, in Minecraft's convention: 0 faces
  /// south (+Z) and increasing yaw turns clockwise seen from above. Ignored
  /// on the axes the [billboard] mode turns.
  double yaw;

  /// Entity pitch in degrees, -90 to 90, positive tipping the face downward.
  /// Ignored on the axes the [billboard] mode turns.
  double pitch;

  /// True when the document carried an `anchor` object at all — Gson leaves
  /// the record field null without one, which `HologramDoc`'s constructor
  /// rejects (`HologramDoc.java:38`).
  bool anchorPresent = true;

  Map<String, dynamic> extras;
  Set<String> absentKeys;

  static GlossHologramDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'hologram');
    final Object? anchorRaw = map['anchor'];
    return GlossHologramDoc(
      schemaVersion: glossCurrentSchemaVersion,
      revision: glossReadRevision(map),
      anchor: GlossHologramAnchor.fromJson(anchorRaw),
      lines: glossReadStringList(map['lines']),
      seeThrough: map['seeThrough'] is bool ? map['seeThrough'] as bool : true,
      billboard: huiReadString(
        map,
        'billboard',
        fallback: glossHologramDefaultBillboard,
      ).trim().toUpperCase(),
      yaw: huiReadDouble(map, 'yaw'),
      pitch: huiReadDouble(map, 'pitch'),
      extras: huiCollectExtras(map, _docKnown),
      absentKeys: <String>{
        if (map['revision'] == null) 'revision',
        if (map['lines'] == null) 'lines',
        if (map['seeThrough'] == null) 'seeThrough',
        if (map['billboard'] == null) 'billboard',
        if (map['yaw'] == null) 'yaw',
        if (map['pitch'] == null) 'pitch',
      },
    )..anchorPresent = anchorRaw is Map;
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{
      'schemaVersion': schemaVersion,
      if (!absentKeys.contains('revision')) 'revision': revision,
      if (anchorPresent) 'anchor': anchor.toJson(),
      if (!absentKeys.contains('lines') || lines.isNotEmpty)
        'lines': List<String>.of(lines),
      if (!absentKeys.contains('seeThrough') || !seeThrough)
        'seeThrough': seeThrough,
      if (!absentKeys.contains('billboard') ||
          billboard != glossHologramDefaultBillboard)
        'billboard': billboard,
      if (!absentKeys.contains('yaw') || yaw != 0) 'yaw': yaw,
      if (!absentKeys.contains('pitch') || pitch != 0) 'pitch': pitch,
    };
    return huiMergeExtras(out, extras);
  }

  GlossHologramDoc copy() {
    final GlossHologramDoc copied = GlossHologramDoc(
      schemaVersion: schemaVersion,
      revision: revision,
      anchor: anchor.copy(),
      lines: List<String>.of(lines),
      seeThrough: seeThrough,
      billboard: billboard,
      yaw: yaw,
      pitch: pitch,
      extras: huiDeepCopyMap(extras),
      absentKeys: Set<String>.of(absentKeys),
    );
    copied.anchorPresent = anchorPresent;
    return copied;
  }
}

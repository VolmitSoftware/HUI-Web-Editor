library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'gloss_hologram_box.dart';
import 'hui_icons.dart';
import 'json_codec.dart';
import 'particle_layer.dart';

const int glossHologramCurrentSchemaVersion = 3;

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
  'style',
  'box',
  'yaw',
  'pitch',
  'particleLayers',
};

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
    super.schemaVersion = glossHologramCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    GlossHologramAnchor? anchor,
    List<String>? lines,
    HuiIconStyle? style,
    GlossHologramBox? box,
    this.yaw = 0,
    this.pitch = 0,
    List<GlossParticleLayer>? particleLayers,
    Map<String, dynamic>? extras,
    Set<String>? absentKeys,
  }) : style = style ?? defaultHologramDisplayStyle(),
       box = box ?? GlossHologramBox(),
       anchor = anchor ?? GlossHologramAnchor(),
       lines = lines ?? <String>[],
       particleLayers = particleLayers ?? <GlossParticleLayer>[],
       extras = extras ?? <String, dynamic>{},
       absentKeys = absentKeys ?? <String>{};

  GlossHologramAnchor anchor;

  /// Hologram text, one entry per line. The plugin joins them with `\n` into
  /// a single `TextDisplay` (`PersistentHologram.java:594-609`) after running
  /// each through the text pipeline. May legally be empty
  /// (`HologramDoc.copyLines` accepts null as an empty list).
  List<String> lines;
  bool stylePresent = true;
  bool boxPresent = true;
  HuiIconStyle style;
  GlossHologramBox box;

  /// Entity yaw in degrees, -180 to 180, in Minecraft's convention: 0 faces
  /// south (+Z) and increasing yaw turns clockwise seen from above. Ignored
  /// on the axes the [style.billboard] mode turns.
  double yaw;

  /// Entity pitch in degrees, -90 to 90, positive tipping the face downward.
  /// Ignored on the axes the [style.billboard] mode turns.
  double pitch;
  List<GlossParticleLayer> particleLayers;
  bool particleLayersPresent = false;

  /// True when the document carried an `anchor` object at all — Gson leaves
  /// the record field null without one, which `HologramDoc`'s constructor
  /// rejects (`HologramDoc.java:38`).
  bool anchorPresent = true;

  Map<String, dynamic> extras;
  Set<String> absentKeys;

  static GlossHologramDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(
      map,
      'hologram',
      expected: glossHologramCurrentSchemaVersion,
    );
    final Object? anchorRaw = map['anchor'];
    final GlossHologramDoc doc = GlossHologramDoc(
      schemaVersion: glossHologramCurrentSchemaVersion,
      revision: glossReadRevision(map),
      anchor: GlossHologramAnchor.fromJson(anchorRaw),
      lines: glossReadStringList(map['lines']),
      style:
          HuiIconStyle.fromJsonOrNull(map['style']) ??
          defaultHologramDisplayStyle(),
      box: GlossHologramBox.fromJson(map['box']),
      yaw: huiReadDouble(map, 'yaw'),
      pitch: huiReadDouble(map, 'pitch'),
      particleLayers: glossReadParticleLayers(map['particleLayers']),
      extras: huiCollectExtras(map, _docKnown),
      absentKeys: <String>{
        if (map['revision'] == null) 'revision',
        if (map['lines'] == null) 'lines',
        if (map['yaw'] == null) 'yaw',
        if (map['pitch'] == null) 'pitch',
      },
    );
    doc.anchorPresent = anchorRaw is Map;
    doc.stylePresent = map.containsKey('style');
    doc.boxPresent = map.containsKey('box');
    doc.particleLayersPresent = map.containsKey('particleLayers');
    return doc;
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{
      'schemaVersion': schemaVersion,
      if (!absentKeys.contains('revision')) 'revision': revision,
      if (anchorPresent) 'anchor': anchor.toJson(),
      if (!absentKeys.contains('lines') || lines.isNotEmpty)
        'lines': List<String>.of(lines),
      if (stylePresent ||
          jsonEncode(style.toJson()) !=
              jsonEncode(defaultHologramDisplayStyle().toJson()))
        'style': style.toJson(),
      if (boxPresent ||
          jsonEncode(box.toJson()) != jsonEncode(GlossHologramBox().toJson()))
        'box': box.toJson(),
      if (!absentKeys.contains('yaw') || yaw != 0) 'yaw': yaw,
      if (!absentKeys.contains('pitch') || pitch != 0) 'pitch': pitch,
      if (particleLayersPresent || particleLayers.isNotEmpty)
        'particleLayers': glossWriteParticleLayers(particleLayers),
    };
    return huiMergeExtras(out, extras);
  }

  GlossHologramDoc copy() {
    final GlossHologramDoc copied = GlossHologramDoc(
      schemaVersion: schemaVersion,
      revision: revision,
      anchor: anchor.copy(),
      lines: List<String>.of(lines),
      style: style.copy(),
      box: box.copy(),
      yaw: yaw,
      pitch: pitch,
      particleLayers: glossCopyParticleLayers(particleLayers),
      extras: huiDeepCopyMap(extras),
      absentKeys: Set<String>.of(absentKeys),
    );
    copied.anchorPresent = anchorPresent;
    copied.stylePresent = stylePresent;
    copied.boxPresent = boxPresent;
    copied.particleLayersPresent = particleLayersPresent;
    return copied;
  }
}

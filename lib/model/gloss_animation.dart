/// Mirror of Gloss `AnimationDoc.java` — the text-animation document:
///
/// ```json
/// {
///   "schemaVersion": 1,
///   "revision": 1,
///   "mode": "ascend",
///   "frameIntervalMs": 500,
///   "frames": ["&c", "&6", "&a", "&b"]
/// }
/// ```
///
/// `mode` is one of `ascend | descend | ascend_descend | random`
/// (`AnimationMode.java`, lowercase on the wire); `frameIntervalMs` is
/// silently clamped by the plugin into `1..60000`
/// (`AnimationDoc.java:13-14,20`) — the editor preserves the written value
/// and surfaces the clamp as a validation warning instead; `frames` must be
/// non-empty for the plugin to accept the file. The document id is the file
/// path under `plugins/Gloss/animations/`, which is also the id text
/// functions reference as `|animation.<id>|`.
library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

/// `AnimationMode`, lowercase as serialized.
const List<String> glossAnimationModes = <String>[
  'ascend',
  'descend',
  'ascend_descend',
  'random',
];

/// `AnimationDoc.MIN_FRAME_INTERVAL_MS` / `MAX_FRAME_INTERVAL_MS`.
const int glossMinFrameIntervalMs = 1;
const int glossMaxFrameIntervalMs = 60000;

/// True when [json] has the shape of a Gloss animation document: the
/// versioned envelope plus the `frames` list no other kind carries.
bool looksLikeAnimationDoc(Object? json) {
  if (json is! Map) return false;
  return json['schemaVersion'] is num &&
      json.containsKey('frames') &&
      !json.containsKey('anchor') &&
      !json.containsKey('components') &&
      !json.containsKey('elements');
}

GlossAnimationDoc decodeGlossAnimationDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    throw HuiFormatException('Invalid JSON: ${e.message}', r'$');
  }
  return GlossAnimationDoc.fromJson(raw);
}

String encodeGlossAnimationDoc(GlossAnimationDoc doc) =>
    huiWriteJson(doc.toJson());

GlossAnimationDoc cloneGlossAnimationDoc(GlossAnimationDoc doc) =>
    GlossAnimationDoc.fromJson(huiDeepCopy(doc.toJson()));

const Set<String> _docKnown = <String>{
  'schemaVersion',
  'revision',
  'mode',
  'frameIntervalMs',
  'frames',
};

final class GlossAnimationDoc extends GlossDoc {
  GlossAnimationDoc({
    super.schemaVersion = glossCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    this.mode = 'ascend',
    this.frameIntervalMs = 500,
    List<String>? frames,
    Map<String, dynamic>? extras,
    Set<String>? absentKeys,
  }) : frames = frames ?? <String>[],
       extras = extras ?? <String, dynamic>{},
       absentKeys = absentKeys ?? <String>{};

  /// As written. The plugin lowercases before checking and rejects the whole
  /// file on an unknown mode (`AnimationDoc.requireMode`); the editor keeps
  /// the text and lets validation report it.
  String mode;

  /// As written; see [effectiveFrameIntervalMs] for what the plugin runs.
  int frameIntervalMs;

  List<String> frames;
  Map<String, dynamic> extras;
  Set<String> absentKeys;

  /// The interval after the plugin's silent clamp into
  /// `1..60000` (`AnimationDoc.java:20`).
  int get effectiveFrameIntervalMs =>
      frameIntervalMs.clamp(glossMinFrameIntervalMs, glossMaxFrameIntervalMs);

  /// [mode] normalized the way `AnimationDoc.requireMode` does, or null when
  /// the plugin would reject it.
  String? get normalizedMode {
    final String lowered = mode.trim().toLowerCase();
    return glossAnimationModes.contains(lowered) ? lowered : null;
  }

  static GlossAnimationDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'animation');
    return GlossAnimationDoc(
      schemaVersion: glossCurrentSchemaVersion,
      revision: glossReadRevision(map),
      mode: huiReadString(map, 'mode'),
      frameIntervalMs: huiReadInt(map, 'frameIntervalMs', fallback: 0),
      frames: glossReadStringList(map['frames']),
      extras: huiCollectExtras(map, _docKnown),
      absentKeys: <String>{
        if (map['revision'] == null) 'revision',
        if (map['mode'] == null) 'mode',
        if (map['frameIntervalMs'] == null) 'frameIntervalMs',
        if (map['frames'] == null) 'frames',
      },
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{
      'schemaVersion': schemaVersion,
      if (!absentKeys.contains('revision')) 'revision': revision,
      if (!absentKeys.contains('mode') || mode.isNotEmpty) 'mode': mode,
      if (!absentKeys.contains('frameIntervalMs') || frameIntervalMs != 0)
        'frameIntervalMs': frameIntervalMs,
      if (!absentKeys.contains('frames') || frames.isNotEmpty)
        'frames': List<String>.of(frames),
    };
    return huiMergeExtras(out, extras);
  }

  GlossAnimationDoc copy() => GlossAnimationDoc(
    schemaVersion: schemaVersion,
    revision: revision,
    mode: mode,
    frameIntervalMs: frameIntervalMs,
    frames: List<String>.of(frames),
    extras: huiDeepCopyMap(extras),
    absentKeys: Set<String>.of(absentKeys),
  );
}

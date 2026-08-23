/// Mirror of Gloss `EmojiDoc.java` — one chat emoji per file:
///
/// ```json
/// {
///   "schemaVersion": 1,
///   "revision": 1,
///   "trigger": "<3",
///   "emoji": "U+2764;",
///   "enabled": true
/// }
/// ```
///
/// The document id is the file path under `plugins/Gloss/emoji/` and becomes
/// the chat token `:<id>:` (`EmojiEntry.token`); `trigger` is an optional
/// second spelling replaced the same way (`EmojiReplacer.apply`). The `emoji`
/// value may be a literal glyph or `U+XXXX;` escapes, resolved once at load
/// through `UnicodeText.parse` (`EmojiService.rebuild`) — [glossParseUnicodeText]
/// is that parser, character for character. The Java record rejects a blank
/// `emoji` (`EmojiDoc.java:14-16`); this model decodes it leniently and
/// leaves the report to `validateEmojiDoc`, per the shared envelope rule in
/// `gloss_doc.dart`.
library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

/// True when [json] has the shape of a Gloss emoji document: the versioned
/// envelope plus the `emoji` key no other kind carries. Routing only — full
/// checking is `validateEmojiDoc`'s job.
bool looksLikeEmojiDoc(Object? json) {
  if (json is! Map) return false;
  return json['schemaVersion'] is num &&
      json.containsKey('emoji') &&
      !json.containsKey('anchor') &&
      !json.containsKey('frames') &&
      !json.containsKey('entries') &&
      !json.containsKey('components') &&
      !json.containsKey('elements');
}

GlossEmojiDoc decodeGlossEmojiDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': e.message,
    });
  }
  return GlossEmojiDoc.fromJson(raw);
}

String encodeGlossEmojiDoc(GlossEmojiDoc doc) => huiWriteJson(doc.toJson());

GlossEmojiDoc cloneGlossEmojiDoc(GlossEmojiDoc doc) =>
    GlossEmojiDoc.fromJson(huiDeepCopy(doc.toJson()));

const Set<String> _docKnown = <String>{
  'schemaVersion',
  'revision',
  'trigger',
  'emoji',
  'enabled',
};

final class GlossEmojiDoc extends GlossDoc {
  GlossEmojiDoc({
    super.schemaVersion = glossCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    this.trigger = '',
    this.emoji = '',
    this.enabled = true,
    Map<String, dynamic>? extras,
    Set<String>? absentKeys,
  }) : extras = extras ?? <String, dynamic>{},
       absentKeys = absentKeys ?? <String>{};

  /// Optional second spelling replaced in chat, e.g. `<3`. A null in the
  /// file is `""` (`EmojiDoc.java:13`), and a blank trigger means the token
  /// `:<id>:` is the only spelling (`EmojiEntry.hasTrigger`).
  String trigger;

  /// A literal glyph or `U+XXXX;` escapes; see [resolvedGlyph]. The plugin
  /// rejects the file when this is blank (`EmojiDoc.java:14-16`).
  String emoji;

  /// A disabled emoji stays listed but is never substituted
  /// (`EmojiReplacer` constructor filters on `enabled`). A file that omits
  /// the key is ENABLED — `EmojiDoc.java` defaults a null wrapper to TRUE in
  /// its compact constructor.
  bool enabled;

  Map<String, dynamic> extras;
  Set<String> absentKeys;

  /// [emoji] through `UnicodeText.parse` — what the replacer actually
  /// inserts into chat.
  String get resolvedGlyph => glossParseUnicodeText(emoji);

  static GlossEmojiDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'emoji');
    return GlossEmojiDoc(
      schemaVersion: glossCurrentSchemaVersion,
      revision: glossReadRevision(map),
      trigger: huiReadString(map, 'trigger'),
      emoji: huiReadString(map, 'emoji'),
      enabled: map['enabled'] == null ? true : huiReadBool(map, 'enabled'),
      extras: huiCollectExtras(map, _docKnown),
      absentKeys: <String>{
        if (map['revision'] == null) 'revision',
        if (map['trigger'] == null) 'trigger',
        if (map['emoji'] == null) 'emoji',
        if (map['enabled'] == null) 'enabled',
      },
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{
      'schemaVersion': schemaVersion,
      if (!absentKeys.contains('revision')) 'revision': revision,
      if (!absentKeys.contains('trigger') || trigger.isNotEmpty)
        'trigger': trigger,
      if (!absentKeys.contains('emoji') || emoji.isNotEmpty) 'emoji': emoji,
      if (!absentKeys.contains('enabled') || !enabled) 'enabled': enabled,
    };
    return huiMergeExtras(out, extras);
  }

  GlossEmojiDoc copy() => GlossEmojiDoc(
    schemaVersion: schemaVersion,
    revision: revision,
    trigger: trigger,
    emoji: emoji,
    enabled: enabled,
    extras: huiDeepCopyMap(extras),
    absentKeys: Set<String>.of(absentKeys),
  );
}

// ---------------------------------------------------------------------------
// UnicodeText.parse mirror
// ---------------------------------------------------------------------------

/// `UnicodeText.parse`, character for character: `U+<hex>;` sequences become
/// their code points, everything else passes through. An invalid or
/// out-of-range escape that WAS terminated renders as `?`
/// (`UnicodeText.appendCodepoint`); an unterminated tail renders as its code
/// point when the hex is valid and stays literal (`U+<hex>`) when it is not
/// (`UnicodeText.flushTail`).
String glossParseUnicodeText(String text) {
  if (text.isEmpty) return '';
  if (!text.contains('U')) return text;

  final int length = text.length;
  final StringBuffer out = StringBuffer();
  final StringBuffer buffer = StringBuffer();
  bool reading = false;
  for (int i = 0; i < length; i++) {
    final String current = text[i];
    if (reading) {
      if (current == ';' && buffer.isNotEmpty) {
        reading = false;
        _appendCodepoint(out, buffer.toString());
        buffer.clear();
      } else {
        buffer.write(current);
      }
      continue;
    }

    if (current == 'U' && i + 1 < length && text[i + 1] == '+') {
      i++;
      buffer.clear();
      reading = true;
      continue;
    }

    out.write(current);
  }

  if (reading) {
    final String hex = buffer.toString();
    final String? parsed = _codepointOrNull(hex);
    if (parsed != null) {
      out.write(parsed);
    } else {
      out.write('U+$hex');
    }
  }

  return out.toString();
}

/// True when [text] resolves without any `?` fallback or literal tail — the
/// validation-side answer to "are all the escapes valid".
bool glossUnicodeTextIsClean(String text) {
  if (text.isEmpty) return true;
  if (!text.contains('U')) return true;

  final int length = text.length;
  final StringBuffer buffer = StringBuffer();
  bool reading = false;
  for (int i = 0; i < length; i++) {
    final String current = text[i];
    if (reading) {
      if (current == ';' && buffer.isNotEmpty) {
        reading = false;
        if (_codepointOrNull(buffer.toString()) == null) return false;
        buffer.clear();
      } else {
        buffer.write(current);
      }
      continue;
    }
    if (current == 'U' && i + 1 < length && text[i + 1] == '+') {
      i++;
      buffer.clear();
      reading = true;
      continue;
    }
  }
  if (reading && _codepointOrNull(buffer.toString()) == null) return false;
  return true;
}

/// `UnicodeText.appendCodepoint`: the code point, or `?` when
/// `Integer.parseInt(hex, 16)` or `Character.toChars` would throw.
void _appendCodepoint(StringBuffer out, String hex) {
  final String? parsed = _codepointOrNull(hex);
  out.write(parsed ?? '?');
}

/// `UnicodeText.codepointOrNull`: `Character.toChars(Integer.parseInt(hex,
/// 16))` as a string, or null when either call would throw — an empty or
/// non-hex string, a value past `Integer.MAX_VALUE`, or a code point outside
/// `0..0x10FFFF`.
String? _codepointOrNull(String hex) {
  if (hex.isEmpty) return null;
  // Integer.parseInt accepts an optional sign; anything else non-hex throws.
  final int? value = int.tryParse(hex, radix: 16);
  if (value == null || value > 0x7FFFFFFF || value < -0x80000000) return null;
  if (value < 0 || value > 0x10FFFF) return null;
  return String.fromCharCode(value);
}

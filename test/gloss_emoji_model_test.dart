/// GlossEmojiDoc: round-trips, the Gson realities (a missing `enabled` is
/// false), the `UnicodeText.parse` mirror character for character, and the
/// shape check import routing relies on.
library;

import 'dart:convert';

import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

const String _heart = '''
{
  "schemaVersion": 1,
  "revision": 3,
  "trigger": "<3",
  "emoji": "U+2764;",
  "enabled": true
}
''';

void main() {
  group('decode', () {
    test('reads the full document', () {
      final GlossEmojiDoc doc = decodeGlossEmojiDoc(_heart);
      expect(doc.revision, 3);
      expect(doc.trigger, '<3');
      expect(doc.emoji, 'U+2764;');
      expect(doc.enabled, isTrue);
      expect(doc.resolvedGlyph, '❤');
    });

    test('rejects a wrong or missing schemaVersion', () {
      expect(
        () => decodeGlossEmojiDoc('{"schemaVersion": 2, "emoji": "x"}'),
        throwsA(isA<HuiFormatException>()),
      );
      expect(
        () => decodeGlossEmojiDoc('{"emoji": "x"}'),
        throwsA(isA<HuiFormatException>()),
      );
    });

    test('a missing enabled is false — Gson primitive default', () {
      final GlossEmojiDoc doc = decodeGlossEmojiDoc(
        '{"schemaVersion": 1, "revision": 1, "emoji": "x"}',
      );
      expect(doc.enabled, isFalse);
      expect(doc.trigger, isEmpty);
    });

    test('a blank emoji decodes leniently for repair', () {
      final GlossEmojiDoc doc = decodeGlossEmojiDoc(
        '{"schemaVersion": 1, "revision": 1, "trigger": "", "emoji": "", '
        '"enabled": true}',
      );
      expect(doc.emoji, isEmpty);
    });
  });

  group('round-trip', () {
    test('decode-encode is stable and matches the source tree', () {
      final GlossEmojiDoc doc = decodeGlossEmojiDoc(_heart);
      final String encoded = encodeGlossEmojiDoc(doc);
      expect(encodeGlossEmojiDoc(decodeGlossEmojiDoc(encoded)), encoded);
      expect(jsonDecode(encoded), jsonDecode(_heart));
    });

    test('unknown keys survive after the known ones', () {
      final GlossEmojiDoc doc = decodeGlossEmojiDoc(
        '{"schemaVersion": 1, "revision": 1, "emoji": "x", '
        '"enabled": true, "category": "faces"}',
      );
      doc.trigger = ':-)';
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossEmojiDoc(doc)) as Map<String, dynamic>;
      expect(out['category'], 'faces');
      expect(out['trigger'], ':-)');
    });
  });

  group('glossParseUnicodeText mirrors UnicodeText.parse', () {
    test('plain text and text without U pass through untouched', () {
      expect(glossParseUnicodeText(''), '');
      expect(glossParseUnicodeText('hello'), 'hello');
      expect(glossParseUnicodeText('no escapes + here;'), 'no escapes + here;');
    });

    test('terminated escapes become their code points', () {
      expect(glossParseUnicodeText('U+2764;'), '❤');
      expect(glossParseUnicodeText('U+2713;'), '✓');
      expect(glossParseUnicodeText('a U+2764; b'), 'a ❤ b');
      expect(glossParseUnicodeText('U+2764;U+2713;'), '❤✓');
      // Supplementary plane: one code point, two UTF-16 units.
      expect(glossParseUnicodeText('U+1F600;'), '😀');
    });

    test('a bad terminated escape renders as ? (appendCodepoint)', () {
      expect(glossParseUnicodeText('U+ZZZZ;'), '?');
      expect(glossParseUnicodeText('U+110000;'), '?',
          reason: 'past the last code point');
      // "U+" then ";" with an empty buffer keeps reading: the ";" and "y"
      // join the buffer, and the second ";" terminates ";y" — not hex, so ?.
      expect(glossParseUnicodeText('x U+;y;'), 'x ?');
    });

    test('an unterminated tail resolves when valid, stays literal when not '
        '(flushTail)', () {
      expect(glossParseUnicodeText('U+2764'), '❤');
      expect(glossParseUnicodeText('U+ZZZ'), 'U+ZZZ');
      expect(glossParseUnicodeText('U+'), 'U+');
    });

    test('a lone U before the end never opens an escape', () {
      expect(glossParseUnicodeText('U'), 'U');
      expect(glossParseUnicodeText('Ux'), 'Ux');
      expect(glossParseUnicodeText('SUP'), 'SUP');
    });

    test('glossUnicodeTextIsClean agrees with the parse fallbacks', () {
      expect(glossUnicodeTextIsClean('plain'), isTrue);
      expect(glossUnicodeTextIsClean('U+2764;'), isTrue);
      expect(glossUnicodeTextIsClean('U+2764'), isTrue);
      expect(glossUnicodeTextIsClean('U+ZZZZ;'), isFalse);
      expect(glossUnicodeTextIsClean('U+ZZZ'), isFalse);
      expect(glossUnicodeTextIsClean('U+110000;'), isFalse);
    });
  });

  group('shape check', () {
    test('claims emoji documents and nothing else', () {
      expect(looksLikeEmojiDoc(jsonDecode(_heart)), isTrue);
      expect(
        looksLikeEmojiDoc(<String, Object?>{
          'schemaVersion': 1,
          'frames': <String>['a'],
          'emoji': 'x',
        }),
        isFalse,
        reason: 'frames marks an animation',
      );
      expect(looksLikeEmojiDoc(<String, Object?>{'emoji': 'x'}), isFalse);
      // The other Gloss kinds must not claim an emoji document either.
      expect(looksLikeMotdDoc(jsonDecode(_heart)), isFalse);
      expect(looksLikeScoreboardDoc(jsonDecode(_heart)), isFalse);
      expect(looksLikeAnimationDoc(jsonDecode(_heart)), isFalse);
      expect(looksLikeHologramDoc(jsonDecode(_heart)), isFalse);
    });
  });
}

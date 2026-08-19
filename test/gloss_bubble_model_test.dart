/// GlossBubbleStyleDoc: round-trips, the silent clamps as derived accessors,
/// the prefix/offset absence semantics, select normalization, the glob
/// matcher, and the shape check import routing relies on.
library;

import 'dart:convert';

import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

const String _style = '''
{
  "schemaVersion": 1,
  "revision": 2,
  "prefix": "&6",
  "offset": [0.0, 1.2, 0.0],
  "wordWrapChars": 24,
  "lineStaggerTicks": 8,
  "maxAliveMs": 7000,
  "flyAway": true,
  "followPlayer": false,
  "hideOwn": false,
  "select": {
    "worlds": ["world*"],
    "groups": ["vip"],
    "priority": 10
  }
}
''';

void main() {
  group('decode', () {
    test('reads the full document', () {
      final GlossBubbleStyleDoc doc = decodeGlossBubbleStyleDoc(_style);
      expect(doc.revision, 2);
      expect(doc.prefix, '&6');
      expect(doc.offset, <double>[0, 1.2, 0]);
      expect(doc.wordWrapChars, 24);
      expect(doc.lineStaggerTicks, 8);
      expect(doc.maxAliveMs, 7000);
      expect(doc.flyAway, isTrue);
      expect(doc.followPlayer, isFalse);
      expect(doc.hideOwn, isFalse);
      expect(doc.select, isNotNull);
      expect(doc.select!.worlds, <String>['world*']);
      expect(doc.select!.groups, <String>['vip']);
      expect(doc.select!.priority, 10);
    });

    test('rejects a wrong or missing schemaVersion', () {
      expect(
        () => decodeGlossBubbleStyleDoc(
          '{"schemaVersion": 2, "wordWrapChars": 32}',
        ),
        throwsA(isA<HuiFormatException>()),
      );
      expect(
        () => decodeGlossBubbleStyleDoc('{"wordWrapChars": 32}'),
        throwsA(isA<HuiFormatException>()),
      );
    });

    test('missing keys carry the Gson defaults, with select null', () {
      final GlossBubbleStyleDoc doc = decodeGlossBubbleStyleDoc(
        '{"schemaVersion": 1, "revision": 1, "flyAway": true}',
      );
      expect(doc.select, isNull);
      expect(doc.wordWrapChars, 0);
      expect(doc.effectiveWordWrapChars, 8, reason: '0 clamps up to 8');
      expect(doc.maxAliveMs, 0);
      expect(doc.effectiveMaxAliveMs, 500);
      expect(doc.followPlayer, isFalse);
    });
  });

  group('the silent clamps are derived, never destructive', () {
    test('all three numeric fields clamp into their ranges', () {
      final GlossBubbleStyleDoc doc = decodeGlossBubbleStyleDoc(_style)
        ..wordWrapChars = 500
        ..lineStaggerTicks = -3
        ..maxAliveMs = 100000;
      expect(doc.effectiveWordWrapChars, 128);
      expect(doc.effectiveLineStaggerTicks, 0);
      expect(doc.effectiveMaxAliveMs, 60000);
      expect(doc.wordWrapChars, 500, reason: 'the file keeps what was written');
    });

    test('only a MISSING prefix falls to &7 — an explicit "" stays empty', () {
      final GlossBubbleStyleDoc absent = decodeGlossBubbleStyleDoc(
        '{"schemaVersion": 1, "revision": 1}',
      );
      expect(absent.effectivePrefix, '&7');
      final GlossBubbleStyleDoc empty = decodeGlossBubbleStyleDoc(
        '{"schemaVersion": 1, "revision": 1, "prefix": ""}',
      );
      expect(empty.effectivePrefix, '');
    });

    test('an absent offset reads as the plugin default (0, 1, 0)', () {
      final GlossBubbleStyleDoc doc = decodeGlossBubbleStyleDoc(
        '{"schemaVersion": 1, "revision": 1}',
      );
      expect(doc.offset, <double>[0, 1, 0]);
      expect(doc.offsetIsValidTriple, isTrue);
    });

    test('a malformed offset is flagged invalid but preserved', () {
      final GlossBubbleStyleDoc doc = decodeGlossBubbleStyleDoc(
        '{"schemaVersion": 1, "revision": 1, "offset": [1, 2]}',
      );
      expect(doc.offsetIsValidTriple, isFalse);
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossBubbleStyleDoc(doc)) as Map<String, dynamic>;
      expect(out['offset'], <int>[1, 2]);
    });
  });

  group('select normalization is derived', () {
    test('worlds trim and drop blanks, keeping case', () {
      final GlossBubbleSelect select = GlossBubbleSelect(
        worlds: <String>[' World_*', '', '  '],
      );
      expect(select.effectiveWorlds, <String>['World_*']);
    });

    test('groups trim, lowercase and drop blanks', () {
      final GlossBubbleSelect select = GlossBubbleSelect(
        groups: <String>[' VIP', '', 'Mvp '],
      );
      expect(select.effectiveGroups, <String>['vip', 'mvp']);
    });
  });

  group('glossBubbleGlobMatches mirrors BubbleStyles.globMatches', () {
    test('wildcards and literals', () {
      expect(glossBubbleGlobMatches('world*', 'world'), isTrue);
      expect(glossBubbleGlobMatches('world*', 'world_nether'), isTrue);
      expect(glossBubbleGlobMatches('world*', 'my_world'), isFalse);
      expect(glossBubbleGlobMatches('w?rld', 'world'), isTrue);
      expect(glossBubbleGlobMatches('w?rld', 'wrld'), isFalse);
      expect(glossBubbleGlobMatches('*', 'anything'), isTrue);
      expect(glossBubbleGlobMatches('plain', 'plain'), isTrue);
      expect(glossBubbleGlobMatches('plain', 'plainer'), isFalse);
    });

    test('regex metacharacters in the pattern stay literal', () {
      expect(glossBubbleGlobMatches('a.b', 'a.b'), isTrue);
      expect(glossBubbleGlobMatches('a.b', 'axb'), isFalse);
      expect(glossBubbleGlobMatches('w(1)', 'w(1)'), isTrue);
    });
  });

  group('round-trip', () {
    test('decode-encode is stable and matches the source tree', () {
      final GlossBubbleStyleDoc doc = decodeGlossBubbleStyleDoc(_style);
      final String encoded = encodeGlossBubbleStyleDoc(doc);
      expect(
        encodeGlossBubbleStyleDoc(decodeGlossBubbleStyleDoc(encoded)),
        encoded,
      );
      expect(jsonDecode(encoded), jsonDecode(_style));
    });

    test('unknown keys survive at the document and the select level', () {
      const String withExtras = '''
{
  "schemaVersion": 1,
  "revision": 1,
  "wordWrapChars": 32,
  "select": {"worlds": [], "groups": [], "priority": 0, "biomes": ["ocean"]},
  "particles": "hearts"
}
''';
      final GlossBubbleStyleDoc doc = decodeGlossBubbleStyleDoc(withExtras);
      doc.wordWrapChars = 20;
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossBubbleStyleDoc(doc)) as Map<String, dynamic>;
      expect(out['particles'], 'hearts');
      expect(
        (out['select'] as Map<String, dynamic>)['biomes'],
        <String>['ocean'],
      );
      expect(out['wordWrapChars'], 20);
    });
  });

  group('shape check', () {
    test('claims bubble styles and nothing else', () {
      expect(looksLikeBubbleStyleDoc(jsonDecode(_style)), isTrue);
      expect(
        looksLikeBubbleStyleDoc(<String, Object?>{
          'schemaVersion': 1,
          'frames': <String>['a'],
          'maxAliveMs': 5000,
        }),
        isFalse,
        reason: 'frames marks an animation',
      );
      expect(
        looksLikeBubbleStyleDoc(<String, Object?>{'wordWrapChars': 32}),
        isFalse,
      );
      // The other Gloss kinds must not claim a bubble style either.
      expect(looksLikeMotdDoc(jsonDecode(_style)), isFalse);
      expect(looksLikeEmojiDoc(jsonDecode(_style)), isFalse);
      expect(looksLikeScoreboardDoc(jsonDecode(_style)), isFalse);
      expect(looksLikeAnimationDoc(jsonDecode(_style)), isFalse);
      expect(looksLikeHologramDoc(jsonDecode(_style)), isFalse);
    });
  });
}

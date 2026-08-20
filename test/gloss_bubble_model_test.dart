library;

import 'dart:convert';

import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

const String _style = '''
{
  "schemaVersion": 2,
  "revision": 2,
  "prefix": "&6",
  "offset": [0.0, 1.2, 0.0],
  "wordWrapChars": 24,
  "maxAliveMs": 7000,
  "motion": {
    "translation": {"x": "2 * t", "y": "8 * sin(pi * t)", "z": "0"},
    "scale": {"x": "1 - 0.5 * t", "y": "1", "z": "1"},
    "rotation": {"x": "0", "y": "180 * t", "z": "0"},
    "opacity": "remaining"
  },
  "shimmer": {
    "spawn": true,
    "flyAway": false,
    "color": "#AABBCC",
    "width": 5,
    "durationMs": 900,
    "spawnDelayMs": 50,
    "flyAwayLeadMs": 1100
  },
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
    test('reads the full schema-2 document with string expressions', () {
      final GlossBubbleStyleDoc doc = decodeGlossBubbleStyleDoc(_style);
      expect(doc.schemaVersion, 2);
      expect(doc.revision, 2);
      expect(doc.prefix, '&6');
      expect(doc.offset, <double>[0, 1.2, 0]);
      expect(doc.wordWrapChars, 24);
      expect(doc.maxAliveMs, 7000);
      expect(doc.motion.translation.x, '2 * t');
      expect(doc.motion.translation.y, '8 * sin(pi * t)');
      expect(doc.motion.scale.x, '1 - 0.5 * t');
      expect(doc.motion.rotation.y, '180 * t');
      expect(doc.motion.opacity, 'remaining');
      expect(doc.shimmer.spawn, isTrue);
      expect(doc.shimmer.flyAway, isFalse);
      expect(doc.shimmer.effectiveColor, '#aabbcc');
      expect(doc.shimmer.width, 5);
      expect(doc.shimmer.durationMs, 900);
      expect(doc.shimmer.spawnDelayMs, 50);
      expect(doc.shimmer.flyAwayLeadMs, 1100);
      expect(doc.followPlayer, isFalse);
      expect(doc.hideOwn, isFalse);
      expect(doc.select!.worlds, <String>['world*']);
      expect(doc.select!.groups, <String>['vip']);
      expect(doc.select!.priority, 10);
    });

    test('rejects legacy, future, and missing schema versions', () {
      for (final String json in <String>[
        '{"schemaVersion":1,"wordWrapChars":32}',
        '{"schemaVersion":3,"wordWrapChars":32}',
        '{"wordWrapChars":32}',
      ]) {
        expect(
          () => decodeGlossBubbleStyleDoc(json),
          throwsA(isA<HuiFormatException>()),
          reason: json,
        );
      }
    });

    test('rejects numeric motion leaves instead of changing their type', () {
      expect(
        () => decodeGlossBubbleStyleDoc(
          '{"schemaVersion":2,"revision":1,'
          '"motion":{"translation":{"x":0}}}',
        ),
        throwsA(
          isA<HuiFormatException>().having(
            (HuiFormatException failure) => failure.path,
            'path',
            r'$.motion.translation.x',
          ),
        ),
      );
    });

    test('missing motion keys carry the exact runtime defaults', () {
      final GlossBubbleStyleDoc doc = decodeGlossBubbleStyleDoc(
        '{"schemaVersion":2,"revision":1}',
      );
      expect(doc.motion.translation.x, '0');
      expect(
        doc.motion.translation.y,
        '10 * pow(clamp((ageMs - lifetimeMs + 2000) / 2000, 0, 1), 16)',
      );
      expect(doc.motion.translation.z, '0');
      expect(doc.motion.scale.x, '1');
      expect(doc.motion.rotation.z, '0');
      expect(doc.motion.opacity, '1');
      expect(doc.shimmer.spawn, isTrue);
      expect(doc.shimmer.flyAway, isTrue);
      expect(doc.shimmer.color, glossBubbleShimmerDefaultColor);
      expect(doc.shimmer.width, 3);
      expect(doc.shimmer.durationMs, glossBubbleShimmerDefaultDurationMs);
      expect(doc.shimmer.spawnDelayMs, glossBubbleShimmerDefaultSpawnDelayMs);
      expect(doc.shimmer.flyAwayLeadMs, glossBubbleShimmerDefaultFlyAwayLeadMs);
      expect(doc.select, isNull);
    });

    test('drops the retired two-tone edge color when rewriting a style', () {
      final GlossBubbleStyleDoc doc = decodeGlossBubbleStyleDoc(
        '{"schemaVersion":2,"revision":1,"shimmer":{"edgeColor":"#aaaaaa"}}',
      );
      final Map<String, dynamic> shimmer =
          doc.toJson()['shimmer'] as Map<String, dynamic>;
      expect(shimmer, isNot(contains('edgeColor')));
    });
  });

  group('written and effective values', () {
    test('numeric bounds are derived without overwriting source values', () {
      final GlossBubbleStyleDoc doc = decodeGlossBubbleStyleDoc(_style)
        ..wordWrapChars = 500
        ..maxAliveMs = 100000;
      expect(doc.effectiveWordWrapChars, 128);
      expect(doc.effectiveMaxAliveMs, 60000);
      expect(doc.wordWrapChars, 500);
    });

    test('shimmer bounds are derived without overwriting source values', () {
      final GlossBubbleShimmer shimmer = GlossBubbleShimmer(
        color: '#ABCDEF',
        width: 99,
        durationMs: 1,
        spawnDelayMs: -1,
        flyAwayLeadMs: 999999,
      );
      expect(shimmer.effectiveColor, '#abcdef');
      expect(shimmer.effectiveWidth, glossBubbleMaxShimmerWidth);
      expect(shimmer.effectiveDurationMs, glossBubbleMinShimmerDurationMs);
      expect(shimmer.effectiveSpawnDelayMs, 0);
      expect(shimmer.effectiveFlyAwayLeadMs, glossBubbleMaxShimmerOffsetMs);
      expect(shimmer.width, 99);
    });

    test('only a missing prefix falls back to &7', () {
      final GlossBubbleStyleDoc absent = decodeGlossBubbleStyleDoc(
        '{"schemaVersion":2,"revision":1}',
      );
      final GlossBubbleStyleDoc empty = decodeGlossBubbleStyleDoc(
        '{"schemaVersion":2,"revision":1,"prefix":""}',
      );
      expect(absent.effectivePrefix, '&7');
      expect(empty.effectivePrefix, '');
    });

    test('offset defaults, while malformed source survives for validation', () {
      final GlossBubbleStyleDoc absent = decodeGlossBubbleStyleDoc(
        '{"schemaVersion":2,"revision":1}',
      );
      expect(absent.offset, <double>[0, 0.3, 0]);
      final GlossBubbleStyleDoc malformed = decodeGlossBubbleStyleDoc(
        '{"schemaVersion":2,"revision":1,"offset":[1,2]}',
      );
      expect(malformed.offsetIsValidTriple, isFalse);
      final Map<String, dynamic> encoded =
          jsonDecode(encodeGlossBubbleStyleDoc(malformed))
              as Map<String, dynamic>;
      expect(encoded['offset'], <int>[1, 2]);
    });
  });

  group('select normalization', () {
    test('worlds keep case while groups lowercase', () {
      final GlossBubbleSelect select = GlossBubbleSelect(
        worlds: <String>[' World_*', '', '  '],
        groups: <String>[' VIP', '', 'Mvp '],
      );
      expect(select.effectiveWorlds, <String>['World_*']);
      expect(select.effectiveGroups, <String>['vip', 'mvp']);
    });
  });

  group('round-trip', () {
    test('decode-encode is stable and matches the source tree', () {
      final String encoded = encodeGlossBubbleStyleDoc(
        decodeGlossBubbleStyleDoc(_style),
      );
      expect(
        encodeGlossBubbleStyleDoc(decodeGlossBubbleStyleDoc(encoded)),
        encoded,
      );
      expect(jsonDecode(encoded), jsonDecode(_style));
    });

    test(
      'unknown document, select, motion, shimmer, and vector keys survive',
      () {
        const String withExtras = '''
{
  "schemaVersion": 2,
  "revision": 1,
  "wordWrapChars": 32,
  "motion": {
    "translation": {"x": "0", "y": "0", "z": "0", "space": "world"},
    "easing": "custom"
  },
  "shimmer": {"sparkle": "legacy"},
  "select": {"worlds": [], "groups": [], "priority": 0, "biomes": ["ocean"]},
  "particles": "hearts"
}
''';
        final GlossBubbleStyleDoc doc = decodeGlossBubbleStyleDoc(withExtras);
        final Map<String, dynamic> out =
            jsonDecode(encodeGlossBubbleStyleDoc(doc)) as Map<String, dynamic>;
        expect(out['particles'], 'hearts');
        expect((out['select'] as Map<String, dynamic>)['biomes'], <String>[
          'ocean',
        ]);
        expect((out['motion'] as Map<String, dynamic>)['easing'], 'custom');
        expect((out['shimmer'] as Map<String, dynamic>)['sparkle'], 'legacy');
        expect(
          ((out['motion'] as Map<String, dynamic>)['translation']
              as Map<String, dynamic>)['space'],
          'world',
        );
      },
    );
  });

  group('shape and glob behavior', () {
    test('claims bubble styles and excludes other Gloss shapes', () {
      expect(looksLikeBubbleStyleDoc(jsonDecode(_style)), isTrue);
      expect(
        looksLikeBubbleStyleDoc(<String, Object?>{
          'schemaVersion': 2,
          'frames': <String>['a'],
          'maxAliveMs': 5000,
        }),
        isFalse,
      );
      expect(
        looksLikeBubbleStyleDoc(<String, Object?>{'wordWrapChars': 32}),
        isFalse,
      );
      expect(looksLikeMotdDoc(jsonDecode(_style)), isFalse);
      expect(looksLikeEmojiDoc(jsonDecode(_style)), isFalse);
      expect(looksLikeScoreboardDoc(jsonDecode(_style)), isFalse);
      expect(looksLikeAnimationDoc(jsonDecode(_style)), isFalse);
      expect(looksLikeHologramDoc(jsonDecode(_style)), isFalse);
    });

    test(
      'glob matcher treats wildcards specially and regex syntax literally',
      () {
        expect(glossBubbleGlobMatches('world*', 'world_nether'), isTrue);
        expect(glossBubbleGlobMatches('w?rld', 'world'), isTrue);
        expect(glossBubbleGlobMatches('a.b', 'a.b'), isTrue);
        expect(glossBubbleGlobMatches('a.b', 'axb'), isFalse);
      },
    );
  });
}

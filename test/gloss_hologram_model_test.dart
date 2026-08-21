/// GlossHologramDoc: byte-faithful round-trips, unknown-key preservation,
/// the schemaVersion hard-reject and the lenient-everything-else contract.
library;

import 'dart:convert';

import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

const String _baseline = '''
{
  "schemaVersion": 1,
  "revision": 7,
  "anchor": {
    "world": "world_nether",
    "position": [10.5, 64, -3.25]
  },
  "lines": [
    "&dTop",
    "&7Bottom"
  ]
}
''';

void main() {
  group('decode', () {
    test('reads the full document', () {
      final GlossHologramDoc doc = decodeGlossHologramDoc(_baseline);
      expect(doc.schemaVersion, 1);
      expect(doc.revision, 7);
      expect(doc.anchor.world, 'world_nether');
      expect(doc.anchor.position, <double>[10.5, 64, -3.25]);
      expect(doc.anchor.positionIsValidTriple, isTrue);
      expect(doc.lines, <String>['&dTop', '&7Bottom']);
      expect(doc.seeThrough, isTrue);
    });

    test('rejects a wrong schemaVersion like DocumentEnvelope does', () {
      expect(
        () => decodeGlossHologramDoc('{"schemaVersion": 2, "revision": 1}'),
        throwsA(isA<HuiFormatException>()),
      );
    });

    test('rejects a missing schemaVersion — Gson reads 0 and 0 != 1', () {
      expect(
        () => decodeGlossHologramDoc('{"revision": 1, "lines": []}'),
        throwsA(isA<HuiFormatException>()),
      );
    });

    test('rejects malformed JSON', () {
      expect(
        () => decodeGlossHologramDoc('{nope'),
        throwsA(isA<HuiFormatException>()),
      );
    });

    test('is lenient about everything validation owns', () {
      final GlossHologramDoc doc = decodeGlossHologramDoc(
        '{"schemaVersion": 1, "revision": 0, '
        '"anchor": {"world": "", "position": [1, 2]}, "lines": []}',
      );
      expect(doc.revision, 0);
      expect(doc.anchor.world, isEmpty);
      expect(doc.anchor.positionIsValidTriple, isFalse);
      expect(doc.anchor.position, <double>[1, 2, 0]);
    });

    test('a missing anchor is flagged, not defaulted away', () {
      final GlossHologramDoc doc = decodeGlossHologramDoc(
        '{"schemaVersion": 1, "revision": 1, "lines": ["a"]}',
      );
      expect(doc.anchorPresent, isFalse);
      expect(jsonDecode(encodeGlossHologramDoc(doc)), <String, dynamic>{
        'schemaVersion': 1,
        'revision': 1,
        'lines': <String>['a'],
      });
    });

    test(
      'a scalar lines value reads as a one-element list '
      '(SingleCollectionTypeFactory) and null entries become empty strings',
      () {
        expect(
          decodeGlossHologramDoc(
            '{"schemaVersion": 1, "revision": 1, "lines": "solo"}',
          ).lines,
          <String>['solo'],
        );
        expect(
          decodeGlossHologramDoc(
            '{"schemaVersion": 1, "revision": 1, "lines": ["a", null, "b"]}',
          ).lines,
          <String>['a', '', 'b'],
        );
      },
    );
  });

  group('round-trip', () {
    test('decode-encode is stable on the canonical shape', () {
      final GlossHologramDoc doc = decodeGlossHologramDoc(_baseline);
      final String encoded = encodeGlossHologramDoc(doc);
      expect(encodeGlossHologramDoc(decodeGlossHologramDoc(encoded)), encoded);
      expect(jsonDecode(encoded), jsonDecode(_baseline));
    });

    test('an explicit occluded hologram remains occluded', () {
      final GlossHologramDoc doc = decodeGlossHologramDoc(
        _baseline.replaceFirst(
          '"lines": [',
          '"seeThrough": false,\n  "lines": [',
        ),
      );

      expect(doc.seeThrough, isFalse);
      expect(jsonDecode(encodeGlossHologramDoc(doc))['seeThrough'], isFalse);
    });

    test('unknown keys survive at both levels, after the known ones', () {
      const String withExtras = '''
{
  "schemaVersion": 1,
  "revision": 3,
  "future": {"nested": [1, 2, 3]},
  "anchor": {
    "world": "world",
    "position": [0, 0, 0],
    "pitch": 45.0
  },
  "lines": ["x"]
}
''';
      final GlossHologramDoc doc = decodeGlossHologramDoc(withExtras);
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossHologramDoc(doc)) as Map<String, dynamic>;
      expect(out['future'], <String, dynamic>{
        'nested': <int>[1, 2, 3],
      });
      expect((out['anchor'] as Map<String, dynamic>)['pitch'], 45.0);
      // Still preserved through an edit to a known field.
      doc.anchor.world = 'world_the_end';
      final Map<String, dynamic> edited =
          jsonDecode(encodeGlossHologramDoc(doc)) as Map<String, dynamic>;
      expect((edited['anchor'] as Map<String, dynamic>)['pitch'], 45.0);
      expect(
        (edited['anchor'] as Map<String, dynamic>)['world'],
        'world_the_end',
      );
    });

    test('an invalid position shape is re-emitted verbatim', () {
      const String badVector =
          '{"schemaVersion": 1, "revision": 1, '
          '"anchor": {"world": "world", "position": [1, 2]}, "lines": []}';
      final GlossHologramDoc doc = decodeGlossHologramDoc(badVector);
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossHologramDoc(doc)) as Map<String, dynamic>;
      expect((out['anchor'] as Map<String, dynamic>)['position'], <int>[1, 2]);
    });

    test('setPosition writes the canonical triple', () {
      final GlossHologramDoc doc = decodeGlossHologramDoc(_baseline);
      doc.anchor.setPosition(1, 2.5, 3);
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossHologramDoc(doc)) as Map<String, dynamic>;
      expect((out['anchor'] as Map<String, dynamic>)['position'], <num>[
        1,
        2.5,
        3,
      ]);
    });
  });

  group('orientation', () {
    test('defaults to the pre-billboard pose when the keys are absent', () {
      final GlossHologramDoc doc = decodeGlossHologramDoc(_baseline);
      expect(doc.billboard, 'CENTER');
      expect(doc.yaw, 0);
      expect(doc.pitch, 0);
    });

    test('a document without the keys re-encodes byte for byte', () {
      final GlossHologramDoc doc = decodeGlossHologramDoc(_baseline);
      final String encoded = encodeGlossHologramDoc(doc);
      expect(encoded.contains('billboard'), isFalse);
      expect(encoded.contains('yaw'), isFalse);
      expect(encoded.contains('pitch'), isFalse);
      expect(encodeGlossHologramDoc(decodeGlossHologramDoc(encoded)), encoded);
    });

    test('reads and re-emits an authored pose, uppercasing the mode', () {
      final GlossHologramDoc doc = decodeGlossHologramDoc(
        _baseline.replaceFirst(
          '"lines": [',
          '"billboard": " fixed ",\n  "yaw": -135.5,\n  "pitch": 12.25,\n  "lines": [',
        ),
      );
      expect(doc.billboard, 'FIXED');
      expect(doc.yaw, -135.5);
      expect(doc.pitch, 12.25);
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossHologramDoc(doc)) as Map<String, dynamic>;
      expect(out['billboard'], 'FIXED');
      expect(out['yaw'], -135.5);
      expect(out['pitch'], 12.25);
    });

    test('an explicit default is kept, never tidied away', () {
      final GlossHologramDoc doc = decodeGlossHologramDoc(
        _baseline.replaceFirst(
          '"lines": [',
          '"billboard": "CENTER",\n  "yaw": 0,\n  "pitch": 0,\n  "lines": [',
        ),
      );
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossHologramDoc(doc)) as Map<String, dynamic>;
      expect(out.containsKey('billboard'), isTrue);
      expect(out.containsKey('yaw'), isTrue);
      expect(out.containsKey('pitch'), isTrue);
    });

    test('a non-default value written into an absent key still emits', () {
      final GlossHologramDoc doc = decodeGlossHologramDoc(_baseline);
      doc.billboard = 'VERTICAL';
      doc.pitch = -20;
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossHologramDoc(doc)) as Map<String, dynamic>;
      expect(out['billboard'], 'VERTICAL');
      expect(out['pitch'], -20);
      expect(out.containsKey('yaw'), isFalse, reason: 'still absent and 0');
    });

    test('an out-of-range angle survives the round-trip for validation', () {
      final GlossHologramDoc doc = decodeGlossHologramDoc(
        _baseline.replaceFirst('"lines": [', '"pitch": 240,\n  "lines": ['),
      );
      expect(doc.pitch, 240);
      expect(
        (jsonDecode(encodeGlossHologramDoc(doc)) as Map<String, dynamic>)['pitch'],
        240,
      );
    });
  });

  group('copy', () {
    test('carries the orientation', () {
      final GlossHologramDoc doc = decodeGlossHologramDoc(_baseline);
      doc.billboard = 'HORIZONTAL';
      doc.yaw = 45;
      doc.pitch = -10;
      final GlossHologramDoc copied = doc.copy();
      expect(copied.billboard, 'HORIZONTAL');
      expect(copied.yaw, 45);
      expect(copied.pitch, -10);
    });

    test('is deep: neither lines nor anchor nor extras are shared', () {
      final GlossHologramDoc doc = decodeGlossHologramDoc(_baseline);
      final GlossHologramDoc copied = doc.copy();
      copied.lines.add('added');
      copied.anchor.world = 'other';
      copied.anchor.setPosition(9, 9, 9);
      copied.seeThrough = false;
      expect(doc.lines, hasLength(2));
      expect(doc.anchor.world, 'world_nether');
      expect(doc.anchor.position, <double>[10.5, 64, -3.25]);
      expect(doc.seeThrough, isTrue);
    });
  });

  group('looksLikeHologramDoc', () {
    test('needs the envelope plus an anchor', () {
      expect(looksLikeHologramDoc(jsonDecode(_baseline)), isTrue);
      expect(
        looksLikeHologramDoc(<String, dynamic>{'anchor': <String, dynamic>{}}),
        isFalse,
        reason: 'no schemaVersion means it is not a Gloss document',
      );
      expect(
        looksLikeHologramDoc(<String, dynamic>{
          'schemaVersion': 1,
          'lines': <String>[],
        }),
        isFalse,
        reason: 'no anchor',
      );
      expect(looksLikeHologramDoc(<Object>[]), isFalse);
    });
  });
}

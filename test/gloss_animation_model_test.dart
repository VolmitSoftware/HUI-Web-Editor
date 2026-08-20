/// GlossAnimationDoc: round-trips, unknown-key preservation, envelope rules
/// and the shape check import routing relies on.
library;

import 'dart:convert';

import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

const String _rainbow = '''
{
  "schemaVersion": 1,
  "revision": 4,
  "mode": "ascend_descend",
  "frameIntervalMs": 250,
  "frames": [
    "&cOne",
    "&aTwo"
  ]
}
''';

void main() {
  group('decode', () {
    test('reads the full document', () {
      final GlossAnimationDoc doc = decodeGlossAnimationDoc(_rainbow);
      expect(doc.revision, 4);
      expect(doc.mode, 'ascend_descend');
      expect(doc.normalizedMode, 'ascend_descend');
      expect(doc.frameIntervalMs, 250);
      expect(doc.effectiveFrameIntervalMs, 250);
      expect(doc.frames, <String>['&cOne', '&aTwo']);
    });

    test('rejects a wrong or missing schemaVersion', () {
      expect(
        () => decodeGlossAnimationDoc('{"schemaVersion": 2, "frames": ["x"]}'),
        throwsA(isA<HuiFormatException>()),
      );
      expect(
        () => decodeGlossAnimationDoc('{"frames": ["x"]}'),
        throwsA(isA<HuiFormatException>()),
      );
    });

    test('mode case and unknown modes decode leniently', () {
      final GlossAnimationDoc upper = decodeGlossAnimationDoc(
        '{"schemaVersion": 1, "revision": 1, "mode": "RANDOM", '
        '"frameIntervalMs": 100, "frames": ["x"]}',
      );
      expect(upper.mode, 'RANDOM');
      expect(
        upper.normalizedMode,
        'random',
        reason: 'requireMode lowercases before checking',
      );
      final GlossAnimationDoc unknown = decodeGlossAnimationDoc(
        '{"schemaVersion": 1, "revision": 1, "mode": "wobble", '
        '"frameIntervalMs": 100, "frames": ["x"]}',
      );
      expect(unknown.normalizedMode, isNull);
    });

    test('an out-of-range interval is preserved, the clamp is derived', () {
      final GlossAnimationDoc doc = decodeGlossAnimationDoc(
        '{"schemaVersion": 1, "revision": 1, "mode": "ascend", '
        '"frameIntervalMs": 999999, "frames": ["x"]}',
      );
      expect(doc.frameIntervalMs, 999999);
      expect(doc.effectiveFrameIntervalMs, 60000);
      expect(
        (jsonDecode(encodeGlossAnimationDoc(doc))
            as Map<String, dynamic>)['frameIntervalMs'],
        999999,
        reason: 'the editor never silently rewrites what the plugin clamps',
      );
    });

    test('a scalar frames value reads as one frame; nulls become empty', () {
      expect(
        decodeGlossAnimationDoc(
          '{"schemaVersion": 1, "revision": 1, "frames": "solo"}',
        ).frames,
        <String>['solo'],
      );
      expect(
        decodeGlossAnimationDoc(
          '{"schemaVersion": 1, "revision": 1, "frames": ["a", null]}',
        ).frames,
        <String>['a', ''],
      );
    });
  });

  group('round-trip', () {
    test('decode-encode is stable and preserves unknown keys', () {
      const String withExtras = '''
{
  "schemaVersion": 1,
  "revision": 2,
  "mode": "random",
  "frameIntervalMs": 100,
  "frames": ["a"],
  "futureKnob": true
}
''';
      final GlossAnimationDoc doc = decodeGlossAnimationDoc(withExtras);
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossAnimationDoc(doc)) as Map<String, dynamic>;
      expect(out['futureKnob'], isTrue);
      expect(out, jsonDecode(withExtras));
      final String encoded = encodeGlossAnimationDoc(doc);
      expect(
        encodeGlossAnimationDoc(decodeGlossAnimationDoc(encoded)),
        encoded,
      );
    });
  });

  group('copy', () {
    test('is deep', () {
      final GlossAnimationDoc doc = decodeGlossAnimationDoc(_rainbow);
      final GlossAnimationDoc copied = doc.copy();
      copied.frames.add('extra');
      copied.mode = 'random';
      expect(doc.frames, hasLength(2));
      expect(doc.mode, 'ascend_descend');
    });
  });

  group('looksLikeAnimationDoc', () {
    test('needs the envelope plus frames, and nothing hologram-shaped', () {
      expect(looksLikeAnimationDoc(jsonDecode(_rainbow)), isTrue);
      expect(
        looksLikeAnimationDoc(<String, dynamic>{'frames': <String>[]}),
        isFalse,
        reason: 'no schemaVersion',
      );
      expect(
        looksLikeAnimationDoc(<String, dynamic>{
          'schemaVersion': 1,
          'anchor': <String, dynamic>{},
          'frames': <String>[],
        }),
        isFalse,
        reason: 'an anchor makes it a hologram',
      );
      expect(
        looksLikeHologramDoc(jsonDecode(_rainbow)),
        isFalse,
        reason: 'the two shape checks are mutually exclusive',
      );
    });
  });
}

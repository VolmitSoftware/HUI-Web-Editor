/// `AnimationClip.frameAt` mirror: mode index math, the silent interval
/// clamp, and a BigInt reference implementation cross-checking the 32-bit
/// lane arithmetic behind RANDOM's 64-bit scramble.
library;

import 'package:gloss_editor/logic/gloss_animation_playback.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

GlossAnimationDoc _doc({
  String mode = 'ascend',
  int intervalMs = 100,
  int frameCount = 4,
}) => GlossAnimationDoc(
  mode: mode,
  frameIntervalMs: intervalMs,
  frames: <String>[for (int i = 0; i < frameCount; i++) 'f$i'],
);

// --- BigInt reference for the Java 64-bit path -----------------------------

final BigInt _mask64 = (BigInt.one << 64) - BigInt.one;
final BigInt _sign64 = BigInt.one << 63;

BigInt _fmix64(BigInt value) {
  BigInt x = value & _mask64;
  x = (x ^ (x >> 33)) & _mask64;
  x = (x * BigInt.parse('FF51AFD7ED558CCD', radix: 16)) & _mask64;
  x = (x ^ (x >> 33)) & _mask64;
  x = (x * BigInt.parse('C4CEB9FE1A85EC53', radix: 16)) & _mask64;
  x = (x ^ (x >> 33)) & _mask64;
  return x;
}

int _javaHash(String id) {
  int hash = 0;
  for (int i = 0; i < id.length; i++) {
    hash = (hash * 31 + id.codeUnitAt(i)) % 0x100000000;
  }
  return hash;
}

int _referenceScrambled(int tick, String id, int count) {
  final BigInt seed =
      (BigInt.from(tick) + (BigInt.from(_javaHash(id)) << 32)) & _mask64;
  BigInt mixed = _fmix64(seed);
  // Interpret as signed two's complement, then Math.floorMod.
  if (mixed >= _sign64) mixed -= BigInt.one << 64;
  final BigInt rem = mixed % BigInt.from(count);
  return (rem < BigInt.zero ? rem + BigInt.from(count) : rem).toInt();
}

void main() {
  group('mode index math', () {
    test('ascend walks forward one frame per interval', () {
      final GlossAnimationDoc doc = _doc();
      expect(
        <int>[for (int t = 0; t < 6; t++)
          glossAnimationFrameIndexAt(doc, 'a', t * 100)],
        <int>[0, 1, 2, 3, 0, 1],
      );
    });

    test('descend walks backward from the last frame', () {
      final GlossAnimationDoc doc = _doc(mode: 'descend');
      expect(
        <int>[for (int t = 0; t < 5; t++)
          glossAnimationFrameIndexAt(doc, 'a', t * 100)],
        <int>[3, 2, 1, 0, 3],
      );
    });

    test('ascend_descend ping-pongs without repeating the turn frame', () {
      final GlossAnimationDoc doc = _doc(mode: 'ascend_descend');
      expect(
        <int>[for (int t = 0; t < 9; t++)
          glossAnimationFrameIndexAt(doc, 'a', t * 100)],
        <int>[0, 1, 2, 3, 3, 2, 1, 0, 0],
      );
    });

    test('mid-interval milliseconds truncate to the same tick', () {
      final GlossAnimationDoc doc = _doc();
      expect(glossAnimationFrameIndexAt(doc, 'a', 99), 0);
      expect(glossAnimationFrameIndexAt(doc, 'a', 100), 1);
      expect(glossAnimationFrameIndexAt(doc, 'a', 199), 1);
    });

    test('one frame is always frame zero, any mode', () {
      for (final String mode in glossAnimationModes) {
        final GlossAnimationDoc doc = _doc(mode: mode, frameCount: 1);
        expect(glossAnimationFrameIndexAt(doc, 'a', 123456), 0);
        expect(glossAnimationFrameAt(doc, 'a', 123456), 'f0');
      }
    });

    test('an unknown mode plays as ascend while validation reports it', () {
      final GlossAnimationDoc doc = _doc(mode: 'wiggle');
      expect(doc.normalizedMode, isNull);
      expect(glossAnimationFrameIndexAt(doc, 'a', 100), 1);
    });
  });

  group('the silent interval clamp (AnimationDoc.java:20)', () {
    test('below 1 ms runs at 1 ms', () {
      final GlossAnimationDoc doc = _doc(intervalMs: 0);
      expect(doc.effectiveFrameIntervalMs, 1);
      expect(glossAnimationFrameIndexAt(doc, 'a', 3), 3);
    });

    test('above 60000 ms runs at 60000 ms', () {
      final GlossAnimationDoc doc = _doc(intervalMs: 90000);
      expect(doc.effectiveFrameIntervalMs, 60000);
      expect(glossAnimationFrameIndexAt(doc, 'a', 59999), 0);
      expect(glossAnimationFrameIndexAt(doc, 'a', 60000), 1);
    });
  });

  group('random scramble vs the BigInt reference', () {
    test('matches across ticks, ids and frame counts', () {
      for (final String id in <String>['rainbow', 'animations/glow', 'x']) {
        for (final int count in <int>[2, 3, 7, 15]) {
          final GlossAnimationDoc doc = _doc(
            mode: 'random',
            frameCount: count,
            intervalMs: 1,
          );
          for (final int nowMs in <int>[
            0,
            1,
            999,
            123456789,
            1755500000000, // epoch-milliseconds scale, tick > 2^32
            9007199254740, // near the 2^53 tick ceiling
          ]) {
            expect(
              glossAnimationFrameIndexAt(doc, id, nowMs),
              _referenceScrambled(nowMs, id, count),
              reason: 'id=$id count=$count nowMs=$nowMs',
            );
          }
        }
      }
    });

    test('is deterministic and id-seeded', () {
      final GlossAnimationDoc doc = _doc(mode: 'random', frameCount: 10);
      final List<int> first = <int>[
        for (int t = 0; t < 20; t++)
          glossAnimationFrameIndexAt(doc, 'seed-a', t * 100),
      ];
      final List<int> again = <int>[
        for (int t = 0; t < 20; t++)
          glossAnimationFrameIndexAt(doc, 'seed-a', t * 100),
      ];
      final List<int> other = <int>[
        for (int t = 0; t < 20; t++)
          glossAnimationFrameIndexAt(doc, 'seed-b', t * 100),
      ];
      expect(again, first);
      expect(other, isNot(first), reason: 'the id seeds the scramble');
    });
  });
}

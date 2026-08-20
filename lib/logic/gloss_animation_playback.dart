/// Mirror of Gloss `AnimationClip.java` — which frame an animation shows at a
/// given wall-clock millisecond.
///
/// `AnimationService` builds one clip per document with
/// `targetFramerate = 1000.0 / frameIntervalMs` (`AnimationService.java:81`)
/// and resolves `|animation.<id>|` to `clip.frameAt(M.ms())`. The index math
/// is:
///
/// ```java
/// long tick = (long) (nowMs / (1000.0 / targetFramerate));
/// ASCEND         -> floorMod(tick, count)
/// DESCEND        -> count - 1 - floorMod(tick, count)
/// ASCEND_DESCEND -> ping-pong over 2 * count
/// RANDOM         -> murmur-style 64-bit scramble of tick + (hash(id) << 32)
/// ```
///
/// The RANDOM scramble is Java 64-bit arithmetic. Dart on the web has no
/// 64-bit integers, so the mix runs on 16/32-bit limbs kept below 2^53 —
/// bit-identical to the JVM on both the VM and dart2js
/// (`gloss_animation_playback_test.dart` cross-checks it against a BigInt
/// reference).
///
/// Everything takes `nowMs` explicitly: the caller owns the clock, tests
/// inject one, and the same millisecond always names the same frame.
library;

import '../model/gloss_animation.dart';

/// The frame [doc] shows at [nowMs], resolved the way the plugin's registered
/// `animation.<id>` function does. [id] only matters for `random` mode, whose
/// scramble seeds on the document id.
///
/// An unknown or blank mode plays as `ascend` — the plugin would have
/// rejected the file, and validation says so; the surface still has to draw
/// something while the author fixes it.
String glossAnimationFrameAt(GlossAnimationDoc doc, String id, int nowMs) {
  final List<String> frames = doc.frames;
  if (frames.isEmpty) return '';
  if (frames.length == 1) return frames[0];
  return frames[glossAnimationFrameIndexAt(doc, id, nowMs)];
}

/// The frame index behind [glossAnimationFrameAt]; what the scrubber and the
/// tests address frames by. Always `0` for a single-frame clip.
int glossAnimationFrameIndexAt(GlossAnimationDoc doc, String id, int nowMs) {
  final int count = doc.frames.length;
  if (count <= 1) return 0;
  // `(long) (nowMs / (1000.0 / targetFramerate))` with
  // `targetFramerate = 1000.0 / effectiveInterval` — the double division
  // round-trips, so this is nowMs / effectiveInterval truncated toward zero.
  final int tick = (nowMs / (1000.0 / (1000.0 / doc.effectiveFrameIntervalMs)))
      .truncate();
  return switch (doc.normalizedMode ?? 'ascend') {
    'descend' => count - 1 - _floorMod(tick, count),
    'ascend_descend' => _pingPong(tick, count),
    'random' => _scrambled(tick, id, count),
    _ => _floorMod(tick, count),
  };
}

/// `Math.floorMod` for the small values every non-random mode uses.
int _floorMod(int value, int modulus) {
  final int rem = value % modulus;
  return rem < 0 ? rem + modulus : rem;
}

/// `AnimationClip.pingPong`.
int _pingPong(int tick, int count) {
  final int cycle = _floorMod(tick, count * 2);
  return cycle < count ? cycle : (count * 2) - 1 - cycle;
}

// ---------------------------------------------------------------------------
// RANDOM - AnimationClip.scrambled on 32-bit lanes
// ---------------------------------------------------------------------------

/// A 64-bit two's-complement value as two unsigned 32-bit words. Every
/// intermediate stays below 2^53, so the arithmetic is exact under dart2js.
typedef _U64 = ({int hi, int lo});

const int _pow32 = 0x100000000;

/// `0xFF51AFD7ED558CCDL` and `0xC4CEB9FE1A85EC53L` — the fmix64 constants.
const _U64 _mixC1 = (hi: 0xFF51AFD7, lo: 0xED558CCD);
const _U64 _mixC2 = (hi: 0xC4CEB9FE, lo: 0x1A85EC53);

/// `AnimationClip.scrambled`: seed, xor-shift/multiply mix, floorMod.
int _scrambled(int tick, String id, int count) {
  // tick + ((long) id.hashCode() << 32): the shift keeps only the hash's low
  // 32 bits in the high word, and tick is non-negative and < 2^53.
  final int hash = _javaStringHash(id);
  _U64 mixed = (hi: ((tick ~/ _pow32) + hash) % _pow32, lo: tick % _pow32);
  mixed = _xor(mixed, _shr33(mixed));
  mixed = _mul(mixed, _mixC1);
  mixed = _xor(mixed, _shr33(mixed));
  mixed = _mul(mixed, _mixC2);
  mixed = _xor(mixed, _shr33(mixed));
  return _floorMod64(mixed, count);
}

/// `String.hashCode`: `h = 31 * h + charAt(i)` over UTF-16 units, wrapping at
/// 32 bits. Returned as the unsigned bit pattern — the callers only ever use
/// the low 32 bits.
int _javaStringHash(String value) {
  int hash = 0;
  for (int i = 0; i < value.length; i++) {
    hash = (hash * 31 + value.codeUnitAt(i)) % _pow32;
  }
  return hash;
}

/// Per-word xor. The operands are 32-bit but dart2js truncates bitwise
/// results, so the words are split into 16-bit halves first — arithmetic
/// operators are the only ones exact past 32 bits on the web.
_U64 _xor(_U64 a, _U64 b) => (hi: _xor32(a.hi, b.hi), lo: _xor32(a.lo, b.lo));

int _xor32(int a, int b) =>
    ((a ~/ 0x10000) ^ (b ~/ 0x10000)) * 0x10000 +
    ((a % 0x10000) ^ (b % 0x10000));

/// `>>> 33`: the high word, shifted one further, is all that survives.
_U64 _shr33(_U64 value) => (hi: 0, lo: value.hi ~/ 2);

/// Low 64 bits of the product, via 16-bit limbs. Multiply/divide/modulo only:
/// every intermediate stays below 2^33, exact on both backends.
_U64 _mul(_U64 a, _U64 b) {
  final List<int> x = <int>[
    a.lo % 0x10000,
    a.lo ~/ 0x10000,
    a.hi % 0x10000,
    a.hi ~/ 0x10000,
  ];
  final List<int> y = <int>[
    b.lo % 0x10000,
    b.lo ~/ 0x10000,
    b.hi % 0x10000,
    b.hi ~/ 0x10000,
  ];
  final List<int> out = <int>[0, 0, 0, 0];
  for (int i = 0; i < 4; i++) {
    int carry = 0;
    for (int j = 0; i + j < 4; j++) {
      final int sum = out[i + j] + x[i] * y[j] + carry;
      out[i + j] = sum % 0x10000;
      carry = sum ~/ 0x10000;
    }
  }
  return (hi: out[3] * 0x10000 + out[2], lo: out[1] * 0x10000 + out[0]);
}

/// `Math.floorMod(signed64, count)` with `0 < count < 2^31`, in base-2^16
/// steps so nothing exceeds 2^47.
int _floorMod64(_U64 value, int count) {
  int rem = (value.hi ~/ 0x10000) % count;
  rem = (rem * 0x10000 + value.hi % 0x10000) % count;
  rem = (rem * 0x10000 + value.lo ~/ 0x10000) % count;
  rem = (rem * 0x10000 + value.lo % 0x10000) % count;
  if (value.hi >= 0x80000000) {
    // The bit pattern is a negative two's-complement value: subtract
    // 2^64 mod count before flooring.
    int pow64 = 1;
    for (int i = 0; i < 4; i++) {
      pow64 = (pow64 * 0x10000) % count;
    }
    rem = (rem - pow64) % count;
    if (rem < 0) rem += count;
  }
  return rem;
}

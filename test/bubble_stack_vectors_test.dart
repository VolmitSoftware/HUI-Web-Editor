/// Replays `test/fixtures/bubble_stack_vectors.json` against the
/// BubbleStackMath port to 1e-9 — the same file the Gloss side's twin Java
/// test pins `BubbleStackMath` itself to.
library;

import 'dart:convert';
import 'dart:io';

import 'package:gloss_editor/logic/bubble_stack_math.dart';
import 'package:test/test.dart';

void main() {
  final Map<String, Object?> fixture =
      jsonDecode(
            File(
              'test/fixtures/bubble_stack_vectors.json',
            ).readAsStringSync(),
          )!
          as Map<String, Object?>;

  test('the fixture constants pin the Java ones', () {
    final Map<String, Object?> constants =
        fixture['constants']! as Map<String, Object?>;
    expect(constants['baseLift'], glossBubbleBaseLift);
    expect(constants['flyAwayWindowMs'], glossBubbleFlyAwayWindowMs);
    expect(constants['flyAwayExponent'], glossBubbleFlyAwayExponent);
    expect(constants['flyAwayHeight'], glossBubbleFlyAwayHeight);
  });

  test('every vector replays to 1e-9', () {
    final int maxAliveMs = fixture['maxAliveMs']! as int;
    final List<Object?> vectors = fixture['vectors']! as List<Object?>;
    expect(vectors, hasLength(120));
    for (final Object? raw in vectors) {
      final Map<String, Object?> vector = raw! as Map<String, Object?>;
      final double spread = (vector['spread']! as num).toDouble();
      final int lineIndex = vector['lineIndex']! as int;
      final int liveCount = vector['liveCount']! as int;
      final int elapsedMs = vector['elapsedMs']! as int;
      final bool flyAway = vector['flyAway']! as bool;
      final int remainingMs = maxAliveMs - elapsedMs;
      final String label =
          'spread=$spread line=$lineIndex live=$liveCount '
          'elapsed=$elapsedMs flyAway=$flyAway';

      expect(
        glossBubbleStackOffset(spread, lineIndex, liveCount),
        closeTo((vector['stackOffset']! as num).toDouble(), 1e-9),
        reason: 'stackOffset $label',
      );
      expect(
        flyAway ? glossBubbleFlyAway(remainingMs) : 0.0,
        closeTo((vector['flyAwayLift']! as num).toDouble(), 1e-9),
        reason: 'flyAwayLift $label',
      );
      expect(
        glossBubbleOffsetY(
          spread,
          lineIndex,
          liveCount,
          remainingMs,
          flyAwayEnabled: flyAway,
        ),
        closeTo((vector['offsetY']! as num).toDouble(), 1e-9),
        reason: 'offsetY $label',
      );
    }
  });

  test('spot values proven by hand against BubbleStackMath.java', () {
    // remaining >= window: no lift.
    expect(glossBubbleFlyAway(2000), 0);
    expect(glossBubbleFlyAway(5000), 0);
    // remaining 0 (or negative, clamped): the full 10-block launch.
    expect(glossBubbleFlyAway(0), closeTo(10, 1e-12));
    expect(glossBubbleFlyAway(-50), closeTo(10, 1e-12));
    // remaining 1000: (1 - 0.5)^16 * 10.
    expect(glossBubbleFlyAway(1000), closeTo(10 / 65536, 1e-12));
    // Stack offset never goes negative for indexes past the live count.
    expect(glossBubbleStackOffset(0.26, 5, 3), 0);
    expect(glossBubbleStackOffset(0.26, 0, 3), closeTo(0.78, 1e-12));
    // offsetY composes all three terms.
    expect(
      glossBubbleOffsetY(0.26, 0, 1, 0, flyAwayEnabled: true),
      closeTo(0.86 + 0.26 + 10, 1e-12),
    );
  });
}

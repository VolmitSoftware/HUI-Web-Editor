/// The bubble preview timeline: deterministic under an injected clock, and
/// faithful to the ported plugin pieces it composes — split lines, staggered
/// spawns, per-bubble lifetime, live-list stacking, fly-away easing.
library;

import 'package:gloss_editor/logic/bubble_preview.dart';
import 'package:gloss_editor/logic/bubble_stack_math.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

GlossBubbleStyleDoc _style({
  int wrap = 32,
  int staggerTicks = 5,
  int maxAliveMs = 5000,
  bool flyAway = true,
}) => GlossBubbleStyleDoc(
  wordWrapChars: wrap,
  lineStaggerTicks: staggerTicks,
  maxAliveMs: maxAliveMs,
  flyAway: flyAway,
);

void main() {
  test('the same millisecond always shows the same stack', () {
    final GlossBubbleStyleDoc style = _style();
    final GlossBubblePreviewTimeline first = GlossBubblePreviewTimeline(style);
    final GlossBubblePreviewTimeline second = GlossBubblePreviewTimeline(style);
    for (final int at in <int>[0, 500, 2500, 7000, 12000]) {
      final List<GlossBubblePreviewBubble> a = first.bubblesAt(at);
      final List<GlossBubblePreviewBubble> b = second.bubblesAt(at);
      expect(a.length, b.length, reason: 'at $at');
      for (int index = 0; index < a.length; index++) {
        expect(a[index].text, b[index].text);
        expect(a[index].offsetY, b[index].offsetY);
      }
    }
  });

  test('line 2 of a wrapped message appears one stagger later', () {
    // 24-char wrap splits the second canned message into multiple lines;
    // stagger 10 ticks = 500 ms.
    final GlossBubblePreviewTimeline timeline = GlossBubblePreviewTimeline(
      _style(wrap: 24, staggerTicks: 10),
    );
    const int atFirstMessage2Line =
        glossBubblePreviewMessageGapMs; // message 2 spawn instant
    final int before = timeline.bubblesAt(atFirstMessage2Line + 499).length;
    final int after = timeline.bubblesAt(atFirstMessage2Line + 500).length;
    expect(after, before + 1);
  });

  test('a bubble expires exactly maxAliveMs after ITS spawn', () {
    final GlossBubblePreviewTimeline timeline = GlossBubblePreviewTimeline(
      _style(staggerTicks: 0, maxAliveMs: 1000),
    );
    expect(timeline.bubblesAt(0), isNotEmpty);
    expect(
      timeline.bubblesAt(999).any(
        (GlossBubblePreviewBubble bubble) => bubble.remainingMs == 1,
      ),
      isTrue,
    );
    // At 1000 the first message's bubbles are gone (second not yet sent
    // until 1800).
    expect(timeline.bubblesAt(1000), isEmpty);
  });

  test('heights come straight from the BubbleStackMath port', () {
    final GlossBubblePreviewTimeline timeline = GlossBubblePreviewTimeline(
      _style(staggerTicks: 0, flyAway: false),
    );
    final List<GlossBubblePreviewBubble> bubbles = timeline.bubblesAt(100);
    expect(bubbles, isNotEmpty);
    for (int index = 0; index < bubbles.length; index++) {
      expect(
        bubbles[index].offsetY,
        glossBubbleOffsetY(
          glossBubbleDefaultStackSpread,
          index,
          bubbles.length,
          bubbles[index].remainingMs,
          flyAwayEnabled: false,
        ),
      );
    }
    // Oldest first: the head of the list carries the highest stack lift.
    if (bubbles.length > 1) {
      expect(bubbles.first.offsetY, greaterThan(bubbles.last.offsetY));
    }
  });

  test('fly-away raises a dying bubble; disabled leaves it in place', () {
    final GlossBubblePreviewTimeline flying = GlossBubblePreviewTimeline(
      _style(staggerTicks: 0, maxAliveMs: 1000, flyAway: true),
    );
    final GlossBubblePreviewTimeline grounded = GlossBubblePreviewTimeline(
      _style(staggerTicks: 0, maxAliveMs: 1000, flyAway: false),
    );
    final double dyingLift = flying.bubblesAt(990).first.offsetY;
    final double steadyLift = grounded.bubblesAt(990).first.offsetY;
    expect(dyingLift, greaterThan(steadyLift + 5),
        reason: '10 ms from expiry the launch is near its full 10 blocks');
  });

  test('the loop period clears the stage before restarting', () {
    final GlossBubblePreviewTimeline timeline = GlossBubblePreviewTimeline(
      _style(),
    );
    expect(timeline.bubblesAt(timeline.periodMs - 1), isEmpty);
    expect(
      timeline.bubblesAt(timeline.periodMs),
      isNotEmpty,
      reason: 'the cycle restarts at the period boundary',
    );
  });
}

library;

import 'package:gloss_editor/logic/bubble_lines.dart';
import 'package:gloss_editor/logic/bubble_preview.dart';
import 'package:gloss_editor/logic/bubble_stack_math.dart';
import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

GlossBubbleStyleDoc _style({
  String prefix = '&7',
  int wrap = 32,
  int maxAliveMs = 5000,
  GlossBubbleMotion? motion,
  GlossBubbleShimmer? shimmer,
}) => GlossBubbleStyleDoc(
  prefix: prefix,
  wordWrapChars: wrap,
  maxAliveMs: maxAliveMs,
  motion: motion ?? GlossBubbleMotion.runtimeDefaults(),
  shimmer: shimmer ?? GlossBubbleShimmer(),
);

void main() {
  test('the showcase conversation is long, named, and formatted', () {
    final String conversation = glossBubblePreviewMessages.join('\n');
    expect(glossBubblePreviewMessages, hasLength(greaterThanOrEqualTo(6)));
    expect(conversation, contains('Magic_Psycho'));
    expect(conversation, contains('SwiftSwamp smells >.<'));
    expect(conversation, contains('Cyberpwn'));
    expect(conversation, contains('Puretie'));
    expect(conversation, contains('§'));
  });

  test('the same millisecond always shows the same stack and motion', () {
    final GlossBubblePreviewTimeline first = GlossBubblePreviewTimeline(
      _style(),
    );
    final GlossBubblePreviewTimeline second = GlossBubblePreviewTimeline(
      _style(),
    );
    for (final int at in <int>[0, 500, 2500, 7000, 12000]) {
      final List<GlossBubblePreviewBubble> a = first.bubblesAt(at);
      final List<GlossBubblePreviewBubble> b = second.bubblesAt(at);
      expect(a.length, b.length, reason: 'at $at');
      for (int index = 0; index < a.length; index++) {
        expect(a[index].text, b[index].text);
        expect(a[index].stackY, b[index].stackY);
        expect(a[index].motion.translationY, b[index].motion.translationY);
        expect(a[index].shimmerBandIndex, b[index].shimmerBandIndex);
      }
    }
  });

  test('a wrapped chat message remains one multiline bubble block', () {
    final GlossBubblePreviewTimeline timeline = GlossBubblePreviewTimeline(
      _style(wrap: 12),
    );
    final List<GlossBubblePreviewBubble> initial = timeline.bubblesAt(0);
    expect(initial, hasLength(1));
    expect(initial.single.text, contains('\n'));
    expect(initial.single.lineCount, greaterThan(1));
    expect(
      initial.single.lineCount,
      glossBubbleWrappedLineCount(initial.single.text),
    );
    expect(timeline.bubblesAt(glossBubblePreviewMessageGapMs), hasLength(2));
  });

  test('a bubble expires exactly maxAliveMs after its message spawn', () {
    final GlossBubblePreviewTimeline timeline = GlossBubblePreviewTimeline(
      _style(maxAliveMs: 1000),
    );
    expect(timeline.bubblesAt(0), hasLength(1));
    expect(timeline.bubblesAt(999).single.remainingMs, 1);
    expect(timeline.bubblesAt(1000), isEmpty);
  });

  test('line-aware stack heights come from the shared stack math', () {
    final GlossBubblePreviewTimeline timeline = GlossBubblePreviewTimeline(
      _style(wrap: 20, motion: GlossBubbleMotion.identity()),
    );
    final List<GlossBubblePreviewBubble> bubbles = timeline.bubblesAt(2000);
    final List<int> lineCounts = <int>[
      for (final GlossBubblePreviewBubble bubble in bubbles) bubble.lineCount,
    ];
    for (int index = 0; index < bubbles.length; index++) {
      expect(
        bubbles[index].stackY,
        glossBubbleStackY(glossBubbleDefaultStackSpread, index, lineCounts),
      );
    }
    expect(bubbles.last.stackY, 0);
  });

  test('shimmer never exposes an unevaluated formatted prefix', () {
    final GlossBubbleStyleDoc style = _style(
      prefix:
          '{{ hex(palette([#FF2D4E, #FFB3C4, #FFFFFF], '
          'floor(time.seconds * 4))) }}',
      shimmer: GlossBubbleShimmer(
        spawn: true,
        durationMs: 1000,
        spawnDelayMs: 0,
      ),
    );
    final GlossBubblePreviewBubble bubble = GlossBubblePreviewTimeline(
      style,
    ).bubblesAt(100).single;
    expect(bubble.shimmerBandIndex, isNotNull);

    final GlossLineRender rendered = renderGlossBubblePreviewText(
      style,
      bubble,
      nowMs: 100,
    );
    expect(rendered.expressionErrors, isEmpty);
    expect(rendered.plainText, isNot(contains('{{')));
    expect(rendered.plainText, contains('Magic_Psycho'));
  });

  test(
    'preview evaluates translation, scale, rotation, and opacity exactly',
    () {
      final GlossBubbleMotion motion = GlossBubbleMotion(
        translation: GlossBubbleMotionVector(x: 't', y: '10 * t', z: '-t'),
        scale: GlossBubbleMotionVector(x: '1 + t', y: '1', z: 'remaining'),
        rotation: GlossBubbleMotionVector(x: '720 * t', y: '0', z: '-90 * t'),
        opacity: 'remaining',
      );
      final GlossBubblePreviewBubble bubble = GlossBubblePreviewTimeline(
        _style(maxAliveMs: 1000, motion: motion),
      ).bubblesAt(500).single;
      expect(bubble.motion.translationX, closeTo(0.5, 1e-12));
      expect(bubble.motion.translationY, closeTo(5, 1e-12));
      expect(bubble.motion.translationZ, closeTo(-0.5, 1e-12));
      expect(bubble.motion.scaleX, closeTo(1.5, 1e-12));
      expect(bubble.motion.scaleZ, closeTo(0.5, 1e-12));
      expect(bubble.motion.rotationX, closeTo(0, 1e-12));
      expect(bubble.motion.rotationZ, closeTo(315, 1e-12));
      expect(bubble.motion.opacity, closeTo(0.5, 1e-12));
    },
  );

  test('the exact default expression reproduces the legacy final fly-away', () {
    final GlossBubblePreviewBubble bubble = GlossBubblePreviewTimeline(
      _style(maxAliveMs: 1000),
    ).bubblesAt(990).single;
    expect(bubble.motion.translationY, greaterThan(9));
  });

  test('preview exposes a bounded delayed spawn sweep', () {
    final GlossBubblePreviewTimeline timeline = GlossBubblePreviewTimeline(
      _style(shimmer: GlossBubbleShimmer(durationMs: 1000, spawnDelayMs: 100)),
    );
    expect(timeline.bubblesAt(99).single.shimmerBandIndex, isNull);
    expect(timeline.bubblesAt(100).single.shimmerBandIndex, 0);
    expect(timeline.bubblesAt(600).single.shimmerBandIndex, greaterThan(0));
    expect(timeline.bubblesAt(1100).single.shimmerBandIndex, isNotNull);
    expect(timeline.bubblesAt(1101).single.shimmerBandIndex, isNull);
    expect(timeline.bubblesAt(2500).first.shimmerBandIndex, isNull);
  });

  test('the departure sweep restarts the band near expiry', () {
    final GlossBubblePreviewTimeline timeline = GlossBubblePreviewTimeline(
      _style(
        shimmer: GlossBubbleShimmer(
          flyAway: true,
          durationMs: 1000,
          flyAwayLeadMs: 1000,
        ),
      ),
    );
    expect(timeline.bubblesAt(3999).first.shimmerBandIndex, isNull);
    expect(timeline.bubblesAt(4000).first.shimmerBandIndex, 0);
  });

  test('the loop period clears the stage before restarting', () {
    final GlossBubblePreviewTimeline timeline = GlossBubblePreviewTimeline(
      _style(),
    );
    expect(timeline.bubblesAt(timeline.periodMs - 1), isEmpty);
    expect(timeline.bubblesAt(timeline.periodMs), isNotEmpty);
  });
}

library;

import 'package:gloss_editor/logic/bubble_shimmer.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  GlossBubbleShimmer shimmer({int width = 1}) => GlossBubbleShimmer(
    spawn: true,
    flyAway: true,
    color: '#ffffff',
    width: width,
    durationMs: 1000,
    spawnDelayMs: 100,
    flyAwayLeadMs: 1000,
  );

  test('spawn and fly-away windows mirror the runtime timing', () {
    final GlossBubbleShimmer style = shimmer();
    double? at(int ageMs) =>
        glossBubbleShimmerProgress(style, ageMs: ageMs, lifetimeMs: 5000);

    expect(at(99), isNull);
    expect(at(100), 0);
    expect(at(600), 0.5);
    expect(at(1100), 1);
    expect(at(1101), isNull);
    expect(at(4000), 0);
    expect(at(4500), 0.5);
    expect(at(5000), 1);
  });

  test('white band restores active color and decoration after each glyph', () {
    final GlossBubbleShimmer style = shimmer();
    expect(
      glossBubbleApplyShimmer('§aHi §lBob', style, 0),
      '§a§x§f§f§f§f§f§fH§ai §lBob',
    );
    expect(
      glossBubbleApplyShimmer('§aHi §lBob', style, 1),
      '§aHi §lBo§x§f§f§f§f§f§fb§a§l',
    );
  });

  test('multiline block sweeps each line at the same horizontal progress', () {
    final GlossBubbleShimmer style = shimmer();
    final String rendered = glossBubbleApplyShimmer(
      '&7Alpha\n&b🚀 Beta',
      style,
      0.5,
    );
    final List<String> lines = rendered.split('\n');
    expect(lines, hasLength(2));
    expect(lines[0], contains('§x'));
    expect(lines[1], contains('§x'));
    expect(lines[1], contains('🚀'));
  });

  test('disabled passes leave text unchanged', () {
    final GlossBubbleShimmer style = GlossBubbleShimmer(
      spawn: false,
      flyAway: false,
    );
    final double? progress = glossBubbleShimmerProgress(
      style,
      ageMs: 0,
      lifetimeMs: 5000,
    );
    expect(progress, isNull);
    expect(glossBubbleApplyShimmer('&7Gloss', style, progress), '&7Gloss');
  });
}

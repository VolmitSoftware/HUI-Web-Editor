/// The `|metric.<key>|` function family the integration bridge registers.
///
/// `IntegrationBridgeService.attach` registers one text function per metric key
/// another Volmit plugin publishes, so a Gloss content line can read a live
/// number. The editor has no bridge and no sample, so the token survives the
/// function stage and the colour stage turns it into a chip — the same
/// treatment `%placeholder%` gets. What these tests pin is that the SCAN still
/// behaves like the registered function it is: both pipes are consumed, so a
/// following `|animation.<id>|` reference resolves exactly as it would in game.
library;

import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

final class _OneAnimation implements GlossAnimationResolver {
  _OneAnimation(this.id, this.frames);

  final String id;
  final List<String> frames;

  @override
  List<String> get ids => <String>[id];

  @override
  GlossAnimationDoc? byId(String wanted) =>
      wanted == id ? GlossAnimationDoc(frames: frames) : null;
}

final class _Emoji implements GlossEmojiResolver {
  _Emoji(this.entries);

  @override
  final List<GlossEmojiEntry> entries;
}

List<GlossMetricChip> _chips(GlossLineRender render) => <GlossMetricChip>[
  for (final GlossTextPiece piece in render.pieces)
    if (piece is GlossMetricChip) piece,
];

void main() {
  group('glossLineMetricRefs', () {
    test('collects keys in order, without duplicates', () {
      expect(
        glossLineMetricRefs('|metric.react.tps| / |metric.iris.chunks|'),
        <String>['react.tps', 'iris.chunks'],
      );
      expect(
        glossLineMetricRefs('|metric.a| |metric.a|'),
        <String>['a'],
      );
    });

    test('a line with no references reads none', () {
      expect(glossLineMetricRefs('&aplain text'), isEmpty);
      expect(glossLineMetricRefs('|animation.rainbow|'), isEmpty);
    });

    test('an empty key is not a metric — the plugin registers no such name', () {
      expect(glossLineMetricRefs('|metric.|'), isEmpty);
    });
  });

  group('the function stage', () {
    test('keeps the token and reports the key', () {
      final GlossLineRender render = renderGlossLine('tps |metric.react.tps|');
      expect(render.metrics, <String>['react.tps']);
      expect(render.plainText, 'tps |metric.react.tps|');
    });

    test('consumes both pipes, so the next reference still resolves', () {
      // With the closing pipe treated as the next candidate opener — what an
      // UNregistered name does — "animation.spin" would be found between the
      // wrong two pipes and the line would render differently.
      final GlossLineRender render = renderGlossLine(
        '|metric.a|animation.spin|',
        animations: _OneAnimation('spin', <String>['*']),
      );
      expect(render.plainText, '|metric.a|animation.spin|');
      expect(render.usedAnimations, isEmpty);
    });

    test('a metric and an animation reference coexist', () {
      final GlossLineRender render = renderGlossLine(
        '|animation.spin| |metric.react.tps|',
        animations: _OneAnimation('spin', <String>['*']),
      );
      expect(render.plainText, '* |metric.react.tps|');
      expect(render.usedAnimations, <String>['spin']);
      expect(render.metrics, <String>['react.tps']);
    });

    test('an unknown function family stays literal and reports nothing', () {
      final GlossLineRender render = renderGlossLine('|server.name|');
      expect(render.metrics, isEmpty);
      expect(render.plainText, '|server.name|');
      expect(_chips(render), isEmpty);
    });
  });

  group('the chip', () {
    test('carries the key, the token and the style in scope', () {
      final GlossLineRender render = renderGlossLine(
        '&c&lTPS &f|metric.react.tps|',
      );
      final GlossMetricChip chip = _chips(render).single;
      expect(chip.key, 'react.tps');
      expect(chip.token, '|metric.react.tps|');
      expect(chip.style.rgb, 0xFFFFFF);
    });

    test('two references make two chips', () {
      final GlossLineRender render = renderGlossLine(
        '|metric.a| and |metric.b|',
      );
      expect(
        <String>[for (final GlossMetricChip chip in _chips(render)) chip.key],
        <String>['a', 'b'],
      );
    });

    test('the token counts as its own characters for length', () {
      // The sampled value is unknowable here, exactly like a placeholder's,
      // so the measured line keeps the token verbatim.
      expect(
        glossLineMaxVisibleLength('|metric.a|', const GlossNoAnimations()),
        '|metric.a|'.length,
      );
    });

    test('emoji inside the surrounding text still substitute', () {
      final GlossLineRender render = renderGlossLine(
        ':check: |metric.a|',
        emoji: _Emoji(<GlossEmojiEntry>[
          const GlossEmojiEntry(
            id: 'check',
            trigger: '',
            glyph: '✓',
            enabled: true,
          ),
        ]),
      );
      expect(render.plainText, '✓ |metric.a|');
      expect(_chips(render).single.key, 'a');
    });
  });

  group('glossMetricInfo', () {
    test('is null when nothing references a metric', () {
      expect(glossMetricInfo(<String>['&aplain', '|animation.x|']), isNull);
    });

    test('lists every distinct key once, as info', () {
      final HuiIssue issue = glossMetricInfo(<String>[
        '|metric.react.tps|',
        '|metric.iris.chunks| |metric.react.tps|',
      ])!;
      expect(issue.severity, HuiSeverity.info);
      expect(issue.path, r'$');
      expect(issue.message, contains('react.tps'));
      expect(issue.message, contains('iris.chunks'));
      expect(issue.message, contains('integration bridge'));
      expect('react.tps'.allMatches(issue.message).length, 1);
    });

    test('singular wording for one key', () {
      final HuiIssue issue = glossMetricInfo(<String>['|metric.a|'])!;
      expect(issue.message, contains('the metric a'));
    });
  });
}

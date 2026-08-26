import 'package:gloss_editor/logic/gloss_particle_text.dart';
import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:test/test.dart';

void main() {
  group('particle text spans', () {
    test('strip authored tags and retain the rendered source range', () {
      final GlossLineRender rendered = renderGlossLine(
        'This is: <particles:green-word>&4GREEN</particles> Colored!',
      );

      expect(rendered.plainText, 'This is: GREEN Colored!');
      expect(rendered.renderedText, 'This is: §4GREEN Colored!');
      expect(rendered.particleSpans, hasLength(1));
      expect(rendered.particleSpans.single.name, 'green-word');
      expect(
        rendered.renderedText.substring(
          rendered.particleSpans.single.start,
          rendered.particleSpans.single.end,
        ),
        '§4GREEN',
      );
      expect(rendered.particleSpanError, isNull);
    });

    test('normalizes names and preserves placeholders inside a span', () {
      final GlossParticleTextRendered rendered = glossRenderMenuParticleText(
        '<PARTICLES:Player_Name>&6%player_name%</PARTICLES>',
      );

      expect(rendered.text, '&6%player_name%');
      expect(rendered.spans.single.name, 'player_name');
      expect(rendered.spans.single.start, 0);
      expect(rendered.spans.single.end, rendered.text.length);
    });

    test('rejects nested, unmatched, invalid, and unclosed tags', () {
      for (final String source in <String>[
        '<particles:a>x<particles:b>y</particles></particles>',
        'x</particles>',
        '<particles:Bad Name>x</particles>',
        '<particles:a>x',
      ]) {
        expect(glossParticleTextSyntaxError(source), isNotNull, reason: source);
      }
    });

    test('invalid authoring remains visible while surfacing the error', () {
      final GlossLineRender rendered = renderGlossLine('<particles:bad name>x');

      expect(rendered.plainText, '<particles:bad name>x');
      expect(rendered.particleSpans, isEmpty);
      expect(rendered.particleSpanError, contains('must match'));
    });

    test('rendered marker mutation is rejected', () {
      expect(
        () => renderGlossParticleText(
          '<particles:a>x</particles>',
          (String marked) => marked.replaceFirst('a', 'b'),
        ),
        throwsA(isA<GlossParticleTextFormatException>()),
      );
    });
  });
}

library;

import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('title preview applies the runtime 32-code-unit cut', () {
    final GlossLineRender render = renderGlossScoreboardTitle('&a${'x' * 31}');

    expect(render.plainText, 'x' * 30);
  });

  test('title preview does not split surrogate or formatting sequences', () {
    expect(renderGlossScoreboardTitle('${'x' * 31}💡').plainText, 'x' * 31);
    expect(
      renderGlossScoreboardTitle('${'x' * 31}&aGreen').plainText,
      'x' * 31,
    );
    expect(
      renderGlossScoreboardTitle('${'x' * 25}[123456]RGB').plainText,
      'x' * 25,
    );
  });

  test('plain row preview renders only the 16 plus 16 wire segments', () {
    final GlossLineRender render = renderGlossScoreboardLine('x' * 40);

    expect(render.plainText, 'x' * 32);
  });

  test('legacy colour carry consumes the suffix wire budget', () {
    final GlossLineRender render = renderGlossScoreboardLine('&a${'x' * 40}');

    expect(render.plainText, 'x' * 28);
    expect(<int>[
      for (final GlossTextPiece piece in render.pieces)
        if (piece case GlossTextRun(:final span)) span.color,
    ], everyElement(0x55FF55));
  });

  test('hex colour carry matches BoardEntry suffix clipping', () {
    final GlossLineRender render = renderGlossScoreboardLine('[123456]ABCDEF');

    expect(render.plainText, 'ABCD');
    expect(<int>[
      for (final GlossTextPiece piece in render.pieces)
        if (piece case GlossTextRun(:final span)) span.color,
    ], everyElement(0x123456));
  });

  test('a hex run crossing the prefix boundary moves wholly to the suffix', () {
    final GlossLineRender render = renderGlossScoreboardLine(
      '${'x' * 10}[123456]ABCD',
    );

    expect(render.plainText, '${'x' * 10}AB');
  });

  test('a hex run crossing the overall line cap is omitted atomically', () {
    final GlossLineRender render = renderGlossScoreboardLine(
      '${'x' * 25}[123456]RGB',
    );

    expect(render.plainText, 'x' * 25);
  });

  test('line fitting does not split surrogate or formatting suffixes', () {
    expect(renderGlossScoreboardLine('${'x' * 31}💡').plainText, 'x' * 31);
    expect(renderGlossScoreboardLine('${'x' * 31}&aGreen').plainText, 'x' * 31);
  });

  test('every Java line separator becomes one row space', () {
    const String input = 'a\r\nb\rc\nd e f';

    expect(renderGlossScoreboardTitle(input).plainText, 'a b c d e f');
    expect(renderGlossScoreboardLine(input).plainText, 'a b c d e f');
  });

  test('unpaired UTF-16 surrogates never reach the preview', () {
    final String input = String.fromCharCodes(<int>[
      0x61,
      0xD800,
      0x62,
      0xDC00,
      0x63,
    ]);

    expect(renderGlossScoreboardTitle(input).plainText, 'abc');
    expect(renderGlossScoreboardLine(input).plainText, 'abc');
  });

  test('measure reports formatting-aware truncation', () {
    final GlossScoreboardLineMeasure clean = measureGlossScoreboardLine(
      '&a${'x' * 28}',
      const GlossNoAnimations(),
    );
    final GlossScoreboardLineMeasure clipped = measureGlossScoreboardLine(
      '&a${'x' * 29}',
      const GlossNoAnimations(),
    );

    expect(clean.truncated, isFalse);
    expect(clean.deliveredVisibleLength, 28);
    expect(clipped.truncated, isTrue);
    expect(clipped.encodedLength, 31);
    expect(clipped.visibleLength, 29);
    expect(clipped.deliveredVisibleLength, 28);
  });

  group('empty title falls back to the board id', () {
    test('a blank title renders the id, like GlossBoardMeta.fromDoc', () {
      final GlossScoreboardDoc doc = GlossScoreboardDoc();

      expect(doc.effectiveTitle('welcome'), 'welcome');
      expect(
        renderGlossScoreboardTitle(doc.effectiveTitle('welcome')).plainText,
        'welcome',
      );
    });

    test('an authored title is never replaced', () {
      final GlossScoreboardDoc doc = GlossScoreboardDoc(title: '&d&lGloss');

      expect(doc.effectiveTitle('welcome'), '&d&lGloss');
      expect(
        renderGlossScoreboardTitle(doc.effectiveTitle('welcome')).plainText,
        'Gloss',
      );
    });

    test('the fallback tests isEmpty, not a trim', () {
      final GlossScoreboardDoc doc = GlossScoreboardDoc(title: ' ');

      expect(doc.effectiveTitle('welcome'), ' ');
    });

    test('the fallback id still takes the 32-unit title cut', () {
      final GlossScoreboardDoc doc = GlossScoreboardDoc();

      expect(
        renderGlossScoreboardTitle(doc.effectiveTitle('x' * 40)).plainText,
        'x' * 32,
      );
    });
  });
}

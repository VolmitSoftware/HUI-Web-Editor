library;

import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

extension on GlossScoreboardDoc {
  String effectiveTitle(String boardId) =>
      presentation.title.isEmpty ? boardId : presentation.title;
}

void main() {
  test('title preview preserves the complete rendered value', () {
    final GlossLineRender render = renderGlossScoreboardTitle('&a${'x' * 31}');

    expect(render.plainText, 'x' * 31);
  });

  test('title preview preserves surrogate and formatting sequences', () {
    expect(
      renderGlossScoreboardTitle('${'x' * 31}💡').plainText,
      '${'x' * 31}💡',
    );
    expect(
      renderGlossScoreboardTitle('${'x' * 31}&aGreen').plainText,
      '${'x' * 31}Green',
    );
    expect(
      renderGlossScoreboardTitle('${'x' * 25}[123456]RGB').plainText,
      '${'x' * 25}RGB',
    );
  });

  test('plain row preview preserves the full modern component', () {
    final GlossLineRender render = renderGlossScoreboardLine('x' * 40);

    expect(render.plainText, 'x' * 40);
  });

  test('legacy colour covers the complete row', () {
    final GlossLineRender render = renderGlossScoreboardLine('&a${'x' * 40}');

    expect(render.plainText, 'x' * 40);
    expect(<int>[
      for (final GlossTextPiece piece in render.pieces)
        if (piece case GlossTextRun(:final span)) span.color,
    ], everyElement(0x55FF55));
  });

  test('hex colour covers the complete row', () {
    final GlossLineRender render = renderGlossScoreboardLine('[123456]ABCDEF');

    expect(render.plainText, 'ABCDEF');
    expect(<int>[
      for (final GlossTextPiece piece in render.pieces)
        if (piece case GlossTextRun(:final span)) span.color,
    ], everyElement(0x123456));
  });

  test('a hex run remains intact anywhere in the row', () {
    final GlossLineRender render = renderGlossScoreboardLine(
      '${'x' * 10}[123456]ABCD',
    );

    expect(render.plainText, '${'x' * 10}ABCD');
  });

  test('a formerly over-limit hex run is preserved', () {
    final GlossLineRender render = renderGlossScoreboardLine(
      '${'x' * 25}[123456]RGB',
    );

    expect(render.plainText, '${'x' * 25}RGB');
  });

  test('full rows preserve surrogate and formatting suffixes', () {
    expect(
      renderGlossScoreboardLine('${'x' * 31}💡').plainText,
      '${'x' * 31}💡',
    );
    expect(
      renderGlossScoreboardLine('${'x' * 31}&aGreen').plainText,
      '${'x' * 31}Green',
    );
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

  test('measure reports full delivery without layout truncation', () {
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
    expect(clipped.truncated, isFalse);
    expect(clipped.encodedLength, 31);
    expect(clipped.visibleLength, 29);
    expect(clipped.deliveredVisibleLength, 29);
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
      final GlossScoreboardDoc doc = GlossScoreboardDoc(
        presentation: GlossScoreboardPresentation(title: '&d&lGloss'),
      );

      expect(doc.effectiveTitle('welcome'), '&d&lGloss');
      expect(
        renderGlossScoreboardTitle(doc.effectiveTitle('welcome')).plainText,
        'Gloss',
      );
    });

    test('the fallback tests isEmpty, not a trim', () {
      final GlossScoreboardDoc doc = GlossScoreboardDoc(
        presentation: GlossScoreboardPresentation(title: ' '),
      );

      expect(doc.effectiveTitle('welcome'), ' ');
    });

    test('the fallback id stays full width', () {
      final GlossScoreboardDoc doc = GlossScoreboardDoc();

      expect(
        renderGlossScoreboardTitle(doc.effectiveTitle('x' * 40)).plainText,
        'x' * 40,
      );
    });
  });
}

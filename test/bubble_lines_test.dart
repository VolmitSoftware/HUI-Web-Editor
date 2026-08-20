library;

import 'package:gloss_editor/logic/bubble_lines.dart';
import 'package:test/test.dart';

void main() {
  group('glossBubbleWrap', () {
    test('keeps a short message as one formatted block', () {
      expect(glossBubbleWrap('§ahello world', 32), '§ahello world');
      expect(glossBubbleWrappedLineCount('§ahello world'), 1);
    });

    test('soft-wraps words and hard-wraps oversized words', () {
      expect(glossBubbleWrap('one two three four', 9), 'one two\nthree\nfour');
      expect(glossBubbleWrap('abcdefghij', 4), 'abcd\nefgh\nij');
    });

    test('carries active color and decorations to inserted lines', () {
      expect(
        glossBubbleWrap('§ahello §lworld again', 7),
        '§ahello\n§a§lworld\n§a§lagain',
      );
      expect(glossBubbleWrap('§a§lbold §rplain', 4), '§a§lbold\n§a§l§rplai\nn');
    });

    test('renders a trusted prefix without charging formatting width', () {
      expect(
        glossBubbleWrap('hello world', 5, renderedPrefix: '§b'),
        '§bhello\n§bworld',
      );
      expect(
        glossBubbleWrap('§1Hello wonderful world', 8, renderedPrefix: '§7'),
        '§7§1Hello\n§1wonderfu\n§1l world',
      );
    });

    test('carries a Bungee RGB color to inserted lines', () {
      const String rgb = '§x§1§2§3§4§5§6';
      expect(glossBubbleWrap('${rgb}abcd efgh', 4), '${rgb}abcd\n${rgb}efgh');
    });

    test('raw ampersand and bracket colors stay literal chat text', () {
      expect(
        glossBubbleVisibleText('&1Hello [FF00FF]world'),
        '&1Hello [FF00FF]world',
      );
      expect(glossBubbleWrap('&ahello', 32), '&ahello');
    });

    test('preserves internal blank lines but drops trailing blank lines', () {
      final String wrapped = glossBubbleWrap('first\n\nsecond', 32);
      expect(wrapped, 'first\n\nsecond');
      expect(glossBubbleWrappedLineCount(wrapped), 3);
      expect(glossBubbleWrap('first\n\n', 32), 'first');
      expect(glossBubbleWrap('\n\n', 32), '');
    });

    test('matches tabs, CRLF, Unicode newlines, and nonbreaking spaces', () {
      expect(glossBubbleWrap('one\ttwo three', 5), 'one\ntwo\nthree');
      expect(glossBubbleWrap('a\r\nb\rc\u2028d\u2029', 8), 'a\nb\nc\nd');
      expect(glossBubbleWrap('a\u00A0b', 8), 'a\u00A0b');
    });

    test('counts a Unicode scalar as one visible character', () {
      expect(glossBubbleWrap('ab😀cd', 3), 'ab😀\ncd');
      expect(glossBubbleVisibleText('§d😀'), '😀');
    });

    test('formatting-only and whitespace-only messages yield no block', () {
      expect(glossBubbleWrap('§a§l', 32), '');
      expect(glossBubbleWrap('   ', 32), '');
      expect(glossBubbleWrappedLineCount(''), 0);
    });
  });
}

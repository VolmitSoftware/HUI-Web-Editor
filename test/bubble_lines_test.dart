/// The BubbleLines port: `§`-only colour stripping, the VolmLib soft wrap as
/// it actually behaves (quirk included), and the blank-line drop.
library;

import 'package:gloss_editor/logic/bubble_lines.dart';
import 'package:test/test.dart';

void main() {
  group('glossBubbleStripColors', () {
    test('drops § pairs and only § pairs', () {
      expect(glossBubbleStripColors('§ahello §lworld'), 'hello world');
      expect(glossBubbleStripColors('&ahello'), '&ahello',
          reason: '& codes pass through — only the client § form strips');
      expect(glossBubbleStripColors('trailing §'), 'trailing §',
          reason: 'a § with nothing after it stays');
      expect(glossBubbleStripColors(''), '');
    });
  });

  group('glossFormWrapWords', () {
    test('short text passes through unwrapped', () {
      expect(glossFormWrapWords('hello world', 32), 'hello world');
      expect(glossFormWrapWords('', 32), '');
    });

    test('wraps on spaces within the window — quirk included', () {
      // First window ("one two th") wraps at its LAST space, absolute. The
      // second window ("three four") holds a single space, which the shipped
      // VolmLib records window-relative (5) and then compares against the
      // absolute offset (8) — so the wrap point is "missed" and the window
      // hard-cuts. Java behavior is the contract; the port replays it.
      expect(
        glossFormWrapWords('one two three four', 9),
        'one two\nthree fou\nr',
      );
    });

    test('hard-cuts a word longer than the window (soft mode)', () {
      expect(glossFormWrapWords('abcdefghij', 4), 'abcd\nefgh\nij');
    });

    test('leading spaces at a window start are consumed', () {
      expect(glossFormWrapWords('a  b', 1), 'a\nb');
    });
  });

  group('glossBubbleSplit', () {
    test('strips, wraps at the style width and drops blank lines', () {
      // "wonderful wor" + "ld" is the shipped wrap's own answer — the
      // single-space window quirk again (see the wrap test above).
      expect(
        glossBubbleSplit('§dhello there wonderful world', 13),
        <String>['hello there', 'wonderful wor', 'ld'],
      );
    });

    test('a whitespace-only message yields no lines', () {
      expect(glossBubbleSplit('   ', 32), isEmpty);
      expect(glossBubbleSplit('§a§b', 32), isEmpty);
    });

    test('the shipped default width keeps every line inside the window', () {
      final List<String> lines = glossBubbleSplit(
        'Sure — let me grab my gear and some golden apples first.',
        32,
      );
      expect(lines.length, greaterThanOrEqualTo(2));
      for (final String line in lines) {
        expect(line.length, lessThanOrEqualTo(33));
        expect(line.trim(), isNotEmpty);
      }
    });
  });
}

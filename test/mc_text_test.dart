import 'package:gloss_editor/logic/mc_text.dart';
import 'package:test/test.dart';

const String section = '§';

/// Every legacy colour code and the RGB the vanilla client renders it as.
const Map<String, int> legacyColors = <String, int>{
  '0': 0x000000,
  '1': 0x0000AA,
  '2': 0x00AA00,
  '3': 0x00AAAA,
  '4': 0xAA0000,
  '5': 0xAA00AA,
  '6': 0xFFAA00,
  '7': 0xAAAAAA,
  '8': 0x555555,
  '9': 0x5555FF,
  'a': 0x55FF55,
  'b': 0x55FFFF,
  'c': 0xFF5555,
  'd': 0xFF55FF,
  'e': 0xFFFF55,
  'f': 0xFFFFFF,
};

McSpan onlySpan(String raw) {
  final McTextResult result = parseMcText(raw);
  expect(
    result.lines,
    hasLength(1),
    reason: 'expected exactly one line for "$raw"',
  );
  expect(
    result.lines.first,
    hasLength(1),
    reason: 'expected exactly one span for "$raw"',
  );
  return result.lines.first.first;
}

List<McSpan> onlyLine(String raw) {
  final McTextResult result = parseMcText(raw);
  expect(
    result.lines,
    hasLength(1),
    reason: 'expected exactly one line for "$raw"',
  );
  return result.lines.first;
}

List<int> colorsOf(List<McSpan> spans) =>
    spans.map((McSpan s) => s.rgb ?? -1).toList();

void main() {
  group('legacy colour codes', () {
    test('every &0-&f maps to the vanilla RGB', () {
      legacyColors.forEach((String code, int rgb) {
        final McSpan span = onlySpan('&${code}X');
        expect(span.text, 'X');
        expect(span.rgb, rgb, reason: 'code &$code');
        expect(span.bold, isFalse);
      });
    });

    test(
      'uppercase legacy codes are lowercased like translateAlternateColorCodes',
      () {
        expect(onlySpan('&CX').rgb, 0xFF5555);
        expect(onlySpan('&AX').rgb, 0x55FF55);
      },
    );

    test('raw section-sign codes are translated too', () {
      expect(onlySpan('${section}cX').rgb, 0xFF5555);
    });

    test('&l sets bold, &m strikethrough, &o italic', () {
      final McSpan bold = onlySpan('&lX');
      expect(bold.bold, isTrue);
      expect(bold.rgb, 0xFFFFFF);

      expect(onlySpan('&mX').strikethrough, isTrue);
      expect(onlySpan('&oX').italic, isTrue);
    });

    test('&r resets colour and decorations', () {
      final McSpan span = onlySpan('&c&l&rX');
      expect(span.text, 'X');
      expect(span.rgb, 0xFFFFFF);
      expect(span.bold, isFalse);
    });

    test('a doubled ampersand keeps the first one literal', () {
      final List<McSpan> spans = onlyLine('&&aX');
      expect(spans, hasLength(2));
      expect(spans[0].text, '&');
      expect(spans[0].rgb, 0xFFFFFF);
      expect(spans[1].text, 'X');
      expect(spans[1].rgb, 0x55FF55);
    });

    test('a trailing ampersand is literal', () {
      expect(onlySpan('X&').text, 'X&');
    });

    test('combined codes stack colour and decoration', () {
      final McSpan span = onlySpan('&6&lMy Menu');
      expect(span.text, 'My Menu');
      expect(span.rgb, 0xFFAA00);
      expect(span.bold, isTrue);
    });
  });

  group('legacy underline and obfuscated codes', () {
    test('&n enables underline', () {
      final McTextResult result = parseMcText('&nUnder');
      expect(result.lines.first.single.text, 'Under');
      expect(result.lines.first.single.underlined, isTrue);
      expect(result.warnings, isEmpty);
    });

    test('&k enables obfuscated text', () {
      final McTextResult result = parseMcText('&kSpooky');
      expect(result.lines.first.single.text, 'Spooky');
      expect(result.lines.first.single.obfuscated, isTrue);
      expect(result.warnings, isEmpty);
    });

    test('a hand-written <underline> tag gets the same treatment', () {
      final McTextResult result = parseMcText('<underline>x');
      expect(result.lines.first.single.text, '<underline>x');
      expect(result.warnings, hasLength(1));
    });

    test('repeated legacy codes stack their styles', () {
      final McTextResult result = parseMcText('&na&nb&kc');
      expect(result.warnings, isEmpty);
      expect(result.lines.first.last.obfuscated, isTrue);
      expect(result.lines.first.last.underlined, isTrue);
    });

    test('legacy colour and underline stack', () {
      final McSpan span = onlySpan('&c&nX');
      expect(span.text, 'X');
      expect(span.rgb, 0xFF5555);
      expect(span.underlined, isTrue);
    });
  });

  group('legacy hex sequences', () {
    // `TextUtils.legacyHex`: the `&x&r&r&g&g&b&b` form Bungee's ChatColor
    // serializes a hex colour to. It is checked BEFORE the single-character
    // codes, so the six pairs never read as six colours.
    String bungee(String hex) =>
        '§x${hex.split('').map((String d) => '§$d').join()}';

    test('the ampersand form becomes one colour', () {
      final McSpan span = onlySpan('&x&f&f&8&8&0&0Sale');
      expect(span.text, 'Sale');
      expect(span.rgb, 0xFF8800);
    });

    test('the section form becomes the same colour', () {
      expect(onlySpan('${bungee('ff8800')}Sale').rgb, 0xFF8800);
    });

    test('mixed markers and mixed case parse', () {
      expect(onlySpan('&x§F&f§8&8§0&0X').rgb, 0xFF8800);
    });

    test('a truncated sequence stays literal', () {
      // One pair short: the leading `&x` is not a known code, and the pairs
      // that follow fall through to the single-character translation.
      final List<McSpan> spans = onlyLine('&x&f&f&8&8&0X');
      expect(spans.first.text, '&x', reason: '&x is not a colour code');
      expect(spans.last.text, 'X');
      expect(spans.last.rgb, 0x000000, reason: 'the trailing &0 coloured it');
    });

    test('a non-hex digit stays literal', () {
      expect(onlyLine('&x&f&f&8&8&0&zX').first.text, startsWith('&x'));
    });

    test('the sequence costs no visible characters', () {
      expect(parseMcText('&x&f&f&8&8&0&0Sale').maxLineLength, 4);
    });
  });

  group('MiniMessage colours', () {
    test('named colour tags', () {
      expect(onlySpan('<gold>X').rgb, 0xFFAA00);
      expect(onlySpan('<dark_aqua>X').rgb, 0x00AAAA);
      expect(onlySpan('<light_purple>X').rgb, 0xFF55FF);
    });

    test('grey aliases resolve to gray', () {
      expect(onlySpan('<grey>X').rgb, 0xAAAAAA);
      expect(onlySpan('<dark_grey>X').rgb, 0x555555);
    });

    test('hex tags', () {
      expect(onlySpan('<#ff8800>X').rgb, 0xFF8800);
      expect(onlySpan('<#FF8800>X').rgb, 0xFF8800);
      expect(onlySpan('<#f80>X').rgb, 0xFF8800);
    });

    test('color / colour / c tags', () {
      expect(onlySpan('<color:gold>X').rgb, 0xFFAA00);
      expect(onlySpan('<colour:#123456>X').rgb, 0x123456);
      expect(onlySpan('<c:red>X').rgb, 0xFF5555);
    });

    test('an invalid colour argument is an unknown tag', () {
      final McTextResult result = parseMcText('<color:banana>X');
      expect(result.lines.first.single.text, '<color:banana>X');
      expect(result.warnings, hasLength(1));
    });

    test('default colour is white', () {
      expect(onlySpan('plain').rgb, 0xFFFFFF);
      expect(mcDefaultTextColor, 0xFFFFFF);
    });
  });

  group('decorations', () {
    test('all decoration tags and their aliases', () {
      expect(onlySpan('<bold>X').bold, isTrue);
      expect(onlySpan('<b>X').bold, isTrue);
      expect(onlySpan('<italic>X').italic, isTrue);
      expect(onlySpan('<i>X').italic, isTrue);
      expect(onlySpan('<em>X').italic, isTrue);
      expect(onlySpan('<underlined>X').underlined, isTrue);
      expect(onlySpan('<u>X').underlined, isTrue);
      expect(onlySpan('<strikethrough>X').strikethrough, isTrue);
      expect(onlySpan('<st>X').strikethrough, isTrue);
      expect(onlySpan('<obfuscated>X').obfuscated, isTrue);
      expect(onlySpan('<obf>X').obfuscated, isTrue);
    });

    test('obfuscated is available through MiniMessage and &k', () {
      expect(onlySpan('<obfuscated>hidden').obfuscated, isTrue);
      expect(parseMcText('&khidden').lines.first.single.obfuscated, isTrue);
    });
  });

  group('nesting and closing tags', () {
    test('closing a decoration restores the outer style', () {
      final List<McSpan> spans = onlyLine('<red>a<bold>b</bold>c');
      expect(spans, hasLength(3));
      expect(spans[0], const McSpan(text: 'a', rgb: 0xFF5555));
      expect(spans[1], const McSpan(text: 'b', rgb: 0xFF5555, bold: true));
      expect(spans[2], const McSpan(text: 'c', rgb: 0xFF5555));
    });

    test('closing a colour restores the previous colour', () {
      final List<McSpan> spans = onlyLine('<red>a<blue>b</blue>c');
      expect(colorsOf(spans), <int>[0xFF5555, 0x5555FF, 0xFF5555]);
    });

    test('</color> closes <color:red>', () {
      final List<McSpan> spans = onlyLine('<color:red>a</color>b');
      expect(colorsOf(spans), <int>[0xFF5555, 0xFFFFFF]);
    });

    test('closing an outer tag also closes everything opened inside it', () {
      final List<McSpan> spans = onlyLine('<bold>a<red>b</bold>c');
      expect(spans[2].text, 'c');
      expect(spans[2].bold, isFalse);
      expect(spans[2].rgb, 0xFFFFFF);
    });

    test('an unmatched closing tag is a no-op and warns', () {
      final McTextResult result = parseMcText('a</bold>b');
      expect(result.lines.first.single.text, 'ab');
      expect(result.warnings, hasLength(1));
      expect(result.warnings.single, contains('</bold>'));
    });

    test('adjacent identical styles coalesce into one span', () {
      expect(onlySpan('<red>a<red>b').text, 'ab');
    });
  });

  group('reset', () {
    test('<reset> drops every open tag', () {
      final List<McSpan> spans = onlyLine('<red><bold>a<reset>b');
      expect(spans, hasLength(2));
      expect(spans[1], const McSpan(text: 'b', rgb: 0xFFFFFF));
    });
  });

  group('gradients', () {
    test('two stops interpolate per character', () {
      final List<McSpan> spans = onlyLine(
        '<gradient:#000000:#ffffff>abcde</gradient>',
      );
      expect(spans, hasLength(5));
      expect(spans.map((McSpan s) => s.text).join(), 'abcde');
      expect(colorsOf(spans), <int>[
        0x000000,
        0x404040,
        0x808080,
        0xBFBFBF,
        0xFFFFFF,
      ]);
    });

    test('three stops walk each segment', () {
      final List<McSpan> spans = onlyLine(
        '<gradient:red:green:blue>abc</gradient>',
      );
      expect(colorsOf(spans), <int>[0xFF5555, 0x55FF55, 0x5555FF]);
    });

    test('a single character gets the first stop', () {
      expect(onlySpan('<gradient:red:blue>a</gradient>').rgb, 0xFF5555);
    });

    test('decorations nested in a gradient keep the gradient colour', () {
      final List<McSpan> spans = onlyLine(
        '<gradient:#000000:#ffffff>ab<bold>cde</bold></gradient>',
      );
      expect(spans, hasLength(5));
      expect(colorsOf(spans), <int>[
        0x000000,
        0x404040,
        0x808080,
        0xBFBFBF,
        0xFFFFFF,
      ]);
      expect(spans[2].bold, isTrue);
      expect(spans[0].bold, isFalse);
    });

    test(
      'an inner solid colour overrides the gradient but still consumes it',
      () {
        final List<McSpan> spans = onlyLine(
          '<gradient:#000000:#ffffff>a<red>b</red>c</gradient>',
        );
        expect(colorsOf(spans), <int>[0x000000, 0xFF5555, 0xFFFFFF]);
      },
    );

    test('a gradient without stops defaults to white to black', () {
      final List<McSpan> spans = onlyLine('<gradient>ab</gradient>');
      expect(colorsOf(spans), <int>[0xFFFFFF, 0x000000]);
    });

    test('a gradient with one stop is an unknown tag', () {
      final McTextResult result = parseMcText('<gradient:red>ab</gradient>');
      expect(result.lines.first.first.text, startsWith('<gradient:red>'));
      expect(result.warnings, isNotEmpty);
    });

    test('a trailing numeric phase argument is accepted', () {
      final List<McSpan> spans = onlyLine(
        '<gradient:#000000:#ffffff:0.5>abcde</gradient>',
      );
      expect(spans, hasLength(5));
      expect(spans.first.rgb, isNot(0x000000));
    });

    test('text after the gradient closes is unaffected', () {
      final List<McSpan> spans = onlyLine(
        '<gradient:#000000:#888888>ab</gradient>tail',
      );
      expect(spans, hasLength(3));
      expect(colorsOf(spans), <int>[0x000000, 0x888888, 0xFFFFFF]);
      expect(spans.last.text, 'tail');
    });
  });

  group('unknown tags', () {
    test('render literally and warn', () {
      final McTextResult result = parseMcText('<nope>text');
      expect(result.lines.first.single.text, '<nope>text');
      expect(result.warnings, hasLength(1));
      expect(result.warnings.single, contains('<nope>'));
    });

    test('a bare less-than is literal text', () {
      expect(onlySpan('1 < 2').text, '1 < 2');
      expect(parseMcText('1 < 2').warnings, isEmpty);
    });

    test('an unterminated tag is literal text', () {
      expect(onlySpan('<red').text, '<red');
    });

    test('placeholders survive untouched', () {
      expect(onlySpan('%player_name%').text, '%player_name%');
    });
  });

  group('line splitting', () {
    test('splits before parsing so style state resets per line', () {
      final McTextResult result = parseMcText('&aone\ntwo');
      expect(result.lines, hasLength(2));
      expect(result.lines[0].single.rgb, 0x55FF55);
      expect(result.lines[1].single.rgb, 0xFFFFFF);
    });

    test('an unclosed tag does not bleed into the next line', () {
      final McTextResult result = parseMcText('<bold>a\nb');
      expect(result.lines[0].single.bold, isTrue);
      expect(result.lines[1].single.bold, isFalse);
    });

    test('an interior blank line is preserved as an empty line', () {
      final McTextResult result = parseMcText('a\n\nb');
      expect(result.lines, hasLength(3));
      expect(result.lines[1], isEmpty);
    });

    test('the empty string produces one empty line', () {
      final McTextResult result = parseMcText('');
      expect(result.lines, hasLength(1));
      expect(result.lines.single, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('trailing blank lines are dropped, matching Java String.split', () {
      expect(parseMcText('a\n').lines, hasLength(1));
      expect(parseMcText('a\n\n\n').lines, hasLength(1));
      expect(parseMcText('\n').lines, isEmpty);
    });

    test('warnings are collected across every line', () {
      final McTextResult result = parseMcText('&na\n<nope>b');
      expect(result.warnings, hasLength(1));
    });
  });

  group('result helpers', () {
    test('plainLines strips every tag', () {
      final McTextResult result = parseMcText('<red>Shop\n&lTools');
      expect(result.plainLines, <String>['Shop', 'Tools']);
      expect(result.plainText, 'Shop\nTools');
    });

    test('maxLineLength is the widest plain line, as the hitbox uses', () {
      final McTextResult result = parseMcText('<red>abc\nabcdef');
      expect(result.maxLineLength, 6);
      expect(result.lineCount, 2);
    });

    test('maxLineLength of the empty string is zero', () {
      expect(parseMcText('').maxLineLength, 0);
    });
  });

  group('McSpan value semantics', () {
    test('equality covers text, colour and every flag', () {
      const McSpan a = McSpan(text: 'x', rgb: 0xFF0000, bold: true);
      const McSpan b = McSpan(text: 'x', rgb: 0xFF0000, bold: true);
      const McSpan c = McSpan(text: 'x', rgb: 0xFF0000);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('isStyled reports any decoration', () {
      const McSpan plain = McSpan(text: 'x');
      const McSpan styled = McSpan(text: 'x', italic: true);
      expect(plain.isStyled, isFalse);
      expect(styled.isStyled, isTrue);
    });
  });
}

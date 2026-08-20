library;

import 'dart:io';

import 'package:gloss_editor/logic/bubble_shimmer.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

const String _white = '§x§f§f§f§f§f§f';
const String _tint = '§x§f§f§8§8§f§f';
const String _glyphs =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

GlossBubbleShimmer _shipped() => GlossBubbleShimmer();

String _line(int from, int glyphCount) {
  final StringBuffer text = StringBuffer('§7');
  for (int index = 0; index < glyphCount; index++) {
    text.write(_glyphs[from + index]);
  }
  return text.toString();
}

String _block(int lines, int glyphsPerLine) => <String>[
  for (int row = 0; row < lines; row++)
    _line(row * glyphsPerLine, glyphsPerLine),
].join('\n');

List<int> _glyphsWearing(String rendered, String code, int totalGlyphs) =>
    <int>[
      for (int index = 0; index < totalGlyphs; index++)
        if (rendered.contains('$code${_glyphs[index]}')) index,
    ];

int? _band(
  GlossBubbleShimmer shimmer,
  String text,
  int ageMs,
  int lifetimeMs,
) => glossBubbleShimmerBandIndex(
  shimmer,
  input: text,
  ageMs: ageMs,
  lifetimeMs: lifetimeMs,
);

String _renderAt(GlossBubbleShimmer shimmer, String text, int? band) =>
    glossBubbleApplyShimmer(text, shimmer, band);

int _occurrences(String input, String needle) {
  int count = 0;
  int cursor = 0;
  while ((cursor = input.indexOf(needle, cursor)) >= 0) {
    count++;
    cursor += needle.length;
  }
  return count;
}

void main() {
  group('two-pass timeline', () {
    test('waits before spawn and runs again during fly-away', () {
      final GlossBubbleShimmer shimmer = _shipped();
      final String input = _line(0, 26);

      expect(_band(shimmer, input, 399, 5000), isNull);
      expect(_band(shimmer, input, 400, 5000), 0);
      expect(_band(shimmer, input, 750, 5000), 13);
      expect(_band(shimmer, input, 1100, 5000), 25);
      expect(_band(shimmer, input, 1101, 5000), isNull);
      expect(_band(shimmer, input, 4299, 5000), isNull);
      expect(_band(shimmer, input, 4300, 5000), 0);
      expect(_band(shimmer, input, 4650, 5000), 13);
      expect(_band(shimmer, input, 5000, 5000), 25);
    });

    test('uses one solid white three-glyph band', () {
      final String rendered = _renderAt(_shipped(), _line(0, 26), 3);

      expect(_glyphsWearing(rendered, _white, 26), <int>[2, 3, 4]);
      expect(rendered, contains('${_white}c§7${_white}d§7${_white}e§7'));
    });

    test('one band crosses wrapped rows without restarting', () {
      final String rendered = _renderAt(_shipped(), _block(2, 8), 8);

      expect(_glyphsWearing(rendered, _white, 16), <int>[7, 8, 9]);
    });

    test('long multiline blocks never create copied bands', () {
      final String row = List<String>.filled(40, 'a').join();
      final String input = List<String>.filled(4, row).join('\n');
      final String rendered = _renderAt(_shipped(), input, 130);

      expect(_occurrences(rendered, _white), 3);
    });

    test('restores active color and decorations after every lit glyph', () {
      final GlossBubbleShimmer shimmer = _shipped();
      expect(_renderAt(shimmer, '§7Hello', 0), '§7${_white}H§7${_white}e§7llo');
      expect(
        _renderAt(shimmer, '§aHi §lBob', 3),
        '§aHi$_white §a§l${_white}B§a§l${_white}o§a§lb',
      );
    });

    test('preserves Unicode glyphs and complete RGB formatting sequences', () {
      final GlossBubbleShimmer shimmer = _shipped();
      expect(
        _renderAt(shimmer, '§x§1§2§3§4§5§6🚀A', 0),
        '§x§1§2§3§4§5§6$_white🚀§x§1§2§3§4§5§6${_white}A§x§1§2§3§4§5§6',
      );
    });
  });

  group('configuration', () {
    test('custom color and even widths apply exactly that many glyphs', () {
      final GlossBubbleShimmer shimmer = GlossBubbleShimmer(
        color: '#ff88ff',
        width: 4,
      );
      expect(
        _glyphsWearing(_renderAt(shimmer, _line(0, 26), 10), _tint, 26),
        <int>[9, 10, 11, 12],
      );
    });

    test('disabled windows stay inactive', () {
      final GlossBubbleShimmer shimmer = GlossBubbleShimmer(
        spawn: false,
        flyAway: false,
      );
      const String input = '§7No band here';

      expect(_band(shimmer, input, 2500, 5000), isNull);
      expect(_renderAt(shimmer, input, null), same(input));
    });
  });

  group('drive cadence', () {
    test('a long default sweep changes on almost every animation frame', () {
      final GlossBubbleShimmer shimmer = _shipped();
      final String input = List<String>.filled(160, 'a').join();
      final Set<int?> sampled = <int?>{
        for (int ageMs = 400; ageMs <= 1100; ageMs += 8)
          _band(shimmer, input, ageMs, 5000),
      };

      expect(sampled.length, greaterThanOrEqualTo(80));
    });

    test('the editor drives shimmer repaints from animation frames', () {
      final String view = File(
        'lib/components/bubble/bubble_view.dart',
      ).readAsStringSync();
      expect(view, contains('requestAnimationFrame'));
      expect(view, contains('_playing && _store.animationsPlaying'));
    });

    test('the inspector exposes the original Gloss preset', () {
      final String inspector = File(
        'lib/components/inspector/bubble_inspector.dart',
      ).readAsStringSync();
      expect(inspector, contains("Text('Original Gloss')"));
      expect(inspector, contains('edited.shimmer = GlossBubbleShimmer()'));
    });
  });
}

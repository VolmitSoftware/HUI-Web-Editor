library;

import 'dart:io';

import 'package:gloss_editor/logic/bubble_shimmer.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

const int _shineTick = 127;
const String _white = '§x§f§f§f§f§f§f';
const String _tint = '§x§f§f§8§8§f§f';
const String _glyphs =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

GlossBubbleShimmer _shipped() => GlossBubbleShimmer();

int _legacyHead(int elapsedMs) => elapsedMs * 3 ~/ 100;

bool _legacyLit(int elapsedMs, int at) {
  final int delta = _legacyHead(elapsedMs) - at;
  return (delta - (delta ~/ _shineTick) * _shineTick).abs() < 2;
}

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

int? _headAt(GlossBubbleShimmer shimmer, int ageMs, int lifetimeMs) =>
    glossBubbleShimmerHead(shimmer, ageMs: ageMs, lifetimeMs: lifetimeMs);

String _renderAt(GlossBubbleShimmer shimmer, String text, int? head) =>
    glossBubbleApplyShimmer(text, shimmer, head);

void main() {
  group('legacy law', () {
    test('matches the exact integer head timeline', () {
      final GlossBubbleShimmer shimmer = _shipped();
      const List<int> ages = <int>[
        0,
        33,
        34,
        66,
        67,
        99,
        100,
        4200,
        4233,
        4234,
        4266,
        4267,
        5000,
      ];
      const List<int> heads = <int>[
        0,
        0,
        1,
        1,
        2,
        2,
        3,
        126,
        126,
        127,
        127,
        128,
        150,
      ];

      for (int index = 0; index < ages.length; index++) {
        expect(_headAt(shimmer, ages[index], 5000), heads[index]);
      }
    });

    test('matches the original predicate on every wrapped row', () {
      final GlossBubbleShimmer shimmer = _shipped();
      final String input = _block(3, 10);

      for (
        int ageMs = 0;
        ageMs <= glossBubbleShimmerDefaultDurationMs + 34;
        ageMs++
      ) {
        final List<int> expected = <int>[
          for (int row = 0; row < 3; row++)
            for (int at = 0; at < 10; at++)
              if (_legacyLit(ageMs, at)) row * 10 + at,
        ];
        expect(
          _glyphsWearing(
            _renderAt(shimmer, input, _headAt(shimmer, ageMs, 5000)),
            _white,
            30,
          ),
          expected,
          reason: 'ageMs=$ageMs',
        );
      }
    });

    test('uses one solid white three-glyph band', () {
      final GlossBubbleShimmer shimmer = _shipped();
      final String rendered = _renderAt(shimmer, _line(0, 26), 3);

      expect(_glyphsWearing(rendered, _white, 26), <int>[2, 3, 4]);
      expect(rendered, contains('${_white}c§7${_white}d§7${_white}e§7'));
    });

    test('restarts the band at the left edge of every line', () {
      final String rendered = _renderAt(_shipped(), _block(2, 8), 3);
      expect(_glyphsWearing(rendered, _white, 16), <int>[2, 3, 4, 10, 11, 12]);
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

    test('spawn free-runs and the optional departure restart is explicit', () {
      final GlossBubbleShimmer shipped = _shipped();
      final GlossBubbleShimmer departure = GlossBubbleShimmer(flyAway: true);
      final GlossBubbleShimmer delayed = GlossBubbleShimmer(spawnDelayMs: 500);

      expect(shipped.flyAway, isFalse);
      expect(_headAt(shipped, 4300, 5000), 129);
      expect(_headAt(departure, 4300, 5000), 0);
      expect(_headAt(delayed, 499, 5000), isNull);
      expect(_headAt(delayed, 500, 5000), 0);
    });

    test('off-text frames return the original string unchanged', () {
      const String input = '§7No band here';
      expect(_renderAt(_shipped(), input, 60), same(input));
    });
  });

  group('drive cadence', () {
    test('the default step is faster than a Minecraft tick', () {
      expect(glossBubbleShimmerStepMs(_shipped()), closeTo(33.33, 0.01));
      expect(glossBubbleShimmerStepMs(_shipped()), lessThan(50));
    });

    test('the editor drives shimmer repaints from animation frames', () {
      final String view = File(
        'lib/components/bubble/bubble_view.dart',
      ).readAsStringSync();
      expect(view, contains('requestAnimationFrame'));
      expect(view, contains('_playing && _store.animationsPlaying'));
    });

    test('the inspector exposes the exact original Gloss preset', () {
      final String inspector = File(
        'lib/components/inspector/bubble_inspector.dart',
      ).readAsStringSync();
      expect(inspector, contains("Text('Original Gloss')"));
      expect(inspector, contains('edited.shimmer = GlossBubbleShimmer()'));
    });
  });
}

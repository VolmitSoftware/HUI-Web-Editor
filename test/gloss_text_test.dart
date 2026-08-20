/// The Gloss text-pipeline mirror: `TextPipeline.java` scan and colour
/// semantics, animation substitution and the editor's chips/warnings on top.
library;

import 'package:gloss_editor/logic/gloss_animation_playback.dart';
import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/logic/mc_text.dart' show McSpan;
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

final class _Animations implements GlossAnimationResolver {
  _Animations(this.docs);

  final Map<String, GlossAnimationDoc> docs;

  @override
  List<String> get ids => docs.keys.toList()..sort();

  @override
  GlossAnimationDoc? byId(String id) => docs[id];
}

GlossAnimationDoc _clip(List<String> frames, {int intervalMs = 100}) =>
    GlossAnimationDoc(frameIntervalMs: intervalMs, frames: frames);

String _plain(GlossLineRender render) => render.plainText;

List<McSpan> _spans(GlossLineRender render) => <McSpan>[
  for (final GlossTextPiece piece in render.pieces)
    if (piece is GlossTextRun) piece.span,
];

void main() {
  test('color-only animation frames get a preview-only sample word', () {
    final GlossLineRender rendered = renderGlossAnimationFramePreview(
      '[FF3300]',
    );
    final GlossTextRun run = rendered.pieces.whereType<GlossTextRun>().single;
    expect(run.span.text, 'RAINBOW');
    expect(run.span.color, 0xFF3300);
    expect(run.span.bold, isTrue);
  });

  group('function substitution (TextPipeline.applyFunctions)', () {
    test('a known animation reference plays its frame at nowMs', () {
      final _Animations animations = _Animations(<String, GlossAnimationDoc>{
        'rainbow': _clip(<String>['A', 'B', 'C']),
      });
      expect(
        _plain(
          renderGlossLine(
            '>|animation.rainbow|<',
            animations: animations,
            nowMs: 0,
          ),
        ),
        '>A<',
      );
      expect(
        _plain(
          renderGlossLine(
            '>|animation.rainbow|<',
            animations: animations,
            nowMs: 100,
          ),
        ),
        '>B<',
      );
    });

    test('an unregistered name stays literal', () {
      final GlossLineRender render = renderGlossLine('|metric.tps| tps');
      expect(_plain(render), '|metric.tps| tps');
      expect(render.missingAnimations, isEmpty);
    });

    test('the closing pipe of an unknown name opens the next candidate — the '
        'Java scan\'s open = close', () {
      final _Animations animations = _Animations(<String, GlossAnimationDoc>{
        'x': _clip(<String>['F']),
      });
      // |a| is unknown; its closing pipe pairs with the next one, so the
      // scan sees name "animation.x" and substitutes it.
      expect(
        _plain(renderGlossLine('|a|animation.x|', animations: animations)),
        '|aF',
      );
    });

    test('a missing animation id is literal text plus a warning', () {
      final GlossLineRender render = renderGlossLine('|animation.nope|');
      expect(_plain(render), '|animation.nope|');
      expect(render.missingAnimations, <String>['animation.nope']);
      expect(
        glossLineMissingAnimationRefs(
          '|animation.nope|',
          const GlossNoAnimations(),
        ),
        <String>['animation.nope'],
      );
    });

    test('a dangling pipe never substitutes', () {
      final _Animations animations = _Animations(<String, GlossAnimationDoc>{
        'x': _clip(<String>['F']),
      });
      expect(
        _plain(renderGlossLine('|animation.x', animations: animations)),
        '|animation.x',
      );
    });

    test('used ids are reported for the animation gate', () {
      final _Animations animations = _Animations(<String, GlossAnimationDoc>{
        'x': _clip(<String>['F']),
      });
      expect(
        glossLineAnimationRefs('|animation.x| |animation.x|', animations),
        <String>['x'],
      );
      expect(glossLineAnimationRefs('static', animations), isEmpty);
    });
  });

  group('placeholders', () {
    test('%...% becomes a chip and text around it keeps its style run', () {
      final GlossLineRender render = renderGlossLine('&aHi %player_name%!');
      expect(render.placeholders, <String>['%player_name%']);
      final GlossPlaceholderChip chip = render.pieces
          .whereType<GlossPlaceholderChip>()
          .single;
      expect(chip.name, 'player_name');
      expect(chip.style.rgb, 0x55FF55, reason: 'chip inherits the green run');
      expect(_plain(render), 'Hi %player_name%!');
    });

    test('a lone percent sign is literal', () {
      expect(_plain(renderGlossLine('100% done')), '100% done');
      expect(renderGlossLine('100% done').placeholders, isEmpty);
    });

    test('placeholders inside a substituted frame are chipped too', () {
      final _Animations animations = _Animations(<String, GlossAnimationDoc>{
        'p': _clip(<String>['%online%']),
      });
      expect(
        renderGlossLine('|animation.p|', animations: animations).placeholders,
        <String>['%online%'],
      );
    });
  });

  group('authored text expressions', () {
    test('math, selection, progress bars and colours render inline', () {
      expect(
        _plain(
          renderGlossLine("HP {{ bar(player.health, 20, 10, '█', '░') }}"),
        ),
        'HP █████████░',
      );
      expect(
        _spans(
          renderGlossLine('{{ hex(mix(#FF0000, #0000FF, 0.5)) }}Pulse'),
        ).single.rgb,
        0x800080,
      );
      expect(_plain(renderGlossLine("{{ select(['A', 'B', 'C'], 4) }}")), 'B');
    });

    test('time expressions animate without a separate animation document', () {
      final GlossLineRender first = renderGlossLine(
        "{{ select(['&c', '&b'], floor(time.seconds * 4)) }}Pulse",
        nowMs: 0,
      );
      final GlossLineRender second = renderGlossLine(
        "{{ select(['&c', '&b'], floor(time.seconds * 4)) }}Pulse",
        nowMs: 250,
      );
      expect(_spans(first).single.rgb, 0xFF5555);
      expect(_spans(second).single.rgb, 0x55FFFF);
      expect(first.isAnimated, isTrue);
      expect(first.expressions, isNotEmpty);
    });

    test('native player and server getters need no extension samples', () {
      expect(
        _plain(
          renderGlossLine(
            '{{ player.name }} {{ player.ping }}ms '
            '{{ server.online }}/{{ server.maxPlayers }} '
            '{{ fixed(server.tps, 1) }} TPS',
          ),
        ),
        'Builder 42ms 86/250 19.8 TPS',
      );
    });

    test('PAPI and metrics use preview samples or explicit fallbacks', () {
      expect(_plain(renderGlossLine("{{ papi('player_name') }}")), 'Builder');
      expect(
        _plain(renderGlossLine("{{ fixed(metric('react.tps'), 1) }} TPS")),
        '19.8 TPS',
      );
      expect(
        _plain(renderGlossLine("{{ papi('vault_prefix', 'Member') }}")),
        'Member',
      );
      expect(
        _plain(
          renderGlossLine("{{ fixed(papiNumber('vault_eco_balance', 0), 2) }}"),
        ),
        '0.00',
      );
      expect(
        _plain(
          renderGlossLine(
            "{{ fixed(metric('missing.value', server.tps), 1) }}",
          ),
        ),
        '19.8',
      );
      final GlossLineRender unknown = renderGlossLine("{{ papi('custom_x') }}");
      expect(unknown.placeholders, <String>['%custom_x%']);
    });

    test('invalid code stays visible and reports an editor error', () {
      final GlossLineRender render = renderGlossLine('{{ nope() }}');
      expect(_plain(render), '{{ nope() }}');
      expect(render.expressionErrors, isNotEmpty);
    });
  });

  group('colours', () {
    test('bracket hex needs exactly six hex digits then a bracket', () {
      final List<McSpan> spans = _spans(renderGlossLine('[FF8800]hot'));
      expect(spans.single.rgb, 0xFF8800);
      expect(spans.single.text, 'hot');
      // Guard failures stay literal, exactly like translateBracketHex.
      expect(_plain(renderGlossLine('[FF88]short')), '[FF88]short');
      expect(_plain(renderGlossLine('[GGGGGG]bad')), '[GGGGGG]bad');
      expect(_plain(renderGlossLine('tail[FFFFFF')), 'tail[FFFFFF');
    });

    test('legacy & codes colour and decorate; colour resets decorations', () {
      final List<McSpan> spans = _spans(renderGlossLine('&c&lBold&aplain'));
      expect(spans, hasLength(2));
      expect(spans[0].rgb, 0xFF5555);
      expect(spans[0].bold, isTrue);
      expect(spans[1].rgb, 0x55FF55);
      expect(spans[1].bold, isFalse, reason: 'a colour code resets formats');
    });

    test('&r resets colour and formats', () {
      final List<McSpan> spans = _spans(renderGlossLine('&c&nred&rback'));
      expect(spans[1].rgb, 0xFFFFFF);
      expect(spans[1].underlined, isFalse);
    });

    test('an unknown code is literal, like translateAlternateColorCodes', () {
      expect(_plain(renderGlossLine('&zkeep')), '&zkeep');
    });

    test('section signs are honoured like the client does', () {
      expect(_spans(renderGlossLine('§edough')).single.rgb, 0xFFFF55);
    });

    test('bungee hex sequences resolve', () {
      final List<McSpan> spans = _spans(renderGlossLine('&x&1&2&a&b&c&dhex'));
      expect(spans.single.rgb, 0x12ABCD);
      expect(spans.single.text, 'hex');
    });

    test('colour state flows across a substituted animation frame', () {
      final _Animations animations = _Animations(<String, GlossAnimationDoc>{
        'c': _clip(<String>['&b']),
      });
      final GlossLineRender render = renderGlossLine(
        '|animation.c|aqua now',
        animations: animations,
      );
      expect(_spans(render).single.rgb, 0x55FFFF);
    });
  });

  group('glossLineMaxVisibleLength', () {
    test('strips colour codes and keeps placeholder tokens verbatim', () {
      expect(
        glossLineMaxVisibleLength('&a&l[FF0000]abc', const GlossNoAnimations()),
        3,
      );
      expect(glossLineMaxVisibleLength('%x%', const GlossNoAnimations()), 3);
    });

    test('substitutes the longest frame of a known animation', () {
      final _Animations animations = _Animations(<String, GlossAnimationDoc>{
        'w': _clip(<String>['&ashort', 'the longest frame']),
      });
      expect(
        glossLineMaxVisibleLength('>|animation.w|<', animations),
        '>the longest frame<'.length,
      );
    });
  });

  group('determinism', () {
    test('the same nowMs always renders the same line', () {
      final _Animations animations = _Animations(<String, GlossAnimationDoc>{
        'r': GlossAnimationDoc(
          mode: 'random',
          frameIntervalMs: 50,
          frames: <String>['1', '2', '3', '4', '5'],
        ),
      });
      final String first = _plain(
        renderGlossLine(
          '|animation.r|',
          animations: animations,
          nowMs: 123456789,
        ),
      );
      final String second = _plain(
        renderGlossLine(
          '|animation.r|',
          animations: animations,
          nowMs: 123456789,
        ),
      );
      expect(first, second);
      expect(
        first,
        animations.docs['r']!.frames[glossAnimationFrameIndexAt(
          animations.docs['r']!,
          'r',
          123456789,
        )],
      );
    });
  });
}

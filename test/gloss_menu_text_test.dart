/// The menu text path: `TextPipeline.renderMenuText` feeding
/// `TextUtils.parse`.
///
/// Menu text now uses the same full viewer-aware pipeline as other authored
/// Gloss text. The browser supplies deterministic expression samples and
/// leaves raw PlaceholderAPI tokens visible because it has no live server.
library;

import 'package:gloss_editor/logic/canvas_scene.dart';
import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/logic/hui_geometry.dart';
import 'package:gloss_editor/logic/mc_text.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

final class _Emoji implements GlossEmojiResolver {
  _Emoji(this.entries);

  @override
  final List<GlossEmojiEntry> entries;
}

final class _MenuAnimations implements GlossAnimationResolver {
  _MenuAnimations()
    : document = GlossAnimationDoc(
        frameIntervalMs: 100,
        frames: <String>['A', 'B'],
      );

  final GlossAnimationDoc document;

  @override
  List<String> get ids => const <String>['rainbow'];

  @override
  GlossAnimationDoc? byId(String id) => id == 'rainbow' ? document : null;
}

const GlossEmojiEntry _heart = GlossEmojiEntry(
  id: 'heart',
  trigger: '<3',
  glyph: '❤',
  enabled: true,
);

const GlossEmojiEntry _check = GlossEmojiEntry(
  id: 'check',
  trigger: '',
  glyph: '✓',
  enabled: true,
);

/// `§x§r§r§g§g§b§b` — what `ChatColor.of("#rrggbb")` serializes to.
String _bungee(String hex) =>
    '§x${hex.split('').map((String d) => '§$d').join()}';

CanvasItem _textItem(
  String text,
  GlossEmojiResolver emoji, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
  int animationTicks = 0,
  int? refreshTicks,
}) => buildCanvasScene(
  menu: HuiMenu(
    offset: Vec3.zero(),
    components: <HuiComponent>[
      HuiComponent(
        'label',
        Vec3.zero(),
        HuiDecorationData(HuiTextIcon(text, null, refreshTicks)),
      ),
    ],
  ),
  uiScale: 1,
  trueRender: true,
  togglePreview: (String _) => true,
  textCache: McTextCache(),
  animations: animations,
  emoji: emoji,
  animationTicks: animationTicks,
).items.single;

void main() {
  group('glossRenderMenuText mirrors TextPipeline.renderMenuText', () {
    test('substitutes emoji tokens and triggers', () {
      final _Emoji emoji = _Emoji(<GlossEmojiEntry>[_check, _heart]);
      expect(glossRenderMenuText('buy :heart: <3', emoji: emoji), 'buy ❤ ❤');
      expect(glossRenderMenuText(':check: done', emoji: emoji), '✓ done');
    });

    test('plays registered animations and keeps unknown functions literal', () {
      final _Emoji emoji = _Emoji(<GlossEmojiEntry>[_heart]);
      expect(
        glossRenderMenuText(
          '|animation.rainbow| :heart:',
          animations: _MenuAnimations(),
          emoji: emoji,
          nowMs: 100,
        ),
        'B ❤',
      );
      expect(
        glossRenderMenuText('|metric.react.tps|', emoji: emoji),
        '|metric.react.tps|',
      );
      expect(glossRenderMenuText('a | b'), 'a | b');
    });

    test('evaluates viewer expressions and native PAPI helpers', () {
      expect(
        glossRenderMenuText(
          "Hello {{ player.name }} {{ papi('server_online') }}",
        ),
        'Hello Builder 86',
      );
    });

    test('leaves raw %placeholder% tokens visible in the browser', () {
      expect(glossRenderMenuText('%player_name%'), '%player_name%');
    });

    test('translates [RRGGBB] to the Bungee hex form', () {
      expect(
        glossRenderMenuText('[Ff8800]Sale'),
        '${_bungee('ff8800')}Sale',
        reason: 'the plugin lowercases the digits before ChatColor.of',
      );
      expect(
        glossRenderMenuText('a[001122]b[334455]c'),
        'a${_bungee('001122')}b${_bungee('334455')}c',
      );
    });

    test('a token that fails the guard stays literal', () {
      // Not six hex digits, no closing bracket at open+7, and truncated.
      expect(glossRenderMenuText('[gg8800]x'), '[gg8800]x');
      expect(glossRenderMenuText('[ff88001]x'), '[ff88001]x');
      expect(glossRenderMenuText('[ff880]'), '[ff880]');
      expect(glossRenderMenuText('plain'), 'plain');
    });

    test('emoji run before the colour translation', () {
      final _Emoji emoji = _Emoji(<GlossEmojiEntry>[
        const GlossEmojiEntry(
          id: 'brand',
          trigger: '',
          glyph: '[ff8800]',
          enabled: true,
        ),
      ]);
      // A glyph that IS a bracket-hex token gets translated, which can only
      // happen when emoji substitute first.
      expect(
        glossRenderMenuText(':brand:x', emoji: emoji),
        '${_bungee('ff8800')}x',
      );
    });

    test('an empty string renders empty', () {
      expect(glossRenderMenuText(''), '');
    });
  });

  group('parseMcText folds the translated hex back into a colour', () {
    test('[RRGGBB] colours the run', () {
      final McTextResult parsed = parseMcText(
        glossRenderMenuText('[ff8800]Sale'),
      );
      expect(parsed.lines.single.single.text, 'Sale');
      expect(parsed.lines.single.single.rgb, 0xFF8800);
    });

    test('the hex sequence costs no visible characters', () {
      expect(parseMcText(glossRenderMenuText('[ff8800]Sale')).maxLineLength, 4);
    });
  });

  group('McTextCache', () {
    test('memoizes identical rendered output', () {
      final McTextCache cache = McTextCache();
      final McTextResult first = cache.parse('&aShop');
      expect(identical(cache.parse('&aShop'), first), isTrue);
    });

    test('applies the emoji stage before parsing', () {
      final McTextCache cache = McTextCache();
      final McTextResult parsed = cache.parse(
        ':heart: Shop',
        emoji: _Emoji(<GlossEmojiEntry>[_heart]),
      );
      expect(parsed.plainText, '❤ Shop');
      expect(parsed.maxLineLength, 6);
    });

    test('drops the memo when the resolver hands back other entries', () {
      final McTextCache cache = McTextCache();
      final _Emoji before = _Emoji(<GlossEmojiEntry>[]);
      final _Emoji after = _Emoji(<GlossEmojiEntry>[_heart]);
      expect(cache.parse(':heart:', emoji: before).plainText, ':heart:');
      expect(cache.parse(':heart:', emoji: after).plainText, '❤');
      expect(cache.parse(':heart:', emoji: before).plainText, ':heart:');
    });

    test('the same entry list keeps the memo', () {
      final McTextCache cache = McTextCache();
      final _Emoji emoji = _Emoji(<GlossEmojiEntry>[_heart]);
      final McTextResult first = cache.parse(':heart:', emoji: emoji);
      expect(identical(cache.parse(':heart:', emoji: emoji), first), isTrue);
    });

    test('animation time and expression samples participate in rendering', () {
      final McTextCache cache = McTextCache();
      final _MenuAnimations animations = _MenuAnimations();
      expect(
        cache
            .parse(
              '|animation.rainbow| {{ player.name }}',
              animations: animations,
              nowMs: 0,
            )
            .plainText,
        'A Builder',
      );
      expect(
        cache
            .parse(
              '|animation.rainbow| {{ player.name }}',
              animations: animations,
              nowMs: 100,
              expressionSamples: const GlossTextExpressionSamples(
                placeholders: <String, Object>{'player_name': 'Puretie'},
              ),
            )
            .plainText,
        'B Puretie',
      );
    });
  });

  group('buildCanvasScene resolves a text icon through the menu path', () {
    test('the glyph, not the token, sizes the hitbox', () {
      final CanvasItem substituted = _textItem(
        'Buy :heart:',
        _Emoji(<GlossEmojiEntry>[_heart]),
      );
      final CanvasItem literal = _textItem('Buy :heart:', const GlossNoEmoji());

      expect(substituted.text!.plainText, 'Buy ❤');
      expect(
        substituted.shape,
        const IconShape.text(lines: 1, maxLineChars: 5),
      );
      expect(literal.text!.plainText, 'Buy :heart:');
      expect(literal.shape, const IconShape.text(lines: 1, maxLineChars: 11));
    });

    test('bracket hex colours the run without an emoji resolver', () {
      final CanvasItem item = _textItem('[ff8800]Sale', const GlossNoEmoji());
      expect(item.text!.lines.single.single.rgb, 0xFF8800);
    });

    test('dynamic menu text follows its runtime refresh interval', () {
      final _MenuAnimations animations = _MenuAnimations();
      final CanvasItem before = _textItem(
        '|animation.rainbow|',
        const GlossNoEmoji(),
        animations: animations,
        animationTicks: 1,
        refreshTicks: 2,
      );
      final CanvasItem after = _textItem(
        '|animation.rainbow|',
        const GlossNoEmoji(),
        animations: animations,
        animationTicks: 2,
        refreshTicks: 2,
      );
      expect(before.text!.plainText, 'A');
      expect(after.text!.plainText, 'B');
      expect(before.textRefreshTicks, 2);
      expect(before.isDynamicText, isTrue);
      expect(before.isAnimated, isTrue);
    });

    test('fast refresh demand mirrors the runtime clock dependency', () {
      expect(glossTextRequiresFastRefresh('{{ player.ping }}'), isFalse);
      expect(glossTextRequiresFastRefresh("{{ 'time.seconds' }}"), isFalse);
      expect(
        glossTextRequiresFastRefresh('{{ floor(time.ticks / 2) }}'),
        isTrue,
      );
      expect(glossTextRequiresFastRefresh('|animation.rainbow|'), isTrue);
      expect(glossTextRequiresFastRefresh('|animation.rainbow'), isFalse);
    });
  });
}

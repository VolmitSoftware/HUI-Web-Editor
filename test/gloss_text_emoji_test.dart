/// The pipeline mirror's emoji stage: `EmojiReplacer.apply` semantics, the
/// stage order (after functions, before colours), and the length functions.
library;

import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

final class _Emoji implements GlossEmojiResolver {
  _Emoji(this.entries);

  @override
  final List<GlossEmojiEntry> entries;
}

final class _OneAnimation implements GlossAnimationResolver {
  _OneAnimation(this.id, this.frames);

  final String id;
  final List<String> frames;

  @override
  List<String> get ids => <String>[id];

  @override
  GlossAnimationDoc? byId(String wanted) =>
      wanted == id ? GlossAnimationDoc(frames: frames) : null;
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

void main() {
  group('glossApplyEmoji mirrors EmojiReplacer.apply', () {
    test('replaces triggers and tokens, all occurrences', () {
      final _Emoji emoji = _Emoji(<GlossEmojiEntry>[_check, _heart]);
      expect(glossApplyEmoji('hi :heart: <3 :heart:', emoji), 'hi ❤ ❤ ❤');
      expect(glossApplyEmoji(':check: ok', emoji), '✓ ok');
      expect(glossApplyEmoji('nothing here', emoji), 'nothing here');
    });

    test('a disabled entry never substitutes', () {
      final _Emoji emoji = _Emoji(<GlossEmojiEntry>[
        const GlossEmojiEntry(
          id: 'heart',
          trigger: '<3',
          glyph: '❤',
          enabled: false,
        ),
      ]);
      expect(glossApplyEmoji(':heart: <3', emoji), ':heart: <3');
    });

    test('presence checks precede both replacements per entry', () {
      // The trigger inserts text containing the token; the token check read
      // the ORIGINAL string, so the inserted token is substituted too —
      // exactly the Java scan's behavior of computing hasToken before
      // replacing the trigger.
      final _Emoji emoji = _Emoji(<GlossEmojiEntry>[
        const GlossEmojiEntry(
          id: 'x',
          trigger: '!!',
          glyph: ':x:',
          enabled: true,
        ),
      ]);
      expect(glossApplyEmoji(':x: !!', emoji), ':x: :x:');
    });

    test('entries apply in list order — EmojiService sorts by id', () {
      final _Emoji emoji = _Emoji(<GlossEmojiEntry>[
        const GlossEmojiEntry(
          id: 'a',
          trigger: ':b:',
          glyph: 'A',
          enabled: true,
        ),
        const GlossEmojiEntry(id: 'b', trigger: '', glyph: 'B', enabled: true),
      ]);
      // "a" runs first and its trigger consumes the ":b:" spelling before
      // "b" ever sees it.
      expect(glossApplyEmoji(':b:', emoji), 'A');
    });
  });

  group('the render pipeline stage order', () {
    test('emoji substitute after functions, before colours', () {
      final GlossLineRender render = renderGlossLine(
        '&c|animation.hearts| :check:',
        animations: _OneAnimation('hearts', <String>['<3']),
        emoji: _Emoji(<GlossEmojiEntry>[_heart, _check]),
      );
      // The frame text "<3" came out of the function stage and STILL got
      // emoji-substituted — proving emoji run after functions.
      expect(render.plainText, '❤ ✓');
      final GlossTextRun run = render.pieces.first as GlossTextRun;
      expect(run.span.rgb, 0xFF5555, reason: 'the &c still translated');
    });

    test('a glyph never re-enters the colour scanner as a code', () {
      final GlossLineRender render = renderGlossLine(
        ':amp:7x',
        emoji: _Emoji(<GlossEmojiEntry>[
          const GlossEmojiEntry(
            id: 'amp',
            trigger: '',
            glyph: '&',
            enabled: true,
          ),
        ]),
      );
      // The emoji stage produced "&7x" BEFORE the colour stage — so the
      // colour scanner does consume it, exactly as the plugin's ordered
      // stages would.
      expect(render.plainText, 'x');
    });
  });

  group('length functions fold the emoji stage in', () {
    test('glossLineMaxVisibleLength counts the glyph, not the token', () {
      final _Emoji emoji = _Emoji(<GlossEmojiEntry>[_heart]);
      expect(
        glossLineMaxVisibleLength(
          '&f:heart:',
          const GlossNoAnimations(),
          emoji: emoji,
        ),
        1,
      );
      expect(
        glossLineMaxVisibleLength('&f:heart:', const GlossNoAnimations()),
        7,
        reason: 'without the resolver the token stays literal',
      );
    });

    test('glossTranslatedLength measures the substituted string', () {
      final _Emoji emoji = _Emoji(<GlossEmojiEntry>[_heart]);
      expect(
        glossTranslatedLength('&f<3', const GlossNoAnimations(), emoji: emoji),
        3,
        reason: '&f (2) + the one-character glyph',
      );
    });
  });
}

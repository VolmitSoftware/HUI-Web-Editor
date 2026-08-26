/// Authored motion for the generated showcases.
///
/// A randomized document that only shuffles nouns still looks static. These
/// build the moving part: colour that travels, glyphs that tick, text that
/// reveals itself — all of it written the way a person would write it in the
/// code view, so opening the generated document teaches the expression
/// language rather than hiding it behind something the editor alone can do.
///
/// Everything here evaluates through `logic/gloss_text.dart`, which is the
/// same evaluator the plugin runs, so every effect plays in game exactly as it
/// plays in the editor. `select([...])` substitutes to one element, so a
/// ticker occupies whatever width its widest frame requires.
library;

import 'dart:math' as math;

import '../config/showcase_flavor.dart';
import '../model/gloss_animation.dart' show glossAnimationModes;

/// A named piece of motion, so generated copy can say what it is using and a
/// test can assert the pool is actually diverse.
final class ShowcaseEffect {
  const ShowcaseEffect(this.id, this.text);

  /// Stable identifier — `breathe`, `sweep`, `strobe` and friends.
  final String id;

  /// The pipeline text itself.
  final String text;
}

/// An animated colour prefix in the mood's palette, for surfaces with no row
/// budget: holograms, MOTD entries, tablist headers, bubble prefixes.
///
/// Six shapes, deliberately different in feel — a slow breath, a linear
/// sweep, an eased sweep, a stepped palette, a hard strobe, and the shipped
/// rainbow animation the plugin extracts on first run.
ShowcaseEffect showcaseColorEffect(math.Random random, ShowcaseMood mood) {
  final int rate = 2 + random.nextInt(5);
  final String primary = mood.primary;
  final String secondary = mood.secondary;
  return showcasePick(random, <ShowcaseEffect>[
    const ShowcaseEffect('rainbow', '|animation.rainbow|'),
    ShowcaseEffect(
      'breathe',
      '{{ hex(mix($primary, $secondary, '
          '(sin(time.seconds * $rate) + 1) / 2)) }}',
    ),
    ShowcaseEffect(
      'sweep',
      '{{ hex(mix($primary, $secondary, mod(time.seconds / $rate, 1))) }}',
    ),
    ShowcaseEffect(
      'ease',
      '{{ hex(mix($primary, $secondary, '
          'smoothstep(0, 1, mod(time.seconds / $rate, 1)))) }}',
    ),
    ShowcaseEffect(
      'palette',
      '{{ hex(palette([$primary, $secondary, #FFFFFF], '
          'floor(time.seconds * $rate))) }}',
    ),
    ShowcaseEffect(
      'strobe',
      "{{ select(['${mood.legacy}', '&f'], floor(time.seconds * $rate)) }}",
    ),
  ]);
}

/// A one-character animated glyph plus a reset, cheap enough for a scoreboard
/// row. The mood's glyphs cycle forward, backward or in a stutter.
ShowcaseEffect showcaseTickPrefix(
  math.Random random,
  ShowcaseMood mood, {
  required double framesPerSecond,
}) {
  assert(framesPerSecond.isFinite && framesPerSecond > 0);
  final String frameIndex = framesPerSecond == 1.0
      ? 'floor(time.seconds)'
      : 'floor(time.seconds * $framesPerSecond)';
  final List<String> glyphs = mood.glyphs;
  final String forward = glyphs.map((String g) => "'$g'").join(', ');
  final String backward = glyphs.reversed.map((String g) => "'$g'").join(', ');
  final String stutter = <String>[
    glyphs.first,
    glyphs.last,
    glyphs.first,
    glyphs[glyphs.length ~/ 2],
  ].map((String g) => "'$g'").join(', ');
  return showcasePick(random, <ShowcaseEffect>[
    ShowcaseEffect(
      'tick-forward',
      '${mood.legacy}{{ select([$forward], $frameIndex) }} &f',
    ),
    ShowcaseEffect(
      'tick-backward',
      '${mood.legacy}{{ select([$backward], $frameIndex) }} &f',
    ),
    ShowcaseEffect(
      'tick-stutter',
      '${mood.legacy}{{ select([$stutter], $frameIndex) }} &f',
    ),
    ShowcaseEffect(
      'tick-flicker',
      "{{ select(['${mood.legacy}', '&8', '${mood.legacy}', '&7'], "
          '$frameIndex) }}${glyphs.first} &f',
    ),
  ]);
}

/// A moving highlight across a fixed strip of bars — the one effect that reads
/// as a machine working rather than as decoration. [cells] bars wide.
ShowcaseEffect showcaseScanline(
  math.Random random,
  ShowcaseMood mood, {
  int cells = 5,
}) {
  final int rate = 3 + random.nextInt(6);
  final List<String> frames = <String>[
    for (int lit = 0; lit < cells; lit++)
      <String>[
        for (int cell = 0; cell < cells; cell++) cell == lit ? '&f▌' : '&8▌',
      ].join(),
  ];
  final String list = frames.map((String f) => "'$f'").join(', ');
  return ShowcaseEffect(
    'scanline',
    '{{ select([$list], floor(time.seconds * $rate)) }}',
  );
}

/// [text] revealed one character at a time and then held, the way a terminal
/// prints. Costs one `select` with as many frames as the text is long, so it
/// is for holograms and MOTD lines, never a board row.
ShowcaseEffect showcaseTypewriter(math.Random random, String text) {
  final int rate = 6 + random.nextInt(7);
  final List<String> frames = <String>[
    for (int end = 1; end <= text.length; end++) text.substring(0, end),
    text,
    text,
    text,
  ];
  final String list = frames
      .map((String frame) => "'${frame.replaceAll("'", '')}'")
      .join(', ');
  return ShowcaseEffect(
    'typewriter',
    '{{ select([$list], floor(time.seconds * $rate)) }}',
  );
}

ShowcaseEffect showcaseAlignment(math.Random random, String text) {
  final int visible = text.runes.length;
  final int width = visible + 2 + random.nextInt(9);
  final String safe = text.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
  return ShowcaseEffect(
    'align',
    '{{ ${showcaseAlignmentExpression(random, "'$safe'", width)} }}',
  );
}

String showcaseAlignmentExpression(
  math.Random random,
  String expression,
  int width,
) =>
    "align($expression, $width, '${showcasePick(random, const <String>['left', 'center', 'middle', 'right'])}')";

ShowcaseEffect showcaseTablistAnimation(math.Random random, ShowcaseMood mood) {
  final int rate = 1 + random.nextInt(4);
  final String word = showcasePick(random, showcaseStatusWords);
  final String glyph = showcasePick(random, mood.glyphs);
  final String primary = _stripHash(mood.primary);
  final String secondary = _stripHash(mood.secondary);
  switch (random.nextInt(showcaseProceduralTextEffectIds.length)) {
    case 0:
      return ShowcaseEffect('rainbow', '|animation.rainbow|&l$word');
    case 1:
      final int width = math.min(word.length, 14);
      return ShowcaseEffect(
        'marquee',
        "${mood.legacy}{{ marquee('$word', $width, floor(time.seconds * $rate)) }}",
      );
    case 2:
      return ShowcaseEffect(
        'timeline',
        "{{ timeline([['${mood.legacy}&l$word', 2], "
            "['&f$glyph $word', 1], ['[$secondary]&l$word', 2]], "
            'time.seconds) }}',
      );
    case 3:
      return ShowcaseEffect(
        'typewriter',
        "${mood.legacy}{{ typewriter('$word', "
            'floor(time.seconds * $rate), 2) }}',
      );
    case 4:
      return ShowcaseEffect(
        'flash',
        "{{ flash('${mood.legacy}&l$word', '&7$word', "
            'floor(time.seconds * $rate)) }}',
      );
    case 5:
      return ShowcaseEffect(
        'wipe',
        "${mood.legacy}{{ wipe('$word', floor(time.seconds * $rate)) }}",
      );
    case 6:
      return ShowcaseEffect(
        'scanner',
        "{{ scanner('$word', '&7', '[$secondary]', "
            'floor(time.seconds * $rate)) }}',
      );
    case 7:
      return ShowcaseEffect(
        'decode',
        "${mood.legacy}{{ scramble('$word', floor(time.seconds * $rate)) }}",
      );
    case 8:
      final int digits = 3 + random.nextInt(3);
      final int target = random.nextInt(math.pow(10, digits).toInt() - 1) + 1;
      final int duration = 5 + random.nextInt(16);
      return ShowcaseEffect(
        'odometer',
        '${mood.legacy}&lONLINE &f{{ odometer(0, $target, '
            'mod(time.seconds, $duration) / $duration, $digits) }}',
      );
    case 9:
      return ShowcaseEffect(
        'wave',
        "{{ wave('$word', ['${mood.legacy}', '[$primary]', "
            "'[$secondary]'], floor(time.seconds * $rate)) }}",
      );
    default:
      final ShowcaseEffect aligned = showcaseAlignment(random, word);
      return ShowcaseEffect('align', '${mood.legacy}${aligned.text}');
  }
}

/// [text] with a hue travelling along it, one bracket-hex colour per
/// character. Static per frame and long, so it belongs on the animation and
/// hologram surfaces where the whole document is the subject.
ShowcaseEffect showcaseWave(math.Random random, String text) {
  final int period = 3 + random.nextInt(4);
  final int start = random.nextInt(360);
  final StringBuffer out = StringBuffer();
  int index = 0;
  for (final int rune in text.runes) {
    final String character = String.fromCharCode(rune);
    if (character == ' ') {
      out.write(character);
      continue;
    }
    out
      ..write('[${showcaseHueHex(start + index * (360 ~/ (period * 8)))}]')
      ..write(character);
    index++;
  }
  return ShowcaseEffect('wave', out.toString());
}

const List<String> showcaseAnimationEffectIds = <String>[
  'rainbow',
  'marquee',
  'timeline',
  'typewriter',
  'flash',
  'wipe',
  'scanner',
  'decode',
  'odometer',
  'wave',
];

const List<String> showcaseProceduralTextEffectIds = <String>[
  ...showcaseAnimationEffectIds,
  'align',
];

({String mode, int intervalMs, List<String> frames}) showcaseAnimationFrames(
  math.Random random,
  ShowcaseMood mood,
  String word,
) {
  final String effectId = showcasePick(random, showcaseProceduralTextEffectIds);
  final String glyph = showcasePick(random, mood.glyphs);
  final String mode =
      glossAnimationModes[random.nextInt(glossAnimationModes.length)];
  final int rate = 1 + random.nextInt(4);
  final String primary = _stripHash(mood.primary);
  final String secondary = _stripHash(mood.secondary);
  switch (effectId) {
    case 'rainbow':
      final int count = 48 + random.nextInt(13);
      final int startHue = random.nextInt(360);
      return (
        mode: mode,
        intervalMs: 50,
        frames: <String>[
          for (int index = 0; index < count; index++)
            '[${showcaseHueHex(startHue + ((360 * index) ~/ count))}]$word',
        ],
      );
    case 'marquee':
      final int width = math.min(word.length, 12);
      return (
        mode: mode,
        intervalMs: 1000,
        frames: <String>[
          "${mood.legacy}{{ marquee('$word', $width, floor(time.seconds * $rate)) }}",
        ],
      );
    case 'timeline':
      return (
        mode: mode,
        intervalMs: 1000,
        frames: <String>[
          "{{ timeline([['${mood.legacy}$word', 3], ['&f$glyph $word', 2], "
              "['[$secondary]$word', 3]], time.seconds) }}",
        ],
      );
    case 'typewriter':
      return (
        mode: mode,
        intervalMs: 1000,
        frames: <String>[
          "${mood.legacy}{{ typewriter('$word', floor(time.seconds * $rate), 2) }}",
        ],
      );
    case 'flash':
      return (
        mode: mode,
        intervalMs: 1000,
        frames: <String>[
          "{{ flash('${mood.legacy}&l$word', '&7$word', floor(time.seconds * $rate)) }}",
        ],
      );
    case 'wipe':
      return (
        mode: mode,
        intervalMs: 1000,
        frames: <String>[
          "${mood.legacy}{{ wipe('$word', floor(time.seconds * $rate)) }}",
        ],
      );
    case 'scanner':
      return (
        mode: mode,
        intervalMs: 1000,
        frames: <String>[
          "{{ scanner('$word', '${mood.legacy}', '[$secondary]', floor(time.seconds * $rate)) }}",
        ],
      );
    case 'decode':
      return (
        mode: mode,
        intervalMs: 1000,
        frames: <String>[
          "${mood.legacy}{{ scramble('$word', floor(time.seconds * $rate)) }}",
        ],
      );
    case 'odometer':
      final int digits = 3 + random.nextInt(4);
      final int target = random.nextInt(math.pow(10, digits).toInt() - 1) + 1;
      final int duration = 5 + random.nextInt(16);
      return (
        mode: mode,
        intervalMs: 1000,
        frames: <String>[
          "${mood.legacy}{{ odometer(0, $target, mod(time.seconds, $duration) / $duration, $digits) }}",
        ],
      );
    case 'wave':
      return (
        mode: mode,
        intervalMs: 1000,
        frames: <String>[
          "{{ wave('$word', ['${mood.legacy}', '[$primary]', '[$secondary]'], floor(time.seconds * $rate)) }}",
        ],
      );
    case 'align':
      return (
        mode: mode,
        intervalMs: 1000,
        frames: <String>[
          '${mood.legacy}${showcaseAlignment(random, word).text}',
        ],
      );
    default:
      throw StateError('Unknown animation effect: $effectId');
  }
}

/// `RRGGBB` for a hue on the full-saturation ring, matching the shipped
/// rainbow animation's own walk.
String showcaseHueHex(int hue) {
  int normalized = hue % 360;
  if (normalized < 0) normalized += 360;
  final int sector = normalized ~/ 60;
  final int rising = (((normalized % 60) * 255) / 60).round();
  final int falling = 255 - rising;
  int red = 0;
  int green = 0;
  int blue = 0;
  switch (sector) {
    case 0:
      red = 255;
      green = rising;
    case 1:
      red = falling;
      green = 255;
    case 2:
      green = 255;
      blue = rising;
    case 3:
      green = falling;
      blue = 255;
    case 4:
      red = rising;
      blue = 255;
    default:
      red = 255;
      blue = falling;
  }
  return _hex2(red) + _hex2(green) + _hex2(blue);
}

/// `RRGGBB` [amount] of the way from [from] to [to]; both are `#RRGGBB`.
String showcaseMixHex(String from, String to, double amount) {
  final int start = int.parse(_stripHash(from), radix: 16);
  final int end = int.parse(_stripHash(to), radix: 16);
  final double t = amount.clamp(0, 1).toDouble();
  int channel(int shift) {
    final int a = (start >> shift) & 0xFF;
    final int b = (end >> shift) & 0xFF;
    return (a + (b - a) * t).round().clamp(0, 255).toInt();
  }

  return _hex2(channel(16)) + _hex2(channel(8)) + _hex2(channel(0));
}

String _stripHash(String value) =>
    value.startsWith('#') ? value.substring(1) : value;

String _hex2(int value) =>
    value.toRadixString(16).padLeft(2, '0').toUpperCase();

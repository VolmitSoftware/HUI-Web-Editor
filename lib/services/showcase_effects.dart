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
/// plays in the editor. Two budgets apply:
///
///  * `hex(...)` substitutes to `[RRGGBB]`, eight encoded characters. A
///    scoreboard row is cut at 32, so board rows use [showcaseTickPrefix] and
///    the legacy palette instead.
///  * `select([...])` substitutes to one element, so a ticker costs whatever
///    its widest frame costs.
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
ShowcaseEffect showcaseTickPrefix(math.Random random, ShowcaseMood mood) {
  final int rate = 4 + random.nextInt(6);
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
      '${mood.legacy}{{ select([$forward], '
          'floor(time.seconds * $rate)) }} &f',
    ),
    ShowcaseEffect(
      'tick-backward',
      '${mood.legacy}{{ select([$backward], '
          'floor(time.seconds * $rate)) }} &f',
    ),
    ShowcaseEffect(
      'tick-stutter',
      '${mood.legacy}{{ select([$stutter], '
          'floor(time.seconds * $rate)) }} &f',
    ),
    ShowcaseEffect(
      'tick-flicker',
      "{{ select(['${mood.legacy}', '&8', '${mood.legacy}', '&7'], "
          'floor(time.seconds * $rate)) }}${glyphs.first} &f',
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

/// Frames for a generated animation document.
///
/// Four shapes: the smooth hue ring the shipped rainbow walks, a two-colour
/// ping-pong in the mood, a hard flicker, and a marquee that slides a glyph
/// through the word.
({String mode, int intervalMs, List<String> frames}) showcaseAnimationFrames(
  math.Random random,
  ShowcaseMood mood,
  String word,
) {
  final int shape = random.nextInt(4);
  final String glyph = showcasePick(random, mood.glyphs);
  final String mode =
      glossAnimationModes[random.nextInt(glossAnimationModes.length)];
  switch (shape) {
    case 0:
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
    case 1:
      final int count = 24 + random.nextInt(17);
      return (
        mode: mode,
        intervalMs: 60,
        frames: <String>[
          for (int index = 0; index < count; index++)
            '[${showcaseMixHex(mood.primary, mood.secondary, index / (count - 1))}]'
                '$word',
          for (int index = count - 2; index > 0; index--)
            '[${showcaseMixHex(mood.primary, mood.secondary, index / (count - 1))}]'
                '$word',
        ],
      );
    case 2:
      // A failing lamp: bright, lit, dim, nearly out, on a four-beat cycle.
      final List<String> tones = <String>[
        _stripHash(mood.secondary),
        _stripHash(mood.primary),
        showcaseMixHex(mood.primary, '#101014', 0.55),
        '221F26',
      ];
      final int count = (4 * (3 + random.nextInt(4))).toInt();
      return (
        mode: mode,
        intervalMs: 80,
        frames: <String>[
          for (int index = 0; index < count; index++)
            '[${tones[index % tones.length]}]$word',
        ],
      );
    default:
      final List<String> letters = word.split('');
      return (
        mode: mode,
        intervalMs: 70,
        frames: <String>[
          for (int slot = 0; slot <= letters.length; slot++)
            '[${_stripHash(mood.primary)}]'
                '${letters.sublist(0, slot).join()}'
                '[${_stripHash(mood.secondary)}]$glyph'
                '[${_stripHash(mood.primary)}]'
                '${letters.sublist(slot).join()}',
        ],
      );
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

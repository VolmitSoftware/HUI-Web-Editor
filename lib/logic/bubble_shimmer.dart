/// Mirror of Gloss `BubbleShimmerPlan.java` — the Gloss shine band.
///
/// ## Timing — the legacy law, unchanged
///
/// The legacy `TextFilterColorSpecial` ran a 60 Hz integer clock from the
/// moment a display component was built, advanced a band head one visible
/// glyph every second clock unit, and lit a glyph when
/// `Math.abs(((clock / 2) - at) % 127) < 2`. That is a free-running band of
/// 127 glyph steps travelling at exactly 30 glyphs per second, one radius
/// glyph either side of the head, wrapping forever rather than sweeping once.
///
/// So `durationMs` is the wall time the head needs for one full
/// [glossBubbleShimmerCycleGlyphs] cycle, not the time for one pass over the
/// text: the band crosses at a constant 30 glyphs per second at the shipped
/// [glossBubbleShimmerDefaultDurationMs] whatever the line length, walks off
/// the right edge, and comes back 127 glyph steps later. Nothing here is
/// bounded to a pass and nothing freezes at the end.
///
/// TRAP: the lit test is Java's `%`, which keeps the DIVIDEND's sign, while
/// Dart's `%` is Euclidean and never returns a negative for a positive
/// divisor. The difference is the whole shape of the band — see
/// [_javaRemainder]. With Java's remainder the band is three glyphs wide and
/// centred on the head while the head is still crossing the text, and becomes
/// a two-glyph trail at `head - 127` and `head - 128` on every later wrap.
/// With Dart's it would be neither.
///
/// Every lit glyph uses one solid color and each wrapped row restarts its
/// visible index at zero, matching the original Gloss filter while keeping the
/// modern one-TextDisplay multiline block. The underlying color and
/// decorations are restored after every lit glyph.
library;

import '../model/gloss_bubble_style.dart';

/// One band step in milliseconds: the head is a whole glyph index, so a frame
/// only changes this often (~33.3 ms at the shipped cycle). The preview has to
/// repaint at least twice this fast or it aliases the band.
double glossBubbleShimmerStepMs(GlossBubbleShimmer shimmer) =>
    shimmer.effectiveDurationMs / glossBubbleShimmerCycleGlyphs;

/// The band head, in visible glyphs, for a bubble of [lifetimeMs] at age
/// [ageMs], or null when neither cycle is running. The departure cycle wins
/// while both are (`BubbleShimmerPlan.head`).
///
/// Once a cycle has started it never stops: the head keeps climbing past the
/// end of the text until the bubble expires.
int? glossBubbleShimmerHead(
  GlossBubbleShimmer shimmer, {
  required int ageMs,
  required int lifetimeMs,
}) {
  final int cycleMs = shimmer.effectiveDurationMs;
  if (shimmer.flyAway) {
    final int departureStartMs = lifetimeMs - shimmer.effectiveFlyAwayLeadMs;
    final int startMs = departureStartMs < 0 ? 0 : departureStartMs;
    if (ageMs >= startMs) return _headAt(ageMs - startMs, cycleMs);
  }
  if (shimmer.spawn && ageMs >= shimmer.effectiveSpawnDelayMs) {
    return _headAt(ageMs - shimmer.effectiveSpawnDelayMs, cycleMs);
  }
  return null;
}

/// Lights the glyphs under the solid band at [head], restoring each glyph's
/// own colour and accumulated formats straight after. Every wrapped row uses
/// its own zero-based visible index, as the original separate components did.
String glossBubbleApplyShimmer(
  String input,
  GlossBubbleShimmer shimmer,
  int? head,
) {
  if (head == null || input.isEmpty) return input;
  final String color = _rgbCode(shimmer.effectiveColor);
  if (!input.contains('\n')) {
    return _renderLine(input, color, shimmer.effectiveWidth, head);
  }
  final List<String> rendered = <String>[];
  for (final String line in input.split('\n')) {
    rendered.add(_renderLine(line, color, shimmer.effectiveWidth, head));
  }
  return rendered.join('\n');
}

int _headAt(int elapsedMs, int cycleMs) =>
    cycleMs == glossBubbleShimmerDefaultDurationMs
    ? (elapsedMs * 3) ~/ 100
    : (elapsedMs * glossBubbleShimmerCycleGlyphs) ~/ cycleMs;

/// Java's `%`: the remainder takes the sign of the dividend.
///
/// Dart's `%` is Euclidean — `(-1) % 127` is 126 here and -1 in Java — so the
/// band law cannot use it. `~/` truncates toward zero exactly like Java's
/// integer division, which makes this the same operation Java's `%` is.
int _javaRemainder(int value, int divisor) =>
    value - (value ~/ divisor) * divisor;

bool _lit(int head, int at, int width) {
  final int distance = _javaRemainder(head - at, glossBubbleShimmerCycleGlyphs);
  final int before = (width - 1) ~/ 2;
  final int after = width - before - 1;
  return distance >= -after && distance <= before;
}

/// Builds lazily, exactly like the plugin: a line with nothing lit is returned
/// untouched rather than rebuilt glyph by glyph.
String _renderLine(String line, String color, int width, int head) {
  StringBuffer? rendered;
  final _BubbleFormatState formatting = _BubbleFormatState();
  int visibleIndex = 0;
  int cursor = 0;
  while (cursor < line.length) {
    final int formatLength = _formatLength(line, cursor);
    if (formatLength > 0) {
      final String raw = line.substring(cursor, cursor + formatLength);
      formatting.apply(raw);
      rendered?.write(raw);
      cursor += formatLength;
      continue;
    }
    final int codePoint = _codePointAt(line, cursor);
    final int glyphLength = codePoint > 0xffff ? 2 : 1;
    if (_lit(head, visibleIndex, width)) {
      rendered ??= StringBuffer(line.substring(0, cursor));
      rendered
        ..write(color)
        ..write(line.substring(cursor, cursor + glyphLength))
        ..write(formatting.codes);
    } else {
      rendered?.write(line.substring(cursor, cursor + glyphLength));
    }
    visibleIndex++;
    cursor += glyphLength;
  }
  return rendered == null ? line : rendered.toString();
}

int _codePointAt(String input, int index) {
  final int first = input.codeUnitAt(index);
  if (first < 0xd800 || first > 0xdbff || index + 1 >= input.length) {
    return first;
  }
  final int second = input.codeUnitAt(index + 1);
  if (second < 0xdc00 || second > 0xdfff) return first;
  return 0x10000 + ((first - 0xd800) << 10) + second - 0xdc00;
}

int _formatLength(String input, int index) {
  if (_isBracketRgb(input, index)) return 8;
  if (_isLegacyRgb(input, index)) return 14;
  if (index + 1 >= input.length) return 0;
  final String marker = input[index];
  if (marker != '&' && marker != '§') return 0;
  return _isLegacyCode(input[index + 1]) ? 2 : 0;
}

bool _isBracketRgb(String input, int index) {
  if (index + 8 > input.length ||
      input[index] != '[' ||
      input[index + 7] != ']') {
    return false;
  }
  for (int cursor = index + 1; cursor < index + 7; cursor++) {
    if (!_isHex(input[cursor])) return false;
  }
  return true;
}

bool _isLegacyRgb(String input, int index) {
  if (index + 14 > input.length) return false;
  final String marker = input[index];
  if ((marker != '&' && marker != '§') ||
      input[index + 1].toLowerCase() != 'x') {
    return false;
  }
  for (int offset = 2; offset < 14; offset += 2) {
    if (input[index + offset] != marker || !_isHex(input[index + offset + 1])) {
      return false;
    }
  }
  return true;
}

bool _isLegacyCode(String value) {
  final String normalized = value.toLowerCase();
  return _isHex(normalized) || 'klmnor'.contains(normalized);
}

bool _isHex(String value) {
  final int code = value.toLowerCase().codeUnitAt(0);
  return code >= 48 && code <= 57 || code >= 97 && code <= 102;
}

String _rgbCode(String color) {
  final StringBuffer code = StringBuffer('§x');
  for (final String digit in color.substring(1).split('')) {
    code.write('§$digit');
  }
  return code.toString();
}

final class _BubbleFormatState {
  String? color;
  final Map<String, String> decorations = <String, String>{};

  void apply(String raw) {
    if (raw.startsWith('[')) {
      color = _rgbCode('#${raw.substring(1, 7).toLowerCase()}');
      decorations.clear();
      return;
    }
    final String code = raw[1].toLowerCase();
    if (code == 'x') {
      color = _normalizeLegacyRgb(raw);
      decorations.clear();
      return;
    }
    if (_isHex(code)) {
      color = '§$code';
      decorations.clear();
      return;
    }
    if (code == 'r') {
      color = null;
      decorations.clear();
      return;
    }
    decorations[code] = '§$code';
  }

  String get codes => <String>[color ?? '§r', ...decorations.values].join();
}

String _normalizeLegacyRgb(String raw) {
  final StringBuffer normalized = StringBuffer('§x');
  for (int offset = 3; offset < raw.length; offset += 2) {
    normalized.write('§${raw[offset].toLowerCase()}');
  }
  return normalized.toString();
}

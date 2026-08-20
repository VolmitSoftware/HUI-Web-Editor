/// Mirror of Gloss `BubbleShimmerPlan.java` — one solid shine band that crosses
/// the complete multiline bubble during two bounded high-frequency windows.
library;

import '../model/gloss_bubble_style.dart';

int? glossBubbleShimmerBandIndex(
  GlossBubbleShimmer shimmer, {
  required String input,
  required int ageMs,
  required int lifetimeMs,
}) {
  final int visibleGlyphs = _visibleCount(input);
  if (visibleGlyphs == 0) return null;
  final double? progress = _progress(
    shimmer,
    ageMs: ageMs,
    lifetimeMs: lifetimeMs,
  );
  if (progress == null) return null;
  return (progress * (visibleGlyphs - 1)).round();
}

double? _progress(
  GlossBubbleShimmer shimmer, {
  required int ageMs,
  required int lifetimeMs,
}) {
  if (shimmer.flyAway) {
    final int departureStartMs = lifetimeMs - shimmer.effectiveFlyAwayLeadMs;
    final int startMs = departureStartMs < 0 ? 0 : departureStartMs;
    final double? departure = _windowProgress(
      ageMs,
      startMs,
      shimmer.effectiveDurationMs,
    );
    if (departure != null) return departure;
  }
  if (shimmer.spawn) {
    return _windowProgress(
      ageMs,
      shimmer.effectiveSpawnDelayMs,
      shimmer.effectiveDurationMs,
    );
  }
  return null;
}

double? _windowProgress(int ageMs, int startsAtMs, int durationMs) {
  final int elapsedMs = ageMs - startsAtMs;
  if (elapsedMs < 0 || elapsedMs > durationMs) return null;
  return elapsedMs / durationMs;
}

/// Lights one continuous band at [bandIndex], restoring each glyph's own
/// colour and accumulated formats straight after.
String glossBubbleApplyShimmer(
  String input,
  GlossBubbleShimmer shimmer,
  int? bandIndex,
) {
  if (bandIndex == null || input.isEmpty) return input;
  final String color = _rgbCode(shimmer.effectiveColor);
  final List<String> rendered = <String>[];
  int visibleIndex = 0;
  for (final String line in input.split('\n')) {
    final ({String text, int nextVisibleIndex}) next = _renderLine(
      line,
      color,
      shimmer.effectiveWidth,
      bandIndex,
      visibleIndex,
    );
    rendered.add(next.text);
    visibleIndex = next.nextVisibleIndex;
  }
  return rendered.join('\n');
}

bool _lit(int bandIndex, int at, int width) {
  final int distance = bandIndex - at;
  final int before = (width - 1) ~/ 2;
  final int after = width - before - 1;
  return distance >= -after && distance <= before;
}

({String text, int nextVisibleIndex}) _renderLine(
  String line,
  String color,
  int width,
  int bandIndex,
  int firstVisibleIndex,
) {
  StringBuffer? rendered;
  final _BubbleFormatState formatting = _BubbleFormatState();
  int visibleIndex = firstVisibleIndex;
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
    if (_lit(bandIndex, visibleIndex, width)) {
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
  return (
    text: rendered == null ? line : rendered.toString(),
    nextVisibleIndex: visibleIndex,
  );
}

int _visibleCount(String input) {
  int count = 0;
  int cursor = 0;
  while (cursor < input.length) {
    if (input[cursor] == '\n') {
      cursor++;
      continue;
    }
    final int formatLength = _formatLength(input, cursor);
    if (formatLength > 0) {
      cursor += formatLength;
      continue;
    }
    final int codePoint = _codePointAt(input, cursor);
    cursor += codePoint > 0xffff ? 2 : 1;
    count++;
  }
  return count;
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

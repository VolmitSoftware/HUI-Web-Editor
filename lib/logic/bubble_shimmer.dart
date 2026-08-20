library;

import '../model/gloss_bubble_style.dart';

double? glossBubbleShimmerProgress(
  GlossBubbleShimmer shimmer, {
  required int ageMs,
  required int lifetimeMs,
}) {
  if (shimmer.flyAway) {
    final int flyAwayStartMs = (lifetimeMs - shimmer.effectiveFlyAwayLeadMs)
        .clamp(0, lifetimeMs);
    final double? departure = _phaseProgress(
      ageMs,
      flyAwayStartMs,
      shimmer.effectiveDurationMs,
    );
    if (departure != null) return departure;
  }
  if (!shimmer.spawn) return null;
  return _phaseProgress(
    ageMs,
    shimmer.effectiveSpawnDelayMs,
    shimmer.effectiveDurationMs,
  );
}

String glossBubbleApplyShimmer(
  String input,
  GlossBubbleShimmer shimmer,
  double? progress,
) {
  if (progress == null || input.isEmpty) return input;
  return input
      .split('\n')
      .map(
        (String line) => _renderLine(
          line,
          shimmer.effectiveColor,
          shimmer.effectiveWidth,
          progress,
        ),
      )
      .join('\n');
}

double? _phaseProgress(int ageMs, int startMs, int durationMs) {
  final int elapsedMs = ageMs - startMs;
  if (elapsedMs < 0 || elapsedMs > durationMs) return null;
  return (elapsedMs / durationMs).clamp(0.0, 1.0).toDouble();
}

String _renderLine(String line, String color, int width, double progress) {
  final int visibleCount = _visibleCount(line);
  if (visibleCount == 0) return line;
  final double center = progress * (visibleCount - 1);
  final int first = (center - ((width - 1) / 2)).round();
  final int last = first + width - 1;
  final StringBuffer rendered = StringBuffer();
  final _BubbleFormatState formatting = _BubbleFormatState();
  final String shimmerCode = _rgbCode(color);
  int visibleIndex = 0;
  int cursor = 0;
  while (cursor < line.length) {
    final int formatLength = _formatLength(line, cursor);
    if (formatLength > 0) {
      final String raw = line.substring(cursor, cursor + formatLength);
      formatting.apply(raw);
      rendered.write(raw);
      cursor += formatLength;
      continue;
    }
    final int codePoint = _codePointAt(line, cursor);
    final String glyph = String.fromCharCode(codePoint);
    if (visibleIndex >= first && visibleIndex <= last) {
      rendered.write(shimmerCode);
      rendered.write(glyph);
      rendered.write(formatting.codes);
    } else {
      rendered.write(glyph);
    }
    visibleIndex++;
    cursor += codePoint > 0xffff ? 2 : 1;
  }
  return rendered.toString();
}

int _visibleCount(String line) {
  int count = 0;
  int cursor = 0;
  while (cursor < line.length) {
    final int formatLength = _formatLength(line, cursor);
    if (formatLength > 0) {
      cursor += formatLength;
      continue;
    }
    final int codePoint = _codePointAt(line, cursor);
    count++;
    cursor += codePoint > 0xffff ? 2 : 1;
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

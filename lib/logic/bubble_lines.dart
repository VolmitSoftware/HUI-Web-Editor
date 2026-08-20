library;

final RegExp _legacyCode = RegExp(r'^[0-9A-Fa-fK-Ok-oRr]$');
final RegExp _legacyColor = RegExp(r'^[0-9A-Fa-f]$');
final RegExp _legacyDecoration = RegExp(r'^[K-Ok-o]$');
final RegExp _hexDigit = RegExp(r'^[0-9A-Fa-f]$');

String glossBubbleWrap(
  String message,
  int wrapChars, {
  String renderedPrefix = '',
}) {
  final int width = wrapChars < 1 ? 1 : wrapChars;
  final List<_BubbleWrapEvent> events = _tokenizeBubbleMessage(
    '$renderedPrefix$message',
  );
  final List<String> lines = <String>[];
  final _BubbleFormatState format = _BubbleFormatState();
  StringBuffer line = StringBuffer();
  int lineWidth = 0;
  bool pendingSpace = false;

  void beginLine() {
    line = StringBuffer(format.activeCodes);
    lineWidth = 0;
  }

  void finishLine({bool preserveBlank = false}) {
    if (lineWidth > 0 || preserveBlank) {
      lines.add(lineWidth > 0 ? line.toString() : '');
    }
    beginLine();
    pendingSpace = false;
  }

  beginLine();
  for (final _BubbleWrapEvent event in events) {
    if (event.isNewline) {
      finishLine(preserveBlank: true);
      continue;
    }
    if (event.isSpace) {
      if (lineWidth > 0) pendingSpace = true;
      continue;
    }

    final List<_BubbleToken> tokens = event.tokens;
    int wordWidth = 0;
    for (final _BubbleToken token in tokens) {
      wordWidth += token.visibleWidth;
    }
    if (wordWidth == 0) {
      for (final _BubbleToken token in tokens) {
        line.write(token.raw);
        format.apply(token);
      }
      continue;
    }

    if (lineWidth > 0 && lineWidth + 1 + wordWidth > width) {
      finishLine();
    } else if (lineWidth > 0 && pendingSpace) {
      line.write(' ');
      lineWidth++;
    }
    pendingSpace = false;

    for (final _BubbleToken token in tokens) {
      if (token.visibleWidth > 0 && lineWidth >= width) {
        finishLine();
      }
      line.write(token.raw);
      format.apply(token);
      lineWidth += token.visibleWidth;
    }
  }
  if (lineWidth > 0) lines.add(line.toString());
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines.join('\n');
}

int glossBubbleWrappedLineCount(String wrapped) =>
    wrapped.isEmpty ? 0 : wrapped.split('\n').length;

String glossBubbleVisibleText(String message) {
  final StringBuffer out = StringBuffer();
  for (final _BubbleWrapEvent event in _tokenizeBubbleMessage(message)) {
    if (event.isNewline) {
      out.write('\n');
      continue;
    }
    if (event.isSpace) {
      out.write(' ');
      continue;
    }
    for (final _BubbleToken token in event.tokens) {
      if (token.visibleWidth > 0) out.write(token.raw);
    }
  }
  return out.toString();
}

List<_BubbleWrapEvent> _tokenizeBubbleMessage(String message) {
  final List<_BubbleWrapEvent> events = <_BubbleWrapEvent>[];
  List<_BubbleToken> word = <_BubbleToken>[];

  void flushWord() {
    if (word.isEmpty) return;
    events.add(_BubbleWrapEvent.word(List<_BubbleToken>.unmodifiable(word)));
    word = <_BubbleToken>[];
  }

  int index = 0;
  while (index < message.length) {
    final int newlineLength = _newlineLengthAt(message, index);
    if (newlineLength > 0) {
      flushWord();
      events.add(const _BubbleWrapEvent.newline());
      index += newlineLength;
      continue;
    }
    if (_isWrapSpace(message[index])) {
      flushWord();
      if (events.isEmpty || !events.last.isSpace) {
        events.add(const _BubbleWrapEvent.space());
      }
      index++;
      continue;
    }

    final _BubbleToken? formatting = _formatTokenAt(message, index);
    if (formatting != null) {
      word.add(formatting);
      index += formatting.raw.length;
      continue;
    }

    final int codePoint = message.substring(index).runes.first;
    final String raw = String.fromCharCode(codePoint);
    word.add(_BubbleToken.visible(raw));
    index += raw.length;
  }
  flushWord();
  return events;
}

int _newlineLengthAt(String message, int index) {
  final String current = message[index];
  if (current == '\r') {
    return index + 1 < message.length && message[index + 1] == '\n' ? 2 : 1;
  }
  return current == '\n' || current == '\u2028' || current == '\u2029' ? 1 : 0;
}

bool _isWrapSpace(String value) => value == ' ' || value == '\t';

_BubbleToken? _formatTokenAt(String message, int index) {
  final String marker = message[index];
  if (marker != '§') return null;
  if (_isBungeeHexAt(message, index)) {
    return _BubbleToken.format(
      message.substring(index, index + 14),
      _BubbleFormatKind.color,
    );
  }
  if (index + 1 >= message.length) return null;
  final String code = message[index + 1];
  if (!_legacyCode.hasMatch(code)) return null;
  final _BubbleFormatKind kind = _legacyColor.hasMatch(code)
      ? _BubbleFormatKind.color
      : code.toLowerCase() == 'r'
      ? _BubbleFormatKind.reset
      : _legacyDecoration.hasMatch(code)
      ? _BubbleFormatKind.decoration
      : _BubbleFormatKind.none;
  return _BubbleToken.format(message.substring(index, index + 2), kind);
}

bool _isBungeeHexAt(String message, int index) {
  if (index + 14 > message.length ||
      message[index] != '§' ||
      message[index + 1].toLowerCase() != 'x') {
    return false;
  }
  for (int offset = index + 2; offset < index + 14; offset += 2) {
    if (message[offset] != '§' || !_hexDigit.hasMatch(message[offset + 1])) {
      return false;
    }
  }
  return true;
}

enum _BubbleFormatKind { none, color, decoration, reset }

final class _BubbleToken {
  const _BubbleToken.visible(this.raw)
    : visibleWidth = 1,
      formatKind = _BubbleFormatKind.none;

  const _BubbleToken.format(this.raw, this.formatKind) : visibleWidth = 0;

  final String raw;
  final int visibleWidth;
  final _BubbleFormatKind formatKind;
}

final class _BubbleWrapEvent {
  const _BubbleWrapEvent.word(this.tokens) : isSpace = false, isNewline = false;

  const _BubbleWrapEvent.space()
    : tokens = const <_BubbleToken>[],
      isSpace = true,
      isNewline = false;

  const _BubbleWrapEvent.newline()
    : tokens = const <_BubbleToken>[],
      isSpace = false,
      isNewline = true;

  final List<_BubbleToken> tokens;
  final bool isSpace;
  final bool isNewline;
}

final class _BubbleFormatState {
  String color = '';
  final List<String> decorations = <String>[];

  String get activeCodes => '$color${decorations.join()}';

  void apply(_BubbleToken token) {
    switch (token.formatKind) {
      case _BubbleFormatKind.color:
        color = token.raw;
        decorations.clear();
      case _BubbleFormatKind.decoration:
        final String code = token.raw[token.raw.length - 1].toLowerCase();
        decorations.removeWhere(
          (String existing) =>
              existing[existing.length - 1].toLowerCase() == code,
        );
        decorations.add(token.raw);
      case _BubbleFormatKind.reset:
        color = '';
        decorations.clear();
      case _BubbleFormatKind.none:
        break;
    }
  }
}

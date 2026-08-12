/// Tokenizer for the code view's highlight layer.
///
/// Two properties matter more than accuracy, because the tokens are painted
/// underneath a textarea and any drift shows up as misaligned text:
///   1. Concatenating every token's text reproduces the source byte for byte.
///      Nothing is dropped, merged or normalised.
///   2. It never throws and never rejects. The buffer is invalid JSON for as
///      long as the user is mid-keystroke, so anything unrecognised falls
///      through as [JsonTokenKind.plain].
///
/// Pure Dart; no DOM, no colours. The view maps kinds to colours.
library;

enum JsonTokenKind {
  /// A string in key position — quoted, with the next non-space character `:`.
  key,

  /// Any other quoted string.
  string,
  number,

  /// `true`, `false` or `null`.
  literal,

  /// One of `{}[],:`.
  punctuation,

  /// Whitespace and anything that is not valid JSON.
  plain,
}

class JsonToken {
  const JsonToken(this.kind, this.text);

  final JsonTokenKind kind;
  final String text;

  @override
  String toString() => 'JsonToken(${kind.name}, ${text.length} chars)';
}

const int _quote = 0x22;
const int _backslash = 0x5C;
const int _newline = 0x0A;
const int _minus = 0x2D;
const int _plus = 0x2B;
const int _dot = 0x2E;
const int _colon = 0x3A;
const int _zero = 0x30;
const int _nine = 0x39;
const int _lowerE = 0x65;
const int _upperE = 0x45;

const Set<int> _punctuation = <int>{
  0x7B, // {
  0x7D, // }
  0x5B, // [
  0x5D, // ]
  0x2C, // ,
  _colon,
};

const List<String> _literals = <String>['true', 'false', 'null'];

List<JsonToken> tokenizeJson(String source) {
  final List<JsonToken> tokens = <JsonToken>[];
  final StringBuffer plain = StringBuffer();

  void flushPlain() {
    if (plain.isEmpty) return;
    tokens.add(JsonToken(JsonTokenKind.plain, plain.toString()));
    plain.clear();
  }

  int index = 0;
  while (index < source.length) {
    final int code = source.codeUnitAt(index);

    if (code == _quote) {
      final int end = _scanString(source, index);
      flushPlain();
      tokens.add(
        JsonToken(
          _colonFollows(source, end) ? JsonTokenKind.key : JsonTokenKind.string,
          source.substring(index, end),
        ),
      );
      index = end;
      continue;
    }

    if (_punctuation.contains(code)) {
      flushPlain();
      tokens.add(JsonToken(JsonTokenKind.punctuation, source[index]));
      index++;
      continue;
    }

    if (code == _minus || _isDigit(code)) {
      final int end = _scanNumber(source, index);
      if (end > index) {
        flushPlain();
        tokens.add(
          JsonToken(JsonTokenKind.number, source.substring(index, end)),
        );
        index = end;
        continue;
      }
    }

    final String? literal = _literalAt(source, index);
    if (literal != null) {
      flushPlain();
      tokens.add(JsonToken(JsonTokenKind.literal, literal));
      index += literal.length;
      continue;
    }

    plain.writeCharCode(code);
    index++;
  }

  flushPlain();
  return tokens;
}

/// Index just past the closing quote of the string opening at [start].
///
/// An unterminated string stops at the end of its line rather than swallowing
/// the rest of the document: while typing, every line below would otherwise
/// flip colour on one keystroke.
int _scanString(String source, int start) {
  int index = start + 1;
  while (index < source.length) {
    final int code = source.codeUnitAt(index);
    if (code == _backslash) {
      index += 2;
      continue;
    }
    if (code == _quote) return index + 1;
    if (code == _newline) return index;
    index++;
  }
  return source.length;
}

bool _colonFollows(String source, int from) {
  for (int index = from; index < source.length; index++) {
    final int code = source.codeUnitAt(index);
    if (code == _colon) return true;
    if (code == 0x20 || code == 0x09 || code == _newline || code == 0x0D) {
      continue;
    }
    return false;
  }
  return false;
}

/// Index just past the number starting at [start], or [start] when what is
/// there is not a number (a lone `-`, for instance).
int _scanNumber(String source, int start) {
  int index = start;
  if (index < source.length && source.codeUnitAt(index) == _minus) index++;

  final int integerStart = index;
  while (index < source.length && _isDigit(source.codeUnitAt(index))) {
    index++;
  }
  if (index == integerStart) return start;

  if (index < source.length && source.codeUnitAt(index) == _dot) {
    int scan = index + 1;
    final int fractionStart = scan;
    while (scan < source.length && _isDigit(source.codeUnitAt(scan))) {
      scan++;
    }
    if (scan > fractionStart) index = scan;
  }

  if (index < source.length) {
    final int code = source.codeUnitAt(index);
    if (code == _lowerE || code == _upperE) {
      int scan = index + 1;
      if (scan < source.length) {
        final int sign = source.codeUnitAt(scan);
        if (sign == _plus || sign == _minus) scan++;
      }
      final int exponentStart = scan;
      while (scan < source.length && _isDigit(source.codeUnitAt(scan))) {
        scan++;
      }
      if (scan > exponentStart) index = scan;
    }
  }

  return index;
}

/// The literal starting exactly at [index], or null. `nullish` is not `null`,
/// so the character after the match must not continue a word.
String? _literalAt(String source, int index) {
  for (final String literal in _literals) {
    if (!source.startsWith(literal, index)) continue;
    final int after = index + literal.length;
    if (after < source.length && _isWordCharacter(source.codeUnitAt(after))) {
      return null;
    }
    return literal;
  }
  return null;
}

bool _isDigit(int code) => code >= _zero && code <= _nine;

bool _isWordCharacter(int code) =>
    _isDigit(code) ||
    (code >= 0x41 && code <= 0x5A) ||
    (code >= 0x61 && code <= 0x7A) ||
    code == 0x5F;

/// Expression engine for HoloUI container previews.
///
/// Dart twin of the plugin's `art.arcane.holoui.expr` package — `ExprParser`
/// (hand-rolled lexer plus precedence-climbing parser), `Expr` (the AST) and
/// `ExprEvaluator` (tree walker). The Java side is the format's source of
/// truth; the two engines are pinned to one answer by the shared vector file
/// `test/fixtures/expr_test_vectors.json`, replayed by both test suites.
///
/// Runtime values are `double`, `String`, `bool` and `List<Object?>` — nothing
/// else. Numbers are always doubles, so the Java/Dart `int`-vs-`double` split
/// never leaks into the language: a literal `7` evaluates to `7.0` and renders
/// as `7` through the integral-string rule in [previewStringify].
///
/// Where Dart's numerics disagree with Java's, Java wins:
///
///   * `%` is Java's truncating remainder (`-1 % 3` is `-1`), which is Dart's
///     [num.remainder], not Dart's `%`.
///   * `round` is `Math.round` (ties toward positive infinity, so `round(-2.5)`
///     is `-2`), not Dart's round-half-away-from-zero.
///   * a colour narrows through a `(long)` cast that saturates before the low
///     32 bits are taken.
///
/// DOM-free: this file is pure logic and runs on the VM under `dart test`.
library;

/// Evaluation errors carry no source position — the tree they walk has no
/// remaining source text to point at. Parse errors always carry one.
const int previewNoPosition = -1;

/// Cap on live recursion depth through the two self-recursive productions.
/// Pathological input (5000 nested parens) would otherwise overflow the stack
/// with an error the document loader cannot catch.
const int previewMaxExprDepth = 256;

class PExprException implements Exception {
  final String message;

  /// Source character offset, or [previewNoPosition] for evaluation errors.
  final int position;

  const PExprException(this.message, this.position);

  @override
  String toString() => position == previewNoPosition
      ? 'PExprException: $message'
      : 'PExprException: $message (at $position)';
}

// ---------------------------------------------------------------------------
// AST
// ---------------------------------------------------------------------------

sealed class PExpr {
  const PExpr();
}

class PNum extends PExpr {
  final double value;

  const PNum(this.value);
}

class PStr extends PExpr {
  final String value;

  const PStr(this.value);
}

class PBool extends PExpr {
  final bool value;

  const PBool(this.value);
}

class PList extends PExpr {
  final List<PExpr> items;

  const PList(this.items);
}

/// Dotted identifier, e.g. `inventory.size`.
class PVar extends PExpr {
  final String name;

  const PVar(this.name);
}

/// Prefix operator: `-` or `!`.
class PUnary extends PExpr {
  final String op;
  final PExpr operand;

  const PUnary(this.op, this.operand);
}

/// `+ - * / % == != < <= > >= && ||`.
class PBinary extends PExpr {
  final String op;
  final PExpr left;
  final PExpr right;

  const PBinary(this.op, this.left, this.right);
}

class PTernary extends PExpr {
  final PExpr condition;
  final PExpr ifTrue;
  final PExpr ifFalse;

  const PTernary(this.condition, this.ifTrue, this.ifFalse);
}

/// Function call; names are never dotted.
class PCall extends PExpr {
  final String name;
  final List<PExpr> args;

  const PCall(this.name, this.args);
}

/// Variable and function resolution, the twin of `ExprScope`.
///
/// Both methods return `null` for a name this scope does not know; the
/// evaluator turns that into a [PExprException]. Implementations resolve their
/// own context-specific names first and fall back to `previewStdFunction`.
abstract class PExprScope {
  Object? variable(String dottedName);

  Object? call(String name, List<Object?> args);
}

// ---------------------------------------------------------------------------
// Parser (precedence-climbing, low to high):
// ternary -> || -> && -> equality -> relational -> additive -> multiplicative
//         -> unary -> primary
// ---------------------------------------------------------------------------

PExpr parsePreviewExpr(String source) => _Parser(source)._parseProgram();

class _Parser {
  _Parser(String source) : _tokens = _tokenize(source);

  final List<_Token> _tokens;
  int _pos = 0;
  int _depth = 0;

  PExpr _parseProgram() {
    if (_tokens.length == 1) {
      throw const PExprException('empty source', 0);
    }
    final PExpr expr = _parseTernary();
    if (!_check(_TokenType.eof)) {
      throw PExprException('unexpected token', _peek().position);
    }
    return expr;
  }

  PExpr _parseTernary() {
    _enterNesting();
    try {
      final PExpr condition = _parseOr();
      if (_match(_TokenType.question)) {
        final PExpr ifTrue = _parseTernary();
        _expect(_TokenType.colon, "expected ':'");
        final PExpr ifFalse = _parseTernary();
        return PTernary(condition, ifTrue, ifFalse);
      }
      return condition;
    } finally {
      _depth--;
    }
  }

  PExpr _parseOr() {
    PExpr left = _parseAnd();
    while (_check(_TokenType.or)) {
      _advance();
      left = PBinary('||', left, _parseAnd());
    }
    return left;
  }

  PExpr _parseAnd() {
    PExpr left = _parseEquality();
    while (_check(_TokenType.and)) {
      _advance();
      left = PBinary('&&', left, _parseEquality());
    }
    return left;
  }

  PExpr _parseEquality() {
    PExpr left = _parseRelational();
    while (_check(_TokenType.eqeq) || _check(_TokenType.neq)) {
      final String op = _opText(_advance().type);
      left = PBinary(op, left, _parseRelational());
    }
    return left;
  }

  PExpr _parseRelational() {
    PExpr left = _parseAdditive();
    while (_check(_TokenType.lt) ||
        _check(_TokenType.le) ||
        _check(_TokenType.gt) ||
        _check(_TokenType.ge)) {
      final String op = _opText(_advance().type);
      left = PBinary(op, left, _parseAdditive());
    }
    return left;
  }

  PExpr _parseAdditive() {
    PExpr left = _parseMultiplicative();
    while (_check(_TokenType.plus) || _check(_TokenType.minus)) {
      final String op = _opText(_advance().type);
      left = PBinary(op, left, _parseMultiplicative());
    }
    return left;
  }

  PExpr _parseMultiplicative() {
    PExpr left = _parseUnary();
    while (_check(_TokenType.star) ||
        _check(_TokenType.slash) ||
        _check(_TokenType.percent)) {
      final String op = _opText(_advance().type);
      left = PBinary(op, left, _parseUnary());
    }
    return left;
  }

  PExpr _parseUnary() {
    if (_check(_TokenType.minus) || _check(_TokenType.not)) {
      _enterNesting();
      try {
        final String op = _opText(_advance().type);
        return PUnary(op, _parseUnary());
      } finally {
        _depth--;
      }
    }
    return _parsePrimary();
  }

  /// Throws once live recursion depth passes [previewMaxExprDepth]; paired with
  /// a `_depth--` in the caller's `finally`.
  void _enterNesting() {
    if (++_depth > previewMaxExprDepth) {
      throw PExprException('expression too deeply nested', _peek().position);
    }
  }

  PExpr _parsePrimary() {
    final _Token t = _peek();
    switch (t.type) {
      case _TokenType.number:
        _advance();
        return PNum(t.number);
      case _TokenType.string:
        _advance();
        return PStr(t.text!);
      case _TokenType.trueLiteral:
        _advance();
        return const PBool(true);
      case _TokenType.falseLiteral:
        _advance();
        return const PBool(false);
      case _TokenType.lparen:
        _advance();
        final PExpr inner = _parseTernary();
        if (!_check(_TokenType.rparen)) {
          throw PExprException('unclosed paren', _peek().position);
        }
        _advance();
        return inner;
      case _TokenType.lbracket:
        _advance();
        final List<PExpr> items = <PExpr>[];
        if (!_check(_TokenType.rbracket)) {
          items.add(_parseTernary());
          while (_match(_TokenType.comma)) {
            items.add(_parseTernary());
          }
        }
        if (!_check(_TokenType.rbracket)) {
          throw PExprException('unclosed bracket', _peek().position);
        }
        _advance();
        return PList(items);
      case _TokenType.ident:
        _advance();
        final String name = t.text!;
        if (_check(_TokenType.lparen)) {
          if (name.contains('.')) {
            throw PExprException('call names cannot be dotted', t.position);
          }
          _advance();
          final List<PExpr> args = <PExpr>[];
          if (!_check(_TokenType.rparen)) {
            args.add(_parseTernary());
            while (_match(_TokenType.comma)) {
              args.add(_parseTernary());
            }
          }
          if (!_check(_TokenType.rparen)) {
            throw PExprException('unclosed paren', _peek().position);
          }
          _advance();
          return PCall(name, args);
        }
        return PVar(name);
      default:
        throw PExprException('unexpected token', t.position);
    }
  }

  _Token _peek() => _tokens[_pos];

  _Token _advance() => _tokens[_pos++];

  bool _check(_TokenType type) => _peek().type == type;

  bool _match(_TokenType type) {
    if (_check(type)) {
      _pos++;
      return true;
    }
    return false;
  }

  void _expect(_TokenType type, String message) {
    if (!_check(type)) {
      throw PExprException(message, _peek().position);
    }
    _pos++;
  }
}

/// The operator text an [PBinary]/[PUnary] node carries, keyed by the token it
/// was built from.
const Map<_TokenType, String> _opTexts = <_TokenType, String>{
  _TokenType.plus: '+',
  _TokenType.minus: '-',
  _TokenType.star: '*',
  _TokenType.slash: '/',
  _TokenType.percent: '%',
  _TokenType.eqeq: '==',
  _TokenType.neq: '!=',
  _TokenType.lt: '<',
  _TokenType.le: '<=',
  _TokenType.gt: '>',
  _TokenType.ge: '>=',
  _TokenType.and: '&&',
  _TokenType.or: '||',
  _TokenType.not: '!',
};

String _opText(_TokenType type) {
  final String? text = _opTexts[type];
  if (text == null) {
    throw StateError('no operator text for $type');
  }
  return text;
}

// ---------------------------------------------------------------------------
// Lexer
// ---------------------------------------------------------------------------

enum _TokenType {
  number,
  string,
  ident,
  trueLiteral,
  falseLiteral,
  lparen,
  rparen,
  lbracket,
  rbracket,
  comma,
  question,
  colon,
  plus,
  minus,
  star,
  slash,
  percent,
  eqeq,
  neq,
  lt,
  le,
  gt,
  ge,
  and,
  or,
  not,
  eof,
}

class _Token {
  final _TokenType type;
  final String? text;
  final double number;
  final int position;

  const _Token(this.type, this.text, this.number, this.position);
}

List<_Token> _tokenize(String source) {
  final List<_Token> tokens = <_Token>[];
  final int n = source.length;
  int i = 0;
  while (i < n) {
    final int c = source.codeUnitAt(i);
    if (_isWhitespace(c)) {
      i++;
      continue;
    }
    final int start = i;
    if (c == _hash) {
      i++;
      final int hexStart = i;
      while (i < n && _isHexDigit(source.codeUnitAt(i))) {
        i++;
      }
      final String hex = source.substring(hexStart, i);
      if (hex.length != 3 && hex.length != 6 && hex.length != 8) {
        throw PExprException('bad hex length', start);
      }
      tokens.add(_Token(_TokenType.number, null, _expandColor(hex), start));
      continue;
    }
    if (_isDigit(c)) {
      i++;
      while (i < n && _isDigit(source.codeUnitAt(i))) {
        i++;
      }
      if (i < n &&
          source.codeUnitAt(i) == _dot &&
          i + 1 < n &&
          _isDigit(source.codeUnitAt(i + 1))) {
        i++;
        while (i < n && _isDigit(source.codeUnitAt(i))) {
          i++;
        }
      }
      tokens.add(
        _Token(
          _TokenType.number,
          null,
          double.parse(source.substring(start, i)),
          start,
        ),
      );
      continue;
    }
    if (c == _singleQuote || c == _doubleQuote) {
      final int quote = c;
      i++;
      final StringBuffer sb = StringBuffer();
      bool closed = false;
      while (i < n) {
        final int cc = source.codeUnitAt(i);
        if (cc == quote) {
          i++;
          closed = true;
          break;
        }
        if (cc == _backslash && i + 1 < n) {
          final int esc = source.codeUnitAt(i + 1);
          switch (esc) {
            case _backslash:
              sb.write(r'\');
            case _singleQuote:
              sb.write("'");
            case _doubleQuote:
              sb.write('"');
            case _lowerN:
              sb.write('\n');
            default:
              throw PExprException('unrecognized escape sequence', i);
          }
          i += 2;
        } else {
          sb.writeCharCode(cc);
          i++;
        }
      }
      if (!closed) {
        throw PExprException('unterminated string', start);
      }
      tokens.add(_Token(_TokenType.string, sb.toString(), 0, start));
      continue;
    }
    if (_isLetter(c) || c == _underscore) {
      i = _scanIdentifierEnd(source, i, n);
      final String text = source.substring(start, i);
      final _TokenType type;
      if (text == 'true') {
        type = _TokenType.trueLiteral;
      } else if (text == 'false') {
        type = _TokenType.falseLiteral;
      } else {
        type = _TokenType.ident;
      }
      tokens.add(_Token(type, text, 0, start));
      continue;
    }
    final _TokenType? single = _singleCharTokens[c];
    if (single != null) {
      tokens.add(_Token(single, null, 0, start));
      i++;
      continue;
    }
    if (i + 1 < n) {
      final _TokenType? two = _twoCharTokens[source.substring(i, i + 2)];
      if (two != null) {
        tokens.add(_Token(two, null, 0, start));
        i += 2;
        continue;
      }
    }
    // `!`, `<` and `>` also stand alone; `=`, `&` and `|` never do.
    final _TokenType? solo = _prefixOnlyTokens[c];
    if (solo == null) {
      throw PExprException('unexpected token', start);
    }
    tokens.add(_Token(solo, null, 0, start));
    i++;
  }
  tokens.add(_Token(_TokenType.eof, null, 0, n));
  return tokens;
}

int _scanIdentifierEnd(String source, int start, int n) {
  int i = start + 1;
  while (i < n && _isIdentifierPart(source.codeUnitAt(i))) {
    i++;
  }
  while (i < n &&
      source.codeUnitAt(i) == _dot &&
      i + 1 < n &&
      (_isLetter(source.codeUnitAt(i + 1)) ||
          source.codeUnitAt(i + 1) == _underscore)) {
    i += 2;
    while (i < n && _isIdentifierPart(source.codeUnitAt(i))) {
      i++;
    }
  }
  return i;
}

/// `#RGB` and `#RRGGBB` are opaque — the parser prefixes `FF`. Only `#AARRGGBB`
/// carries its own alpha.
double _expandColor(String hex) {
  if (hex.length == 3) {
    final StringBuffer rgb = StringBuffer();
    for (int i = 0; i < 3; i++) {
      final String c = hex[i];
      rgb
        ..write(c)
        ..write(c);
    }
    return int.parse('FF$rgb', radix: 16).toDouble();
  }
  if (hex.length == 6) {
    return int.parse('FF$hex', radix: 16).toDouble();
  }
  return int.parse(hex, radix: 16).toDouble();
}

const int _hash = 0x23;
const int _dot = 0x2E;
const int _singleQuote = 0x27;
const int _doubleQuote = 0x22;
const int _backslash = 0x5C;
const int _lowerN = 0x6E;
const int _underscore = 0x5F;

const Map<String, _TokenType> _twoCharTokens = <String, _TokenType>{
  '!=': _TokenType.neq,
  '==': _TokenType.eqeq,
  '<=': _TokenType.le,
  '>=': _TokenType.ge,
  '&&': _TokenType.and,
  '||': _TokenType.or,
};

const Map<int, _TokenType> _prefixOnlyTokens = <int, _TokenType>{
  0x21: _TokenType.not,
  0x3C: _TokenType.lt,
  0x3E: _TokenType.gt,
};

const Map<int, _TokenType> _singleCharTokens = <int, _TokenType>{
  0x28: _TokenType.lparen,
  0x29: _TokenType.rparen,
  0x5B: _TokenType.lbracket,
  0x5D: _TokenType.rbracket,
  0x2C: _TokenType.comma,
  0x3F: _TokenType.question,
  0x3A: _TokenType.colon,
  0x2B: _TokenType.plus,
  0x2D: _TokenType.minus,
  0x2A: _TokenType.star,
  0x2F: _TokenType.slash,
  0x25: _TokenType.percent,
};

// Java's lexer classifies characters with `Character.isWhitespace`,
// `isLetter`, `isDigit` and `isLetterOrDigit`, all of which are Unicode-aware
// over UTF-16 code units. ASCII takes the fast path; anything above falls back
// to the matching Unicode general categories.
final RegExp _unicodeSpace = RegExp(r'^[\p{Zs}\p{Zl}\p{Zp}]$', unicode: true);
final RegExp _unicodeLetter = RegExp(r'^\p{L}$', unicode: true);
final RegExp _unicodeDigit = RegExp(r'^\p{Nd}$', unicode: true);

bool _isWhitespace(int c) {
  if (c < 0x80) {
    return c == 0x20 || (c >= 0x09 && c <= 0x0D) || (c >= 0x1C && c <= 0x1F);
  }
  // Java excludes the three no-break spaces from isWhitespace.
  if (c == 0xA0 || c == 0x2007 || c == 0x202F) {
    return false;
  }
  return _unicodeSpace.hasMatch(String.fromCharCode(c));
}

bool _isLetter(int c) {
  if (c < 0x80) {
    return (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);
  }
  return _unicodeLetter.hasMatch(String.fromCharCode(c));
}

bool _isDigit(int c) {
  if (c < 0x80) {
    return c >= 0x30 && c <= 0x39;
  }
  return _unicodeDigit.hasMatch(String.fromCharCode(c));
}

bool _isIdentifierPart(int c) =>
    _isLetter(c) || _isDigit(c) || c == _underscore;

bool _isHexDigit(int c) =>
    (c >= 0x30 && c <= 0x39) ||
    (c >= 0x61 && c <= 0x66) ||
    (c >= 0x41 && c <= 0x46);

// ---------------------------------------------------------------------------
// Evaluator
// ---------------------------------------------------------------------------

Object evalPreviewExpr(PExpr expr, PExprScope scope) {
  switch (expr) {
    case PNum(value: final double value):
      return value;
    case PStr(value: final String value):
      return value;
    case PBool(value: final bool value):
      return value;
    case PList(items: final List<PExpr> items):
      return <Object?>[
        for (final PExpr item in items) evalPreviewExpr(item, scope),
      ];
    case PVar(name: final String name):
      final Object? value = scope.variable(name);
      if (value == null) {
        throw PExprException('unknown variable: $name', previewNoPosition);
      }
      return value;
    case PUnary():
      return _evalUnary(expr, scope);
    case PBinary():
      return _evalBinary(expr, scope);
    case PTernary():
      return previewRequireBool(evalPreviewExpr(expr.condition, scope))
          ? evalPreviewExpr(expr.ifTrue, scope)
          : evalPreviewExpr(expr.ifFalse, scope);
    case PCall(name: final String name, args: final List<PExpr> args):
      final List<Object?> values = <Object?>[
        for (final PExpr arg in args) evalPreviewExpr(arg, scope),
      ];
      final Object? result = scope.call(name, values);
      if (result == null) {
        throw PExprException('unknown function: $name', previewNoPosition);
      }
      return result;
  }
}

double evalNumber(PExpr expr, PExprScope scope) =>
    previewRequireNumber(evalPreviewExpr(expr, scope));

bool evalBool(PExpr expr, PExprScope scope) =>
    previewRequireBool(evalPreviewExpr(expr, scope));

/// Numbers render per the integral-string rule: `54.0` becomes `"54"`.
String evalString(PExpr expr, PExprScope scope) =>
    previewStringify(evalPreviewExpr(expr, scope));

/// The numeric ARGB value narrowed to 32 bits, unsigned: `#FFFF0000` is
/// `0xFFFF0000`, not Java's signed `-65536`. Java's `(int) (long) value`
/// reinterprets the same bits, so the two agree channel for channel.
int evalColor(PExpr expr, PExprScope scope) =>
    previewNarrowArgb(evalNumber(expr, scope));

/// True when [expr] contains no [PVar] or [PCall] node anywhere — a field the
/// document loader can fold once at build instead of re-evaluating.
bool isConstantExpr(PExpr expr) {
  switch (expr) {
    case PNum():
    case PStr():
    case PBool():
      return true;
    case PList(items: final List<PExpr> items):
      return items.every(isConstantExpr);
    case PVar():
    case PCall():
      return false;
    case PUnary():
      return isConstantExpr(expr.operand);
    case PBinary():
      return isConstantExpr(expr.left) && isConstantExpr(expr.right);
    case PTernary():
      return isConstantExpr(expr.condition) &&
          isConstantExpr(expr.ifTrue) &&
          isConstantExpr(expr.ifFalse);
  }
}

Object _evalUnary(PUnary u, PExprScope scope) {
  final Object value = evalPreviewExpr(u.operand, scope);
  switch (u.op) {
    case '-':
      return -previewRequireNumber(value);
    case '!':
      return !previewRequireBool(value);
    default:
      throw PExprException(
        'unknown unary operator: ${u.op}',
        previewNoPosition,
      );
  }
}

Object _evalBinary(PBinary b, PExprScope scope) {
  final String op = b.op;
  // && and || short-circuit: the right operand is only evaluated (and its
  // variables/calls only looked up) when the left does not decide the result.
  if (op == '&&') {
    final bool left = previewRequireBool(evalPreviewExpr(b.left, scope));
    return left && previewRequireBool(evalPreviewExpr(b.right, scope));
  }
  if (op == '||') {
    final bool left = previewRequireBool(evalPreviewExpr(b.left, scope));
    return left || previewRequireBool(evalPreviewExpr(b.right, scope));
  }

  final Object left = evalPreviewExpr(b.left, scope);
  final Object right = evalPreviewExpr(b.right, scope);
  switch (op) {
    case '+':
      // Numeric addition unless either side is a string, then concatenation.
      if (left is String || right is String) {
        return previewStringify(left) + previewStringify(right);
      }
      return previewRequireNumber(left) + previewRequireNumber(right);
    case '-':
      return previewRequireNumber(left) - previewRequireNumber(right);
    case '*':
      return previewRequireNumber(left) * previewRequireNumber(right);
    case '/':
      return previewRequireNumber(left) / _requireNonZero(right);
    case '%':
      // Java's truncating remainder keeps the sign of the left operand, which
      // is Dart's remainder(); Dart's own % is the floor variant `mod()` uses.
      return previewRequireNumber(left).remainder(_requireNonZero(right));
    case '==':
      return _valuesEqual(left, right);
    case '!=':
      return !_valuesEqual(left, right);
    case '<':
      return previewRequireNumber(left) < previewRequireNumber(right);
    case '<=':
      return previewRequireNumber(left) <= previewRequireNumber(right);
    case '>':
      return previewRequireNumber(left) > previewRequireNumber(right);
    case '>=':
      return previewRequireNumber(left) >= previewRequireNumber(right);
    default:
      throw PExprException('unknown binary operator: $op', previewNoPosition);
  }
}

/// `==`/`!=` compare numbers, strings or booleans; mixed types are an error.
bool _valuesEqual(Object? left, Object? right) {
  if (left is double && right is double) {
    return left == right;
  }
  if (left is String && right is String) {
    return left == right;
  }
  if (left is bool && right is bool) {
    return left == right;
  }
  throw PExprException(
    'cannot compare ${previewTypeName(left)} and ${previewTypeName(right)}',
    previewNoPosition,
  );
}

// ---------------------------------------------------------------------------
// Coercion helpers, shared with the function library
// ---------------------------------------------------------------------------

double previewRequireNumber(Object? value) {
  if (value is double) {
    return value;
  }
  throw PExprException(
    'expected number, got ${previewTypeName(value)}',
    previewNoPosition,
  );
}

bool previewRequireBool(Object? value) {
  if (value is bool) {
    return value;
  }
  throw PExprException(
    'expected boolean, got ${previewTypeName(value)}',
    previewNoPosition,
  );
}

double _requireNonZero(Object? value) {
  final double d = previewRequireNumber(value);
  if (d == 0.0) {
    throw const PExprException('division by zero', previewNoPosition);
  }
  return d;
}

String previewTypeName(Object? value) {
  if (value == null) {
    return 'null';
  }
  if (value is double) {
    return 'number';
  }
  if (value is String) {
    return 'string';
  }
  if (value is bool) {
    return 'boolean';
  }
  if (value is List) {
    return 'list';
  }
  return value.runtimeType.toString();
}

/// Text form of a runtime value. Numbers follow the integral-string rule (a
/// finite double equal to its own rint renders as a `long`, no decimal point);
/// everything else follows Java's `Double.toString`.
String previewStringify(Object? value) {
  if (value is String) {
    return value;
  }
  if (value is double) {
    return _numberToString(value);
  }
  if (value is bool) {
    return value ? 'true' : 'false';
  }
  throw PExprException(
    'cannot convert ${previewTypeName(value)} to string',
    previewNoPosition,
  );
}

String _numberToString(double value) {
  if (value.isFinite && value == value.roundToDouble()) {
    return previewLongToString(value);
  }
  return _javaDoubleToString(value);
}

/// Java `Long.toString((long) value)` for an integral double, saturating cast
/// included: `(long) 1e21` is `Long.MAX_VALUE`, not `1e21`.
String previewLongToString(double value) {
  if (value >= _longMaxAsDouble) {
    return '9223372036854775807';
  }
  if (value <= _longMinAsDouble) {
    return '-9223372036854775808';
  }
  // Exact on both the VM (64-bit ints) and the web (BigInt) above 2^53.
  return value.abs() < 9007199254740992.0
      ? value.toInt().toString()
      : BigInt.from(value).toString();
}

/// Java `Double.toString`: plain decimal in `[1e-3, 1e7)`, scientific notation
/// outside it, always with at least one fraction digit. Dart prints plain
/// decimals over a much wider range and writes exponents as `e+7`.
String _javaDoubleToString(double value) {
  if (value.isNaN) {
    return 'NaN';
  }
  if (value.isInfinite) {
    return value.isNegative ? '-Infinity' : 'Infinity';
  }
  final double magnitude = value.abs();
  if (magnitude >= 1e-3 && magnitude < 1e7) {
    return value.toString();
  }
  if (magnitude == 0.0) {
    return value.isNegative ? '-0.0' : '0.0';
  }
  final String exponential = value.toStringAsExponential();
  final int marker = exponential.indexOf('e');
  String mantissa = exponential.substring(0, marker);
  if (!mantissa.contains('.')) {
    mantissa = '$mantissa.0';
  }
  String exponent = exponential.substring(marker + 1);
  if (exponent.startsWith('+')) {
    exponent = exponent.substring(1);
  }
  return '${mantissa}E$exponent';
}

/// Java `Math.round` as a double: ties go toward positive infinity, so
/// `round(2.5)` is `3` and `round(-2.5)` is `-2`. Dart's [num.round] rounds
/// ties away from zero, which disagrees on every negative half.
double previewRound(double value) {
  if (value.isNaN) {
    return 0.0;
  }
  if (value >= _longMaxAsDouble) {
    return _longMaxAsDouble;
  }
  if (value <= _longMinAsDouble) {
    return _longMinAsDouble;
  }
  final double floor = value.floorToDouble();
  // `value - floor` is exact here, so 0.49999999999999994 stays below the tie
  // instead of being lifted over it by a `floor(value + 0.5)` shortcut.
  final double rounded = value - floor >= 0.5 ? floor + 1.0 : floor;
  // Java's result comes back through a long, which has no negative zero.
  return rounded == 0.0 ? 0.0 : rounded;
}

/// The unsigned low 32 bits of Java's `(long) value` cast — the narrowing every
/// colour goes through before its channels are read.
int previewNarrowArgb(double value) {
  if (value.isNaN) {
    return 0;
  }
  final double truncated = value.truncateToDouble();
  if (truncated >= _longMaxAsDouble) {
    return 0xFFFFFFFF;
  }
  if (truncated <= _longMinAsDouble) {
    return 0;
  }
  // Dart's % is the floor variant, so a negative value lands on its
  // two's-complement image without a sign fixup.
  return (truncated % 4294967296.0).toInt();
}

/// `(double) Long.MAX_VALUE` and `(double) Long.MIN_VALUE`, the two saturation
/// points of Java's double-to-long cast.
const double _longMaxAsDouble = 9223372036854775807.0;
const double _longMinAsDouble = -9223372036854775808.0;

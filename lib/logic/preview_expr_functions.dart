/// Standard function library for the preview expression language.
///
/// Dart twin of the plugin's `ExprFunctions`: math, colour and string helpers,
/// dispatched by name over already-evaluated arguments. [previewStdFunction]
/// returns `null` for an unknown name so a [PExprScope] can resolve its own
/// context-specific names (`lang`, `count`, `occupied`, `item`) first and fall
/// back to this library.
///
/// Colours are the unsigned 32-bit ARGB value carried as a double, alpha in the
/// most significant byte. Channel maths goes through integer division and
/// remainder rather than shifts so the VM and the web agree above 2^31.
///
/// DOM-free: pure logic, runs on the VM under `dart test`.
library;

import 'dart:math' as math;

import 'preview_expr.dart';

final BigInt _javaLongMax = BigInt.parse('9223372036854775807');
final BigInt _javaLongMin = BigInt.parse('-9223372036854775808');
const double _javaLongMaxAsDouble = 9223372036854775807.0;
const double _javaLongMinAsDouble = -9223372036854775808.0;
const double _maxSafeIntegerAsDouble = 9007199254740992.0;

/// Every pure function shared by authored text and container-preview
/// expressions. Contexts add `lang`, inventory functions, PAPI and metrics.
const List<String> previewStandardFunctionNames = <String>[
  'clamp',
  'lerp',
  'min',
  'max',
  'floor',
  'ceil',
  'round',
  'abs',
  'mod',
  'sin',
  'cos',
  'pow',
  'smoothstep',
  'rgb',
  'argb',
  'alpha',
  'mix',
  'palette',
  'select',
  'number',
  'bar',
  'hex',
  'str',
  'fixed',
  'plain',
  'readable',
  'marquee',
  'timeline',
  'typewriter',
  'flash',
  'wipe',
  'scanner',
  'scramble',
  'odometer',
  'wave',
];

Object? previewStdFunction(String name, List<Object?> args) {
  switch (name) {
    case 'clamp':
      _requireCount(name, args, 3);
      return math.min(
        math.max(_numArg(name, args, 0), _numArg(name, args, 1)),
        _numArg(name, args, 2),
      );
    case 'lerp':
      _requireCount(name, args, 3);
      final double a = _numArg(name, args, 0);
      final double b = _numArg(name, args, 1);
      return a + (b - a) * _numArg(name, args, 2);
    case 'min':
      _requireCount(name, args, 2);
      return math.min(_numArg(name, args, 0), _numArg(name, args, 1));
    case 'max':
      _requireCount(name, args, 2);
      return math.max(_numArg(name, args, 0), _numArg(name, args, 1));
    case 'floor':
      return _oneNumArg(name, args).floorToDouble();
    case 'ceil':
      return _oneNumArg(name, args).ceilToDouble();
    case 'round':
      return previewRound(_oneNumArg(name, args));
    case 'abs':
      return _oneNumArg(name, args).abs();
    case 'mod':
      return _mod(name, args);
    case 'sin':
      return math.sin(_oneNumArg(name, args));
    case 'cos':
      return math.cos(_oneNumArg(name, args));
    case 'pow':
      _requireCount(name, args, 2);
      final double power = math
          .pow(_numArg(name, args, 0), _numArg(name, args, 1))
          .toDouble();
      if (!power.isFinite) {
        throw const PExprException(
          'pow result must be finite',
          previewNoPosition,
        );
      }
      return power;
    case 'smoothstep':
      _requireCount(name, args, 3);
      final double lower = _numArg(name, args, 0);
      final double upper = _numArg(name, args, 1);
      // Edges are checked before argument 3 is read, exactly like
      // `ExprFunctions.smoothstep`, so a call that is wrong in both ways
      // reports the same failure in both engines.
      if (lower == upper) {
        throw const PExprException(
          'smoothstep edges must differ',
          previewNoPosition,
        );
      }
      final double value = _numArg(name, args, 2);
      final double t = math.min(
        1.0,
        math.max(0.0, (value - lower) / (upper - lower)),
      );
      return t * t * (3.0 - 2.0 * t);
    case 'rgb':
      _requireCount(name, args, 3);
      return _packArgb(
        0xFF,
        _clampChannel(_numArg(name, args, 0)),
        _clampChannel(_numArg(name, args, 1)),
        _clampChannel(_numArg(name, args, 2)),
      );
    case 'argb':
      _requireCount(name, args, 4);
      return _packArgb(
        _clampChannel(_numArg(name, args, 0)),
        _clampChannel(_numArg(name, args, 1)),
        _clampChannel(_numArg(name, args, 2)),
        _clampChannel(_numArg(name, args, 3)),
      );
    case 'alpha':
      return _alpha(name, args);
    case 'mix':
      return _mix(name, args);
    case 'palette':
      return _palette(name, args);
    case 'select':
      return _select(name, args);
    case 'number':
      return _number(name, args);
    case 'bar':
      return _bar(name, args);
    case 'hex':
      return _hex(name, args);
    case 'str':
      _requireCount(name, args, 1);
      return previewStringify(args[0]);
    case 'fixed':
      return _fixed(name, args);
    case 'plain':
      _requireCount(name, args, 1);
      return _strArg(name, args, 0).replaceAll(_legacyCode, '');
    case 'readable':
      _requireCount(name, args, 1);
      return previewReadable(_strArg(name, args, 0));
    case 'marquee':
      return _marquee(name, args);
    case 'timeline':
      return _timeline(name, args);
    case 'typewriter':
      return _typewriter(name, args);
    case 'flash':
      return _flash(name, args);
    case 'wipe':
      return _wipe(name, args);
    case 'scanner':
      return _scanner(name, args);
    case 'scramble':
      return _scramble(name, args);
    case 'odometer':
      return _odometer(name, args);
    case 'wave':
      return _wave(name, args);
    default:
      return null;
  }
}

// ---------------------------------------------------------------------------
// Math
// ---------------------------------------------------------------------------

/// `floorMod` semantics on doubles: `a - floor(a / b) * b`. A zero divisor
/// throws exactly like the `%` operator rather than producing NaN, so the two
/// remainder operations agree and both stay pinnable in the vector file.
double _mod(String name, List<Object?> args) {
  _requireCount(name, args, 2);
  final double a = _numArg(name, args, 0);
  final double b = _numArg(name, args, 1);
  if (b == 0.0) {
    throw const PExprException('division by zero', previewNoPosition);
  }
  return a - (a / b).floorToDouble() * b;
}

// ---------------------------------------------------------------------------
// Colour
// ---------------------------------------------------------------------------

double _alpha(String name, List<Object?> args) {
  _requireCount(name, args, 2);
  final int color = previewNarrowArgb(_numArg(name, args, 0));
  final int a = _clampChannel(_numArg(name, args, 1));
  return ((color % 0x1000000) + a * 0x1000000).toDouble();
}

/// Per-channel linear blend (including alpha): `round(a + (b - a) * t)` with
/// `t` clamped to [0, 1].
double _mix(String name, List<Object?> args) {
  _requireCount(name, args, 3);
  final int c1 = previewNarrowArgb(_numArg(name, args, 0));
  final int c2 = previewNarrowArgb(_numArg(name, args, 1));
  final double t = math.min(1.0, math.max(0.0, _numArg(name, args, 2)));
  return _packArgb(
    _mixChannel(_channel(c1, 0x1000000), _channel(c2, 0x1000000), t),
    _mixChannel(_channel(c1, 0x10000), _channel(c2, 0x10000), t),
    _mixChannel(_channel(c1, 0x100), _channel(c2, 0x100), t),
    _mixChannel(_channel(c1, 1), _channel(c2, 1), t),
  );
}

int _mixChannel(int a, int b, double t) =>
    previewRound(a + (b - a) * t).toInt();

/// One byte of an already-narrowed ARGB value; [divisor] is `1 << shift`.
int _channel(int argb, int divisor) => (argb ~/ divisor) % 256;

int _clampChannel(double value) =>
    previewRound(math.min(255.0, math.max(0.0, value))).toInt();

double _packArgb(int a, int r, int g, int b) =>
    (a * 0x1000000 + r * 0x10000 + g * 0x100 + b).toDouble();

// ---------------------------------------------------------------------------
// Lists / strings
// ---------------------------------------------------------------------------

/// Index is `(long) floor(index)` — a saturating cast in Java — wrapped into
/// range with `floorMod`.
double _palette(String name, List<Object?> args) {
  _requireCount(name, args, 2);
  final Object? listArg = args[0];
  if (listArg is! List<Object?>) {
    throw PExprException(
      '{function} argument 1 must be a list',
      previewNoPosition,
      <String, Object?>{'function': name},
    );
  }
  if (listArg.isEmpty) {
    throw PExprException(
      '{function} list must not be empty',
      previewNoPosition,
      <String, Object?>{'function': name},
    );
  }
  final int index = _floorModSignedLong(_numArg(name, args, 1), listArg.length);
  final Object? item = listArg[index];
  if (item is! double) {
    throw PExprException(
      '{function} list entries must be numbers',
      previewNoPosition,
      <String, Object?>{'function': name},
    );
  }
  return item;
}

Object? _select(String name, List<Object?> args) {
  _requireCount(name, args, 2);
  final Object? listArg = args[0];
  if (listArg is! List<Object?>) {
    throw PExprException(
      '{function} argument 1 must be a list',
      previewNoPosition,
      <String, Object?>{'function': name},
    );
  }
  if (listArg.isEmpty) {
    throw PExprException(
      '{function} list must not be empty',
      previewNoPosition,
      <String, Object?>{'function': name},
    );
  }
  final int index = _floorModSignedLong(_numArg(name, args, 1), listArg.length);
  return listArg[index];
}

const int _animationMaxTextCharacters = 256;
const int _animationMaxStyledCharacters = 64;
const int _animationMaxWindowWidth = 64;
const int _animationMaxTimelineSteps = 64;
const int _animationMaxStyles = 16;
const double _animationMaxTimelineSeconds = 3600;
const double _animationMaxSafeWholeNumber = 9007199254740991;
final List<int> _scrambleGlyphs = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#\$?'
    .runes
    .toList(growable: false);
final RegExp _animationFormattingToken = RegExp(
  r'(?:&[0-9A-Fa-fK-Ok-oRr]|§[0-9A-Fa-fK-Ok-oRr]|\[[0-9A-Fa-f]{6}\]|%[^%\s]+%)',
);
final RegExp _animationStyle = RegExp(
  r'^(?:&[0-9A-Fa-fRr]|\[[0-9A-Fa-f]{6}\])(?:&[0-9A-Fa-fK-Ok-oRr]|\[[0-9A-Fa-f]{6}\])?$',
);

String _marquee(String name, List<Object?> args) {
  _requireCount(name, args, 3);
  final List<int> text = _animationPlainCodePoints(
    name,
    _strArg(name, args, 0),
    _animationMaxTextCharacters,
  );
  final int width = _animationWholeArg(
    name,
    args,
    1,
    1,
    _animationMaxWindowWidth,
  );
  final int cycle = text.length + width;
  final int start = _animationStep(name, _numArg(name, args, 2), cycle);
  final StringBuffer out = StringBuffer();
  for (int index = 0; index < width; index++) {
    final int source = (start + index) % cycle;
    out.writeCharCode(source < text.length ? text[source] : 32);
  }
  return out.toString();
}

String _timeline(String name, List<Object?> args) {
  _requireCount(name, args, 2);
  final Object? stepsArg = args[0];
  if (stepsArg is! List<Object?>) {
    throw _animationError('$name argument 1 must be a list');
  }
  if (stepsArg.isEmpty || stepsArg.length > _animationMaxTimelineSteps) {
    throw _animationError(
      '$name argument 1 must contain between 1 and $_animationMaxTimelineSteps steps',
    );
  }
  final List<String> texts = <String>[];
  final List<double> durations = <double>[];
  double total = 0;
  for (int index = 0; index < stepsArg.length; index++) {
    final Object? rawStep = stepsArg[index];
    if (rawStep is! List<Object?> ||
        rawStep.length != 2 ||
        rawStep[0] is! String ||
        rawStep[1] is! double ||
        !(rawStep[1]! as double).isFinite ||
        (rawStep[1]! as double) <= 0) {
      throw _animationError(
        '$name step ${index + 1} must be [text, positiveSeconds]',
      );
    }
    final String text = rawStep[0]! as String;
    final double duration = rawStep[1]! as double;
    _animationCodePoints(name, text, _animationMaxTextCharacters);
    texts.add(text);
    durations.add(duration);
    total += duration;
    if (total > _animationMaxTimelineSeconds) {
      throw _animationError(
        '$name total duration must not exceed ${_animationMaxTimelineSeconds.toInt()} seconds',
      );
    }
  }
  final double elapsed = _numArg(name, args, 1);
  if (!elapsed.isFinite) {
    throw _animationError('$name argument 2 must be finite');
  }
  double position = elapsed % total;
  if (position < 0) position += total;
  for (int index = 0; index < durations.length; index++) {
    if (position < durations[index]) return texts[index];
    position -= durations[index];
  }
  return texts.last;
}

String _typewriter(String name, List<Object?> args) {
  _requireCount(name, args, 3);
  final List<int> text = _animationPlainCodePoints(
    name,
    _strArg(name, args, 0),
    _animationMaxTextCharacters,
  );
  if (text.isEmpty) return '';
  final int hold = _animationWholeArg(name, args, 2, 0, 1200);
  final int phase = _animationStep(
    name,
    _numArg(name, args, 1),
    text.length * 2 + hold,
  );
  final int visible = phase <= text.length
      ? phase
      : phase < text.length + hold
      ? text.length
      : text.length * 2 + hold - phase;
  return _animationPrefix(text, visible, false);
}

String _flash(String name, List<Object?> args) {
  _requireCount(name, args, 3);
  final String first = _strArg(name, args, 0);
  final String second = _strArg(name, args, 1);
  _animationCodePoints(name, first, _animationMaxTextCharacters);
  _animationCodePoints(name, second, _animationMaxTextCharacters);
  return _animationStep(name, _numArg(name, args, 2), 2) == 0 ? first : second;
}

String _wipe(String name, List<Object?> args) {
  _requireCount(name, args, 2);
  final List<int> text = _animationPlainCodePoints(
    name,
    _strArg(name, args, 0),
    _animationMaxTextCharacters,
  );
  if (text.isEmpty) return '';
  final int phase = _animationStep(
    name,
    _numArg(name, args, 1),
    text.length * 2,
  );
  final int visible = phase <= text.length ? phase : text.length * 2 - phase;
  return _animationPrefix(text, visible, true);
}

String _scanner(String name, List<Object?> args) {
  _requireCount(name, args, 4);
  final List<int> text = _animationPlainCodePoints(
    name,
    _strArg(name, args, 0),
    _animationMaxStyledCharacters,
  );
  if (text.isEmpty) return '';
  final String base = _strArg(name, args, 1);
  final String highlight = _strArg(name, args, 2);
  _animationRequireStyle(name, base);
  _animationRequireStyle(name, highlight);
  final int active = _animationStep(name, _numArg(name, args, 3), text.length);
  final StringBuffer out = StringBuffer();
  out.write(active == 0 ? highlight : base);
  for (int index = 0; index < text.length; index++) {
    out.writeCharCode(text[index]);
    if (index == active) {
      out.write(base);
    } else if (index + 1 == active) {
      out.write(highlight);
    }
  }
  return out.toString();
}

String _scramble(String name, List<Object?> args) {
  _requireCount(name, args, 2);
  final List<int> text = _animationPlainCodePoints(
    name,
    _strArg(name, args, 0),
    _animationMaxTextCharacters,
  );
  if (text.isEmpty) return '';
  final int phase = _animationStep(
    name,
    _numArg(name, args, 1),
    text.length + 2,
  );
  final int resolved = math.min(phase, text.length);
  final StringBuffer out = StringBuffer();
  for (int index = 0; index < text.length; index++) {
    final int codePoint = text[index];
    if (index < resolved || _animationIsWhitespace(codePoint)) {
      out.writeCharCode(codePoint);
    } else {
      final int mixed = phase * 31 + index * 17 + codePoint;
      out.writeCharCode(_scrambleGlyphs[mixed % _scrambleGlyphs.length]);
    }
  }
  return out.toString();
}

String _odometer(String name, List<Object?> args) {
  _requireCount(name, args, 4);
  final double from = _numArg(name, args, 0);
  final double to = _numArg(name, args, 1);
  final double progress = _numArg(name, args, 2);
  if (!from.isFinite || !to.isFinite || !progress.isFinite) {
    throw _animationError('$name numeric arguments must be finite');
  }
  if (from.abs() > _animationMaxSafeWholeNumber ||
      to.abs() > _animationMaxSafeWholeNumber) {
    throw _animationError(
      '$name endpoints must stay within the safe whole-number range',
    );
  }
  if (from != from.roundToDouble() || to != to.roundToDouble()) {
    throw _animationError('$name endpoints must be whole numbers');
  }
  final int digits = _animationWholeArg(name, args, 3, 1, 16);
  final double interpolated =
      from + (to - from) * math.max(0.0, math.min(1.0, progress));
  if (!interpolated.isFinite) {
    throw _animationError('$name result must be finite');
  }
  final int value = previewRound(interpolated).toInt();
  final String raw = value.toString();
  final bool negative = raw.startsWith('-');
  final String magnitude = negative ? raw.substring(1) : raw;
  final String padded = magnitude.padLeft(digits, '0');
  return negative ? '-$padded' : padded;
}

String _wave(String name, List<Object?> args) {
  _requireCount(name, args, 3);
  final List<int> text = _animationPlainCodePoints(
    name,
    _strArg(name, args, 0),
    _animationMaxStyledCharacters,
  );
  if (text.isEmpty) return '';
  final Object? stylesArg = args[1];
  if (stylesArg is! List<Object?> ||
      stylesArg.isEmpty ||
      stylesArg.length > _animationMaxStyles) {
    throw _animationError(
      '$name argument 2 must contain between 1 and $_animationMaxStyles styles',
    );
  }
  final List<String> styles = <String>[];
  for (final Object? rawStyle in stylesArg) {
    if (rawStyle is! String) {
      throw _animationError('$name argument 2 entries must be strings');
    }
    _animationRequireStyle(name, rawStyle);
    styles.add(rawStyle);
  }
  final int start = _animationStep(name, _numArg(name, args, 2), styles.length);
  final StringBuffer out = StringBuffer();
  for (int index = 0; index < text.length; index++) {
    out.write(styles[(start + index) % styles.length]);
    out.writeCharCode(text[index]);
  }
  out.write(styles.first);
  return out.toString();
}

List<int> _animationCodePoints(String name, String text, int maximum) {
  _animationSingleLine(name, text);
  final List<int> codePoints = text.runes.toList(growable: false);
  if (codePoints.length > maximum) {
    throw _animationError('$name text must not exceed $maximum characters');
  }
  return codePoints;
}

List<int> _animationPlainCodePoints(String name, String text, int maximum) {
  if (_animationFormattingToken.hasMatch(text)) {
    throw _animationError(
      '$name text must be plain; put formatting outside the text argument',
    );
  }
  final List<int> codePoints = _animationCodePoints(name, text, maximum);
  for (final int codePoint in codePoints) {
    if (_animationIsComplexGraphemePart(codePoint)) {
      throw _animationError(
        '$name text must use standalone characters, not combined emoji or marks',
      );
    }
  }
  return codePoints;
}

bool _animationIsComplexGraphemePart(int codePoint) =>
    codePoint == 0x200D ||
    codePoint >= 0x0300 && codePoint <= 0x036F ||
    codePoint >= 0x1AB0 && codePoint <= 0x1AFF ||
    codePoint >= 0x1DC0 && codePoint <= 0x1DFF ||
    codePoint >= 0x20D0 && codePoint <= 0x20FF ||
    codePoint >= 0xFE00 && codePoint <= 0xFE0F ||
    codePoint >= 0xFE20 && codePoint <= 0xFE2F ||
    codePoint >= 0x1F1E6 && codePoint <= 0x1F1FF ||
    codePoint >= 0x1F3FB && codePoint <= 0x1F3FF ||
    codePoint >= 0xE0020 && codePoint <= 0xE007F ||
    codePoint >= 0xE0100 && codePoint <= 0xE01EF;

bool _animationIsWhitespace(int codePoint) =>
    codePoint == 0x09 ||
    codePoint == 0x0B ||
    codePoint == 0x0C ||
    codePoint == 0x20;

void _animationRequireStyle(String name, String value) {
  _animationSingleLine(name, value);
  if (!_animationStyle.hasMatch(value)) {
    throw _animationError(
      '$name styles must start with a color or reset and contain at most two formatting codes',
    );
  }
}

void _animationSingleLine(String name, String value) {
  if (value.contains('\n') ||
      value.contains('\r') ||
      value.contains('\u0085') ||
      value.contains('\u2028') ||
      value.contains('\u2029')) {
    throw _animationError('$name text must stay on one line');
  }
}

String _animationPrefix(List<int> text, int visible, bool pad) {
  final StringBuffer out = StringBuffer();
  for (int index = 0; index < visible; index++) {
    out.writeCharCode(text[index]);
  }
  if (pad) out.write(' ' * (text.length - visible));
  return out.toString();
}

int _animationStep(String name, double value, int divisor) {
  if (!value.isFinite) {
    throw _animationError('animation step must be finite');
  }
  return _floorModSignedLong(value, divisor);
}

int _animationWholeArg(
  String name,
  List<Object?> args,
  int index,
  int minimum,
  int maximum,
) {
  final double value = _numArg(name, args, index);
  if (value != value.roundToDouble() || value < minimum || value > maximum) {
    throw _animationError(
      '$name argument ${index + 1} must be a whole number in [$minimum, $maximum]',
    );
  }
  return value.toInt();
}

PExprException _animationError(String message) =>
    PExprException(message, previewNoPosition);

int _floorModSignedLong(double value, int divisor) {
  if (value.isNaN) return 0;
  final double floored = value.floorToDouble();
  if (floored.abs() < _maxSafeIntegerAsDouble) {
    return floored.toInt() % divisor;
  }
  final BigInt narrowed = floored >= _javaLongMaxAsDouble
      ? _javaLongMax
      : floored <= _javaLongMinAsDouble
      ? _javaLongMin
      : BigInt.from(floored);
  return (narrowed % BigInt.from(divisor)).toInt();
}

double _number(String name, List<Object?> args) {
  _requireCount(name, args, 1);
  final Object? value = args[0];
  if (value is double) return value;
  if (value is! String) {
    throw PExprException(
      '{function} argument 1 must be a number or string',
      previewNoPosition,
      <String, Object?>{'function': name},
    );
  }
  final String plain = value
      .replaceAll(RegExp(r'[&§][0-9A-Fa-fK-Ok-oRr]'), '')
      .replaceAll(',', '');
  final Match? match = RegExp(
    r'[-+]?(?:\d+(?:\.\d*)?|\.\d+)',
  ).firstMatch(plain);
  if (match == null) {
    throw PExprException(
      '{function} could not find a number',
      previewNoPosition,
      <String, Object?>{'function': name},
    );
  }
  return double.parse(match.group(0)!);
}

String _bar(String name, List<Object?> args) {
  _requireCount(name, args, 5);
  final double value = _numArg(name, args, 0);
  final double maximum = _numArg(name, args, 1);
  final double widthValue = _numArg(name, args, 2);
  if (maximum <= 0) {
    throw PExprException(
      '{function} argument 2 must be greater than zero',
      previewNoPosition,
      <String, Object?>{'function': name},
    );
  }
  if (widthValue != widthValue.roundToDouble() ||
      widthValue < 1 ||
      widthValue > 64) {
    throw PExprException(
      '{function} argument 3 must be a whole number in [1, 64]',
      previewNoPosition,
      <String, Object?>{'function': name},
    );
  }
  final int width = widthValue.toInt();
  final int count = previewRound(
    math.min(1.0, math.max(0.0, value / maximum)) * width,
  ).toInt();
  return _strArg(name, args, 3) * count +
      _strArg(name, args, 4) * (width - count);
}

String _hex(String name, List<Object?> args) {
  _requireCount(name, args, 1);
  final int color = previewNarrowArgb(_numArg(name, args, 0)) & 0xFFFFFF;
  return '[${color.toRadixString(16).padLeft(6, '0').toUpperCase()}]';
}

String _fixed(String name, List<Object?> args) {
  _requireCount(name, args, 2);
  final double x = _numArg(name, args, 0);
  final double digitsArg = _numArg(name, args, 1);
  // digits must be a whole number in [0, 20]: negative/fractional precision is
  // meaningless to String.format, and >20 is a RangeError in Dart's
  // toStringAsFixed, so the shared range keeps both engines identical.
  if (digitsArg != digitsArg.roundToDouble() ||
      digitsArg < 0 ||
      digitsArg > 20) {
    throw PExprException(
      '{function} argument 2 (digits) must be a whole number in [0, 20]',
      previewNoPosition,
      <String, Object?>{'function': name},
    );
  }
  final int digits = digitsArg.toInt();
  if (!x.isFinite) {
    // Java's %f writes "NaN" / "Infinity" / "-Infinity", same as Dart's
    // toString, which is what toStringAsFixed falls back to anyway.
    return x.toString();
  }
  return _javaFixed(x, digits);
}

/// Java `String.format("%.Nf", x)`.
///
/// Java rounds the *shortest* decimal representation of the double half-up, not
/// the exact binary value: `fixed(1.005, 2)` is `1.01` there even though the
/// double really is 1.00499999999999989. Dart's [double.toStringAsFixed] rounds
/// the exact value and answers `1.00`, and above 1e21 it gives up and returns
/// `1e+21`, so neither end of the range can use it.
String _javaFixed(double value, int digits) {
  final double magnitude = value.abs();
  // Shortest significant digits, positioned so that magnitude is
  // `0.<sig> * 10^decExp`.
  final String exponential = magnitude.toStringAsExponential();
  final int marker = exponential.indexOf('e');
  final String sig = exponential.substring(0, marker).replaceFirst('.', '');
  final int decExp = int.parse(exponential.substring(marker + 1)) + 1;

  final int keep = decExp + digits;
  final String roundedSig;
  final int roundedExp;
  if (keep >= sig.length) {
    roundedSig = sig;
    roundedExp = decExp;
  } else if (keep < 0) {
    roundedSig = '0';
    roundedExp = 1;
  } else if (keep == 0) {
    // Every significant digit falls outside the precision: the value either
    // rounds up into the last kept place or vanishes.
    roundedSig = sig.codeUnitAt(0) >= _digitFive ? '1' : '0';
    roundedExp = sig.codeUnitAt(0) >= _digitFive ? decExp + 1 : 1;
  } else if (sig.codeUnitAt(keep) < _digitFive) {
    roundedSig = sig.substring(0, keep);
    roundedExp = decExp;
  } else {
    final List<int> units = sig.substring(0, keep).codeUnits.toList();
    int carry = keep - 1;
    while (carry >= 0 && units[carry] == _digitNine) {
      units[carry] = _digitZero;
      carry--;
    }
    if (carry < 0) {
      // All nines: 9.99 at one digit becomes 10.0, one place wider.
      roundedSig = '1';
      roundedExp = decExp + 1;
    } else {
      units[carry]++;
      roundedSig = String.fromCharCodes(units);
      roundedExp = decExp;
    }
  }

  final String integer;
  String fraction;
  if (roundedExp <= 0) {
    integer = '0';
    fraction = '${'0' * -roundedExp}$roundedSig';
  } else if (roundedExp >= roundedSig.length) {
    integer = '$roundedSig${'0' * (roundedExp - roundedSig.length)}';
    fraction = '';
  } else {
    integer = roundedSig.substring(0, roundedExp);
    fraction = roundedSig.substring(roundedExp);
  }
  if (fraction.length < digits) {
    fraction = fraction.padRight(digits, '0');
  }
  final String sign = value.isNegative ? '-' : '';
  return digits == 0 ? '$sign$integer' : '$sign$integer.$fraction';
}

const int _digitZero = 0x30;
const int _digitFive = 0x35;
const int _digitNine = 0x39;

/// Legacy colour/format codes: `&` followed by a colour digit, a format letter,
/// or reset. Everything else beginning with `&` is left alone.
final RegExp _legacyCode = RegExp(r'&[0-9A-Fa-fK-Ok-oRr]');

/// Turns an enum-style id into display text: `IRON_ORE` becomes `Iron Ore`.
///
/// Splitting follows Java's `String.split("_")`, which drops trailing empty
/// parts but keeps leading and interior ones: `IRON_` is `Iron`, `_IRON` is
/// ` Iron`, `IRON__ORE` is `Iron  Ore`.
String previewReadable(String value) {
  final List<String> words = _javaSplit(value.toLowerCase(), '_');
  final StringBuffer out = StringBuffer();
  for (int index = 0; index < words.length; index++) {
    if (index > 0) {
      out.write(' ');
    }
    final String word = words[index];
    out.write(word.isEmpty ? word : word[0].toUpperCase() + word.substring(1));
  }
  return out.toString();
}

/// Java `String.split(literal)`: no match returns the whole input, a match
/// drops trailing empty parts.
List<String> _javaSplit(String value, String separator) {
  if (!value.contains(separator)) {
    return <String>[value];
  }
  final List<String> parts = value.split(separator);
  int end = parts.length;
  while (end > 0 && parts[end - 1].isEmpty) {
    end--;
  }
  return parts.sublist(0, end);
}

// ---------------------------------------------------------------------------
// Argument helpers
// ---------------------------------------------------------------------------

double _oneNumArg(String name, List<Object?> args) {
  _requireCount(name, args, 1);
  return _numArg(name, args, 0);
}

void _requireCount(String name, List<Object?> args, int count) {
  if (args.length != count) {
    throw PExprException(
      'Required argument count for {function}: {count}; received: {actual}',
      previewNoPosition,
      <String, Object?>{
        'function': name,
        'count': count,
        'actual': args.length,
      },
    );
  }
}

double _numArg(String name, List<Object?> args, int index) {
  final Object? value = args[index];
  if (value is double) {
    return value;
  }
  throw PExprException(
    '{function} argument {index} must be a number',
    previewNoPosition,
    <String, Object?>{'function': name, 'index': index + 1},
  );
}

String _strArg(String name, List<Object?> args, int index) {
  final Object? value = args[index];
  if (value is String) {
    return value;
  }
  throw PExprException(
    '{function} argument {index} must be a string',
    previewNoPosition,
    <String, Object?>{'function': name, 'index': index + 1},
  );
}

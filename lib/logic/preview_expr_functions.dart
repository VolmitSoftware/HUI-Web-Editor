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
      final double value = _numArg(name, args, 2);
      if (lower == upper) {
        throw const PExprException(
          'smoothstep edges must differ',
          previewNoPosition,
        );
      }
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

/// Index is `(int) floor(index)` — a saturating cast in Java — wrapped into
/// range with `floorMod`.
double _palette(String name, List<Object?> args) {
  _requireCount(name, args, 2);
  final Object? listArg = args[0];
  if (listArg is! List<Object?>) {
    throw PExprException('$name argument 1 must be a list', previewNoPosition);
  }
  if (listArg.isEmpty) {
    throw PExprException('$name list must not be empty', previewNoPosition);
  }
  final double index = _numArg(name, args, 1).floorToDouble();
  final int narrowed = index.isNaN
      ? 0
      : index >= 2147483647.0
      ? 2147483647
      : index <= -2147483648.0
      ? -2147483648
      : index.toInt();
  // Dart's int % is the floor variant, which is Java's floorMod here.
  final Object? item = listArg[narrowed % listArg.length];
  if (item is! double) {
    throw PExprException(
      '$name list entries must be numbers',
      previewNoPosition,
    );
  }
  return item;
}

Object? _select(String name, List<Object?> args) {
  _requireCount(name, args, 2);
  final Object? listArg = args[0];
  if (listArg is! List<Object?>) {
    throw PExprException('$name argument 1 must be a list', previewNoPosition);
  }
  if (listArg.isEmpty) {
    throw PExprException('$name list must not be empty', previewNoPosition);
  }
  final int index = _numArg(name, args, 1).floor();
  return listArg[index % listArg.length];
}

double _number(String name, List<Object?> args) {
  _requireCount(name, args, 1);
  final Object? value = args[0];
  if (value is double) return value;
  if (value is! String) {
    throw PExprException(
      '$name argument 1 must be a number or string',
      previewNoPosition,
    );
  }
  final String plain = value
      .replaceAll(RegExp(r'[&§][0-9A-Fa-fK-Ok-oRr]'), '')
      .replaceAll(',', '');
  final Match? match = RegExp(
    r'[-+]?(?:\d+(?:\.\d*)?|\.\d+)',
  ).firstMatch(plain);
  if (match == null) {
    throw PExprException('$name could not find a number', previewNoPosition);
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
      '$name argument 2 must be greater than zero',
      previewNoPosition,
    );
  }
  if (widthValue != widthValue.roundToDouble() ||
      widthValue < 1 ||
      widthValue > 64) {
    throw PExprException(
      '$name argument 3 must be a whole number in [1, 64]',
      previewNoPosition,
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
      '$name argument 2 (digits) must be a whole number in [0, 20]',
      previewNoPosition,
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
      '$name expects $count argument(s), got ${args.length}',
      previewNoPosition,
    );
  }
}

double _numArg(String name, List<Object?> args, int index) {
  final Object? value = args[index];
  if (value is double) {
    return value;
  }
  throw PExprException(
    '$name argument ${index + 1} must be a number',
    previewNoPosition,
  );
}

String _strArg(String name, List<Object?> args, int index) {
  final Object? value = args[index];
  if (value is String) {
    return value;
  }
  throw PExprException(
    '$name argument ${index + 1} must be a string',
    previewNoPosition,
  );
}

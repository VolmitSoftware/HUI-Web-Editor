import 'package:holoui_editor/logic/preview_expr.dart';
import 'package:holoui_editor/logic/preview_expr_functions.dart';
import 'package:test/test.dart';

/// Targeted cases for what `expr_test_vectors.json` leaves thin: parse-error
/// positions, the depth cap, and the handful of places where a naive Dart port
/// would quietly disagree with Java (`%`, `round`, `Double.toString`, `%f`,
/// colour narrowing). Every expectation here was read off the plugin's own
/// engine, not derived from the Dart implementation.
class MapScope extends PExprScope {
  MapScope([this.vars = const <String, Object?>{}]);

  final Map<String, Object?> vars;

  @override
  Object? variable(String dottedName) => vars[dottedName];

  @override
  Object? call(String name, List<Object?> args) =>
      previewStdFunction(name, args);
}

Object eval(
  String source, [
  Map<String, Object?> vars = const <String, Object?>{},
]) => evalPreviewExpr(parsePreviewExpr(source), MapScope(vars));

double evalNum(String source) => eval(source) as double;

String evalStr(String source) => eval(source) as String;

void expectParseError(String source, String message, int position) {
  expect(
    () => parsePreviewExpr(source),
    throwsA(
      isA<PExprException>()
          .having((PExprException e) => e.message, 'message', message)
          .having((PExprException e) => e.position, 'position', position),
    ),
    reason: source,
  );
}

void expectEvalError(String source, String message) {
  expect(
    () => eval(source),
    throwsA(
      isA<PExprException>()
          .having((PExprException e) => e.message, 'message', message)
          .having(
            (PExprException e) => e.position,
            'position',
            previewNoPosition,
          ),
    ),
    reason: source,
  );
}

void main() {
  group('depth cap', () {
    test('255 nested parens parse', () {
      expect(evalNum('${'(' * 255}1${')' * 255}'), 1.0);
    });

    test('256 nested parens are rejected at the cap, not by the stack', () {
      expectParseError(
        '${'(' * 256}1${')' * 256}',
        'expression too deeply nested',
        256,
      );
    });

    test('5000 nested parens raise PExprException instead of overflowing', () {
      expect(
        () => parsePreviewExpr('${'(' * 5000}1${')' * 5000}'),
        throwsA(isA<PExprException>()),
      );
    });

    test('unary chains share the same cap', () {
      expect(evalNum('${'-' * 255}1'), -1.0);
      expectParseError('${'-' * 256}1', 'expression too deeply nested', 255);
      expect(eval('${'!' * 254}true'), isTrue);
    });
  });

  group('parse errors carry the offending position', () {
    test('call names are never dotted', () {
      expectParseError('a.b(1)', 'call names cannot be dotted', 0);
      // The same name without the call is a perfectly good dotted variable.
      expect(eval('a.b', <String, Object?>{'a.b': 4.0}), 4.0);
      expect(
        eval('surge.active.x', <String, Object?>{'surge.active.x': true}),
        isTrue,
      );
    });

    test('only the four documented escapes are accepted', () {
      expect(evalStr(r"'a\nb'"), 'a\nb');
      expect(evalStr(r"'a\\b'"), r'a\b');
      expect(evalStr(r"'a\'b'"), "a'b");
      expect(evalStr(r'"a\"b"'), 'a"b');
      expectParseError(r"'a\q'", 'unrecognized escape sequence', 2);
      expectParseError(r"'a\t'", 'unrecognized escape sequence', 2);
      expectParseError("'abc", 'unterminated string', 0);
      expectParseError(r"'a\'", 'unterminated string', 0);
    });

    test('every lexer and parser error points at its own token', () {
      expectParseError('   ', 'empty source', 0);
      expectParseError('', 'empty source', 0);
      expectParseError('1 2', 'unexpected token', 2);
      expectParseError('1 +', 'unexpected token', 3);
      expectParseError('+1', 'unexpected token', 0);
      expectParseError("'a' 'b'", 'unexpected token', 4);
      expectParseError('1 == = 2', 'unexpected token', 5);
      expectParseError('true(1)', 'unexpected token', 4);
      expectParseError('(1', 'unclosed paren', 2);
      expectParseError('()', 'unexpected token', 1);
      expectParseError('f(1', 'unclosed paren', 3);
      expectParseError('[1', 'unclosed bracket', 2);
      expectParseError('1 ? 2', "expected ':'", 5);
      expectParseError('=', 'unexpected token', 0);
      expectParseError('&', 'unexpected token', 0);
      expectParseError('|', 'unexpected token', 0);
      expectParseError('@', 'unexpected token', 0);
      expectParseError('#FFFF', 'bad hex length', 0);
      expectParseError('#', 'bad hex length', 0);
      expectParseError('.5', 'unexpected token', 0);
      expectParseError('1..2', 'unexpected token', 1);
      // No exponent or hex literals: `1e5` lexes as `1` then the name `e5`.
      expectParseError('1e5', 'unexpected token', 1);
      expectParseError('0x10', 'unexpected token', 1);
    });

    test('evaluation errors carry no position', () {
      expectEvalError('missing + 1', 'unknown variable: missing');
      expectEvalError('bogus(1)', 'unknown function: bogus');
      expectEvalError("1 == '1'", 'cannot compare number and string');
      expectEvalError('true + 1', 'expected number, got boolean');
      expectEvalError('1 && true', 'expected boolean, got number');
      expectEvalError('1 ? 2 : 3', 'expected boolean, got number');
      expectEvalError('1 / 0', 'division by zero');
      expectEvalError('5 % 0', 'division by zero');
      expectEvalError('mod(1, 0)', 'division by zero');
      expectEvalError('clamp(1, 2)', 'clamp expects 3 argument(s), got 2');
      expectEvalError('palette(1, 2)', 'palette argument 1 must be a list');
      expectEvalError("plain(1)", 'plain argument 1 must be a string');
      expectEvalError("[1] + 1", 'expected number, got list');
    });
  });

  group('lexer literals', () {
    test('colour literals expand to unsigned ARGB', () {
      expect(evalNum('#F00'), 0xFFFF0000.toDouble());
      expect(evalNum('#ABC'), 0xFFAABBCC.toDouble());
      expect(evalNum('#123456'), 0xFF123456.toDouble());
      expect(evalNum('#AABBCCDD'), 0xAABBCCDD.toDouble());
      expect(evalNum('#00000000'), 0.0);
    });

    test('identifiers accept unicode letters and dotted segments', () {
      expect(eval('Ünter', <String, Object?>{'Ünter': 1.0}), 1.0);
      expect(eval('_x1.y_2', <String, Object?>{'_x1.y_2': 2.0}), 2.0);
      expect(evalStr("readable('Ünter_ORE')"), 'Ünter Ore');
    });

    test('numbers are always doubles', () {
      expect(eval('7'), isA<double>());
      expect(eval('7'), 7.0);
      expect(evalNum('007'), 7.0);
    });
  });

  group('evaluator semantics', () {
    test('&& and || short-circuit past a would-be error', () {
      expect(eval('false && (1 / 0 == 0)'), isFalse);
      expect(eval('true || (1 / 0 == 0)'), isTrue);
      expect(
        () => eval('true && (1 / 0 == 0)'),
        throwsA(isA<PExprException>()),
      );
    });

    test('+ concatenates as soon as either side is a string', () {
      expect(evalStr("'x' + 5"), 'x5');
      expect(evalStr("5 + 'x'"), '5x');
      expect(evalStr("'flag:' + true"), 'flag:true');
    });

    test('isConstantExpr is false for anything reaching the scope', () {
      expect(isConstantExpr(parsePreviewExpr('1 + 2 * 3')), isTrue);
      expect(isConstantExpr(parsePreviewExpr("[1, 2, '#F00']")), isTrue);
      expect(isConstantExpr(parsePreviewExpr('true ? 1 : 2')), isTrue);
      expect(isConstantExpr(parsePreviewExpr('-(!true ? 1 : 2)')), isTrue);
      expect(isConstantExpr(parsePreviewExpr('vars.accent')), isFalse);
      expect(isConstantExpr(parsePreviewExpr('rgb(1, 2, 3)')), isFalse);
      expect(isConstantExpr(parsePreviewExpr('[1, i]')), isFalse);
      expect(isConstantExpr(parsePreviewExpr('1 + time')), isFalse);
    });

    test('the typed entry points coerce like the Java ones', () {
      final MapScope scope = MapScope(const <String, Object?>{'lit': true});
      expect(evalNumber(parsePreviewExpr('1 + 1'), scope), 2.0);
      expect(evalBool(parsePreviewExpr('lit'), scope), isTrue);
      expect(evalString(parsePreviewExpr('54.0'), scope), '54');
      expect(evalColor(parsePreviewExpr('#F00'), scope), 0xFFFF0000);
      expect(
        evalColor(parsePreviewExpr('alpha(0 - 1, 128)'), scope),
        0x80FFFFFF,
      );
      expect(
        () => evalNumber(parsePreviewExpr('lit'), scope),
        throwsA(isA<PExprException>()),
      );
    });
  });

  group('Java numeric parity', () {
    test('% truncates toward zero where mod() floors', () {
      expect(evalNum('(0 - 7) % 3'), -1.0);
      expect(evalNum('7 % (0 - 3)'), 1.0);
      expect(evalNum('(0 - 7) % (0 - 3)'), -1.0);
      expect(evalNum('(0 - 7.5) % 2'), -1.5);
      expect(evalNum('mod(-7, 3)'), 2.0);
      expect(evalNum('mod(7, -3)'), -2.0);
      expect(evalNum('mod(-7, -3)'), -1.0);
      expect(evalNum('mod(-7.5, 2)'), 0.5);
    });

    test('round breaks ties toward positive infinity', () {
      expect(evalNum('round(2.5)'), 3.0);
      expect(evalNum('round(-2.5)'), -2.0);
      expect(evalNum('round(1.5)'), 2.0);
      expect(evalNum('round(-1.5)'), -1.0);
      expect(evalNum('round(-0.5)'), 0.0);
      // The double just below one half must not be lifted over it.
      expect(evalNum('round(0.49999999999999994)'), 0.0);
      expect(evalNum('round(0 - 0.0)').isNegative, isFalse);
    });

    test(
      'numbers stringify through the integral rule then Double.toString',
      () {
        expect(evalStr('str(54.0)'), '54');
        expect(evalStr('str(0 - 0.0)'), '0');
        expect(evalStr('str(0.5)'), '0.5');
        expect(evalStr('str(0.001)'), '0.001');
        expect(evalStr('str(9999999.5)'), '9999999.5');
        // Outside [1e-3, 1e7) Java switches to scientific notation.
        expect(evalStr('str(0.0001)'), '1.0E-4');
        expect(evalStr('str(0.00001)'), '1.0E-5');
        expect(evalStr('str(10000000.5)'), '1.00000005E7');
        expect(evalStr('str(123456789.25)'), '1.2345678925E8');
        expect(evalStr("'x' + 0.0001"), 'x1.0E-4');
        expect(evalStr('str(1 / 3)'), '0.3333333333333333');
        expect(evalStr('str(0.1 + 0.2)'), '0.30000000000000004');
        // Integral values render through a saturating (long) cast.
        expect(evalStr('str(9007199254740993)'), '9007199254740992');
        expect(evalStr('str(99999999999999999999)'), '9223372036854775807');
        expect(
          evalStr('str(0 - 99999999999999999999)'),
          '-9223372036854775808',
        );
      },
    );

    test('fixed rounds the shortest decimal half-up, as String.format does', () {
      // 1.005 is really 1.00499999999999989; Java rounds the printed form.
      expect(evalStr('fixed(1.005, 2)'), '1.01');
      expect(evalStr('fixed(2.675, 2)'), '2.68');
      expect(evalStr('fixed(0.125, 2)'), '0.13');
      expect(evalStr('fixed(9.995, 2)'), '10.00');
      expect(evalStr('fixed(99.995, 2)'), '100.00');
      expect(evalStr('fixed(0.999, 2)'), '1.00');
      expect(evalStr('fixed(0.0001, 2)'), '0.00');
      expect(evalStr('fixed(0.005, 2)'), '0.01');
      expect(evalStr('fixed(0.004, 2)'), '0.00');
      expect(evalStr('fixed(0 - 2.5, 0)'), '-3');
      expect(evalStr('fixed(0, 0)'), '0');
      // A negative that rounds to nothing still keeps its sign, and unary minus
      // is the only way to reach a negative zero (`0 - 0.0` is `+0.0`).
      expect(evalStr('fixed(-0.0, 1)'), '-0.0');
      expect(evalStr('fixed(0 - 0.0, 1)'), '0.0');
      expect(evalStr('fixed(-0.4, 0)'), '-0');
      expect(evalStr('fixed(-0.0000001, 2)'), '-0.00');
      // str() runs the integral rule through a long, which has no signed zero.
      expect(evalStr('str(-0.0)'), '0');
      // Past 1e21 Dart's toStringAsFixed gives up and returns "1e+21".
      expect(
        evalStr('fixed(100000000000000000000, 2)'),
        '100000000000000000000.00',
      );
      expect(
        evalStr('fixed(999999999999999999990, 3)'),
        '1000000000000000000000.000',
      );
    });
  });

  group('function library', () {
    test('colour channels survive a negative or oversized input', () {
      expect(evalNum('alpha(0 - 1, 128)'), 0x80FFFFFF.toDouble());
      expect(evalNum('mix(0 - 1, #FFFFFFFF, 0.5)'), 0xFFFFFFFF.toDouble());
      expect(
        evalNum('mix(#FF000000, #FFFFFFFF, 0.333)'),
        0xFF555555.toDouble(),
      );
      expect(evalNum('rgb(0.5, 254.5, 255.5)'), 0xFF01FFFF.toDouble());
      expect(evalNum('argb(127.5, 128.5, 0, 255)'), 0x808100FF.toDouble());
      expect(evalNum('alpha(#FF102030, 255.4)'), 0xFF102030.toDouble());
    });

    test('palette wraps its index through floorMod', () {
      expect(evalNum('palette([1,2,3], -0.5)'), 3.0);
      expect(evalNum('palette([1,2,3], 3.9)'), 1.0);
      expect(evalNum('palette([10,20,30], -4)'), 30.0);
      expectEvalError(
        "palette([1,'x'], 1)",
        'palette list entries must be numbers',
      );
    });

    test('readable follows Java split, dropping only trailing empties', () {
      expect(previewReadable('IRON_ORE'), 'Iron Ore');
      expect(evalStr("readable('_')"), '');
      expect(evalStr("readable('__')"), '');
      expect(evalStr("readable('a_b_')"), 'A B');
      expect(evalStr("readable('_a_')"), ' A');
      expect(evalStr("readable('123_abc')"), '123 Abc');
    });

    test('plain drops only legacy codes', () {
      expect(evalStr(r"plain('&6&lChest')"), 'Chest');
      expect(evalStr(r"plain('&&6x')"), '&x');
      expect(evalStr(r"plain('&z&K&r&O')"), '&z');
      expect(evalStr(r"plain('a&')"), 'a&');
    });

    test('previewStdFunction answers null for a name it does not own', () {
      expect(previewStdFunction('lang', <Object?>['a.key']), isNull);
      expect(previewStdFunction('count', <Object?>[0.0]), isNull);
      expect(previewStdFunction('clamp', <Object?>[15.0, 0.0, 10.0]), 10.0);
    });
  });
}

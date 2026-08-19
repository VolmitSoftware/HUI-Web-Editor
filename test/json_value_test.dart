/// Tolerant single-value JSON parsing for the extras editor.
///
/// Extras are arbitrary unknown keys the plugin ignores and the editor must
/// re-emit byte-stable, so the parser has to accept every JSON value type while
/// still being pleasant to type into: bare text is a string, and nothing is
/// committed that `jsonEncode` cannot write back.
library;

import 'dart:convert';

import 'package:gloss_editor/logic/json_value.dart';
import 'package:test/test.dart';

void main() {
  group('parseJsonValue literals', () {
    test('reads null', () {
      final JsonParseResult result = parseJsonValue('null');
      expect(result.ok, isTrue);
      expect(result.value, isNull);
    });

    test('reads booleans', () {
      expect(parseJsonValue('true').value, isTrue);
      expect(parseJsonValue('false').value, isFalse);
    });

    test('trims surrounding whitespace before reading', () {
      expect(parseJsonValue('  true  ').value, isTrue);
    });

    test('is case sensitive, so True is bare text', () {
      expect(parseJsonValue('True').value, 'True');
    });
  });

  group('parseJsonValue numbers', () {
    test('reads integers as int', () {
      expect(parseJsonValue('42').value, 42);
      expect(parseJsonValue('42').value, isA<int>());
    });

    test('reads negative and signed integers', () {
      expect(parseJsonValue('-7').value, -7);
      expect(parseJsonValue('+7').value, 7);
    });

    test('reads decimals as double', () {
      expect(parseJsonValue('1.5').value, 1.5);
      expect(parseJsonValue('1.5').value, isA<double>());
    });

    test('reads exponent form as double', () {
      expect(parseJsonValue('2e3').value, 2000.0);
      expect(parseJsonValue('2e3').value, isA<double>());
    });

    test('reads a leading-dot decimal', () {
      expect(parseJsonValue('.5').value, 0.5);
    });

    test('hex is text, not a number - JSON has no hex literal', () {
      expect(parseJsonValue('0x10').value, '0x10');
    });

    test('NaN and Infinity are text - jsonEncode cannot write them', () {
      expect(parseJsonValue('NaN').value, 'NaN');
      expect(parseJsonValue('Infinity').value, 'Infinity');
    });

    test(
      'an overflowing exponent stays text rather than becoming Infinity',
      () {
        expect(parseJsonValue('1e999').value, '1e999');
      },
    );
  });

  group('parseJsonValue strings', () {
    test('bare text becomes a string', () {
      expect(parseJsonValue('hello world').value, 'hello world');
    });

    test('bare text is trimmed', () {
      expect(parseJsonValue('   spaced   ').value, 'spaced');
    });

    test('empty input is the empty string', () {
      expect(parseJsonValue('').ok, isTrue);
      expect(parseJsonValue('').value, '');
      expect(parseJsonValue('   ').value, '');
    });

    test('a quoted string is decoded, so escapes and literals survive', () {
      expect(parseJsonValue('"true"').value, 'true');
      expect(parseJsonValue('"42"').value, '42');
      expect(parseJsonValue(r'"a\nb"').value, 'a\nb');
      expect(parseJsonValue('"  padded  "').value, '  padded  ');
    });

    test('an unterminated quoted string is an error, never bare text', () {
      final JsonParseResult result = parseJsonValue('"oops');
      expect(result.ok, isFalse);
      expect(result.error, isNotNull);
      expect(result.value, isNull);
    });
  });

  group('parseJsonValue containers', () {
    test('reads an object', () {
      final JsonParseResult result = parseJsonValue('{"a": 1, "b": [true]}');
      expect(result.ok, isTrue);
      expect(result.value, <String, Object?>{
        'a': 1,
        'b': <Object?>[true],
      });
    });

    test('reads an array', () {
      expect(parseJsonValue('[1, "two", null]').value, <Object?>[
        1,
        'two',
        null,
      ]);
    });

    test('a broken object is an error, not bare text', () {
      final JsonParseResult result = parseJsonValue('{oops');
      expect(result.ok, isFalse);
      expect(result.error, isNotNull);
    });

    test('a broken array is an error, not bare text', () {
      expect(parseJsonValue('[1, 2').ok, isFalse);
    });

    test('trailing junk after a container is an error', () {
      expect(parseJsonValue('[1, 2] and more').ok, isFalse);
    });
  });

  group('formatJsonValue', () {
    test('writes literals', () {
      expect(formatJsonValue(null), 'null');
      expect(formatJsonValue(true), 'true');
      expect(formatJsonValue(false), 'false');
    });

    test('writes numbers', () {
      expect(formatJsonValue(42), '42');
      expect(formatJsonValue(-1.25), '-1.25');
    });

    test('writes plain text bare, so the field is not full of quotes', () {
      expect(formatJsonValue('hello world'), 'hello world');
    });

    test('quotes text that would otherwise read back as something else', () {
      expect(formatJsonValue('true'), '"true"');
      expect(formatJsonValue('null'), '"null"');
      expect(formatJsonValue('42'), '"42"');
      expect(formatJsonValue(''), '""');
      expect(formatJsonValue('  padded  '), '"  padded  "');
      expect(formatJsonValue('{not an object'), '"{not an object"');
      expect(formatJsonValue('[not an array'), '"[not an array"');
      expect(formatJsonValue('"quoted"'), r'"\"quoted\""');
      expect(formatJsonValue('two\nlines'), r'"two\nlines"');
    });

    test('writes containers as compact JSON', () {
      expect(formatJsonValue(<String, Object?>{'a': 1}), '{"a":1}');
      expect(formatJsonValue(<Object?>[1, 'two']), '[1,"two"]');
    });
  });

  group('round trip', () {
    final List<Object?> values = <Object?>[
      null,
      true,
      false,
      0,
      42,
      -7,
      1.5,
      -0.25,
      '',
      'hello world',
      'true',
      'null',
      '42',
      '0x10',
      '  padded  ',
      'two\nlines',
      '"quoted"',
      '{not an object',
      'ends with a dot.',
      '%player_name%',
      <String, Object?>{
        'a': 1,
        'b': <Object?>[true, null],
      },
      <Object?>[1, 'two', 3.5],
    ];

    test('format then parse returns the original value', () {
      for (final Object? value in values) {
        final JsonParseResult result = parseJsonValue(formatJsonValue(value));
        expect(result.ok, isTrue, reason: '$value');
        expect(result.value, value, reason: '$value');
      }
    });

    test('every formatted value is encodable, so export can never fail', () {
      for (final Object? value in values) {
        expect(
          () => jsonEncode(parseJsonValue(formatJsonValue(value)).value),
          returnsNormally,
          reason: '$value',
        );
      }
    });
  });
}

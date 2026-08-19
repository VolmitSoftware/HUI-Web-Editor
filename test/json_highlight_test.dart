import 'dart:convert';

import 'package:gloss_editor/components/code_editor/json_highlight.dart';
import 'package:test/test.dart';

String _joined(List<JsonToken> tokens) =>
    tokens.map((JsonToken token) => token.text).join();

List<JsonToken> _significant(List<JsonToken> tokens) => tokens
    .where((JsonToken token) => token.kind != JsonTokenKind.plain)
    .toList();

void main() {
  group('tokenizeJson', () {
    test('preserves the source exactly when reassembled', () {
      const String source =
          '{\n  "id": "shop",\n  "count": -12.5e3,\n'
          '  "on": true,\n  "off": null,\n  "list": [1, 2]\n}';
      expect(_joined(tokenizeJson(source)), source);
    });

    test('preserves an empty source as no tokens', () {
      expect(tokenizeJson(''), isEmpty);
    });

    test('marks a string followed by a colon as a key', () {
      final List<JsonToken> tokens = _significant(tokenizeJson('{"a": "b"}'));
      expect(tokens[1].kind, JsonTokenKind.key);
      expect(tokens[1].text, '"a"');
      expect(tokens[3].kind, JsonTokenKind.string);
      expect(tokens[3].text, '"b"');
    });

    test('treats a key with whitespace before the colon as a key', () {
      final List<JsonToken> tokens = _significant(tokenizeJson('{"a"\n : 1}'));
      expect(tokens[1].kind, JsonTokenKind.key);
    });

    test('keeps an escaped quote inside the string token', () {
      final List<JsonToken> tokens = _significant(
        tokenizeJson(r'{"a": "say \"hi\" now"}'),
      );
      expect(tokens[3].kind, JsonTokenKind.string);
      expect(tokens[3].text, r'"say \"hi\" now"');
    });

    test('does not run an unterminated string past the end of its line', () {
      const String source = '{"a": "oops\n"b": 1}';
      final List<JsonToken> tokens = tokenizeJson(source);
      expect(_joined(tokens), source);
      final JsonToken broken = _significant(tokens)[3];
      expect(broken.text, '"oops');
    });

    test('scans signed, fractional and exponent numbers as one token', () {
      for (final String number in <String>[
        '0',
        '-4',
        '12.5',
        '-0.25',
        '1e10',
        '2E-3',
        '-6.02e+23',
      ]) {
        final List<JsonToken> tokens = _significant(
          tokenizeJson('{"n": $number}'),
        );
        expect(tokens[3].kind, JsonTokenKind.number, reason: number);
        expect(tokens[3].text, number, reason: number);
      }
    });

    test('stops a number before a trailing dot with no digits', () {
      final List<JsonToken> tokens = _significant(tokenizeJson('[1.]'));
      expect(tokens[1].kind, JsonTokenKind.number);
      expect(tokens[1].text, '1');
    });

    test('marks true, false and null as literals', () {
      for (final String literal in <String>['true', 'false', 'null']) {
        final List<JsonToken> tokens = _significant(
          tokenizeJson('{"v": $literal}'),
        );
        expect(tokens[3].kind, JsonTokenKind.literal, reason: literal);
        expect(tokens[3].text, literal, reason: literal);
      }
    });

    test('leaves a word that only starts like a literal as plain text', () {
      final List<JsonToken> tokens = tokenizeJson('nullish');
      expect(_joined(tokens), 'nullish');
      expect(_significant(tokens), isEmpty);
    });

    test('emits every structural character as punctuation', () {
      final List<JsonToken> tokens = _significant(
        tokenizeJson('{"a":[1],"b":{}}'),
      );
      final List<String> punctuation = tokens
          .where((JsonToken token) => token.kind == JsonTokenKind.punctuation)
          .map((JsonToken token) => token.text)
          .toList();
      expect(punctuation, <String>[
        '{',
        ':',
        '[',
        ']',
        ',',
        ':',
        '{',
        '}',
        '}',
      ]);
    });

    test(
      'round-trips a pretty-printed HoloUI menu without losing a character',
      () {
        final String source = const JsonEncoder.withIndent('  ').convert(
          <String, Object?>{
            'offset': <double>[0, 1.7, 2.5],
            'followPlayer': true,
            'maxDistance': null,
            'components': <Object?>[
              <String, Object?>{
                'id': 'button-1',
                'offset': <double>[0, 0.85, 0],
                'type': 'button',
                'highlightModifier': 0.05,
                'icon': <String, Object?>{'type': 'text', 'text': '&6&lShop'},
              },
            ],
          },
        );
        expect(_joined(tokenizeJson(source)), source);
      },
    );
  });
}

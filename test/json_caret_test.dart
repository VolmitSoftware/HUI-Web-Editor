/// Where the caret is, in JSON-path terms, in a buffer that may not parse.
///
/// Every case here is written with `|` marking the caret and stripped before
/// the call, so the fixture reads like the thing the user is looking at.
library;

import 'package:gloss_editor/components/code_editor/json_caret.dart';
import 'package:gloss_editor/logic/json_schema.dart';
import 'package:test/test.dart';

/// Runs [jsonCaretContext] on [marked] with `|` removed and its index used as
/// the caret.
JsonCaretContext _at(String marked) {
  final int caret = marked.indexOf('|');
  expect(caret, isNot(-1), reason: 'the fixture needs a | caret');
  return jsonCaretContext(marked.replaceFirst('|', ''), caret);
}

List<String> _keys(List<JsonPathStep> path) =>
    <String>[for (final JsonPathStep step in path) step.toString()];

void main() {
  group('slots', () {
    test('an empty object body is a key slot', () {
      final JsonCaretContext context = _at('{\n  |\n}');
      expect(context.slot, JsonCaretSlot.key);
      expect(context.prefix, isEmpty);
      expect(context.needsColon, isTrue);
      expect(context.commaInsertAt, isNull);
    });

    test('a half-typed key is a key slot carrying its prefix', () {
      final JsonCaretContext context = _at('{\n  "see|\n}');
      expect(context.slot, JsonCaretSlot.key);
      expect(context.prefix, 'see');
      expect(context.quoted, isTrue);
    });

    test('the caret inside a finished key filters on what precedes it', () {
      final JsonCaretContext context = _at('{\n  "see|Through": true\n}');
      expect(context.slot, JsonCaretSlot.key);
      expect(context.prefix, 'see');
      expect(context.needsColon, isFalse);
    });

    test('a quoted value is replaced whole, colons and all', () {
      const String source = '{"item": "minecraft:stone"}';
      final JsonCaretContext context = jsonCaretContext(
        source,
        source.indexOf('stone') + 3,
      );
      expect(context.prefix, 'minecraft:sto');
      expect(
        source.substring(context.replaceStart, context.replaceEnd),
        '"minecraft:stone"',
      );
    });

    test('after a colon is a value slot naming its key', () {
      final JsonCaretContext context = _at('{"mode": |}');
      expect(context.slot, JsonCaretSlot.value);
      expect(context.valueKey, 'mode');
      expect(context.prefix, isEmpty);
    });

    test('a half-typed string value carries its prefix without quotes', () {
      final JsonCaretContext context = _at('{"mode": "asc|"}');
      expect(context.slot, JsonCaretSlot.value);
      expect(context.valueKey, 'mode');
      expect(context.prefix, 'asc');
      expect(context.quoted, isTrue);
    });

    test('an unterminated string value still resolves', () {
      final JsonCaretContext context = _at('{\n  "mode": "asc|\n}');
      expect(context.slot, JsonCaretSlot.value);
      expect(context.valueKey, 'mode');
      expect(context.prefix, 'asc');
    });

    test('inside a list is a value slot with no key', () {
      final JsonCaretContext context = _at('{"lines": [|]}');
      expect(context.slot, JsonCaretSlot.value);
      expect(context.valueKey, isNull);
      expect(context.containerIsObject, isFalse);
      expect(_keys(context.containerPath), <String>['.lines']);
    });

    test('outside the document root is nothing at all', () {
      expect(_at('|').slot, JsonCaretSlot.none);
      expect(_at('  |{}').slot, JsonCaretSlot.none);
    });

    test('a list that already holds a value is nothing at all', () {
      expect(_at('{"lines": ["a"|]}').slot, JsonCaretSlot.none);
    });

    test('an empty quoted value is still a value slot', () {
      final JsonCaretContext context = _at('{"mode": "|"}');
      expect(context.slot, JsonCaretSlot.value);
      expect(context.valueKey, 'mode');
      expect(context.quoted, isTrue);
      expect(context.prefix, isEmpty);
    });

    test('the caret just past a finished key offers nothing', () {
      expect(_at('{"a"|: 1}').slot, JsonCaretSlot.none);
    });
  });

  group('paths', () {
    const String menu =
        '{\n'
        '  "components": [\n'
        '    {\n'
        '      "id": "shop",\n'
        '      "data": {\n'
        '        "type": "button",\n'
        '        "icon": {\n'
        '          "type": "item",\n'
        '          "style": {\n'
        '            "billboard": "@"\n'
        '          }\n'
        '        }\n'
        '      }\n'
        '    }\n'
        '  ]\n'
        '}';

    test('reads the container path through a list and two objects', () {
      final JsonCaretContext context = _at(menu.replaceFirst('"@"', '|'));
      expect(context.slot, JsonCaretSlot.value);
      expect(context.valueKey, 'billboard');
      expect(_keys(context.containerPath), <String>[
        '.components',
        '[0]',
        '.data',
        '.icon',
        '.style',
      ]);
    });

    test('each step carries the type tag of the object it belongs to', () {
      final JsonCaretContext context = _at(menu.replaceFirst('"@"', '|'));
      final List<JsonPathStep> path = context.containerPath;
      expect(path[3].key, 'icon');
      expect(path[3].ownerType, 'button');
      expect(path[4].key, 'style');
      expect(path[4].ownerType, 'item');
    });

    test('picks up a type written after the caret', () {
      final JsonCaretContext context = _at(
        '{"data": {"icon": {|}, "type": "toggle"}}',
      );
      expect(_keys(context.containerPath), <String>['.data', '.icon']);
      expect(context.containerPath.last.ownerType, 'toggle');
    });

    test('names the key under the caret, not one written after it', () {
      // The scan that looks past the caret for a `type` walks the same frames
      // forward; the key being given a value has to be read before it does.
      final JsonCaretContext context = _at('{"mode": "|", "frames": ["a"]}');
      expect(context.slot, JsonCaretSlot.value);
      expect(context.valueKey, 'mode');
    });

    test('the container object reports its own type tag', () {
      final JsonCaretContext context = _at('{"type": "button", "hi|"}');
      expect(context.containerType, 'button');
    });
  });

  group('insertion hints', () {
    test('a key with a colon after it does not need another', () {
      expect(_at('{"a|": 1}').needsColon, isFalse);
      expect(_at('{"a|" : 1}').needsColon, isFalse);
    });

    test('a key after a finished member asks for a separating comma', () {
      final JsonCaretContext context = _at('{\n  "a": 1\n  |\n}');
      expect(context.slot, JsonCaretSlot.key);
      expect(context.commaInsertAt, isNotNull);
      expect(context.commaInsertAt, '{\n  "a": 1'.length);
    });

    test('a key after a comma asks for nothing', () {
      expect(_at('{\n  "a": 1,\n  |\n}').commaInsertAt, isNull);
    });

    test('a comma is asked for after a nested object closes too', () {
      final JsonCaretContext context = _at('{\n  "a": {"b": 1}\n  |\n}');
      expect(context.commaInsertAt, '{\n  "a": {"b": 1}'.length);
    });

    test('sibling keys are reported, including the ones after the caret', () {
      final JsonCaretContext context = _at('{"a": 1, |, "b": 2}');
      expect(context.siblingKeys, containsAll(<String>['a', 'b']));
    });

    test('the replace range covers the quotes when there are quotes', () {
      const String source = '{"mode": "asc"}';
      final JsonCaretContext context = jsonCaretContext(
        source,
        source.indexOf('asc') + 3,
      );
      expect(source.substring(context.replaceStart, context.replaceEnd), '"asc"');
    });
  });

  group('key hits', () {
    const String source = '{"a": 1, "b": {"c": 2}}';

    test('finds the key the offset falls inside', () {
      final JsonKeyHit? hit = jsonKeyAt(source, source.indexOf('"c"') + 1);
      expect(hit, isNotNull);
      expect(hit!.key, 'c');
      expect(_keys(hit.path), <String>['.b', '.c']);
      expect(source.substring(hit.start, hit.end), '"c"');
    });

    test('counts the opening quote as part of the key', () {
      final JsonKeyHit? hit = jsonKeyAt(source, source.indexOf('"a"'));
      expect(hit?.key, 'a');
    });

    test('a value string is not a key', () {
      expect(jsonKeyAt('{"a": "b"}', 7), isNull);
    });

    test('whitespace is not a key', () {
      expect(jsonKeyAt(source, 7), isNull);
    });

    test('lists every key span in document order', () {
      expect(jsonKeySpans(source), hasLength(3));
      expect(
        jsonKeySpans(source).first.start,
        source.indexOf('"a"'),
      );
    });
  });

  group('word scanning', () {
    test('reads a bare word and its span', () {
      final ({int start, int end, bool quoted, String text}) word = jsonWordAt(
        '{"a": tru}',
        9,
      );
      expect(word.text, 'tru');
      expect(word.quoted, isFalse);
      expect(word.start, 6);
      expect(word.end, 9);
    });

    test('an empty slot is a zero-width span', () {
      final ({int start, int end, bool quoted, String text}) word = jsonWordAt(
        '{"a": }',
        6,
      );
      expect(word.text, isEmpty);
      expect(word.start, word.end);
    });
  });
}

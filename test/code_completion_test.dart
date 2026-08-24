/// What Ctrl+Space offers, and what accepting it writes.
///
/// Every case runs the real pipeline — caret analysis over a marked buffer,
/// then the kind's shipped JSON-path model — so a change to either shows up
/// here rather than in a user's editor.
library;

import 'package:gloss_editor/components/code_editor/code_completion.dart';
import 'package:gloss_editor/components/code_editor/json_caret.dart';
import 'package:gloss_editor/config/gloss_json_schema.dart';
import 'package:gloss_editor/logic/json_schema.dart';
import 'package:test/test.dart';

/// `|` marks the caret and is stripped before anything runs.
({String source, JsonCaretContext caret}) _caret(String marked) {
  final int at = marked.indexOf('|');
  expect(at, isNot(-1), reason: 'the fixture needs a | caret');
  final String source = marked.replaceFirst('|', '');
  return (source: source, caret: jsonCaretContext(source, at));
}

List<HuiCompletion> _offer(String kind, String marked) {
  final GlossJsonObject root = glossJsonSchemaFor(kind)!;
  return huiCodeCompletions(root: root, caret: _caret(marked).caret);
}

List<String> _labels(List<HuiCompletion> items) =>
    <String>[for (final HuiCompletion item in items) item.label];

/// Accepts the candidate labelled [label] and returns the whole next buffer
/// with `|` put back where the caret ended up.
String _accept(String kind, String marked, String label) {
  final ({String source, JsonCaretContext caret}) at = _caret(marked);
  final GlossJsonObject root = glossJsonSchemaFor(kind)!;
  final List<HuiCompletion> items = huiCodeCompletions(
    root: root,
    caret: at.caret,
  );
  final HuiCompletion item = items.firstWhere(
    (HuiCompletion candidate) => candidate.label == label,
    orElse: () => throw StateError('no candidate "$label" in ${_labels(items)}'),
  );
  final HuiCompletionEdit edit = huiApplyCompletion(at.source, at.caret, item);
  return edit.text.replaceRange(edit.caret, edit.caret, '|');
}

void main() {
  group('key candidates', () {
    test('offers the root keys of the open kind', () {
      expect(
        _labels(_offer('hologram', '{\n  |\n}')),
        <String>['schemaVersion', 'revision', 'anchor', 'lines', 'seeThrough'],
      );
    });

    test('filters on what precedes the caret, in declaration order', () {
      final List<String> labels = _labels(
        _offer('animation', '{\n  "fram|\n}'),
      );
      expect(labels, <String>['frameIntervalMs', 'frames']);
    });

    test('ranks a substring match behind every prefix match', () {
      final List<String> labels = _labels(
        _offer('bubbleStyle', '{\n  "wrap|\n}'),
      );
      expect(labels, <String>['wordWrapChars']);
    });

    test('drops the keys the object already carries', () {
      final List<String> labels = _labels(
        _offer('emoji', '{"schemaVersion": 1, "emoji": "x", |}'),
      );
      expect(labels, isNot(contains('emoji')));
      expect(labels, isNot(contains('schemaVersion')));
      expect(labels, contains('trigger'));
    });

    test('still offers the key the caret is editing', () {
      expect(
        _labels(_offer('hologram', '{"see|Through": true}')),
        contains('seeThrough'),
      );
    });

    test('never offers a key the format only reads for migration', () {
      final List<String> labels = _labels(
        _offer('menu', '{"components": [{"data": {"type": "decoration", '
            '"icon": {"type": "item", |}}}]}'),
      );
      expect(labels, contains('customModelValue'));
      expect(labels, isNot(contains('customModelData')));
    });

    test('offers the variant keys the enclosing type names', () {
      final List<String> button = _labels(
        _offer('menu', '{"components": [{"data": {"type": "button", |}}]}'),
      );
      expect(button, containsAll(<String>['actions', 'icon', 'hitbox']));
      expect(button, isNot(contains('trueIcon')));

      final List<String> toggle = _labels(
        _offer('menu', '{"components": [{"data": {"type": "toggle", |}}]}'),
      );
      expect(toggle, containsAll(<String>['trueIcon', 'falseActions']));
      expect(toggle, isNot(contains('actions')));
    });

    test('offers the shared keys when the type is not written yet', () {
      final List<String> labels = _labels(
        _offer('menu', '{"components": [{"data": {|}}]}'),
      );
      expect(labels, <String>['type']);
    });

    test('offers the reserved keys of an open map', () {
      final List<String> labels = _labels(
        _offer('tablist', '{"nameFormats": {|}}'),
      );
      expect(labels, <String>['default', '_op']);
    });

    test('offers damage-indicator trajectory and presentation keys', () {
      expect(
        _labels(_offer('damageIndicators', '{"damage":{"motion":{|}}}')),
        <String>[
          'horizontalSpeed',
          'verticalSpeed',
          'verticalAcceleration',
          'spinDegreesPerSecond',
        ],
      );
      expect(
        _labels(_offer('damageIndicators', '{"healing":{"presentation":{|}}}')),
        <String>['startScale', 'endScale', 'fadeStartFraction'],
      );
    });

    test('carries the type and the summary of every key it offers', () {
      final HuiCompletion item = _offer(
        'hologram',
        '{"seeThrough|"}',
      ).first;
      expect(item.detail, 'boolean');
      expect(item.description, isNotEmpty);
      expect(item.kind, HuiCompletionKind.key);
    });
  });

  group('value candidates', () {
    test('offers the enum a field accepts, marking the default', () {
      final List<HuiCompletion> items = _offer('animation', '{"mode": |}');
      expect(_labels(items), <String>[
        'ascend',
        'descend',
        'ascend_descend',
        'random',
      ]);
      expect(items.first.isDefault, isTrue);
      expect(items.first.detail, 'default');
      expect(items[1].detail, 'string');
    });

    test('offers both booleans, marking the default', () {
      final List<HuiCompletion> items = _offer(
        'hologram',
        '{"seeThrough": |}',
      );
      expect(_labels(items), <String>['true', 'false']);
      expect(items.first.isDefault, isTrue);
    });

    test('offers the default alone when the field has no closed set', () {
      final List<HuiCompletion> items = _offer(
        'animation',
        '{"frameIntervalMs": |}',
      );
      expect(_labels(items), <String>['500']);
      expect(items.single.isDefault, isTrue);
    });

    test('offers nothing for a field with no set and no default', () {
      expect(_offer('menu', '{"maxDistance": |}'), isEmpty);
    });

    test('filters the enum as the value is typed', () {
      expect(
        _labels(_offer('animation', '{"mode": "desc|"}')),
        <String>['descend', 'ascend_descend'],
      );
    });

    test('offers the tags of a nested union whose object has more keys', () {
      expect(
        _labels(
          _offer(
            'menu',
            '{"components": [{"data": {"type": "decoration", "icon": '
                '{"type": "te|", "text": "hi"}}}]}',
          ),
        ),
        <String>[
          'text',
          'textImage',
          'animatedTextImage',
          'item',
          'customItem',
        ],
      );
    });

    test('offers the variant tags of a discriminated object', () {
      expect(
        _labels(_offer('menu', '{"components": [{"data": {"type": |}}]}')),
        <String>['button', 'decoration', 'toggle'],
      );
    });

    test('resolves a value five levels down, through two variants', () {
      expect(
        _labels(
          _offer(
            'menu',
            '{"components": [{"data": {"type": "toggle", "trueIcon": '
                '{"type": "text", "style": {"textAlignment": |}}}}]}',
          ),
        ),
        <String>['center', 'left', 'right'],
      );
    });
  });

  group('accepting', () {
    test('writes a key, its colon and the field default', () {
      expect(
        _accept('hologram', '{\n  |\n}', 'seeThrough'),
        '{\n  "seeThrough": true|\n}',
      );
    });

    test('parks the caret inside an empty literal it had to invent', () {
      expect(
        _accept('hologram', '{\n  |\n}', 'lines'),
        '{\n  "lines": [|]\n}',
      );
      expect(
        _accept('emoji', '{\n  |\n}', 'emoji'),
        '{\n  "emoji": "|"\n}',
      );
    });

    test('writes only the key when a colon already follows', () {
      expect(
        _accept('hologram', '{\n  "see|": true\n}', 'seeThrough'),
        '{\n  "seeThrough"|: true\n}',
      );
    });

    test('splices the separating comma onto the previous member', () {
      expect(
        _accept('hologram', '{\n  "revision": 1\n  |\n}', 'seeThrough'),
        '{\n  "revision": 1,\n  "seeThrough": true|\n}',
      );
    });

    test('replaces a quoted value including its quotes', () {
      expect(
        _accept('animation', '{"mode": "asc|"}', 'ascend_descend'),
        '{"mode": "ascend_descend"|}',
      );
    });

    test('closes a value string the user had left open', () {
      expect(
        _accept('animation', '{\n  "mode": "asc|\n}', 'ascend'),
        '{\n  "mode": "ascend"|\n}',
      );
    });

    test('writes a bare literal without inventing quotes', () {
      expect(
        _accept('hologram', '{"seeThrough": |}', 'false'),
        '{"seeThrough": false|}',
      );
    });
  });

  group('nothing to offer', () {
    test('a slot outside the document root has no candidates', () {
      final GlossJsonObject root = glossJsonSchemaFor('menu')!;
      expect(
        huiCodeCompletions(root: root, caret: JsonCaretContext.none),
        isEmpty,
      );
    });

    test('a key the model does not know has no value candidates', () {
      expect(_offer('hologram', '{"whatever": |}'), isEmpty);
    });
  });
}

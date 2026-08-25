import 'dart:convert';

import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

const String _board = r'''
{
  "schemaVersion": 2,
  "revision": 7,
  "select": {"priority": 20, "when": "viewer.health < 5"},
  "presentation": {
    "title": "&d&lGloss",
    "lines": ["one", "two"],
    "hideNumbers": true
  },
  "variants": [
    {
      "id": "critical",
      "priority": 100,
      "when": "viewer.healthPercent <= 25",
      "presentation": {
        "title": "&cLOW HEALTH",
        "lines": ["safe"],
        "hideNumbers": true
      }
    }
  ]
}
''';

void main() {
  test('decodes the schema 2 selection, presentation and variants', () {
    final GlossScoreboardDoc doc = decodeGlossScoreboardDoc(_board);
    expect(doc.schemaVersion, glossScoreboardCurrentSchemaVersion);
    expect(doc.revision, 7);
    expect(doc.select.priority, 20);
    expect(doc.select.when, 'viewer.health < 5');
    expect(doc.presentation.title, '&d&lGloss');
    expect(doc.presentation.lines, <String>['one', 'two']);
    expect(doc.presentation.hideNumbers, isTrue);
    expect(doc.variants.single.id, 'critical');
    expect(doc.variants.single.presentation.title, '&cLOW HEALTH');
  });

  test('rejects unsupported and missing schema versions', () {
    expect(
      () => decodeGlossScoreboardDoc(
        '{"schemaVersion":1,"title":"old","lines":[]}',
      ),
      throwsA(isA<HuiFormatException>()),
    );
    expect(
      () => decodeGlossScoreboardDoc('{"presentation":{},"variants":[]}'),
      throwsA(isA<HuiFormatException>()),
    );
  });

  test('round-trip is stable, canonical and preserves unknown keys', () {
    final GlossScoreboardDoc doc = decodeGlossScoreboardDoc(_board);
    doc.extras['future'] = <String, Object?>{'enabled': true};
    final String encoded = encodeGlossScoreboardDoc(doc);
    expect(
      encodeGlossScoreboardDoc(decodeGlossScoreboardDoc(encoded)),
      encoded,
    );
    final Map<String, dynamic> json =
        jsonDecode(encoded) as Map<String, dynamic>;
    expect(json.keys, <String>[
      'schemaVersion',
      'revision',
      'select',
      'presentation',
      'variants',
      'future',
    ]);
    expect(json, isNot(contains('title')));
    expect(json, isNot(contains('primary')));
    expect(json, isNot(contains('permission')));
  });

  test('copy is deep', () {
    final GlossScoreboardDoc doc = decodeGlossScoreboardDoc(_board);
    final GlossScoreboardDoc copied = doc.copy();
    copied.presentation.lines.add('extra');
    copied.variants.single.presentation.title = 'other';
    expect(doc.presentation.lines, hasLength(2));
    expect(doc.variants.single.presentation.title, '&cLOW HEALTH');
  });

  test('shape routing claims only canonical scoreboard documents', () {
    expect(looksLikeScoreboardDoc(jsonDecode(_board)), isTrue);
    expect(
      looksLikeScoreboardDoc(<String, Object?>{
        'schemaVersion': 2,
        'title': 'old',
        'lines': <String>[],
      }),
      isFalse,
    );
  });
}

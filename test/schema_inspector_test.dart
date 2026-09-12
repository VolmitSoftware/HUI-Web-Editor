import 'dart:convert';

import 'package:gloss_editor/logic/schema_inspector.dart';
import 'package:test/test.dart';

/// The generic inspector reads a served JSON Schema rather than a hand-written
/// field table, which is what lets a kind this build has no stage for still be
/// edited field by field instead of only as raw text.
void main() {
  test('object properties become fields in declaration order', () {
    final SchemaForm form = SchemaForm.of(_schema);

    expect(
      form.fields.map((SchemaField field) => field.pointer),
      <String>['/title', '/lines', '/interval', '/enabled', '/mode', '/layout'],
    );
    expect(form.fields.first.control, SchemaControl.text);
    expect(form.fields.first.label, 'Title');
    expect(form.fields.first.help, 'Shown at the top of the board.');
  });

  test('numbers carry their bounds and booleans carry no bounds', () {
    final SchemaForm form = SchemaForm.of(_schema);

    final SchemaField interval = form.field('/interval')!;
    expect(interval.control, SchemaControl.integer);
    expect(interval.minimum, 1);
    expect(interval.maximum, 600);
    expect(form.field('/enabled')!.control, SchemaControl.checkbox);
    expect(form.field('/enabled')!.minimum, isNull);
  });

  test('an enum becomes a choice with its literal values', () {
    final SchemaField mode = SchemaForm.of(_schema).field('/mode')!;

    expect(mode.control, SchemaControl.choice);
    expect(mode.choices, <String>['ascend', 'descend', 'random']);
  });

  test('an array of primitives is a list and an array of objects repeats', () {
    final SchemaForm form = SchemaForm.of(_schema);

    expect(form.field('/lines')!.control, SchemaControl.textList);
    final SchemaField layout = form.field('/layout')!;
    expect(layout.control, SchemaControl.objectList);
    expect(
      layout.fields.map((SchemaField field) => field.pointer),
      <String>['/layout/-/id', '/layout/-/weight'],
    );
  });

  test('a \$ref resolves through \$defs', () {
    final SchemaField weight = SchemaForm.of(_schema).field('/layout')!.fields
        .last;

    expect(weight.control, SchemaControl.number);
    expect(weight.help, 'Relative share of the row.');
  });

  test('a nested object becomes a group with its own fields', () {
    final SchemaForm form = SchemaForm.of(
      jsonDecode('''
      {"type":"object","properties":{
        "select":{"type":"object","description":"When this document applies.",
          "properties":{"priority":{"type":"integer"},"when":{"type":"string"}}}}}
      '''),
    );

    final SchemaField select = form.field('/select')!;
    expect(select.control, SchemaControl.group);
    expect(
      select.fields.map((SchemaField field) => field.pointer),
      <String>['/select/priority', '/select/when'],
    );
  });

  test('a schema that is not an object yields no fields', () {
    expect(SchemaForm.of(jsonDecode('[]')).fields, isEmpty);
    expect(SchemaForm.of(null).fields, isEmpty);
  });

  test('required keys are marked and the rest are not', () {
    final SchemaForm form = SchemaForm.of(_schema);

    expect(form.field('/title')!.required, isTrue);
    expect(form.field('/interval')!.required, isFalse);
  });
}

final Object? _schema = jsonDecode('''
{
  "\$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["title", "lines"],
  "properties": {
    "title": {"type": "string", "description": "Shown at the top of the board."},
    "lines": {"type": "array", "items": {"type": "string"}},
    "interval": {"type": "integer", "minimum": 1, "maximum": 600},
    "enabled": {"type": "boolean"},
    "mode": {"enum": ["ascend", "descend", "random"]},
    "layout": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {"type": "string"},
          "weight": {"\$ref": "#/\$defs/weight"}
        }
      }
    }
  },
  "\$defs": {
    "weight": {"type": "number", "description": "Relative share of the row."}
  }
}
''');

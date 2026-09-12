/// Field descriptors read straight out of a served JSON Schema.
///
/// A document kind this build has no stage for still arrives with the schema
/// the plugin ships for it, in the sync project's `schemas` section. Walking
/// that schema gives an inspector its rows without anyone hand-writing a field
/// table per kind, which is the whole point: a kind a newer server adds is
/// editable field by field here on the day it lands, not the release after.
///
/// What is read, and nothing else: `properties` in declaration order, `type`,
/// `enum`, `minimum`/`maximum`, `items`, `description`, `required`, and `$ref`
/// into `$defs`. Composition keywords the Gloss schemas do not use (`oneOf`,
/// `patternProperties`, remote `$ref`) resolve to a text field rather than to
/// nothing, so an unreadable corner degrades to raw text instead of vanishing.
library;

/// Which control an inspector row draws for one schema field.
enum SchemaControl {
  text,
  multilineText,
  number,
  integer,
  checkbox,
  choice,
  textList,
  objectList,
  group,
}

/// One editable slot: where it lives in the document, how it is drawn, and
/// whatever the schema said about it.
final class SchemaField {
  const SchemaField({
    required this.pointer,
    required this.name,
    required this.label,
    required this.control,
    this.help = '',
    this.required = false,
    this.minimum,
    this.maximum,
    this.choices = const <String>[],
    this.fields = const <SchemaField>[],
  });

  /// JSON pointer into the document. A repeatable card's children point
  /// through `-`, the pointer token for "any element".
  final String pointer;

  /// The property name as the format spells it.
  final String name;

  /// The property name as a person reads it.
  final String label;

  final SchemaControl control;

  /// The schema's `description`, or empty when it carries none.
  final String help;

  final bool required;
  final num? minimum;
  final num? maximum;

  /// The literal values an enum accepts.
  final List<String> choices;

  /// Children of a [SchemaControl.group] or [SchemaControl.objectList].
  final List<SchemaField> fields;
}

/// The fields one schema describes, flattened to what an inspector needs.
final class SchemaForm {
  const SchemaForm._(this.fields);

  static const SchemaForm empty = SchemaForm._(<SchemaField>[]);

  final List<SchemaField> fields;

  /// Walks [schema], which is the decoded JSON Schema as the sync project
  /// carried it. Anything that is not a schema object yields [empty].
  static SchemaForm of(Object? schema) {
    if (schema is! Map) return empty;
    final Map<String, Object?> root = schema.cast<String, Object?>();
    return SchemaForm._(_fieldsOf(root, root, ''));
  }

  /// The field at [pointer], searching nested groups and repeatable cards.
  SchemaField? field(String pointer) => _find(fields, pointer);

  static SchemaField? _find(List<SchemaField> fields, String pointer) {
    for (final SchemaField field in fields) {
      if (field.pointer == pointer) return field;
      final SchemaField? nested = _find(field.fields, pointer);
      if (nested != null) return nested;
    }
    return null;
  }
}

List<SchemaField> _fieldsOf(
  Map<String, Object?> node,
  Map<String, Object?> root,
  String pointer,
) {
  final Object? properties = node['properties'];
  if (properties is! Map) return const <SchemaField>[];
  final Set<String> required = <String>{
    for (final Object? name in node['required'] is List
        ? node['required']! as List<Object?>
        : const <Object?>[])
      if (name is String) name,
  };
  final List<SchemaField> fields = <SchemaField>[];
  properties.forEach((Object? name, Object? value) {
    if (name is! String || value is! Map) return;
    fields.add(
      _fieldOf(
        name,
        _resolve(value.cast<String, Object?>(), root),
        root,
        '$pointer/${_escape(name)}',
        required.contains(name),
      ),
    );
  });
  return List<SchemaField>.unmodifiable(fields);
}

SchemaField _fieldOf(
  String name,
  Map<String, Object?> node,
  Map<String, Object?> root,
  String pointer,
  bool required,
) {
  final String help = node['description'] is String
      ? node['description']! as String
      : '';
  final List<String> choices = <String>[
    for (final Object? value in node['enum'] is List
        ? node['enum']! as List<Object?>
        : const <Object?>[])
      '$value',
  ];
  if (choices.isNotEmpty) {
    return SchemaField(
      pointer: pointer,
      name: name,
      label: _label(name),
      control: SchemaControl.choice,
      help: help,
      required: required,
      choices: List<String>.unmodifiable(choices),
    );
  }
  final String type = _typeOf(node);
  switch (type) {
    case 'object':
      return SchemaField(
        pointer: pointer,
        name: name,
        label: _label(name),
        control: SchemaControl.group,
        help: help,
        required: required,
        fields: _fieldsOf(node, root, pointer),
      );
    case 'array':
      final Object? rawItems = node['items'];
      final Map<String, Object?> items = rawItems is Map
          ? _resolve(rawItems.cast<String, Object?>(), root)
          : const <String, Object?>{};
      if (_typeOf(items) == 'object') {
        return SchemaField(
          pointer: pointer,
          name: name,
          label: _label(name),
          control: SchemaControl.objectList,
          help: help,
          required: required,
          fields: _fieldsOf(items, root, '$pointer/-'),
        );
      }
      return SchemaField(
        pointer: pointer,
        name: name,
        label: _label(name),
        control: SchemaControl.textList,
        help: help,
        required: required,
      );
    case 'boolean':
      return SchemaField(
        pointer: pointer,
        name: name,
        label: _label(name),
        control: SchemaControl.checkbox,
        help: help,
        required: required,
      );
    case 'integer':
    case 'number':
      return SchemaField(
        pointer: pointer,
        name: name,
        label: _label(name),
        control: type == 'integer'
            ? SchemaControl.integer
            : SchemaControl.number,
        help: help,
        required: required,
        minimum: node['minimum'] is num ? node['minimum']! as num : null,
        maximum: node['maximum'] is num ? node['maximum']! as num : null,
      );
    default:
      return SchemaField(
        pointer: pointer,
        name: name,
        label: _label(name),
        control: _multiline(node) ? SchemaControl.multilineText : SchemaControl.text,
        help: help,
        required: required,
      );
  }
}

/// A local `#/$defs/<name>` reference, resolved once. A reference this walker
/// cannot follow is left as the empty schema, which reads as a text field.
Map<String, Object?> _resolve(
  Map<String, Object?> node,
  Map<String, Object?> root,
) {
  final Object? reference = node[r'$ref'];
  if (reference is! String || !reference.startsWith(r'#/$defs/')) {
    return node;
  }
  final Object? defs = root[r'$defs'];
  if (defs is! Map) return node;
  final Object? target = defs[reference.substring(r'#/$defs/'.length)];
  return target is Map ? target.cast<String, Object?>() : node;
}

String _typeOf(Map<String, Object?> node) {
  final Object? type = node['type'];
  if (type is String) return type;
  if (type is List && type.isNotEmpty && type.first is String) {
    return type.first! as String;
  }
  if (node['properties'] is Map) return 'object';
  if (node['items'] != null) return 'array';
  return 'string';
}

bool _multiline(Map<String, Object?> node) {
  final Object? maximum = node['maxLength'];
  return maximum is num && maximum > 120;
}

/// `frameIntervalMs` reads as `Frame interval ms`: the format's own spelling,
/// split at its humps, never a second name for the same thing.
String _label(String name) {
  final StringBuffer label = StringBuffer();
  for (int index = 0; index < name.length; index++) {
    final String character = name[index];
    if (character == '-' || character == '_') {
      label.write(' ');
      continue;
    }
    final bool upper = character.toUpperCase() == character &&
        character.toLowerCase() != character;
    if (upper && index > 0) label.write(' ');
    label.write(index == 0 ? character.toUpperCase() : character.toLowerCase());
  }
  return label.toString();
}

String _escape(String token) =>
    token.replaceAll('~', '~0').replaceAll('/', '~1');

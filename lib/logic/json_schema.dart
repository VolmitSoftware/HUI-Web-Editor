/// JSON-path model of the Gloss document formats.
///
/// The code editor needs to answer two questions the highlighter cannot: what
/// keys are legal at a caret, and what a key under the pointer means. Both come
/// from here, so completion and hover can never disagree with each other.
///
/// This file is the vocabulary only; the nine kinds' declarations live in
/// `config/gloss_json_schema.dart` and `config/gloss_menu_json_schema.dart`.
/// Everything is const and DOM-free, so the whole model is testable on the VM.
///
/// Three rules the declarations obey, and the tests pin:
///   1. Derived from the models, never from a schema file. `gloss.schema.json`
///      covers the menu format alone; the other eight kinds have no shipped
///      schema, so the truth is each `lib/model/*.dart` `toJson`, the allowed
///      values in `lib/logic/*_validation.dart`, and the prose in
///      `config/field_docs.dart`.
///   2. Every key a model's `toJson` emits is declared. `json_schema_test.dart`
///      walks fully-populated documents of all nine kinds and fails on a key
///      this model does not know, so the completion cannot drift behind a
///      format change.
///   3. A [GlossJsonField.docKey] must resolve through `huiFieldDoc`. A field
///      may have no doc key at all, but a doc key that points at nothing is a
///      typo, not an omission, and the tests reject it.
///
/// Unknown keys are never an error here. Every model preserves what it does not
/// recognise through `extras`, so this model describes what is KNOWN, not what
/// is allowed — nothing in the editor rejects a key because it is missing from
/// these tables.
library;

/// How a value slot is spelled in JSON. [integer] is a [number] the format
/// only ever writes without a fraction; the distinction drives the placeholder
/// a key completion inserts, nothing else.
enum GlossJsonType {
  object,
  array,
  string,
  number,
  integer,
  boolean,
  any;

  /// Short label for the completion row's right-hand column.
  String get label => switch (this) {
    GlossJsonType.object => 'object',
    GlossJsonType.array => 'array',
    GlossJsonType.string => 'string',
    GlossJsonType.number => 'number',
    GlossJsonType.integer => 'integer',
    GlossJsonType.boolean => 'boolean',
    GlossJsonType.any => 'any',
  };

  /// The literal a key completion drops in when it has to invent a value.
  /// Never a guess at content: an empty string, a zero, a false, or an empty
  /// container.
  String get emptyLiteral => switch (this) {
    GlossJsonType.object => '{}',
    GlossJsonType.array => '[]',
    GlossJsonType.string => '""',
    GlossJsonType.number => '0',
    GlossJsonType.integer => '0',
    GlossJsonType.boolean => 'false',
    GlossJsonType.any => 'null',
  };
}

/// One accepted value, written exactly as it appears in the file — quotes
/// included for strings, so a candidate is inserted verbatim and never
/// re-quoted by the caller.
final class GlossJsonValue {
  const GlossJsonValue(this.literal, {this.summary});

  final String literal;

  /// One line, or null when the literal speaks for itself (`true`).
  final String? summary;
}

/// One key in an object shape.
final class GlossJsonField {
  const GlossJsonField({
    required this.key,
    required this.type,
    required this.title,
    required this.summary,
    this.docKey,
    this.values = const <GlossJsonValue>[],
    this.defaultLiteral,
    this.node,
    this.legacy = false,
  });

  /// The JSON key, byte for byte.
  final String key;

  final GlossJsonType type;

  /// The field's name in the editor's words, matching the inspector's label
  /// where the inspector has one.
  final String title;

  /// One line for the completion row. The long explanation is [docKey]'s job.
  final String summary;

  /// Key into `huiFieldDoc`, when the inspector documents this field. Null is
  /// normal; a key that resolves to nothing is a bug the tests catch.
  final String? docKey;

  /// The closed set of values, when the format has one.
  final List<GlossJsonValue> values;

  /// What the plugin uses when the key is absent, as a literal. Null when the
  /// field has no default, or when the default is a value the editor cannot
  /// state in one literal.
  final String? defaultLiteral;

  /// The shape behind an object or array field.
  final GlossJsonNode? node;

  /// A key the format still READS but never writes — a pre-3.0 spelling the
  /// importer migrates. Hover explains it, because files in the wild carry it;
  /// completion never offers it, because writing one is a mistake.
  final bool legacy;
}

sealed class GlossJsonNode {
  const GlossJsonNode();
}

/// An object shape, optionally discriminated.
///
/// Menus put three unions in the format — component data, icons and actions —
/// and all three key off a mandatory `type` string. [variants] holds the fields
/// each tag adds on top of [fields]; an unknown or absent tag resolves to
/// [fields] alone rather than to nothing, so half-typed JSON still completes
/// the keys every variant shares.
final class GlossJsonObject extends GlossJsonNode {
  const GlossJsonObject({
    this.fields = const <GlossJsonField>[],
    this.discriminator,
    this.variants = const <String, List<GlossJsonField>>{},
    this.openKeyType,
    this.openKeyTitle,
    this.openKeySummary,
  });

  final List<GlossJsonField> fields;

  /// The key whose value picks a variant, or null for a plain object.
  final String? discriminator;

  final Map<String, List<GlossJsonField>> variants;

  /// Non-null when the object is an open map — author-chosen keys with a
  /// uniform value type, like a tablist's `nameFormats`.
  final GlossJsonType? openKeyType;
  final String? openKeyTitle;
  final String? openKeySummary;

  /// The fields legal when the discriminator reads [tag].
  List<GlossJsonField> fieldsFor(String? tag) {
    final List<GlossJsonField>? extra = tag == null ? null : variants[tag];
    if (extra == null || extra.isEmpty) return fields;
    return <GlossJsonField>[...fields, ...extra];
  }

  GlossJsonField? field(String key, {String? tag}) {
    for (final GlossJsonField candidate in fieldsFor(tag)) {
      if (candidate.key == key) return candidate;
    }
    return null;
  }
}

/// A list shape. [item] carries the element's own shape for lists of objects
/// or lists of lists; [itemType] and [itemValues] describe scalar elements.
final class GlossJsonArray extends GlossJsonNode {
  const GlossJsonArray({
    this.item,
    this.itemType = GlossJsonType.any,
    this.itemTitle = 'Entry',
    this.itemSummary = '',
    this.itemValues = const <GlossJsonValue>[],
    this.fixedLength,
  });

  final GlossJsonNode? item;
  final GlossJsonType itemType;
  final String itemTitle;
  final String itemSummary;
  final List<GlossJsonValue> itemValues;

  /// Set when the format reads exactly this many elements and rejects any
  /// other count — a Bukkit `Vector`, which is always three numbers.
  final int? fixedLength;
}

/// One hop along a JSON path.
///
/// [ownerType] is the discriminator value of the object this step's [key]
/// belongs to, captured while the path was read out of the buffer. It travels
/// with the step because resolution happens long after the text was scanned and
/// cannot go back and look.
final class JsonPathStep {
  const JsonPathStep.key(String this.key, {this.ownerType}) : index = null;

  const JsonPathStep.index(int this.index) : key = null, ownerType = null;

  final String? key;
  final int? index;
  final String? ownerType;

  @override
  bool operator ==(Object other) =>
      other is JsonPathStep &&
      other.key == key &&
      other.index == index &&
      other.ownerType == ownerType;

  @override
  int get hashCode => Object.hash(key, index, ownerType);

  @override
  String toString() => key != null ? '.$key' : '[$index]';
}

/// Dotted rendering of [path], rooted at `$` — the same spelling
/// `HuiIssue.path` uses, so a hover and an issue name the same node the same
/// way.
String glossJsonPathText(List<JsonPathStep> path) {
  final StringBuffer out = StringBuffer(r'$');
  for (final JsonPathStep step in path) {
    if (step.key != null) {
      out.write('.${step.key}');
    } else {
      out.write('[${step.index}]');
    }
  }
  return out.toString();
}

/// The node [path] addresses, or null when the path leaves the model.
///
/// A key step whose field has no nested [GlossJsonField.node] resolves to null:
/// a scalar has no shape to descend into, and asking for one is a caller bug
/// rather than a schema gap.
GlossJsonNode? glossJsonNodeAt(GlossJsonNode root, List<JsonPathStep> path) {
  GlossJsonNode? node = root;
  for (final JsonPathStep step in path) {
    if (node == null) return null;
    if (step.key != null) {
      if (node is! GlossJsonObject) return null;
      final GlossJsonField? field = node.field(step.key!, tag: step.ownerType);
      node = field?.node;
      continue;
    }
    if (node is! GlossJsonArray) return null;
    node = node.item;
  }
  return node;
}

/// The field [path] names, or null. The last step must be a key.
GlossJsonField? glossJsonFieldAt(GlossJsonNode root, List<JsonPathStep> path) {
  if (path.isEmpty) return null;
  final JsonPathStep last = path.last;
  if (last.key == null) return null;
  final GlossJsonNode? parent = glossJsonNodeAt(
    root,
    path.sublist(0, path.length - 1),
  );
  if (parent is! GlossJsonObject) return null;
  return parent.field(last.key!, tag: last.ownerType);
}

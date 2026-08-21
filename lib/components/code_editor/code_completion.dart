/// What Ctrl+Space offers, and what accepting one writes.
///
/// Two pure functions with no DOM between them: [huiCodeCompletions] turns a
/// caret context plus a kind's JSON-path model into a ranked candidate list,
/// and [huiApplyCompletion] turns a chosen candidate into the whole next buffer
/// and the caret that goes with it. The widget only moves text around.
///
/// Insertion rules, so accepting a candidate never produces JSON the user then
/// has to repair:
///   * Every literal carries its own quotes, and the replaced range always
///     swallows the quotes already there, so a string can never end up
///     double-quoted or bare.
///   * A key completed where no `:` follows writes `"key": <value>` with the
///     field's own default, or the emptiest literal of its type when it has
///     none — never invented content.
///   * A key completed after a finished member splices the separating comma in
///     at the end of that member rather than in front of the new key, so the
///     file stays in the shape a person would have typed.
library;

import '../../logic/json_schema.dart';
import 'json_caret.dart';

enum HuiCompletionKind { key, value }

/// One row in the popup.
final class HuiCompletion {
  const HuiCompletion({
    required this.label,
    required this.detail,
    required this.description,
    required this.kind,
    required this.insert,
    required this.caretOffset,
    this.isDefault = false,
  });

  /// What the user reads and what typing filters against.
  final String label;

  /// The right-hand column: a type name, or `default`.
  final String detail;

  /// One line under the label. May be empty.
  final String description;

  final HuiCompletionKind kind;

  /// Exact text that replaces the caret's slot.
  final String insert;

  /// Where the caret lands, counted from the start of [insert].
  final int caretOffset;

  /// True when this value is what the plugin uses with the key absent.
  final bool isDefault;
}

/// The buffer and caret after accepting a candidate.
final class HuiCompletionEdit {
  const HuiCompletionEdit(this.text, this.caret);

  final String text;
  final int caret;
}

/// Candidates valid at [caret], most relevant first.
///
/// An empty list is the normal answer in plenty of places — a free-text value,
/// a container the model does not describe — and the caller shows nothing
/// rather than an empty popup.
List<HuiCompletion> huiCodeCompletions({
  required GlossJsonObject root,
  required JsonCaretContext caret,
}) => switch (caret.slot) {
  JsonCaretSlot.key => _rank(_keyCompletions(root, caret), caret.prefix),
  JsonCaretSlot.value => _rank(_valueCompletions(root, caret), caret.prefix),
  JsonCaretSlot.none => const <HuiCompletion>[],
};

List<HuiCompletion> _keyCompletions(
  GlossJsonObject root,
  JsonCaretContext caret,
) {
  final GlossJsonNode? node = glossJsonNodeAt(root, caret.containerPath);
  if (node is! GlossJsonObject) return const <HuiCompletion>[];
  final List<HuiCompletion> out = <HuiCompletion>[];
  for (final GlossJsonField field in node.fieldsFor(caret.containerType)) {
    if (field.legacy) continue;
    if (field.key != caret.prefix && caret.siblingKeys.contains(field.key)) {
      continue;
    }
    final String insert = _keyInsert(field, caret);
    out.add(
      HuiCompletion(
        label: field.key,
        detail: field.type.label,
        description: field.summary,
        kind: HuiCompletionKind.key,
        insert: insert,
        caretOffset: _keyCaret(insert, field, caret),
      ),
    );
  }
  return out;
}

String _keyInsert(GlossJsonField field, JsonCaretContext caret) {
  final String quoted = '"${field.key}"';
  if (!caret.needsColon) return quoted;
  return '$quoted: ${field.defaultLiteral ?? field.type.emptyLiteral}';
}

/// Inside the value it just wrote when that value is an empty container the
/// user has to fill; at the end otherwise.
int _keyCaret(String insert, GlossJsonField field, JsonCaretContext caret) {
  if (!caret.needsColon) return insert.length;
  final String value = field.defaultLiteral ?? field.type.emptyLiteral;
  if (value == '""' || value == '{}' || value == '[]') return insert.length - 1;
  return insert.length;
}

List<HuiCompletion> _valueCompletions(
  GlossJsonObject root,
  JsonCaretContext caret,
) {
  final List<GlossJsonValue> values;
  final GlossJsonType type;
  final String? defaultLiteral;

  if (caret.containerIsObject) {
    final String? key = caret.valueKey;
    if (key == null) return const <HuiCompletion>[];
    final GlossJsonNode? node = glossJsonNodeAt(root, caret.containerPath);
    if (node is! GlossJsonObject) return const <HuiCompletion>[];
    final GlossJsonField? field = node.field(key, tag: caret.containerType);
    if (field == null) return const <HuiCompletion>[];
    values = field.values;
    type = field.type;
    defaultLiteral = field.defaultLiteral;
  } else {
    final GlossJsonNode? node = glossJsonNodeAt(root, caret.containerPath);
    if (node is! GlossJsonArray) return const <HuiCompletion>[];
    values = node.itemValues;
    type = node.itemType;
    defaultLiteral = null;
  }

  final List<GlossJsonValue> offered = <GlossJsonValue>[
    ...values,
    if (values.isEmpty && type == GlossJsonType.boolean) ...<GlossJsonValue>[
      const GlossJsonValue('true'),
      const GlossJsonValue('false'),
    ],
  ];

  final List<HuiCompletion> out = <HuiCompletion>[];
  bool sawDefault = false;
  for (final GlossJsonValue value in offered) {
    final bool isDefault = value.literal == defaultLiteral;
    sawDefault = sawDefault || isDefault;
    out.add(
      HuiCompletion(
        label: _label(value.literal),
        detail: isDefault ? 'default' : type.label,
        description: value.summary ?? '',
        kind: HuiCompletionKind.value,
        insert: value.literal,
        caretOffset: value.literal.length,
        isDefault: isDefault,
      ),
    );
  }
  // A default outside the closed set still deserves one keystroke: it is what
  // the plugin runs when the key is absent, which is exactly what an author
  // reaching for completion wants to see.
  if (!sawDefault && defaultLiteral != null) {
    out.add(
      HuiCompletion(
        label: _label(defaultLiteral),
        detail: 'default',
        description: 'What Gloss uses when this key is absent.',
        kind: HuiCompletionKind.value,
        insert: defaultLiteral,
        caretOffset: defaultLiteral.length,
        isDefault: true,
      ),
    );
  }
  return out;
}

/// The literal without its quotes, so typing filters on what is read.
String _label(String literal) {
  if (literal.length >= 2 && literal.startsWith('"') && literal.endsWith('"')) {
    return literal.substring(1, literal.length - 1);
  }
  return literal;
}

/// Prefix matches first, then substring matches; declaration order inside each
/// band, because the model lists keys in the order the format writes them.
List<HuiCompletion> _rank(List<HuiCompletion> items, String prefix) {
  if (prefix.isEmpty) return items;
  final String needle = prefix.toLowerCase();
  final List<HuiCompletion> starts = <HuiCompletion>[];
  final List<HuiCompletion> contains = <HuiCompletion>[];
  for (final HuiCompletion item in items) {
    final String label = item.label.toLowerCase();
    if (label.startsWith(needle)) {
      starts.add(item);
    } else if (label.contains(needle)) {
      contains.add(item);
    }
  }
  return <HuiCompletion>[...starts, ...contains];
}

/// [source] with [item] accepted at [caret].
HuiCompletionEdit huiApplyCompletion(
  String source,
  JsonCaretContext caret,
  HuiCompletion item,
) {
  final int? comma = caret.commaInsertAt;
  final StringBuffer out = StringBuffer();
  int caretAt;
  if (comma != null && comma <= caret.replaceStart) {
    out.write(source.substring(0, comma));
    out.write(',');
    out.write(source.substring(comma, caret.replaceStart));
    caretAt = caret.replaceStart + 1 + item.caretOffset;
  } else {
    out.write(source.substring(0, caret.replaceStart));
    caretAt = caret.replaceStart + item.caretOffset;
  }
  out.write(item.insert);
  out.write(source.substring(caret.replaceEnd));
  return HuiCompletionEdit(out.toString(), caretAt);
}

/// Regenerates `lib/config/field_docs.g.dart` from the plugin's JSON schemas.
///
/// Gloss ships `schema/gloss.schema.json` and `schema/gloss-preview.schema.json`
/// with a `description` on most properties — text nothing in the editor read
/// until this tool existed. The generated map is the FALLBACK layer of the
/// inspector's help: a hand-written entry in `field_docs.dart` always wins, so
/// this file can be regenerated without reviewing 90 popovers for regressions.
///
/// ```
/// dart run tool/extract_field_docs.dart
/// dart run tool/extract_field_docs.dart /path/to/Gloss/schema
/// ```
///
/// Output is sorted by doc key and formatted the way `dart format` leaves it,
/// so a regeneration is a reviewable diff rather than a reshuffle.
/// `test/field_docs_test.dart` holds the shipped output against this tool's
/// contract.
library;

import 'dart:convert';
import 'dart:io';

/// Default source, relative to this repo — the plugin checkout sits beside it.
final String defaultSchemaDirectory =
    '${Platform.environment['GLOSS_REPOSITORY'] ?? '../Gloss'}/schema';

const String outputPath = 'lib/config/field_docs.g.dart';

/// `$defs` name to the doc-key namespace the inspector looks help up by. The
/// empty key is the schema root. A `$defs` entry missing from this map is
/// skipped rather than guessed at: a key nothing mounts is dead weight, and a
/// key that collides with a hand-written one would be silently shadowed.
const Map<String, Map<String, String>> namespaces =
    <String, Map<String, String>>{
      'gloss.schema.json': <String, String>{
        '': 'menu',
        'component': 'component',
        'componentData': 'component',
        'buttonComponent': 'button',
        'toggleComponent': 'toggle',
        'decoComponent': 'decoration',
        'hitbox': 'hitbox',
        'action': 'action',
        'commandAction': 'action.command',
        'soundAction': 'action.sound',
        'messageAction': 'action.message',
        'teleportAction': 'action.teleport',
        'connectAction': 'action.connect',
        'navigationAction': 'action.navigation',
        'icon': 'icon',
        'iconDisplayStyle': 'icon.style',
        'textIcon': 'icon.text',
        'textImageIcon': 'icon.textImage',
        'animatedTextImageIcon': 'icon.animated',
        'itemIcon': 'icon.item',
        'customItemIcon': 'icon.customItem',
        'blockIcon': 'icon.block',
        'entityIcon': 'icon.entity',
      },
      'gloss-preview.schema.json': <String, String>{
        '': 'preview',
        'match': 'preview.match',
        'variant': 'preview.variant',
        'card': 'preview.card',
        'element': 'preview.element',
        'repeat': 'preview.repeat',
      },
    };

/// `$defs` that carry no `properties` of their own but whose description is
/// worth a popover: the shared value shapes the preview editors talk about.
const Map<String, Map<String, String>> sharedDefs =
    <String, Map<String, String>>{
      'gloss.schema.json': <String, String>{
        // The one `$def` whose own description carries a rule none of its
        // properties do: navigation ends the action list for that click.
        'navigationAction': 'action.navigation',
      },
      'gloss-preview.schema.json': <String, String>{
        'expression': 'preview.expression',
        'names': 'preview.names',
        'vars': 'preview.vars',
      },
    };

/// Words whose humanized casing a plain camelCase split gets wrong.
const Map<String, String> titleWords = <String, String>{
  'argb': 'ARGB',
  'id': 'id',
  'ms': 'ms',
  'x': 'X',
  'y': 'Y',
  'z': 'Z',
  'papi': 'PAPI',
  'rgb': 'RGB',
  'ui': 'UI',
};

/// One generated entry, before it is rendered into Dart source.
class GeneratedDoc {
  GeneratedDoc({
    required this.key,
    required this.title,
    required this.body,
    required this.citation,
  });

  final String key;
  final String title;
  final String body;
  final String citation;
}

void main(List<String> args) {
  final String directoryPath = args.isEmpty
      ? defaultSchemaDirectory
      : args.first;
  final Directory directory = Directory(directoryPath);
  if (!directory.existsSync()) {
    stderr.writeln('missing schema directory: $directoryPath');
    exitCode = 1;
    return;
  }

  final Map<String, GeneratedDoc> docs = <String, GeneratedDoc>{};
  final List<String> sources = <String>[];
  for (final String fileName in namespaces.keys) {
    final File file = File('$directoryPath/$fileName');
    if (!file.existsSync()) {
      stderr.writeln('missing schema: ${file.path}');
      exitCode = 1;
      return;
    }
    final Map<String, Object?> schema =
        jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    sources.add(fileName);
    _collect(fileName, schema, docs);
  }

  if (docs.isEmpty) {
    stderr.writeln(
      'no documented properties found; refusing to write an '
      'empty map',
    );
    exitCode = 1;
    return;
  }

  final List<String> keys = docs.keys.toList()..sort();
  File(outputPath).writeAsStringSync(_render(sources, keys, docs));
  // The formatter owns the layout, so a regeneration never fights
  // `dart format --set-exit-if-changed` in CI. It cannot split a string
  // literal, which is why [_wrap] still does the paragraph wrapping.
  final ProcessResult formatted = Process.runSync('dart', <String>[
    'format',
    outputPath,
  ]);
  if (formatted.exitCode != 0) {
    stderr.writeln('dart format failed: ${formatted.stderr}');
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'wrote $outputPath (${keys.length} docs from '
    '${sources.length} schemas)',
  );
}

/// Walks the root properties and every mapped `$defs` entry of one schema.
void _collect(
  String fileName,
  Map<String, Object?> schema,
  Map<String, GeneratedDoc> into,
) {
  final Map<String, String> mapped = namespaces[fileName]!;
  final Map<String, Object?> defs =
      (schema[r'$defs'] as Map<String, Object?>?) ?? <String, Object?>{};

  final String? rootNamespace = mapped[''];
  if (rootNamespace != null) {
    _collectProperties(
      fileName: fileName,
      pointer: '#',
      namespace: rootNamespace,
      owner: schema,
      defs: defs,
      into: into,
    );
  }

  for (final MapEntry<String, Object?> entry in defs.entries) {
    final String? namespace = mapped[entry.key];
    final Map<String, Object?> def = entry.value as Map<String, Object?>;
    if (namespace != null) {
      _collectProperties(
        fileName: fileName,
        pointer: r'#/$defs/' + entry.key,
        namespace: namespace,
        owner: def,
        defs: defs,
        into: into,
      );
    }
    final String? sharedKey = sharedDefs[fileName]?[entry.key];
    if (sharedKey == null) continue;
    final String body = _body(def, defs);
    if (body.isEmpty) continue;
    into[sharedKey] = GeneratedDoc(
      key: sharedKey,
      title: _defTitle(def['title'] as String?) ?? _humanize(entry.key),
      body: body,
      citation: '$fileName#/\$defs/${entry.key}',
    );
  }
}

void _collectProperties({
  required String fileName,
  required String pointer,
  required String namespace,
  required Map<String, Object?> owner,
  required Map<String, Object?> defs,
  required Map<String, GeneratedDoc> into,
}) {
  final Map<String, Object?>? properties =
      owner['properties'] as Map<String, Object?>?;
  if (properties == null) return;
  for (final MapEntry<String, Object?> entry in properties.entries) {
    final Map<String, Object?> property = entry.value as Map<String, Object?>;
    final String body = _body(property, defs);
    if (body.isEmpty) continue;
    final String key = '$namespace.${entry.key}';
    into[key] = GeneratedDoc(
      key: key,
      title: _humanize(entry.key),
      body: body,
      citation: '$fileName$pointer/properties/${entry.key}',
    );
  }
}

/// Description first, then the constraints a builder cannot see in the pane:
/// the accepted values, the range, and the value an omitted key takes.
String _body(Map<String, Object?> property, Map<String, Object?> defs) {
  final Map<String, Object?> resolved = _resolve(property, defs);
  final List<String> parts = <String>[];
  final String? description =
      (property['description'] as String?) ??
      (resolved['description'] as String?);
  if (description != null && description.trim().isNotEmpty) {
    parts.add(_collapse(description));
  }

  final List<Object?>? values = _enumValues(resolved);
  if (values != null && values.isNotEmpty) {
    parts.add('Accepted values: ${values.join(', ')}.');
  }

  final String? range = _range(resolved);
  if (range != null) parts.add(range);

  final Object? fallback = resolved['default'] ?? property['default'];
  if (fallback != null) {
    parts.add('Omitted, this is ${_literal(fallback)}.');
  }

  // Constraint-only bodies are still worth a popover — `icon.style.*` carries
  // no descriptions at all, and the ranges are exactly what the pane hides.
  return parts.join(' ');
}

/// Follows a single `$ref` into `$defs`, and unwraps the one-level `oneOf` /
/// `anyOf` shapes these schemas use for "value or expression" and nullable
/// fields. Deeper nesting is left alone: nothing in either schema needs it.
Map<String, Object?> _resolve(
  Map<String, Object?> property,
  Map<String, Object?> defs,
) {
  final String? reference = property[r'$ref'] as String?;
  if (reference != null) {
    final Map<String, Object?>? target = _dereference(reference, defs);
    if (target != null) return target;
  }
  for (final String key in const <String>['oneOf', 'anyOf']) {
    final List<Object?>? branches = property[key] as List<Object?>?;
    if (branches == null) continue;
    for (final Object? branch in branches) {
      if (branch is! Map<String, Object?>) continue;
      if (branch['type'] == 'null') continue;
      final Map<String, Object?> candidate = _resolve(branch, defs);
      if (candidate['description'] != null || candidate['enum'] != null) {
        return <String, Object?>{...candidate, ...property}
          ..remove(r'$ref')
          ..remove('oneOf')
          ..remove('anyOf');
      }
    }
  }
  return property;
}

Map<String, Object?>? _dereference(
  String reference,
  Map<String, Object?> defs,
) {
  const String prefix = r'#/$defs/';
  if (!reference.startsWith(prefix)) return null;
  final Object? target = defs[reference.substring(prefix.length)];
  return target is Map<String, Object?> ? target : null;
}

List<Object?>? _enumValues(Map<String, Object?> schema) {
  final Object? direct = schema['enum'];
  if (direct is List<Object?>) return direct;
  final List<Object?>? branches =
      (schema['oneOf'] ?? schema['anyOf']) as List<Object?>?;
  if (branches == null) return null;
  for (final Object? branch in branches) {
    if (branch is Map<String, Object?> && branch['enum'] is List<Object?>) {
      return branch['enum'] as List<Object?>;
    }
  }
  return null;
}

String? _range(Map<String, Object?> schema) {
  final Object? minimum = schema['minimum'];
  final Object? maximum = schema['maximum'];
  final Object? exclusiveMinimum = schema['exclusiveMinimum'];
  if (exclusiveMinimum != null && maximum != null) {
    return 'Accepted range: greater than ${_literal(exclusiveMinimum)}, '
        'up to ${_literal(maximum)}.';
  }
  if (exclusiveMinimum != null) {
    return 'Must be greater than ${_literal(exclusiveMinimum)}.';
  }
  if (minimum != null && maximum != null) {
    return 'Accepted range: ${_literal(minimum)} through ${_literal(maximum)}.';
  }
  if (minimum != null) return 'Minimum ${_literal(minimum)}.';
  if (maximum != null) return 'Maximum ${_literal(maximum)}.';
  return null;
}

String _literal(Object? value) => value is String ? value : '$value';

/// One paragraph, single-spaced: the popover is a card, not a document.
String _collapse(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ');

/// A `$defs` title as a popover heading. The schema writes them as JSON-Schema
/// object names — `Navigation Action Data Object` — which reads as filler
/// above a body that is already about that object.
String? _defTitle(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  String text = raw.trim();
  for (final String suffix in const <String>[' Data Object', ' Object']) {
    if (text.endsWith(suffix)) {
      text = text.substring(0, text.length - suffix.length);
      break;
    }
  }
  final List<String> words = text.split(RegExp(r'\s+'));
  return <String>[
    for (int i = 0; i < words.length; i++)
      // An all-caps word is an acronym the schema meant; anything else is
      // title case the popover does not want.
      if (i == 0 || words[i].toUpperCase() == words[i])
        words[i]
      else
        words[i].toLowerCase(),
  ].join(' ');
}

/// `customModelValue` becomes `Custom model value`, with the acronyms the
/// split would otherwise flatten restored from [titleWords].
String _humanize(String key) {
  final List<String> words = key
      .replaceAllMapped(
        RegExp('([a-z0-9])([A-Z])'),
        (Match match) => '${match[1]} ${match[2]}',
      )
      .split(RegExp(r'[\s_]+'))
      .where((String word) => word.isNotEmpty)
      .toList();
  final List<String> out = <String>[];
  for (int i = 0; i < words.length; i++) {
    final String lower = words[i].toLowerCase();
    final String? override = titleWords[lower];
    if (override != null) {
      out.add(i == 0 ? _capitalize(override) : override);
      continue;
    }
    out.add(i == 0 ? _capitalize(lower) : lower);
  }
  return out.join(' ');
}

String _capitalize(String word) =>
    word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}';

String _render(
  List<String> sources,
  List<String> keys,
  Map<String, GeneratedDoc> docs,
) {
  final StringBuffer buffer = StringBuffer()
    ..writeln('// GENERATED FILE - DO NOT HAND-EDIT.')
    ..writeln('//')
    ..writeln('// Regenerate with `dart run tool/extract_field_docs.dart`.')
    ..writeln('// Source: ${sources.join(', ')} in the Gloss plugin repo.')
    ..writeln()
    ..writeln('/// Schema-derived field help: the fallback layer behind the')
    ..writeln('/// hand-written entries in `field_docs.dart`.')
    ..writeln('///')
    ..writeln('/// Every body here is the plugin schema\'s own `description`,')
    ..writeln('/// plus the accepted values, range and default the inspector')
    ..writeln('/// cannot show inline. A hand-written doc for the same key')
    ..writeln('/// always wins, so this file never needs a review pass of its')
    ..writeln('/// own — see `huiFieldDoc` in `field_docs.dart`.')
    ..writeln('library;')
    ..writeln()
    ..writeln("import 'field_docs.dart';")
    ..writeln()
    ..writeln('const Map<String, HuiFieldDoc> huiGeneratedFieldDocs =')
    ..writeln('    <String, HuiFieldDoc>{');
  for (final String key in keys) {
    final GeneratedDoc doc = docs[key]!;
    buffer
      ..writeln('  ${_dartString(key)}: HuiFieldDoc(')
      ..writeln('    title: ${_dartString(doc.title)},')
      ..writeln('    body:')
      ..writeln('        ${_wrap(doc.body, 8)},')
      ..writeln('    citation: ${_dartString(doc.citation)},')
      ..writeln('  ),');
  }
  buffer.writeln('};');
  return buffer.toString();
}

/// Adjacent string literals, wrapped near the 80 column line the rest of the
/// codebase keeps, so the generated file needs no formatter pass.
String _wrap(String text, int indent) {
  const int limit = 72;
  final List<String> words = text.split(' ');
  final List<String> lines = <String>[];
  StringBuffer current = StringBuffer();
  for (final String word in words) {
    if (current.isEmpty) {
      current.write(word);
      continue;
    }
    if (current.length + 1 + word.length > limit - indent) {
      lines.add(current.toString());
      current = StringBuffer(word);
      continue;
    }
    current.write(' $word');
  }
  if (current.isNotEmpty) lines.add(current.toString());
  final String pad = ' ' * indent;
  return lines
      .asMap()
      .entries
      .map(
        (MapEntry<int, String> entry) => entry.key == 0
            ? _dartString(
                '${entry.value}${entry.key == lines.length - 1 ? '' : ' '}',
              )
            : '$pad${_dartString('${entry.value}${entry.key == lines.length - 1 ? '' : ' '}')}',
      )
      .join('\n');
}

String _dartString(String value) {
  final String escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');
  return "'$escaped'";
}

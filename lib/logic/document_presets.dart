import 'dart:convert';

final class DocumentPresets {
  DocumentPresets._(this._defaults, this._presets);

  static final DocumentPresets empty = DocumentPresets._(
    <String, Map<String, Object?>>{},
    <String, Map<String, Map<String, Object?>>>{},
  );

  static const Set<String> kinds = <String>{
    'animations', 'bubbles', 'previews', 'damage-indicators', 'emoji',
    'entity-overlays', 'holograms', 'menus', 'names', 'motd', 'panels',
    'real-drops', 'boards', 'tablist', 'surfaces', 'nametags', 'channels',
    'strings', 'leaderboards', 'inventories', 'markers', 'nameplates',
    'waypoints', 'behaviors', 'glyphs', 'connections',
  };
  static const Set<String> _identity = <String>{
    'schemaVersion', 'revision', 'id', 'uuid', 'preset',
  };

  final Map<String, Map<String, Object?>> _defaults;
  final Map<String, Map<String, Map<String, Object?>>> _presets;

  factory DocumentPresets.parse(String source) {
    if (utf8.encode(source).length > 2 * 1024 * 1024) {
      throw const FormatException('The preset catalog exceeds 2 MiB.');
    }
    final Map<String, Object?> root = _object(jsonDecode(source), 'presets');
    _weight(root);
    _fields(root, const <String>{'schemaVersion', 'revision', 'defaults', 'presets'});
    if (root['schemaVersion'] != 1 || root['revision'] is! num ||
        (root['revision']! as num) < 1 ||
        (root['revision']! as num) > 9007199254740991 ||
        (root['revision']! as num) % 1 != 0) {
      throw const FormatException('Presets require schemaVersion 1 and a positive integer revision.');
    }
    int remaining = 64 * 1024 * 1024;
    final Map<String, Map<String, Object?>> defaults = <String, Map<String, Object?>>{};
    for (final MapEntry<String, Object?> entry in _optional(root, 'defaults').entries) {
      _kind(entry.key);
      final Map<String, Object?> values = _values(entry.value);
      remaining -= _weight(values);
      defaults[entry.key] = values;
    }
    final Map<String, Map<String, Map<String, Object?>>> presets =
        <String, Map<String, Map<String, Object?>>>{};
    for (final MapEntry<String, Object?> entry in _optional(root, 'presets').entries) {
      _kind(entry.key);
      final Map<String, Object?> definitions = _object(entry.value, entry.key);
      final Map<String, Map<String, Object?>> compiled = <String, Map<String, Object?>>{};
      for (final String name in definitions.keys) {
        if (name.trim().isEmpty || name.contains('/') || name.contains('\\') || name.contains('..')) {
          throw FormatException('Invalid preset name: $name');
        }
        if (compiled.containsKey(name)) continue;
        final List<String> chain = <String>[];
        final Set<String> visited = <String>{};
        String? cursor = name;
        while (cursor != null && !compiled.containsKey(cursor)) {
          if (!visited.add(cursor)) {
            throw FormatException('Preset inheritance cycle: $cursor');
          }
          final Map<String, Object?> definition = _object(definitions[cursor], cursor);
          _fields(definition, const <String>{'extends', 'values'});
          _values(definition.containsKey('values') ? definition['values'] : <String, Object?>{});
          chain.add(cursor);
          final Object? parent = definition['extends'];
          if (parent != null && (parent is! String || parent.trim().isEmpty)) {
            throw const FormatException('Preset extends must be a nonblank name.');
          }
          cursor = parent as String?;
        }
        Map<String, Object?> inherited = cursor == null
            ? <String, Object?>{} : _copy(compiled[cursor]!);
        for (final String current in chain.reversed) {
          final Map<String, Object?> definition = _object(definitions[current], current);
          inherited = _merge(inherited, _optional(definition, 'values'));
          remaining -= _weight(inherited);
          if (remaining < 0) {
            throw const FormatException('Preset catalog exceeds the prepared-data memory limit.');
          }
          compiled[current] = inherited;
        }
      }
      presets[entry.key] = compiled;
    }
    return DocumentPresets._(defaults, presets);
  }

  static String? collection(String? wireKind) => switch (wireKind) {
    'menu' => 'menus', 'container-preview' => 'previews', 'panel' => 'panels',
    'hologram' => 'holograms', 'animation' => 'animations', 'scoreboard' => 'boards',
    'surface' => 'surfaces', 'channel' => 'channels', 'bubble-style' => 'bubbles',
    'inventory' => 'inventories', 'nameplate' => 'nameplates', 'nametag' => 'nametags',
    'marker' => 'markers', 'waypoint' => 'waypoints', 'glyph' => 'glyphs', 'behavior' => 'behaviors',
    _ => kinds.contains(wireKind) ? wireKind : null,
  };

  Set<String> collectionsForPreset(String name) => <String>{
    for (final MapEntry<String, Map<String, Map<String, Object?>>> entry in _presets.entries)
      if (entry.value.containsKey(name)) entry.key,
  };

  bool applies(String? wireKind, String source) {
    final String? kind = collection(wireKind);
    if (kind == null) return false;
    final Map<String, Object?> authored = _object(jsonDecode(source), 'document');
    return _defaults.containsKey(kind) || authored['preset'] != null;
  }

  String resolve(String? wireKind, String source) {
    final String? kind = collection(wireKind);
    if (kind == null) return source;
    final Map<String, Object?> authored = _object(jsonDecode(source), 'document');
    _weight(authored);
    final Object? selected = authored['preset'];
    if (selected == null && !_defaults.containsKey(kind)) return source;
    Map<String, Object?> resolved = _copy(_defaults[kind] ?? <String, Object?>{});
    if (selected != null) {
      if (selected is! String || selected.trim().isEmpty) {
        throw const FormatException('Preset must be a nonblank name.');
      }
      final Map<String, Object?>? preset = _presets[kind]?[selected];
      if (preset == null) throw FormatException('$kind preset does not exist: $selected');
      resolved = _merge(resolved, preset);
    }
    resolved = _merge(resolved, authored)..remove('preset');
    return jsonEncode(resolved);
  }

  static void _kind(String value) {
    if (!kinds.contains(value)) throw FormatException('Unknown preset document kind: $value');
  }

  static Map<String, Object?> _values(Object? value) {
    final Map<String, Object?> values = _object(value, 'values');
    for (final String field in _identity) {
      if (values.containsKey(field)) throw FormatException('Preset values cannot define $field.');
    }
    return values;
  }

  static void _fields(Map<String, Object?> value, Set<String> fields) {
    for (final String field in value.keys) {
      if (!fields.contains(field)) throw FormatException('Unknown preset field: $field');
    }
  }

  static int _weight(Object? value, [int depth = 0]) {
    if (depth > 128) throw const FormatException('Preset data exceeds 128 levels.');
    int weight = 64;
    if (value is Map<String, Object?>) {
      for (final MapEntry<String, Object?> entry in value.entries) {
        weight += 64 + entry.key.length * 2 + _weight(entry.value, depth + 1);
      }
    } else if (value is List<Object?>) {
      for (final Object? item in value) { weight += _weight(item, depth + 1); }
    } else if (value is String) {
      weight += value.length * 2;
    }
    if (weight > 64 * 1024 * 1024) throw const FormatException('Preset data exceeds the memory limit.');
    return weight;
  }
}

final class InheritedDocumentSource {
  InheritedDocumentSource(this.source, String canonical)
      : _authored = _object(jsonDecode(source), 'document'),
        _baseline = _object(jsonDecode(canonical), 'document');

  final String source;
  final Map<String, Object?> _authored;
  final Map<String, Object?> _baseline;

  String encode(String canonical) {
    final Map<String, Object?> current = _object(jsonDecode(canonical), 'document');
    if (_equal(current, _baseline)) return source;
    return const JsonEncoder.withIndent('  ').convert(_edit(_authored, _baseline, current));
  }

  static Map<String, Object?> _edit(Map<String, Object?> authored,
      Map<String, Object?> before, Map<String, Object?> after) {
    final Map<String, Object?> result = _copy(authored);
    for (final String key in <String>{...before.keys, ...after.keys}) {
      if (before.containsKey(key) == after.containsKey(key) && _equal(before[key], after[key])) continue;
      if (!after.containsKey(key)) {
        result[key] = null;
      } else if (before[key] is Map<String, Object?> && after[key] is Map<String, Object?>) {
        result[key] = _edit(authored[key] is Map<String, Object?>
            ? authored[key]! as Map<String, Object?> : <String, Object?>{},
            before[key]! as Map<String, Object?>, after[key]! as Map<String, Object?>);
      } else {
        result[key] = after[key];
      }
    }
    return result;
  }
}

Map<String, Object?> _object(Object? value, String path) {
  if (value is! Map<String, Object?>) throw FormatException('$path must be an object.');
  return value;
}

Map<String, Object?> _optional(Map<String, Object?> value, String key) =>
    value.containsKey(key) ? _object(value[key], key) : <String, Object?>{};

Map<String, Object?> _copy(Map<String, Object?> value) =>
    _object(jsonDecode(jsonEncode(value)), 'value');

Map<String, Object?> _merge(Map<String, Object?> base, Map<String, Object?> overlay) {
  final Map<String, Object?> result = _copy(base);
  for (final MapEntry<String, Object?> entry in overlay.entries) {
    final Object? previous = result[entry.key];
    result[entry.key] = previous is Map<String, Object?> && entry.value is Map<String, Object?>
        ? _merge(previous, entry.value! as Map<String, Object?>) : entry.value;
  }
  return result;
}

bool _equal(Object? left, Object? right) {
  if (identical(left, right)) return true;
  if (left is Map<String, Object?> && right is Map<String, Object?>) {
    return left.length == right.length && left.entries.every((MapEntry<String, Object?> entry) =>
        right.containsKey(entry.key) && _equal(entry.value, right[entry.key]));
  }
  if (left is List<Object?> && right is List<Object?>) {
    if (left.length != right.length) return false;
    for (int index = 0; index < left.length; index++) {
      if (!_equal(left[index], right[index])) return false;
    }
    return true;
  }
  return left == right;
}

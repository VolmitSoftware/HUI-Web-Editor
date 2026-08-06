import 'dart:convert';

import 'hui_menu.dart';

/// Raised for the errors that would make HoloUI's Gson pipeline reject the
/// whole menu file: malformed JSON, a bad vector, or a missing/unknown `type`
/// discriminator. Everything else is imported leniently and surfaced by
/// `validateHuiMenu` instead.
class HuiFormatException implements Exception {
  final String message;

  /// Dotted path of the offending node, e.g. `components[2].data.icon`.
  /// The document root is `$`.
  final String path;

  const HuiFormatException(this.message, this.path);

  @override
  String toString() => 'HuiFormatException: $message (at $path)';
}

HuiMenu decodeHuiMenu(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    throw HuiFormatException('Invalid JSON: ${e.message}', r'$');
  }
  return HuiMenu.fromJson(raw);
}

String encodeHuiMenu(HuiMenu menu) => _writeValue(menu.toJson(), 0);

/// Pretty-prints an already-decoded JSON tree in this file's canonical style
/// (2-space indent, integral doubles without a trailing `.0`, inline numeric
/// arrays). Shared by every model's `encode*` function, not just
/// [encodeHuiMenu].
String huiWriteJson(Object? value) => _writeValue(value, 0);

HuiMenu cloneHuiMenu(HuiMenu menu) =>
    HuiMenu.fromJson(huiDeepCopy(menu.toJson()));

// --- reading helpers (shared by every model class) -------------------------

Map<String, dynamic> huiReadObject(Object? raw, String path) {
  if (raw is Map) {
    final Map<String, dynamic> out = <String, dynamic>{};
    raw.forEach((Object? key, Object? value) => out[key.toString()] = value);
    return out;
  }
  throw HuiFormatException('Expected a JSON object', path);
}

/// Mirrors `EnumType`: the discriminator is mandatory and is consumed (it never
/// lands in `extras`).
String huiReadTypeTag(Map<String, dynamic> raw, String path) {
  final Object? type = raw['type'];
  if (type is! String || type.isEmpty) {
    throw HuiFormatException('Missing type', path);
  }
  return type;
}

/// `EnumType.read` throws `JsonParseException` and `ConfigManager.loadConfig`
/// catches it around the whole document, so one bad discriminator costs the
/// entire menu — worth saying out loud. `fontImage` and `itemStack` land here
/// too: `MenuIconType` declares them with a null data class, and `EnumType`
/// filters null-typed constants out of its map before reading
/// (`MenuIconType.java:31-32`, `EnumType.java:38-39,82-85`).
Never huiUnknownType(String type, String path) => throw HuiFormatException(
  'Unknown type: $type. HoloUI rejects the whole menu file when a '
  'component, icon or action type is not one it knows',
  path,
);

String huiReadString(
  Map<String, dynamic> raw,
  String key, {
  String fallback = '',
}) {
  final Object? value = raw[key];
  if (value == null) return fallback;
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return fallback;
}

double huiReadDouble(
  Map<String, dynamic> raw,
  String key, {
  double fallback = 0,
}) {
  return huiReadDoubleOrNull(raw, key) ?? fallback;
}

double? huiReadDoubleOrNull(Map<String, dynamic> raw, String key) {
  final Object? value = raw[key];
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int huiReadInt(Map<String, dynamic> raw, String key, {int fallback = 0}) {
  final Object? value = raw[key];
  if (value is num) return value.toInt();
  if (value is String) {
    final double? parsed = double.tryParse(value);
    if (parsed != null) return parsed.toInt();
  }
  return fallback;
}

bool huiReadBool(Map<String, dynamic> raw, String key) {
  final Object? value = raw[key];
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.toLowerCase() == 'true';
  return false;
}

/// `SingleCollectionTypeFactory`: any list slot also accepts a single value.
List<Object?> huiReadList(Object? raw) {
  if (raw == null) return const <Object?>[];
  if (raw is List) return raw;
  return <Object?>[raw];
}

List<String> huiReadStringList(Object? raw) => huiReadList(raw)
    .where((Object? e) => e != null)
    .map((Object? e) => e is String ? e : e.toString())
    .toList();

Map<String, dynamic> huiCollectExtras(
  Map<String, dynamic> raw,
  Set<String> consumed,
) {
  final Map<String, dynamic> out = <String, dynamic>{};
  raw.forEach((String key, Object? value) {
    if (!consumed.contains(key)) out[key] = huiDeepCopy(value);
  });
  return out;
}

/// Re-emits preserved unknown keys after the known ones; known keys win.
Map<String, dynamic> huiMergeExtras(
  Map<String, dynamic> known,
  Map<String, dynamic> extras,
) {
  if (extras.isEmpty) return known;
  extras.forEach((String key, Object? value) {
    if (!known.containsKey(key)) known[key] = huiDeepCopy(value);
  });
  return known;
}

Object? huiDeepCopy(Object? value) {
  if (value is Map) {
    final Map<String, dynamic> out = <String, dynamic>{};
    value.forEach(
      (Object? key, Object? v) => out[key.toString()] = huiDeepCopy(v),
    );
    return out;
  }
  if (value is List) {
    return value.map(huiDeepCopy).toList();
  }
  return value;
}

Map<String, dynamic> huiDeepCopyMap(Map<String, dynamic> value) =>
    huiDeepCopy(value)! as Map<String, dynamic>;

// --- writing ---------------------------------------------------------------

const String _indentUnit = '  ';

String _writeValue(Object? value, int depth) {
  if (value == null) return 'null';
  if (value is bool) return value ? 'true' : 'false';
  if (value is num) return _writeNumber(value);
  if (value is String) return jsonEncode(value);
  if (value is List) return _writeList(value, depth);
  if (value is Map) return _writeMap(value, depth);
  return jsonEncode(value);
}

/// Integral doubles are written without a trailing `.0` so exported files read
/// like the hand-authored examples; Gson accepts either form.
String _writeNumber(num value) {
  if (value is int) return value.toString();
  final double d = value.toDouble();
  if (d.isNaN || d.isInfinite) return '0';
  if (d == d.roundToDouble() && d.abs() < 1e15) return d.toInt().toString();
  return d.toString();
}

String _writeList(List<Object?> value, int depth) {
  if (value.isEmpty) return '[]';
  if (value.every((Object? e) => e is num)) {
    return '[${value.map((Object? e) => _writeNumber(e! as num)).join(', ')}]';
  }
  final String pad = _indentUnit * (depth + 1);
  final StringBuffer buffer = StringBuffer('[\n');
  for (int i = 0; i < value.length; i++) {
    buffer.write(pad);
    buffer.write(_writeValue(value[i], depth + 1));
    if (i < value.length - 1) buffer.write(',');
    buffer.write('\n');
  }
  buffer.write(_indentUnit * depth);
  buffer.write(']');
  return buffer.toString();
}

String _writeMap(Map<Object?, Object?> value, int depth) {
  if (value.isEmpty) return '{}';
  final String pad = _indentUnit * (depth + 1);
  final List<Object?> keys = value.keys.toList();
  final StringBuffer buffer = StringBuffer('{\n');
  for (int i = 0; i < keys.length; i++) {
    buffer.write(pad);
    buffer.write(jsonEncode(keys[i].toString()));
    buffer.write(': ');
    buffer.write(_writeValue(value[keys[i]], depth + 1));
    if (i < keys.length - 1) buffer.write(',');
    buffer.write('\n');
  }
  buffer.write(_indentUnit * depth);
  buffer.write('}');
  return buffer.toString();
}

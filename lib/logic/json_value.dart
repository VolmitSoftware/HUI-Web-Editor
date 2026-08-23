/// Tolerant single-value JSON parse and format, for editing `extras`.
///
/// Extras are the keys HoloUi does not recognise. The codec deep-copies them on
/// import and merges them back on export (`json_codec.dart:112-129`), so
/// whatever the editor commits has to survive `jsonEncode` — that is the one
/// hard rule here. Everything else is typing comfort: bare text is a string, so
/// the common case of an unknown string key needs no quotes, while a value that
/// would read back as something else is written quoted.
library;

import 'dart:convert';

import '../l10n/hui_localizations.dart';

/// Outcome of [parseJsonValue].
///
/// [ok] is separate from [value] because `null` is a legal JSON value: a
/// successful parse of `null` and a failed parse both carry a null [value].
class JsonParseResult {
  const JsonParseResult._(
    this.ok,
    this.value,
    this._errorEnglish,
    this._errorArguments,
  );

  const JsonParseResult.value(Object? value)
    : this._(true, value, null, const <String, Object?>{});

  JsonParseResult.failure(
    String message, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) : this._(
         false,
         null,
         message,
         Map<String, Object?>.unmodifiable(arguments),
       );

  final bool ok;

  /// Null, bool, int, double, String, `List<Object?>` or `Map<String, dynamic>`.
  final Object? value;

  final String? _errorEnglish;
  final Map<String, Object?> _errorArguments;

  /// One sentence naming what could not be read. Null when [ok].
  String? get error =>
      _errorEnglish == null ? null : huiText(_errorEnglish, _errorArguments);
}

/// JSON number grammar, widened to the forms people actually type: a leading
/// `+`, a leading zero and a bare `.5` are all accepted. Hex is deliberately
/// not, because `int.parse` would take `0x10` and JSON has no such literal.
final RegExp _numberPattern = RegExp(
  r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$',
);

/// Text safe to show without quotes: it survives a [parseJsonValue] round trip
/// unchanged.
final RegExp _bareUnsafeStart = RegExp(r'^[{\["]');

/// Reads one JSON value out of [raw].
///
/// Blank input is the empty string rather than an error, so clearing a field
/// never leaves an extras entry in a state that cannot be committed.
JsonParseResult parseJsonValue(String raw) {
  final String text = raw.trim();
  if (text.isEmpty) return const JsonParseResult.value('');

  switch (text) {
    case 'null':
      return const JsonParseResult.value(null);
    case 'true':
      return const JsonParseResult.value(true);
    case 'false':
      return const JsonParseResult.value(false);
  }

  if (_numberPattern.hasMatch(text)) {
    final Object? number = _parseNumber(text);
    // Falls through to text when the literal is out of range (`1e999` parses to
    // Infinity, which jsonEncode refuses to write).
    if (number != null) return JsonParseResult.value(number);
  }

  // A leading brace, bracket or quote is a commitment: the user meant JSON, so
  // a mistake is reported instead of being silently kept as text.
  if (_bareUnsafeStart.hasMatch(text)) {
    try {
      return JsonParseResult.value(jsonDecode(text));
    } on FormatException catch (error) {
      final int? offset = error.offset;
      return offset == null
          ? JsonParseResult.failure('Not valid JSON.')
          : JsonParseResult.failure(
              'Not valid JSON (at character {character}).',
              <String, Object?>{'character': offset + 1},
            );
    }
  }

  return JsonParseResult.value(text);
}

/// Writes [value] in the form [parseJsonValue] reads back identically.
String formatJsonValue(Object? value) {
  if (value is String) return _isBare(value) ? value : jsonEncode(value);
  try {
    return jsonEncode(value);
  } on JsonUnsupportedObjectError {
    // Only reachable if a caller hands over something the model never holds;
    // showing the object beats throwing inside a build.
    return value.toString();
  }
}

Object? _parseNumber(String text) {
  final bool fractional =
      text.contains('.') || text.contains('e') || text.contains('E');
  if (!fractional) {
    final int? whole = int.tryParse(text);
    if (whole != null) return whole;
  }
  final double? decimal = double.tryParse(text);
  if (decimal == null || !decimal.isFinite) return null;
  return decimal;
}

bool _isBare(String value) {
  if (value.isEmpty) return false;
  if (value.trim() != value) return false;
  if (value.contains('\n') || value.contains('\r') || value.contains('\t')) {
    return false;
  }
  if (value == 'null' || value == 'true' || value == 'false') return false;
  if (_bareUnsafeStart.hasMatch(value)) return false;
  return !_numberPattern.hasMatch(value);
}

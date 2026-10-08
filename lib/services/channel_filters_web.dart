library;

import 'dart:convert';
import 'dart:js_interop';

@JS('GlossChannelFilters')
external JSObject? get _engine;

@JS('GlossChannelFilters.runJson')
external JSString _run(JSString source, JSString message);

@JS('GlossChannelFilters.validateJson')
external JSString? _validate(JSString source);

@JS('GlossChannelFilters.validateBehaviorJson')
external JSString? _validateBehavior(JSString source);

String? validateBehavior(Map<String, Object?> doc) => _engine == null
    ? 'RE2 validation engine is unavailable.'
    : _validateBehavior(jsonEncode(doc).toJS)?.toDart;

Map<String, Object?> run(Map<String, Object?> doc, String message) {
  if (_engine == null) {
    return <String, Object?>{
      'message': message,
      'notice':
          'RE2 preview engine is unavailable. Reload the editor to retry.',
    };
  }
  final Object? decoded = jsonDecode(
    _run(jsonEncode(doc).toJS, message.toJS).toDart,
  );
  return Map<String, Object?>.from(decoded as Map);
}

String? validate(Map<String, Object?> doc) =>
    _engine == null ? null : _validate(jsonEncode(doc).toJS)?.toDart;

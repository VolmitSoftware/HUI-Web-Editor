library;

import 'package:http/http.dart' as http;

import 'hui_localizations.dart';

typedef HuiLocaleSourceLoader = Future<String?> Function(String locale);

final RegExp _localePlaceholderPattern = RegExp(r'\{([a-z][a-zA-Z0-9_]*)\}');

final class HuiLocaleController {
  HuiLocaleController({
    HuiLocalizations? localizations,
    HuiLocaleSourceLoader? loader,
  }) : _localizations = localizations ?? huiLocalizations,
       _loader = loader ?? loadHuiLocaleSource;

  final HuiLocalizations _localizations;
  final HuiLocaleSourceLoader _loader;
  final Map<String, String> _sourceCache = <String, String>{};
  HuiLocaleSnapshot? _englishSchema;
  int _request = 0;

  String get activeLocale => _localizations.activeLocale;

  Future<HuiLocaleInstallResult> activate(String requestedLocale) async {
    final String locale;
    try {
      locale = canonicalHuiLocale(requestedLocale);
    } on ArgumentError catch (error) {
      return HuiLocaleInstallResult.rejected(
        requestedLocale,
        error.message?.toString() ?? error.toString(),
      );
    }
    final int request = ++_request;
    try {
      final HuiLocaleInstallResult result = await _loadCandidate(
        locale,
        request,
      );
      if (!result.applied) return result;
      if (request != _request) return _replaced(locale);
      return result;
    } catch (error) {
      if (request != _request) return _replaced(locale);
      return HuiLocaleInstallResult.rejected(
        locale,
        'Could not load locale $locale: $error',
      );
    }
  }

  Future<HuiLocaleInstallResult> _loadCandidate(
    String locale,
    int request,
  ) async {
    HuiLocaleSnapshot? english = _englishSchema;
    if (english == null) {
      final String? englishSource = await _source(huiEnglishLocale);
      if (request != _request) return _replaced(locale);
      if (englishSource == null || englishSource.trim().isEmpty) {
        if (locale == huiEnglishLocale) {
          _localizations.resetToEnglish();
          return const HuiLocaleInstallResult.applied(huiEnglishLocale);
        }
        return HuiLocaleInstallResult.rejected(
          locale,
          'The English locale schema is unavailable.',
        );
      }
      final HuiLocalizations candidate = HuiLocalizations();
      final HuiLocaleInstallResult result = candidate.installJson(
        huiEnglishLocale,
        englishSource,
      );
      if (!result.applied) return result;
      english = candidate.snapshot;
      _englishSchema = english;
      _sourceCache[huiEnglishLocale] = englishSource;
    }
    if (locale == huiEnglishLocale) {
      _localizations.installSnapshot(english);
      return const HuiLocaleInstallResult.applied(huiEnglishLocale);
    }

    final String? source = await _source(locale);
    if (request != _request) return _replaced(locale);
    if (source == null || source.trim().isEmpty) {
      return HuiLocaleInstallResult.rejected(
        locale,
        'Locale file languages/$locale.json is unavailable.',
      );
    }
    final HuiLocalizations candidate = HuiLocalizations();
    final HuiLocaleInstallResult result = candidate.installJson(locale, source);
    if (!result.applied) return result;
    if (!_sameCatalogShape(english, candidate.snapshot)) {
      return HuiLocaleInstallResult.rejected(
        locale,
        'Locale $locale does not match the complete English catalog.',
      );
    }
    _sourceCache[locale] = source;
    _localizations.installSnapshot(candidate.snapshot);
    return result;
  }

  Future<String?> _source(String locale) async {
    final String? cached = _sourceCache[locale];
    if (cached != null) return cached;
    return _loader(locale);
  }

  static HuiLocaleInstallResult _replaced(String locale) =>
      HuiLocaleInstallResult.rejected(locale, 'Locale request replaced.');

  static bool _sameCatalogShape(
    HuiLocaleSnapshot english,
    HuiLocaleSnapshot candidate,
  ) =>
      _sameKeys(english.messages, candidate.messages) &&
      _sameKeys(english.contexts, candidate.contexts) &&
      _sameKeys(english.plurals, candidate.plurals) &&
      _sameKeys(english.previewMessages, candidate.previewMessages) &&
      _sameContextPlaceholders(english, candidate) &&
      _samePreviewPlaceholders(english, candidate) &&
      _validPluralForms(english) &&
      _validPluralForms(candidate) &&
      _samePluralPlaceholders(english, candidate);

  static bool _sameKeys(Map<Object, Object> left, Map<Object, Object> right) =>
      left.length == right.length && left.keys.every(right.containsKey);

  static bool _samePreviewPlaceholders(
    HuiLocaleSnapshot english,
    HuiLocaleSnapshot candidate,
  ) {
    for (final MapEntry<String, String> message
        in english.previewMessages.entries) {
      if (!_sameNames(
        _placeholderNames(message.value),
        _placeholderNames(candidate.previewMessages[message.key]!),
      )) {
        return false;
      }
    }
    return true;
  }

  static bool _sameContextPlaceholders(
    HuiLocaleSnapshot english,
    HuiLocaleSnapshot candidate,
  ) {
    for (final MapEntry<String, String> message in english.contexts.entries) {
      if (!_sameNames(
        _placeholderNames(message.value),
        _placeholderNames(candidate.contexts[message.key]!),
      )) {
        return false;
      }
    }
    return true;
  }

  static bool _validPluralForms(HuiLocaleSnapshot snapshot) {
    final Set<HuiPluralForm> required = _requiredPluralForms(snapshot.locale);
    for (final Map<HuiPluralForm, String> forms in snapshot.plurals.values) {
      if (!_sameNames(required, forms.keys.toSet())) return false;
    }
    return true;
  }

  static bool _samePluralPlaceholders(
    HuiLocaleSnapshot english,
    HuiLocaleSnapshot candidate,
  ) {
    for (final MapEntry<String, Map<HuiPluralForm, String>> plural
        in english.plurals.entries) {
      final Set<String> allowed = <String>{};
      Set<String>? required;
      for (final String template in plural.value.values) {
        final Set<String> placeholders = _placeholderNames(template);
        allowed.addAll(placeholders);
        required = required == null
            ? Set<String>.of(placeholders)
            : required.intersection(placeholders);
      }
      final Set<String> requiredNames = required ?? const <String>{};
      for (final String template in candidate.plurals[plural.key]!.values) {
        final Set<String> placeholders = _placeholderNames(template);
        if (!placeholders.containsAll(requiredNames) ||
            !allowed.containsAll(placeholders)) {
          return false;
        }
      }
    }
    return true;
  }

  static Set<String> _placeholderNames(String value) =>
      _localePlaceholderPattern
          .allMatches(value)
          .map((RegExpMatch match) => match.group(1)!)
          .toSet();

  static bool _sameNames<T>(Set<T> left, Set<T> right) =>
      left.length == right.length && left.containsAll(right);

  static Set<HuiPluralForm> _requiredPluralForms(String locale) =>
      switch (locale) {
        'he_IL' => <HuiPluralForm>{
          HuiPluralForm.one,
          HuiPluralForm.two,
          HuiPluralForm.other,
        },
        'es_ES' || 'fr_FR' || 'it_IT' || 'pt_PT' => <HuiPluralForm>{
          HuiPluralForm.one,
          HuiPluralForm.many,
          HuiPluralForm.other,
        },
        'lt_LT' => <HuiPluralForm>{
          HuiPluralForm.one,
          HuiPluralForm.few,
          HuiPluralForm.other,
        },
        'pl_PL' || 'ru_RU' => <HuiPluralForm>{
          HuiPluralForm.one,
          HuiPluralForm.few,
          HuiPluralForm.many,
          HuiPluralForm.other,
        },
        'ja-JP' ||
        'ko_KR' ||
        'zh_CN' ||
        'zh_TW' => <HuiPluralForm>{HuiPluralForm.other},
        _ => <HuiPluralForm>{HuiPluralForm.one, HuiPluralForm.other},
      };
}

Future<String?> loadHuiLocaleSource(String locale) async {
  final http.Response response = await http.get(
    Uri.base.resolve('/languages/$locale.json'),
  );
  if (response.statusCode == 404) return null;
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('Locale request failed with HTTP ${response.statusCode}.');
  }
  return response.body;
}

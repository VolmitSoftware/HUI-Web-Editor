library;

import 'dart:convert';

const String huiEnglishLocale = 'en_US';
const String huiLocaleStorageKey = 'gloss.locale';
const String huiDocumentTitleSource = 'Gloss Editor';
const String huiDocumentDescriptionSource =
    'Visual web editor for creating and previewing Gloss menu configurations.';

final RegExp _huiPlaceholderPattern = RegExp(r'\{([a-z][a-zA-Z0-9_]*)\}');

final class HuiLocale {
  const HuiLocale({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.htmlLanguage,
    this.rightToLeft = false,
  });

  final String code;
  final String nativeName;
  final String englishName;
  final String htmlLanguage;
  final bool rightToLeft;
}

const List<HuiLocale> huiSupportedLocales = <HuiLocale>[
  HuiLocale(
    code: 'en_US',
    nativeName: 'English',
    englishName: 'English',
    htmlLanguage: 'en-US',
  ),
  HuiLocale(
    code: 'de_DE',
    nativeName: 'Deutsch',
    englishName: 'German',
    htmlLanguage: 'de-DE',
  ),
  HuiLocale(
    code: 'es_ES',
    nativeName: 'Español',
    englishName: 'Spanish',
    htmlLanguage: 'es-ES',
  ),
  HuiLocale(
    code: 'fi_FI',
    nativeName: 'Suomi',
    englishName: 'Finnish',
    htmlLanguage: 'fi-FI',
  ),
  HuiLocale(
    code: 'fr_FR',
    nativeName: 'Français',
    englishName: 'French',
    htmlLanguage: 'fr-FR',
  ),
  HuiLocale(
    code: 'he_IL',
    nativeName: 'עברית',
    englishName: 'Hebrew',
    htmlLanguage: 'he-IL',
    rightToLeft: true,
  ),
  HuiLocale(
    code: 'it_IT',
    nativeName: 'Italiano',
    englishName: 'Italian',
    htmlLanguage: 'it-IT',
  ),
  HuiLocale(
    code: 'ja-JP',
    nativeName: '日本語',
    englishName: 'Japanese',
    htmlLanguage: 'ja-JP',
  ),
  HuiLocale(
    code: 'ko_KR',
    nativeName: '한국어',
    englishName: 'Korean',
    htmlLanguage: 'ko-KR',
  ),
  HuiLocale(
    code: 'lt_LT',
    nativeName: 'Lietuvių',
    englishName: 'Lithuanian',
    htmlLanguage: 'lt-LT',
  ),
  HuiLocale(
    code: 'nl_NL',
    nativeName: 'Nederlands',
    englishName: 'Dutch',
    htmlLanguage: 'nl-NL',
  ),
  HuiLocale(
    code: 'pl_PL',
    nativeName: 'Polski',
    englishName: 'Polish',
    htmlLanguage: 'pl-PL',
  ),
  HuiLocale(
    code: 'pt_PT',
    nativeName: 'Português',
    englishName: 'Portuguese',
    htmlLanguage: 'pt-PT',
  ),
  HuiLocale(
    code: 'ru_RU',
    nativeName: 'Русский',
    englishName: 'Russian',
    htmlLanguage: 'ru-RU',
  ),
  HuiLocale(
    code: 'tr_TR',
    nativeName: 'Türkçe',
    englishName: 'Turkish',
    htmlLanguage: 'tr-TR',
  ),
  HuiLocale(
    code: 'vi_VI',
    nativeName: 'Tiếng Việt',
    englishName: 'Vietnamese',
    htmlLanguage: 'vi-VN',
  ),
  HuiLocale(
    code: 'zh_CN',
    nativeName: '简体中文',
    englishName: 'Simplified Chinese',
    htmlLanguage: 'zh-CN',
  ),
  HuiLocale(
    code: 'zh_TW',
    nativeName: '繁體中文',
    englishName: 'Traditional Chinese',
    htmlLanguage: 'zh-TW',
  ),
];

HuiLocale huiLocale(String code) {
  final String canonical = canonicalHuiLocale(code);
  return huiSupportedLocales.firstWhere(
    (HuiLocale locale) => locale.code == canonical,
  );
}

String canonicalHuiLocale(String code) {
  final String normalized = code.trim().replaceAll('-', '_').toLowerCase();
  for (final HuiLocale locale in huiSupportedLocales) {
    if (locale.code.replaceAll('-', '_').toLowerCase() == normalized ||
        locale.htmlLanguage.replaceAll('-', '_').toLowerCase() == normalized) {
      return locale.code;
    }
  }
  throw ArgumentError.value(code, 'code', 'Unsupported Gloss Editor locale.');
}

String? matchHuiLocale(Iterable<String> preferences) {
  for (final String preference in preferences) {
    try {
      return canonicalHuiLocale(preference);
    } on ArgumentError {
      final String normalized = preference
          .trim()
          .replaceAll('_', '-')
          .toLowerCase();
      final String language = normalized.split('-').first;
      if (language == 'zh') {
        final List<String> parts = normalized.split('-');
        if (parts.any(
          (String part) =>
              part == 'tw' || part == 'hk' || part == 'mo' || part == 'hant',
        )) {
          return 'zh_TW';
        }
        return 'zh_CN';
      }
      for (final HuiLocale locale in huiSupportedLocales) {
        if (locale.htmlLanguage.toLowerCase().split('-').first == language) {
          return locale.code;
        }
      }
    }
  }
  return null;
}

final class HuiLocaleSnapshot {
  const HuiLocaleSnapshot({
    required this.locale,
    required this.messages,
    required this.contexts,
    required this.plurals,
    required this.previewMessages,
  });

  factory HuiLocaleSnapshot.english() => const HuiLocaleSnapshot(
    locale: huiEnglishLocale,
    messages: <String, String>{},
    contexts: <String, String>{},
    plurals: <String, Map<HuiPluralForm, String>>{},
    previewMessages: <String, String>{},
  );

  final String locale;
  final Map<String, String> messages;
  final Map<String, String> contexts;
  final Map<String, Map<HuiPluralForm, String>> plurals;
  final Map<String, String> previewMessages;
}

enum HuiPluralForm { zero, one, two, few, many, other }

final class HuiLocaleInstallResult {
  const HuiLocaleInstallResult._({
    required this.applied,
    required this.locale,
    this.error,
  });

  const HuiLocaleInstallResult.applied(String locale)
    : this._(applied: true, locale: locale);

  const HuiLocaleInstallResult.rejected(String locale, String error)
    : this._(applied: false, locale: locale, error: error);

  final bool applied;
  final String locale;
  final String? error;
}

final class HuiLocalizations {
  HuiLocaleSnapshot _snapshot = HuiLocaleSnapshot.english();

  HuiLocaleSnapshot get snapshot => _snapshot;

  String get activeLocale => _snapshot.locale;

  String text(
    String english, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) {
    final String template = _snapshot.messages[english] ?? english;
    return _interpolate(template, arguments);
  }

  String contextualText(
    String id,
    String english, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) {
    final String template = _snapshot.contexts[id] ?? english;
    return _interpolate(template, arguments);
  }

  String plural(
    String key,
    int count, {
    required String oneEnglish,
    required String otherEnglish,
    String? zeroEnglish,
    String? twoEnglish,
    String? fewEnglish,
    String? manyEnglish,
    Map<String, Object?> arguments = const <String, Object?>{},
  }) {
    final HuiPluralForm form = _pluralForm(_snapshot.locale, count);
    final Map<HuiPluralForm, String>? translations = _snapshot.plurals[key];
    final String template =
        translations?[form] ??
        translations?[HuiPluralForm.other] ??
        _englishPluralTemplate(
          form,
          oneEnglish: oneEnglish,
          otherEnglish: otherEnglish,
          zeroEnglish: zeroEnglish,
          twoEnglish: twoEnglish,
          fewEnglish: fewEnglish,
          manyEnglish: manyEnglish,
        );
    final Map<String, Object?> values = <String, Object?>{
      ...arguments,
      'count': count,
    };
    return template.replaceAllMapped(_huiPlaceholderPattern, (Match match) {
      final String name = match.group(1)!;
      return values.containsKey(name) ? '${values[name] ?? ''}' : match[0]!;
    });
  }

  HuiLocaleInstallResult installJson(String expectedLocale, String source) {
    final String locale;
    try {
      locale = canonicalHuiLocale(expectedLocale);
    } on ArgumentError catch (error) {
      return HuiLocaleInstallResult.rejected(
        expectedLocale,
        error.message?.toString() ?? error.toString(),
      );
    }
    try {
      final Object? decoded = jsonDecode(source);
      if (decoded is! Map<String, Object?>) {
        return HuiLocaleInstallResult.rejected(
          locale,
          'Locale source must be a JSON object.',
        );
      }
      final Object? declared = decoded['locale'];
      if (declared is! String || canonicalHuiLocale(declared) != locale) {
        return HuiLocaleInstallResult.rejected(
          locale,
          'Locale source must declare locale $locale.',
        );
      }
      final Map<String, String>? messages = _stringMap(decoded['messages']);
      final Map<String, String>? contexts = _stringMap(decoded['contexts']);
      final Map<String, Map<HuiPluralForm, String>>? plurals = _pluralMap(
        decoded['plurals'],
      );
      final Map<String, String>? previewMessages = _stringMap(
        decoded['previewMessages'],
      );
      if (messages == null ||
          contexts == null ||
          plurals == null ||
          previewMessages == null) {
        return HuiLocaleInstallResult.rejected(
          locale,
          'Locale messages, contexts, plurals, and previewMessages are invalid.',
        );
      }
      for (final MapEntry<String, String> message in messages.entries) {
        if (!_sameNames(
          _placeholderNames(message.key),
          _placeholderNames(message.value),
        )) {
          return HuiLocaleInstallResult.rejected(
            locale,
            'Locale message "${message.key}" changes its placeholders.',
          );
        }
      }
      final HuiLocaleSnapshot next = HuiLocaleSnapshot(
        locale: locale,
        messages: Map<String, String>.unmodifiable(messages),
        contexts: Map<String, String>.unmodifiable(contexts),
        plurals: Map<String, Map<HuiPluralForm, String>>.unmodifiable(plurals),
        previewMessages: Map<String, String>.unmodifiable(previewMessages),
      );
      _snapshot = next;
      return HuiLocaleInstallResult.applied(locale);
    } on FormatException catch (error) {
      return HuiLocaleInstallResult.rejected(locale, error.message);
    } on ArgumentError catch (error) {
      return HuiLocaleInstallResult.rejected(
        locale,
        error.message?.toString() ?? error.toString(),
      );
    }
  }

  void resetToEnglish() {
    _snapshot = HuiLocaleSnapshot.english();
  }

  void installSnapshot(HuiLocaleSnapshot snapshot) {
    _snapshot = snapshot;
  }

  static Map<String, String>? _stringMap(Object? value) {
    if (value is! Map<String, Object?>) return null;
    final Map<String, String> messages = <String, String>{};
    for (final MapEntry<String, Object?> entry in value.entries) {
      if (entry.value is! String || (entry.value as String).trim().isEmpty) {
        return null;
      }
      messages[entry.key] = entry.value as String;
    }
    return messages;
  }

  static Map<String, Map<HuiPluralForm, String>>? _pluralMap(Object? value) {
    if (value is! Map<String, Object?>) return null;
    final Map<String, Map<HuiPluralForm, String>> messages =
        <String, Map<HuiPluralForm, String>>{};
    for (final MapEntry<String, Object?> entry in value.entries) {
      final Object? rawForms = entry.value;
      if (rawForms is! Map<String, Object?>) return null;
      final Map<HuiPluralForm, String> forms = <HuiPluralForm, String>{};
      for (final MapEntry<String, Object?> formEntry in rawForms.entries) {
        HuiPluralForm? form;
        for (final HuiPluralForm candidate in HuiPluralForm.values) {
          if (candidate.name == formEntry.key) {
            form = candidate;
            break;
          }
        }
        if (form == null ||
            formEntry.value is! String ||
            (formEntry.value as String).trim().isEmpty) {
          return null;
        }
        forms[form] = formEntry.value as String;
      }
      if (!forms.containsKey(HuiPluralForm.other)) return null;
      messages[entry.key] = Map<HuiPluralForm, String>.unmodifiable(forms);
    }
    return messages;
  }

  static Set<String> _placeholderNames(String value) => _huiPlaceholderPattern
      .allMatches(value)
      .map((RegExpMatch match) => match.group(1)!)
      .toSet();

  static bool _sameNames(Set<String> left, Set<String> right) =>
      left.length == right.length && left.containsAll(right);

  static String _interpolate(String template, Map<String, Object?> arguments) {
    if (arguments.isEmpty) return template;
    return template.replaceAllMapped(_huiPlaceholderPattern, (Match match) {
      final String name = match.group(1)!;
      return arguments.containsKey(name)
          ? '${arguments[name] ?? ''}'
          : match[0]!;
    });
  }

  static HuiPluralForm _pluralForm(String locale, int count) {
    final int absolute = count.abs();
    final int mod10 = absolute % 10;
    final int mod100 = absolute % 100;
    return switch (locale) {
      'fr_FR' =>
        absolute == 0 || absolute == 1
            ? HuiPluralForm.one
            : absolute % 1000000 == 0
            ? HuiPluralForm.many
            : HuiPluralForm.other,
      'es_ES' || 'it_IT' || 'pt_PT' =>
        absolute == 1
            ? HuiPluralForm.one
            : absolute > 0 && absolute % 1000000 == 0
            ? HuiPluralForm.many
            : HuiPluralForm.other,
      'he_IL' =>
        absolute == 1
            ? HuiPluralForm.one
            : absolute == 2
            ? HuiPluralForm.two
            : HuiPluralForm.other,
      'lt_LT' =>
        mod10 == 1 && (mod100 < 11 || mod100 > 19)
            ? HuiPluralForm.one
            : mod10 >= 2 && mod10 <= 9 && (mod100 < 11 || mod100 > 19)
            ? HuiPluralForm.few
            : HuiPluralForm.other,
      'pl_PL' =>
        absolute == 1
            ? HuiPluralForm.one
            : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
            ? HuiPluralForm.few
            : HuiPluralForm.many,
      'ru_RU' =>
        mod10 == 1 && mod100 != 11
            ? HuiPluralForm.one
            : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
            ? HuiPluralForm.few
            : HuiPluralForm.many,
      'ja-JP' || 'ko_KR' || 'zh_CN' || 'zh_TW' => HuiPluralForm.other,
      'tr_TR' => absolute == 1 ? HuiPluralForm.one : HuiPluralForm.other,
      'vi_VI' =>
        absolute == 0 || absolute == 1
            ? HuiPluralForm.one
            : HuiPluralForm.other,
      _ => absolute == 1 ? HuiPluralForm.one : HuiPluralForm.other,
    };
  }

  static String _englishPluralTemplate(
    HuiPluralForm form, {
    required String oneEnglish,
    required String otherEnglish,
    String? zeroEnglish,
    String? twoEnglish,
    String? fewEnglish,
    String? manyEnglish,
  }) => switch (form) {
    HuiPluralForm.zero => zeroEnglish ?? otherEnglish,
    HuiPluralForm.one => oneEnglish,
    HuiPluralForm.two => twoEnglish ?? otherEnglish,
    HuiPluralForm.few => fewEnglish ?? otherEnglish,
    HuiPluralForm.many => manyEnglish ?? otherEnglish,
    HuiPluralForm.other => otherEnglish,
  };
}

final HuiLocalizations huiLocalizations = HuiLocalizations();

String huiText(
  String english, [
  Map<String, Object?> arguments = const <String, Object?>{},
]) => huiLocalizations.text(english, arguments);

String huiTextKey(
  String id,
  String english, [
  Map<String, Object?> arguments = const <String, Object?>{},
]) => huiLocalizations.contextualText(id, english, arguments);

String huiPlural(
  String key,
  int count, {
  required String oneEnglish,
  required String otherEnglish,
  String? zeroEnglish,
  String? twoEnglish,
  String? fewEnglish,
  String? manyEnglish,
  Map<String, Object?> arguments = const <String, Object?>{},
}) => huiLocalizations.plural(
  key,
  count,
  oneEnglish: oneEnglish,
  otherEnglish: otherEnglish,
  zeroEnglish: zeroEnglish,
  twoEnglish: twoEnglish,
  fewEnglish: fewEnglish,
  manyEnglish: manyEnglish,
  arguments: arguments,
);

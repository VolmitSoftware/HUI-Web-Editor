import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:gloss_editor/l10n/hui_locale_loader.dart';
import 'package:gloss_editor/l10n/hui_locale_preferences.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

void main() {
  test('locale manifest matches the shared plugin locale set', () {
    expect(
      huiSupportedLocales.map((HuiLocale locale) => locale.code).toList(),
      <String>[
        'en_US',
        'de_DE',
        'es_ES',
        'fi_FI',
        'fr_FR',
        'he_IL',
        'it_IT',
        'ja-JP',
        'ko_KR',
        'lt_LT',
        'nl_NL',
        'pl_PL',
        'pt_PT',
        'ru_RU',
        'tr_TR',
        'vi_VI',
        'zh_CN',
        'zh_TW',
      ],
    );
    expect(huiLocale('he_IL').rightToLeft, isTrue);
    expect(
      huiSupportedLocales
          .where((HuiLocale locale) => locale.code != 'he_IL')
          .every((HuiLocale locale) => !locale.rightToLeft),
      isTrue,
    );
  });

  test('canonicalizes plugin and browser locale spellings', () {
    expect(canonicalHuiLocale('ja_JP'), 'ja-JP');
    expect(canonicalHuiLocale('ZH-tw'), 'zh_TW');
    expect(canonicalHuiLocale('vi-VN'), 'vi_VI');
    expect(matchHuiLocale(<String>['en-GB', 'fr-CA']), 'en_US');
    expect(matchHuiLocale(<String>['en-GB', 'fr-FR']), 'en_US');
    expect(matchHuiLocale(<String>['fr-CA']), 'fr_FR');
    expect(matchHuiLocale(<String>['zh-Hant-HK']), 'zh_TW');
    expect(matchHuiLocale(<String>['zh-MO']), 'zh_TW');
    expect(matchHuiLocale(<String>['zh-Mong']), 'zh_CN');
    expect(matchHuiLocale(<String>['pt-BR']), 'pt_PT');
    expect(() => canonicalHuiLocale('en_GB'), throwsArgumentError);
  });

  test('maps canonical locale spellings to install manifests', () {
    expect(huiLocaleManifestPath('he-IL'), '/manifests/he_IL.webmanifest');
    expect(huiLocaleManifestPath('ja_JP'), '/manifests/ja-JP.webmanifest');
    expect(() => huiLocaleManifestPath('en_GB'), throwsArgumentError);
  });

  test('resolves stored locale before browser preferences', () {
    expect(
      resolveInitialHuiLocale(
        storedLocale: 'de_DE',
        browserLanguages: <String>['fr-FR'],
      ),
      'de_DE',
    );
    expect(
      resolveInitialHuiLocale(
        storedLocale: 'invalid',
        browserLanguages: <String>['he-IL'],
      ),
      'he_IL',
    );
  });

  test('installs UI and preview messages atomically', () {
    final HuiLocalizations localizations = HuiLocalizations();
    final HuiLocaleInstallResult result = localizations.installJson(
      'de_DE',
      jsonEncode(<String, Object?>{
        'locale': 'de_DE',
        'messages': <String, String>{'Delete {name}?': '{name} löschen?'},
        'contexts': <String, String>{
          'actions.sound.pitch': 'Tonhöhe',
          'orientation.pitch': 'Neigung',
        },
        'plurals': <String, Object?>{},
        'previewMessages': <String, String>{
          'gloss.preview.state.waiting': 'Warten',
        },
      }),
    );

    expect(result.applied, isTrue);
    expect(
      localizations.text('Delete {name}?', <String, Object?>{'name': 'menu'}),
      'menu löschen?',
    );
    expect(
      localizations.snapshot.previewMessages['gloss.preview.state.waiting'],
      'Warten',
    );
    expect(
      localizations.contextualText('actions.sound.pitch', 'Pitch'),
      'Tonhöhe',
    );
    expect(
      localizations.contextualText('orientation.pitch', 'Pitch'),
      'Neigung',
    );
    expect(
      localizations.text('Missing English source'),
      'Missing English source',
    );
  });

  test('rejected locale leaves the previous snapshot active', () {
    final HuiLocalizations localizations = HuiLocalizations();
    expect(
      localizations.installJson('de_DE', _source('de_DE')).applied,
      isTrue,
    );
    final HuiLocaleInstallResult result = localizations.installJson(
      'fr_FR',
      '{broken',
    );

    expect(result.applied, isFalse);
    expect(localizations.activeLocale, 'de_DE');
  });

  test('rejects changed placeholders without replacing the snapshot', () {
    final HuiLocalizations localizations = HuiLocalizations();
    expect(
      localizations.installJson('de_DE', _source('de_DE')).applied,
      isTrue,
    );
    final HuiLocaleInstallResult result = localizations.installJson(
      'fr_FR',
      jsonEncode(<String, Object?>{
        'locale': 'fr_FR',
        'messages': <String, String>{'Delete {name}?': 'Supprimer {menu} ?'},
        'contexts': <String, String>{},
        'plurals': <String, Object?>{},
        'previewMessages': <String, String>{},
      }),
    );

    expect(result.applied, isFalse);
    expect(result.error, contains('placeholders'));
    expect(localizations.activeLocale, 'de_DE');
  });

  test('rejects blank message and plural translations', () {
    final HuiLocalizations localizations = HuiLocalizations();
    expect(
      localizations.installJson('de_DE', _source('de_DE')).applied,
      isTrue,
    );

    final HuiLocaleInstallResult blankMessage = localizations.installJson(
      'fr_FR',
      jsonEncode(<String, Object?>{
        'locale': 'fr_FR',
        'messages': <String, String>{'Gloss Editor': '   '},
        'contexts': <String, String>{},
        'plurals': <String, Object?>{},
        'previewMessages': <String, String>{},
      }),
    );
    final HuiLocaleInstallResult blankPlural = localizations.installJson(
      'fr_FR',
      jsonEncode(<String, Object?>{
        'locale': 'fr_FR',
        'messages': <String, String>{},
        'contexts': <String, String>{},
        'plurals': <String, Object?>{
          'selection.count': <String, String>{
            'one': '   ',
            'other': '{count} éléments',
          },
        },
        'previewMessages': <String, String>{},
      }),
    );

    expect(blankMessage.applied, isFalse);
    expect(blankPlural.applied, isFalse);
    expect(localizations.activeLocale, 'de_DE');
  });

  test(
    'a slower replaced request cannot overwrite the newest locale',
    () async {
      final Completer<String?> german = Completer<String?>();
      final Completer<String?> french = Completer<String?>();
      final HuiLocalizations localizations = HuiLocalizations();
      final HuiLocaleController controller = HuiLocaleController(
        localizations: localizations,
        loader: (String locale) => switch (locale) {
          'en_US' => Future<String?>.value(_source('en_US')),
          'de_DE' => german.future,
          'fr_FR' => french.future,
          _ => Future<String?>.value(null),
        },
      );

      expect((await controller.activate('en_US')).applied, isTrue);
      final Future<HuiLocaleInstallResult> first = controller.activate('de_DE');
      final Future<HuiLocaleInstallResult> second = controller.activate(
        'fr_FR',
      );
      french.complete(_source('fr_FR'));
      expect((await second).applied, isTrue);
      german.complete(_source('de_DE'));
      expect((await first).applied, isFalse);
      expect(localizations.activeLocale, 'fr_FR');
    },
  );

  test(
    'rejects incomplete catalogs without replacing the active locale',
    () async {
      final HuiLocalizations localizations = HuiLocalizations();
      final HuiLocaleController controller = HuiLocaleController(
        localizations: localizations,
        loader: (String locale) => Future<String?>.value(
          locale == 'fr_FR'
              ? jsonEncode(<String, Object?>{
                  'locale': 'fr_FR',
                  'messages': <String, String>{},
                  'contexts': <String, String>{},
                  'plurals': <String, Object?>{},
                  'previewMessages': <String, String>{},
                })
              : _source(locale),
        ),
      );

      expect((await controller.activate('de_DE')).applied, isTrue);
      final HuiLocaleInstallResult result = await controller.activate('fr_FR');

      expect(result.applied, isFalse);
      expect(result.error, contains('complete English catalog'));
      expect(localizations.activeLocale, 'de_DE');
    },
  );

  test('loads shipped catalogs with plural-specific placeholders', () async {
    final HuiLocalizations localizations = HuiLocalizations();
    final HuiLocaleController controller = HuiLocaleController(
      localizations: localizations,
      loader: (String locale) async {
        final File source = File('l10n/$locale.json');
        return source.existsSync() ? source.readAsString() : null;
      },
    );

    final HuiLocaleInstallResult result = await controller.activate('de_DE');

    expect(result.applied, isTrue, reason: result.error);
    expect(localizations.activeLocale, 'de_DE');
    expect(localizations.text('Gloss Editor'), 'Gloss-Editor');
    expect(
      localizations.plural(
        'shell.selection-noun',
        1,
        oneEnglish: 'selected component',
        otherEnglish: '{count} selected components',
      ),
      'ausgewählte Komponente',
    );
  });

  test(
    'rejects preview placeholder drift against the English schema',
    () async {
      final HuiLocalizations localizations = HuiLocalizations();
      final HuiLocaleController controller = HuiLocaleController(
        localizations: localizations,
        loader: (String locale) => Future<String?>.value(
          jsonEncode(<String, Object?>{
            'locale': locale,
            'messages': <String, String>{},
            'contexts': <String, String>{},
            'plurals': <String, Object?>{},
            'previewMessages': <String, String>{
              'gloss.preview.sample': locale == 'en_US'
                  ? 'Viewing {name}'
                  : 'Anzeige {document}',
            },
          }),
        ),
      );

      final HuiLocaleInstallResult result = await controller.activate('de_DE');

      expect(result.applied, isFalse);
      expect(localizations.activeLocale, huiEnglishLocale);
    },
  );

  test('rejects missing locale-required plural forms', () async {
    final HuiLocalizations localizations = HuiLocalizations();
    final HuiLocaleController controller = HuiLocaleController(
      localizations: localizations,
      loader: (String locale) => Future<String?>.value(
        jsonEncode(<String, Object?>{
          'locale': locale,
          'messages': <String, String>{},
          'contexts': <String, String>{},
          'plurals': <String, Object?>{
            'selection.count': locale == 'en_US'
                ? <String, String>{
                    'one': '{count} selected',
                    'other': '{count} selected',
                  }
                : <String, String>{'other': '{count} ausgewählt'},
          },
          'previewMessages': <String, String>{},
        }),
      ),
    );

    final HuiLocaleInstallResult result = await controller.activate('de_DE');

    expect(result.applied, isFalse);
    expect(localizations.activeLocale, huiEnglishLocale);
  });

  test('rejects plural forms the locale does not use', () async {
    final HuiLocalizations localizations = HuiLocalizations();
    final HuiLocaleController controller = HuiLocaleController(
      localizations: localizations,
      loader: (String locale) => Future<String?>.value(
        jsonEncode(<String, Object?>{
          'locale': locale,
          'messages': <String, String>{},
          'contexts': <String, String>{},
          'plurals': <String, Object?>{
            'selection.count': locale == 'en_US'
                ? <String, String>{
                    'one': '{count} selected',
                    'other': '{count} selected',
                  }
                : <String, String>{
                    'one': '{count} נבחר',
                    'two': '{count} נבחרו',
                    'many': '{count} נבחרו',
                    'other': '{count} נבחרו',
                  },
          },
          'previewMessages': <String, String>{},
        }),
      ),
    );

    final HuiLocaleInstallResult result = await controller.activate('he_IL');

    expect(result.applied, isFalse);
    expect(localizations.activeLocale, huiEnglishLocale);
  });

  test('selects locale-specific plural forms and interpolates count', () {
    final HuiLocalizations localizations = HuiLocalizations();
    final HuiLocaleInstallResult result = localizations.installJson(
      'ru_RU',
      jsonEncode(<String, Object?>{
        'locale': 'ru_RU',
        'messages': <String, String>{},
        'contexts': <String, String>{},
        'plurals': <String, Object?>{
          'selection.count': <String, String>{
            'one': '{count} выбран',
            'few': '{count} выбрано',
            'many': '{count} выбрано много',
            'other': '{count} выбрано',
          },
        },
        'previewMessages': <String, String>{},
      }),
    );

    expect(result.applied, isTrue);
    expect(
      localizations.plural(
        'selection.count',
        1,
        oneEnglish: '{count} selected',
        otherEnglish: '{count} selected',
      ),
      '1 выбран',
    );
    expect(
      localizations.plural(
        'selection.count',
        2,
        oneEnglish: '{count} selected',
        otherEnglish: '{count} selected',
      ),
      '2 выбрано',
    );
    expect(
      localizations.plural(
        'selection.count',
        5,
        oneEnglish: '{count} selected',
        otherEnglish: '{count} selected',
      ),
      '5 выбрано много',
    );
  });

  test('uses the supported locales plural rules', () {
    final Map<String, Map<int, String>> expectations =
        <String, Map<int, String>>{
          'en_US': <int, String>{0: 'other', 1: 'one', 2: 'other'},
          'es_ES': <int, String>{
            1: 'one',
            2: 'other',
            1000000: 'many',
            2000000: 'many',
            1000001: 'other',
          },
          'fr_FR': <int, String>{
            0: 'one',
            1: 'one',
            2: 'other',
            1000000: 'many',
            1000001: 'other',
          },
          'it_IT': <int, String>{1: 'one', 2: 'other', 1000000: 'many'},
          'pt_PT': <int, String>{1: 'one', 2: 'other', 1000000: 'many'},
          'he_IL': <int, String>{
            0: 'other',
            1: 'one',
            2: 'two',
            3: 'other',
            10: 'other',
            20: 'other',
            100: 'other',
            101: 'other',
          },
          'lt_LT': <int, String>{1: 'one', 2: 'few', 11: 'other'},
          'pl_PL': <int, String>{1: 'one', 2: 'few', 5: 'many', 12: 'many'},
          'ru_RU': <int, String>{1: 'one', 2: 'few', 5: 'many', 11: 'many'},
          'tr_TR': <int, String>{0: 'other', 1: 'one', 2: 'other'},
          'vi_VI': <int, String>{0: 'one', 1: 'one', 2: 'other'},
          'ja-JP': <int, String>{0: 'other', 1: 'other', 2: 'other'},
          'zh_CN': <int, String>{0: 'other', 1: 'other', 2: 'other'},
        };
    for (final MapEntry<String, Map<int, String>> locale
        in expectations.entries) {
      final HuiLocalizations localizations = HuiLocalizations();
      final HuiLocaleInstallResult result = localizations.installJson(
        locale.key,
        jsonEncode(<String, Object?>{
          'locale': locale.key,
          'messages': <String, String>{},
          'contexts': <String, String>{},
          'plurals': <String, Object?>{
            'forms': <String, String>{
              'zero': 'zero',
              'one': 'one',
              'two': 'two',
              'few': 'few',
              'many': 'many',
              'other': 'other',
            },
          },
          'previewMessages': <String, String>{},
        }),
      );
      expect(result.applied, isTrue, reason: locale.key);
      for (final MapEntry<int, String> expectation in locale.value.entries) {
        expect(
          localizations.plural(
            'forms',
            expectation.key,
            oneEnglish: 'one',
            otherEnglish: 'other',
          ),
          expectation.value,
          reason: '${locale.key}:${expectation.key}',
        );
      }
    }
  });

  test('rejects plural placeholders absent from the English schema', () async {
    final HuiLocalizations localizations = HuiLocalizations();
    final HuiLocaleController controller = HuiLocaleController(
      localizations: localizations,
      loader: (String locale) => Future<String?>.value(
        jsonEncode(<String, Object?>{
          'locale': locale,
          'messages': <String, String>{},
          'contexts': <String, String>{},
          'plurals': <String, Object?>{
            'selection.count': locale == huiEnglishLocale
                ? <String, String>{
                    'one': '{count} selected',
                    'other': '{count} selected',
                  }
                : <String, String>{
                    'one': '{count} ausgewählt',
                    'other': '{total} ausgewählt',
                  },
          },
          'previewMessages': <String, String>{},
        }),
      ),
    );

    final HuiLocaleInstallResult result = await controller.activate('de_DE');

    expect(result.applied, isFalse);
    expect(localizations.activeLocale, huiEnglishLocale);
  });
}

String _source(String locale) => jsonEncode(<String, Object?>{
  'locale': locale,
  'messages': <String, String>{'Gloss Editor': '$locale Gloss Editor'},
  'contexts': <String, String>{},
  'plurals': <String, Object?>{},
  'previewMessages': <String, String>{},
});

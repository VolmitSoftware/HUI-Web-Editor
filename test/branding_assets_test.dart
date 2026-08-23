import 'dart:convert';
import 'dart:io';

import 'package:gloss_editor/l10n/hui_localizations.dart';
import 'package:test/test.dart';

void main() {
  test('Gloss brand assets are wired through the shell and document head', () {
    final String index = File('web/index.html').readAsStringSync();
    final String topBar = File(
      'lib/components/shell/top_bar.dart',
    ).readAsStringSync();

    expect(index, contains('<title>Gloss Editor</title>'));
    expect(index, contains('<link id="hui-manifest" rel="manifest">'));
    expect(index, contains("'href', '/manifests/' + locale + '.webmanifest'"));
    expect(index, contains('assets/brand/apple-touch-icon.png'));
    expect(index, contains('assets/brand/icon-512x512.png'));
    expect(topBar, contains("src: 'assets/brand/logo.png'"));

    const List<String> assets = <String>[
      'web/assets/brand/logo.png',
      'web/assets/brand/favicon-16x16.png',
      'web/assets/brand/favicon-32x32.png',
      'web/assets/brand/apple-touch-icon.png',
      'web/assets/brand/icon-192x192.png',
      'web/assets/brand/icon-512x512.png',
      'web/favicon.ico',
    ];
    for (final String asset in assets) {
      expect(File(asset).lengthSync(), greaterThan(0), reason: asset);
    }
  });

  test('the document has one title and description metadata owner', () {
    final String index = File('web/index.html').readAsStringSync();
    final String app = File('lib/app.dart').readAsStringSync();
    final String platform = File(
      'lib/l10n/hui_locale_platform_web.dart',
    ).readAsStringSync();
    final int arcaneAppStart = app.indexOf('ArcaneApp(');
    final int fallbackScriptsStart = app.indexOf(
      'includeFallbackScripts:',
      arcaneAppStart,
    );
    expect(arcaneAppStart, isNonNegative);
    expect(fallbackScriptsStart, greaterThan(arcaneAppStart));
    final String arcaneAppHeadArguments = app.substring(
      arcaneAppStart,
      fallbackScriptsStart,
    );

    expect(RegExp(r'<title(?:\s[^>]*)?>').allMatches(index), hasLength(1));
    expect(
      RegExp(
        r'<meta\s+name=["\x27]description["\x27](?:\s[^>]*)?>',
      ).allMatches(index),
      hasLength(1),
    );
    expect(arcaneAppHeadArguments, isNot(contains('title:')));
    expect(arcaneAppHeadArguments, isNot(contains('description:')));
    expect(platform, contains('web.document.title = title;'));
    expect(
      platform,
      contains(
        '''_setMeta('meta[name="description"]', 'content', description);''',
      ),
    );
  });

  test('every locale has matching install metadata and Gloss icons', () {
    final List<String> manifestFiles =
        Directory('web/manifests')
            .listSync()
            .whereType<File>()
            .map((File file) => file.uri.pathSegments.last)
            .toList()
          ..sort();
    final List<String> expectedFiles =
        huiSupportedLocales
            .map((HuiLocale locale) => '${locale.code}.webmanifest')
            .toList()
          ..sort();
    expect(manifestFiles, expectedFiles);

    for (final HuiLocale locale in huiSupportedLocales) {
      final Map<String, Object?> catalog =
          jsonDecode(
                File('web/languages/${locale.code}.json').readAsStringSync(),
              )
              as Map<String, Object?>;
      final Map<String, Object?> messages =
          catalog['messages'] as Map<String, Object?>;
      final Map<String, Object?> manifest =
          jsonDecode(
                File(
                  'web/manifests/${locale.code}.webmanifest',
                ).readAsStringSync(),
              )
              as Map<String, Object?>;

      expect(
        manifest['name'],
        messages[huiDocumentTitleSource],
        reason: locale.code,
      );
      expect(
        manifest['description'],
        messages[huiDocumentDescriptionSource],
        reason: locale.code,
      );
      expect(manifest['short_name'], 'Gloss', reason: locale.code);
      expect(manifest['lang'], locale.htmlLanguage, reason: locale.code);
      expect(
        manifest['dir'],
        locale.rightToLeft ? 'rtl' : 'ltr',
        reason: locale.code,
      );
      expect(manifest['start_url'], '/', reason: locale.code);
      expect(manifest['icons'], isA<List<Object?>>(), reason: locale.code);
      expect(
        jsonEncode(manifest['icons']),
        allOf(contains('icon-192x192.png'), contains('icon-512x512.png')),
        reason: locale.code,
      );
    }
  });

  test('a live locale stamp swaps the linked install manifest', () {
    final String platform = File(
      'lib/l10n/hui_locale_platform_web.dart',
    ).readAsStringSync();

    expect(
      platform,
      contains(
        "_setAttribute('link[rel=\"manifest\"]', 'href', manifestPath);",
      ),
    );
    expect(File('web/manifest.webmanifest').existsSync(), isFalse);
  });

  test('retired HoloUI brand artwork is removed', () {
    const List<String> retiredAssets = <String>[
      'web/assets/brand/logo.svg',
      'web/assets/brand/logo.webp',
      'web/assets/brand/background.svg',
    ];
    for (final String asset in retiredAssets) {
      expect(File(asset).existsSync(), isFalse, reason: asset);
    }
  });
}

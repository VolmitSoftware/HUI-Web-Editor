import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('Gloss brand assets are wired through the shell and document head', () {
    final String index = File('web/index.html').readAsStringSync();
    final String topBar = File(
      'lib/components/shell/top_bar.dart',
    ).readAsStringSync();

    expect(index, contains('<title>Gloss Editor</title>'));
    expect(index, contains('href="manifest.webmanifest"'));
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

  test('web manifest is valid and references the Gloss install icons', () {
    final Map<String, Object?> manifest =
        jsonDecode(File('web/manifest.webmanifest').readAsStringSync())
            as Map<String, Object?>;
    expect(manifest['name'], 'Gloss Editor');
    expect(manifest['short_name'], 'Gloss');
    expect(manifest['start_url'], '/');
    expect(manifest['icons'], isA<List<Object?>>());
    expect(
      jsonEncode(manifest['icons']),
      allOf(contains('icon-192x192.png'), contains('icon-512x512.png')),
    );
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

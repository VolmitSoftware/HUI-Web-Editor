/// VM coverage for the pure-Dart half of `lib/services/`: path rules, guarded
/// storage, library persistence and zip export. The browser halves (canvas
/// decode, Blob download, clipboard) are stubbed off-web and are verified in the
/// integrator's browser pass.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:holoui_editor/services/image_library.dart';
import 'package:holoui_editor/services/storage_service.dart';
import 'package:test/test.dart';

void main() {
  setUp(StorageService.clearAll);

  group('sanitizeImagePath', () {
    test('rewrites separators and strips traversal', () {
      expect(sanitizeImagePath(r'icons\shop.png'), 'icons/shop.png');
      expect(sanitizeImagePath('/leading.png'), 'leading.png');
      expect(sanitizeImagePath('../../etc/passwd.png'), 'etc/passwd.png');
      expect(sanitizeImagePath('C:/win.png'), 'C/win.png');
      expect(sanitizeImagePath('a//b.png'), 'a/b.png');
      expect(sanitizeImagePath('   '), 'image.png');
    });

    test('truncates to the path limit while keeping the extension', () {
      final String long = '${'a' * 400}.png';
      final String sanitized = sanitizeImagePath(long);
      expect(sanitized.length, huiMaxImagePathLength);
      expect(sanitized.endsWith('.png'), isTrue);
    });

    test('output always passes validation', () {
      const List<String> inputs = <String>[
        r'..\..\a:b//c.png',
        '/',
        'ok.png',
      ];
      for (final String input in inputs) {
        expect(validateImagePath(sanitizeImagePath(input)), isNull, reason: input);
      }
    });
  });

  group('validateImagePath', () {
    test('accepts a relative forward-slash path', () {
      expect(validateImagePath('icons/shop.png'), isNull);
    });

    test('rejects the HoloUI-illegal forms', () {
      expect(validateImagePath(''), isNotNull);
      expect(validateImagePath('/abs.png'), isNotNull);
      expect(validateImagePath(r'win\path.png'), isNotNull);
      expect(validateImagePath('c:/x.png'), isNotNull);
      expect(validateImagePath('../x.png'), isNotNull);
      expect(validateImagePath('dir/'), isNotNull);
      expect(validateImagePath('${'a' * 300}.png'), isNotNull);
    });
  });

  group('StorageService', () {
    test('round-trips values and reports writes', () {
      expect(StorageService.write('holoui.demo', 'v'), isTrue);
      expect(StorageService.read('holoui.demo'), 'v');
      StorageService.remove('holoui.demo');
      expect(StorageService.read('holoui.demo'), isNull);
    });

    test('keys and usage only cover the holoui prefix', () {
      StorageService.write('holoui.a', '12345');
      StorageService.write('other.b', '12345');
      expect(StorageService.keys(), <String>['holoui.a']);
      expect(StorageService.estimateUsageBytes(), ('holoui.a'.length + 5) * 2);
      StorageService.remove('other.b');
    });

    test('missing keys read as null', () {
      expect(StorageService.read('holoui.missing'), isNull);
    });
  });

  group('ImageLibrary', () {
    String dataUri(List<int> bytes) => 'data:image/png;base64,${base64Encode(bytes)}';

    void seed(List<Map<String, Object>> entries) {
      StorageService.write(ImageLibrary.storageKey, jsonEncode(entries));
    }

    test('loads persisted entries', () {
      seed(<Map<String, Object>>[
        <String, Object>{
          'path': 'icons/shop.png',
          'dataUri': dataUri(<int>[1, 2, 3]),
          'width': 8,
          'height': 8,
        },
      ]);
      final ImageLibrary library = ImageLibrary();
      expect(library.images.length, 1);
      expect(library.paths, <String>{'icons/shop.png'});
      expect(library.byPath('icons/shop.png')!.width, 8);
      expect(library.contains('nope.png'), isFalse);
    });

    test('survives a corrupt payload', () {
      StorageService.write(ImageLibrary.storageKey, '{not json');
      final ImageLibrary library = ImageLibrary();
      expect(library.images, isEmpty);
      expect(library.lastError, isNotNull);
    });

    test('rename validates, de-duplicates and persists', () {
      seed(<Map<String, Object>>[
        <String, Object>{'path': 'a.png', 'dataUri': dataUri(<int>[1]), 'width': 4, 'height': 4},
        <String, Object>{'path': 'b.png', 'dataUri': dataUri(<int>[2]), 'width': 4, 'height': 4},
      ]);
      final ImageLibrary library = ImageLibrary();
      expect(library.rename('a.png', 'b.png'), isFalse);
      expect(library.rename('missing.png', 'c.png'), isFalse);
      expect(library.rename('a.png', r'/sub\c.png'), isTrue);
      expect(library.paths.contains('sub/c.png'), isTrue);

      final ImageLibrary reloaded = ImageLibrary();
      expect(reloaded.paths, <String>{'sub/c.png', 'b.png'});
    });

    test('rename forces the png extension used by the stored bytes', () {
      seed(<Map<String, Object>>[
        <String, Object>{'path': 'a.png', 'dataUri': dataUri(<int>[1]), 'width': 4, 'height': 4},
      ]);
      final ImageLibrary library = ImageLibrary();
      expect(library.rename('a.png', 'logo.jpg'), isTrue);
      expect(library.paths, <String>{'logo.png'});
    });

    test('remove and clear persist', () {
      seed(<Map<String, Object>>[
        <String, Object>{'path': 'a.png', 'dataUri': dataUri(<int>[1]), 'width': 4, 'height': 4},
        <String, Object>{'path': 'b.png', 'dataUri': dataUri(<int>[2]), 'width': 4, 'height': 4},
      ]);
      final ImageLibrary library = ImageLibrary();
      library.remove('a.png');
      expect(ImageLibrary().paths, <String>{'b.png'});
      library.clear();
      expect(ImageLibrary().images, isEmpty);
    });

    test('notifies listeners on mutation', () {
      seed(<Map<String, Object>>[
        <String, Object>{'path': 'a.png', 'dataUri': dataUri(<int>[1]), 'width': 4, 'height': 4},
      ]);
      final ImageLibrary library = ImageLibrary();
      int notifications = 0;
      library.addListener(() => notifications++);
      library.remove('a.png');
      expect(notifications, 1);
    });

    test('zip entry names are exactly the stored paths', () async {
      seed(<Map<String, Object>>[
        <String, Object>{
          'path': 'icons/shop.png',
          'dataUri': dataUri(<int>[1, 2, 3, 4]),
          'width': 4,
          'height': 4,
        },
        <String, Object>{
          'path': 'flat.png',
          'dataUri': dataUri(<int>[9]),
          'width': 1,
          'height': 1,
        },
      ]);
      final ImageLibrary library = ImageLibrary();
      final List<int> zip = await library.exportZipBytes();
      final Archive archive = ZipDecoder().decodeBytes(Uint8List.fromList(zip));
      expect(
        archive.map((ArchiveFile f) => f.name).toList(),
        <String>['icons/shop.png', 'flat.png'],
      );
      expect(archive.findFile('icons/shop.png')!.readBytes(), <int>[1, 2, 3, 4]);
    });

    test('decode is a no-op off-web', () async {
      seed(<Map<String, Object>>[
        <String, Object>{'path': 'a.png', 'dataUri': dataUri(<int>[1]), 'width': 4, 'height': 4},
      ]);
      final ImageLibrary library = ImageLibrary();
      expect(await library.decode('a.png'), isNull);
      expect(await library.decode('missing.png'), isNull);
      expect(library.pixelsFor('a.png'), isNull);
    });

    test('usage estimate grows with the library', () {
      final ImageLibrary empty = ImageLibrary();
      final int base = empty.estimateUsageBytes();
      seed(<Map<String, Object>>[
        <String, Object>{
          'path': 'a.png',
          'dataUri': dataUri(List<int>.filled(64, 7)),
          'width': 8,
          'height': 8,
        },
      ]);
      expect(ImageLibrary().estimateUsageBytes(), greaterThan(base));
    });

    test('addFromFiles reports failure off-web without touching storage', () async {
      final ImageLibrary library = ImageLibrary();
      final ImageAddOutcome outcome = await library.addFromFiles(<Object>[Object()]);
      expect(outcome.added, isEmpty);
      expect(outcome.errors, hasLength(1));
      expect(outcome.isSuccess, isFalse);
      expect(library.images, isEmpty);
      expect(await library.addFromFiles(<Object>[]), same(ImageAddOutcome.empty));
    });
  });

  group('decodeDataUriBytes', () {
    test('decodes base64 and plain payloads', () {
      expect(decodeDataUriBytes('data:image/png;base64,${base64Encode(<int>[1, 2])}'), <int>[1, 2]);
      expect(decodeDataUriBytes('data:text/plain,hi'), utf8.encode('hi'));
      expect(decodeDataUriBytes('not-a-data-uri'), isNull);
      expect(decodeDataUriBytes('data:image/png;base64,%%%'), isNull);
    });
  });

  group('ImagePixels', () {
    test('reads in range and returns transparent outside', () {
      const ImagePixels pixels = ImagePixels(
        width: 2,
        height: 2,
        rows: <List<int>>[
          <int>[0xFFFF0000, 0xFF00FF00],
          <int>[0xFF0000FF, 0x00000000],
        ],
      );
      expect(pixels.at(1, 0), 0xFF00FF00);
      expect(pixels.at(-1, 0), 0);
      expect(pixels.at(0, 5), 0);
      expect(pixels.at(9, 1), 0);
    });
  });

  group('StoredImage', () {
    test('json round-trips and flags oversized images', () {
      const StoredImage image = StoredImage(
        path: 'a.png',
        dataUri: 'data:image/png;base64,AA==',
        width: 128,
        height: 8,
      );
      final StoredImage? parsed = StoredImage.fromJson(image.toJson());
      expect(parsed!.path, 'a.png');
      expect(parsed.width, 128);
      expect(parsed.pixelCount, 1024);
      expect(parsed.isOversized, isTrue);
      expect(StoredImage.fromJson(<String, Object?>{'path': 'x'}), isNull);
      expect(StoredImage.fromJson('nope'), isNull);
    });
  });
}

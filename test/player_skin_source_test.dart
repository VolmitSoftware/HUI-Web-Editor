/// The head-by-username path, driven against an injected HTTP client.
///
/// Nothing here reaches minotar.net or mc-heads.net: every response is
/// hand-built, so the suite is the same speed offline and the CDN cannot make it
/// flake. The one thing a live host would prove that these cannot is the exact
/// bytes it returns, which the browser verification covers instead.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:gloss_editor/l10n/hui_localizations.dart';
import 'package:gloss_editor/services/image_library.dart';
import 'package:gloss_editor/services/player_skin_source.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

Uint8List _skinPngBytes({int size = 64}) {
  final img.Image skin = img.Image(width: size, height: size, numChannels: 4);
  final int scale = size ~/ 64;
  for (int y = 8 * scale; y < 16 * scale; y++) {
    for (int x = 8 * scale; x < 16 * scale; x++) {
      skin.setPixelRgba(x, y, 200, 120, 60, 255);
    }
  }
  return img.encodePng(skin);
}

http.StreamedResponse _bytesResponse(
  int status,
  List<int> body, {
  String contentType = 'image/png',
  int? contentLength,
}) => http.StreamedResponse(
  Stream<List<int>>.value(body),
  status,
  contentLength: contentLength ?? body.length,
  headers: <String, String>{'content-type': contentType},
);

typedef _RequestHandler =
    Future<http.StreamedResponse> Function(http.BaseRequest request);

final class _HandlerClient extends http.BaseClient {
  _HandlerClient(this.handler);

  final _RequestHandler handler;
  final List<Uri> requested = <Uri>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requested.add(request.url);
    return handler(request);
  }
}

PlayerSkinSource _source(_HandlerClient client, {Duration? timeout}) =>
    PlayerSkinSource(
      client: client,
      requestTimeout: timeout ?? const Duration(seconds: 5),
    );

void main() {
  setUp(huiLocalizations.resetToEnglish);
  tearDown(huiLocalizations.resetToEnglish);

  group('isMinecraftUsername', () {
    test('accepts what Mojang issues and nothing else', () {
      expect(isMinecraftUsername('Notch'), isTrue);
      expect(isMinecraftUsername('jeb_'), isTrue);
      expect(isMinecraftUsername('a'), isTrue);
      expect(isMinecraftUsername('0123456789abcdef'), isTrue);
      expect(isMinecraftUsername('0123456789abcdefg'), isFalse);
      expect(isMinecraftUsername(''), isFalse);
      expect(isMinecraftUsername('has space'), isFalse);
      expect(isMinecraftUsername('has-dash'), isFalse);
      expect(isMinecraftUsername('%player_name%'), isFalse);
    });
  });

  group('the documented host chain', () {
    test('asks minotar.net for the full skin PNG first', () async {
      final _HandlerClient client = _HandlerClient(
        (http.BaseRequest request) async =>
            _bytesResponse(200, _skinPngBytes()),
      );

      final PlayerSkinFetch fetched = await _source(client).fetch('Notch');

      expect(fetched.isSuccess, isTrue);
      expect(fetched.host, 'minotar.net');
      expect(
        client.requested.single.toString(),
        'https://minotar.net/skin/Notch.png',
      );
      expect(fetched.pngDataUri, startsWith(huiNormalizedPngDataUriPrefix));
    });

    test('falls back to mc-heads.net when minotar does not answer', () async {
      final _HandlerClient client = _HandlerClient((
        http.BaseRequest request,
      ) async {
        if (request.url.host == 'minotar.net') {
          throw const SocketExceptionStub();
        }
        return _bytesResponse(200, _skinPngBytes());
      });

      final PlayerSkinFetch fetched = await _source(client).fetch('Notch');

      expect(fetched.isSuccess, isTrue);
      expect(fetched.host, 'mc-heads.net');
      expect(client.requested.length, 2);
      expect(client.requested.last.host, 'mc-heads.net');
    });

    test('stops after the last host and names what each one said', () async {
      final _HandlerClient client = _HandlerClient(
        (http.BaseRequest request) async => _bytesResponse(404, <int>[]),
      );

      final PlayerSkinFetch fetched = await _source(client).fetch('Nobody');

      expect(fetched.isSuccess, isFalse);
      expect(fetched.failure, PlayerSkinFailure.notFound);
      expect(fetched.message, contains('minotar.net'));
      expect(fetched.message, contains('mc-heads.net'));
      expect(client.requested.length, 2);
    });

    test('stored host failures resolve in the active locale', () async {
      final _HandlerClient client = _HandlerClient(
        (http.BaseRequest request) async => _bytesResponse(404, <int>[]),
      );
      final PlayerSkinFetch fetched = await _source(client).fetch('Nobody');

      expect(fetched.message, contains('has no skin for that name'));
      huiLocalizations.installSnapshot(
        const HuiLocaleSnapshot(
          locale: 'de_DE',
          messages: <String, String>{
            'Could not fetch a skin for "{username}": {reasons}.':
                'Für "{username}" konnte kein Skin abgerufen werden: {reasons}.',
            'has no skin for that name': 'hat keinen Skin für diesen Namen',
          },
          contexts: <String, String>{},
          plurals: <String, Map<HuiPluralForm, String>>{},
          previewMessages: <String, String>{},
        ),
      );

      expect(
        fetched.message,
        'Für "Nobody" konnte kein Skin abgerufen werden: '
        'minotar.net hat keinen Skin für diesen Namen; '
        'mc-heads.net hat keinen Skin für diesen Namen.',
      );
    });

    test('the shipped chain is minotar then mc-heads', () {
      expect(
        PlayerSkinSource.defaultHosts
            .map((PlayerSkinHost host) => host.name)
            .toList(),
        <String>['minotar.net', 'mc-heads.net'],
      );
    });
  });

  group('failures each get their own message', () {
    test('an unusable username never leaves the browser', () async {
      final _HandlerClient client = _HandlerClient(
        (http.BaseRequest request) async =>
            _bytesResponse(200, _skinPngBytes()),
      );

      final PlayerSkinFetch fetched = await _source(client).fetch('not a name');

      expect(fetched.failure, PlayerSkinFailure.invalidName);
      expect(fetched.message, contains('not a Minecraft username'));
      expect(client.requested, isEmpty);
    });

    test(
      'an empty box asks for a name rather than reporting a failure',
      () async {
        final _HandlerClient client = _HandlerClient(
          (http.BaseRequest request) async =>
              _bytesResponse(200, _skinPngBytes()),
        );

        final PlayerSkinFetch fetched = await _source(client).fetch('   ');

        expect(fetched.failure, PlayerSkinFailure.invalidName);
        expect(fetched.message, 'Type a Minecraft username first.');
        expect(client.requested, isEmpty);
      },
    );

    test(
      'being offline reads as unreachable, not as a missing player',
      () async {
        final _HandlerClient client = _HandlerClient(
          (http.BaseRequest request) async => throw const SocketExceptionStub(),
        );

        final PlayerSkinFetch fetched = await _source(client).fetch('Notch');

        expect(fetched.failure, PlayerSkinFailure.unreachable);
        expect(fetched.message, contains('could not be reached'));
      },
    );

    test('a timeout is reported as one and does not hang', () async {
      // A future that never completes, rather than a delayed one: Future.delayed
      // with no computation throws ArgumentError for a non-nullable type, which
      // would exercise the wrong branch.
      final _HandlerClient client = _HandlerClient(
        (http.BaseRequest request) => Completer<http.StreamedResponse>().future,
      );

      final PlayerSkinFetch fetched = await _source(
        client,
        timeout: const Duration(milliseconds: 20),
      ).fetch('Notch');

      expect(fetched.failure, PlayerSkinFailure.unreachable);
      expect(fetched.message, contains('did not answer in time'));
    });

    test('rate limiting is called rate limiting', () async {
      final _HandlerClient client = _HandlerClient(
        (http.BaseRequest request) async => _bytesResponse(429, <int>[]),
      );

      final PlayerSkinFetch fetched = await _source(client).fetch('Notch');

      expect(fetched.failure, PlayerSkinFailure.rateLimited);
      expect(fetched.message, contains('rate limiting'));
    });

    test('a 5xx from every host is an outage, not a missing player', () async {
      final _HandlerClient client = _HandlerClient(
        (http.BaseRequest request) async => _bytesResponse(503, <int>[]),
      );

      final PlayerSkinFetch fetched = await _source(client).fetch('Notch');

      expect(fetched.failure, PlayerSkinFailure.unreachable);
      expect(fetched.message, contains('HTTP 503'));
    });

    test(
      'a response that is not a PNG is rejected before it is stored',
      () async {
        final _HandlerClient client = _HandlerClient(
          (http.BaseRequest request) async => _bytesResponse(
            200,
            utf8.encode('<!doctype html><title>captive portal</title>'),
            contentType: 'text/html',
          ),
        );

        final PlayerSkinFetch fetched = await _source(client).fetch('Notch');

        expect(fetched.failure, PlayerSkinFailure.notASkin);
        expect(fetched.message, contains('not a PNG'));
      },
    );

    test('an implausibly large body is refused by declared length', () async {
      final _HandlerClient client = _HandlerClient(
        (http.BaseRequest request) async => _bytesResponse(
          200,
          _skinPngBytes(),
          contentLength: 10 * 1024 * 1024,
        ),
      );

      final PlayerSkinFetch fetched = await _source(client).fetch('Notch');

      expect(fetched.failure, PlayerSkinFailure.tooLarge);
      expect(fetched.message, contains('too large'));
    });

    test('an implausibly large body is refused while streaming too', () async {
      final _HandlerClient client = _HandlerClient(
        (http.BaseRequest request) async => http.StreamedResponse(
          Stream<List<int>>.fromIterable(<List<int>>[
            for (int chunk = 0; chunk < 40; chunk++)
              List<int>.filled(32 * 1024, 0x89),
          ]),
          200,
          headers: <String, String>{'content-type': 'image/png'},
        ),
      );

      final PlayerSkinFetch fetched = await _source(client).fetch('Notch');

      expect(fetched.failure, PlayerSkinFailure.tooLarge);
    });

    test('one host failing does not mask another host succeeding', () async {
      final _HandlerClient client = _HandlerClient((
        http.BaseRequest request,
      ) async {
        if (request.url.host == 'minotar.net') {
          return _bytesResponse(429, <int>[]);
        }
        return _bytesResponse(200, _skinPngBytes());
      });

      final PlayerSkinFetch fetched = await _source(client).fetch('Notch');

      expect(fetched.isSuccess, isTrue);
      expect(fetched.host, 'mc-heads.net');
    });
  });

  group('what the fetched skin becomes', () {
    test(
      'a fetched skin composes to the same 8x8 head a file import does',
      () async {
        final Uint8List bytes = _skinPngBytes();
        final _HandlerClient client = _HandlerClient(
          (http.BaseRequest request) async => _bytesResponse(200, bytes),
        );
        final PlayerSkinFetch fetched = await _source(client).fetch('Notch');
        final ImageLibrary library = ImageLibrary(
          autoLoad: false,
          writer: (String _, String _) => true,
        );

        final ImageAddOutcome outcome = library.addPlayerHeadFromSkin(
          username: fetched.username,
          skinPngDataUri: fetched.pngDataUri!,
        );

        expect(outcome.isSuccess, isTrue);
        expect(outcome.added.single.path, 'heads/notch-head.png');
        expect(outcome.added.single.width, 8);
        expect(outcome.added.single.height, 8);
        expect(
          outcome.added.single.dataUri,
          minecraftHeadFromSkinPng(
            '$huiNormalizedPngDataUriPrefix${base64Encode(bytes)}',
          )!.dataUri,
        );
      },
    );

    test('a high-resolution skin still lands as an 8x8 head', () async {
      final _HandlerClient client = _HandlerClient(
        (http.BaseRequest request) async =>
            _bytesResponse(200, _skinPngBytes(size: 128)),
      );
      final PlayerSkinFetch fetched = await _source(client).fetch('Notch');
      final ImageLibrary library = ImageLibrary(
        autoLoad: false,
        writer: (String _, String _) => true,
      );

      final ImageAddOutcome outcome = library.addPlayerHeadFromSkin(
        username: fetched.username,
        skinPngDataUri: fetched.pngDataUri!,
      );

      expect(outcome.added.single.width, 8);
    });

    test('a PNG that is not a skin leaves the library untouched', () {
      final ImageLibrary library = ImageLibrary(
        autoLoad: false,
        writer: (String _, String _) => true,
      );
      final String notASkin =
          '$huiNormalizedPngDataUriPrefix'
          '${base64Encode(img.encodePng(img.Image(width: 32, height: 32)))}';

      final ImageAddOutcome outcome = library.addPlayerHeadFromSkin(
        username: 'Notch',
        skinPngDataUri: notASkin,
      );

      expect(outcome.isSuccess, isFalse);
      expect(outcome.errors.single, contains('not a valid'));
      expect(library.images, isEmpty);
    });

    test(
      'a refused browser write reports the quota and stores nothing',
      () async {
        final Uint8List bytes = _skinPngBytes();
        final ImageLibrary library = ImageLibrary(
          autoLoad: false,
          writer: (String _, String _) => false,
        );

        final ImageAddOutcome outcome = library.addPlayerHeadFromSkin(
          username: 'Notch',
          skinPngDataUri:
              '$huiNormalizedPngDataUriPrefix${base64Encode(bytes)}',
        );

        expect(outcome.quotaExceeded, isTrue);
        expect(outcome.added, isEmpty);
        expect(library.images, isEmpty);
      },
    );

    test('fetching the same name twice replaces rather than duplicates', () {
      final String skin =
          '$huiNormalizedPngDataUriPrefix${base64Encode(_skinPngBytes())}';
      final ImageLibrary library = ImageLibrary(
        autoLoad: false,
        writer: (String _, String _) => true,
      );

      library.addPlayerHeadFromSkin(username: 'Notch', skinPngDataUri: skin);
      library.addPlayerHeadFromSkin(username: 'Notch', skinPngDataUri: skin);

      expect(library.images.length, 1);
      expect(library.images.single.path, 'heads/notch-head.png');
    });

    test('keeping the existing head parks the new one beside it', () {
      final String skin =
          '$huiNormalizedPngDataUriPrefix${base64Encode(_skinPngBytes())}';
      final ImageLibrary library = ImageLibrary(
        autoLoad: false,
        writer: (String _, String _) => true,
      );

      library.addPlayerHeadFromSkin(username: 'Notch', skinPngDataUri: skin);
      final ImageAddOutcome second = library.addPlayerHeadFromSkin(
        username: 'Notch',
        skinPngDataUri: skin,
        replaceExisting: false,
      );

      expect(library.images.length, 2);
      expect(second.added.single.path, 'heads/notch-head-2.png');
    });
  });
}

/// Stands in for the platform exception a failed connection throws. The source
/// treats every transport error the same way, so the concrete type does not
/// matter — only that it is not an HTTP response.
final class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}

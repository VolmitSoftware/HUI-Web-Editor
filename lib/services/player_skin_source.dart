/// Fetches a player's full skin PNG by username, for the head importer.
///
/// This is the one outbound request the editor makes outside a server-issued
/// capability link, and it only happens when somebody types a name and asks for
/// a head. The username is the entire payload; nothing about the workspace is
/// sent.
///
/// The bytes are fetched with a plain HTTP request and base64-encoded here
/// rather than pointed at an `<img>` and read back through a canvas: a
/// cross-origin image taints the canvas, `getImageData` then throws, and the
/// editor stores images as data URIs anyway. See [PlayerSkinSource.hosts] for
/// the host chain and what each host does with a name it does not know.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'image_library.dart' show huiNormalizedPngDataUriPrefix;

/// Minecraft usernames: 1 to 16 of `[A-Za-z0-9_]`. Mojang enforces three
/// characters at signup, but shorter legacy accounts exist, so the floor here is
/// one. This mirrors `PlayerHeadService.isResolvableName`
/// (PlayerHeadService.java:83-99) so a name the editor accepts is a name the
/// plugin would also try to resolve.
final RegExp _usernamePattern = RegExp(r'^[A-Za-z0-9_]{1,16}$');

bool isMinecraftUsername(String value) => _usernamePattern.hasMatch(value);

/// A skin host, named so failures can say which one said what.
final class PlayerSkinHost {
  const PlayerSkinHost({required this.name, required this.template});

  /// Display name, used verbatim in messages and in the README.
  final String name;

  /// Builds the request URL for a username already known to be well-formed.
  final Uri Function(String username) template;

  Uri uriFor(String username) => template(username);
}

/// Why a fetch did not produce a skin. Each maps to one message the user sees.
enum PlayerSkinFailure {
  /// Rejected before any request was made.
  invalidName,

  /// Every host answered, and none of them with a usable skin.
  notFound,

  /// A host asked us to slow down.
  rateLimited,

  /// Offline, DNS failure, timeout, CORS rejection, or the host being down.
  unreachable,

  /// A response arrived but was not a PNG.
  notASkin,

  /// A response arrived and was implausibly large for a 64x64 skin.
  tooLarge,
}

final class PlayerSkinFetch {
  const PlayerSkinFetch._({
    required this.username,
    this.pngDataUri,
    this.host,
    this.failure,
    this.message,
  });

  const PlayerSkinFetch.success({
    required String username,
    required String pngDataUri,
    required String host,
  }) : this._(username: username, pngDataUri: pngDataUri, host: host);

  const PlayerSkinFetch.failed({
    required String username,
    required PlayerSkinFailure failure,
    required String message,
  }) : this._(username: username, failure: failure, message: message);

  final String username;

  /// The full skin PNG as a `data:image/png;base64,` URI, on success.
  final String? pngDataUri;

  /// Which host answered, on success.
  final String? host;

  final PlayerSkinFailure? failure;

  /// A complete sentence for the user. Non-null exactly when [failure] is.
  final String? message;

  bool get isSuccess => pngDataUri != null;
}

final class PlayerSkinSource {
  PlayerSkinSource({
    http.Client? client,
    List<PlayerSkinHost>? hosts,
    this.requestTimeout = const Duration(seconds: 10),
    this.maxResponseBytes = 256 * 1024,
  }) : _client = client ?? http.Client(),
       hosts = hosts ?? defaultHosts {
    if (requestTimeout <= Duration.zero ||
        maxResponseBytes <= 0 ||
        this.hosts.isEmpty) {
      throw ArgumentError('Invalid skin source limits.');
    }
  }

  /// The documented chain, tried in order.
  ///
  /// `minotar.net` is first: it serves the FULL skin PNG (not a pre-rendered
  /// head) straight from a username, sends `Access-Control-Allow-Origin: *`,
  /// needs no account id lookup, and returned the correct skin for every account
  /// checked against it. `mc-heads.net` is the fallback and serves the same
  /// shape of response, so a minotar outage costs a retry rather than the
  /// feature — it is second rather than first because it was observed handing
  /// back a default skin for accounts minotar resolved correctly.
  /// `crafatar.com` is deliberately not in the chain: its skin route takes an
  /// account id, not a username, and resolving a name to an id needs Mojang's
  /// API, which sends no CORS headers.
  ///
  /// Neither host reports a name it does not know. Both answer HTTP 200 with a
  /// default skin, and — measured against both, 2026-08 — that skin is derived
  /// from the name rather than being one fixed placeholder, so there is nothing
  /// byte-stable to compare a response against. A real account that never
  /// uploaded a skin returns the same kind of answer, which makes the two cases
  /// genuinely indistinguishable here. The importer therefore stores what it was
  /// given and says plainly that a Steve or Alex head means the name was
  /// probably wrong, rather than guessing and being confidently wrong.
  static final List<PlayerSkinHost> defaultHosts =
      List<PlayerSkinHost>.unmodifiable(<PlayerSkinHost>[
        PlayerSkinHost(
          name: 'minotar.net',
          template: (String username) =>
              Uri.parse('https://minotar.net/skin/$username.png'),
        ),
        PlayerSkinHost(
          name: 'mc-heads.net',
          template: (String username) =>
              Uri.parse('https://mc-heads.net/skin/$username'),
        ),
      ]);

  final http.Client _client;
  final List<PlayerSkinHost> hosts;
  final Duration requestTimeout;

  /// A vanilla skin is 64x64 and a couple of kilobytes; anything near this is a
  /// redirect to something that is not a skin.
  final int maxResponseBytes;

  Future<PlayerSkinFetch> fetch(String rawUsername) async {
    final String username = rawUsername.trim();
    if (!isMinecraftUsername(username)) {
      return PlayerSkinFetch.failed(
        username: username,
        failure: PlayerSkinFailure.invalidName,
        message: username.isEmpty
            ? 'Type a Minecraft username first.'
            : '"$username" is not a Minecraft username. Names are 1 to 16 '
                  'characters of letters, digits and underscores.',
      );
    }

    final List<String> refusals = <String>[];
    PlayerSkinFailure worst = PlayerSkinFailure.unreachable;
    for (final PlayerSkinHost host in hosts) {
      final _HostAnswer answer = await _fetchFrom(host, username);
      if (answer.bytes != null) {
        return PlayerSkinFetch.success(
          username: username,
          pngDataUri:
              '$huiNormalizedPngDataUriPrefix${base64Encode(answer.bytes!)}',
          host: host.name,
        );
      }
      refusals.add('${host.name} ${answer.reason}');
      worst = _worse(worst, answer.failure!);
    }

    return PlayerSkinFetch.failed(
      username: username,
      failure: worst,
      message:
          'Could not fetch a skin for "$username": ${refusals.join('; ')}.',
    );
  }

  void close() => _client.close();

  /// Ranks failures so the message the user gets names the most actionable
  /// reason across the whole chain, not just whatever the last host said.
  static PlayerSkinFailure _worse(
    PlayerSkinFailure current,
    PlayerSkinFailure next,
  ) {
    const List<PlayerSkinFailure> severity = <PlayerSkinFailure>[
      PlayerSkinFailure.unreachable,
      PlayerSkinFailure.tooLarge,
      PlayerSkinFailure.notASkin,
      PlayerSkinFailure.rateLimited,
      PlayerSkinFailure.notFound,
    ];
    return severity.indexOf(next) > severity.indexOf(current) ? next : current;
  }

  Future<_HostAnswer> _fetchFrom(PlayerSkinHost host, String username) async {
    try {
      final http.Request request = http.Request('GET', host.uriFor(username));
      request.headers['accept'] = 'image/png';
      final http.StreamedResponse response = await _client
          .send(request)
          .timeout(requestTimeout);

      if (response.statusCode == 429) {
        await _drain(response);
        return const _HostAnswer.refused(
          PlayerSkinFailure.rateLimited,
          'is rate limiting this browser',
        );
      }
      if (response.statusCode == 404 || response.statusCode == 410) {
        await _drain(response);
        return const _HostAnswer.refused(
          PlayerSkinFailure.notFound,
          'has no skin for that name',
        );
      }
      if (response.statusCode != 200) {
        await _drain(response);
        return _HostAnswer.refused(
          PlayerSkinFailure.unreachable,
          'returned HTTP ${response.statusCode}',
        );
      }

      final int? declared = response.contentLength;
      if (declared != null && declared > maxResponseBytes) {
        await _drain(response);
        return const _HostAnswer.refused(
          PlayerSkinFailure.tooLarge,
          'returned a file far too large to be a skin',
        );
      }

      final Uint8List? bytes = await _read(response);
      if (bytes == null) {
        return const _HostAnswer.refused(
          PlayerSkinFailure.tooLarge,
          'returned a file far too large to be a skin',
        );
      }
      if (!_isPng(bytes)) {
        return const _HostAnswer.refused(
          PlayerSkinFailure.notASkin,
          'returned something that is not a PNG',
        );
      }
      return _HostAnswer.ok(bytes);
    } on TimeoutException {
      return const _HostAnswer.refused(
        PlayerSkinFailure.unreachable,
        'did not answer in time',
      );
    } catch (_) {
      // Offline, DNS failure and a CORS rejection all arrive here identically:
      // the browser does not tell a script which one it was.
      return const _HostAnswer.refused(
        PlayerSkinFailure.unreachable,
        'could not be reached',
      );
    }
  }

  /// Reads the body under the size cap, returning null once it is exceeded so a
  /// hostile or misrouted response cannot fill memory.
  Future<Uint8List?> _read(http.StreamedResponse response) async {
    final BytesBuilder builder = BytesBuilder(copy: false);
    int length = 0;
    final Stopwatch elapsed = Stopwatch()..start();
    final StreamIterator<List<int>> chunks = StreamIterator<List<int>>(
      response.stream,
    );
    try {
      while (true) {
        final Duration remaining = requestTimeout - elapsed.elapsed;
        if (remaining <= Duration.zero) throw TimeoutException('skin');
        if (!await chunks.moveNext().timeout(remaining)) break;
        length += chunks.current.length;
        if (length > maxResponseBytes) return null;
        builder.add(chunks.current);
      }
    } finally {
      await chunks.cancel();
    }
    return builder.takeBytes();
  }

  Future<void> _drain(http.StreamedResponse response) async {
    try {
      await response.stream.drain<void>().timeout(requestTimeout);
    } catch (_) {
      // A body we are already discarding is not worth a second failure path.
    }
  }

  static bool _isPng(Uint8List bytes) =>
      bytes.length > 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A;
}

final class _HostAnswer {
  const _HostAnswer.ok(this.bytes) : failure = null, reason = '';

  const _HostAnswer.refused(this.failure, this.reason) : bytes = null;

  final Uint8List? bytes;
  final PlayerSkinFailure? failure;

  /// A verb phrase that completes "minotar.net ...".
  final String reason;
}

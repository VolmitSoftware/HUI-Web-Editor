import 'dart:convert';
import 'dart:io';

import 'package:holoui_sync_relay/holoui_sync_relay.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late MemoryRelayStore store;
  late HoloUiSyncRelay relay;
  late DateTime now;

  setUp(() async {
    now = DateTime.utc(2026, 8, 12, 12);
    store = MemoryRelayStore();
    relay = HoloUiSyncRelay(
      config: RelayConfig(
        dataDirectory: Directory.systemTemp,
        allowedOrigins: const <String>{'https://editor.test'},
        allowAnonymousCreate: true,
      ),
      store: store,
      clock: () => now,
    );
    await relay.start();
  });

  tearDown(() => relay.close());

  test(
    'editor and server capabilities are isolated through a full publish',
    () async {
      final Map<String, Object?> created = await _create(relay, _project('a'));
      final String id = created['sessionId']! as String;
      final String editor = created['editorToken']! as String;
      final String server = created['serverToken']! as String;
      expect(_capabilityBytes(id), hasLength(32));
      expect(_capabilityBytes(editor), hasLength(32));
      expect(_capabilityBytes(server), hasLength(32));
      expect(<String>{id, editor, server}, hasLength(3));

      expect((await _get(relay, '/v1/sessions/$id', server)).statusCode, 401);
      expect(
        (await _get(
          relay,
          '/v1/sessions/$id/publication?after=0',
          editor,
        )).statusCode,
        401,
      );

      final Map<String, Object?> edited = _project('b');
      final Response published = await _jsonRequest(
        relay,
        'PUT',
        '/v1/sessions/$id/publication',
        <String, Object?>{
          'protocol': 1,
          'baseRevision': _revisionA,
          'snapshot': edited,
        },
        token: editor,
      );
      expect(published.statusCode, 202);
      final Map<String, Object?> pending = await _responseJson(
        await _get(relay, '/v1/sessions/$id/publication?after=0', server),
      );
      final Map<String, Object?> publication =
          pending['publication']! as Map<String, Object?>;
      expect(publication['revision'], 1);
      expect(publication['baseRevision'], _revisionA);
      expect((publication['snapshot']! as Map)['baseRevision'], _revisionB);

      final Map<String, Object?> actual = _project('server');
      final Response ack = await _jsonRequest(
        relay,
        'POST',
        '/v1/sessions/$id/publication/1/ack',
        <String, Object?>{
          'protocol': 1,
          'status': 'applied',
          'message': 'Applied safely.',
          'serverRevision': _revisionServer,
          'snapshot': actual,
        },
        token: server,
      );
      expect(ack.statusCode, 200);
      expect(
        (await _get(
          relay,
          '/v1/sessions/$id/publication?after=0',
          server,
        )).statusCode,
        204,
      );
      final Map<String, Object?> fetched = await _responseJson(
        await _get(relay, '/v1/sessions/$id', editor),
      );
      expect(fetched['status'], 'applied');
      expect(fetched['baseRevision'], _revisionServer);
      expect((fetched['snapshot']! as Map)['menus'], actual['menus']);
    },
  );

  test('old base and simultaneous pending publications conflict', () async {
    final Map<String, Object?> created = await _create(relay, _project('a'));
    final String id = created['sessionId']! as String;
    final String editor = created['editorToken']! as String;
    final Response stale = await _jsonRequest(
      relay,
      'PUT',
      '/v1/sessions/$id/publication',
      <String, Object?>{
        'protocol': 1,
        'baseRevision': _revisionB,
        'snapshot': _project('b'),
      },
      token: editor,
    );
    expect(stale.statusCode, 409);
    expect(
      (await _publish(relay, id, editor, _revisionA, _project('b'))).statusCode,
      202,
    );
    expect(
      (await _publish(relay, id, editor, _revisionA, _project('b'))).statusCode,
      409,
    );
    expect(
      (await _get(
        relay,
        '/v1/sessions/$id/publication',
        created['serverToken']! as String,
      )).statusCode,
      400,
    );
    expect(
      (await _get(
        relay,
        '/v1/sessions/$id/publication?after=0&after=1',
        created['serverToken']! as String,
      )).statusCode,
      400,
    );
  });

  test('revoke and expiry return distinct gone errors', () async {
    final Map<String, Object?> revoked = await _create(relay, _project('a'));
    final Response revoke = await _delete(
      relay,
      '/v1/sessions/${revoked['sessionId']}',
      revoked['serverToken']! as String,
    );
    expect(revoke.statusCode, 204);
    final Response gone = await _get(
      relay,
      '/v1/sessions/${revoked['sessionId']}',
      revoked['editorToken']! as String,
    );
    expect(gone.statusCode, 410);
    expect(await _errorCode(gone), 'session_revoked');

    final Map<String, Object?> expired = await _create(relay, _project('a'));
    now = now.add(const Duration(hours: 2));
    final Response timeout = await _get(
      relay,
      '/v1/sessions/${expired['sessionId']}',
      expired['editorToken']! as String,
    );
    expect(timeout.statusCode, 410);
    expect(await _errorCode(timeout), 'session_expired');
  });

  test('expired tombstones are retained briefly and then cleaned up', () async {
    final Map<String, Object?> expired = await _create(relay, _project('a'));
    final String id = expired['sessionId']! as String;
    now = now.add(const Duration(hours: 2));
    await relay.cleanupExpired();
    expect(await store.read(id), isNotNull);
    now = now.add(const Duration(hours: 25));
    await relay.cleanupExpired();
    expect(await store.read(id), isNull);
  });

  test(
    'the active-session capacity is atomic across concurrent creates',
    () async {
      await relay.close();
      store = MemoryRelayStore();
      relay = HoloUiSyncRelay(
        config: RelayConfig(
          dataDirectory: Directory.systemTemp,
          maximumActiveSessions: 1,
          allowedOrigins: const <String>{'https://editor.test'},
          allowAnonymousCreate: true,
        ),
        store: store,
        clock: () => now,
      );
      await relay.start();
      final List<Response> responses = await Future.wait(<Future<Response>>[
        _createResponse(relay, _project('a')),
        _createResponse(relay, _project('a')),
      ]);
      expect(
        responses.map((Response response) => response.statusCode).toList()
          ..sort(),
        <int>[201, 503],
      );
      expect((await store.list()).length, 1);
    },
  );

  test(
    'revoked tombstones still consume the bounded storage reserve',
    () async {
      await relay.close();
      store = MemoryRelayStore();
      const int snapshotLimit = 2 * 1024 * 1024;
      relay = HoloUiSyncRelay(
        config: RelayConfig(
          dataDirectory: Directory.systemTemp,
          maximumSnapshotBytes: snapshotLimit,
          maximumStoredBytes:
              snapshotLimit * 2 + RelayConfig.protocolEnvelopeBytes,
          maximumActiveSessions: 10,
          allowedOrigins: const <String>{'https://editor.test'},
          allowAnonymousCreate: true,
        ),
        store: store,
        clock: () => now,
      );
      await relay.start();
      final Map<String, Object?> created = await _create(relay, _project('a'));
      expect(
        (await _delete(
          relay,
          '/v1/sessions/${created['sessionId']}',
          created['serverToken']! as String,
        )).statusCode,
        204,
      );
      expect((await _createResponse(relay, _project('a'))).statusCode, 503);
    },
  );

  test(
    'strict JSON, body limits, CORS and security headers are enforced',
    () async {
      final Response wrongType = await relay.handler(
        Request(
          'POST',
          Uri.parse('http://relay.test/v1/sessions'),
          headers: const <String, String>{'content-type': 'text/plain'},
          body: '{}',
        ),
      );
      expect(wrongType.statusCode, 415);
      final MemoryRelayStore boundedStore = MemoryRelayStore();
      final HoloUiSyncRelay boundedRelay = HoloUiSyncRelay(
        config: RelayConfig(
          dataDirectory: Directory.systemTemp,
          maximumSnapshotBytes: 1024,
          maximumRequestBytes: 64,
          allowedOrigins: const <String>{'https://editor.test'},
          allowAnonymousCreate: true,
        ),
        store: boundedStore,
        clock: () => now,
      );
      await boundedRelay.start();
      addTearDown(boundedRelay.close);
      final Response streamedOversize = await boundedRelay.handler(
        Request(
          'POST',
          Uri.parse('http://relay.test/v1/sessions'),
          headers: const <String, String>{'content-type': 'application/json'},
          body: Stream<List<int>>.fromIterable(<List<int>>[
            utf8.encode('{"padding":"'),
            List<int>.filled(128, 97),
            utf8.encode('"}'),
          ]),
        ),
      );
      expect(streamedOversize.statusCode, 413);
      final Response extra =
          await _jsonRequest(relay, 'POST', '/v1/sessions', <String, Object?>{
            'protocol': 1,
            'expiresInSeconds': 3600,
            'snapshot': _project('a'),
            'unexpected': true,
          });
      expect(extra.statusCode, 400);
      final Response preflight = await relay.handler(
        Request(
          'OPTIONS',
          Uri.parse('http://relay.test/v1/sessions/x'),
          headers: const <String, String>{'origin': 'https://editor.test'},
        ),
      );
      expect(preflight.statusCode, 204);
      expect(
        preflight.headers['access-control-allow-origin'],
        'https://editor.test',
      );
      expect(preflight.headers['cache-control'], 'no-store');
      expect(preflight.headers['access-control-allow-credentials'], isNull);
      final Response unsafePreflight = await relay.handler(
        Request(
          'OPTIONS',
          Uri.parse('http://relay.test/v1/sessions/x'),
          headers: const <String, String>{
            'origin': 'https://editor.test',
            'access-control-request-method': 'TRACE',
          },
        ),
      );
      expect(unsafePreflight.statusCode, 403);
      final Response blockedOrigin = await relay.handler(
        Request(
          'GET',
          Uri.parse('http://relay.test/v1/health'),
          headers: const <String, String>{'origin': 'https://attacker.test'},
        ),
      );
      expect(blockedOrigin.statusCode, 403);
    },
  );

  test('protocol byte limits match both clients', () {
    expect(RelayConfig.maximumProtocolProjectBytes, 32 * 1024 * 1024);
    expect(
      RelayConfig.maximumProtocolRequestBytes,
      (32 * 1024 * 1024) + (256 * 1024),
    );
    expect(
      RelayConfig.maximumProtocolResponseBytes,
      (64 * 1024 * 1024) + (256 * 1024),
    );
    final RelayConfig config = RelayConfig.fromEnvironment(<String, String>{});
    expect(config.maximumSnapshotBytes, 8 * 1024 * 1024);
    expect(config.maximumRequestBytes, 8 * 1024 * 1024 + 256 * 1024);
    expect(config.maximumResponseBytes, 16 * 1024 * 1024 + 256 * 1024);
    final RelayConfig maximum = RelayConfig.fromEnvironment(<String, String>{
      'HOLOUI_RELAY_MAX_SNAPSHOT_BYTES': '${32 * 1024 * 1024}',
    });
    expect(maximum.maximumSnapshotBytes, 32 * 1024 * 1024);
    expect(maximum.maximumRequestBytes, 32 * 1024 * 1024 + 256 * 1024);
    expect(maximum.maximumResponseBytes, 64 * 1024 * 1024 + 256 * 1024);
  });

  test('request and response bytes derive from the configured snapshot', () {
    final RelayConfig config = RelayConfig.fromEnvironment(<String, String>{
      'HOLOUI_RELAY_MAX_SNAPSHOT_BYTES': '${8 * 1024 * 1024}',
      'HOLOUI_RELAY_MAX_REQUEST_BYTES': '${64 * 1024 * 1024}',
      'HOLOUI_RELAY_MAX_RESPONSE_BYTES': '${128 * 1024 * 1024}',
    });
    expect(config.maximumSnapshotBytes, 8 * 1024 * 1024);
    expect(config.maximumRequestBytes, 8 * 1024 * 1024 + 256 * 1024);
    expect(config.maximumResponseBytes, 16 * 1024 * 1024 + 256 * 1024);
  });

  test(
    'create token configuration is validated and retained only as a hash',
    () {
      final RelayConfig anonymous = RelayConfig.fromEnvironment(
        <String, String>{'HOLOUI_RELAY_CREATE_TOKEN': ''},
      );
      expect(anonymous.createTokenHashes, isEmpty);
      expect(anonymous.allowAnonymousCreate, isFalse);

      final RelayConfig secured = RelayConfig.fromEnvironment(<String, String>{
        'HOLOUI_RELAY_CREATE_TOKEN': _createToken,
      });
      expect(secured.createTokenHashes, <String>{tokenHash(_createToken)});
      expect(secured.createTokenHashes, isNot(contains(_createToken)));

      final String minimumToken = List<String>.filled(22, 'm').join();
      final String maximumToken = List<String>.filled(128, 'x').join();
      final RelayConfig multiple = RelayConfig.fromEnvironment(<String, String>{
        'HOLOUI_RELAY_CREATE_TOKENS':
            '$minimumToken, $maximumToken,$minimumToken',
      });
      expect(multiple.createTokenHashes, <String>{
        tokenHash(minimumToken),
        tokenHash(maximumToken),
      });

      final List<String> invalidTokens = <String>[
        'short',
        '${List<String>.filled(21, 'a').join()}!',
        List<String>.filled(129, 'a').join(),
      ];
      for (final String invalid in invalidTokens) {
        expect(
          () => RelayConfig.fromEnvironment(<String, String>{
            'HOLOUI_RELAY_CREATE_TOKEN': invalid,
          }),
          throwsFormatException,
        );
      }
      expect(
        () => RelayConfig.fromEnvironment(<String, String>{
          'HOLOUI_RELAY_CREATE_TOKEN': _createToken,
          'HOLOUI_RELAY_CREATE_TOKENS': minimumToken,
        }),
        throwsFormatException,
      );
      expect(
        () => RelayConfig.fromEnvironment(<String, String>{
          'HOLOUI_RELAY_CREATE_TOKENS': List<String>.generate(
            RelayConfig.maximumCreateTokens + 1,
            (int index) => 'operator_${index.toString().padLeft(14, '0')}',
          ).join(','),
        }),
        throwsFormatException,
      );
      expect(
        () => RelayConfig.fromEnvironment(<String, String>{
          'HOLOUI_RELAY_CREATE_TOKEN': _createToken,
          'HOLOUI_RELAY_ALLOW_ANONYMOUS_CREATE': 'true',
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'create admission fails closed unless anonymous mode is explicit',
    () async {
      await relay.close();
      store = MemoryRelayStore();
      relay = HoloUiSyncRelay(
        config: RelayConfig(dataDirectory: Directory.systemTemp),
        store: store,
        clock: () => now,
      );
      await expectLater(relay.start(), throwsStateError);
      expect(await store.list(), isEmpty);
    },
  );

  test(
    'configured create admission authenticates before body and rate limits',
    () async {
      await relay.close();
      store = MemoryRelayStore();
      relay = HoloUiSyncRelay(
        config: RelayConfig(
          dataDirectory: Directory.systemTemp,
          createTokenHashes: <String>{tokenHash(_createToken)},
          maximumSessionsPerAddressPerMinute: 1,
        ),
        store: store,
        clock: () => now,
      );
      await relay.start();

      final Response missing = await relay.handler(
        Request(
          'POST',
          Uri.parse('http://relay.test/v1/sessions'),
          headers: const <String, String>{'content-type': 'text/plain'},
          body: 'not json',
        ),
      );
      expect(missing.statusCode, 401);
      expect(await _errorCode(missing), 'unauthorized');
      expect(
        (await _createResponse(
          relay,
          _project('a'),
          headers: const <String, String>{
            'authorization': 'Bearer wrong_create_token_0123456789',
          },
        )).statusCode,
        401,
      );
      expect(
        (await _createResponse(
          relay,
          _project('a'),
          headers: const <String, String>{
            'authorization': 'Bearer malformed token',
          },
        )).statusCode,
        401,
      );
      expect(await store.list(), isEmpty);

      final Response accepted = await _createResponse(
        relay,
        _project('a'),
        headers: const <String, String>{
          'authorization': 'Bearer $_createToken',
        },
      );
      expect(accepted.statusCode, 201);
      expect(
        (await _createResponse(
          relay,
          _project('a'),
          headers: const <String, String>{
            'authorization': 'Bearer $_createToken',
          },
        )).statusCode,
        429,
      );

      final Response health = await relay.handler(
        Request('GET', Uri.parse('http://relay.test/v1/health')),
      );
      expect(health.statusCode, 200);
      expect(await _responseJson(health), <String, Object?>{
        'status': 'ok',
        'protocol': 1,
      });
    },
  );

  test(
    'custom relays may explicitly retain anonymous create admission',
    () async {
      final Response response = await _createResponse(relay, _project('a'));
      expect(response.statusCode, 201);
    },
  );

  test(
    'operator principals have isolated active and retained quotas',
    () async {
      await relay.close();
      store = MemoryRelayStore();
      relay = HoloUiSyncRelay(
        config: RelayConfig(
          dataDirectory: Directory.systemTemp,
          createTokenHashes: <String>{
            tokenHash(_createToken),
            tokenHash(_secondCreateToken),
          },
          maximumActiveSessionsPerPrincipal: 1,
          maximumRetainedSessionsPerPrincipal: 2,
        ),
        store: store,
        clock: () => now,
      );
      await relay.start();

      final Map<String, Object?> first = await _responseJson(
        await _authorizedCreateResponse(relay, _project('a'), _createToken),
      );
      expect(
        (await _authorizedCreateResponse(
          relay,
          _project('a'),
          _createToken,
        )).statusCode,
        503,
      );
      expect(
        (await _authorizedCreateResponse(
          relay,
          _project('a'),
          _secondCreateToken,
        )).statusCode,
        201,
      );
      expect(
        (await _delete(
          relay,
          '/v1/sessions/${first['sessionId']}',
          first['serverToken']! as String,
        )).statusCode,
        204,
      );
      final Map<String, Object?> replacement = await _responseJson(
        await _authorizedCreateResponse(relay, _project('a'), _createToken),
      );
      expect(
        (await _delete(
          relay,
          '/v1/sessions/${replacement['sessionId']}',
          replacement['serverToken']! as String,
        )).statusCode,
        204,
      );
      final Response retained = await _authorizedCreateResponse(
        relay,
        _project('a'),
        _createToken,
      );
      expect(retained.statusCode, 503);
      expect(await _errorCode(retained), 'principal_capacity_reached');

      final List<RelaySession> sessions = await store.list();
      expect(
        sessions
            .map<String>((RelaySession session) => session.createPrincipalHash)
            .toSet(),
        hasLength(2),
      );
      expect(
        sessions
            .where(
              (RelaySession session) =>
                  session.createPrincipalHash ==
                  tokenHash(
                    'holoui-create-principal-v1:${tokenHash(_createToken)}',
                  ),
            )
            .length,
        2,
      );
    },
  );

  test('operator principals have isolated storage and rate quotas', () async {
    await relay.close();
    store = MemoryRelayStore();
    const int snapshotLimit = 2 * 1024 * 1024;
    const int reserved = snapshotLimit * 2 + RelayConfig.protocolEnvelopeBytes;
    relay = HoloUiSyncRelay(
      config: RelayConfig(
        dataDirectory: Directory.systemTemp,
        maximumSnapshotBytes: snapshotLimit,
        maximumStoredBytesPerPrincipal: reserved,
        maximumRetainedSessionsPerPrincipal: 10,
        maximumActiveSessionsPerPrincipal: 10,
        maximumSessionsPerAddressPerMinute: 10,
        maximumSessionsPerPrincipalPerMinute: 1,
        maximumRateLimitAddresses: 10,
        trustProxy: true,
        createTokenHashes: <String>{
          tokenHash(_createToken),
          tokenHash(_secondCreateToken),
        },
      ),
      store: store,
      clock: () => now,
    );
    await relay.start();

    final Map<String, Object?> first = await _responseJson(
      await _authorizedCreateResponse(
        relay,
        _project('a'),
        _createToken,
        headers: const <String, String>{'x-forwarded-for': '192.0.2.1'},
      ),
    );
    expect(
      (await _authorizedCreateResponse(
        relay,
        _project('a'),
        _createToken,
        headers: const <String, String>{'x-forwarded-for': '192.0.2.2'},
      )).statusCode,
      429,
    );
    expect(
      (await _authorizedCreateResponse(
        relay,
        _project('a'),
        _secondCreateToken,
        headers: const <String, String>{'x-forwarded-for': '192.0.2.2'},
      )).statusCode,
      201,
    );
    expect(
      (await _delete(
        relay,
        '/v1/sessions/${first['sessionId']}',
        first['serverToken']! as String,
      )).statusCode,
      204,
    );
    now = now.add(const Duration(seconds: 61));
    final Response storage = await _authorizedCreateResponse(
      relay,
      _project('a'),
      _createToken,
      headers: const <String, String>{'x-forwarded-for': '192.0.2.3'},
    );
    expect(storage.statusCode, 503);
    expect(await _errorCode(storage), 'principal_storage_capacity_reached');
  });

  test('stored reservations survive a lower snapshot limit', () async {
    await relay.close();
    store = MemoryRelayStore();
    const int storedLimit = 70 * 1024 * 1024;
    relay = HoloUiSyncRelay(
      config: RelayConfig(
        dataDirectory: Directory.systemTemp,
        maximumSnapshotBytes: 32 * 1024 * 1024,
        maximumStoredBytes: storedLimit,
        maximumStoredBytesPerPrincipal: storedLimit,
        maximumRetainedSessionsPerPrincipal: 10,
        maximumActiveSessionsPerPrincipal: 10,
        allowAnonymousCreate: true,
      ),
      store: store,
      clock: () => now,
    );
    await relay.start();
    expect((await _createResponse(relay, _project('a'))).statusCode, 201);
    final RelaySession retained = (await store.list()).single;
    expect(
      retained.reservedBytes,
      (64 * 1024 * 1024) + RelayConfig.protocolEnvelopeBytes,
    );

    await relay.close();
    relay = HoloUiSyncRelay(
      config: RelayConfig(
        dataDirectory: Directory.systemTemp,
        maximumSnapshotBytes: 8 * 1024 * 1024,
        maximumStoredBytes: storedLimit,
        maximumStoredBytesPerPrincipal: storedLimit,
        maximumRetainedSessionsPerPrincipal: 10,
        maximumActiveSessionsPerPrincipal: 10,
        allowAnonymousCreate: true,
      ),
      store: store,
      clock: () => now,
    );
    await relay.start();
    final Response denied = await _createResponse(relay, _project('a'));
    expect(denied.statusCode, 503);
    expect(await _errorCode(denied), 'storage_capacity_reached');
  });

  test('raising the snapshot limit cannot enlarge retained sessions', () async {
    await relay.close();
    store = MemoryRelayStore();
    relay = HoloUiSyncRelay(
      config: RelayConfig(
        dataDirectory: Directory.systemTemp,
        maximumSnapshotBytes: 1024,
        allowAnonymousCreate: true,
      ),
      store: store,
      clock: () => now,
    );
    await relay.start();
    final Map<String, Object?> created = await _create(relay, _project('a'));

    await relay.close();
    relay = HoloUiSyncRelay(
      config: RelayConfig(
        dataDirectory: Directory.systemTemp,
        maximumSnapshotBytes: 2048,
        allowAnonymousCreate: true,
      ),
      store: store,
      clock: () => now,
    );
    await relay.start();
    final Map<String, Object?> expanded = Map<String, Object?>.of(_project('b'))
      ..['padding'] = List<String>.filled(1300, 'x').join();
    final Response denied = await _publish(
      relay,
      created['sessionId']! as String,
      created['editorToken']! as String,
      _revisionA,
      expanded,
    );
    expect(denied.statusCode, 413);
    expect(await _errorCode(denied), 'snapshot_too_large');
  });

  test('create rate limiting ignores forwarding headers by default', () async {
    await relay.close();
    store = MemoryRelayStore();
    relay = HoloUiSyncRelay(
      config: RelayConfig(
        dataDirectory: Directory.systemTemp,
        maximumSessionsPerAddressPerMinute: 1,
        allowAnonymousCreate: true,
      ),
      store: store,
      clock: () => now,
    );
    await relay.start();
    expect(
      (await _createResponse(
        relay,
        _project('a'),
        headers: const <String, String>{'x-forwarded-for': '192.0.2.1'},
      )).statusCode,
      201,
    );
    expect(
      (await _createResponse(
        relay,
        _project('a'),
        headers: const <String, String>{'x-forwarded-for': '192.0.2.2'},
      )).statusCode,
      429,
    );
  });

  test('rate-limit address cardinality is bounded', () async {
    await relay.close();
    store = MemoryRelayStore();
    relay = HoloUiSyncRelay(
      config: RelayConfig(
        dataDirectory: Directory.systemTemp,
        maximumRateLimitAddresses: 1,
        trustProxy: true,
        allowAnonymousCreate: true,
      ),
      store: store,
      clock: () => now,
    );
    await relay.start();
    expect(
      (await _createResponse(
        relay,
        _project('a'),
        headers: const <String, String>{'x-forwarded-for': '192.0.2.1'},
      )).statusCode,
      201,
    );
    expect(
      (await _createResponse(
        relay,
        _project('a'),
        headers: const <String, String>{'x-forwarded-for': '192.0.2.2'},
      )).statusCode,
      429,
    );
    now = now.add(const Duration(seconds: 61));
    expect(
      (await _createResponse(
        relay,
        _project('a'),
        headers: const <String, String>{'x-forwarded-for': '192.0.2.2'},
      )).statusCode,
      201,
    );
  });

  test('conflict rebases explicitly and revisions remain monotonic', () async {
    final Map<String, Object?> created = await _create(relay, _project('a'));
    final String id = created['sessionId']! as String;
    final String editor = created['editorToken']! as String;
    final String server = created['serverToken']! as String;
    expect(
      (await _publish(relay, id, editor, _revisionA, _project('b'))).statusCode,
      202,
    );
    final Map<String, Object?> current = _project('server');
    expect(
      (await _ack(
        relay,
        id,
        server,
        1,
        'conflict',
        message: 'Server changed.',
        serverRevision: _revisionServer,
        snapshot: current,
      )).statusCode,
      200,
    );
    expect(
      (await _publish(relay, id, editor, _revisionA, _project('b'))).statusCode,
      409,
    );
    final Map<String, Object?> next = _project('d');
    final Map<String, Object?> accepted = await _responseJson(
      await _publish(relay, id, editor, _revisionServer, next),
    );
    expect((accepted['publication']! as Map)['revision'], 2);
    final Map<String, Object?> polled = await _responseJson(
      await _get(relay, '/v1/sessions/$id/publication?after=1', server),
    );
    expect((polled['publication']! as Map)['revision'], 2);
  });

  test('rejected publication can be replaced without rebasing', () async {
    final Map<String, Object?> created = await _create(relay, _project('a'));
    final String id = created['sessionId']! as String;
    final String editor = created['editorToken']! as String;
    final String server = created['serverToken']! as String;
    await _publish(relay, id, editor, _revisionA, _project('b'));
    final Map<String, Object?> rejected = await _responseJson(
      await _ack(relay, id, server, 1, 'rejected', message: 'Invalid project.'),
    );
    final Map<Object?, Object?> acknowledgement =
        ((rejected['publication']! as Map)['ack']! as Map);
    expect(acknowledgement['status'], 'rejected');
    expect(acknowledgement['serverRevision'], isNull);
    final Map<String, Object?> session = await _responseJson(
      await _get(relay, '/v1/sessions/$id', editor),
    );
    expect(session['baseRevision'], _revisionA);
    expect(
      (((session['publication']! as Map)['ack']! as Map)['serverRevision']),
      isNull,
    );
    final Map<String, Object?> accepted = await _responseJson(
      await _publish(relay, id, editor, _revisionA, _project('d')),
    );
    expect((accepted['publication']! as Map)['revision'], 2);
  });

  test(
    'ack retries are exact and cannot mutate an acknowledged result',
    () async {
      final Map<String, Object?> created = await _create(relay, _project('a'));
      final String id = created['sessionId']! as String;
      final String editor = created['editorToken']! as String;
      final String server = created['serverToken']! as String;
      await _publish(relay, id, editor, _revisionA, _project('b'));
      final Map<String, Object?> actual = _project('server');
      Future<Response> acknowledge(String message) => _ack(
        relay,
        id,
        server,
        1,
        'applied',
        message: message,
        serverRevision: _revisionServer,
        snapshot: actual,
      );
      expect((await acknowledge('Applied safely.')).statusCode, 200);
      expect((await acknowledge('Applied safely.')).statusCode, 200);
      expect((await acknowledge('Changed response.')).statusCode, 409);
    },
  );

  test(
    'expired session state is disclosed only to a valid capability',
    () async {
      final Map<String, Object?> created = await _create(relay, _project('a'));
      now = now.add(const Duration(hours: 2));
      expect(
        (await _get(
          relay,
          '/v1/sessions/${created['sessionId']}',
          'not-the-editor-token',
        )).statusCode,
        401,
      );
    },
  );

  test(
    'encoded separators and dot segments cannot change route scope',
    () async {
      final Map<String, Object?> created = await _create(relay, _project('a'));
      final String id = created['sessionId']! as String;
      final String editor = created['editorToken']! as String;
      final Response encodedSlash = await relay.handler(
        Request(
          'GET',
          Uri.parse('http://relay.test/v1/sessions/$id%2Fpublication'),
          headers: <String, String>{'authorization': 'Bearer $editor'},
        ),
      );
      expect(encodedSlash.statusCode, 404);
      final Response encodedDot = await relay.handler(
        Request(
          'GET',
          Uri.parse('http://relay.test/v1/sessions/%2e%2e'),
          headers: <String, String>{'authorization': 'Bearer $editor'},
        ),
      );
      expect(encodedDot.statusCode, 404);
    },
  );
}

Future<Response> _createResponse(
  HoloUiSyncRelay relay,
  Map<String, Object?> project, {
  Map<String, String> headers = const <String, String>{},
}) => _jsonRequest(relay, 'POST', '/v1/sessions', <String, Object?>{
  'protocol': 1,
  'expiresInSeconds': 3600,
  'snapshot': project,
}, headers: headers);

Future<Response> _authorizedCreateResponse(
  HoloUiSyncRelay relay,
  Map<String, Object?> project,
  String createToken, {
  Map<String, String> headers = const <String, String>{},
}) => _createResponse(
  relay,
  project,
  headers: <String, String>{'authorization': 'Bearer $createToken', ...headers},
);

const String _revisionA =
    'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _revisionB =
    'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String _revisionServer =
    'sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const String _revisionD =
    'sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const String _createToken = 'create_token_0123456789abcdef';
const String _secondCreateToken = 'second_create_token_0123456789';

Map<String, Object?> _project(String value) => <String, Object?>{
  'format': 'holoui-sync-project',
  'version': 1,
  'kind': 'menu',
  'subjectId': 'main',
  'baseRevision': switch (value) {
    'a' => _revisionA,
    'b' => _revisionB,
    'd' => _revisionD,
    _ => _revisionServer,
  },
  'menus': <Object?>[
    <String, Object?>{'id': 'main', 'json': '{"value":"$value"}'},
  ],
  'images': <Object?>[],
  'constraints': <String, Object?>{
    'subjectId': 'main',
    'menuIds': <String>['main'],
    'imagePaths': <String>[],
    'newImagePrefix': 'sync/menus/main/',
    'allowDeletes': false,
  },
  'warnings': <String>[],
};

Future<Map<String, Object?>> _create(
  HoloUiSyncRelay relay,
  Map<String, Object?> project,
) async => _responseJson(
  await _jsonRequest(relay, 'POST', '/v1/sessions', <String, Object?>{
    'protocol': 1,
    'expiresInSeconds': 3600,
    'snapshot': project,
  }),
);

Future<Response> _publish(
  HoloUiSyncRelay relay,
  String id,
  String token,
  String base,
  Map<String, Object?> project,
) => _jsonRequest(
  relay,
  'PUT',
  '/v1/sessions/$id/publication',
  <String, Object?>{'protocol': 1, 'baseRevision': base, 'snapshot': project},
  token: token,
);

Future<Response> _ack(
  HoloUiSyncRelay relay,
  String id,
  String token,
  int revision,
  String status, {
  required String message,
  String? serverRevision,
  Map<String, Object?>? snapshot,
}) {
  final Map<String, Object?> body = <String, Object?>{
    'protocol': 1,
    'status': status,
    'message': message,
  };
  if (serverRevision != null) body['serverRevision'] = serverRevision;
  if (snapshot != null) body['snapshot'] = snapshot;
  return _jsonRequest(
    relay,
    'POST',
    '/v1/sessions/$id/publication/$revision/ack',
    body,
    token: token,
  );
}

Future<Response> _get(HoloUiSyncRelay relay, String path, String token) async =>
    await relay.handler(
      Request(
        'GET',
        Uri.parse('http://relay.test$path'),
        headers: <String, String>{'authorization': 'Bearer $token'},
      ),
    );

Future<Response> _delete(
  HoloUiSyncRelay relay,
  String path,
  String token,
) async => await relay.handler(
  Request(
    'DELETE',
    Uri.parse('http://relay.test$path'),
    headers: <String, String>{'authorization': 'Bearer $token'},
  ),
);

Future<Response> _jsonRequest(
  HoloUiSyncRelay relay,
  String method,
  String path,
  Map<String, Object?> body, {
  String? token,
  Map<String, String> headers = const <String, String>{},
}) async => await relay.handler(
  Request(
    method,
    Uri.parse('http://relay.test$path'),
    headers: <String, String>{
      'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
      ...headers,
    },
    body: jsonEncode(body),
  ),
);

Future<Map<String, Object?>> _responseJson(Response response) async =>
    (jsonDecode(await response.readAsString()) as Map).cast<String, Object?>();

Future<String> _errorCode(Response response) async {
  final Map<String, Object?> body = await _responseJson(response);
  return ((body['error']! as Map)['code'])! as String;
}

List<int> _capabilityBytes(String value) {
  final int padding = (4 - value.length % 4) % 4;
  final String suffix = List<String>.filled(padding, '=').join();
  return base64Url.decode('$value$suffix');
}

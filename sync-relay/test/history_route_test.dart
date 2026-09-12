import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gloss_sync_relay/gloss_sync_relay.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late MemoryRelayStore store;
  late GlossSyncRelay relay;
  late DateTime now;

  setUp(() async {
    now = DateTime.utc(2026, 8, 12, 12);
    store = MemoryRelayStore();
    relay = GlossSyncRelay(
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

  test('a history request waits for the server and returns its bytes', () async {
    final Map<String, Object?> session = await _create(relay);
    final String id = session['sessionId']! as String;
    final String editorToken = session['editorToken']! as String;
    final String serverToken = session['serverToken']! as String;

    final Future<Response> pending = _get(
      relay,
      '/v3/sessions/$id/history?kind=menus&documentId=shop%2Fmain&version=1700',
      editorToken,
    );
    await _settle();

    final Response poll = await _get(
      relay,
      '/v3/sessions/$id/publication?after=0',
      serverToken,
    );
    expect(poll.statusCode, 200);
    final Map<String, Object?> polled = await _json(poll);
    expect(polled['publication'], isNull);
    expect(polled['historyRequests'], <Object?>[
      <String, Object?>{'kind': 'menus', 'id': 'shop/main', 'version': 1700},
    ]);

    final Response answered = await _post(
      relay,
      '/v3/sessions/$id/history?kind=menus&documentId=shop%2Fmain&version=1700',
      serverToken,
      <String, Object?>{
        'protocol': 3,
        'found': true,
        'json': '{"components":[]}',
      },
    );
    expect(answered.statusCode, 200);
    expect((await _json(answered))['accepted'], isTrue);

    final Response resolved = await pending;
    expect(resolved.statusCode, 200);
    final Map<String, Object?> body = await _json(resolved);
    expect(body['found'], isTrue);
    expect(body['json'], '{"components":[]}');
    expect(body['kind'], 'menus');
    expect(body['id'], 'shop/main');
    expect(body['version'], 1700);
  });

  test('a version the server no longer keeps resolves as not found', () async {
    final Map<String, Object?> session = await _create(relay);
    final String id = session['sessionId']! as String;

    final Future<Response> pending = _get(
      relay,
      '/v3/sessions/$id/history?kind=menus&documentId=shop&version=9',
      session['editorToken']! as String,
    );
    await _settle();
    await _post(
      relay,
      '/v3/sessions/$id/history?kind=menus&documentId=shop&version=9',
      session['serverToken']! as String,
      <String, Object?>{'protocol': 3, 'found': false, 'json': null},
    );

    final Map<String, Object?> body = await _json(await pending);
    expect(body['found'], isFalse);
    expect(body['json'], isNull);
  });

  test('answering a version nobody asked for is refused', () async {
    final Map<String, Object?> session = await _create(relay);
    final String id = session['sessionId']! as String;

    final Response response = await _post(
      relay,
      '/v3/sessions/$id/history?kind=menus&documentId=shop&version=9',
      session['serverToken']! as String,
      <String, Object?>{'protocol': 3, 'found': true, 'json': '{}'},
    );

    expect(response.statusCode, 409);
    expect(
      ((await _json(response))['error']! as Map)['code'],
      'history_not_requested',
    );
  });

  test('the editor token cannot answer and the server token cannot ask', () async {
    final Map<String, Object?> session = await _create(relay);
    final String id = session['sessionId']! as String;

    final Response asked = await _get(
      relay,
      '/v3/sessions/$id/history?kind=menus&documentId=shop&version=9',
      session['serverToken']! as String,
    );
    final Response answered = await _post(
      relay,
      '/v3/sessions/$id/history?kind=menus&documentId=shop&version=9',
      session['editorToken']! as String,
      <String, Object?>{'protocol': 3, 'found': false, 'json': null},
    );

    expect(asked.statusCode, 401);
    expect(answered.statusCode, 401);
  });

  test('a malformed history query is refused before anything waits', () async {
    final Map<String, Object?> session = await _create(relay);
    final String id = session['sessionId']! as String;

    final Response response = await _get(
      relay,
      '/v3/sessions/$id/history?kind=Not-A-Slug&documentId=shop&version=9',
      session['editorToken']! as String,
    );

    expect(response.statusCode, 400);
    expect(
      ((await _json(response))['error']! as Map)['code'],
      'invalid_history_request',
    );
  });
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

Future<Map<String, Object?>> _create(GlossSyncRelay relay) async {
  final Response response = await _post(
    relay,
    '/v3/sessions',
    null,
    <String, Object?>{
      'protocol': 3,
      'expiresInSeconds': 3600,
      'snapshot': _project(),
    },
  );
  expect(response.statusCode, 201);
  return _json(response);
}

Map<String, Object?> _project() => <String, Object?>{
  'format': 'gloss-sync-project',
  'version': 3,
  'kind': 'menu',
  'subjectId': 'main',
  'baseRevision':
      'sha256:0000000000000000000000000000000000000000000000000000000000000000',
  'documents': <Object?>[
    <String, Object?>{
      'kind': 'menu',
      'id': 'main',
      'json': '{"components":[]}',
    },
  ],
  'images': <Object?>[],
  'constraints': <String, Object?>{
    'subjectId': 'main',
    'documentKinds': <String>['menu'],
    'createDocumentKinds': <String>[],
    'newImagePrefix': 'sync/menus/main/',
    'allowDeletes': false,
  },
  'warnings': <Object?>[],
};

Future<Response> _get(GlossSyncRelay relay, String path, String token) async =>
    await relay.handler(
      Request(
        'GET',
        Uri.parse('http://relay.test$path'),
        headers: <String, String>{'authorization': 'Bearer $token'},
      ),
    );

Future<Response> _post(
  GlossSyncRelay relay,
  String path,
  String? token,
  Map<String, Object?> body,
) async => await relay.handler(
  Request(
    'POST',
    Uri.parse('http://relay.test$path'),
    headers: <String, String>{
      'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
    },
    body: jsonEncode(body),
  ),
);

Future<Map<String, Object?>> _json(Response response) async =>
    (jsonDecode(await response.readAsString()) as Map).cast<String, Object?>();

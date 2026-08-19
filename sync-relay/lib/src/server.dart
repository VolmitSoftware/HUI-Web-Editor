library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';

import 'config.dart';
import 'model.dart';
import 'store.dart';

typedef RelayClock = DateTime Function();

final class GlossSyncRelay {
  GlossSyncRelay({
    required this.config,
    required this.store,
    RelayClock? clock,
    Random? random,
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  final RelayConfig config;
  final RelayStore store;
  final RelayClock _clock;
  final Random _random;
  final Map<String, List<DateTime>> _createsByAddress =
      <String, List<DateTime>>{};
  final Map<String, List<DateTime>> _createsByPrincipal =
      <String, List<DateTime>>{};
  Future<void> _sessionCreationTail = Future<void>.value();
  Timer? _cleanupTimer;
  Future<void>? _cleanupTask;

  Future<void> start() async {
    if (config.createTokenHashes.isEmpty && !config.allowAnonymousCreate) {
      throw StateError(
        'create admission is not configured; set create tokens or explicitly allow anonymous create',
      );
    }
    await store.start();
    await cleanupExpired();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _pruneRateWindows(_clock().toUtc());
      unawaited(
        cleanupExpired().catchError((Object error, StackTrace stackTrace) {
          stderr.writeln('Relay cleanup failed: $error');
          stderr.writeln(stackTrace);
        }),
      );
    });
  }

  Future<void> close() async {
    _cleanupTimer?.cancel();
    await _sessionCreationTail;
    final Future<void>? cleanup = _cleanupTask;
    if (cleanup != null) await cleanup;
    await store.close();
  }

  Future<void> cleanupExpired() {
    final Future<void>? active = _cleanupTask;
    if (active != null) return active;
    final Future<void> task = _deleteExpired();
    _cleanupTask = task;
    task.then<void>(
      (_) => _cleanupTask = null,
      onError: (Object _, StackTrace _) => _cleanupTask = null,
    );
    return task;
  }

  Future<void> _deleteExpired() async {
    final DateTime cutoff = _clock().toUtc().subtract(config.maximumTtl);
    final List<RelaySession> sessions = await store.list();
    for (final RelaySession session in sessions) {
      if (!session.expiresAt.isAfter(cutoff)) await store.delete(session.id);
    }
  }

  Handler get handler => _withHeaders(_route);

  Future<Response> _route(Request request) async {
    if (request.method == 'OPTIONS') return _preflight(request);
    final String? origin = request.headers['origin'];
    if (origin != null && !config.allowedOrigins.contains(origin)) {
      return _error(403, 'origin_not_allowed');
    }
    final String path = request.url.path.startsWith('/')
        ? request.url.path
        : '/${request.url.path}';
    final String prefix = config.apiPrefix;
    if (path == '$prefix/health' && request.method == 'GET') {
      return _json(200, <String, Object?>{'status': 'ok', 'protocol': 2});
    }
    if (path == '$prefix/sessions' && request.method == 'POST') {
      final String address = _clientAddress(request);
      final String principal = _authorizeCreate(request, address);
      return _create(request, address, principal);
    }
    if (!path.startsWith('$prefix/sessions/')) return _error(404, 'not_found');
    final String tail = path.substring('$prefix/sessions/'.length);
    final List<String> segments = tail.split('/');
    if (segments.isEmpty || !_capability.hasMatch(segments.first)) {
      return _error(404, 'not_found');
    }
    final String id = segments.first;
    if (segments.length == 1) {
      if (request.method == 'GET') return _fetchEditor(request, id);
      if (request.method == 'DELETE') return _revoke(request, id);
    }
    if (segments.length == 2 && segments[1] == 'publication') {
      if (request.method == 'PUT') return _publish(request, id);
      if (request.method == 'GET') return _fetchPublication(request, id);
    }
    if (segments.length == 4 &&
        segments[1] == 'publication' &&
        int.tryParse(segments[2]) != null &&
        segments[3] == 'ack' &&
        request.method == 'POST') {
      return _acknowledge(request, id, int.parse(segments[2]));
    }
    return _error(404, 'not_found');
  }

  Future<Response> _create(
    Request request,
    String address,
    String principal,
  ) async {
    final DateTime now = _clock().toUtc();
    if (!_consumeCreate(address, principal, now)) {
      return _error(429, 'rate_limited');
    }
    final Map<String, Object?> body = await _body(request);
    _exactKeys(body, <String>{'protocol', 'expiresInSeconds', 'snapshot'});
    _protocol(body);
    final Map<String, Object?> snapshot = requireObject(
      body['snapshot'],
      'snapshot',
    );
    _snapshotSize(snapshot);
    _snapshotShape(snapshot);
    requireRevision(snapshot, 'baseRevision');
    final Object? rawTtl = body['expiresInSeconds'];
    if (rawTtl is! int) throw const RelayProblem(400, 'invalid_ttl');
    final Duration ttl = Duration(seconds: rawTtl);
    if (ttl < config.minimumTtl || ttl > config.maximumTtl) {
      throw const RelayProblem(400, 'invalid_ttl');
    }
    return _serializeSessionCreation(
      () => _createSession(
        now: now,
        ttl: ttl,
        snapshot: snapshot,
        principal: principal,
      ),
    );
  }

  String _authorizeCreate(Request request, String address) {
    final Set<String> expectedHashes = config.createTokenHashes;
    if (expectedHashes.isEmpty) {
      return tokenHash('gloss-anonymous-create-principal-v2:$address');
    }
    final String? authorization = request.headers['authorization'];
    if (authorization == null || !authorization.startsWith('Bearer ')) {
      throw const RelayProblem(401, 'unauthorized');
    }
    final String token = authorization.substring('Bearer '.length);
    final bool validShape = _capability.hasMatch(token);
    final String candidateHash = tokenHash(token);
    final String? matchedHash = expectedHashes.lookup(candidateHash);
    final bool matches = constantTimeEquals(
      candidateHash,
      matchedHash ?? _missingCreateTokenHash,
    );
    if (!validShape || !matches || matchedHash == null) {
      throw const RelayProblem(401, 'unauthorized');
    }
    return tokenHash('gloss-create-principal-v2:$matchedHash');
  }

  Future<Response> _createSession({
    required DateTime now,
    required Duration ttl,
    required Map<String, Object?> snapshot,
    required String principal,
  }) async {
    final List<RelaySession> sessions = await store.list();
    final int reservedSessionBytes =
        config.maximumSnapshotBytes * 2 + RelayConfig.protocolEnvelopeBytes;
    final int reservedBytes = sessions.fold<int>(
      0,
      (int total, RelaySession session) => total + session.reservedBytes,
    );
    if (reservedBytes + reservedSessionBytes > config.maximumStoredBytes) {
      return _error(503, 'storage_capacity_reached');
    }
    final List<RelaySession> principalSessions = sessions
        .where((RelaySession value) => value.createPrincipalHash == principal)
        .toList();
    if (principalSessions.length >=
        config.maximumRetainedSessionsPerPrincipal) {
      return _error(503, 'principal_capacity_reached');
    }
    final int principalReservedBytes = principalSessions.fold<int>(
      0,
      (int total, RelaySession session) => total + session.reservedBytes,
    );
    if (principalReservedBytes + reservedSessionBytes >
        config.maximumStoredBytesPerPrincipal) {
      return _error(503, 'principal_storage_capacity_reached');
    }
    final int active = sessions
        .where(
          (RelaySession value) => !value.isExpired(now) && !value.isRevoked,
        )
        .length;
    if (active >= config.maximumActiveSessions) {
      return _error(503, 'capacity_reached');
    }
    final int principalActive = principalSessions
        .where(
          (RelaySession value) => !value.isExpired(now) && !value.isRevoked,
        )
        .length;
    if (principalActive >= config.maximumActiveSessionsPerPrincipal) {
      return _error(503, 'principal_active_capacity_reached');
    }
    final String baseRevision = requireRevision(snapshot, 'baseRevision');
    String id;
    do {
      id = _capabilityToken();
    } while (await store.read(id) != null);
    String editorToken;
    do {
      editorToken = _capabilityToken();
    } while (editorToken == id);
    String serverToken;
    do {
      serverToken = _capabilityToken();
    } while (serverToken == id || serverToken == editorToken);
    final RelaySession session = RelaySession(
      id: id,
      createPrincipalHash: principal,
      reservedBytes: reservedSessionBytes,
      editorTokenHash: tokenHash(editorToken),
      serverTokenHash: tokenHash(serverToken),
      createdAt: now,
      expiresAt: now.add(ttl),
      baseRevision: baseRevision,
      snapshot: snapshot,
      nextPublicationRevision: 1,
    );
    await store.create(session);
    return _json(201, <String, Object?>{
      'protocol': 2,
      'sessionId': id,
      'editorToken': editorToken,
      'serverToken': serverToken,
      'expiresAt': session.expiresAt.toIso8601String(),
      'baseRevision': baseRevision,
    });
  }

  Future<T> _serializeSessionCreation<T>(Future<T> Function() operation) {
    final Future<T> result = _sessionCreationTail.then<T>((_) => operation());
    _sessionCreationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<Response> _fetchEditor(Request request, String id) async {
    final RelaySession session = await _authorized(request, id, editor: true);
    return _json(200, _sessionEnvelope(session));
  }

  Future<Response> _publish(Request request, String id) async {
    final RelaySession authorized = await _authorized(
      request,
      id,
      editor: true,
    );
    final Map<String, Object?> body = await _body(request);
    _exactKeys(body, <String>{'protocol', 'baseRevision', 'snapshot'});
    _protocol(body);
    final String baseRevision = requireRevision(body, 'baseRevision');
    final Map<String, Object?> snapshot = requireObject(
      body['snapshot'],
      'snapshot',
    );
    _snapshotSize(snapshot, reservedBytes: authorized.reservedBytes);
    _snapshotShape(snapshot);
    requireRevision(snapshot, 'baseRevision');
    if (baseRevision != authorized.baseRevision) {
      return _error(409, 'base_revision_conflict');
    }
    if (authorized.publication?.state == RelayPublicationState.pending) {
      return _error(409, 'publication_pending');
    }
    if (authorized.nextPublicationRevision >= relayMaximumSafeInteger) {
      return _error(409, 'publication_revision_exhausted');
    }
    final RelayPublication publication = RelayPublication(
      revision: authorized.nextPublicationRevision,
      baseRevision: baseRevision,
      snapshot: snapshot,
      publishedAt: _clock().toUtc(),
    );
    await store.update(id, (RelaySession current) {
      _requireLive(current);
      if (current.baseRevision != baseRevision ||
          current.publication?.state == RelayPublicationState.pending) {
        throw const RelayProblem(409, 'base_revision_conflict');
      }
      return current.publish(publication);
    });
    return _json(202, <String, Object?>{
      'protocol': 2,
      'publication': <String, Object?>{
        'revision': publication.revision,
        'state': publication.state.name,
        'publishedAt': publication.publishedAt.toUtc().toIso8601String(),
      },
    });
  }

  Future<Response> _fetchPublication(Request request, String id) async {
    final RelaySession session = await _authorized(request, id, editor: false);
    final Map<String, List<String>> parameters = request.url.queryParametersAll;
    if (parameters.keys.toSet().difference(const <String>{
          'after',
        }).isNotEmpty ||
        parameters['after']?.length != 1) {
      return _error(400, 'invalid_revision');
    }
    final int after = int.tryParse(parameters['after']!.single) ?? -1;
    if (after < 0 || after > relayMaximumSafeInteger) {
      return _error(400, 'invalid_revision');
    }
    final RelayPublication? publication = session.publication;
    if (publication == null ||
        publication.revision <= after ||
        publication.state != RelayPublicationState.pending) {
      return Response(204);
    }
    return _json(200, <String, Object?>{
      'protocol': 2,
      'sessionId': id,
      'publication': <String, Object?>{
        'revision': publication.revision,
        'baseRevision': publication.baseRevision,
        'snapshot': publication.snapshot,
        'publishedAt': publication.publishedAt.toUtc().toIso8601String(),
        'state': publication.state.name,
      },
    });
  }

  Future<Response> _acknowledge(
    Request request,
    String id,
    int revision,
  ) async {
    if (revision < 1 || revision > relayMaximumSafeInteger) {
      return _error(400, 'invalid_revision');
    }
    final RelaySession authorized = await _authorized(
      request,
      id,
      editor: false,
    );
    final Map<String, Object?> body = await _body(request);
    final Object? rawStatusValue = body['status'];
    final Set<String> expectedFields = <String>{
      'protocol',
      'status',
      'message',
      if (rawStatusValue == 'applied' || rawStatusValue == 'conflict')
        'serverRevision',
      if (rawStatusValue == 'applied' || rawStatusValue == 'conflict')
        'snapshot',
    };
    _exactKeys(body, expectedFields);
    _protocol(body);
    final String rawStatus = requireString(body, 'status');
    final RelayPublicationState status;
    try {
      status = RelayPublicationState.values.byName(rawStatus);
    } on ArgumentError {
      return _error(400, 'invalid_ack_status');
    }
    if (status == RelayPublicationState.pending) {
      return _error(400, 'invalid_ack_status');
    }
    final String message = requireString(body, 'message', allowEmpty: true);
    if (message.length > 2048) return _error(400, 'message_too_large');
    final bool promotes =
        status == RelayPublicationState.applied ||
        status == RelayPublicationState.conflict;
    final String? serverRevision = promotes
        ? requireRevision(body, 'serverRevision')
        : null;
    final Map<String, Object?>? snapshot = promotes
        ? requireObject(body['snapshot'], 'snapshot')
        : null;
    if (promotes) {
      _snapshotSize(snapshot!, reservedBytes: authorized.reservedBytes);
      _snapshotShape(snapshot);
      if (requireRevision(snapshot, 'baseRevision') != serverRevision) {
        return _error(400, 'server_revision_mismatch');
      }
    }
    final RelaySession updated = await store.update(id, (RelaySession current) {
      _requireLive(current);
      final RelayPublication? publication = current.publication;
      if (publication == null || publication.revision != revision) {
        throw const RelayProblem(409, 'publication_revision_conflict');
      }
      if (publication.state != RelayPublicationState.pending) {
        if (publication.state == status &&
            publication.ack?.serverRevision == serverRevision &&
            publication.ack?.message == message &&
            (!promotes || _jsonEquivalent(current.snapshot, snapshot))) {
          return current;
        }
        throw const RelayProblem(409, 'publication_already_acknowledged');
      }
      final RelayAck ack = RelayAck(
        status: status,
        message: message,
        serverRevision: serverRevision,
        acknowledgedAt: _clock().toUtc(),
      );
      return current.acknowledge(
        publication.acknowledge(ack),
        promotedSnapshot: snapshot,
        promotedRevision: serverRevision,
      );
    });
    return _json(200, <String, Object?>{
      'protocol': 2,
      'baseRevision': updated.baseRevision,
      'publication': <String, Object?>{
        'revision': updated.publication!.revision,
        'state': updated.publication!.state.name,
        'ack': updated.publication!.ack!.toJson(),
      },
    });
  }

  Future<Response> _revoke(Request request, String id) async {
    await _authorized(request, id, editor: false);
    await store.update(id, (RelaySession current) {
      if (current.isRevoked) return current;
      return current.revoke(_clock().toUtc());
    });
    return Response(204);
  }

  Future<RelaySession> _authorized(
    Request request,
    String id, {
    required bool editor,
  }) async {
    final RelaySession? session = await store.read(id);
    if (session == null) throw const RelayProblem(404, 'not_found');
    final String? authorization = request.headers['authorization'];
    if (authorization == null || !authorization.startsWith('Bearer ')) {
      throw const RelayProblem(401, 'unauthorized');
    }
    final String token = authorization.substring('Bearer '.length);
    if (!_capability.hasMatch(token)) {
      throw const RelayProblem(401, 'unauthorized');
    }
    final String expected = editor
        ? session.editorTokenHash
        : session.serverTokenHash;
    if (!constantTimeEquals(tokenHash(token), expected)) {
      throw const RelayProblem(401, 'unauthorized');
    }
    if (session.isRevoked) throw const RelayProblem(410, 'session_revoked');
    if (session.isExpired(_clock().toUtc())) {
      throw const RelayProblem(410, 'session_expired');
    }
    return session;
  }

  void _requireLive(RelaySession session) {
    if (session.isRevoked) throw const RelayProblem(410, 'session_revoked');
    if (session.isExpired(_clock().toUtc())) {
      throw const RelayProblem(410, 'session_expired');
    }
  }

  Future<Map<String, Object?>> _body(Request request) async {
    final String contentType = request.headers['content-type'] ?? '';
    if (contentType.split(';').first.trim().toLowerCase() !=
        'application/json') {
      throw const RelayProblem(415, 'json_required');
    }
    final String? rawLength = request.headers['content-length'];
    if (rawLength != null) {
      final int? declaredLength = int.tryParse(rawLength);
      if (declaredLength == null || declaredLength < 0) {
        throw const RelayProblem(400, 'invalid_content_length');
      }
      if (declaredLength > config.maximumRequestBytes) {
        throw const RelayProblem(413, 'request_too_large');
      }
    }
    final BytesBuilder bytes = BytesBuilder(copy: false);
    int length = 0;
    final Stopwatch elapsed = Stopwatch()..start();
    try {
      await for (final List<int> chunk in request.read().timeout(
        const Duration(seconds: 30),
      )) {
        if (elapsed.elapsed > const Duration(seconds: 30)) {
          throw const RelayProblem(408, 'request_timeout');
        }
        length += chunk.length;
        if (length > config.maximumRequestBytes) {
          throw const RelayProblem(413, 'request_too_large');
        }
        bytes.add(chunk);
      }
    } on TimeoutException {
      throw const RelayProblem(408, 'request_timeout');
    } finally {
      elapsed.stop();
    }
    try {
      return requireObject(
        jsonDecode(utf8.decode(bytes.takeBytes(), allowMalformed: false)),
        'request',
      );
    } on RelayProblem {
      rethrow;
    } catch (_) {
      throw const RelayProblem(400, 'invalid_json');
    }
  }

  void _snapshotSize(Map<String, Object?> snapshot, {int? reservedBytes}) {
    final int snapshotBytes = utf8.encode(jsonEncode(snapshot)).length;
    if (snapshotBytes > config.maximumSnapshotBytes ||
        (reservedBytes != null &&
            relaySnapshotReservationEnvelopeBytes + (2 * snapshotBytes) >
                reservedBytes)) {
      throw const RelayProblem(413, 'snapshot_too_large');
    }
  }

  void _protocol(Map<String, Object?> body) {
    if (body['protocol'] != 2) {
      throw const RelayProblem(400, 'unsupported_protocol');
    }
  }

  /// Transport-shape validation for protocol-v2 snapshots. The relay checks
  /// ONLY the format identity, the open kind-slug grammar, and bounded sizes.
  /// It never interprets kinds — a new document kind must work against this
  /// relay without a redeploy.
  void _snapshotShape(Map<String, Object?> snapshot) {
    final Object? format = snapshot['format'];
    final Object? version = snapshot['version'];
    if (format == 'holoui-sync-project' || version == 1) {
      throw const RelayProblem(400, 'unsupported_project_format');
    }
    if (format != 'gloss-sync-project' || version != 2) {
      throw const RelayProblem(400, 'unsupported_project_format');
    }
    final Object? kind = snapshot['kind'];
    if (kind is! String || !relayKindSlug.hasMatch(kind)) {
      throw const RelayProblem(400, 'invalid_project_kind');
    }
    final Object? documents = snapshot['documents'];
    if (documents is! List ||
        documents.isEmpty ||
        documents.length > relayMaximumDocuments) {
      throw const RelayProblem(400, 'invalid_project_documents');
    }
    for (final Object? entry in documents) {
      if (entry is! Map) {
        throw const RelayProblem(400, 'invalid_project_documents');
      }
      final Object? entryKind = entry['kind'];
      final Object? id = entry['id'];
      final Object? json = entry['json'];
      final Object? revision = entry['revision'];
      if (entryKind is! String ||
          !relayKindSlug.hasMatch(entryKind) ||
          id is! String ||
          id.isEmpty ||
          id.length > 256 ||
          json is! String ||
          json.isEmpty ||
          (revision != null &&
              (revision is! int ||
                  revision < 1 ||
                  revision > relayMaximumSafeInteger)) ||
          entry.keys.any(
            (Object? key) =>
                key != 'kind' &&
                key != 'id' &&
                key != 'revision' &&
                key != 'json',
          )) {
        throw const RelayProblem(400, 'invalid_project_documents');
      }
    }
  }

  void _exactKeys(Map<String, Object?> body, Set<String> allowed) {
    if (!body.keys.toSet().containsAll(allowed) ||
        body.keys.any((String key) => !allowed.contains(key))) {
      throw const RelayProblem(400, 'invalid_fields');
    }
  }

  String _capabilityToken() {
    final Uint8List bytes = Uint8List(32);
    for (int index = 0; index < bytes.length; index++) {
      bytes[index] = _random.nextInt(256);
    }
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  bool _consumeCreate(String address, String principal, DateTime now) {
    final DateTime cutoff = now.subtract(const Duration(minutes: 1));
    List<DateTime>? addressWindow = _pruneRateWindow(
      _createsByAddress,
      address,
      cutoff,
    );
    List<DateTime>? principalWindow = _pruneRateWindow(
      _createsByPrincipal,
      principal,
      cutoff,
    );
    if (addressWindow == null &&
        _createsByAddress.length >= config.maximumRateLimitAddresses) {
      _pruneRateMap(_createsByAddress, cutoff);
      if (_createsByAddress.length >= config.maximumRateLimitAddresses) {
        return false;
      }
    }
    final int maximumPrincipals =
        config.maximumRateLimitAddresses + config.createTokenHashes.length;
    if (principalWindow == null &&
        _createsByPrincipal.length >= maximumPrincipals) {
      _pruneRateMap(_createsByPrincipal, cutoff);
      if (_createsByPrincipal.length >= maximumPrincipals) return false;
    }
    final List<DateTime> currentAddressWindow = addressWindow ?? <DateTime>[];
    final List<DateTime> currentPrincipalWindow =
        principalWindow ?? <DateTime>[];
    if (currentAddressWindow.length >=
            config.maximumSessionsPerAddressPerMinute ||
        currentPrincipalWindow.length >=
            config.maximumSessionsPerPrincipalPerMinute) {
      return false;
    }
    _createsByAddress.putIfAbsent(address, () => currentAddressWindow).add(now);
    _createsByPrincipal
        .putIfAbsent(principal, () => currentPrincipalWindow)
        .add(now);
    return true;
  }

  List<DateTime>? _pruneRateWindow(
    Map<String, List<DateTime>> windows,
    String key,
    DateTime cutoff,
  ) {
    final List<DateTime>? window = windows[key];
    if (window == null) return null;
    window.removeWhere((DateTime value) => value.isBefore(cutoff));
    if (window.isNotEmpty) return window;
    windows.remove(key);
    return null;
  }

  void _pruneRateWindows(DateTime now) {
    final DateTime cutoff = now.subtract(const Duration(minutes: 1));
    _pruneRateMap(_createsByAddress, cutoff);
    _pruneRateMap(_createsByPrincipal, cutoff);
  }

  void _pruneRateMap(Map<String, List<DateTime>> windows, DateTime cutoff) {
    windows.removeWhere((String _, List<DateTime> values) {
      values.removeWhere((DateTime value) => value.isBefore(cutoff));
      return values.isEmpty;
    });
  }

  String _clientAddress(Request request) {
    if (config.trustProxy) {
      final String? forwarded = request.headers['x-forwarded-for'];
      if (forwarded != null) {
        final String first = forwarded.split(',').first.trim();
        final InternetAddress? address = InternetAddress.tryParse(first);
        if (address != null) return address.address;
      }
    }
    return request.context['shelf.io.connection_info'] is HttpConnectionInfo
        ? (request.context['shelf.io.connection_info']! as HttpConnectionInfo)
              .remoteAddress
              .address
        : 'unknown';
  }

  Map<String, Object?> _sessionEnvelope(RelaySession session) =>
      <String, Object?>{
        'protocol': 2,
        'sessionId': session.id,
        'status': session.status,
        'expiresAt': session.expiresAt.toIso8601String(),
        'baseRevision': session.baseRevision,
        'snapshot': session.snapshot,
        'publication': session.publication?.toJson(),
      };

  Handler _withHeaders(Handler inner) => (Request request) async {
    try {
      final Response response = await inner(request);
      return _secure(response, request);
    } on RelayProblem catch (problem) {
      return _secure(_error(problem.status, problem.code), request);
    } on FormatException {
      return _secure(_error(400, 'invalid_request'), request);
    } catch (error, stackTrace) {
      stderr.writeln('Relay request failed: $error');
      stderr.writeln(stackTrace);
      return _secure(_error(500, 'internal_error'), request);
    }
  };

  Response _secure(Response response, Request request) {
    final Map<String, String> headers = <String, String>{
      ...response.headers,
      'cache-control': 'no-store',
      'x-content-type-options': 'nosniff',
      'referrer-policy': 'no-referrer',
      'content-security-policy': "default-src 'none'; frame-ancestors 'none'",
      'permissions-policy': 'camera=(), microphone=(), geolocation=()',
    };
    final String? origin = request.headers['origin'];
    if (origin != null && config.allowedOrigins.contains(origin)) {
      headers['access-control-allow-origin'] = origin;
      headers['vary'] = 'Origin';
    }
    return response.change(headers: headers);
  }

  Response _preflight(Request request) {
    final String? origin = request.headers['origin'];
    if (origin == null || !config.allowedOrigins.contains(origin)) {
      return _error(403, 'origin_not_allowed');
    }
    final String? requestedMethod =
        request.headers['access-control-request-method'];
    if (requestedMethod != null &&
        !const <String>{
          'GET',
          'POST',
          'PUT',
          'DELETE',
        }.contains(requestedMethod.toUpperCase())) {
      return _error(403, 'cors_method_not_allowed');
    }
    return Response(
      204,
      headers: <String, String>{
        'access-control-allow-origin': origin,
        'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'access-control-allow-headers': 'Authorization, Content-Type',
        'access-control-max-age': '600',
        'vary': 'Origin',
      },
    );
  }

  Response _json(int status, Object body) {
    final Uint8List encoded = utf8.encode(jsonEncode(body));
    if (encoded.length > config.maximumResponseBytes) {
      return Response(
        500,
        body: jsonEncode(<String, Object?>{
          'protocol': 2,
          'error': <String, Object?>{
            'code': 'response_too_large',
            'message': 'response too large',
          },
        }),
        headers: const <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    }
    return Response(
      status,
      body: encoded,
      headers: const <String, String>{
        'content-type': 'application/json; charset=utf-8',
      },
    );
  }

  Response _error(int status, String code) => _json(status, <String, Object?>{
    'protocol': 2,
    'error': <String, Object?>{
      'code': code,
      'message': code.replaceAll('_', ' '),
    },
  });
}

final class RelayProblem implements Exception {
  const RelayProblem(this.status, this.code);

  final int status;
  final String code;
}

final RegExp _capability = RegExp(r'^[A-Za-z0-9_-]{22,128}$');
const String _missingCreateTokenHash =
    '0000000000000000000000000000000000000000000000000000000000000000';

bool _jsonEquivalent(Object? left, Object? right) {
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final Object? key in left.keys) {
      if (!right.containsKey(key) || !_jsonEquivalent(left[key], right[key])) {
        return false;
      }
    }
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (int index = 0; index < left.length; index++) {
      if (!_jsonEquivalent(left[index], right[index])) return false;
    }
    return true;
  }
  return left == right;
}

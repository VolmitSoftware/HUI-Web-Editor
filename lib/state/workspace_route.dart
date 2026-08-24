library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../config/defaults.dart';
import '../l10n/hui_localizations.dart';
import '../model/model.dart';
import 'workspace.dart';

sealed class WorkspaceRoute {
  const WorkspaceRoute();
}

final class WorkspaceDocumentRoute extends WorkspaceRoute {
  const WorkspaceDocumentRoute({
    required this.workspaceId,
    required this.documentId,
  });

  final String workspaceId;
  final String documentId;
}

final class WorkspaceMenuImportRoute extends WorkspaceRoute {
  const WorkspaceMenuImportRoute(this.envelope);

  final WorkspaceMenuImportEnvelope envelope;
}

final class WorkspaceSyncRoute extends WorkspaceRoute {
  const WorkspaceSyncRoute({
    required this.sessionId,
    required this.editorToken,
    required this.relayEndpoint,
  });

  final String sessionId;
  final String editorToken;

  final Uri relayEndpoint;
}

final class WorkspaceMenuImportEnvelope {
  const WorkspaceMenuImportEnvelope({
    required this.runtimeId,
    required this.json,
  });

  static const int version = 1;
  static const String kind = 'menu';

  final String runtimeId;
  final String json;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'kind': kind,
    'runtimeId': runtimeId,
    'json': json,
  };
}

final class WorkspaceRouteResult {
  const WorkspaceRouteResult({this.route, String? error}) : _error = error;

  final WorkspaceRoute? route;
  final String? _error;

  String? get error => _error == null ? null : huiText(_error);
}

String workspaceDocumentHash(String workspaceId, String documentId) =>
    '#/workspace/$workspaceId/document/$documentId';

String workspaceMenuImportHash(WorkspaceMenuImportEnvelope envelope) {
  final List<int> encoded = utf8.encode(jsonEncode(envelope.toJson()));
  final List<int> compressed = const GZipEncoder().encodeBytes(encoded);
  return '#/import/menu/${base64Url.encode(compressed).replaceAll('=', '')}';
}

WorkspaceRouteResult parseWorkspaceRoute(String rawHash) {
  final String hash = rawHash.trim();
  if (hash.isEmpty || hash == '#') return const WorkspaceRouteResult();
  if (!hash.startsWith('#/')) {
    return const WorkspaceRouteResult(error: 'The editor link is malformed.');
  }
  final List<String> segments = hash.substring(2).split('/');
  if (segments.length == 4 &&
      segments[0] == 'workspace' &&
      segments[2] == 'document') {
    final String workspaceId = segments[1];
    final String documentId = segments[3];
    if (!isWorkspaceUuid(workspaceId) || !isWorkspaceUuid(documentId)) {
      return const WorkspaceRouteResult(
        error: 'The workspace link contains an invalid id.',
      );
    }
    return WorkspaceRouteResult(
      route: WorkspaceDocumentRoute(
        workspaceId: workspaceId,
        documentId: documentId,
      ),
    );
  }
  if (segments.length == 3 &&
      segments[0] == 'import' &&
      segments[1] == WorkspaceMenuImportEnvelope.kind) {
    return _decodeMenuEnvelope(segments[2]);
  }
  if (segments.length == 3 && segments[0] == 'sync') {
    return _decodeSyncRoute(segments[1], segments[2]);
  }
  return const WorkspaceRouteResult(error: 'The editor link is not supported.');
}

WorkspaceRouteResult _decodeSyncRoute(String sessionId, String tokenAndQuery) {
  final int question = tokenAndQuery.indexOf('?');
  if (question <= 0 || tokenAndQuery.indexOf('?', question + 1) >= 0) {
    return const WorkspaceRouteResult(
      error: 'The server sync link is malformed.',
    );
  }
  final String editorToken = tokenAndQuery.substring(0, question);
  final String query = tokenAndQuery.substring(question + 1);
  if (!_syncCapabilityPattern.hasMatch(sessionId) ||
      !_syncCapabilityPattern.hasMatch(editorToken)) {
    return const WorkspaceRouteResult(
      error: 'The server sync link contains an invalid capability.',
    );
  }
  final Uri queryUri;
  try {
    queryUri = Uri.parse('https://editor.invalid/?$query');
  } catch (_) {
    return const WorkspaceRouteResult(
      error: 'The server sync relay is malformed.',
    );
  }
  if (queryUri.queryParametersAll.length != 1 ||
      queryUri.queryParametersAll['relay']?.length != 1) {
    return const WorkspaceRouteResult(
      error: 'The server sync link must name exactly one relay.',
    );
  }
  final String encodedRelay = queryUri.queryParameters['relay'] ?? '';
  if (query != 'relay=$encodedRelay' ||
      encodedRelay.isEmpty ||
      encodedRelay.length > _maxRelayEncodingLength ||
      !_unpaddedBase64UrlPattern.hasMatch(encodedRelay)) {
    return const WorkspaceRouteResult(
      error: 'The server sync relay is empty or too large.',
    );
  }
  final String decodedRelay;
  try {
    final int padding = (4 - encodedRelay.length % 4) % 4;
    final String suffix = List<String>.filled(padding, '=').join();
    final List<int> bytes = base64Url.decode('$encodedRelay$suffix');
    decodedRelay = utf8.decode(bytes, allowMalformed: false);
    if (base64Url.encode(bytes).replaceAll('=', '') != encodedRelay) {
      throw const FormatException('Non-canonical relay encoding.');
    }
  } catch (_) {
    return const WorkspaceRouteResult(
      error: 'The server sync relay is not valid base64url UTF-8.',
    );
  }
  final Uri? relay = validateEditorSyncRelay(decodedRelay);
  if (relay == null) {
    return const WorkspaceRouteResult(
      error:
          'The server sync relay must use HTTPS (localhost may use HTTP) and end in /v3.',
    );
  }
  return WorkspaceRouteResult(
    route: WorkspaceSyncRoute(
      sessionId: sessionId,
      editorToken: editorToken,
      relayEndpoint: relay,
    ),
  );
}

Uri? validateEditorSyncRelay(String raw) {
  if (raw.isEmpty || raw.length > _maxRelayDecodedLength) return null;
  final Uri relay;
  try {
    relay = Uri.parse(raw);
  } catch (_) {
    return null;
  }
  if (!relay.hasAuthority ||
      relay.host.isEmpty ||
      relay.userInfo.isNotEmpty ||
      relay.query.isNotEmpty ||
      relay.fragment.isNotEmpty) {
    return null;
  }
  final bool local =
      relay.host == 'localhost' ||
      relay.host == '127.0.0.1' ||
      relay.host == '::1';
  if (relay.scheme != 'https' && !(relay.scheme == 'http' && local)) {
    return null;
  }
  String path = relay.path;
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (!path.endsWith('/v3')) return null;
  return relay.replace(path: path);
}

bool isValidEditorSyncCapability(String value) =>
    _syncCapabilityPattern.hasMatch(value);

String workspaceSyncHash({
  required String sessionId,
  required String editorToken,
  required Uri relayEndpoint,
}) {
  final String relay = base64Url
      .encode(utf8.encode(relayEndpoint.toString()))
      .replaceAll('=', '');
  return '#/sync/$sessionId/$editorToken?relay=$relay';
}

WorkspaceRouteResult _decodeMenuEnvelope(String payload) {
  if (payload.isEmpty || payload.length > _maxEncodedEnvelopeLength) {
    return const WorkspaceRouteResult(
      error: 'The menu handoff payload is empty or too large.',
    );
  }
  final List<int> compressed;
  try {
    final int padding = (4 - payload.length % 4) % 4;
    final String suffix = List<String>.filled(padding, '=').join();
    compressed = base64Url.decode('$payload$suffix');
  } catch (_) {
    return const WorkspaceRouteResult(
      error: 'The menu handoff payload is not valid base64url.',
    );
  }
  final List<int> decoded;
  try {
    decoded = _decodeBoundedGzipMember(compressed);
  } on _DecodedEnvelopeTooLarge {
    return const WorkspaceRouteResult(
      error: 'The decoded menu handoff is too large.',
    );
  } catch (_) {
    return const WorkspaceRouteResult(
      error: 'The menu handoff payload is not valid gzip data.',
    );
  }
  final Object? raw;
  try {
    raw = jsonDecode(utf8.decode(decoded));
  } catch (_) {
    return const WorkspaceRouteResult(
      error: 'The menu handoff envelope is not valid UTF-8 JSON.',
    );
  }
  if (raw is! Map) {
    return const WorkspaceRouteResult(
      error: 'The menu handoff envelope must be a JSON object.',
    );
  }
  if (raw['version'] != WorkspaceMenuImportEnvelope.version ||
      raw['kind'] != WorkspaceMenuImportEnvelope.kind) {
    return const WorkspaceRouteResult(
      error: 'The menu handoff envelope version or kind is unsupported.',
    );
  }
  final Object? runtimeId = raw['runtimeId'];
  final Object? json = raw['json'];
  if (runtimeId is! String || !isCanonicalMenuId(runtimeId)) {
    return const WorkspaceRouteResult(
      error: 'The menu handoff runtime id is not canonical.',
    );
  }
  if (json is! String || json.isEmpty || json.length > _maxMenuJsonLength) {
    return const WorkspaceRouteResult(
      error: 'The menu handoff JSON is empty or too large.',
    );
  }
  try {
    decodeHuiMenu(json);
  } catch (_) {
    return const WorkspaceRouteResult(
      error: 'The menu handoff does not contain valid Gloss menu JSON.',
    );
  }
  return WorkspaceRouteResult(
    route: WorkspaceMenuImportRoute(
      WorkspaceMenuImportEnvelope(runtimeId: runtimeId, json: json),
    ),
  );
}

Uint8List _decodeBoundedGzipMember(List<int> compressed) {
  final InputMemoryStream input = InputMemoryStream(compressed);
  _readGzipHeader(input);
  final _BoundedOutputStream output = _BoundedOutputStream(
    _maxDecodedEnvelopeLength,
  );
  Inflate.stream(input, output: output);
  if (input.length < 8) {
    throw const FormatException('Missing gzip footer.');
  }
  final int expectedCrc = input.readUint32();
  final int expectedLength = input.readUint32();
  if (!input.isEOS) {
    throw const FormatException(
      'Concatenated gzip members and trailing bytes are not supported.',
    );
  }
  if (expectedLength > _maxDecodedEnvelopeLength) {
    throw const _DecodedEnvelopeTooLarge();
  }
  final Uint8List decoded = output.getBytes();
  if (expectedLength != decoded.length || getCrc32(decoded) != expectedCrc) {
    throw const FormatException('The gzip checksum or size is invalid.');
  }
  return decoded;
}

void _readGzipHeader(InputMemoryStream input) {
  if (input.length < 10 ||
      input.readByte() != 0x1f ||
      input.readByte() != 0x8b ||
      input.readByte() != 8) {
    throw const FormatException('Invalid gzip header.');
  }
  final int flags = input.readByte();
  if ((flags & 0xe0) != 0) {
    throw const FormatException('Invalid gzip flags.');
  }
  input.skip(6);
  if ((flags & 0x04) != 0) {
    if (input.length < 2) throw const FormatException('Invalid gzip extra.');
    final int extraLength = input.readUint16();
    if (input.length < extraLength) {
      throw const FormatException('Invalid gzip extra.');
    }
    input.skip(extraLength);
  }
  if ((flags & 0x08) != 0) _skipGzipString(input);
  if ((flags & 0x10) != 0) _skipGzipString(input);
  if ((flags & 0x02) != 0) {
    if (input.length < 2) {
      throw const FormatException('Invalid gzip header checksum.');
    }
    input.skip(2);
  }
  if (input.length < 9) {
    throw const FormatException('Missing gzip body or footer.');
  }
}

void _skipGzipString(InputMemoryStream input) {
  while (!input.isEOS) {
    if (input.readByte() == 0) return;
  }
  throw const FormatException('Unterminated gzip header string.');
}

final class _BoundedOutputStream extends OutputStream {
  _BoundedOutputStream(this.maximumLength)
    : _buffer = Uint8List(
        maximumLength < _initialCapacity ? maximumLength : _initialCapacity,
      ),
      super(byteOrder: ByteOrder.littleEndian);

  static const int _initialCapacity = 32 * 1024;

  final int maximumLength;
  Uint8List _buffer;
  int _length = 0;

  @override
  int get length => _length;

  @override
  void clear() {
    _length = 0;
  }

  @override
  void flush() {}

  @override
  Uint8List getBytes() => subset(0, _length);

  @override
  Uint8List subset(int start, [int? end]) {
    final int resolvedStart = start < 0 ? _length + start : start;
    final int requestedEnd = end ?? _length;
    final int resolvedEnd = requestedEnd < 0
        ? _length + requestedEnd
        : requestedEnd;
    if (resolvedStart < 0 ||
        resolvedEnd < resolvedStart ||
        resolvedEnd > _length) {
      throw const FormatException('Invalid inflate output range.');
    }
    return Uint8List.view(
      _buffer.buffer,
      _buffer.offsetInBytes + resolvedStart,
      resolvedEnd - resolvedStart,
    );
  }

  @override
  void writeByte(int value) {
    _ensureCapacity(1);
    _buffer[_length++] = value;
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final int count = length ?? bytes.length;
    if (count < 0 || count > bytes.length) {
      throw const FormatException('Invalid inflate output length.');
    }
    _ensureCapacity(count);
    _buffer.setRange(_length, _length + count, bytes);
    _length += count;
  }

  @override
  void writeStream(InputStream stream) {
    final int count = stream.length;
    _ensureCapacity(count);
    _buffer.setRange(_length, _length + count, stream.toUint8List());
    _length += count;
  }

  void _ensureCapacity(int additionalLength) {
    final int required = _length + additionalLength;
    if (additionalLength < 0 || required > maximumLength) {
      throw const _DecodedEnvelopeTooLarge();
    }
    if (required <= _buffer.length) return;
    int capacity = _buffer.isEmpty ? 1 : _buffer.length;
    while (capacity < required) {
      final int doubled = capacity * 2;
      capacity = doubled > maximumLength ? maximumLength : doubled;
    }
    final Uint8List expanded = Uint8List(capacity)
      ..setRange(0, _length, _buffer);
    _buffer = expanded;
  }
}

final class _DecodedEnvelopeTooLarge implements Exception {
  const _DecodedEnvelopeTooLarge();
}

const int _maxEncodedEnvelopeLength = 48_000;
const int _maxDecodedEnvelopeLength = 2 * 1024 * 1024;
const int _maxMenuJsonLength = 2 * 1024 * 1024;
const int _maxRelayEncodingLength = 2048;
const int _maxRelayDecodedLength = 1024;
final RegExp _syncCapabilityPattern = RegExp(r'^[A-Za-z0-9_-]{22,128}$');
final RegExp _unpaddedBase64UrlPattern = RegExp(r'^[A-Za-z0-9_-]+$');

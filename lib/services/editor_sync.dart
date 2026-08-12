library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart' as crypto;

import '../config/defaults.dart';
import '../logic/validation.dart';
import '../model/model.dart';
import '../state/workspace.dart';
import '../state/workspace_board.dart';
import 'editor_sync_binding_storage.dart';
import 'image_library.dart';

const int huiEditorSyncProtocol = 1;
const int huiEditorSyncMaxProjectBytes = 32 * 1024 * 1024;
const int huiEditorSyncMaxResponseEnvelopeBytes = 256 * 1024;
const int huiEditorSyncMaxRequestBytes =
    huiEditorSyncMaxProjectBytes + huiEditorSyncMaxResponseEnvelopeBytes;
const int huiEditorSyncMaxResponseBytes =
    (huiEditorSyncMaxProjectBytes * 2) + huiEditorSyncMaxResponseEnvelopeBytes;
const int huiEditorSyncMaxMenus = 256;
const int huiEditorSyncMaxImages = 512;
const int huiEditorSyncMaxImageDimension = 64;
const int huiEditorSyncMaxImagePixels = 64 * 64;
const int huiEditorSyncMaxAssetPixels = 262144;
const int huiEditorSyncMaxRenderPixels = 262144;
const int huiEditorSyncMaxRenderRows = 4096;
const int huiEditorSyncMaxSafeInteger = 9007199254740991;

enum EditorSyncStatus {
  connected,
  pending,
  applied,
  conflict,
  rejected,
  expired,
  revoked,
  disconnected,
  unavailable,
}

enum EditorSyncAppliedDecision { reconcile, preserveLocalConflict }

final class EditorSyncAppliedResolution {
  const EditorSyncAppliedResolution({
    required this.decision,
    required this.binding,
  });

  final EditorSyncAppliedDecision decision;
  final EditorSyncBinding binding;
}

final class EditorSyncPollGate {
  EditorSyncBinding? _inFlight;
  bool _queued = false;

  EditorSyncBinding? begin(EditorSyncBinding binding) {
    if (_inFlight != null) {
      _queued = true;
      return null;
    }
    _inFlight = binding;
    return binding;
  }

  bool shouldApply(EditorSyncBinding captured, EditorSyncBinding? current) =>
      identical(_inFlight, captured) &&
      current != null &&
      current.sessionId == captured.sessionId &&
      current.baseRevision == captured.baseRevision &&
      current.pendingContentRevision == captured.pendingContentRevision;

  bool complete(EditorSyncBinding captured) {
    if (!identical(_inFlight, captured)) return false;
    _inFlight = null;
    final bool followUp = _queued;
    _queued = false;
    return followUp;
  }

  void reset() {
    _inFlight = null;
    _queued = false;
  }
}

final class EditorSyncMenu {
  const EditorSyncMenu({required this.id, required this.json});

  final String id;
  final String json;

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'json': json};
}

final class EditorSyncImage {
  const EditorSyncImage({required this.path, required this.data});

  final String path;
  final String data;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'path': path,
    'data': data,
  };
}

final class EditorSyncConstraints {
  const EditorSyncConstraints({
    required this.subjectId,
    required this.menuIds,
    required this.imagePaths,
    this.newMenuPrefix,
    this.newImagePrefix,
  });

  final String subjectId;
  final List<String> menuIds;
  final List<String> imagePaths;
  final String? newMenuPrefix;
  final String? newImagePrefix;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'subjectId': subjectId,
    'menuIds': menuIds,
    'imagePaths': imagePaths,
    if (newMenuPrefix != null) 'newMenuPrefix': newMenuPrefix,
    if (newImagePrefix != null) 'newImagePrefix': newImagePrefix,
    'allowDeletes': false,
  };

  static EditorSyncConstraints decode(Object? raw) {
    if (raw is! Map ||
        raw.keys.any(
          (Object? key) =>
              key is! String ||
              !const <String>{
                'subjectId',
                'menuIds',
                'imagePaths',
                'newMenuPrefix',
                'newImagePrefix',
                'allowDeletes',
              }.contains(key),
        ) ||
        raw['subjectId'] is! String ||
        (raw['subjectId'] as String).isEmpty ||
        raw['menuIds'] is! List ||
        raw['imagePaths'] is! List ||
        raw['allowDeletes'] != false) {
      throw const FormatException('Sync constraints are missing.');
    }
    final List<String> menuIds = _strictStrings(raw['menuIds'], 'menu id');
    final List<String> imagePaths = _strictStrings(
      raw['imagePaths'],
      'image path',
    );
    if (menuIds.any((String id) => !isCanonicalMenuId(id)) ||
        imagePaths.any((String path) => !_validSyncImagePath(path)) ||
        !_isSorted(menuIds) ||
        !_isSorted(imagePaths)) {
      throw const FormatException('Sync constraints contain invalid paths.');
    }
    final Object? newMenuPrefix = raw['newMenuPrefix'];
    final Object? newImagePrefix = raw['newImagePrefix'];
    if (newImagePrefix is! String ||
        !_validPrefix(newMenuPrefix, menu: true) ||
        !_validPrefix(newImagePrefix, menu: false)) {
      throw const FormatException('Sync constraints contain invalid prefixes.');
    }
    return EditorSyncConstraints(
      subjectId: raw['subjectId'] as String,
      menuIds: List<String>.unmodifiable(menuIds),
      imagePaths: List<String>.unmodifiable(imagePaths),
      newMenuPrefix: newMenuPrefix as String?,
      newImagePrefix: newImagePrefix as String?,
    );
  }
}

final class EditorSyncProject {
  const EditorSyncProject({
    required this.kind,
    required this.subjectId,
    required this.baseRevision,
    required this.menus,
    required this.images,
    required this.constraints,
    this.board,
    this.warnings = const <String>[],
  });

  final String kind;
  final String subjectId;
  final String baseRevision;
  final List<EditorSyncMenu> menus;
  final Map<String, dynamic>? board;
  final List<EditorSyncImage> images;
  final EditorSyncConstraints constraints;
  final List<String> warnings;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'format': 'holoui-sync-project',
    'version': 1,
    'kind': kind,
    'subjectId': subjectId,
    'baseRevision': baseRevision,
    'menus': menus.map((EditorSyncMenu menu) => menu.toJson()).toList(),
    if (board != null) 'board': board,
    'images': images.map((EditorSyncImage image) => image.toJson()).toList(),
    'constraints': constraints.toJson(),
    'warnings': warnings,
  };

  static EditorSyncProject decode(Object? raw) {
    if (raw is! Map ||
        raw['format'] != 'holoui-sync-project' ||
        raw['version'] != 1) {
      throw const FormatException('Unsupported HoloUI sync project.');
    }
    final Object? kind = raw['kind'];
    final Object? subjectId = raw['subjectId'];
    final Object? baseRevision = raw['baseRevision'];
    if ((kind != 'menu' && kind != 'board') ||
        subjectId is! String ||
        subjectId.isEmpty ||
        !isCanonicalMenuId(subjectId) ||
        (kind == 'board' && subjectId != subjectId.toLowerCase()) ||
        baseRevision is! String ||
        !_revisionPattern.hasMatch(baseRevision)) {
      throw const FormatException('Invalid HoloUI sync project identity.');
    }
    final Set<String> projectKeys = <String>{
      'format',
      'version',
      'kind',
      'subjectId',
      'baseRevision',
      'menus',
      if (kind == 'board') 'board',
      'images',
      'constraints',
      'warnings',
    };
    if (raw.length != projectKeys.length ||
        raw.keys.any((Object? key) => !projectKeys.contains(key))) {
      throw const FormatException('Sync project fields are invalid.');
    }
    final Object? rawMenus = raw['menus'];
    if (rawMenus is! List ||
        rawMenus.isEmpty ||
        rawMenus.length > huiEditorSyncMaxMenus) {
      throw const FormatException('Invalid HoloUI sync menu collection.');
    }
    final List<EditorSyncMenu> menus = <EditorSyncMenu>[];
    final Set<String> menuIds = <String>{};
    for (final Object? entry in rawMenus) {
      if (entry is! Map ||
          entry.length != 2 ||
          entry.keys.any((Object? key) => key != 'id' && key != 'json')) {
        throw const FormatException('Invalid HoloUI sync menu entry.');
      }
      final Object? id = entry['id'];
      final Object? json = entry['json'];
      if (id is! String ||
          !isCanonicalMenuId(id) ||
          !menuIds.add(id) ||
          json is! String ||
          json.isEmpty ||
          utf8.encode(json).length > 2 * 1024 * 1024) {
        throw const FormatException('Invalid HoloUI sync menu entry.');
      }
      decodeHuiMenu(json);
      menus.add(EditorSyncMenu(id: id, json: json));
    }
    if (kind == 'menu' && (menus.length != 1 || menus.first.id != subjectId)) {
      throw const FormatException(
        'Menu sync scope does not match its subject.',
      );
    }
    if (!_isSorted(menus.map((EditorSyncMenu menu) => menu.id))) {
      throw const FormatException('Sync menus must be sorted by id.');
    }
    Map<String, dynamic>? board;
    final Object? rawBoard = raw['board'];
    if (kind == 'board') {
      if (rawBoard is! Map) {
        throw const FormatException(
          'Board sync is missing its board definition.',
        );
      }
      board = _copyStringMap(rawBoard);
      final String? boardProblem = editorSyncBoardDefinitionProblem(
        board,
        menuIds,
      );
      if (boardProblem != null || board['id'] != subjectId) {
        throw const FormatException('The world board identity is invalid.');
      }
    } else if (rawBoard != null) {
      throw const FormatException('Menu sync must not contain a board.');
    }
    final Object? rawImages = raw['images'];
    final List<EditorSyncImage> images = <EditorSyncImage>[];
    final Set<String> imagePaths = <String>{};
    final Map<String, StoredImageData> decodedImages =
        <String, StoredImageData>{};
    int assetPixels = 0;
    if (rawImages is! List || rawImages.length > huiEditorSyncMaxImages) {
      throw const FormatException('Invalid HoloUI sync image collection.');
    }
    for (final Object? entry in rawImages) {
      if (entry is! Map ||
          entry.length != 2 ||
          entry.keys.any((Object? key) => key != 'path' && key != 'data')) {
        throw const FormatException('Invalid HoloUI sync image entry.');
      }
      final Object? path = entry['path'];
      final Object? data = entry['data'];
      if (path is! String ||
          !_validSyncImagePath(path) ||
          !imagePaths.add(path) ||
          data is! String ||
          data.length > huiMaxStoredImageBytes * 2) {
        throw const FormatException('Invalid HoloUI sync image entry.');
      }
      final StoredImageData? decoded = decodeSupportedImageData(data);
      if (decoded == null ||
          decoded.bytes.length > huiMaxStoredImageBytes ||
          decoded.width > huiEditorSyncMaxImageDimension ||
          decoded.height > huiEditorSyncMaxImageDimension ||
          decoded.width * decoded.height > huiEditorSyncMaxImagePixels) {
        throw const FormatException('HoloUI sync image has invalid bytes.');
      }
      assetPixels += decoded.width * decoded.height;
      if (assetPixels > huiEditorSyncMaxAssetPixels) {
        throw const FormatException(
          'HoloUI sync images exceed the decoded asset budget.',
        );
      }
      decodedImages[path] = decoded;
      images.add(EditorSyncImage(path: path, data: data));
    }
    if (!_isSorted(images.map((EditorSyncImage image) => image.path))) {
      throw const FormatException('Sync images must be sorted by path.');
    }
    final EditorSyncConstraints constraints = EditorSyncConstraints.decode(
      raw['constraints'],
    );
    if (constraints.subjectId != subjectId) {
      throw const FormatException('Sync constraints do not match the subject.');
    }
    if ((kind == 'board' && constraints.newMenuPrefix == null) ||
        (kind == 'menu' && constraints.newMenuPrefix != null) ||
        constraints.newImagePrefix !=
            (kind == 'board' ? 'sync/$subjectId/' : 'sync/menus/$subjectId/')) {
      throw const FormatException('Sync menu creation scope is invalid.');
    }
    if (kind == 'menu' &&
        (constraints.menuIds.length != 1 ||
            constraints.menuIds.single != subjectId)) {
      throw const FormatException('Menu sync constraints are invalid.');
    }
    if (kind == 'board') {
      final String rootMenuId = board!['rootMenuId']! as String;
      final int separator = rootMenuId.lastIndexOf('/');
      final String expectedPrefix = separator >= 0
          ? rootMenuId.substring(0, separator + 1)
          : '$rootMenuId/';
      if (constraints.newMenuPrefix != expectedPrefix ||
          !constraints.menuIds.contains(rootMenuId)) {
        throw const FormatException('Board sync constraints are invalid.');
      }
    }
    if (menuIds.any(
          (String id) =>
              !constraints.menuIds.contains(id) &&
              (constraints.newMenuPrefix == null ||
                  !id.startsWith(constraints.newMenuPrefix!)),
        ) ||
        imagePaths.any(
          (String path) =>
              !constraints.imagePaths.contains(path) &&
              (constraints.newImagePrefix == null ||
                  !path.startsWith(constraints.newImagePrefix!)),
        )) {
      throw const FormatException('Sync snapshot exceeds its constraints.');
    }
    if (constraints.menuIds.any((String id) => !menuIds.contains(id)) ||
        constraints.imagePaths.any(
          (String path) => !imagePaths.contains(path),
        )) {
      throw const FormatException(
        'Sync snapshots cannot delete captured menus or images.',
      );
    }
    final Object? rawWarnings = raw['warnings'];
    if (rawWarnings is! List || rawWarnings.length > 256) {
      throw const FormatException('Sync project warnings are invalid.');
    }
    final List<String> warnings = <String>[
      for (final Object? warning in rawWarnings)
        if (warning is String && warning.length <= 512) warning,
    ];
    if (warnings.length != rawWarnings.length) {
      throw const FormatException('Sync project warnings are invalid.');
    }
    if (!_isSorted(warnings)) {
      throw const FormatException('Sync project warnings must be sorted.');
    }
    _validateSyncRasterBudget(menus, decodedImages);
    if (_projectRevision(raw) != baseRevision) {
      throw const FormatException(
        'Sync project revision does not match its content.',
      );
    }
    final EditorSyncProject project = EditorSyncProject(
      kind: kind as String,
      subjectId: subjectId,
      baseRevision: baseRevision,
      menus: List<EditorSyncMenu>.unmodifiable(menus),
      board: board == null ? null : Map<String, dynamic>.unmodifiable(board),
      images: List<EditorSyncImage>.unmodifiable(images),
      constraints: constraints,
      warnings: List<String>.unmodifiable(warnings),
    );
    if (utf8.encode(jsonEncode(project.toJson())).length >
        huiEditorSyncMaxProjectBytes) {
      throw const FormatException('HoloUI sync project is too large.');
    }
    return project;
  }
}

void _validateSyncRasterBudget(
  Iterable<EditorSyncMenu> menus,
  Map<String, StoredImageData> images,
) {
  final _EditorSyncRasterBudget budget = _EditorSyncRasterBudget(images);
  for (final EditorSyncMenu menu in menus) {
    budget.visit(jsonDecode(menu.json));
  }
}

final class _EditorSyncRasterBudget {
  _EditorSyncRasterBudget(this.images);

  final Map<String, StoredImageData> images;
  int renderPixels = 0;
  int renderRows = 0;

  void visit(Object? value) {
    if (value is List) {
      for (final Object? child in value) {
        visit(child);
      }
      return;
    }
    if (value is! Map) return;
    if (value['type'] == 'textImage') {
      _add(value['path']);
    } else if (value['type'] == 'animatedTextImage') {
      final Object? source = value['source'];
      if (source is List) {
        for (final Object? frame in source) {
          _add(frame);
        }
      } else {
        _add(source);
      }
    }
    for (final Object? child in value.values) {
      visit(child);
    }
  }

  void _add(Object? rawPath) {
    if (rawPath is! String) {
      throw const FormatException('HoloUI sync image reference is invalid.');
    }
    final StoredImageData? image = images[rawPath];
    if (image == null) {
      throw FormatException('HoloUI sync image reference is missing: $rawPath');
    }
    renderPixels += image.width * image.height;
    renderRows += image.height;
    if (renderPixels > huiEditorSyncMaxRenderPixels ||
        renderRows > huiEditorSyncMaxRenderRows) {
      throw const FormatException(
        'HoloUI sync menus exceed the raster render budget.',
      );
    }
  }
}

final class EditorSyncSession {
  const EditorSyncSession({
    required this.sessionId,
    required this.baseRevision,
    required this.expiresAt,
    required this.project,
    required this.status,
    this.message,
    this.serverRevision,
  });

  final String sessionId;
  final String baseRevision;
  final DateTime expiresAt;
  final EditorSyncProject project;
  final EditorSyncStatus status;
  final String? message;
  final String? serverRevision;
}

final class EditorSyncBinding {
  const EditorSyncBinding({
    required this.sessionId,
    required this.editorToken,
    required this.relayEndpoint,
    required this.kind,
    required this.subjectId,
    required this.baseRevision,
    required this.menuDocumentIds,
    required this.imagePaths,
    required this.constraints,
    required this.warnings,
    this.boardDocumentId,
    this.pendingContentRevision,
  });

  final String sessionId;
  final String editorToken;
  final Uri relayEndpoint;
  final String kind;
  final String subjectId;
  final String baseRevision;
  final Map<String, String> menuDocumentIds;
  final List<String> imagePaths;
  final EditorSyncConstraints constraints;
  final List<String> warnings;
  final String? boardDocumentId;
  final String? pendingContentRevision;

  EditorSyncBinding copyWith({
    String? baseRevision,
    String? pendingContentRevision,
    bool clearPendingContentRevision = false,
  }) => EditorSyncBinding(
    sessionId: sessionId,
    editorToken: editorToken,
    relayEndpoint: relayEndpoint,
    kind: kind,
    subjectId: subjectId,
    baseRevision: baseRevision ?? this.baseRevision,
    menuDocumentIds: menuDocumentIds,
    imagePaths: imagePaths,
    constraints: constraints,
    warnings: warnings,
    boardDocumentId: boardDocumentId,
    pendingContentRevision: clearPendingContentRevision
        ? null
        : pendingContentRevision ?? this.pendingContentRevision,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': 1,
    'sessionId': sessionId,
    'editorToken': editorToken,
    'relayEndpoint': relayEndpoint.toString(),
    'kind': kind,
    'subjectId': subjectId,
    'baseRevision': baseRevision,
    'menuDocumentIds': menuDocumentIds,
    'imagePaths': imagePaths,
    'constraints': constraints.toJson(),
    'warnings': warnings,
    'boardDocumentId': boardDocumentId,
    'pendingContentRevision': pendingContentRevision,
  };

  static EditorSyncBinding? decode(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['version'] != 1) return null;
      final Object? sessionId = decoded['sessionId'];
      final Object? editorToken = decoded['editorToken'];
      final Uri? relay = _parseRelay(decoded['relayEndpoint']);
      final Object? kind = decoded['kind'];
      final Object? subjectId = decoded['subjectId'];
      final Object? baseRevision = decoded['baseRevision'];
      final Object? rawMap = decoded['menuDocumentIds'];
      final Object? rawPaths = decoded['imagePaths'];
      final Object? boardDocumentId = decoded['boardDocumentId'];
      final Object? rawWarnings = decoded['warnings'];
      final Object? pendingContentRevision = decoded['pendingContentRevision'];
      final EditorSyncConstraints constraints = EditorSyncConstraints.decode(
        decoded['constraints'],
      );
      if (sessionId is! String ||
          !_capabilityPattern.hasMatch(sessionId) ||
          editorToken is! String ||
          !_capabilityPattern.hasMatch(editorToken) ||
          relay == null ||
          (kind != 'menu' && kind != 'board') ||
          subjectId is! String ||
          baseRevision is! String ||
          !_revisionPattern.hasMatch(baseRevision) ||
          rawMap is! Map ||
          rawPaths is! List ||
          rawWarnings is! List ||
          (pendingContentRevision != null &&
              (pendingContentRevision is! String ||
                  !_revisionPattern.hasMatch(pendingContentRevision))) ||
          (boardDocumentId != null && boardDocumentId is! String)) {
        return null;
      }
      if (constraints.subjectId != subjectId ||
          (kind == 'board' && constraints.newMenuPrefix == null) ||
          (kind == 'menu' && constraints.newMenuPrefix != null)) {
        return null;
      }
      final Map<String, String> menuDocumentIds = <String, String>{};
      rawMap.forEach((Object? key, Object? value) {
        if (key is String && value is String) menuDocumentIds[key] = value;
      });
      final List<String> imagePaths = <String>[
        for (final Object? path in rawPaths)
          if (path is String) path,
      ];
      final List<String> warnings = <String>[
        for (final Object? warning in rawWarnings)
          if (warning is String) warning,
      ];
      if (warnings.length != rawWarnings.length) return null;
      return EditorSyncBinding(
        sessionId: sessionId,
        editorToken: editorToken,
        relayEndpoint: relay,
        kind: kind as String,
        subjectId: subjectId,
        baseRevision: baseRevision,
        menuDocumentIds: Map<String, String>.unmodifiable(menuDocumentIds),
        imagePaths: List<String>.unmodifiable(imagePaths),
        constraints: constraints,
        warnings: List<String>.unmodifiable(warnings),
        boardDocumentId: boardDocumentId as String?,
        pendingContentRevision: pendingContentRevision as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

final class EditorSyncClient {
  EditorSyncClient({
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 12),
    this.maximumResponseBytes = huiEditorSyncMaxResponseBytes,
  }) : _client = client ?? http.Client() {
    if (requestTimeout <= Duration.zero ||
        maximumResponseBytes <= 0 ||
        maximumResponseBytes > huiEditorSyncMaxResponseBytes) {
      throw ArgumentError('Invalid editor sync client limits.');
    }
  }

  final http.Client _client;
  final Duration requestTimeout;
  final int maximumResponseBytes;

  Future<EditorSyncSession> fetch(
    EditorSyncBinding binding, {
    bool initialSnapshot = false,
  }) async {
    final http.Request request = http.Request('GET', _sessionUri(binding));
    request.headers.addAll(_headers(binding.editorToken));
    final _EditorSyncHttpResponse response = await _request(request);
    if (response.statusCode == 410) {
      final String code = _errorCode(response.bodyBytes);
      throw EditorSyncGone(code == 'session_revoked');
    }
    if (response.statusCode != 200) {
      throw EditorSyncFailure('Relay returned HTTP ${response.statusCode}.');
    }
    return _decodeSession(
      response.bodyBytes,
      binding,
      initialSnapshot: initialSnapshot,
    );
  }

  Future<void> publish(
    EditorSyncBinding binding,
    EditorSyncProject project,
  ) async {
    final Uint8List body = Uint8List.fromList(
      utf8.encode(
        jsonEncode(<String, dynamic>{
          'protocol': huiEditorSyncProtocol,
          'baseRevision': binding.baseRevision,
          'snapshot': project.toJson(),
        }),
      ),
    );
    if (body.length > huiEditorSyncMaxRequestBytes) {
      throw const EditorSyncFailure('The project is too large to publish.');
    }
    final http.Request request = http.Request(
      'PUT',
      _sessionUri(
        binding,
      ).replace(path: '${_sessionUri(binding).path}/publication'),
    );
    request.headers.addAll(<String, String>{
      ..._headers(binding.editorToken),
      'content-type': 'application/json',
    });
    request.bodyBytes = body;
    final _EditorSyncHttpResponse response = await _request(request);
    if (response.statusCode == 410) {
      throw EditorSyncGone(_errorCode(response.bodyBytes) == 'session_revoked');
    }
    if (response.statusCode == 409) {
      throw EditorSyncConflict(_errorMessage(response.bodyBytes));
    }
    if (response.statusCode != 202) {
      throw EditorSyncFailure('Relay returned HTTP ${response.statusCode}.');
    }
    _decodeAcceptedPublication(response.bodyBytes);
  }

  void close() => _client.close();

  Future<_EditorSyncHttpResponse> _request(http.BaseRequest request) async {
    try {
      final http.StreamedResponse response = await _client
          .send(request)
          .timeout(requestTimeout);
      final String contentType = response.headers['content-type'] ?? '';
      if (response.statusCode != 204 &&
          !contentType.toLowerCase().startsWith('application/json')) {
        throw const EditorSyncFailure(
          'The relay response is not application/json.',
        );
      }
      final BytesBuilder bytes = BytesBuilder(copy: false);
      int length = 0;
      final StreamIterator<List<int>> iterator = StreamIterator<List<int>>(
        response.stream,
      );
      final Stopwatch elapsed = Stopwatch()..start();
      try {
        while (true) {
          final Duration remaining = requestTimeout - elapsed.elapsed;
          if (remaining <= Duration.zero ||
              !await iterator.moveNext().timeout(remaining)) {
            if (remaining <= Duration.zero) throw TimeoutException('relay');
            break;
          }
          final List<int> chunk = iterator.current;
          length += chunk.length;
          if (length > maximumResponseBytes) {
            throw const EditorSyncFailure('The relay response is too large.');
          }
          bytes.add(chunk);
        }
      } finally {
        await iterator.cancel();
      }
      return _EditorSyncHttpResponse(
        statusCode: response.statusCode,
        bodyBytes: bytes.takeBytes(),
      );
    } on EditorSyncFailure {
      rethrow;
    } on TimeoutException {
      throw const EditorSyncFailure('The relay timed out.');
    } catch (_) {
      throw const EditorSyncFailure('The relay could not be reached.');
    }
  }
}

void _decodeAcceptedPublication(Uint8List bytes) {
  final Object? raw;
  try {
    raw = jsonDecode(utf8.decode(bytes, allowMalformed: false));
  } catch (_) {
    throw const EditorSyncFailure('The relay publish response is malformed.');
  }
  if (raw is! Map ||
      raw['protocol'] != huiEditorSyncProtocol ||
      !_hasExactKeys(raw, const <String>{'protocol', 'publication'})) {
    throw const EditorSyncFailure('The relay publish response is malformed.');
  }
  final Object? publication = raw['publication'];
  if (publication is! Map ||
      !_hasExactKeys(publication, const <String>{
        'revision',
        'state',
        'publishedAt',
      }) ||
      publication['revision'] is! int ||
      (publication['revision']! as int) < 1 ||
      (publication['revision']! as int) > huiEditorSyncMaxSafeInteger ||
      publication['state'] != 'pending' ||
      publication['publishedAt'] is! String ||
      DateTime.tryParse(publication['publishedAt']! as String) == null) {
    throw const EditorSyncFailure('The relay publish response is malformed.');
  }
}

final class _EditorSyncHttpResponse {
  const _EditorSyncHttpResponse({
    required this.statusCode,
    required this.bodyBytes,
  });

  final int statusCode;
  final Uint8List bodyBytes;
}

final class EditorSyncFailure implements Exception {
  const EditorSyncFailure(this.message);
  final String message;
}

final class EditorSyncConflict extends EditorSyncFailure {
  const EditorSyncConflict(super.message);
}

final class EditorSyncGone extends EditorSyncFailure {
  const EditorSyncGone(this.revoked)
    : super(revoked ? 'This sync was revoked.' : 'This sync expired.');
  final bool revoked;
}

EditorSyncBinding? loadEditorSyncBinding(String workspaceId) {
  final String? raw = readEditorSyncBinding(workspaceId);
  return raw == null ? null : EditorSyncBinding.decode(raw);
}

bool persistEditorSyncBinding(
  String workspaceId,
  EditorSyncBinding binding, {
  EditorSyncBindingWriter writer = writeEditorSyncBinding,
  void Function(EditorSyncBinding binding)? onFailure,
}) {
  final bool persisted = writer(workspaceId, jsonEncode(binding.toJson()));
  if (!persisted) onFailure?.call(binding);
  return persisted;
}

void clearEditorSyncBinding(String workspaceId) =>
    removeEditorSyncBinding(workspaceId);

String editorSyncProjectRevision(Map<String, dynamic> project) =>
    _projectRevision(project);

String editorSyncCanonicalProjectContent(Map<String, dynamic> project) =>
    _canonicalProjectContent(project);

String? editorSyncBoardDefinitionProblem(
  Map<String, dynamic> board,
  Iterable<String> menuIds,
) {
  try {
    _validateBoardDefinition(board, menuIds.toSet());
    return null;
  } on FormatException catch (error) {
    return error.message.toString();
  }
}

EditorSyncAppliedDecision decideEditorSyncAppliedReconciliation({
  required EditorSyncBinding binding,
  required EditorSyncProject localProject,
}) =>
    binding.pendingContentRevision != null &&
        localProject.baseRevision == binding.pendingContentRevision
    ? EditorSyncAppliedDecision.reconcile
    : EditorSyncAppliedDecision.preserveLocalConflict;

Future<EditorSyncAppliedResolution> resolveEditorSyncApplied({
  required EditorSyncBinding binding,
  required EditorSyncProject serverProject,
  required Workspace workspace,
  required ImageLibrary images,
}) async {
  final EditorSyncProject localProject = collectEditorSyncProject(
    binding: binding,
    workspace: workspace,
    images: images,
  );
  final EditorSyncAppliedDecision decision =
      decideEditorSyncAppliedReconciliation(
        binding: binding,
        localProject: localProject,
      );
  if (decision == EditorSyncAppliedDecision.preserveLocalConflict) {
    return EditorSyncAppliedResolution(decision: decision, binding: binding);
  }
  return EditorSyncAppliedResolution(
    decision: decision,
    binding: await refreshEditorSyncProject(
      binding: binding,
      project: serverProject,
      workspace: workspace,
      images: images,
    ),
  );
}

EditorSyncBinding reconcileEditorSyncTerminalStatus(
  EditorSyncBinding binding,
  EditorSyncStatus status,
) => status == EditorSyncStatus.rejected
    ? binding.copyWith(clearPendingContentRevision: true)
    : binding;

bool canPublishEditorSyncStatus(EditorSyncStatus status) => switch (status) {
  EditorSyncStatus.connected ||
  EditorSyncStatus.applied ||
  EditorSyncStatus.rejected => true,
  _ => false,
};

Future<EditorSyncBinding> importEditorSyncProject({
  required EditorSyncBinding capability,
  required EditorSyncProject project,
  required Workspace workspace,
  required ImageLibrary images,
  bool replaceExisting = false,
}) async {
  if (!workspace.canWrite) {
    throw const EditorSyncFailure('The local workspace is not writable.');
  }
  final Map<String, List<WorkspaceDoc>> matches =
      <String, List<WorkspaceDoc>>{};
  final List<WorkspaceDoc> boardMatches = <WorkspaceDoc>[];
  final List<StoredImage> stagedImages = _storedImages(project.images);
  for (final WorkspaceDoc doc in workspace.docs) {
    if (doc.kind != WorkspaceDocKind.menu || doc.runtimeId == null) continue;
    matches.putIfAbsent(doc.runtimeId!, () => <WorkspaceDoc>[]).add(doc);
  }
  if (project.kind == 'board') {
    for (final WorkspaceDoc doc in workspace.docs) {
      if (doc.kind != WorkspaceDocKind.board) continue;
      if (decodeWorkspaceBoard(doc.json).data.runtimeBoardId ==
          project.subjectId) {
        boardMatches.add(doc);
      }
    }
    if (boardMatches.length > 1 ||
        (boardMatches.isNotEmpty && !replaceExisting)) {
      throw EditorSyncConflict(
        'The local workspace already contains world board ${project.subjectId}. Confirm replacement first.',
      );
    }
  }
  for (final EditorSyncMenu menu in project.menus) {
    final List<WorkspaceDoc> existing = matches[menu.id] ?? <WorkspaceDoc>[];
    if (existing.length > 1 || (existing.isNotEmpty && !replaceExisting)) {
      throw EditorSyncConflict(
        'The local workspace already contains ${menu.id}. Confirm replacement first.',
      );
    }
  }
  for (final StoredImage incoming in stagedImages) {
    final StoredImage? current = images.byPath(incoming.path);
    if (current != null &&
        current.dataUri != incoming.dataUri &&
        !replaceExisting) {
      throw EditorSyncConflict(
        'The local image ${incoming.path} differs. Confirm replacement first.',
      );
    }
  }

  final String workspaceRollback = workspace.createRollbackSnapshot();
  try {
    final String folderId;
    if (boardMatches.isNotEmpty) {
      folderId = boardMatches.single.folderId;
    } else if (project.kind == 'board') {
      folderId = workspace.createFolder(title: project.subjectId).id;
    } else {
      folderId = workspace.unfiledFolderId;
    }
    final Map<String, String> menuDocumentIds = <String, String>{};
    for (final EditorSyncMenu menu in project.menus) {
      final List<WorkspaceDoc> existing = matches[menu.id] ?? <WorkspaceDoc>[];
      if (existing.isNotEmpty) {
        final WorkspaceDoc doc = existing.single;
        final String targetFolderId = project.kind == 'menu'
            ? doc.folderId
            : folderId;
        final String targetTitle = project.kind == 'menu'
            ? doc.title
            : menu.id.split('/').last;
        if (!workspace.replaceDocument(
          id: doc.id,
          title: targetTitle,
          runtimeId: menu.id,
          json: menu.json,
          kind: WorkspaceDocKind.menu,
          folderId: targetFolderId,
        )) {
          throw EditorSyncFailure(
            'The synced menu ${menu.id} could not be stored locally.',
          );
        }
        menuDocumentIds[menu.id] = doc.id;
      } else {
        final WorkspaceDoc doc = workspace.create(
          title: menu.id.split('/').last,
          runtimeId: menu.id,
          json: menu.json,
          kind: WorkspaceDocKind.menu,
          folderId: folderId,
        );
        menuDocumentIds[menu.id] = doc.id;
      }
    }
    String? boardDocumentId;
    if (project.kind == 'board') {
      final WorkspaceDoc? existingBoard = boardMatches.firstOrNull;
      final WorkspaceBoardData current = existingBoard == null
          ? const WorkspaceBoardData()
          : decodeWorkspaceBoard(existingBoard.json).data;
      final WorkspaceBoardData board = current.copyWith(
        scopeFolderId: folderId,
        runtimeBoardId: project.subjectId,
        runtimeBoard: project.board,
        syncMenuIds: project.menus
            .map((EditorSyncMenu menu) => menu.id)
            .toList(growable: false),
        syncImagePaths: project.images
            .map((EditorSyncImage image) => image.path)
            .toList(growable: false),
      );
      if (existingBoard == null) {
        final WorkspaceDoc doc = workspace.create(
          title: project.subjectId,
          runtimeId: null,
          json: encodeWorkspaceBoard(board),
          kind: WorkspaceDocKind.board,
          folderId: folderId,
        );
        boardDocumentId = doc.id;
      } else {
        if (!workspace.replaceDocument(
          id: existingBoard.id,
          title: existingBoard.title,
          json: encodeWorkspaceBoard(board),
          kind: WorkspaceDocKind.board,
          folderId: folderId,
        )) {
          throw const EditorSyncFailure(
            'The synced world board could not be stored locally.',
          );
        }
        boardDocumentId = existingBoard.id;
      }
    }
    if (menuDocumentIds.isEmpty) {
      throw const EditorSyncFailure(
        'The synced project contained no documents.',
      );
    }
    if (!workspace.save()) {
      throw const EditorSyncFailure(
        'The synced workspace could not be stored locally.',
      );
    }
    await workspace.writesSettled;
    if (workspace.hasUnsavedChanges) {
      throw EditorSyncFailure(
        workspace.lastError ??
            'The synced workspace could not be stored locally.',
      );
    }
    if (!images.upsertAll(stagedImages)) {
      throw EditorSyncFailure(
        images.lastError ?? 'The synced images could not be stored locally.',
      );
    }
    return EditorSyncBinding(
      sessionId: capability.sessionId,
      editorToken: capability.editorToken,
      relayEndpoint: capability.relayEndpoint,
      kind: project.kind,
      subjectId: project.subjectId,
      baseRevision: project.baseRevision,
      menuDocumentIds: Map<String, String>.unmodifiable(menuDocumentIds),
      imagePaths: List<String>.unmodifiable(
        project.images.map((EditorSyncImage image) => image.path),
      ),
      constraints: project.constraints,
      warnings: project.warnings,
      boardDocumentId: boardDocumentId,
      pendingContentRevision: null,
    );
  } catch (error) {
    await _restoreWorkspaceAfterSyncFailure(workspace, workspaceRollback);
    if (error is EditorSyncFailure) rethrow;
    throw const EditorSyncFailure(
      'The synced project could not be stored locally.',
    );
  }
}

Future<EditorSyncBinding> refreshEditorSyncProject({
  required EditorSyncBinding binding,
  required EditorSyncProject project,
  required Workspace workspace,
  required ImageLibrary images,
}) async {
  if (project.kind != binding.kind || project.subjectId != binding.subjectId) {
    throw const EditorSyncConflict(
      'The refreshed server scope changed identity.',
    );
  }
  if (_canonicalJson(project.constraints.toJson()) !=
      _canonicalJson(binding.constraints.toJson())) {
    throw const EditorSyncConflict(
      'The refreshed server scope changed constraints.',
    );
  }
  final Set<String> refreshedMenuIds = project.menus
      .map((EditorSyncMenu menu) => menu.id)
      .toSet();
  final Set<String> refreshedImagePaths = project.images
      .map((EditorSyncImage image) => image.path)
      .toSet();
  if (!refreshedMenuIds.containsAll(binding.menuDocumentIds.keys) ||
      !refreshedImagePaths.containsAll(binding.imagePaths)) {
    throw const EditorSyncConflict(
      'The refreshed server scope removed bound resources.',
    );
  }
  final List<StoredImage> stored = _storedImages(project.images);
  final String workspaceRollback = workspace.createRollbackSnapshot();
  try {
    final Map<String, String> nextIds = <String, String>{};
    for (final EditorSyncMenu menu in project.menus) {
      final String? documentId = binding.menuDocumentIds[menu.id];
      final WorkspaceDoc? doc = workspace.byId(documentId);
      if (doc == null) {
        if (binding.kind != 'board' || binding.boardDocumentId == null) {
          throw EditorSyncConflict(
            'The bound menu ${menu.id} is missing locally.',
          );
        }
        final WorkspaceDoc? boardDoc = workspace.byId(binding.boardDocumentId);
        final String? folderId = boardDoc == null
            ? null
            : decodeWorkspaceBoard(boardDoc.json).data.scopeFolderId;
        if (folderId == null) {
          throw const EditorSyncConflict('The bound board folder is missing.');
        }
        final WorkspaceDoc created = workspace.create(
          title: menu.id.split('/').last,
          runtimeId: menu.id,
          json: menu.json,
          kind: WorkspaceDocKind.menu,
          folderId: folderId,
        );
        nextIds[menu.id] = created.id;
        continue;
      }
      if (!workspace.replaceDocument(
        id: doc.id,
        title: menu.id.split('/').last,
        runtimeId: menu.id,
        json: menu.json,
        kind: WorkspaceDocKind.menu,
        folderId: doc.folderId,
      )) {
        throw EditorSyncFailure(
          'The bound menu ${menu.id} could not be refreshed.',
        );
      }
      nextIds[menu.id] = doc.id;
    }
    final String? boardDocumentId = binding.boardDocumentId;
    if (binding.kind == 'board') {
      final WorkspaceDoc? boardDoc = workspace.byId(boardDocumentId);
      if (boardDoc == null) {
        throw const EditorSyncConflict(
          'The bound world board is missing locally.',
        );
      }
      final WorkspaceBoardData current = decodeWorkspaceBoard(
        boardDoc.json,
      ).data;
      final WorkspaceBoardData refreshed = current.copyWith(
        runtimeBoardId: project.subjectId,
        runtimeBoard: project.board,
        syncMenuIds: project.menus
            .map((EditorSyncMenu menu) => menu.id)
            .toList(growable: false),
        syncImagePaths: project.images
            .map((EditorSyncImage image) => image.path)
            .toList(growable: false),
      );
      if (!workspace.replaceDocument(
        id: boardDoc.id,
        title: boardDoc.title,
        json: encodeWorkspaceBoard(refreshed),
        kind: WorkspaceDocKind.board,
        folderId: boardDoc.folderId,
      )) {
        throw const EditorSyncFailure(
          'The world board could not be refreshed.',
        );
      }
    }
    if (!workspace.save()) {
      throw const EditorSyncFailure(
        'The refreshed workspace could not be stored locally.',
      );
    }
    await workspace.writesSettled;
    if (workspace.hasUnsavedChanges) {
      throw EditorSyncFailure(
        workspace.lastError ??
            'The refreshed workspace could not be stored locally.',
      );
    }
    if (!images.upsertAll(stored)) {
      throw EditorSyncFailure(
        images.lastError ?? 'The refreshed images could not be stored locally.',
      );
    }
    return EditorSyncBinding(
      sessionId: binding.sessionId,
      editorToken: binding.editorToken,
      relayEndpoint: binding.relayEndpoint,
      kind: binding.kind,
      subjectId: binding.subjectId,
      baseRevision: project.baseRevision,
      menuDocumentIds: Map<String, String>.unmodifiable(nextIds),
      imagePaths: List<String>.unmodifiable(
        project.images.map((EditorSyncImage image) => image.path),
      ),
      constraints: binding.constraints,
      warnings: project.warnings,
      boardDocumentId: boardDocumentId,
      pendingContentRevision: null,
    );
  } catch (error) {
    await _restoreWorkspaceAfterSyncFailure(workspace, workspaceRollback);
    if (error is EditorSyncFailure) rethrow;
    throw const EditorSyncFailure(
      'The refreshed project could not be stored locally.',
    );
  }
}

Future<void> _restoreWorkspaceAfterSyncFailure(
  Workspace workspace,
  String rollbackSnapshot,
) async {
  try {
    final bool restored = await workspace.restoreRollbackSnapshot(
      rollbackSnapshot,
    );
    if (!restored) {
      throw const EditorSyncFailure(
        'The local sync transaction could not be rolled back. Reload the '
        'workspace before continuing.',
      );
    }
  } catch (_) {
    throw const EditorSyncFailure(
      'The local sync transaction could not be rolled back. Reload the '
      'workspace before continuing.',
    );
  }
}

List<StoredImage> _storedImages(List<EditorSyncImage> images) => <StoredImage>[
  for (final EditorSyncImage image in images)
    StoredImage(
      path: image.path,
      dataUri: image.data,
      width: decodeSupportedImageData(image.data)!.width,
      height: decodeSupportedImageData(image.data)!.height,
    ),
];

EditorSyncProject collectEditorSyncProject({
  required EditorSyncBinding binding,
  required Workspace workspace,
  required ImageLibrary images,
}) {
  final Map<String, WorkspaceDoc> scopedMenus = <String, WorkspaceDoc>{};
  for (final MapEntry<String, String> entry
      in binding.menuDocumentIds.entries) {
    final WorkspaceDoc? doc = workspace.byId(entry.value);
    if (doc == null ||
        doc.kind != WorkspaceDocKind.menu ||
        doc.runtimeId != entry.key) {
      throw EditorSyncFailure(
        'The bound menu ${entry.key} is missing or renamed.',
      );
    }
    scopedMenus[entry.key] = doc;
  }
  Map<String, dynamic>? board;
  if (binding.kind == 'board') {
    final WorkspaceDoc? doc = workspace.byId(binding.boardDocumentId);
    if (doc == null || doc.kind != WorkspaceDocKind.board) {
      throw const EditorSyncFailure('The bound world board is missing.');
    }
    final WorkspaceBoardDecodeResult decoded = decodeWorkspaceBoard(doc.json);
    if (decoded.data.runtimeBoardId != binding.subjectId ||
        decoded.data.runtimeBoard == null) {
      throw const EditorSyncFailure('The bound world board scope has changed.');
    }
    board = decoded.data.runtimeBoard;
    final String? folderId = decoded.data.scopeFolderId;
    if (folderId == null) {
      throw const EditorSyncFailure('The bound world board folder is missing.');
    }
    _addReachableBoardMenus(
      binding: binding,
      workspace: workspace,
      folderId: folderId,
      board: board!,
      scopedMenus: scopedMenus,
    );
  }
  final List<EditorSyncMenu> menus = <EditorSyncMenu>[];
  for (final MapEntry<String, WorkspaceDoc> entry in scopedMenus.entries) {
    final HuiMenu menu;
    try {
      menu = decodeHuiMenu(entry.value.json);
    } catch (_) {
      throw EditorSyncFailure('The bound menu ${entry.key} is invalid JSON.');
    }
    final List<HuiIssue> issues = validateHuiMenu(
      menu,
      knownImagePaths: images.paths,
    );
    if (issues.any((HuiIssue issue) => issue.severity == HuiSeverity.error)) {
      throw EditorSyncFailure(
        'The bound menu ${entry.key} has validation errors.',
      );
    }
    menus.add(EditorSyncMenu(id: entry.key, json: entry.value.json));
  }
  menus.sort((EditorSyncMenu a, EditorSyncMenu b) => a.id.compareTo(b.id));
  if (binding.kind != 'board' &&
      (menus.length != 1 || menus.first.id != binding.subjectId)) {
    throw const EditorSyncFailure('The bound menu scope has changed.');
  }
  final Set<String> referencedImagePaths = <String>{};
  for (final EditorSyncMenu menu in menus) {
    _collectImagePaths(jsonDecode(menu.json), referencedImagePaths);
  }
  referencedImagePaths.addAll(binding.imagePaths);
  final List<EditorSyncImage> projectImages = <EditorSyncImage>[];
  final String? imagePrefix = binding.constraints.newImagePrefix;
  final List<String> orderedImagePaths = referencedImagePaths.toList()..sort();
  for (final String path in orderedImagePaths) {
    if (!binding.constraints.imagePaths.contains(path) &&
        (imagePrefix == null || !path.startsWith(imagePrefix))) {
      throw EditorSyncFailure(
        'Image $path is outside the allowed server scope.',
      );
    }
    final StoredImage? image = images.byPath(path);
    if (image == null || !isValidStoredImageData(image)) {
      throw EditorSyncFailure('The bound image $path is missing or invalid.');
    }
    projectImages.add(EditorSyncImage(path: path, data: image.dataUri));
  }
  final EditorSyncProject provisional = EditorSyncProject(
    kind: binding.kind,
    subjectId: binding.subjectId,
    baseRevision: 'sha256:${List<String>.filled(64, '0').join()}',
    menus: List<EditorSyncMenu>.unmodifiable(menus),
    board: board,
    images: List<EditorSyncImage>.unmodifiable(projectImages),
    constraints: binding.constraints,
    warnings: binding.warnings,
  );
  final EditorSyncProject collected = EditorSyncProject(
    kind: provisional.kind,
    subjectId: provisional.subjectId,
    baseRevision: _projectRevision(provisional.toJson()),
    menus: provisional.menus,
    board: provisional.board,
    images: provisional.images,
    constraints: provisional.constraints,
    warnings: provisional.warnings,
  );
  return EditorSyncProject.decode(collected.toJson());
}

void _addReachableBoardMenus({
  required EditorSyncBinding binding,
  required Workspace workspace,
  required String folderId,
  required Map<String, dynamic> board,
  required Map<String, WorkspaceDoc> scopedMenus,
}) {
  final Set<String> folderIds = <String>{folderId};
  bool addedFolder = true;
  while (addedFolder) {
    addedFolder = false;
    for (final WorkspaceFolder folder in workspace.folders) {
      if (folder.parentId != null &&
          folderIds.contains(folder.parentId) &&
          folderIds.add(folder.id)) {
        addedFolder = true;
      }
    }
  }
  final Map<String, List<WorkspaceDoc>> candidates =
      <String, List<WorkspaceDoc>>{};
  for (final WorkspaceDoc doc in workspace.docs) {
    final String? id = doc.runtimeId;
    if (doc.kind != WorkspaceDocKind.menu ||
        id == null ||
        !folderIds.contains(doc.folderId)) {
      continue;
    }
    candidates.putIfAbsent(id, () => <WorkspaceDoc>[]).add(doc);
  }

  final String rootMenuId = board['rootMenuId']! as String;
  final List<String> pending = <String>[rootMenuId];
  final Set<String> visited = <String>{};
  int cursor = 0;
  while (cursor < pending.length) {
    final String id = pending[cursor++];
    if (!visited.add(id)) continue;
    if (visited.length > huiEditorSyncMaxMenus) {
      throw const EditorSyncFailure(
        'The world board navigation graph exceeds 256 menus.',
      );
    }
    final WorkspaceDoc? bound = scopedMenus[id];
    final List<WorkspaceDoc> matches = candidates[id] ?? <WorkspaceDoc>[];
    final List<WorkspaceDoc> distinct = <WorkspaceDoc>[
      for (final WorkspaceDoc match in matches)
        if (bound == null || match.id != bound.id) match,
    ];
    if (bound != null) distinct.insert(0, bound);
    if (distinct.length > 1) {
      throw EditorSyncFailure('The board menu id $id is duplicated.');
    }
    if (distinct.isEmpty) continue;
    final WorkspaceDoc document = distinct.single;
    if (!binding.constraints.menuIds.contains(id) &&
        (binding.constraints.newMenuPrefix == null ||
            !id.startsWith(binding.constraints.newMenuPrefix!))) {
      throw EditorSyncFailure(
        'Menu $id is outside ${binding.constraints.newMenuPrefix ?? 'the allowed server scope'}.',
      );
    }
    scopedMenus[id] = document;
    final Object? source;
    try {
      source = jsonDecode(document.json);
    } catch (_) {
      throw EditorSyncFailure('The bound menu $id is invalid JSON.');
    }
    final Set<String> targets = <String>{};
    _collectMenuTargets(source, targets);
    final List<String> ordered = targets.toList()..sort();
    pending.addAll(ordered);
  }
  if (!scopedMenus.containsKey(rootMenuId)) {
    throw EditorSyncFailure(
      'The board root menu $rootMenuId is missing from its synced folder.',
    );
  }
}

void _collectMenuTargets(Object? value, Set<String> output) {
  if (value is List) {
    for (final Object? child in value) {
      _collectMenuTargets(child, output);
    }
    return;
  }
  if (value is! Map) return;
  final Object? type = value['type'];
  if (type == 'navigate') {
    final Object? mode = value['mode'];
    final Object? target = value['target'];
    if ((mode == null || mode == 'push' || mode == 'replace') &&
        target is String &&
        isCanonicalMenuId(target)) {
      output.add(target);
    }
  } else if (type == 'command') {
    final Object? source = value['source'];
    final Object? command = value['command'];
    if ((source == null || source == 'player') && command is String) {
      final RegExpMatch? match = _playerOpenCommandPattern.firstMatch(command);
      final String? target = match?.group(1);
      if (target != null && isCanonicalMenuId(target)) output.add(target);
    }
  }
  for (final Object? child in value.values) {
    _collectMenuTargets(child, output);
  }
}

void _collectImagePaths(Object? value, Set<String> output) {
  if (value is List) {
    for (final Object? child in value) {
      _collectImagePaths(child, output);
    }
    return;
  }
  if (value is! Map) return;
  if (value['type'] == 'textImage' && value['path'] is String) {
    output.add(value['path'] as String);
  } else if (value['type'] == 'animatedTextImage') {
    final Object? source = value['source'];
    if (source is String) output.add(source);
    if (source is List) {
      for (final Object? frame in source) {
        if (frame is String) output.add(frame);
      }
    }
  }
  for (final Object? child in value.values) {
    _collectImagePaths(child, output);
  }
}

EditorSyncSession _decodeSession(
  Uint8List bytes,
  EditorSyncBinding binding, {
  required bool initialSnapshot,
}) {
  final Object? raw;
  try {
    raw = jsonDecode(utf8.decode(bytes, allowMalformed: false));
  } catch (_) {
    throw const EditorSyncFailure('The relay returned malformed JSON.');
  }
  if (raw is! Map ||
      raw['protocol'] != huiEditorSyncProtocol ||
      raw['sessionId'] != binding.sessionId ||
      !_hasExactKeys(raw, const <String>{
        'protocol',
        'sessionId',
        'status',
        'expiresAt',
        'baseRevision',
        'snapshot',
        'publication',
      })) {
    throw const EditorSyncFailure('The relay returned the wrong session.');
  }
  final Object? baseRevision = raw['baseRevision'];
  final Object? expiresAt = raw['expiresAt'];
  final Object? rawStatus = raw['status'];
  if (baseRevision is! String ||
      !_revisionPattern.hasMatch(baseRevision) ||
      expiresAt is! String ||
      rawStatus is! String) {
    throw const EditorSyncFailure('The relay session is malformed.');
  }
  final DateTime? expiry = DateTime.tryParse(expiresAt)?.toUtc();
  if (expiry == null) {
    throw const EditorSyncFailure('The relay expiry is malformed.');
  }
  EditorSyncStatus status = switch (rawStatus) {
    'open' => EditorSyncStatus.connected,
    'pending' => EditorSyncStatus.pending,
    'applied' => EditorSyncStatus.applied,
    'conflict' => EditorSyncStatus.conflict,
    'rejected' => EditorSyncStatus.rejected,
    _ => throw const EditorSyncFailure('The relay status is unsupported.'),
  };
  final EditorSyncProject project;
  try {
    project = EditorSyncProject.decode(raw['snapshot']);
  } catch (_) {
    throw const EditorSyncFailure('The relay snapshot is malformed.');
  }
  if (project.baseRevision != baseRevision) {
    throw const EditorSyncFailure(
      'The relay session and snapshot revisions disagree.',
    );
  }
  if (!initialSnapshot &&
      (project.kind != binding.kind ||
          project.subjectId != binding.subjectId ||
          _canonicalJson(project.constraints.toJson()) !=
              _canonicalJson(binding.constraints.toJson()))) {
    throw const EditorSyncFailure(
      'The relay session scope changed unexpectedly.',
    );
  }
  String? message;
  String? serverRevision;
  final Object? publication = raw['publication'];
  if (publication == null) {
    if (status != EditorSyncStatus.connected) {
      throw const EditorSyncFailure(
        'The relay session is missing its publication.',
      );
    }
    if (!initialSnapshot &&
        (baseRevision != binding.baseRevision ||
            binding.pendingContentRevision != null)) {
      throw const EditorSyncFailure(
        'The relay session does not match this tab.',
      );
    }
  } else {
    final _DecodedPublication decoded = _decodePublication(publication);
    if (decoded.status != status) {
      throw const EditorSyncFailure(
        'The relay publication state is inconsistent.',
      );
    }
    message = decoded.message;
    serverRevision = decoded.serverRevision;
    if (decoded.project.kind != project.kind ||
        decoded.project.subjectId != project.subjectId ||
        _canonicalJson(decoded.project.constraints.toJson()) !=
            _canonicalJson(project.constraints.toJson())) {
      throw const EditorSyncFailure(
        'The relay publication scope is inconsistent.',
      );
    }
    if ((status == EditorSyncStatus.pending ||
            status == EditorSyncStatus.rejected) &&
        decoded.baseRevision != baseRevision) {
      throw const EditorSyncFailure(
        'The relay publication base is inconsistent.',
      );
    }
    if ((status == EditorSyncStatus.applied ||
            status == EditorSyncStatus.conflict) &&
        serverRevision != baseRevision) {
      throw const EditorSyncFailure(
        'The relay acknowledgement revision is inconsistent.',
      );
    }
    if (!initialSnapshot) {
      final String? pendingRevision = binding.pendingContentRevision;
      if (pendingRevision != null) {
        if (decoded.baseRevision != binding.baseRevision ||
            decoded.project.baseRevision != pendingRevision) {
          throw const EditorSyncFailure(
            'The relay publication does not match this tab.',
          );
        }
      } else if (status == EditorSyncStatus.pending ||
          baseRevision != binding.baseRevision) {
        throw const EditorSyncFailure(
          'The relay publication does not match this tab.',
        );
      }
    }
  }
  return EditorSyncSession(
    sessionId: binding.sessionId,
    baseRevision: baseRevision,
    expiresAt: expiry,
    project: project,
    status: status,
    message: message,
    serverRevision: serverRevision,
  );
}

final class _DecodedPublication {
  const _DecodedPublication({
    required this.status,
    required this.baseRevision,
    required this.project,
    this.message,
    this.serverRevision,
  });

  final EditorSyncStatus status;
  final String baseRevision;
  final EditorSyncProject project;
  final String? message;
  final String? serverRevision;
}

_DecodedPublication _decodePublication(Object? raw) {
  if (raw is! Map ||
      !_hasExactKeys(raw, const <String>{
        'revision',
        'baseRevision',
        'snapshot',
        'publishedAt',
        'state',
        'ack',
      }) ||
      raw['revision'] is! int ||
      (raw['revision']! as int) < 1 ||
      (raw['revision']! as int) > huiEditorSyncMaxSafeInteger ||
      raw['baseRevision'] is! String ||
      !_revisionPattern.hasMatch(raw['baseRevision']! as String) ||
      raw['publishedAt'] is! String ||
      DateTime.tryParse(raw['publishedAt']! as String) == null) {
    throw const EditorSyncFailure('The relay publication is malformed.');
  }
  final EditorSyncProject project;
  try {
    project = EditorSyncProject.decode(raw['snapshot']);
  } catch (_) {
    throw const EditorSyncFailure('The relay publication is malformed.');
  }
  final Object? state = raw['state'];
  final EditorSyncStatus status = switch (state) {
    'pending' => EditorSyncStatus.pending,
    'applied' => EditorSyncStatus.applied,
    'conflict' => EditorSyncStatus.conflict,
    'rejected' => EditorSyncStatus.rejected,
    _ => throw const EditorSyncFailure(
      'The relay publication state is unsupported.',
    ),
  };
  final Object? rawAck = raw['ack'];
  if (status == EditorSyncStatus.pending) {
    if (rawAck != null) {
      throw const EditorSyncFailure(
        'A pending relay publication cannot be acknowledged.',
      );
    }
    return _DecodedPublication(
      status: EditorSyncStatus.pending,
      baseRevision: raw['baseRevision']! as String,
      project: project,
    );
  }
  if (rawAck is! Map ||
      !_hasExactKeys(rawAck, const <String>{
        'status',
        'message',
        'serverRevision',
        'acknowledgedAt',
      }) ||
      rawAck['status'] != state ||
      rawAck['message'] is! String ||
      (rawAck['message']! as String).length > 2048 ||
      rawAck['acknowledgedAt'] is! String ||
      DateTime.tryParse(rawAck['acknowledgedAt']! as String) == null) {
    throw const EditorSyncFailure(
      'The relay publication acknowledgement is malformed.',
    );
  }
  final Object? rawServerRevision = rawAck['serverRevision'];
  final bool promotes =
      status == EditorSyncStatus.applied || status == EditorSyncStatus.conflict;
  if (promotes
      ? rawServerRevision is! String ||
            !_revisionPattern.hasMatch(rawServerRevision)
      : rawServerRevision != null) {
    throw const EditorSyncFailure(
      'The relay publication acknowledgement is malformed.',
    );
  }
  return _DecodedPublication(
    status: status,
    baseRevision: raw['baseRevision']! as String,
    project: project,
    message: rawAck['message']! as String,
    serverRevision: rawServerRevision as String?,
  );
}

bool _hasExactKeys(Map raw, Set<String> expected) =>
    raw.length == expected.length &&
    raw.keys.every((Object? key) => key is String && expected.contains(key));

Map<String, String> _headers(String token) => <String, String>{
  'accept': 'application/json',
  'authorization': 'Bearer $token',
};

Uri _sessionUri(EditorSyncBinding binding) => binding.relayEndpoint.replace(
  path: '${binding.relayEndpoint.path}/sessions/${binding.sessionId}',
);

Uri? _parseRelay(Object? raw) {
  if (raw is! String || raw.length > 1024) return null;
  final Uri relay;
  try {
    relay = Uri.parse(raw);
  } catch (_) {
    return null;
  }
  if (!relay.hasAuthority ||
      relay.userInfo.isNotEmpty ||
      relay.query.isNotEmpty ||
      relay.fragment.isNotEmpty ||
      !relay.path.endsWith('/v1')) {
    return null;
  }
  final bool local =
      relay.host == 'localhost' ||
      relay.host == '127.0.0.1' ||
      relay.host == '::1';
  return relay.scheme == 'https' || (relay.scheme == 'http' && local)
      ? relay
      : null;
}

String _errorCode(Uint8List bytes) {
  try {
    final Object? raw = jsonDecode(utf8.decode(bytes));
    if (raw is Map && raw['error'] is Map) {
      final Object? code = (raw['error']! as Map)['code'];
      if (code is String) return code;
    }
  } catch (_) {}
  return '';
}

String _errorMessage(Uint8List bytes) {
  try {
    final Object? raw = jsonDecode(utf8.decode(bytes));
    if (raw is Map && raw['error'] is Map) {
      final Object? message = (raw['error']! as Map)['message'];
      if (message is String && message.isNotEmpty) return message;
    }
  } catch (_) {}
  return 'The relay rejected the publication because the session changed.';
}

Map<String, dynamic> _copyStringMap(Map raw) => <String, dynamic>{
  for (final MapEntry<Object?, Object?> entry in raw.entries)
    if (entry.key is String) entry.key! as String: entry.value,
};

String _projectRevision(Map raw) =>
    'sha256:${crypto.sha256.convert(utf8.encode(_canonicalProjectContent(raw)))}';

String _canonicalProjectContent(Map raw) {
  final Map<String, dynamic> content = <String, dynamic>{
    for (final MapEntry<Object?, Object?> entry in raw.entries)
      if (entry.key is String && entry.key != 'baseRevision')
        entry.key! as String: entry.value,
  };
  return _canonicalJson(content);
}

String _canonicalJson(Object? value) {
  if (value is num) {
    return _canonicalNumber(value);
  }
  if (value == null || value is bool || value is String) {
    return jsonEncode(value);
  }
  if (value is List) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  if (value is Map) {
    final List<String> keys = <String>[
      for (final Object? key in value.keys)
        if (key is String) key,
    ]..sort();
    if (keys.length != value.length) {
      throw const FormatException(
        'Canonical JSON object keys must be strings.',
      );
    }
    return '{${keys.map((String key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  throw const FormatException('Canonical JSON contains an unsupported value.');
}

String _canonicalNumber(num value) {
  final double numeric = value.toDouble();
  if (!numeric.isFinite) {
    throw const FormatException('Canonical JSON numbers must be finite.');
  }
  if (numeric == 0) return '0';
  final String encoded = numeric.toString();
  if (encoded.endsWith('.0')) {
    return encoded.substring(0, encoded.length - 2);
  }
  return encoded.replaceFirstMapped(
    RegExp(r'e([+-]?)0+(\d+)'),
    (Match match) => 'e${match.group(1)}${match.group(2)}',
  );
}

void _validateBoardDefinition(Map<String, dynamic> board, Set<String> menuIds) {
  _requireExactKeys(board, const <String>{
    'schemaVersion',
    'id',
    'uuid',
    'revision',
    'rootMenuId',
    'transform',
    'follow',
    'visibility',
  });
  final Object? schemaVersion = board['schemaVersion'];
  final Object? id = board['id'];
  final Object? uuid = board['uuid'];
  final Object? revision = board['revision'];
  final Object? rootMenuId = board['rootMenuId'];
  if (schemaVersion != 1 ||
      id is! String ||
      !isCanonicalMenuId(id) ||
      id != id.toLowerCase() ||
      uuid is! String ||
      !_uuidPattern.hasMatch(uuid) ||
      revision is! num ||
      !revision.isFinite ||
      revision.toInt() != revision ||
      revision.toInt() < 1 ||
      revision.toInt() > huiEditorSyncMaxSafeInteger ||
      rootMenuId is! String ||
      !menuIds.contains(rootMenuId)) {
    throw const FormatException('The world board identity is invalid.');
  }
  _validateBoardTransform(board['transform']);
  _validateBoardFollow(board['follow']);
  _validateBoardVisibility(board['visibility']);
}

void _validateBoardTransform(Object? raw) {
  final Map<String, dynamic> transform = _strictStringMap(
    raw,
    'world board transform',
  );
  _requireExactKeys(transform, const <String>{
    'worldKey',
    'worldUuid',
    'x',
    'y',
    'z',
    'yaw',
    'pitch',
    'roll',
    'scale',
  });
  final Object? worldKey = transform['worldKey'];
  final Object? worldUuid = transform['worldUuid'];
  if (worldKey is! String ||
      worldKey.length > 255 ||
      !_worldKeyPattern.hasMatch(worldKey) ||
      worldUuid is! String ||
      !_uuidPattern.hasMatch(worldUuid)) {
    throw const FormatException('The world board transform is invalid.');
  }
  for (final String field in <String>[
    'x',
    'y',
    'z',
    'yaw',
    'pitch',
    'roll',
    'scale',
  ]) {
    final Object? value = transform[field];
    if (value is! num || !value.isFinite) {
      throw const FormatException('The world board transform is invalid.');
    }
  }
  final num scale = transform['scale']! as num;
  if (scale < 0.05 || scale > 16) {
    throw const FormatException('The world board scale is invalid.');
  }
}

void _validateBoardFollow(Object? raw) {
  final Map<String, dynamic> follow = _strictStringMap(
    raw,
    'world board follow settings',
  );
  _requireExactKeys(follow, const <String>{
    'mode',
    'targetPlayerUuid',
    'rotation',
  });
  final Object? mode = follow['mode'];
  final Object? target = follow['targetPlayerUuid'];
  final Object? rotation = follow['rotation'];
  if (mode == 'none') {
    if (target != null || rotation != 'fixed') {
      throw const FormatException(
        'The world board follow settings are invalid.',
      );
    }
    return;
  }
  if (mode != 'player' ||
      target is! String ||
      !_uuidPattern.hasMatch(target) ||
      !const <String>{'fixed', 'yaw', 'full'}.contains(rotation)) {
    throw const FormatException('The world board follow settings are invalid.');
  }
}

void _validateBoardVisibility(Object? raw) {
  final Map<String, dynamic> visibility = _strictStringMap(
    raw,
    'world board visibility',
  );
  _requireExactKeys(visibility, const <String>{
    'mode',
    'viewPermission',
    'interactPermission',
    'viewRange',
    'interactionRange',
  });
  final Object? mode = visibility['mode'];
  final Object? viewPermission = visibility['viewPermission'];
  final Object? interactPermission = visibility['interactPermission'];
  final Object? viewRange = visibility['viewRange'];
  final Object? interactionRange = visibility['interactionRange'];
  if (!const <String>{'public', 'permission', 'hidden'}.contains(mode) ||
      !_validPermission(viewPermission) ||
      !_validPermission(interactPermission) ||
      viewRange is! num ||
      !viewRange.isFinite ||
      viewRange <= 0 ||
      viewRange > 256 ||
      interactionRange is! num ||
      !interactionRange.isFinite ||
      interactionRange <= 0 ||
      interactionRange > 32 ||
      interactionRange > viewRange ||
      (mode == 'permission' && viewPermission == null) ||
      (mode != 'permission' && viewPermission != null) ||
      (mode == 'hidden' && interactPermission != null)) {
    throw const FormatException('The world board visibility is invalid.');
  }
}

Map<String, dynamic> _strictStringMap(Object? raw, String label) {
  if (raw is! Map) throw FormatException('Invalid $label.');
  final Map<String, dynamic> result = _copyStringMap(raw);
  if (result.length != raw.length) throw FormatException('Invalid $label.');
  return result;
}

void _requireExactKeys(Map<String, dynamic> value, Set<String> keys) {
  if (value.length != keys.length || !value.keys.toSet().containsAll(keys)) {
    throw const FormatException(
      'World board definitions cannot contain unsupported fields.',
    );
  }
}

bool _validPermission(Object? value) =>
    value == null || (value is String && _permissionPattern.hasMatch(value));

bool _isSorted(Iterable<String> values) {
  String? previous;
  for (final String value in values) {
    if (previous != null && previous.compareTo(value) > 0) return false;
    previous = value;
  }
  return true;
}

List<String> _strictStrings(Object? raw, String label) {
  if (raw is! List) throw FormatException('Invalid sync $label list.');
  final List<String> values = <String>[];
  final Set<String> seen = <String>{};
  for (final Object? value in raw) {
    if (value is! String || value.isEmpty || !seen.add(value)) {
      throw FormatException('Invalid sync $label list.');
    }
    values.add(value);
  }
  return values;
}

bool _validPrefix(Object? raw, {required bool menu}) {
  if (raw == null) return true;
  if (raw is! String || raw.isEmpty || !raw.endsWith('/')) return false;
  return menu
      ? isCanonicalMenuId('${raw}entry')
      : _validSyncImagePath('${raw}image.png');
}

bool _validSyncImagePath(String path) {
  if (validateImagePath(path) != null || path != path.trim()) return false;
  for (final String segment in path.split('/')) {
    if (segment == '.' || segment == '..' || segment.startsWith('.')) {
      return false;
    }
  }
  return true;
}

final RegExp _revisionPattern = RegExp(r'^sha256:[0-9a-f]{64}$');
final RegExp _capabilityPattern = RegExp(r'^[A-Za-z0-9_-]{22,128}$');
final RegExp _playerOpenCommandPattern = RegExp(
  r'^\s*/?(?:holoui|holo|hui|holou|hu)\s+open\s+(?:menu=)?([^\s]+)\s*$',
);
final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final RegExp _worldKeyPattern = RegExp(r'^[a-z0-9._-]+:[a-z0-9/._-]+$');
final RegExp _permissionPattern = RegExp(r'^[a-z0-9][a-z0-9._-]*$');

library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart' as crypto;

import '../config/defaults.dart';
import '../l10n/hui_localizations.dart';
import '../logic/validation.dart';
import '../model/model.dart';
import '../doctype/doctype.dart';
import '../state/workspace.dart';
import '../state/workspace_bundle.dart';
import '../state/workspace_panel.dart';
import 'editor_sync_binding_storage.dart';
import 'image_library.dart';

const int huiEditorSyncProtocol = 3;

const String huiEditorSyncFormat = 'gloss-sync-project';

const String _workspaceWireKind = 'workspace';
const String _menuWireKind = 'menu';
const String _panelWireKind = 'panel';

/// The workspace document kinds behind the supported wire kinds. Wire slugs
/// are deliberately independent of [WorkspaceDocKind] names; this is the one
/// place the two vocabularies meet.
final WorkspaceDocKind _menuDocKind = DocumentTypeRegistry.byWireKind(
  _menuWireKind,
)!.kind;
final WorkspaceDocKind _panelDocKind = DocumentTypeRegistry.byWireKind(
  _panelWireKind,
)!.kind;
const int huiEditorSyncMaxProjectBytes = 32 * 1024 * 1024;
const int huiEditorSyncMaxDocuments = 512;

/// `EditorSyncDocuments.MAX_DOCUMENT_BYTES` — the per-document JSON ceiling.
const int huiEditorSyncMaxDocumentBytes = 2 * 1024 * 1024;

/// `EditorSyncDocuments.MAX_DOCUMENT_ID_CHARS`.
const int huiEditorSyncMaxDocumentIdChars = 256;
const int huiEditorSyncMaxResponseEnvelopeBytes = 256 * 1024;
const int huiEditorSyncMaxRequestBytes =
    huiEditorSyncMaxProjectBytes + huiEditorSyncMaxResponseEnvelopeBytes;
const int huiEditorSyncMaxResponseBytes =
    (huiEditorSyncMaxProjectBytes * 2) + huiEditorSyncMaxResponseEnvelopeBytes;
const int huiEditorSyncMaxMenus = 256;
const int huiEditorSyncMaxImages = 512;
const int huiEditorSyncMaxImageDimension = 16;
const int huiEditorSyncMaxImagePixels = 16 * 16;
const int huiEditorSyncMaxAssetDimension = 4096;
const int huiEditorSyncMaxAssetImagePixels = 16777216;
const int huiEditorSyncMaxAssetPixels = 67108864;
const int huiEditorSyncMaxRenderPixels = 262144;
const int huiEditorSyncMaxRenderRows = 4096;
const int huiEditorSyncMaxSafeInteger = 9007199254740991;

final List<String> huiEditorSyncDocumentKinds = <String>[
  for (final DocumentTypeAdapter adapter in DocumentTypeRegistry.all)
    adapter.syncWireKind!,
]..sort();

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

final class EditorSyncDocument {
  const EditorSyncDocument({
    required this.kind,
    required this.id,
    required this.json,
    this.revision,
  });

  final String kind;
  final String id;
  final String json;
  final int? revision;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind,
    'id': id,
    if (revision != null) 'revision': revision,
    'json': json,
  };
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
    required this.documentKinds,
    required this.createDocumentKinds,
    required this.allowDeletes,
    this.newMenuPrefix,
    this.newImagePrefix,
  });

  final String subjectId;
  final List<String> documentKinds;
  final List<String> createDocumentKinds;
  final bool allowDeletes;
  final String? newMenuPrefix;
  final String? newImagePrefix;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'subjectId': subjectId,
    'documentKinds': documentKinds,
    'createDocumentKinds': createDocumentKinds,
    'allowDeletes': allowDeletes,
    if (newMenuPrefix != null) 'newMenuPrefix': newMenuPrefix,
    if (newImagePrefix != null) 'newImagePrefix': newImagePrefix,
  };

  static EditorSyncConstraints decode(Object? raw) {
    if (raw is! Map ||
        raw.keys.any(
          (Object? key) =>
              key is! String ||
              !const <String>{
                'subjectId',
                'documentKinds',
                'createDocumentKinds',
                'newMenuPrefix',
                'newImagePrefix',
                'allowDeletes',
              }.contains(key),
        ) ||
        raw['subjectId'] is! String ||
        (raw['subjectId'] as String).isEmpty ||
        raw['documentKinds'] is! List ||
        raw['createDocumentKinds'] is! List ||
        raw['allowDeletes'] is! bool) {
      throw const FormatException('Sync constraints are missing.');
    }
    final List<String> documentKinds = _strictStrings(
      raw['documentKinds'],
      'document kind',
    );
    final List<String> createDocumentKinds = _strictStrings(
      raw['createDocumentKinds'],
      'document kind',
    );
    if (documentKinds.any(
          (String kind) => DocumentTypeRegistry.byWireKind(kind) == null,
        ) ||
        createDocumentKinds.any(
          (String kind) => !documentKinds.contains(kind),
        ) ||
        !_isSorted(documentKinds) ||
        !_isSorted(createDocumentKinds)) {
      throw const FormatException('Sync constraints contain invalid kinds.');
    }
    final Object? newMenuPrefix = raw['newMenuPrefix'];
    final Object? newImagePrefix = raw['newImagePrefix'];
    if (!_validPrefix(newMenuPrefix, menu: true) ||
        !_validPrefix(newImagePrefix, menu: false)) {
      throw const FormatException('Sync constraints contain invalid prefixes.');
    }
    return EditorSyncConstraints(
      subjectId: raw['subjectId'] as String,
      documentKinds: List<String>.unmodifiable(documentKinds),
      createDocumentKinds: List<String>.unmodifiable(createDocumentKinds),
      allowDeletes: raw['allowDeletes'] as bool,
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
    required this.documents,
    required this.images,
    required this.constraints,
    this.warnings = const <String>[],
  });

  /// The sync subject's wire kind slug.
  final String kind;
  final String subjectId;
  final String baseRevision;

  final List<EditorSyncDocument> documents;
  final List<EditorSyncImage> images;
  final EditorSyncConstraints constraints;
  final List<String> warnings;

  /// The menu documents, in wire order.
  List<EditorSyncDocument> get menus => <EditorSyncDocument>[
    for (final EditorSyncDocument document in documents)
      if (document.kind == _menuWireKind) document,
  ];

  /// The parsed world-panel definition for panel-subject projects, or null.
  /// Panel document text is canonical JSON, so re-encoding the returned map
  /// with [editorSyncCanonicalJson] reproduces the wire bytes.
  Map<String, dynamic>? panelDefinition() {
    for (final EditorSyncDocument document in documents) {
      if (document.kind == _panelWireKind) {
        return _copyStringMap(jsonDecode(document.json) as Map);
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'format': huiEditorSyncFormat,
    'version': huiEditorSyncProtocol,
    'kind': kind,
    'subjectId': subjectId,
    'baseRevision': baseRevision,
    'documents': documents
        .map((EditorSyncDocument document) => document.toJson())
        .toList(),
    'images': images.map((EditorSyncImage image) => image.toJson()).toList(),
    'constraints': constraints.toJson(),
    'warnings': warnings,
  };

  static EditorSyncProject decode(Object? raw) {
    if (raw is! Map ||
        raw['format'] != huiEditorSyncFormat ||
        raw['version'] != huiEditorSyncProtocol) {
      throw const FormatException('Unsupported Gloss sync project.');
    }
    const Set<String> projectKeys = <String>{
      'format',
      'version',
      'kind',
      'subjectId',
      'baseRevision',
      'documents',
      'images',
      'constraints',
      'warnings',
    };
    if (!_hasExactKeys(raw, projectKeys)) {
      throw const FormatException('Sync project fields are invalid.');
    }
    final Object? kind = raw['kind'];
    final Object? subjectId = raw['subjectId'];
    final Object? baseRevision = raw['baseRevision'];
    if (kind is! String ||
        (kind != _workspaceWireKind &&
            DocumentTypeRegistry.byWireKind(kind) == null) ||
        subjectId is! String ||
        subjectId.isEmpty ||
        baseRevision is! String ||
        !editorSyncRevisionPattern.hasMatch(baseRevision)) {
      throw const FormatException('Invalid Gloss sync project identity.');
    }
    final EditorSyncConstraints constraints = EditorSyncConstraints.decode(
      raw['constraints'],
    );
    _validateConstraintShape(kind, subjectId, constraints);

    final Object? rawDocuments = raw['documents'];
    if (rawDocuments is! List ||
        rawDocuments.length > huiEditorSyncMaxDocuments ||
        (kind != _workspaceWireKind && rawDocuments.isEmpty)) {
      throw const FormatException('Invalid Gloss sync document collection.');
    }
    final List<EditorSyncDocument> documents = <EditorSyncDocument>[];
    final Set<String> documentKeys = <String>{};
    final Set<String> menuIds = <String>{};
    final List<EditorSyncDocument> panels = <EditorSyncDocument>[];
    for (final Object? entry in rawDocuments) {
      final EditorSyncDocument document = _decodeDocumentEntry(
        entry,
        documentKeys,
      );
      if (!constraints.documentKinds.contains(document.kind)) {
        throw const FormatException(
          'Sync document kind is outside the session constraints.',
        );
      }
      final DocumentTypeAdapter adapter = DocumentTypeRegistry.byWireKind(
        document.kind,
      )!;
      if (!_validDocumentId(document.kind, document.id)) {
        throw const FormatException('Invalid Gloss sync document id.');
      }
      if (document.kind == _panelWireKind) {
        final Object? decoded;
        try {
          decoded = jsonDecode(document.json);
        } catch (_) {
          throw const FormatException('The world panel is not valid JSON.');
        }
        if (decoded is! Map || document.json != _canonicalJson(decoded)) {
          throw const FormatException(
            'The world panel document must be canonical JSON text.',
          );
        }
        panels.add(document);
      } else {
        try {
          adapter.decodeSnapshot(document.json);
        } catch (_) {
          throw FormatException(
            huiText("The synced {kind} document is invalid.", <String, Object?>{
              'kind': document.kind,
            }),
          );
        }
      }
      if (_requiresDocumentRevision(document.kind)) {
        final Object? decoded = jsonDecode(document.json);
        final Object? jsonRevision = decoded is Map
            ? decoded['revision']
            : null;
        if (jsonRevision is! num ||
            jsonRevision.toInt() != jsonRevision ||
            jsonRevision.toInt() != document.revision) {
          throw const FormatException(
            'Sync document revision does not match its JSON.',
          );
        }
      }
      if (document.kind == _menuWireKind) menuIds.add(document.id);
      documents.add(document);
    }
    if (!_isSorted(
      documents.map(
        (EditorSyncDocument document) => '${document.kind}\u0000${document.id}',
      ),
    )) {
      throw const FormatException(
        'Sync documents must be sorted by kind and id.',
      );
    }
    for (final EditorSyncDocument panel in panels) {
      final Map<String, dynamic> definition = _copyStringMap(
        jsonDecode(panel.json) as Map,
      );
      if (definition['id'] != panel.id ||
          editorSyncPanelDefinitionProblem(definition, menuIds) != null) {
        throw const FormatException('The world panel identity is invalid.');
      }
    }
    if (kind != _workspaceWireKind &&
        !documents.any(
          (EditorSyncDocument document) =>
              document.kind == kind && document.id == subjectId,
        )) {
      throw const FormatException(
        'The sync subject document is missing from the snapshot.',
      );
    }

    final Object? rawImages = raw['images'];
    if (rawImages is! List || rawImages.length > huiEditorSyncMaxImages) {
      throw const FormatException('Invalid Gloss sync image collection.');
    }
    final List<EditorSyncImage> images = <EditorSyncImage>[];
    final Set<String> imagePaths = <String>{};
    final Map<String, StoredImageData> decodedImages =
        <String, StoredImageData>{};
    int assetPixels = 0;
    for (final Object? entry in rawImages) {
      if (entry is! Map ||
          !_hasExactKeys(entry, const <String>{'path', 'data'})) {
        throw const FormatException('Invalid Gloss sync image entry.');
      }
      final Object? path = entry['path'];
      final Object? data = entry['data'];
      if (path is! String ||
          !_validSyncImagePath(path) ||
          !imagePaths.add(path) ||
          data is! String ||
          data.length > huiMaxStoredImageBytes * 2) {
        throw const FormatException('Invalid Gloss sync image entry.');
      }
      final StoredImageData? decoded = decodeSupportedImageData(data);
      if (decoded == null ||
          decoded.bytes.length > huiMaxStoredImageBytes ||
          decoded.width > huiEditorSyncMaxAssetDimension ||
          decoded.height > huiEditorSyncMaxAssetDimension ||
          decoded.width * decoded.height > huiEditorSyncMaxAssetImagePixels) {
        throw const FormatException('Gloss sync image has invalid bytes.');
      }
      assetPixels += decoded.width * decoded.height;
      if (assetPixels > huiEditorSyncMaxAssetPixels) {
        throw const FormatException(
          'Gloss sync images exceed the decoded asset budget.',
        );
      }
      decodedImages[path] = decoded;
      images.add(EditorSyncImage(path: path, data: data));
    }
    if (!_isSorted(images.map((EditorSyncImage image) => image.path))) {
      throw const FormatException('Sync images must be sorted by path.');
    }

    final Object? rawWarnings = raw['warnings'];
    if (rawWarnings is! List || rawWarnings.length > 256) {
      throw const FormatException('Sync project warnings are invalid.');
    }
    final List<String> warnings = <String>[
      for (final Object? warning in rawWarnings)
        if (warning is String && warning.length <= 512) warning,
    ];
    if (warnings.length != rawWarnings.length || !_isSorted(warnings)) {
      throw const FormatException('Sync project warnings are invalid.');
    }
    final Set<String> referencedImagePaths = _validateSyncRasterBudget(
      documents.where(
        (EditorSyncDocument document) => document.kind == _menuWireKind,
      ),
      decodedImages,
    );
    if (kind != _workspaceWireKind &&
        (referencedImagePaths.length != decodedImages.length ||
            decodedImages.keys.any(
              (String path) => !referencedImagePaths.contains(path),
            ))) {
      throw const FormatException(
        'Focused sync projects may contain only referenced menu images.',
      );
    }
    if (_projectRevision(raw) != baseRevision) {
      throw const FormatException(
        'Sync project revision does not match its content.',
      );
    }
    final EditorSyncProject project = EditorSyncProject(
      kind: kind,
      subjectId: subjectId,
      baseRevision: baseRevision,
      documents: List<EditorSyncDocument>.unmodifiable(documents),
      images: List<EditorSyncImage>.unmodifiable(images),
      constraints: constraints,
      warnings: List<String>.unmodifiable(warnings),
    );
    if (utf8.encode(jsonEncode(project.toJson())).length >
        huiEditorSyncMaxProjectBytes) {
      throw const FormatException('Gloss sync project is too large.');
    }
    return project;
  }

  static EditorSyncDocument _decodeDocumentEntry(
    Object? entry,
    Set<String> seen,
  ) {
    if (entry is! Map ||
        entry.keys.any(
          (Object? key) =>
              key != 'kind' &&
              key != 'id' &&
              key != 'revision' &&
              key != 'json',
        )) {
      throw const FormatException('Invalid Gloss sync document entry.');
    }
    final Object? kind = entry['kind'];
    final Object? id = entry['id'];
    final Object? json = entry['json'];
    final Object? revision = entry['revision'];
    if (kind is! String ||
        DocumentTypeRegistry.byWireKind(kind) == null ||
        id is! String ||
        id.isEmpty ||
        id.length > huiEditorSyncMaxDocumentIdChars ||
        !seen.add('$kind\u0000$id') ||
        json is! String ||
        json.isEmpty ||
        utf8.encode(json).length > huiEditorSyncMaxDocumentBytes ||
        (revision != null &&
            (revision is! int ||
                revision < 1 ||
                revision > huiEditorSyncMaxSafeInteger)) ||
        (_requiresDocumentRevision(kind) != (revision != null))) {
      throw const FormatException('Invalid Gloss sync document entry.');
    }
    return EditorSyncDocument(
      kind: kind,
      id: id,
      json: json,
      revision: revision as int?,
    );
  }
}

bool _requiresDocumentRevision(String kind) =>
    kind != _menuWireKind && kind != 'container-preview';

bool _validDocumentId(String kind, String id) {
  if (!isCanonicalMenuId(id)) return false;
  if (kind == _menuWireKind || kind == _panelWireKind) return true;
  if (kind == 'motd') return id == 'motd';
  if (kind == 'tablist') return id == 'tablist';
  if (kind == 'real-drops') return id == 'default';
  if (kind == 'damage-indicators') return id == 'default';
  return !id.contains('/');
}

void _validateConstraintShape(
  String kind,
  String subjectId,
  EditorSyncConstraints constraints,
) {
  if (constraints.subjectId != subjectId) {
    throw const FormatException('Sync constraints do not match the subject.');
  }
  if (kind == _workspaceWireKind) {
    if (subjectId != _workspaceWireKind ||
        !_sameStrings(constraints.documentKinds, huiEditorSyncDocumentKinds) ||
        !_sameStrings(
          constraints.createDocumentKinds,
          huiEditorSyncDocumentKinds,
        ) ||
        !constraints.allowDeletes ||
        constraints.newMenuPrefix != null ||
        constraints.newImagePrefix != null) {
      throw const FormatException('Workspace sync constraints are invalid.');
    }
    return;
  }
  if (kind == _menuWireKind) {
    if (!_sameStrings(constraints.documentKinds, const <String>[
          _menuWireKind,
        ]) ||
        constraints.createDocumentKinds.isNotEmpty ||
        constraints.allowDeletes ||
        constraints.newMenuPrefix != null ||
        constraints.newImagePrefix == null) {
      throw const FormatException('Menu sync constraints are invalid.');
    }
    return;
  }
  if (kind == _panelWireKind) {
    if (!_sameStrings(constraints.documentKinds, const <String>[
          _menuWireKind,
          _panelWireKind,
        ]) ||
        !_sameStrings(constraints.createDocumentKinds, const <String>[
          _menuWireKind,
        ]) ||
        constraints.allowDeletes ||
        constraints.newMenuPrefix == null ||
        constraints.newImagePrefix == null) {
      throw const FormatException('Panel sync constraints are invalid.');
    }
    return;
  }
  if (!_sameStrings(constraints.documentKinds, <String>[kind]) ||
      constraints.createDocumentKinds.isNotEmpty ||
      constraints.allowDeletes ||
      constraints.newMenuPrefix != null ||
      constraints.newImagePrefix != null) {
    throw const FormatException('Document sync constraints are invalid.');
  }
}

bool _sameStrings(List<String> first, List<String> second) {
  if (first.length != second.length) return false;
  for (int index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

Set<String> _validateSyncRasterBudget(
  Iterable<EditorSyncDocument> menus,
  Map<String, StoredImageData> images,
) {
  final _EditorSyncRasterBudget budget = _EditorSyncRasterBudget(images);
  for (final EditorSyncDocument menu in menus) {
    budget.visit(jsonDecode(menu.json));
  }
  return Set<String>.unmodifiable(budget.referencedPaths);
}

final class _EditorSyncRasterBudget {
  _EditorSyncRasterBudget(this.images);

  final Map<String, StoredImageData> images;
  final Set<String> referencedPaths = <String>{};
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
      throw const FormatException('Gloss sync image reference is invalid.');
    }
    final StoredImageData? image = images[rawPath];
    if (image == null) {
      throw FormatException(
        huiText(
          'Gloss sync image reference is missing: {path}',
          <String, Object?>{'path': rawPath},
        ),
      );
    }
    referencedPaths.add(rawPath);
    if (image.width > huiEditorSyncMaxImageDimension ||
        image.height > huiEditorSyncMaxImageDimension ||
        image.width * image.height > huiEditorSyncMaxImagePixels) {
      throw FormatException(
        huiText(
          'Gloss menu image exceeds the text-image limit: {path}',
          <String, Object?>{'path': rawPath},
        ),
      );
    }
    renderPixels += image.width * image.height;
    renderRows += image.height;
    if (renderPixels > huiEditorSyncMaxRenderPixels ||
        renderRows > huiEditorSyncMaxRenderRows) {
      throw const FormatException(
        'Gloss sync menus exceed the raster render budget.',
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
    required this.documentIds,
    required this.imagePaths,
    required this.constraints,
    required this.warnings,
    this.pendingContentRevision,
  });

  final String sessionId;
  final String editorToken;
  final Uri relayEndpoint;
  final String kind;
  final String subjectId;
  final String baseRevision;
  final Map<String, String> documentIds;
  final List<String> imagePaths;
  final EditorSyncConstraints constraints;
  final List<String> warnings;
  final String? pendingContentRevision;

  String? documentId(String kind, String id) =>
      documentIds[_documentKey(kind, id)];

  bool isDocumentBound(WorkspaceDoc doc) {
    if (doc.kind == _panelDocKind) {
      final WorkspacePanelData data = decodeWorkspacePanel(doc.json).data;
      final String? id = data.runtimeBoardId;
      return id != null && documentId(_panelWireKind, id) == doc.id;
    }
    final String? wireKind = DocumentTypeRegistry.of(doc.kind).syncWireKind;
    final String? id = doc.runtimeId;
    return wireKind != null && id != null && documentId(wireKind, id) == doc.id;
  }

  String? get firstDocumentId => documentIds.values.firstOrNull;

  String? get panelDocumentId {
    for (final MapEntry<String, String> entry in documentIds.entries) {
      if (entry.key.startsWith('$_panelWireKind\u0000')) return entry.value;
    }
    return null;
  }

  EditorSyncBinding copyWith({
    String? baseRevision,
    Map<String, String>? documentIds,
    List<String>? imagePaths,
    List<String>? warnings,
    String? pendingContentRevision,
    bool clearPendingContentRevision = false,
  }) => EditorSyncBinding(
    sessionId: sessionId,
    editorToken: editorToken,
    relayEndpoint: relayEndpoint,
    kind: kind,
    subjectId: subjectId,
    baseRevision: baseRevision ?? this.baseRevision,
    documentIds: documentIds ?? this.documentIds,
    imagePaths: imagePaths ?? this.imagePaths,
    constraints: constraints,
    warnings: warnings ?? this.warnings,
    pendingContentRevision: clearPendingContentRevision
        ? null
        : pendingContentRevision ?? this.pendingContentRevision,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': huiEditorSyncProtocol,
    'sessionId': sessionId,
    'editorToken': editorToken,
    'relayEndpoint': relayEndpoint.toString(),
    'kind': kind,
    'subjectId': subjectId,
    'baseRevision': baseRevision,
    'documentIds': documentIds,
    'imagePaths': imagePaths,
    'constraints': constraints.toJson(),
    'warnings': warnings,
    'pendingContentRevision': pendingContentRevision,
  };

  static EditorSyncBinding? decode(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map ||
          decoded['version'] != huiEditorSyncProtocol ||
          !_hasExactKeys(decoded, const <String>{
            'version',
            'sessionId',
            'editorToken',
            'relayEndpoint',
            'kind',
            'subjectId',
            'baseRevision',
            'documentIds',
            'imagePaths',
            'constraints',
            'warnings',
            'pendingContentRevision',
          })) {
        return null;
      }
      final Object? sessionId = decoded['sessionId'];
      final Object? editorToken = decoded['editorToken'];
      final Uri? relay = _parseRelay(decoded['relayEndpoint']);
      final Object? kind = decoded['kind'];
      final Object? subjectId = decoded['subjectId'];
      final Object? baseRevision = decoded['baseRevision'];
      final Object? rawIds = decoded['documentIds'];
      final Object? rawPaths = decoded['imagePaths'];
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
          kind is! String ||
          (kind != _workspaceWireKind &&
              DocumentTypeRegistry.byWireKind(kind) == null) ||
          subjectId is! String ||
          baseRevision is! String ||
          !editorSyncRevisionPattern.hasMatch(baseRevision) ||
          rawIds is! Map ||
          rawPaths is! List ||
          rawWarnings is! List ||
          (pendingContentRevision != null &&
              (pendingContentRevision is! String ||
                  !editorSyncRevisionPattern.hasMatch(
                    pendingContentRevision,
                  )))) {
        return null;
      }
      _validateConstraintShape(kind, subjectId, constraints);
      final Map<String, String> documentIds = <String, String>{};
      rawIds.forEach((Object? key, Object? value) {
        if (key is String && value is String) documentIds[key] = value;
      });
      if (documentIds.length != rawIds.length) return null;
      final List<String> imagePaths = _strictStrings(rawPaths, 'image path');
      final List<String> warnings = _strictStrings(rawWarnings, 'warning');
      return EditorSyncBinding(
        sessionId: sessionId,
        editorToken: editorToken,
        relayEndpoint: relay,
        kind: kind,
        subjectId: subjectId,
        baseRevision: baseRevision,
        documentIds: Map<String, String>.unmodifiable(documentIds),
        imagePaths: List<String>.unmodifiable(imagePaths),
        constraints: constraints,
        warnings: List<String>.unmodifiable(warnings),
        pendingContentRevision: pendingContentRevision as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

String _documentKey(String kind, String id) => '$kind\u0000$id';

final class EditorSyncClient {
  EditorSyncClient({
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 12),
    this.maximumResponseBytes = huiEditorSyncMaxResponseBytes,
  }) : _client = client ?? http.Client() {
    if (requestTimeout <= Duration.zero ||
        maximumResponseBytes <= 0 ||
        maximumResponseBytes > huiEditorSyncMaxResponseBytes) {
      throw ArgumentError(huiText('Invalid editor sync client limits.'));
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
      throw EditorSyncFailure(
        'Relay returned HTTP {status}.',
        <String, Object?>{'status': response.statusCode},
      );
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
      final String? relayMessage = _errorMessage(response.bodyBytes);
      if (relayMessage != null) {
        throw EditorSyncConflict.literal(relayMessage);
      }
      throw const EditorSyncConflict(
        'The relay rejected the publication because the session changed.',
      );
    }
    if (response.statusCode != 202) {
      throw EditorSyncFailure(
        'Relay returned HTTP {status}.',
        <String, Object?>{'status': response.statusCode},
      );
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
  const EditorSyncFailure(
    this._english, [
    this._arguments = const <String, Object?>{},
  ]) : _resolver = null;

  const EditorSyncFailure.deferred(String Function() resolver)
    : _english = '',
      _arguments = const <String, Object?>{},
      _resolver = resolver;

  EditorSyncFailure.literal(String message)
    : _english = '',
      _arguments = const <String, Object?>{},
      _resolver = (() => message);

  final String _english;
  final Map<String, Object?> _arguments;
  final String Function()? _resolver;

  String get message => _resolver?.call() ?? huiText(_english, _arguments);
}

final class EditorSyncConflict extends EditorSyncFailure {
  const EditorSyncConflict(super._english, [super._arguments]);

  EditorSyncConflict.literal(super.message) : super.literal();
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

/// Canonical JSON text for [value] under the frozen protocol canonicalization
/// (lexicographic keys, array order, ECMAScript number spelling). Panel
/// documents are required to be in this form on the wire.
String editorSyncCanonicalJson(Object? value) => _canonicalJson(value);

String? editorSyncPanelDefinitionProblem(
  Map<String, dynamic> board,
  Iterable<String> menuIds,
) {
  try {
    _validatePanelDefinition(board, menuIds.toSet());
    return null;
  } on FormatException catch (error) {
    return huiText(error.message.toString());
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
}) async {
  if (!workspace.canWrite) {
    throw const EditorSyncFailure('The local workspace is not writable.');
  }
  if (project.kind == _workspaceWireKind) {
    return _replaceWorkspaceProject(
      capability: capability,
      project: project,
      workspace: workspace,
      images: images,
      preserveUnlinkedPanels: false,
    );
  }
  return _mergeSyncProject(
    capability: capability,
    project: project,
    workspace: workspace,
    images: images,
  );
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
  if (project.kind == _workspaceWireKind) {
    return _replaceWorkspaceProject(
      capability: binding,
      project: project,
      workspace: workspace,
      images: images,
      preserveUnlinkedPanels: true,
    );
  }
  final Set<String> refreshedKeys = <String>{
    for (final EditorSyncDocument document in project.documents)
      _documentKey(document.kind, document.id),
  };
  if (!project.constraints.allowDeletes &&
      !refreshedKeys.containsAll(binding.documentIds.keys)) {
    throw const EditorSyncConflict(
      'The refreshed server scope removed bound resources.',
    );
  }
  return _mergeSyncProject(
    capability: binding,
    project: project,
    workspace: workspace,
    images: images,
  );
}

Future<EditorSyncBinding> _replaceWorkspaceProject({
  required EditorSyncBinding capability,
  required EditorSyncProject project,
  required Workspace workspace,
  required ImageLibrary images,
  required bool preserveUnlinkedPanels,
}) async {
  final Map<String, dynamic> state = _workspaceStateForProject(
    project,
    workspace,
    preserveUnlinkedPanels: preserveUnlinkedPanels,
  );
  final WorkspaceBundle bundle = WorkspaceBundle(
    workspaceState: state,
    images: _storedImages(project.images),
  );
  final WorkspaceBundleImportResult result = await importWorkspaceBundle(
    bundle,
    workspace,
    images,
  );
  if (!result.isSuccess) {
    throw EditorSyncFailure.literal(
      result.error ?? huiText('The server workspace could not be stored.'),
    );
  }
  return _bindingForProject(capability, project, workspace);
}

Map<String, dynamic> _workspaceStateForProject(
  EditorSyncProject project,
  Workspace workspace, {
  required bool preserveUnlinkedPanels,
}) {
  final int now = DateTime.now().millisecondsSinceEpoch;
  final Map<String, String> folderIds = <String, String>{};
  final List<Map<String, dynamic>> folders = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> documents = <Map<String, dynamic>>[];
  for (final EditorSyncDocument document in project.documents) {
    final DocumentTypeAdapter adapter = DocumentTypeRegistry.byWireKind(
      document.kind,
    )!;
    final String folderId = folderIds.putIfAbsent(document.kind, () {
      final String id = newWorkspaceUuid();
      folders.add(<String, dynamic>{
        'id': id,
        'title': adapter.pluralLabel,
        'parentId': null,
        'updatedAt': now,
      });
      return id;
    });
    final String workspaceDocumentId = newWorkspaceUuid();
    final String json = document.kind == _panelWireKind
        ? encodeWorkspacePanel(
            WorkspacePanelData(
              scopeFolderId: folderId,
              runtimeBoardId: document.id,
              runtimeBoard: _copyStringMap(jsonDecode(document.json) as Map),
              syncMenuIds: project.menus
                  .map((EditorSyncDocument menu) => menu.id)
                  .toList(growable: false),
              syncImagePaths: project.images
                  .map((EditorSyncImage image) => image.path)
                  .toList(growable: false),
            ),
          )
        : document.json;
    documents.add(<String, dynamic>{
      'id': workspaceDocumentId,
      'title': document.id.split('/').last,
      'runtimeId': document.kind == _panelWireKind ? null : document.id,
      'json': json,
      'updatedAt': now,
      'kind': adapter.kind.name,
      'folderId': folderId,
    });
  }
  if (preserveUnlinkedPanels) {
    for (final WorkspaceDoc doc in workspace.docs) {
      if (doc.kind != _panelDocKind ||
          decodeWorkspacePanel(doc.json).data.runtimeBoard != null) {
        continue;
      }
      documents.add(<String, dynamic>{...doc.toJson(), 'folderId': null});
    }
  }
  return <String, dynamic>{
    'schemaVersion': Workspace.schemaVersion,
    'workspaceId': workspace.id,
    'folders': folders,
    'documents': documents,
    'activeDocumentId': documents.isEmpty ? null : documents.first['id'],
  };
}

Future<EditorSyncBinding> _mergeSyncProject({
  required EditorSyncBinding capability,
  required EditorSyncProject project,
  required Workspace workspace,
  required ImageLibrary images,
}) async {
  final String workspaceRollback = workspace.createRollbackSnapshot();
  final List<StoredImage> imageRollback = List<StoredImage>.of(images.images);
  try {
    for (final EditorSyncDocument document in project.documents) {
      final DocumentTypeAdapter adapter = DocumentTypeRegistry.byWireKind(
        document.kind,
      )!;
      final WorkspaceDoc? existing = _findRuntimeDocument(
        workspace,
        document.kind,
        document.id,
      );
      final String json = document.kind == _panelWireKind
          ? encodeWorkspacePanel(
              (existing == null
                      ? const WorkspacePanelData()
                      : decodeWorkspacePanel(existing.json).data)
                  .copyWith(
                    runtimeBoardId: document.id,
                    runtimeBoard: _copyStringMap(
                      jsonDecode(document.json) as Map,
                    ),
                    syncMenuIds: project.menus
                        .map((EditorSyncDocument menu) => menu.id)
                        .toList(growable: false),
                    syncImagePaths: project.images
                        .map((EditorSyncImage image) => image.path)
                        .toList(growable: false),
                  ),
            )
          : document.json;
      if (existing == null) {
        workspace.create(
          title: document.id.split('/').last,
          runtimeId: document.kind == _panelWireKind ? null : document.id,
          json: json,
          kind: adapter.kind,
        );
      } else if (!workspace.replaceDocument(
        id: existing.id,
        title: existing.title,
        runtimeId: document.kind == _panelWireKind ? null : document.id,
        json: json,
        kind: adapter.kind,
        folderId: existing.folderId,
      )) {
        throw EditorSyncFailure(
          'The synced document {id} could not be stored locally.',
          <String, Object?>{'id': document.id},
        );
      }
    }
    if (!workspace.save()) {
      throw const EditorSyncFailure(
        'The synced workspace could not be stored locally.',
      );
    }
    await workspace.writesSettled;
    if (workspace.hasUnsavedChanges) {
      throw EditorSyncFailure.deferred(
        workspace.lastErrorMessage ??
            () => huiText('The synced workspace could not be stored locally.'),
      );
    }
    if (!images.upsertAll(_storedImages(project.images))) {
      throw EditorSyncFailure.deferred(
        images.lastErrorMessage ??
            () => huiText('The synced images could not be stored locally.'),
      );
    }
    await images.writesSettled;
    if (images.hasUnsavedChanges) {
      throw EditorSyncFailure.deferred(
        images.lastErrorMessage ??
            () => huiText('The synced images could not be stored locally.'),
      );
    }
    return _bindingForProject(capability, project, workspace);
  } catch (error) {
    await _restoreWorkspaceAfterSyncFailure(workspace, workspaceRollback);
    images.replaceAll(imageRollback);
    await images.writesSettled;
    if (error is EditorSyncFailure) rethrow;
    throw const EditorSyncFailure(
      'The synced project could not be stored locally.',
    );
  }
}

EditorSyncBinding _bindingForProject(
  EditorSyncBinding capability,
  EditorSyncProject project,
  Workspace workspace,
) {
  final Map<String, String> documentIds = <String, String>{};
  for (final EditorSyncDocument document in project.documents) {
    final WorkspaceDoc? local = _findRuntimeDocument(
      workspace,
      document.kind,
      document.id,
    );
    if (local == null) {
      throw const EditorSyncFailure(
        'A synced document was not retained in the workspace.',
      );
    }
    documentIds[_documentKey(document.kind, document.id)] = local.id;
  }
  return EditorSyncBinding(
    sessionId: capability.sessionId,
    editorToken: capability.editorToken,
    relayEndpoint: capability.relayEndpoint,
    kind: project.kind,
    subjectId: project.subjectId,
    baseRevision: project.baseRevision,
    documentIds: Map<String, String>.unmodifiable(documentIds),
    imagePaths: List<String>.unmodifiable(
      project.images.map((EditorSyncImage image) => image.path),
    ),
    constraints: project.constraints,
    warnings: project.warnings,
  );
}

WorkspaceDoc? _findRuntimeDocument(
  Workspace workspace,
  String wireKind,
  String runtimeId,
) {
  final DocumentTypeAdapter adapter = DocumentTypeRegistry.byWireKind(
    wireKind,
  )!;
  WorkspaceDoc? match;
  for (final WorkspaceDoc doc in workspace.docs) {
    if (doc.kind != adapter.kind) continue;
    final bool matches = wireKind == _panelWireKind
        ? decodeWorkspacePanel(doc.json).data.runtimeBoardId == runtimeId
        : doc.runtimeId == runtimeId;
    if (!matches) continue;
    if (match != null) {
      throw EditorSyncConflict(
        'The local workspace contains duplicate runtime id {id}.',
        <String, Object?>{'id': runtimeId},
      );
    }
    match = doc;
  }
  return match;
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
  final List<WorkspaceDoc> scoped = <WorkspaceDoc>[];
  if (binding.kind == _workspaceWireKind) {
    scoped.addAll(workspace.docs);
  } else {
    for (final String documentId in binding.documentIds.values) {
      final WorkspaceDoc? doc = workspace.byId(documentId);
      if (doc == null) {
        throw const EditorSyncFailure(
          'A bound server document is missing locally.',
        );
      }
      scoped.add(doc);
    }
    if (binding.kind == _panelWireKind &&
        binding.constraints.newMenuPrefix != null) {
      _addReachablePanelMenus(binding, workspace, scoped);
    }
  }

  final List<EditorSyncDocument> documents = <EditorSyncDocument>[];
  final Set<String> keys = <String>{};
  for (final WorkspaceDoc doc in scoped) {
    final DocumentTypeAdapter adapter = DocumentTypeRegistry.of(doc.kind);
    final String? wireKind = adapter.syncWireKind;
    if (wireKind == null) continue;
    String? runtimeId = doc.runtimeId;
    String json = doc.json;
    if (wireKind == _panelWireKind) {
      final WorkspacePanelDecodeResult decoded = decodeWorkspacePanel(doc.json);
      if (decoded.warning != null) {
        throw const EditorSyncFailure('A linked world panel is unreadable.');
      }
      runtimeId = decoded.data.runtimeBoardId;
      final Map<String, dynamic>? runtimeBoard = decoded.data.runtimeBoard;
      if (runtimeId == null || runtimeBoard == null) {
        continue;
      }
      json = _canonicalJson(runtimeBoard);
    } else {
      if (runtimeId == null) {
        throw const EditorSyncFailure('A runtime document is missing its id.');
      }
      try {
        adapter.decodeSnapshot(json);
      } catch (_) {
        throw EditorSyncFailure(
          'The local {kind} document {id} is invalid.',
          <String, Object?>{'kind': wireKind, 'id': runtimeId},
        );
      }
      if (wireKind == _menuWireKind) {
        final HuiMenu menu = decodeHuiMenu(json);
        final List<HuiIssue> issues = validateHuiMenu(
          menu,
          knownImagePaths: images.paths,
        );
        if (issues.any(
          (HuiIssue issue) => issue.severity == HuiSeverity.error,
        )) {
          throw EditorSyncFailure(
            'The menu {id} has validation errors.',
            <String, Object?>{'id': runtimeId},
          );
        }
      }
    }
    final String key = _documentKey(wireKind, runtimeId);
    if (!keys.add(key)) {
      throw EditorSyncFailure(
        'The workspace contains duplicate runtime id {id}.',
        <String, Object?>{'id': runtimeId},
      );
    }
    documents.add(
      EditorSyncDocument(
        kind: wireKind,
        id: runtimeId,
        json: json,
        revision: _documentJsonRevision(wireKind, json),
      ),
    );
  }
  documents.sort((EditorSyncDocument first, EditorSyncDocument second) {
    final int kind = first.kind.compareTo(second.kind);
    return kind == 0 ? first.id.compareTo(second.id) : kind;
  });

  final Set<String> imagePaths = <String>{};
  if (binding.kind == _workspaceWireKind) {
    imagePaths.addAll(images.paths);
  } else {
    imagePaths.addAll(binding.imagePaths);
    for (final EditorSyncDocument document in documents) {
      _collectImagePaths(jsonDecode(document.json), imagePaths);
    }
  }
  final List<String> orderedPaths = imagePaths.toList()..sort();
  final List<EditorSyncImage> projectImages = <EditorSyncImage>[];
  for (final String path in orderedPaths) {
    final StoredImage? image = images.byPath(path);
    if (image == null || !isValidStoredImageData(image)) {
      throw EditorSyncFailure(
        'The bound image {path} is missing or invalid.',
        <String, Object?>{'path': path},
      );
    }
    final String? prefix = binding.constraints.newImagePrefix;
    if (binding.kind != _workspaceWireKind &&
        !binding.imagePaths.contains(path) &&
        (prefix == null || !path.startsWith(prefix))) {
      throw EditorSyncFailure(
        'Image {path} is outside the allowed server scope.',
        <String, Object?>{'path': path},
      );
    }
    projectImages.add(EditorSyncImage(path: path, data: image.dataUri));
  }

  final EditorSyncProject provisional = EditorSyncProject(
    kind: binding.kind,
    subjectId: binding.subjectId,
    baseRevision: 'sha256:${List<String>.filled(64, '0').join()}',
    documents: List<EditorSyncDocument>.unmodifiable(documents),
    images: List<EditorSyncImage>.unmodifiable(projectImages),
    constraints: binding.constraints,
    warnings: binding.warnings,
  );
  final EditorSyncProject collected = EditorSyncProject(
    kind: provisional.kind,
    subjectId: provisional.subjectId,
    baseRevision: _projectRevision(provisional.toJson()),
    documents: provisional.documents,
    images: provisional.images,
    constraints: provisional.constraints,
    warnings: provisional.warnings,
  );
  return EditorSyncProject.decode(collected.toJson());
}

int? _documentJsonRevision(String kind, String json) {
  if (!_requiresDocumentRevision(kind)) return null;
  final Object? decoded = jsonDecode(json);
  final Object? revision = decoded is Map ? decoded['revision'] : null;
  if (revision is! num || revision.toInt() != revision) {
    throw const EditorSyncFailure(
      'A versioned runtime document is missing its revision.',
    );
  }
  return revision.toInt();
}

void _addReachablePanelMenus(
  EditorSyncBinding binding,
  Workspace workspace,
  List<WorkspaceDoc> scoped,
) {
  final WorkspaceDoc? panel = workspace.byId(binding.panelDocumentId);
  if (panel == null) {
    throw const EditorSyncFailure('The bound world panel is missing.');
  }
  final WorkspacePanelData data = decodeWorkspacePanel(panel.json).data;
  final Object? root = data.runtimeBoard?['rootMenuId'];
  if (root is! String) {
    throw const EditorSyncFailure('The bound world panel root is missing.');
  }
  final String prefix = binding.constraints.newMenuPrefix!;
  final Map<String, List<WorkspaceDoc>> candidates =
      <String, List<WorkspaceDoc>>{};
  for (final WorkspaceDoc doc in workspace.docs) {
    final String? id = doc.runtimeId;
    if (doc.kind != _menuDocKind || id == null) continue;
    if (binding.documentId(_menuWireKind, id) == doc.id ||
        id.startsWith(prefix)) {
      candidates.putIfAbsent(id, () => <WorkspaceDoc>[]).add(doc);
    }
  }
  final List<String> pending = <String>[root];
  final Set<String> visited = <String>{};
  for (int cursor = 0; cursor < pending.length; cursor++) {
    final String id = pending[cursor];
    if (!visited.add(id)) continue;
    if (visited.length > huiEditorSyncMaxMenus) {
      throw const EditorSyncFailure(
        'The world panel navigation graph exceeds 256 menus.',
      );
    }
    final List<WorkspaceDoc> matches = candidates[id] ?? <WorkspaceDoc>[];
    if (matches.length > 1) {
      throw EditorSyncFailure(
        'The panel menu id {id} is duplicated.',
        <String, Object?>{'id': id},
      );
    }
    if (matches.isEmpty) continue;
    final WorkspaceDoc document = matches.single;
    if (!scoped.any((WorkspaceDoc current) => current.id == document.id)) {
      scoped.add(document);
    }
    final Object? source = jsonDecode(document.json);
    final Set<String> targets = <String>{};
    _collectMenuTargets(source, targets);
    final List<String> ordered = targets.toList()..sort();
    pending.addAll(ordered);
  }
  if (!visited.contains(root) || !candidates.containsKey(root)) {
    throw EditorSyncFailure(
      'The panel root menu {id} is missing.',
      <String, Object?>{'id': root},
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
      !editorSyncRevisionPattern.hasMatch(baseRevision) ||
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
      !editorSyncRevisionPattern.hasMatch(raw['baseRevision']! as String) ||
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
            !editorSyncRevisionPattern.hasMatch(rawServerRevision)
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
      !relay.path.endsWith('/v3')) {
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

String? _errorMessage(Uint8List bytes) {
  try {
    final Object? raw = jsonDecode(utf8.decode(bytes));
    if (raw is Map && raw['error'] is Map) {
      final Object? message = (raw['error']! as Map)['message'];
      if (message is String && message.isNotEmpty) return message;
    }
  } catch (_) {}
  return null;
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

void _validatePanelDefinition(Map<String, dynamic> board, Set<String> menuIds) {
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
    throw const FormatException('The world panel identity is invalid.');
  }
  _validateBoardTransform(board['transform']);
  _validateBoardFollow(board['follow']);
  _validateBoardVisibility(board['visibility']);
}

void _validateBoardTransform(Object? raw) {
  final Map<String, dynamic> transform = _strictStringMap(
    raw,
    'world panel transform',
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
    throw const FormatException('The world panel transform is invalid.');
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
      throw const FormatException('The world panel transform is invalid.');
    }
  }
  final num scale = transform['scale']! as num;
  if (scale < 0.05 || scale > 16) {
    throw const FormatException('The world panel scale is invalid.');
  }
}

void _validateBoardFollow(Object? raw) {
  final Map<String, dynamic> follow = _strictStringMap(
    raw,
    'world panel follow settings',
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
        'The world panel follow settings are invalid.',
      );
    }
    return;
  }
  if (mode != 'player' ||
      target is! String ||
      !_uuidPattern.hasMatch(target) ||
      !const <String>{'fixed', 'yaw', 'full'}.contains(rotation)) {
    throw const FormatException('The world panel follow settings are invalid.');
  }
}

void _validateBoardVisibility(Object? raw) {
  final Map<String, dynamic> visibility = _strictStringMap(
    raw,
    'world panel visibility',
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
    throw const FormatException('The world panel visibility is invalid.');
  }
}

Map<String, dynamic> _strictStringMap(Object? raw, String label) {
  if (raw is! Map) throw FormatException(_invalidMapMessage(label));
  final Map<String, dynamic> result = _copyStringMap(raw);
  if (result.length != raw.length) {
    throw FormatException(_invalidMapMessage(label));
  }
  return result;
}

String _invalidMapMessage(String label) => switch (label) {
  'world panel transform' => huiText('Invalid world panel transform.'),
  'world panel follow settings' => huiText(
    'Invalid world panel follow settings.',
  ),
  'world panel visibility' => huiText('Invalid world panel visibility.'),
  _ => throw ArgumentError.value(label, 'label'),
};

void _requireExactKeys(Map<String, dynamic> value, Set<String> keys) {
  if (value.length != keys.length || !value.keys.toSet().containsAll(keys)) {
    throw const FormatException(
      'World panel definitions cannot contain unsupported fields.',
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
  if (raw is! List) throw FormatException(_invalidStringListMessage(label));
  final List<String> values = <String>[];
  final Set<String> seen = <String>{};
  for (final Object? value in raw) {
    if (value is! String || value.isEmpty || !seen.add(value)) {
      throw FormatException(_invalidStringListMessage(label));
    }
    values.add(value);
  }
  return values;
}

String _invalidStringListMessage(String label) => switch (label) {
  'menu id' => huiText('Invalid sync menu id list.'),
  'image path' => huiText('Invalid sync image path list.'),
  'document kind' => huiText('Invalid sync document kind list.'),
  'warning' => huiText('Invalid sync warning list.'),
  _ => throw ArgumentError.value(label, 'label'),
};

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

/// The project revision grammar shared with `EditorSyncProject` and the
/// relay: a lowercase SHA-256 of the canonical project content.
final RegExp editorSyncRevisionPattern = RegExp(r'^sha256:[0-9a-f]{64}$');

final RegExp editorSyncKindPattern = RegExp(r'^[a-z][a-z0-9-]{0,31}$');
final RegExp _capabilityPattern = RegExp(r'^[A-Za-z0-9_-]{22,128}$');
final RegExp _playerOpenCommandPattern = RegExp(
  r'^\s*/?gloss\s+(?:menu\s+)?open\s+(?:menu=)?([^\s]+)\s*$',
);

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final RegExp _worldKeyPattern = RegExp(r'^[a-z0-9._-]+:[a-z0-9/._-]+$');
final RegExp _permissionPattern = RegExp(r'^[a-z0-9][a-z0-9._-]*$');

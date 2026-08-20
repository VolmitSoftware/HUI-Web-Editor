/// Pins the sync-v2 wire limits that exist in four places at once.
///
/// The protocol numbers live in Gloss (`EditorSyncDocuments`,
/// `EditorSyncSnapshotBuilder`, `EditorSyncKind`, `EditorSyncProject`,
/// `EditorSyncJson`), in `lib/services/editor_sync.dart`, in the `sync-relay`
/// package and in that package's JSON schema. `sync-relay` is a separate Dart
/// package with its own pubspec and is not a dependency of the editor, so its
/// values are read out of its source text here rather than imported; the Gloss
/// values are read out of the Java source the same way.
///
/// A failure names the constant that drifted. Gloss is the truth repo: the
/// editor and relay follow the Java values, never the other way round.
library;

import 'dart:convert';
import 'dart:io';

import 'package:gloss_editor/services/editor_sync.dart';
import 'package:test/test.dart';

import 'support/java_source.dart';

const String _syncPackage = 'src/main/java/art/arcane/gloss/editor/sync';
const String _relayModel = 'sync-relay/lib/src/model.dart';
const String _relayConfig = 'sync-relay/lib/src/config.dart';
const String _relaySchema = 'sync-relay/schema/project-v2.schema.json';

String _readLocal(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    throw StateError('missing $path');
  }
  return file.readAsStringSync();
}

Map<String, Object?> _schemaNode(Map<String, Object?> schema, List<String> at) {
  Map<String, Object?> node = schema;
  for (final String key in at) {
    node = node[key]! as Map<String, Object?>;
  }
  return node;
}

void main() {
  group('the editor and the sync-relay package agree', () {
    late final String model = _readLocal(_relayModel);
    late final String config = _readLocal(_relayConfig);

    String drift(String editorConstant, String relayConstant) =>
        '$editorConstant (lib/services/editor_sync.dart) and $relayConstant '
        '($_relayModel / $_relayConfig) describe the same wire limit and must '
        'hold the same value';

    test('document counts and id lengths match', () {
      expect(
        huiEditorSyncMaxDocuments,
        constantInt(model, 'relayMaximumDocuments'),
        reason: drift('huiEditorSyncMaxDocuments', 'relayMaximumDocuments'),
      );
      expect(
        huiEditorSyncMaxDocumentIdChars,
        constantInt(model, 'relayMaximumDocumentIdChars'),
        reason: drift(
          'huiEditorSyncMaxDocumentIdChars',
          'relayMaximumDocumentIdChars',
        ),
      );
      expect(
        huiEditorSyncMaxSafeInteger,
        constantInt(model, 'relayMaximumSafeInteger'),
        reason: drift('huiEditorSyncMaxSafeInteger', 'relayMaximumSafeInteger'),
      );
    });

    test('the protocol byte ceilings match', () {
      final int projectBytes = constantInt(
        config,
        'maximumProtocolProjectBytes',
      );
      final int envelopeBytes = constantInt(config, 'protocolEnvelopeBytes');
      expect(
        huiEditorSyncMaxProjectBytes,
        projectBytes,
        reason: drift(
          'huiEditorSyncMaxProjectBytes',
          'RelayConfig.maximumProtocolProjectBytes',
        ),
      );
      expect(
        huiEditorSyncMaxResponseEnvelopeBytes,
        envelopeBytes,
        reason: drift(
          'huiEditorSyncMaxResponseEnvelopeBytes',
          'RelayConfig.protocolEnvelopeBytes',
        ),
      );
      // The relay derives its request/response ceilings from the same two
      // numbers; keeping the derivation identical is the point of the pin.
      expect(huiEditorSyncMaxRequestBytes, projectBytes + envelopeBytes);
      expect(huiEditorSyncMaxResponseBytes, (projectBytes * 2) + envelopeBytes);
    });

    test('the kind and revision grammars match', () {
      expect(
        editorSyncKindPattern.pattern,
        stringLiteral(model, 'relayKindSlug'),
        reason: drift('editorSyncKindPattern', 'relayKindSlug'),
      );
      expect(
        editorSyncRevisionPattern.pattern,
        stringLiteral(model, 'relayRevisionPattern'),
        reason: drift('editorSyncRevisionPattern', 'relayRevisionPattern'),
      );
    });
  });

  group('the editor matches the Gloss sync classes', () {
    late final String documents = readGlossJava(
      '$_syncPackage/EditorSyncDocuments.java',
    );
    late final String snapshots = readGlossJava(
      '$_syncPackage/EditorSyncSnapshotBuilder.java',
    );
    late final String kinds = readGlossJava(
      '$_syncPackage/EditorSyncKind.java',
    );
    late final String project = readGlossJava(
      '$_syncPackage/EditorSyncProject.java',
    );
    late final String json = readGlossJava('$_syncPackage/EditorSyncJson.java');

    String drift(String editorConstant, String javaMember) =>
        '$editorConstant drifted from $javaMember; refresh '
        'lib/services/editor_sync.dart from the Gloss source — Gloss is the '
        'truth repo and the Java side is never edited to make this pass';

    test('the documents[] limits match EditorSyncDocuments', () {
      expect(
        huiEditorSyncMaxDocuments,
        constantInt(documents, 'MAX_DOCUMENTS'),
        reason: drift('huiEditorSyncMaxDocuments', 'MAX_DOCUMENTS'),
      );
      expect(
        huiEditorSyncMaxDocumentBytes,
        constantInt(documents, 'MAX_DOCUMENT_BYTES'),
        reason: drift('huiEditorSyncMaxDocumentBytes', 'MAX_DOCUMENT_BYTES'),
      );
      expect(
        huiEditorSyncMaxDocumentIdChars,
        constantInt(documents, 'MAX_DOCUMENT_ID_CHARS'),
        reason: drift(
          'huiEditorSyncMaxDocumentIdChars',
          'MAX_DOCUMENT_ID_CHARS',
        ),
      );
    });

    test('the snapshot budgets match EditorSyncSnapshotBuilder', () {
      expect(
        huiEditorSyncMaxMenus,
        constantInt(snapshots, 'MAX_MENU_COUNT'),
        reason: drift('huiEditorSyncMaxMenus', 'MAX_MENU_COUNT'),
      );
      expect(
        huiEditorSyncMaxImages,
        constantInt(snapshots, 'MAX_IMAGE_COUNT'),
        reason: drift('huiEditorSyncMaxImages', 'MAX_IMAGE_COUNT'),
      );
      expect(
        huiEditorSyncMaxImageDimension,
        constantInt(snapshots, 'MAX_IMAGE_DIMENSION'),
        reason: drift('huiEditorSyncMaxImageDimension', 'MAX_IMAGE_DIMENSION'),
      );
      expect(
        huiEditorSyncMaxImagePixels,
        constantInt(snapshots, 'MAX_IMAGE_PIXELS'),
        reason: drift('huiEditorSyncMaxImagePixels', 'MAX_IMAGE_PIXELS'),
      );
      expect(
        huiEditorSyncMaxAssetPixels,
        constantInt(snapshots, 'MAX_PROJECT_IMAGE_PIXELS'),
        reason: drift(
          'huiEditorSyncMaxAssetPixels',
          'MAX_PROJECT_IMAGE_PIXELS',
        ),
      );
      expect(
        huiEditorSyncMaxRenderPixels,
        constantInt(snapshots, 'MAX_PROJECT_IMAGE_PIXELS'),
        reason: drift(
          'huiEditorSyncMaxRenderPixels',
          'MAX_PROJECT_IMAGE_PIXELS',
        ),
      );
      expect(
        huiEditorSyncMaxRenderRows,
        constantInt(snapshots, 'MAX_PROJECT_IMAGE_ROWS'),
        reason: drift('huiEditorSyncMaxRenderRows', 'MAX_PROJECT_IMAGE_ROWS'),
      );
    });

    test('the wire identity matches EditorSyncJson', () {
      expect(
        huiEditorSyncProtocol,
        constantInt(json, 'PROTOCOL_VERSION'),
        reason: drift('huiEditorSyncProtocol', 'PROTOCOL_VERSION'),
      );
      expect(
        huiEditorSyncFormat,
        stringLiteral(json, 'PROJECT_FORMAT'),
        reason: drift('huiEditorSyncFormat', 'PROJECT_FORMAT'),
      );
    });

    test('the kind slug grammar matches EditorSyncKind', () {
      expect(
        editorSyncKindPattern.pattern,
        stringLiteral(kinds, 'WIRE_KIND_PATTERN'),
        reason: drift('editorSyncKindPattern', 'WIRE_KIND_PATTERN'),
      );
    });

    test('the revision grammar matches EditorSyncProject', () {
      // `String.matches` is implicitly anchored, so the Java literal carries no
      // `^`/`$` of its own.
      final RegExpMatch? matched = RegExp(
        r'baseRevision\.matches\("([^"]+)"\)',
      ).firstMatch(project);
      expect(
        matched,
        isNotNull,
        reason: 'EditorSyncProject no longer matches baseRevision inline',
      );
      expect(
        unanchoredPattern(editorSyncRevisionPattern.pattern),
        matched!.group(1),
        reason: drift('editorSyncRevisionPattern', 'EditorSyncProject'),
      );
    });
  });

  group('the relay schema states the same limits', () {
    late final Map<String, Object?> schema =
        jsonDecode(_readLocal(_relaySchema)) as Map<String, Object?>;
    late final Map<String, Object?> properties = _schemaNode(schema, <String>[
      'properties',
    ]);

    String drift(String pointer) =>
        '$pointer in $_relaySchema drifted from the shared sync-v2 limit';

    test('documents[] bounds match', () {
      final Map<String, Object?> documents = _schemaNode(properties, <String>[
        'documents',
      ]);
      expect(
        documents['maxItems'],
        huiEditorSyncMaxDocuments,
        reason: drift('documents.maxItems'),
      );
      final Map<String, Object?> entry = _schemaNode(documents, <String>[
        'items',
        'properties',
      ]);
      expect(
        (entry['id']! as Map<String, Object?>)['maxLength'],
        huiEditorSyncMaxDocumentIdChars,
        reason: drift('documents.items.id.maxLength'),
      );
      expect(
        (entry['json']! as Map<String, Object?>)['maxLength'],
        huiEditorSyncMaxDocumentBytes,
        reason: drift('documents.items.json.maxLength'),
      );
    });

    test('images[] and identity grammars match', () {
      expect(
        _schemaNode(properties, <String>['images'])['maxItems'],
        huiEditorSyncMaxImages,
        reason: drift('images.maxItems'),
      );
      // `kind` and `baseRevision` are $ref-ed shared definitions.
      final Map<String, Object?> defs = _schemaNode(schema, <String>[r'$defs']);
      expect(
        _schemaNode(defs, <String>['kindSlug'])['pattern'],
        editorSyncKindPattern.pattern,
        reason: drift(r'$defs.kindSlug.pattern'),
      );
      expect(
        _schemaNode(defs, <String>['revision'])['pattern'],
        editorSyncRevisionPattern.pattern,
        reason: drift(r'$defs.revision.pattern'),
      );
      expect(
        _schemaNode(properties, <String>['format'])['const'],
        huiEditorSyncFormat,
        reason: drift('format.const'),
      );
      expect(
        _schemaNode(properties, <String>['version'])['const'],
        huiEditorSyncProtocol,
        reason: drift('version.const'),
      );
    });
  });
}

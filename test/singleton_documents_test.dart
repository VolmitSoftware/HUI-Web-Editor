import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/model/gloss_doc.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:test/test.dart';

void main() {
  for (final GlossDocumentTypeAdapter type in <GlossDocumentTypeAdapter>[
    DocumentTypes.damageIndicators,
    DocumentTypes.entityOverlays,
    DocumentTypes.realDrops,
    DocumentTypes.motd,
    DocumentTypes.tablist,
  ]) {
    test('${type.syncWireKind} keeps one canonical, editable document', () {
      final EditorStore store = EditorStore(
        workspace: Workspace(autoLoad: false),
        autosaveDelay: Duration.zero,
      );
      addTearDown(store.dispose);
      store.newGlossDocument(type, name: 'custom');
      final String documentId = store.workspace.active!.id;
      expect(store.menuId, type.fixedRuntimeId);
      store.newGlossDocument(type);
      expect(store.workspace.active!.id, documentId);
      final GlossDoc template = type.newBlank()..revision = 42;
      store.newGlossDocument(type, from: template);
      expect(store.glossDoc!.revision, 42);
      expect(store.performUndo(), isTrue);
      expect(store.glossDoc!.revision, isNot(42));
      expect(store.duplicateDocument(documentId), isNull);
      expect(store.renameDocumentRuntimeId(documentId, 'duplicate'), isFalse);
      store.importJsonAsNewDocument('imported.json', type.encodeDoc(template));
      expect(store.workspace.active!.id, documentId);
      expect(store.glossDoc!.revision, 42);
      expect(
        store.workspace.docs.where((WorkspaceDoc doc) => doc.kind == type.kind),
        hasLength(1),
      );
    });
  }
}

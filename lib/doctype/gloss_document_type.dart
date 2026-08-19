/// Shared behavior of the Gloss document kinds (hologram, animation,
/// scoreboard).
///
/// The three kinds are structurally alike — a versioned envelope document
/// with a runtime id, canonical-text JSON, snapshot-driven undo and no
/// source preservation — so everything [EditorStore] needs from them funnels
/// through this base and its four codec primitives. A concrete kind adds its
/// model, its validation, its surface and its templates.
library;

import '../config/defaults.dart' show sanitizeMenuId;
import '../model/model.dart';
import '../state/editor_store.dart';
import '../state/workspace.dart';
import 'document_type.dart';

/// Base adapter for the Gloss kinds. The store's generic code paths
/// (`applyCode`, import routing, creation) type-test against this instead of
/// enumerating kinds.
abstract class GlossDocumentTypeAdapter extends DocumentTypeAdapter {
  const GlossDocumentTypeAdapter();

  /// Decodes runtime JSON into this kind's model. Throws [HuiFormatException]
  /// for malformed JSON or an unsupported `schemaVersion`; everything else is
  /// lenient and left to [validate].
  GlossDoc decodeDoc(String json);

  /// The model re-encoded in the editor's canonical text style.
  String encodeDoc(GlossDoc doc);

  /// A fresh default document — the kind's blank template.
  GlossDoc newBlank();

  /// Routing check for import auto-detection and the code editor's shape
  /// refusal: does decoded JSON look like this kind?
  bool looksLike(Object? decoded);

  /// The code-view message when pasted JSON is not this kind's shape.
  String get codeShapeError;

  /// Title/runtime id a fresh document starts under.
  String get defaultDocumentName;

  @override
  bool get hasRuntimeId => true;

  @override
  bool get transferable => true;

  @override
  bool get undoable => true;

  @override
  bool get sourcePreserving => false;

  @override
  void createNew(EditorStore store, {String? folderId, String? runtimeId}) =>
      store.newGlossDocument(
        this,
        name: runtimeId ?? defaultDocumentName,
        folderId: folderId,
      );

  @override
  AdoptedDocument adopt(WorkspaceDoc doc) {
    final String editorId = sanitizeMenuId(doc.runtimeId!);
    try {
      return AdoptedDocument(editorId: editorId, model: decodeDoc(doc.json));
    } on HuiFormatException catch (e) {
      return AdoptedDocument(
        editorId: editorId,
        model: newBlank(),
        failure:
            'The saved document "${doc.title}" was unreadable '
            '(${e.message}) and was replaced with a blank $noun.',
      );
    } catch (_) {
      return AdoptedDocument(
        editorId: editorId,
        model: newBlank(),
        failure:
            'The saved document "${doc.title}" was unreadable and was '
            'replaced with a blank $noun.',
      );
    }
  }

  @override
  Object decodeSnapshot(String snapshot) => decodeDoc(snapshot);

  @override
  String snapshot(DocumentStateView state) => encodeDoc(state.glossDoc!);

  @override
  String exportJson(DocumentStateView state) => snapshot(state);

  @override
  String formattedJson(DocumentStateView state) => snapshot(state);

  @override
  MenuRenameRewrite rewriteForMenuRename(
    WorkspaceDoc doc,
    String previous,
    String next,
  ) => MenuRenameRewrite.none;
}

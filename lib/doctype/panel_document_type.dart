library;

import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneIcon, IconSize, Widget;

import '../logic/validation.dart' show HuiIssue;
import '../state/editor_store.dart';
import '../state/workspace.dart';
import '../state/workspace_panel.dart';
import 'document_type.dart';

/// The world-panel document: a flow map over the workspace's menus plus the
/// linked runtime panel definition. Editor-only metadata — its JSON lives in
/// the workspace record and is written through [EditorStore.updatePanel],
/// outside the snapshot/undo path.
final class PanelDocumentType extends DocumentTypeAdapter {
  const PanelDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.panel;

  @override
  String get noun => 'flow map';

  @override
  String get createLabel => 'New menu flow map';

  @override
  List<EditorView> get availableViews => const <EditorView>[EditorView.panel];

  @override
  bool get hasRuntimeId => false;

  @override
  bool get transferable => false;

  @override
  bool get undoable => false;

  @override
  bool get sourcePreserving => false;

  @override
  String? get syncWireKind => 'panel';

  @override
  Widget railIcon() => ArcaneIcon.workflow(size: IconSize.sm);

  @override
  void createNew(EditorStore store, {String? folderId, String? runtimeId}) =>
      store.newPanelDocument(
        name: 'Menu flow map',
        folderId: folderId,
        scopeFolderId: folderId,
      );

  @override
  AdoptedDocument adopt(WorkspaceDoc doc) =>
      AdoptedDocument(editorId: doc.title);

  @override
  Object decodeSnapshot(String snapshot) => throw StateError(
    'Panel metadata does not use the runtime snapshot path.',
  );

  @override
  String snapshot(DocumentStateView state) => throw StateError(
    'Panel metadata does not use the runtime snapshot path.',
  );

  @override
  String exportJson(DocumentStateView state) =>
      throw StateError('Panel metadata is editor-only and cannot be exported.');

  @override
  String formattedJson(DocumentStateView state) => throw StateError(
    'Panel metadata is editor-only and cannot be formatted.',
  );

  @override
  List<HuiIssue> validate(DocumentStateView state) => const <HuiIssue>[];

  @override
  MenuRenameRewrite rewriteForMenuRename(
    WorkspaceDoc doc,
    String previous,
    String next,
  ) {
    final WorkspacePanelDecodeResult decoded = decodeWorkspacePanel(doc.json);
    if (decoded.warning != null) {
      return MenuRenameRewrite(
        failure:
            'Cannot safely rename while menu flow map "${doc.title}" is unreadable.',
      );
    }
    final Map<String, dynamic>? runtimeBoard = decoded.data.runtimeBoard;
    final bool rootChanged = runtimeBoard?['rootMenuId'] == previous;
    final List<String> syncMenuIds = <String>[
      for (final String menuId in decoded.data.syncMenuIds)
        menuId == previous ? next : menuId,
    ];
    final bool syncChanged = !_sameStrings(
      syncMenuIds,
      decoded.data.syncMenuIds,
    );
    if (!rootChanged && !syncChanged) return MenuRenameRewrite.none;
    final Map<String, dynamic>? changedBoard = runtimeBoard == null
        ? null
        : <String, dynamic>{
            ...runtimeBoard,
            if (rootChanged) 'rootMenuId': next,
          };
    return MenuRenameRewrite(
      json: encodeWorkspacePanel(
        decoded.data.copyWith(
          runtimeBoard: changedBoard,
          syncMenuIds: syncMenuIds,
        ),
      ),
      panelRoots: rootChanged ? 1 : 0,
    );
  }

  static bool _sameStrings(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (int index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}

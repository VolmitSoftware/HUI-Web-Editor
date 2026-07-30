/// Every command the shell can run, in one place.
///
/// The top bar, the command palette and the keyboard binder all call these
/// methods, so a shortcut and its button can never diverge. Dialogs owned by
/// other modules arrive as optional callbacks; when one is absent the intent
/// falls back to the direct store/service path so the editor stays usable.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../../model/model.dart';
import '../../services/clipboard.dart';
import '../../services/file_transfer.dart';
import '../../state/editor_store.dart';
import '../../state/workspace.dart';

class ShellIntents {
  ShellIntents({
    required this.store,
    required this.requestDeleteSelected,
    required this.openPalette,
    this.onOpenImport,
    this.onOpenExport,
    this.onOpenImages,
    this.onOpenTemplates,
    this.onOpenHelp,
    this.onOpenSettings,
    this.onOpenValidation,
    this.onToggleTheme,
  });

  final EditorStore store;

  /// Arms the shell's confirm dialog rather than deleting immediately.
  final void Function() requestDeleteSelected;
  final void Function() openPalette;

  final void Function()? onOpenImport;
  final void Function()? onOpenExport;
  final void Function()? onOpenImages;
  final void Function()? onOpenTemplates;
  final void Function()? onOpenHelp;
  final void Function()? onOpenSettings;
  final void Function()? onOpenValidation;
  final void Function()? onToggleTheme;

  // --- history --------------------------------------------------------------

  void undo() {
    if (!store.canUndo) {
      ArcaneSonner.info('Nothing to undo.');
      return;
    }
    final String? label = store.undoLabel;
    store.performUndo();
    ArcaneSonner.info(label == null ? 'Undone.' : 'Undid $label.');
  }

  void redo() {
    if (!store.canRedo) {
      ArcaneSonner.info('Nothing to redo.');
      return;
    }
    final String? label = store.redoLabel;
    store.performRedo();
    ArcaneSonner.info(label == null ? 'Redone.' : 'Redid $label.');
  }

  // --- transfer -------------------------------------------------------------

  Future<void> copyJson() async {
    final bool copied = await copyText(store.exportJson());
    if (copied) {
      ArcaneSonner.success('Menu JSON copied to the clipboard.');
    } else {
      ArcaneSonner.error(
        'The browser refused clipboard access. Use Export to download the '
        'file instead.',
      );
    }
  }

  Future<void> importMenu() async {
    final void Function()? dialog = onOpenImport;
    if (dialog != null) {
      dialog();
      return;
    }
    final (String, String)? picked = await pickJsonFile();
    if (picked == null) return;
    store.importJson(picked.$1, picked.$2);
  }

  void exportMenu() {
    final void Function()? dialog = onOpenExport;
    if (dialog != null) {
      dialog();
      return;
    }
    downloadText(store.exportFileName, store.exportJson());
    ArcaneSonner.success('Saved ${store.exportFileName}.');
  }

  // --- documents ------------------------------------------------------------

  void newDocument() {
    store.newDocument();
    ArcaneSonner.success('Started a new menu.');
  }

  void openDocument(String docId) {
    if (!store.openDocument(docId)) {
      ArcaneSonner.error('That document is no longer available.');
    }
  }

  void deleteActiveDocument() {
    final WorkspaceDoc? active = store.workspace.active;
    if (active == null) return;
    final String name = active.name;
    if (store.deleteDocument(active.id)) {
      ArcaneSonner.success('Deleted $name.');
    }
  }

  // --- components -----------------------------------------------------------

  void addComponent(String type) {
    final String? id = store.addComponent(type);
    if (id != null) ArcaneSonner.success('Added $id.');
  }

  void duplicateSelected() {
    final String? id = store.selectedId;
    if (id == null) {
      ArcaneSonner.info('Select a component first.');
      return;
    }
    store.duplicateComponent(id);
  }

  /// Arms the confirm dialog; the actual delete runs in [deleteSelectedNow].
  void deleteSelected() {
    if (store.selectedId == null) {
      ArcaneSonner.info('Select a component first.');
      return;
    }
    requestDeleteSelected();
  }

  void deleteSelectedNow() {
    final String? id = store.selectedId;
    if (id == null) return;
    store.deleteComponent(id);
    ArcaneSonner.success('Deleted $id.');
  }

  void deselect() => store.select(null);

  /// Arrow-key nudge in blocks; the store snaps the result to the grid.
  void nudgeSelected(double dx, double dy) {
    final String? id = store.selectedId;
    if (id == null) return;
    store.moveComponent(id, Vec3(dx, dy, 0));
  }

  // --- view -----------------------------------------------------------------

  void setView(EditorView view) => store.view = view;

  void toggleGrid() => store.showGrid = !store.showGrid;

  void toggleSnap() => store.snapToGrid = !store.snapToGrid;

  void toggleHitboxes() => store.showHitboxes = !store.showHitboxes;

  void toggleAnchors() => store.showAnchors = !store.showAnchors;

  void toggleTrueRender() => store.trueRender = !store.trueRender;

  void toggleTheme() => onToggleTheme?.call();

  // --- panels ---------------------------------------------------------------

  void openValidation() {
    final void Function()? panel = onOpenValidation;
    if (panel == null) {
      ArcaneSonner.info('The validation panel is not available yet.');
      return;
    }
    panel();
  }

  void openImages() => _openOr(onOpenImages, 'The image manager');

  void openTemplates() => _openOr(onOpenTemplates, 'Templates');

  void openHelp() => _openOr(onOpenHelp, 'Help');

  void openSettings() => _openOr(onOpenSettings, 'Settings');

  void _openOr(void Function()? open, String what) {
    if (open == null) {
      ArcaneSonner.info('$what is not available yet.');
      return;
    }
    open();
  }
}

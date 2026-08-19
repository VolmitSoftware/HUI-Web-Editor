/// Every command the shell can run, in one place.
///
/// The top bar, the command palette and the keyboard binder all call these
/// methods, so a shortcut and its button can never diverge. Dialogs owned by
/// other modules arrive as optional callbacks; when one is absent the intent
/// falls back to the direct store/service path so the editor stays usable.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../../logic/canvas_scene.dart';
import '../../logic/multi_select.dart';
import '../../model/model.dart';
import '../../services/clipboard.dart';
import '../../config/editing.dart';
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

  /// Align and distribute resolve the same frame the canvas draws, so they need
  /// the same memos: without them every command re-parses every label and
  /// re-scans every decoded image. The shell holds one `ShellIntents` per
  /// store, so these live as long as the document does.
  final McTextCache _textCache = McTextCache();
  final ImageCharCache _charCache = ImageCharCache();

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
    if (!store.canTransferDocument) {
      ArcaneSonner.info(
        'Menu flow maps are editor-only and are not runtime JSON.',
      );
      return;
    }
    final bool copied = await copyText(store.exportJson());
    if (copied) {
      ArcaneSonner.success('$_documentLabel JSON copied to the clipboard.');
    } else {
      ArcaneSonner.error(
        'The browser refused clipboard access. Use Export to download the '
        'file instead.',
      );
    }
  }

  Future<void> importMenu() async {
    if (!store.canTransferDocument) {
      ArcaneSonner.info('Open a menu or preview document before importing.');
      return;
    }
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
    if (!store.canTransferDocument) {
      ArcaneSonner.info('Menu flow maps are editor-only and are not exported.');
      return;
    }
    final void Function()? dialog = onOpenExport;
    if (dialog != null) {
      dialog();
      return;
    }
    downloadText(store.exportFileName, store.exportJson());
    ArcaneSonner.success('Saved ${store.exportFileName}.');
  }

  String get _documentLabel => store.isPreviewDoc ? 'Preview' : 'Menu';

  // --- documents ------------------------------------------------------------

  void newDocument() {
    if (store.newDocument()) {
      ArcaneSonner.success('Started a new menu.');
    }
  }

  void openDocument(String docId) {
    if (!store.openDocument(docId)) {
      ArcaneSonner.error('That document is no longer available.');
    }
  }

  void deleteActiveDocument() {
    final WorkspaceDoc? active = store.workspace.active;
    if (active == null) return;
    final String name = active.title;
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
    final List<String> ids = _selectedIds();
    if (ids.isEmpty) {
      ArcaneSonner.info('Select a component first.');
      return;
    }
    if (ids.length == 1) {
      store.duplicateComponent(ids.first);
      return;
    }
    // `duplicateSelection` lands the copies exactly on their sources — it is
    // built for alt-drag, where a placement nudge would fight the gesture. From
    // a command there is no gesture to follow, so the toast has to say where
    // they went or the menu looks unchanged.
    final List<String> created = store.duplicateSelection();
    if (created.isEmpty) return;
    ArcaneSonner.success(
      'Duplicated ${created.length} components on top of the originals.',
    );
  }

  /// Arms the confirm dialog; the actual delete runs in [deleteSelectedNow].
  void deleteSelected() {
    if (store.selectionIds.isEmpty) {
      ArcaneSonner.info('Select a component first.');
      return;
    }
    requestDeleteSelected();
  }

  void deleteSelectedNow() {
    final List<String> ids = _selectedIds();
    if (ids.isEmpty) return;
    // One store call, one undo step, labelled by count. The per-id loop this
    // replaced left the history reading `delete <first id>` after deleting
    // three, because the drag bracket pushes only the first change.
    store.deleteComponents(ids);
    ArcaneSonner.success(
      ids.length == 1
          ? 'Deleted ${ids.first}.'
          : 'Deleted ${ids.length} components.',
    );
  }

  void deselect() => store.select(null);

  void selectAll() {
    if (store.components.isEmpty) {
      ArcaneSonner.info('This menu has no components yet.');
      return;
    }
    store.selectAll();
  }

  /// Arrow-key nudge in blocks; the store snaps the result to the grid.
  void nudgeSelected(double dx, double dy) {
    final HuiComponent? lead = store.selected;
    if (lead == null) return;
    if (store.selectionIds.length == 1) {
      store.moveComponent(lead.id, Vec3(dx, dy, 0));
      return;
    }
    // Snap the primary and apply ITS delta to the rest, exactly as a group drag
    // does. Snapping each member on its own would pull an off-grid group onto
    // the grid one arrow press at a time and destroy the spacing.
    final double snappedX = dx == 0
        ? lead.offset.x
        : store.snapValue(lead.offset.x + dx);
    final double snappedY = dy == 0
        ? lead.offset.y
        : store.snapValue(lead.offset.y + dy);
    final double stepX = snappedX - lead.offset.x;
    final double stepY = snappedY - lead.offset.y;
    if (stepX == 0 && stepY == 0) return;
    final Map<String, Vec3> offsets = <String, Vec3>{
      for (final HuiComponent component in store.selectedComponents)
        component.id: Vec3(
          _round(component.offset.x + stepX),
          _round(component.offset.y + stepY),
          component.offset.z,
        ),
    };
    store.setOffsets('nudge ${offsets.length} components', offsets);
  }

  // --- arrangement ----------------------------------------------------------

  /// Flushes the selection against its own bounding box. Below two components
  /// there is no box to flush against, and silently doing nothing reads as a
  /// broken command, so the guard says so.
  void alignSelection(HuiAlign align) {
    final List<String> ids = _selectedIds();
    if (ids.length < 2) {
      ArcaneSonner.info('Select at least two components to align them.');
      return;
    }
    final Map<String, Vec3> offsets = alignOffsets(
      scene: _scene(),
      ids: ids,
      align: align,
    );
    if (offsets.isEmpty) return;
    store.setOffsets('align ${_alignLabel(align)}', offsets);
    ArcaneSonner.success(
      'Aligned ${offsets.length} components ${_alignLabel(align)}.',
    );
  }

  /// Equal gaps between the outer two components. Two components already have
  /// exactly one gap, so there is nothing to equalise below three.
  void distributeSelection(HuiAxis axis) {
    final List<String> ids = _selectedIds();
    if (ids.length < 3) {
      ArcaneSonner.info('Select at least three components to distribute them.');
      return;
    }
    final Map<String, Vec3> offsets = distributeOffsets(
      scene: _scene(),
      ids: ids,
      axis: axis,
    );
    if (offsets.isEmpty) return;
    final String direction = axis == HuiAxis.horizontal
        ? 'horizontally'
        : 'vertically';
    store.setOffsets('distribute $direction', offsets);
    ArcaneSonner.success(
      'Spaced ${offsets.length} components evenly $direction.',
    );
  }

  /// Restacks the selection in draw order. `toFront`/`toBack` move the group
  /// past the nearest unselected component, so with everything selected there
  /// is nothing to move past and the operation is a genuine no-op.
  void reorderDepth(HuiZOrder op) {
    final Set<String> ids = store.selectionIds;
    if (ids.isEmpty) {
      ArcaneSonner.info('Select a component first.');
      return;
    }
    final Map<String, Vec3> offsets = zOrderOffsets(
      items: _scene().items,
      ids: ids,
      op: op,
      step: huiDepthStep,
    );
    if (offsets.isEmpty) {
      ArcaneSonner.info(
        ids.length >= store.components.length
            ? 'Every component is selected, so there is nothing to move past.'
            : 'Nothing to restack.',
      );
      return;
    }
    // One label per operation, so a run of presses coalesces into one undo
    // step the way a run of nudges does.
    store.setOffsets(_depthLabel(op), offsets);
  }

  /// Document order, which is what align, distribute and delete all want: the
  /// selection is insertion-ordered and the order the user clicked in is not a
  /// property of the layout.
  List<String> _selectedIds() => <String>[
    for (final HuiComponent component in store.selectedComponents) component.id,
  ];

  /// The frame the canvas is showing right now — same uiScale, same
  /// `trueRender` — so aligning flushes the edges the user can actually see.
  /// The store's own validation scene is fixed at uiScale 1 and is not it.
  CanvasScene _scene() => buildCanvasScene(
    menu: store.menu,
    uiScale: store.previewUiScale,
    trueRender: store.trueRender,
    togglePreview: store.togglePreviewFor,
    textCache: _textCache,
    images: store.images,
    catalogs: store.catalogs,
    charCache: _charCache,
    emoji: store.workspaceEmoji,
  );

  /// `EditorStore._round` — four decimals, so exported JSON stays stable.
  double _round(double value) =>
      !value.isFinite ? 0 : (value * 10000).roundToDouble() / 10000;

  String _alignLabel(HuiAlign align) => switch (align) {
    HuiAlign.left => 'left',
    HuiAlign.centerX => 'centred',
    HuiAlign.right => 'right',
    HuiAlign.top => 'top',
    HuiAlign.middleY => 'middle',
    HuiAlign.bottom => 'bottom',
  };

  String _depthLabel(HuiZOrder op) => switch (op) {
    HuiZOrder.forward => 'bring forward',
    HuiZOrder.backward => 'send back',
    HuiZOrder.toFront => 'bring to front',
    HuiZOrder.toBack => 'send to back',
  };

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

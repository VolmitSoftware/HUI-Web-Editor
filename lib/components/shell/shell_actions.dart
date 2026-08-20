/// The command registry behind the palette.
///
/// Built fresh every time the palette opens so labels reflect live state
/// ("Show grid" vs "Hide grid") and the document list is current.
///
/// Shortcut chips are never written here: they are read out of the one
/// shortcut table by action id (`shortcut_sheet.dart`), which is the same
/// declaration the document binder dispatches from. A chip in the palette is
/// therefore the chord that actually runs, by construction.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../../doctype/doctype.dart';
import '../../logic/multi_select.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../../state/workspace.dart';
import 'shell_intents.dart';
import 'shortcut_sheet.dart';

class ShellAction {
  ShellAction({
    required this.id,
    required this.group,
    required this.label,
    required this.run,
    this.icon,
    this.shortcut,
    this.keywords = const <String>[],
    this.enabled = true,
  });

  final String id;

  /// Palette heading. Insertion order of the first action decides group order.
  final String group;
  final String label;
  final void Function() run;
  final Widget? icon;

  /// Platform-neutral spec such as `mod+Shift+Z`, rendered per platform.
  final String? shortcut;
  final List<String> keywords;
  final bool enabled;

  String get haystack => '$label ${keywords.join(' ')} $group'.toLowerCase();
}

const String shellGroupFile = 'File';
const String shellGroupEdit = 'Edit';
const String shellGroupSelection = 'Selection';
const String shellGroupAdd = 'Add component';
const String shellGroupView = 'View';
const String shellGroupCanvas = 'Canvas';
const String shellGroupHelp = 'Help';
const String shellGroupLibrary = 'Library';
const String shellGroupDocuments = 'Documents';

/// [onShowShortcuts] and [onReplayTour] are shell-owned overlays the intents
/// layer has no handle on; their commands are omitted when the shell does not
/// supply them rather than being listed and dead.
List<ShellAction> buildShellActions(
  ShellIntents intents, {
  void Function()? onShowShortcuts,
  void Function()? onReplayTour,
}) {
  final EditorStore store = intents.store;
  final int selected = store.selectionIds.length;
  final String documentNoun = store.docType.noun;
  final List<ShellAction> actions = <ShellAction>[
    ShellAction(
      id: 'file.new',
      group: shellGroupFile,
      label: 'New menu',
      icon: ArcaneIcon.filePlus(size: IconSize.sm),
      keywords: const <String>['document', 'blank', 'create'],
      run: intents.newDocument,
    ),
    ShellAction(
      id: 'file.import',
      group: shellGroupFile,
      label: 'Import JSON',
      icon: ArcaneIcon.upload(size: IconSize.sm),
      keywords: <String>['open', 'load', 'file', documentNoun],
      enabled: store.canTransferDocument,
      run: () => intents.importMenu(),
    ),
    ShellAction(
      id: 'file.export',
      group: shellGroupFile,
      label: 'Export $documentNoun JSON',
      icon: ArcaneIcon.download(size: IconSize.sm),
      shortcut: huiShortcutSpec('file.export'),
      keywords: const <String>['save', 'download', 'json'],
      enabled: store.canTransferDocument,
      run: intents.exportMenu,
    ),
    ShellAction(
      id: 'file.copy',
      group: shellGroupFile,
      label: 'Copy $documentNoun JSON',
      icon: ArcaneIcon.copy(size: IconSize.sm),
      keywords: const <String>['clipboard'],
      enabled: store.canTransferDocument,
      run: () => intents.copyJson(),
    ),
    ShellAction(
      id: 'file.templates',
      group: shellGroupFile,
      label: 'Browse templates',
      icon: ArcaneIcon.layoutTemplate(size: IconSize.sm),
      keywords: const <String>['starter', 'example', 'preset'],
      run: intents.openTemplates,
    ),
    ShellAction(
      id: 'file.images',
      group: shellGroupFile,
      label: 'Manage images',
      icon: ArcaneIcon.images(size: IconSize.sm),
      keywords: const <String>['upload', 'texture', 'library', 'zip'],
      run: intents.openImages,
    ),
    ShellAction(
      id: 'edit.undo',
      group: shellGroupEdit,
      label: store.undoLabel == null ? 'Undo' : 'Undo ${store.undoLabel}',
      icon: ArcaneIcon.undo(size: IconSize.sm),
      shortcut: huiShortcutSpec('edit.undo'),
      enabled: store.canUndo,
      run: intents.undo,
    ),
    ShellAction(
      id: 'edit.redo',
      group: shellGroupEdit,
      label: store.redoLabel == null ? 'Redo' : 'Redo ${store.redoLabel}',
      icon: ArcaneIcon.redo(size: IconSize.sm),
      shortcut: huiShortcutSpec('edit.redo'),
      enabled: store.canRedo,
      run: intents.redo,
    ),
    ShellAction(
      id: 'edit.duplicate',
      group: shellGroupEdit,
      label: 'Duplicate ${_selectionNoun(selected)}',
      icon: ArcaneIcon.copy(size: IconSize.sm),
      shortcut: huiShortcutSpec('edit.duplicate'),
      enabled: selected > 0,
      run: intents.duplicateSelected,
    ),
    ShellAction(
      id: 'edit.delete',
      group: shellGroupEdit,
      label: 'Delete ${_selectionNoun(selected)}',
      icon: ArcaneIcon.trash2(size: IconSize.sm),
      shortcut: huiShortcutSpec('edit.delete'),
      enabled: selected > 0,
      run: intents.deleteSelected,
    ),
    ShellAction(
      id: 'edit.deselect',
      group: shellGroupEdit,
      label: selected > 1 ? 'Deselect all' : 'Deselect',
      icon: ArcaneIcon.x(size: IconSize.sm),
      shortcut: huiShortcutSpec('edit.deselect'),
      enabled: selected > 0,
      run: intents.deselect,
    ),
    ShellAction(
      id: 'selection.all',
      group: shellGroupSelection,
      label: 'Select all components',
      icon: ArcaneIcon.listChecks(size: IconSize.sm),
      shortcut: huiShortcutSpec('selection.all'),
      keywords: const <String>['every', 'everything', 'multi'],
      enabled: store.components.isNotEmpty,
      run: intents.selectAll,
    ),
    // Every arrangement command is enabled on any selection, not on a large
    // enough one. The palette hides disabled actions outright, so gating align
    // at two would hide it exactly when the user is looking for it and would
    // never say why; the intents' guard toast names the requirement instead.
    for (final (String id, String label, HuiAlign align, Widget icon)
        in _alignments)
      ShellAction(
        id: 'selection.align.$id',
        group: shellGroupSelection,
        label: label,
        icon: icon,
        keywords: const <String>['align', 'flush', 'edge', 'arrange'],
        enabled: selected > 0,
        run: () => intents.alignSelection(align),
      ),
    ShellAction(
      id: 'selection.distribute.horizontal',
      group: shellGroupSelection,
      label: 'Distribute horizontally',
      icon: ArcaneIcon.alignHorizontalDistributeCenter(size: IconSize.sm),
      keywords: const <String>['space', 'even', 'gap', 'arrange'],
      enabled: selected > 0,
      run: () => intents.distributeSelection(HuiAxis.horizontal),
    ),
    ShellAction(
      id: 'selection.distribute.vertical',
      group: shellGroupSelection,
      label: 'Distribute vertically',
      icon: ArcaneIcon.alignVerticalDistributeCenter(size: IconSize.sm),
      keywords: const <String>['space', 'even', 'gap', 'arrange'],
      enabled: selected > 0,
      run: () => intents.distributeSelection(HuiAxis.vertical),
    ),
    // Depth only decides which icon draws over which; click dispatch stays in
    // rail order. "To front" and "to back" move the selection past the nearest
    // unselected component, so with everything selected they are no-ops — and
    // again the toast, not a hidden row, is what says so.
    for (final (String id, String label, HuiZOrder op, Widget icon) in _depths)
      ShellAction(
        id: 'selection.$id',
        group: shellGroupSelection,
        label: label,
        icon: icon,
        keywords: const <String>['depth', 'z', 'draw order', 'stack', 'layer'],
        enabled: selected > 0,
        run: () => intents.reorderDepth(op),
      ),
    for (final String type in huiComponentTypes)
      ShellAction(
        id: 'add.$type',
        group: shellGroupAdd,
        label: 'Add ${_typeLabel(type)}',
        icon: ArcaneIcon.plus(size: IconSize.sm),
        keywords: <String>[type, 'component', 'new'],
        enabled: store.isMenuDoc,
        run: () => intents.addComponent(type),
      ),
    // The four modes are offered for every kind; a kind that cannot serve one
    // has it listed disabled, and the switcher's tooltip carries the reason.
    ShellAction(
      id: 'view.visual',
      group: shellGroupView,
      label: 'Visual mode (${store.docType.surfaceLabel})',
      icon: ArcaneIcon.eye(size: IconSize.sm),
      shortcut: huiShortcutSpec('view.visual'),
      keywords: const <String>['surface', 'editor', 'design'],
      enabled: store.docType.supportsView(EditorView.visual),
      run: () => intents.setView(EditorView.visual),
    ),
    ShellAction(
      id: 'view.preview',
      group: shellGroupView,
      label: 'Preview mode',
      icon: ArcaneIcon.rotate3d(size: IconSize.sm),
      shortcut: huiShortcutSpec('view.preview'),
      keywords: const <String>['3d', 'player', 'simulate', 'stage', 'in game'],
      enabled: store.docType.supportsView(EditorView.preview),
      run: () => intents.setView(EditorView.preview),
    ),
    ShellAction(
      id: 'view.code',
      group: shellGroupView,
      label: 'Code mode',
      icon: ArcaneIcon.code(size: IconSize.sm),
      shortcut: huiShortcutSpec('view.code'),
      keywords: const <String>['json', 'text'],
      enabled: store.docType.supportsView(EditorView.code),
      run: () => intents.setView(EditorView.code),
    ),
    ShellAction(
      id: 'view.split',
      group: shellGroupView,
      label: 'Split mode',
      icon: ArcaneIcon.layers(size: IconSize.sm),
      shortcut: huiShortcutSpec('view.split'),
      keywords: const <String>['side by side', 'json'],
      enabled: store.docType.supportsView(EditorView.split),
      run: () => intents.setView(EditorView.split),
    ),
    ShellAction(
      id: 'view.theme',
      group: shellGroupView,
      label: 'Toggle light / dark theme',
      icon: ArcaneIcon.sun(size: IconSize.sm),
      keywords: const <String>['dark', 'light', 'appearance'],
      run: intents.toggleTheme,
    ),
    ShellAction(
      id: 'canvas.grid',
      group: shellGroupCanvas,
      label: store.showGrid ? 'Hide block grid' : 'Show block grid',
      icon: ArcaneIcon.grid3x3(size: IconSize.sm),
      enabled: store.isMenuDoc,
      run: intents.toggleGrid,
    ),
    ShellAction(
      id: 'canvas.snap',
      group: shellGroupCanvas,
      label: store.snapToGrid ? 'Disable snapping' : 'Enable snapping',
      icon: ArcaneIcon.magnet(size: IconSize.sm),
      keywords: const <String>['grid', 'align'],
      enabled: store.isMenuDoc,
      run: intents.toggleSnap,
    ),
    ShellAction(
      id: 'canvas.hitboxes',
      group: shellGroupCanvas,
      label: store.showHitboxes ? 'Hide hitboxes' : 'Show hitboxes',
      icon: ArcaneIcon.square(size: IconSize.sm),
      keywords: const <String>['click', 'bounds'],
      enabled: store.isMenuDoc,
      run: intents.toggleHitboxes,
    ),
    ShellAction(
      id: 'canvas.anchors',
      group: shellGroupCanvas,
      label: store.showAnchors ? 'Hide anchors' : 'Show anchors',
      icon: ArcaneIcon.mousePointer(size: IconSize.sm),
      keywords: const <String>['offset', 'origin'],
      enabled: store.isMenuDoc,
      run: intents.toggleAnchors,
    ),
    ShellAction(
      id: 'canvas.trueRender',
      group: shellGroupCanvas,
      label: store.trueRender
          ? 'Show authored positions'
          : 'Show true in-game positions',
      icon: ArcaneIcon.maximize(size: IconSize.sm),
      keywords: const <String>['bias', 'offset', 'display entity'],
      enabled: store.isMenuDoc,
      run: intents.toggleTrueRender,
    ),
    ShellAction(
      id: 'help.validation',
      group: shellGroupHelp,
      label: 'Show validation issues',
      icon: ArcaneIcon.triangleAlert(size: IconSize.sm),
      keywords: const <String>['errors', 'warnings', 'problems'],
      enabled: !store.isPanelDoc,
      run: intents.openValidation,
    ),
    ShellAction(
      id: 'help.help',
      group: shellGroupHelp,
      label: 'Help and formatting reference',
      icon: ArcaneIcon.circleQuestionMark(size: IconSize.sm),
      keywords: const <String>['docs', 'guide', 'colours', 'minimessage'],
      run: intents.openHelp,
    ),
    if (onShowShortcuts != null)
      ShellAction(
        id: 'help.shortcuts',
        group: shellGroupHelp,
        label: 'Keyboard shortcuts',
        icon: ArcaneIcon.keyboard(size: IconSize.sm),
        shortcut: huiShortcutSpec('help.shortcuts'),
        keywords: const <String>['keys', 'chord', 'binding', 'cheat sheet'],
        run: onShowShortcuts,
      ),
    if (onReplayTour != null)
      ShellAction(
        id: 'help.tour',
        group: shellGroupHelp,
        label: 'Replay the guided tour',
        icon: ArcaneIcon.compass(size: IconSize.sm),
        keywords: const <String>['onboarding', 'intro', 'walkthrough', 'first'],
        run: onReplayTour,
      ),
    ShellAction(
      id: 'help.settings',
      group: shellGroupHelp,
      label: 'Settings',
      icon: ArcaneIcon.settings(size: IconSize.sm),
      keywords: const <String>['preferences', 'reset'],
      run: intents.openSettings,
    ),
  ];

  // Library scope. The tab strip is the pointer route; these are the same
  // switches by name, which is what makes the mode reachable from the keyboard
  // without spending a chord on each of ten kinds.
  actions.add(
    ShellAction(
      id: 'library.mode.all',
      group: shellGroupLibrary,
      label: 'Show all documents',
      icon: ArcaneIcon.layoutList(size: IconSize.sm),
      keywords: const <String>['mode', 'filter', 'scope', 'library'],
      enabled: store.mode != null,
      run: () => intents.setMode(null),
    ),
  );
  for (final DocumentTypeAdapter type in DocumentTypeRegistry.tabs) {
    actions.add(
      ShellAction(
        id: 'library.mode.${type.kind.name}',
        group: shellGroupLibrary,
        label: 'Show only ${type.pluralLabel.toLowerCase()}',
        icon: type.tabIcon(),
        keywords: <String>['mode', 'filter', 'scope', type.noun],
        enabled: !identical(store.mode, type),
        run: () => intents.setMode(type),
      ),
    );
  }

  final String? activeId = store.workspace.activeId;
  for (final WorkspaceDoc doc in store.workspace.recent) {
    if (doc.id == activeId) continue;
    actions.add(
      ShellAction(
        id: 'doc.${doc.id}',
        group: shellGroupDocuments,
        label: 'Open ${doc.title}',
        icon: ArcaneIcon.files(size: IconSize.sm),
        keywords: const <String>['switch', 'document', 'workspace'],
        run: () => intents.openDocument(doc.id),
      ),
    );
  }
  return actions;
}

String _typeLabel(String type) => switch (type) {
  'button' => 'button (clickable)',
  'toggle' => 'toggle (two states)',
  _ => 'decoration (display only)',
};

/// "selected component" reads as though only one is selected when eight are,
/// and the commands act on all of them.
String _selectionNoun(int selected) =>
    selected > 1 ? '$selected selected components' : 'selected component';

/// Lucide's object-alignment glyphs: a vertical rule means the components line
/// up horizontally, and the other way round.
final List<(String, String, HuiAlign, Widget)> _alignments =
    <(String, String, HuiAlign, Widget)>[
      (
        'left',
        'Align left edges',
        HuiAlign.left,
        ArcaneIcon.alignStartVertical(size: IconSize.sm),
      ),
      (
        'centerX',
        'Align horizontal centres',
        HuiAlign.centerX,
        ArcaneIcon.alignCenterVertical(size: IconSize.sm),
      ),
      (
        'right',
        'Align right edges',
        HuiAlign.right,
        ArcaneIcon.alignEndVertical(size: IconSize.sm),
      ),
      (
        'top',
        'Align top edges',
        HuiAlign.top,
        ArcaneIcon.alignStartHorizontal(size: IconSize.sm),
      ),
      (
        'middleY',
        'Align vertical centres',
        HuiAlign.middleY,
        ArcaneIcon.alignCenterHorizontal(size: IconSize.sm),
      ),
      (
        'bottom',
        'Align bottom edges',
        HuiAlign.bottom,
        ArcaneIcon.alignEndHorizontal(size: IconSize.sm),
      ),
    ];

final List<(String, String, HuiZOrder, Widget)> _depths =
    <(String, String, HuiZOrder, Widget)>[
      (
        'forward',
        'Bring forward',
        HuiZOrder.forward,
        ArcaneIcon.arrowUp(size: IconSize.sm),
      ),
      (
        'backward',
        'Send backward',
        HuiZOrder.backward,
        ArcaneIcon.arrowDown(size: IconSize.sm),
      ),
      (
        'toFront',
        'Bring to front',
        HuiZOrder.toFront,
        ArcaneIcon.bringToFront(size: IconSize.sm),
      ),
      (
        'toBack',
        'Send to back',
        HuiZOrder.toBack,
        ArcaneIcon.sendToBack(size: IconSize.sm),
      ),
    ];

/// The command registry behind the palette.
///
/// Built fresh every time the palette opens so labels reflect live state
/// ("Show grid" vs "Hide grid") and the document list is current.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../../state/workspace.dart';
import 'shell_intents.dart';

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

  String get haystack =>
      '$label ${keywords.join(' ')} $group'.toLowerCase();
}

const String shellGroupFile = 'File';
const String shellGroupEdit = 'Edit';
const String shellGroupAdd = 'Add component';
const String shellGroupView = 'View';
const String shellGroupCanvas = 'Canvas';
const String shellGroupHelp = 'Help';
const String shellGroupDocuments = 'Documents';

List<ShellAction> buildShellActions(ShellIntents intents) {
  final EditorStore store = intents.store;
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
      label: 'Import menu JSON',
      icon: ArcaneIcon.upload(size: IconSize.sm),
      keywords: const <String>['open', 'load', 'file'],
      run: () => intents.importMenu(),
    ),
    ShellAction(
      id: 'file.export',
      group: shellGroupFile,
      label: 'Export menu JSON',
      icon: ArcaneIcon.download(size: IconSize.sm),
      shortcut: 'mod+S',
      keywords: const <String>['save', 'download', 'json'],
      run: intents.exportMenu,
    ),
    ShellAction(
      id: 'file.copy',
      group: shellGroupFile,
      label: 'Copy menu JSON',
      icon: ArcaneIcon.copy(size: IconSize.sm),
      keywords: const <String>['clipboard'],
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
      shortcut: 'mod+Z',
      enabled: store.canUndo,
      run: intents.undo,
    ),
    ShellAction(
      id: 'edit.redo',
      group: shellGroupEdit,
      label: store.redoLabel == null ? 'Redo' : 'Redo ${store.redoLabel}',
      icon: ArcaneIcon.redo(size: IconSize.sm),
      shortcut: 'mod+Shift+Z',
      enabled: store.canRedo,
      run: intents.redo,
    ),
    ShellAction(
      id: 'edit.duplicate',
      group: shellGroupEdit,
      label: 'Duplicate selected component',
      icon: ArcaneIcon.copy(size: IconSize.sm),
      shortcut: 'mod+D',
      enabled: store.selectedId != null,
      run: intents.duplicateSelected,
    ),
    ShellAction(
      id: 'edit.delete',
      group: shellGroupEdit,
      label: 'Delete selected component',
      icon: ArcaneIcon.trash2(size: IconSize.sm),
      shortcut: 'Delete',
      enabled: store.selectedId != null,
      run: intents.deleteSelected,
    ),
    ShellAction(
      id: 'edit.deselect',
      group: shellGroupEdit,
      label: 'Deselect',
      icon: ArcaneIcon.x(size: IconSize.sm),
      shortcut: 'Escape',
      enabled: store.selectedId != null,
      run: intents.deselect,
    ),
    for (final String type in huiComponentTypes)
      ShellAction(
        id: 'add.$type',
        group: shellGroupAdd,
        label: 'Add ${_typeLabel(type)}',
        icon: ArcaneIcon.plus(size: IconSize.sm),
        keywords: <String>[type, 'component', 'new'],
        run: () => intents.addComponent(type),
      ),
    ShellAction(
      id: 'view.visual',
      group: shellGroupView,
      label: 'Visual editor',
      icon: ArcaneIcon.eye(size: IconSize.sm),
      shortcut: 'V',
      run: () => intents.setView(EditorView.visual),
    ),
    ShellAction(
      id: 'view.code',
      group: shellGroupView,
      label: 'Code editor',
      icon: ArcaneIcon.code(size: IconSize.sm),
      shortcut: 'C',
      run: () => intents.setView(EditorView.code),
    ),
    ShellAction(
      id: 'view.split',
      group: shellGroupView,
      label: 'Split view',
      icon: ArcaneIcon.layers(size: IconSize.sm),
      shortcut: 'S',
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
      run: intents.toggleGrid,
    ),
    ShellAction(
      id: 'canvas.snap',
      group: shellGroupCanvas,
      label: store.snapToGrid ? 'Disable snapping' : 'Enable snapping',
      icon: ArcaneIcon.magnet(size: IconSize.sm),
      keywords: const <String>['grid', 'align'],
      run: intents.toggleSnap,
    ),
    ShellAction(
      id: 'canvas.hitboxes',
      group: shellGroupCanvas,
      label: store.showHitboxes ? 'Hide hitboxes' : 'Show hitboxes',
      icon: ArcaneIcon.square(size: IconSize.sm),
      keywords: const <String>['click', 'bounds'],
      run: intents.toggleHitboxes,
    ),
    ShellAction(
      id: 'canvas.anchors',
      group: shellGroupCanvas,
      label: store.showAnchors ? 'Hide anchors' : 'Show anchors',
      icon: ArcaneIcon.mousePointer(size: IconSize.sm),
      keywords: const <String>['offset', 'origin'],
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
      run: intents.toggleTrueRender,
    ),
    ShellAction(
      id: 'help.validation',
      group: shellGroupHelp,
      label: 'Show validation issues',
      icon: ArcaneIcon.triangleAlert(size: IconSize.sm),
      keywords: const <String>['errors', 'warnings', 'problems'],
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
    ShellAction(
      id: 'help.settings',
      group: shellGroupHelp,
      label: 'Settings',
      icon: ArcaneIcon.settings(size: IconSize.sm),
      keywords: const <String>['preferences', 'reset'],
      run: intents.openSettings,
    ),
  ];

  final String? activeId = store.workspace.activeId;
  for (final WorkspaceDoc doc in store.workspace.recent) {
    if (doc.id == activeId) continue;
    actions.add(
      ShellAction(
        id: 'doc.${doc.id}',
        group: shellGroupDocuments,
        label: 'Open ${doc.name}',
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

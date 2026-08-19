library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:arcane_jaspr/core/dom_value.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../config/defaults.dart';
import '../../doctype/doctype.dart';
import '../../state/editor_store.dart';
import '../../state/workspace.dart';
import '../../state/workspace_bundle.dart';
import '../../state/workspace_panel.dart';
import '../../state/workspace_route.dart';
import '../../services/clipboard.dart';
import '../../services/editor_sync.dart';
import '../../services/file_transfer.dart';
import '../../services/local_data_reset.dart';
import '../../services/showcase_randomizer.dart';
import '../../services/workspace_location.dart';
import '../common/common.dart';

enum _EditorRailTab { library, contents }

class EditorRail extends StatefulWidget {
  const EditorRail({
    required this.store,
    required this.contents,
    this.syncBinding,
    this.isDarkMode = true,
    super.key,
  });

  final EditorStore store;
  final Widget contents;
  final EditorSyncBinding? syncBinding;
  final bool isDarkMode;

  @override
  State<EditorRail> createState() => _EditorRailState();
}

class _EditorRailState extends State<EditorRail> {
  _EditorRailTab _tab = _EditorRailTab.library;
  final Set<String> _expanded = <String>{};
  String? _selectedId;
  String? _editingId;
  String? _movingId;
  String? _armedDeleteId;
  String? _menuItemId;
  String? _menuTriggerId;
  HuiActionMenuPoint _menuPoint = const HuiActionMenuPoint(8, 8);
  String? _lastActiveId;
  WorkspaceBundle? _pendingBundle;
  WorkspacePortableStateCheck? _pendingBundleCheck;
  String? _bundleFileName;
  String? _bundleError;
  bool _importingBundle = false;
  bool _resetArmed = false;
  bool _resetting = false;
  String? _lastShowcaseTemplateId;

  EditorStore get _store => component.store;

  Workspace get _workspace => _store.workspace;

  String? get _syncPanelFolderId {
    final EditorSyncBinding? binding = component.syncBinding;
    if (binding?.kind != 'panel') return null;
    final WorkspaceDoc? board = _workspace.byId(binding?.panelDocumentId);
    if (board == null) return null;
    return decodeWorkspacePanel(board.json).data.scopeFolderId;
  }

  String? get _syncScopeHint {
    final EditorSyncBinding? binding = component.syncBinding;
    if (binding == null) return null;
    final String imagePrefix = binding.constraints.newImagePrefix ?? 'none';
    if (binding.kind == 'menu') {
      return 'Synced menu id is locked; new images must start with '
          '"$imagePrefix".';
    }
    return 'Synced panel: new menu ids must start with '
        '"${binding.constraints.newMenuPrefix}" and new images with '
        '"$imagePrefix".';
  }

  @override
  void initState() {
    super.initState();
    _store.addListener(_onChanged);
    _workspace.addListener(_onChanged);
    _lastActiveId = _workspace.activeId;
    _selectedId = _lastActiveId;
    _expandActivePath();
  }

  @override
  void didUpdateComponent(EditorRail oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (identical(oldComponent.store, component.store)) return;
    oldComponent.store.removeListener(_onChanged);
    oldComponent.store.workspace.removeListener(_onChanged);
    _store.addListener(_onChanged);
    _workspace.addListener(_onChanged);
    _lastActiveId = _workspace.activeId;
    _selectedId = _lastActiveId;
    _expandActivePath();
  }

  @override
  void dispose() {
    _store.removeListener(_onChanged);
    _workspace.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final String? activeId = _workspace.activeId;
    if (activeId != _lastActiveId) {
      _lastActiveId = activeId;
      _selectedId = activeId;
      _editingId = null;
      _movingId = null;
      _armedDeleteId = null;
      _menuItemId = null;
      _menuTriggerId = null;
      _expandActivePath();
    }
    setState(() {});
  }

  void _expandActivePath() {
    final WorkspaceDoc? active = _workspace.active;
    if (active == null) return;
    String? folderId = active.folderId;
    final Set<String> seen = <String>{};
    while (folderId != null && seen.add(folderId)) {
      _expanded.add(folderId);
      folderId = _workspace.folderById(folderId)?.parentId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool library = _store.isPanelDoc || _tab == _EditorRailTab.library;
    return dom.div(classes: 'hui-editor-rail', <Widget>[
      dom.div(classes: 'hui-editor-rail-tabs', <Widget>[
        ArcaneToggleGroup(
          value: library
              ? _EditorRailTab.library.name
              : _EditorRailTab.contents.name,
          variant: ToggleGroupVariant.outline,
          size: ToggleGroupSize.sm,
          onChanged: _store.isPanelDoc ? null : _setTab,
          items: <ToggleGroupItem>[
            ToggleGroupItem(
              value: _EditorRailTab.library.name,
              child: dom.span(<Widget>[
                ArcaneIcon.folders(size: IconSize.sm),
                const Text('Library'),
              ]),
            ),
            if (!_store.isPanelDoc)
              ToggleGroupItem(
                value: _EditorRailTab.contents.name,
                child: dom.span(<Widget>[
                  ArcaneIcon.layers(size: IconSize.sm),
                  Text(_store.isPreviewDoc ? 'Elements' : 'Components'),
                ]),
              ),
          ],
        ),
      ]),
      if (library) _library() else component.contents,
      if (_menuItemId != null) _itemContextMenu(),
    ]);
  }

  Widget _library() {
    final List<WorkspaceFolder> roots = _workspace.childFolders(null).toList();
    roots.sort(_compareFolders);
    final List<WorkspaceDoc> rootDocuments =
        _workspace.documentsInFolder(null).toList()..sort(_compareDocuments);
    return dom.div(classes: 'hui-library hui-rail-pane', <Widget>[
      dom.div(classes: 'hui-library-inner', <Widget>[
        _header(),
        dom.p(classes: 'hui-library-hint', <Widget>[
          Text(
            _syncScopeHint ??
                (_store.isPanelDoc
                    ? 'Flow maps stay in this browser.'
                    : 'Folders organize files; runtime ids remain canonical.'),
          ),
        ]),
        if (_pendingBundle != null || _bundleError != null)
          _bundleImportPrompt(),
        if (_resetArmed) _resetPrompt(),
        if (roots.isEmpty && rootDocuments.isEmpty)
          const dom.div(classes: 'hui-library-empty', <Widget>[
            Text('Create a folder or document to begin.'),
          ])
        else
          dom.div(
            classes: 'hui-library-tree',
            attributes: const <String, String>{'role': 'tree'},
            <Widget>[
              for (final WorkspaceFolder folder in roots) _folder(folder, 0),
              for (final WorkspaceDoc doc in rootDocuments) _document(doc, 0),
            ],
          ),
      ]),
    ]);
  }

  Widget _header() => dom.div(classes: 'hui-library-header', <Widget>[
    dom.div(classes: 'hui-library-heading', <Widget>[
      const HuiEyebrow('Workspace'),
      dom.span(classes: 'hui-rail-count', <Widget>[
        Text('${_workspace.docs.length}'),
      ]),
    ]),
    dom.div(classes: 'hui-library-create', <Widget>[
      _iconButton(
        label: 'New folder',
        icon: ArcaneIcon.folderPlus(size: IconSize.sm),
        onPressed: _createFolder,
      ),
      _iconButton(
        label: 'Random Gloss showcase',
        icon: ArcaneIcon.dices(size: IconSize.sm),
        onPressed: _createRandomShowcase,
      ),
      for (final DocumentTypeAdapter type in DocumentTypeRegistry.all)
        _iconButton(
          label: type.createLabel,
          icon: type.createIcon(),
          onPressed: () => _createDocument(type),
        ),
      _iconButton(
        label: 'Import workspace bundle',
        icon: ArcaneIcon.upload(size: IconSize.sm),
        onPressed: _pickWorkspaceBundle,
      ),
      _iconButton(
        label: 'Export workspace bundle',
        icon: ArcaneIcon.download(size: IconSize.sm),
        onPressed: _exportWorkspaceBundle,
      ),
      _iconButton(
        label: 'Erase all local data',
        icon: ArcaneIcon.trash2(size: IconSize.sm),
        onPressed: () => setState(() => _resetArmed = true),
        destructive: true,
      ),
    ]),
  ]);

  Widget _folder(WorkspaceFolder folder, int depth) {
    final bool expanded = _expanded.contains(folder.id);
    final bool selected = _selectedId == folder.id;
    final List<WorkspaceFolder> children =
        _workspace.childFolders(folder.id).toList()..sort(_compareFolders);
    final List<WorkspaceDoc> documents =
        _workspace.documentsInFolder(folder.id).toList()
          ..sort(_compareDocuments);
    final bool hasChildren = children.isNotEmpty || documents.isNotEmpty;
    return dom.div(
      key: ValueKey<String>('workspace-folder-${folder.id}'),
      classes: 'hui-library-folder',
      attributes: <String, String>{'role': 'treeitem'},
      <Widget>[
        dom.div(
          classes: 'hui-library-row is-folder${selected ? ' is-selected' : ''}',
          styles: dom.Styles(
            raw: <String, String>{'--hui-tree-depth': '$depth'},
          ),
          events: <String, void Function(Object)>{
            'click': (Object _) => _select(folder.id),
            'contextmenu': (Object event) => _openItemMenu(
              folder.id,
              event: event,
              triggerId: _folderMenuTriggerId(folder.id),
            ),
          },
          <Widget>[
            dom.button(
              classes: 'hui-library-disclosure',
              attributes: <String, String>{
                'type': 'button',
                'aria-label': expanded ? 'Collapse folder' : 'Expand folder',
                'aria-expanded': expanded ? 'true' : 'false',
                if (!hasChildren) 'disabled': '',
              },
              events: <String, void Function(Object)>{
                'click': (Object event) {
                  domStopPropagation(event);
                  _toggleFolder(folder.id);
                },
              },
              <Widget>[
                hasChildren
                    ? expanded
                          ? ArcaneIcon.chevronDown(size: IconSize.sm)
                          : ArcaneIcon.chevronRight(size: IconSize.sm)
                    : const dom.span(<Widget>[]),
              ],
            ),
            expanded
                ? ArcaneIcon.folderOpen(size: IconSize.sm)
                : ArcaneIcon.folder(size: IconSize.sm),
            dom.span(classes: 'hui-library-label', <Widget>[
              Text(folder.title),
            ]),
            dom.span(classes: 'hui-library-count', <Widget>[
              Text('${children.length + documents.length}'),
            ]),
            _rowMenuButton(
              itemId: folder.id,
              label: folder.title,
              triggerId: _folderMenuTriggerId(folder.id),
            ),
          ],
        ),
        if (selected && _hasOpenEditor(folder.id)) _folderActions(folder),
        if (expanded)
          dom.div(classes: 'hui-library-children', <Widget>[
            for (final WorkspaceFolder child in children)
              _folder(child, depth + 1),
            for (final WorkspaceDoc doc in documents) _document(doc, depth + 1),
          ]),
      ],
    );
  }

  Widget _document(WorkspaceDoc doc, int depth) {
    final bool selected = _selectedId == doc.id;
    final bool active = _workspace.activeId == doc.id;
    final bool conflict =
        doc.runtimeId != null &&
        _workspace.runtimeIdConflicts.any(
          (WorkspaceRuntimeIdConflict item) =>
              item.kind == doc.kind && item.runtimeId == doc.runtimeId,
        );
    return dom.div(
      key: ValueKey<String>('workspace-document-${doc.id}'),
      classes: 'hui-library-document',
      <Widget>[
        dom.div(
          classes:
              'hui-library-row is-document${selected ? ' is-selected' : ''}'
              '${active ? ' is-active' : ''}',
          styles: dom.Styles(
            raw: <String, String>{'--hui-tree-depth': '$depth'},
          ),
          events: <String, void Function(Object)>{
            'contextmenu': (Object event) => _openItemMenu(
              doc.id,
              event: event,
              triggerId: _documentMenuTriggerId(doc.id),
            ),
          },
          <Widget>[
            dom.button(
              classes: 'hui-library-row-primary',
              attributes: <String, String>{
                'type': 'button',
                'aria-current': active ? 'page' : 'false',
              },
              events: <String, void Function(Object)>{
                'click': (Object _) {
                  _select(doc.id);
                  _store.openDocument(doc.id);
                },
              },
              <Widget>[
                const dom.span(
                  classes: 'hui-library-document-spacer',
                  <Widget>[],
                ),
                _documentIcon(doc.kind),
                dom.span(classes: 'hui-library-document-copy', <Widget>[
                  dom.span(classes: 'hui-library-label', <Widget>[
                    Text(doc.title),
                  ]),
                  dom.code(<Widget>[
                    Text(doc.runtimeId ?? 'editor-only flow map'),
                  ]),
                ]),
                if (conflict)
                  dom.span(
                    classes: 'hui-library-warning',
                    attributes: const <String, String>{
                      'title': 'Duplicate runtime id',
                    },
                    <Widget>[ArcaneIcon.triangleAlert(size: IconSize.sm)],
                  ),
                if (active)
                  const dom.span(
                    classes: 'hui-library-active-dot',
                    attributes: <String, String>{'aria-label': 'Open'},
                    <Widget>[],
                  ),
              ],
            ),
            _rowMenuButton(
              itemId: doc.id,
              label: doc.title,
              triggerId: _documentMenuTriggerId(doc.id),
            ),
          ],
        ),
        if (selected && _hasOpenEditor(doc.id)) _documentActions(doc),
      ],
    );
  }

  Widget _folderActions(WorkspaceFolder folder) {
    return _itemEditor(
      id: folder.id,
      title: folder.title,
      onRename: (String value) => _workspace.renameFolder(folder.id, value),
      moveValue: folder.parentId ?? _rootFolderValue,
      moveOptions: <ArcaneSelectOption>[
        const ArcaneSelectOption(
          label: 'Workspace root',
          value: _rootFolderValue,
        ),
        for (final WorkspaceFolder destination in _folderDestinations(folder))
          ArcaneSelectOption(
            label: _folderPath(destination),
            value: destination.id,
          ),
      ],
      onMove: (String value) => _workspace.moveFolder(
        folder.id,
        value == _rootFolderValue ? null : value,
      ),
      onDelete: () => _workspace.deleteFolder(folder.id),
    );
  }

  Widget _documentActions(WorkspaceDoc doc) => _itemEditor(
    id: doc.id,
    title: doc.title,
    runtimeId: doc.runtimeId,
    onRename: (String value) => _workspace.renameDocumentTitle(doc.id, value),
    onRenameRuntimeId: doc.runtimeId == null
        ? null
        : (String value) => _renameRuntimeId(doc, value),
    moveValue: doc.folderId ?? _rootFolderValue,
    moveOptions: <ArcaneSelectOption>[
      const ArcaneSelectOption(
        label: 'Workspace root',
        value: _rootFolderValue,
      ),
      for (final WorkspaceFolder destination in _sortedFolders())
        ArcaneSelectOption(
          label: _folderPath(destination),
          value: destination.id,
        ),
    ],
    onMove: (String value) =>
        _moveDocument(doc, value == _rootFolderValue ? null : value),
    onCopyLink: () => _copyDocumentLink(doc),
    onDelete: () => _store.deleteDocument(doc.id),
  );

  Widget _itemEditor({
    required String id,
    required String title,
    required void Function(String value) onRename,
    required String moveValue,
    required List<ArcaneSelectOption> moveOptions,
    required void Function(String value) onMove,
    required void Function() onDelete,
    String? runtimeId,
    void Function(String value)? onRenameRuntimeId,
    void Function()? onCopyLink,
  }) {
    if (_editingId == id) {
      return dom.div(classes: 'hui-library-editor', <Widget>[
        dom.label(<Widget>[
          const dom.span(<Widget>[Text('Display title')]),
          TextInput(
            value: title,
            fullWidth: true,
            size: ComponentSize.sm,
            onInput: onRename,
          ),
        ]),
        if (runtimeId != null && onRenameRuntimeId != null)
          dom.label(<Widget>[
            const dom.span(<Widget>[Text('Runtime id')]),
            TextInput(
              value: runtimeId,
              fullWidth: true,
              size: ComponentSize.sm,
              onInput: onRenameRuntimeId,
            ),
          ]),
        Button.ghost(
          size: ButtonSize.sm,
          icon: ArcaneIcon.check(size: IconSize.sm),
          label: 'Done',
          onPressed: () => setState(() => _editingId = null),
        ),
      ]);
    }
    if (_movingId == id) {
      return dom.div(classes: 'hui-library-editor', <Widget>[
        const dom.span(<Widget>[Text('Move to')]),
        ArcaneSelect(
          value: moveValue,
          fullWidth: true,
          size: ComponentSize.sm,
          options: moveOptions,
          onChange: (String value) {
            onMove(value);
            setState(() => _movingId = null);
          },
        ),
        Button.ghost(
          size: ButtonSize.sm,
          label: 'Cancel',
          onPressed: () => setState(() => _movingId = null),
        ),
      ]);
    }
    if (_armedDeleteId == id) {
      return dom.div(classes: 'hui-library-editor is-delete', <Widget>[
        const dom.span(<Widget>[Text('Delete this item?')]),
        Button.destructive(
          size: ButtonSize.sm,
          icon: ArcaneIcon.trash2(size: IconSize.sm),
          label: 'Delete',
          onPressed: () {
            setState(() => _armedDeleteId = null);
            onDelete();
          },
        ),
        Button.ghost(
          size: ButtonSize.sm,
          label: 'Keep',
          onPressed: () => setState(() => _armedDeleteId = null),
        ),
      ]);
    }
    return dom.div(classes: 'hui-library-actions', <Widget>[
      Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.iconSm,
        onPressed: () => setState(() => _editingId = id),
        attributes: const <String, String>{
          'aria-label': 'Rename',
          'title': 'Rename',
        },
        child: ArcaneIcon.pencil(size: IconSize.sm),
      ),
      Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.iconSm,
        onPressed: () => setState(() => _movingId = id),
        attributes: const <String, String>{
          'aria-label': 'Move',
          'title': 'Move',
        },
        child: ArcaneIcon.folderInput(size: IconSize.sm),
      ),
      if (onCopyLink != null)
        Button(
          variant: ButtonVariant.ghost,
          size: ButtonSize.iconSm,
          onPressed: onCopyLink,
          attributes: const <String, String>{
            'aria-label': 'Copy link',
            'title': 'Copy link',
          },
          child: ArcaneIcon.link(size: IconSize.sm),
        ),
      Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.iconSm,
        onPressed: () => setState(() => _armedDeleteId = id),
        attributes: const <String, String>{
          'aria-label': 'Delete',
          'title': 'Delete',
        },
        child: ArcaneIcon.trash2(size: IconSize.sm),
      ),
    ]);
  }

  bool _hasOpenEditor(String id) =>
      _editingId == id || _movingId == id || _armedDeleteId == id;

  String _folderMenuTriggerId(String id) => 'hui-folder-actions-$id';

  String _documentMenuTriggerId(String id) => 'hui-document-actions-$id';

  String get _itemMenuId => 'hui-library-item-menu';

  Widget _rowMenuButton({
    required String itemId,
    required String label,
    required String triggerId,
  }) => dom.button(
    id: triggerId,
    classes: 'hui-library-row-menu',
    attributes: <String, String>{
      'type': 'button',
      'aria-label': 'Actions for $label',
      'aria-haspopup': 'menu',
      'aria-expanded': _menuItemId == itemId ? 'true' : 'false',
      'aria-controls': _itemMenuId,
      'data-arcane-interactive': 'true',
    },
    events: <String, void Function(Object)>{
      'click': (Object event) {
        domStopPropagation(event);
        _openItemMenu(itemId, triggerId: triggerId);
      },
    },
    <Widget>[ArcaneIcon.ellipsisVertical(size: IconSize.sm)],
  );

  void _openItemMenu(
    String itemId, {
    Object? event,
    required String triggerId,
  }) {
    if (event != null) {
      domPreventDefault(event);
      domStopPropagation(event);
    }
    final HuiActionMenuPoint point = event == null
        ? huiActionMenuAnchor(triggerId)
        : huiActionMenuEventPoint(event);
    setState(() {
      _selectedId = itemId;
      _menuItemId = itemId;
      _menuTriggerId = triggerId;
      _menuPoint = point;
      _editingId = null;
      _movingId = null;
      _armedDeleteId = null;
    });
    context.binding.addPostFrameCallback(() {
      if (mounted) focusHuiActionMenu(_itemMenuId);
    });
  }

  void _closeItemMenu({bool restoreFocus = false}) {
    final String? triggerId = _menuTriggerId;
    setState(() {
      _menuItemId = null;
      _menuTriggerId = null;
    });
    if (!restoreFocus || triggerId == null) return;
    context.binding.addPostFrameCallback(() {
      if (mounted) focusHuiActionMenu(triggerId);
    });
  }

  Widget _itemContextMenu() {
    final String? id = _menuItemId;
    final WorkspaceFolder? folder = _workspace.folderById(id);
    final WorkspaceDoc? doc = _workspace.byId(id);
    if (id == null || (folder == null && doc == null)) {
      return const dom.span(<Widget>[]);
    }
    final String label = folder?.title ?? doc!.title;
    return HuiActionMenu(
      id: _itemMenuId,
      label: 'Actions for $label',
      point: _menuPoint,
      onClose: () => _closeItemMenu(),
      items: folder != null
          ? _folderMenuItems(folder)
          : _documentMenuItems(doc!),
    );
  }

  List<HuiActionMenuItem> _folderMenuItems(WorkspaceFolder folder) =>
      <HuiActionMenuItem>[
        HuiActionMenuItem(
          label: 'New folder here',
          icon: ArcaneIcon.folderPlus(size: IconSize.sm),
          onSelect: _createFolder,
        ),
        HuiActionMenuItem(
          label: 'New menu here',
          icon: ArcaneIcon.filePlus(size: IconSize.sm),
          onSelect: () => _createDocument(DocumentTypes.menu),
        ),
        HuiActionMenuItem(
          label: 'Rename',
          icon: ArcaneIcon.pencil(size: IconSize.sm),
          separatorBefore: true,
          onSelect: () => setState(() => _editingId = folder.id),
        ),
        HuiActionMenuItem(
          label: 'Move',
          icon: ArcaneIcon.folderInput(size: IconSize.sm),
          onSelect: () => setState(() => _movingId = folder.id),
        ),
        HuiActionMenuItem(
          label: 'Delete folder',
          hint: 'Keeps contents',
          icon: ArcaneIcon.trash2(size: IconSize.sm),
          destructive: true,
          separatorBefore: true,
          onSelect: () => setState(() => _armedDeleteId = folder.id),
        ),
      ];

  List<HuiActionMenuItem> _documentMenuItems(WorkspaceDoc doc) {
    final bool bound =
        component.syncBinding?.menuDocumentIds.containsValue(doc.id) ?? false;
    return <HuiActionMenuItem>[
      HuiActionMenuItem(
        label: 'Open',
        icon: ArcaneIcon.externalLink(size: IconSize.sm),
        disabled: doc.id == _workspace.activeId,
        onSelect: () => _store.openDocument(doc.id),
      ),
      HuiActionMenuItem(
        label: 'Rename',
        icon: ArcaneIcon.pencil(size: IconSize.sm),
        separatorBefore: true,
        onSelect: () => setState(() => _editingId = doc.id),
      ),
      HuiActionMenuItem(
        label: 'Duplicate',
        icon: ArcaneIcon.copy(size: IconSize.sm),
        disabled: bound,
        hint: bound ? 'Server bound' : null,
        onSelect: () {
          final WorkspaceDoc? copy = _store.duplicateDocument(doc.id);
          if (copy != null) ArcaneSonner.success('Created ${copy.title}.');
        },
      ),
      HuiActionMenuItem(
        label: 'Move',
        icon: ArcaneIcon.folderInput(size: IconSize.sm),
        onSelect: () => setState(() => _movingId = doc.id),
      ),
      HuiActionMenuItem(
        label: 'Copy link',
        icon: ArcaneIcon.link(size: IconSize.sm),
        onSelect: () => _copyDocumentLink(doc),
      ),
      HuiActionMenuItem(
        label: 'Delete document',
        icon: ArcaneIcon.trash2(size: IconSize.sm),
        destructive: true,
        separatorBefore: true,
        onSelect: () => setState(() => _armedDeleteId = doc.id),
      ),
    ];
  }

  Widget _iconButton({
    required String label,
    required Widget icon,
    required void Function() onPressed,
    bool destructive = false,
  }) {
    final Widget button = Button(
      variant: ButtonVariant.ghost,
      size: ButtonSize.iconSm,
      onPressed: onPressed,
      attributes: <String, String>{'aria-label': label, 'title': label},
      child: icon,
    );
    return destructive
        ? dom.span(classes: 'hui-library-reset', <Widget>[button])
        : button;
  }

  Widget _documentIcon(WorkspaceDocKind kind) =>
      DocumentTypeRegistry.of(kind).railIcon();

  void _setTab(String? value) {
    for (final _EditorRailTab tab in _EditorRailTab.values) {
      if (tab.name == value) {
        setState(() {
          _tab = tab;
          _menuItemId = null;
          _menuTriggerId = null;
        });
      }
    }
  }

  void _select(String id) => setState(() {
    _selectedId = id;
    _editingId = null;
    _movingId = null;
    _armedDeleteId = null;
    _menuItemId = null;
    _menuTriggerId = null;
  });

  void _toggleFolder(String id) => setState(() {
    if (!_expanded.remove(id)) _expanded.add(id);
  });

  String? get _targetFolderId {
    final WorkspaceFolder? selectedFolder = _workspace.folderById(_selectedId);
    if (selectedFolder != null) return selectedFolder.id;
    final WorkspaceDoc? selectedDocument = _workspace.byId(_selectedId);
    return selectedDocument?.folderId ?? _workspace.active?.folderId;
  }

  void _createFolder() {
    final WorkspaceFolder? selectedFolder = _workspace.folderById(_selectedId);
    final String? parentId = selectedFolder?.id;
    final WorkspaceFolder folder = _workspace.createFolder(
      title: 'New folder',
      parentId: parentId,
    );
    setState(() {
      if (parentId != null) _expanded.add(parentId);
      _selectedId = folder.id;
      _editingId = folder.id;
    });
  }

  void _createDocument(DocumentTypeAdapter type) {
    final String? folderId = _targetFolderId;
    if (folderId != null) _expanded.add(folderId);
    type.createNew(
      _store,
      folderId: folderId,
      runtimeId: _syncRuntimeIdOverride(type, folderId),
    );
  }

  void _createRandomShowcase() {
    final ShowcaseSelection? selection = createRandomGlossShowcase(
      _store,
      previousTemplateId: _lastShowcaseTemplateId,
    );
    if (selection == null) {
      ArcaneSonner.error('No Gloss showcase templates are available.');
      return;
    }
    _lastShowcaseTemplateId = selection.template.id;
    ArcaneSonner.success(
      'Created ${selection.template.name} as a ${selection.type.noun} showcase.',
    );
  }

  /// A synced world-panel session mints new subject-kind documents inside its
  /// folder under the server's reserved id prefix.
  String? _syncRuntimeIdOverride(DocumentTypeAdapter type, String? folderId) {
    final EditorSyncBinding? binding = component.syncBinding;
    final String? prefix = binding?.constraints.newMenuPrefix;
    if (binding?.kind == 'panel' &&
        prefix != null &&
        folderId == _syncPanelFolderId &&
        type.syncWireKind == 'menu') {
      return _uniqueSyncRuntimeId(prefix);
    }
    return null;
  }

  void _renameRuntimeId(WorkspaceDoc doc, String value) {
    final EditorSyncBinding? binding = component.syncBinding;
    final String canonical = sanitizeMenuId(value);
    if (binding != null && binding.menuDocumentIds.containsKey(doc.runtimeId)) {
      if (canonical != doc.runtimeId) {
        ArcaneSonner.error('A bound server menu id cannot be renamed.');
      }
      return;
    }
    if (doc.folderId == _syncPanelFolderId &&
        !_runtimeIdAllowedInSyncPanel(canonical)) {
      ArcaneSonner.error(
        'Synced panel menu ids must start with '
        '"${component.syncBinding?.constraints.newMenuPrefix}".',
      );
      return;
    }
    _store.renameDocumentRuntimeId(doc.id, canonical);
  }

  void _moveDocument(WorkspaceDoc doc, String? folderId) {
    if (folderId == _syncPanelFolderId &&
        doc.kind == DocumentTypes.menu.kind &&
        !_runtimeIdAllowedInSyncPanel(doc.runtimeId)) {
      ArcaneSonner.error(
        'Rename this menu into the server prefix before moving it into the '
        'synced panel.',
      );
      return;
    }
    _workspace.moveDocument(doc.id, folderId);
  }

  bool _runtimeIdAllowedInSyncPanel(String? runtimeId) {
    if (runtimeId == null) return false;
    final EditorSyncBinding? binding = component.syncBinding;
    if (binding == null || binding.kind != 'panel') return true;
    if (binding.menuDocumentIds.containsKey(runtimeId)) return true;
    final String? prefix = binding.constraints.newMenuPrefix;
    return prefix != null && runtimeId.startsWith(prefix);
  }

  String _uniqueSyncRuntimeId(String prefix) {
    final Set<String> existing = <String>{
      for (final WorkspaceDoc doc in _workspace.docs)
        if (doc.runtimeId != null) doc.runtimeId!,
    };
    String candidate = '${prefix}new-menu';
    for (int suffix = 2; existing.contains(candidate); suffix++) {
      candidate = '${prefix}new-menu-$suffix';
    }
    return candidate;
  }

  Widget _resetPrompt() => dom.div(
    classes: 'hui-library-bundle is-danger',
    attributes: const <String, String>{'role': 'alert'},
    <Widget>[
      const dom.strong(<Widget>[Text('Erase all local editor data?')]),
      dom.span(<Widget>[
        Text(
          '${_workspace.docs.length} documents, '
          '${_workspace.folders.length} folders and every stored image will '
          'be removed from this browser.',
        ),
      ]),
      const dom.span(<Widget>[
        Text('Export a workspace bundle first if anything must be kept.'),
      ]),
      dom.div(classes: 'hui-library-bundle-actions', <Widget>[
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          label: 'Export backup',
          icon: ArcaneIcon.download(size: IconSize.sm),
          onPressed: _resetting ? null : _exportWorkspaceBundle,
        ),
        Button.destructive(
          size: ButtonSize.sm,
          label: 'Erase everything',
          icon: ArcaneIcon.trash2(size: IconSize.sm),
          loading: _resetting,
          onPressed: _resetting ? null : _resetAllLocalData,
        ),
        Button.ghost(
          size: ButtonSize.sm,
          label: 'Cancel',
          onPressed: _resetting
              ? null
              : () => setState(() => _resetArmed = false),
        ),
      ]),
    ],
  );

  Future<void> _resetAllLocalData() async {
    setState(() => _resetting = true);
    final LocalDataResetResult result = await resetAllLocalEditorData(
      _store,
      isDarkMode: component.isDarkMode,
    );
    if (!mounted) return;
    setState(() {
      _resetting = false;
      if (result.success) _resetArmed = false;
    });
    if (result.success) {
      ArcaneSonner.warning(result.message);
    } else {
      ArcaneSonner.error(result.message);
    }
  }

  Widget _bundleImportPrompt() {
    final WorkspaceBundle? bundle = _pendingBundle;
    final WorkspacePortableStateCheck? check = _pendingBundleCheck;
    if (bundle == null || check == null) {
      return dom.div(classes: 'hui-library-bundle is-error', <Widget>[
        const dom.strong(<Widget>[Text('Workspace import failed')]),
        dom.span(<Widget>[Text(_bundleError ?? 'The bundle was unreadable.')]),
        Button.ghost(
          size: ButtonSize.sm,
          label: 'Dismiss',
          onPressed: _clearBundlePrompt,
        ),
      ]);
    }
    return dom.div(classes: 'hui-library-bundle', <Widget>[
      dom.strong(<Widget>[Text(_bundleFileName ?? 'Workspace bundle')]),
      dom.span(<Widget>[
        Text(
          '${check.documentCount} documents, ${check.folderCount} folders, '
          '${bundle.images.length} images',
        ),
      ]),
      if (check.warning != null)
        dom.span(classes: 'hui-library-bundle-warning', <Widget>[
          Text(check.warning!),
        ]),
      const dom.span(<Widget>[
        Text('Importing replaces this local workspace after confirmation.'),
      ]),
      dom.div(classes: 'hui-library-bundle-actions', <Widget>[
        Button.destructive(
          size: ButtonSize.sm,
          loading: _importingBundle,
          label: 'Replace workspace',
          onPressed: _importingBundle ? null : _confirmWorkspaceBundle,
        ),
        Button.ghost(
          size: ButtonSize.sm,
          label: 'Cancel',
          onPressed: _importingBundle ? null : _clearBundlePrompt,
        ),
      ]),
    ]);
  }

  Future<void> _pickWorkspaceBundle() async {
    final (String, String)? picked = await pickJsonFile();
    if (!mounted || picked == null) return;
    final WorkspaceBundleDecodeResult decoded = decodeWorkspaceBundle(
      picked.$2,
      _workspace,
    );
    setState(() {
      _bundleFileName = picked.$1;
      _pendingBundle = decoded.bundle;
      _pendingBundleCheck = decoded.workspaceCheck;
      _bundleError = decoded.error;
    });
  }

  void _exportWorkspaceBundle() {
    downloadText(
      'gloss-workspace.json',
      encodeWorkspaceBundle(_workspace, _store.images),
      mime: 'application/json',
    );
    ArcaneSonner.success('Saved gloss-workspace.json.');
  }

  Future<void> _confirmWorkspaceBundle() async {
    final WorkspaceBundle? bundle = _pendingBundle;
    if (bundle == null) return;
    setState(() => _importingBundle = true);
    final bool imported = await _store.importBundle(bundle);
    if (!mounted) return;
    setState(() {
      _importingBundle = false;
      if (imported) {
        _pendingBundle = null;
        _pendingBundleCheck = null;
        _bundleFileName = null;
        _bundleError = null;
      }
    });
    if (imported) {
      ArcaneSonner.success('Workspace bundle imported.');
    } else {
      ArcaneSonner.error('The workspace bundle could not be saved.');
    }
  }

  void _clearBundlePrompt() => setState(() {
    _pendingBundle = null;
    _pendingBundleCheck = null;
    _bundleFileName = null;
    _bundleError = null;
  });

  Future<void> _copyDocumentLink(WorkspaceDoc doc) async {
    final String hash = workspaceDocumentHash(_workspace.id, doc.id);
    final bool copied = await copyText(workspaceUrlForHash(hash));
    if (copied) {
      ArcaneSonner.success('Document link copied.');
    } else {
      ArcaneSonner.error('The browser refused clipboard access.');
    }
  }

  List<WorkspaceFolder> _sortedFolders() {
    final List<WorkspaceFolder> folders = List<WorkspaceFolder>.of(
      _workspace.folders,
    );
    folders.sort(
      (WorkspaceFolder a, WorkspaceFolder b) =>
          _folderPath(a).compareTo(_folderPath(b)),
    );
    return folders;
  }

  List<WorkspaceFolder> _folderDestinations(WorkspaceFolder moving) =>
      _sortedFolders()
          .where(
            (WorkspaceFolder candidate) =>
                candidate.id != moving.id &&
                !_isInside(candidate.id, moving.id),
          )
          .toList(growable: false);

  bool _isInside(String candidateId, String ancestorId) {
    String? cursor = candidateId;
    final Set<String> seen = <String>{};
    while (cursor != null && seen.add(cursor)) {
      if (cursor == ancestorId) return true;
      cursor = _workspace.folderById(cursor)?.parentId;
    }
    return false;
  }

  String _folderPath(WorkspaceFolder folder) {
    final List<String> parts = <String>[folder.title];
    String? parentId = folder.parentId;
    final Set<String> seen = <String>{folder.id};
    while (parentId != null && seen.add(parentId)) {
      final WorkspaceFolder? parent = _workspace.folderById(parentId);
      if (parent == null) break;
      parts.insert(0, parent.title);
      parentId = parent.parentId;
    }
    return parts.join(' / ');
  }

  static int _compareFolders(WorkspaceFolder a, WorkspaceFolder b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());

  static int _compareDocuments(WorkspaceDoc a, WorkspaceDoc b) {
    final int kind = a.kind.index.compareTo(b.kind.index);
    return kind != 0
        ? kind
        : a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }
}

const String _rootFolderValue = '__root__';

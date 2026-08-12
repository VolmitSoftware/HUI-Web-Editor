library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:arcane_jaspr/core/dom_value.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../config/defaults.dart';
import '../../state/editor_store.dart';
import '../../state/workspace.dart';
import '../../state/workspace_bundle.dart';
import '../../state/workspace_board.dart';
import '../../state/workspace_route.dart';
import '../../services/clipboard.dart';
import '../../services/editor_sync.dart';
import '../../services/file_transfer.dart';
import '../../services/workspace_location.dart';
import '../common/common.dart';

enum _EditorRailTab { library, contents }

class EditorRail extends StatefulWidget {
  const EditorRail({
    required this.store,
    required this.contents,
    this.syncBinding,
    super.key,
  });

  final EditorStore store;
  final Widget contents;
  final EditorSyncBinding? syncBinding;

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
  String? _lastActiveId;
  WorkspaceBundle? _pendingBundle;
  WorkspacePortableStateCheck? _pendingBundleCheck;
  String? _bundleFileName;
  String? _bundleError;
  bool _importingBundle = false;

  EditorStore get _store => component.store;

  Workspace get _workspace => _store.workspace;

  String? get _syncBoardFolderId {
    final EditorSyncBinding? binding = component.syncBinding;
    if (binding?.kind != 'board') return null;
    final WorkspaceDoc? board = _workspace.byId(binding?.boardDocumentId);
    if (board == null) return null;
    return decodeWorkspaceBoard(board.json).data.scopeFolderId;
  }

  String? get _syncScopeHint {
    final EditorSyncBinding? binding = component.syncBinding;
    if (binding == null) return null;
    final String imagePrefix = binding.constraints.newImagePrefix ?? 'none';
    if (binding.kind == 'menu') {
      return 'Synced menu id is locked; new images must start with '
          '"$imagePrefix".';
    }
    return 'Synced board: new menu ids must start with '
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
    final bool library = _store.isBoardDoc || _tab == _EditorRailTab.library;
    return dom.div(classes: 'hui-editor-rail', <Widget>[
      dom.div(classes: 'hui-editor-rail-tabs', <Widget>[
        ArcaneToggleGroup(
          value: library
              ? _EditorRailTab.library.name
              : _EditorRailTab.contents.name,
          variant: ToggleGroupVariant.outline,
          size: ToggleGroupSize.sm,
          onChanged: _store.isBoardDoc ? null : _setTab,
          items: <ToggleGroupItem>[
            ToggleGroupItem(
              value: _EditorRailTab.library.name,
              child: dom.span(<Widget>[
                ArcaneIcon.folders(size: IconSize.sm),
                const Text('Library'),
              ]),
            ),
            if (!_store.isBoardDoc)
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
    ]);
  }

  Widget _library() {
    final List<WorkspaceFolder> roots = _workspace.childFolders(null).toList();
    roots.sort(_compareFolders);
    return dom.div(classes: 'hui-library hui-rail-pane', <Widget>[
      dom.div(classes: 'hui-library-inner', <Widget>[
        _header(),
        dom.p(classes: 'hui-library-hint', <Widget>[
          Text(
            _syncScopeHint ??
                (_store.isBoardDoc
                    ? 'Boards stay local to this browser workspace.'
                    : 'Folders organize files; runtime ids remain canonical.'),
          ),
        ]),
        if (_pendingBundle != null || _bundleError != null)
          _bundleImportPrompt(),
        if (roots.isEmpty)
          const dom.div(classes: 'hui-library-empty', <Widget>[
            Text('Create a folder or document to begin.'),
          ])
        else
          dom.div(
            classes: 'hui-library-tree',
            attributes: const <String, String>{'role': 'tree'},
            <Widget>[
              for (final WorkspaceFolder folder in roots) _folder(folder, 0),
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
        label: 'New menu',
        icon: ArcaneIcon.filePlus(size: IconSize.sm),
        onPressed: _createMenu,
      ),
      _iconButton(
        label: 'New preview document',
        icon: ArcaneIcon.layoutGrid(size: IconSize.sm),
        onPressed: _createPreview,
      ),
      _iconButton(
        label: 'New flow board',
        icon: ArcaneIcon.workflow(size: IconSize.sm),
        onPressed: _createBoard,
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
          ],
        ),
        if (selected) _folderActions(folder),
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
        dom.button(
          classes:
              'hui-library-row is-document${selected ? ' is-selected' : ''}'
              '${active ? ' is-active' : ''}',
          styles: dom.Styles(
            raw: <String, String>{'--hui-tree-depth': '$depth'},
          ),
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
            const dom.span(classes: 'hui-library-document-spacer', <Widget>[]),
            _documentIcon(doc.kind),
            dom.span(classes: 'hui-library-document-copy', <Widget>[
              dom.span(classes: 'hui-library-label', <Widget>[Text(doc.title)]),
              dom.code(<Widget>[Text(doc.runtimeId ?? 'editor-only board')]),
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
        if (selected) _documentActions(doc),
      ],
    );
  }

  Widget _folderActions(WorkspaceFolder folder) {
    if (folder.id == _workspace.unfiledFolderId) {
      return const dom.div(classes: 'hui-library-editor is-system', <Widget>[
        Text('Unfiled is the protected fallback folder.'),
      ]);
    }
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
    moveValue: doc.folderId,
    moveOptions: <ArcaneSelectOption>[
      for (final WorkspaceFolder destination in _sortedFolders())
        ArcaneSelectOption(
          label: _folderPath(destination),
          value: destination.id,
        ),
    ],
    onMove: (String value) => _moveDocument(doc, value),
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

  Widget _iconButton({
    required String label,
    required Widget icon,
    required void Function() onPressed,
  }) => Button(
    variant: ButtonVariant.ghost,
    size: ButtonSize.iconSm,
    onPressed: onPressed,
    attributes: <String, String>{'aria-label': label, 'title': label},
    child: icon,
  );

  Widget _documentIcon(WorkspaceDocKind kind) => switch (kind) {
    WorkspaceDocKind.menu => ArcaneIcon.fileBraces(size: IconSize.sm),
    WorkspaceDocKind.containerPreview => ArcaneIcon.layoutGrid(
      size: IconSize.sm,
    ),
    WorkspaceDocKind.board => ArcaneIcon.workflow(size: IconSize.sm),
  };

  void _setTab(String? value) {
    for (final _EditorRailTab tab in _EditorRailTab.values) {
      if (tab.name == value) setState(() => _tab = tab);
    }
  }

  void _select(String id) => setState(() {
    _selectedId = id;
    _editingId = null;
    _movingId = null;
    _armedDeleteId = null;
  });

  void _toggleFolder(String id) => setState(() {
    if (!_expanded.remove(id)) _expanded.add(id);
  });

  String get _targetFolderId {
    final WorkspaceFolder? selectedFolder = _workspace.folderById(_selectedId);
    if (selectedFolder != null) return selectedFolder.id;
    final WorkspaceDoc? selectedDocument = _workspace.byId(_selectedId);
    return selectedDocument?.folderId ??
        _workspace.active?.folderId ??
        _workspace.unfiledFolderId;
  }

  void _createFolder() {
    final WorkspaceFolder folder = _workspace.createFolder(
      title: 'New folder',
      parentId: _targetFolderId,
    );
    setState(() {
      _expanded.add(_targetFolderId);
      _selectedId = folder.id;
      _editingId = folder.id;
    });
  }

  void _createMenu() {
    final String folderId = _targetFolderId;
    _expanded.add(folderId);
    final EditorSyncBinding? binding = component.syncBinding;
    final String? prefix = binding?.constraints.newMenuPrefix;
    if (binding?.kind == 'board' &&
        prefix != null &&
        folderId == _syncBoardFolderId) {
      _store.newDocument(
        name: 'New menu',
        runtimeId: _uniqueSyncRuntimeId(prefix),
        folderId: folderId,
      );
      return;
    }
    _store.newDocument(name: 'New menu', folderId: folderId);
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
    if (doc.folderId == _syncBoardFolderId &&
        !_runtimeIdAllowedInSyncBoard(canonical)) {
      ArcaneSonner.error(
        'Synced board menu ids must start with '
        '"${component.syncBinding?.constraints.newMenuPrefix}".',
      );
      return;
    }
    _workspace.renameDocumentRuntimeId(doc.id, canonical);
  }

  void _moveDocument(WorkspaceDoc doc, String folderId) {
    if (folderId == _syncBoardFolderId &&
        doc.kind == WorkspaceDocKind.menu &&
        !_runtimeIdAllowedInSyncBoard(doc.runtimeId)) {
      ArcaneSonner.error(
        'Rename this menu into the server prefix before moving it into the '
        'synced board.',
      );
      return;
    }
    _workspace.moveDocument(doc.id, folderId);
  }

  bool _runtimeIdAllowedInSyncBoard(String? runtimeId) {
    if (runtimeId == null) return false;
    final EditorSyncBinding? binding = component.syncBinding;
    if (binding == null || binding.kind != 'board') return true;
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

  void _createPreview() {
    final String folderId = _targetFolderId;
    _expanded.add(folderId);
    _store.newPreviewDocument(name: 'New preview', folderId: folderId);
  }

  void _createBoard() {
    final String folderId = _targetFolderId;
    _expanded.add(folderId);
    _store.newBoardDocument(
      name: 'Flow board',
      folderId: folderId,
      scopeFolderId: folderId,
    );
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
      'holoui-workspace.json',
      encodeWorkspaceBundle(_workspace, _store.images),
      mime: 'application/json',
    );
    ArcaneSonner.success('Saved holoui-workspace.json.');
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

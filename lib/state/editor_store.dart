/// The editor's single source of truth.
///
/// Every document change goes through [EditorStore.mutate], which snapshots the
/// document, runs the mutation, revalidates, schedules the workspace autosave
/// and notifies listeners. Nothing else is allowed to write the menu, which is
/// what keeps undo, validation and persistence in lockstep.
///
/// The store is DOM-free so it can be exercised on the VM: storage arrives as
/// injected functions and user-facing messages go to [EditorStore.onError] /
/// [EditorStore.onInfo] sinks that the shell wires to the toast stack.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:jaspr/jaspr.dart' show ChangeNotifier;

import '../config/defaults.dart';
import '../config/gloss_templates.dart';
import '../doctype/doctype.dart';
import '../logic/canvas_scene.dart';
import '../logic/gloss_text.dart';
import '../logic/validation.dart';
import '../logic/preview_sim_controls.dart';
import '../l10n/hui_localizations.dart';
import '../model/model.dart';
import '../preview/preview_types.dart';
import '../services/catalogs.dart';
import '../services/image_library.dart';
import 'undo_stack.dart';
import 'workspace.dart';
import 'workspace_panel.dart';
import 'workspace_bundle.dart';

/// The four editor modes, offered for every document kind.
///
/// [visual] is whichever editing surface the kind draws into (the component
/// canvas for a menu, the sidebar mock for a scoreboard, and so on — see
/// [DocumentTypeAdapter.surface]); [preview] is the same content rendered the
/// way the server renders it; [code] is the generic JSON editor; [split] pairs
/// visual and code. A kind that genuinely cannot serve one of them says why
/// through [DocumentTypeAdapter.unavailableViewReason] instead of dropping it
/// from the switcher.
enum EditorView { visual, preview, code, split }

/// Canvas background treatment. Lives in the store because the settings dialog
/// persists it and the status bar reflects it.
enum HuiBackdropMode { none, dark, light, image }

typedef EditorMessageSink = void Function(String message);

const Set<String> _directHistoryLabels = <String>{
  'add card',
  'add display style',
  'add format',
  'add hover release sequence',
  'add line',
  'add material property',
  'add material property map',
  'add repeat',
  'add select group',
  'add select world',
  'add variant',
  'align bottom',
  'align centred',
  'align left',
  'align middle',
  'align right',
  'align top',
  'bring forward',
  'bring to front',
  'delete element',
  'delete entry',
  'delete frame',
  'delete line',
  'duplicate element',
  'duplicate entry',
  'duplicate frame',
  'duplicate selection',
  'enable custom hitbox',
  'move element',
  'move variant',
  'remove card',
  'remove frame',
  'remove repeat',
  'rename animation profile',
  'rename drop script variable',
  'rename format',
  'rename image',
  'rename material property map',
  'reorder components',
  'reorder element',
  'send back',
  'send to back',
  'use automatic hitbox',
};

class EditorStore extends ChangeNotifier implements DocumentStateView {
  EditorStore({
    Workspace? workspace,
    HuiCatalogs? catalogs,
    ImageLibrary? images,
    this.autosaveDelay = const Duration(milliseconds: 500),
    bool autoLoad = true,
  }) : workspace = workspace ?? Workspace(),
       _catalogs = catalogs ?? HuiCatalogs.empty(),
       _images = images {
    _images?.addListener(_onImagesChanged);
    this.workspace.addListener(_onWorkspaceChanged);
    // The controller's own notifications are simulation state, not document
    // state: they must repaint the preview-card surface exactly like any
    // other store notification, but must never touch `previewRevision`,
    // undo, dirty tracking or autosave. Forwarding into `_notify` gives
    // every existing `store.addListener` call site that for free.
    previewSim.addListener(_notify);
    _menu = createDefaultMenu();
    _keepWorkspaceEmpty = this.workspace.read(emptyWorkspaceKey) == 'true';
    if (autoLoad) {
      _loadPreferences();
      // The restored document must not overwrite the restored scope: the mode
      // follows documents the USER opens, and reopening the tab is not that.
      _restoringSession = true;
      _adoptActiveDocument();
      _restoringSession = false;
    } else {
      _refreshIssues();
    }
  }

  /// Preview and canvas flags, persisted separately from the documents so a
  /// corrupt preference blob can never take the menus down with it.
  static const String preferencesKey = 'gloss.prefs.v1';
  static const String emptyWorkspaceKey = 'gloss.empty-workspace.v1';

  final Workspace workspace;

  /// Debounce window for the workspace autosave.
  final Duration autosaveDelay;

  /// Routed to the toast stack by the shell.
  EditorMessageSink? onError;
  EditorMessageSink? onInfo;

  late HuiMenu _menu;
  String _menuId = huiDefaultMenuId;

  /// Which model [_menu]/[_previewDoc] the active document actually holds,
  /// as the adapter that owns the kind's behavior. Every menu-editing method
  /// below (`mutate`, `replaceMenu`) requires the menu type and is a
  /// documented no-op otherwise; the container-preview document has its own
  /// write path ([mutatePreview]) with the same undo, autosave and
  /// notification mechanics. Menus are entirely unaffected: this field starts
  /// and stays at [DocumentTypes.menu] unless another document kind is
  /// explicitly opened, created or imported.
  DocumentTypeAdapter _docType = DocumentTypes.menu;

  /// The active container-preview document, or null while another kind is
  /// open. Always written through [_setPreviewDoc].
  HuiPreviewDoc? _previewDoc;

  /// The active Gloss document (hologram, animation or scoreboard model), or
  /// null while another kind is open. Always written through [_setGlossDoc].
  GlossDoc? _glossDoc;

  /// Bumped on every change to [_glossDoc] — the Gloss surfaces' memo key,
  /// the exact counterpart of [_previewRevision].
  int _glossRevision = 0;

  /// Bumped on every change to [_previewDoc], whether it was swapped wholesale
  /// or edited in place.
  int _previewRevision = 0;

  /// The one [PreviewSim] the preview-card viewport and the simulation panel
  /// (task E8) share — see [PreviewSimController]'s own doc comment for why
  /// it lives here rather than inside either widget. Its notifications are
  /// simulation state, deliberately kept OFF [_previewRevision]: a pinned
  /// override or a tick must repaint the card without marking the document
  /// dirty, without an undo step, and without invalidating the viewport's
  /// revision-keyed memo of the document's own category/vars resolution.
  final PreviewSimController previewSim = PreviewSimController();

  /// Index into `previewDoc.elements` of the selected element, or null.
  ///
  /// Deliberately separate from [_selection]: a preview element has no id to
  /// address it by — the format identifies elements by position alone — so the
  /// two selection models cannot share a representation. Only one of them is
  /// ever meaningful, decided by [_docKind].
  int? _previewSelection;

  /// Insertion-ordered: the LAST id is the primary, which is what every
  /// single-select call site reads through [selectedId].
  final Set<String> _selection = <String>{};
  late final Set<String> _selectionView = UnmodifiableSetView<String>(
    _selection,
  );
  EditorView _view = EditorView.visual;

  /// The mode each kind was last left in. One remembered view per kind, not
  /// one for the whole editor: the code view a scoreboard was left in has
  /// nothing to say about the menu opened after it, and a single global
  /// preference made every document switch feel like it moved the furniture.
  final Map<WorkspaceDocKind, EditorView> _viewByKind =
      <WorkspaceDocKind, EditorView>{};

  /// The library scope: the kind whose documents the rail lists, or null while
  /// the whole workspace is listed.
  DocumentTypeAdapter? _mode;
  double _previewUiScale = 1;
  bool _showHitboxes = false;
  bool _showAnchors = true;
  bool _showGrid = true;
  bool _snapToGrid = true;
  bool _trueRender = false;
  double _gridSize = 0.05;
  HuiBackdropMode _backdrop = HuiBackdropMode.image;
  bool _animationsPlaying = true;
  final Map<String, bool> _togglePreviewState = <String, bool>{};

  bool _previewShowPlanes = false;
  bool _previewShowNormals = false;
  bool _previewShowAnchors = false;
  bool _previewShowCenter = true;
  bool _previewShowDistanceSphere = false;
  bool _previewShowGroundGrid = true;
  bool _previewLogOpen = true;
  bool _previewBannerDismissed = false;
  PreviewCameraMode _previewCameraMode = PreviewCameraMode.orbit;

  List<HuiIssue> _issues = const <HuiIssue>[];

  /// Validation resolves the same scene the canvas does, so it needs the same
  /// memos: without them every keystroke re-parses every label and re-scans
  /// every decoded image.
  final McTextCache _textCache = McTextCache();
  final ImageCharCache _charCache = ImageCharCache();
  CanvasScene? _scene;
  final UndoStack _undo = UndoStack();
  HuiCatalogs _catalogs;
  final ImageLibrary? _images;

  Timer? _autosaveTimer;
  bool _documentDirty = false;
  bool _documentPersistedInWorkspace = false;
  bool _preferencesDirty = false;
  DateTime? _lastSavedAt;
  bool _dragActive = false;
  bool _dragPushed = false;
  String? _coalesceLabel;
  DateTime? _coalesceAt;
  bool _disposed = false;

  /// True only while the constructor adopts the document the tab was left on.
  bool _restoringSession = false;
  bool _keepWorkspaceEmpty = false;
  String Function()? _lastError;
  String Function()? _codeError;
  String? _preservedMenuSource;
  int _documentRevision = 0;
  int? _pendingDocumentRevision;
  int? _pendingWorkspaceRevision;

  // --- document -------------------------------------------------------------

  /// Read-only handle on the document. Write through [mutate] so the change is
  /// undoable, validated and saved. Meaningless while [isPreviewDoc] is true —
  /// still a valid, harmless [HuiMenu] (never null), just not the active
  /// document.
  @override
  HuiMenu get menu => _menu;

  /// The active menu's components, and empty for every other kind — a
  /// hologram has no components, and answering with a menu's would be a list
  /// of things the open document does not contain.
  List<HuiComponent> get components =>
      isMenuDoc ? _menu.components : const <HuiComponent>[];

  /// The adapter owning the active document kind's behavior.
  DocumentTypeAdapter get docType => _docType;

  /// Which model the active document holds.
  WorkspaceDocKind get docKind => _docType.kind;

  bool get isMenuDoc => identical(_docType, DocumentTypes.menu);

  bool get hasActiveDocument => workspace.active != null;

  bool get isPreviewDoc => identical(_docType, DocumentTypes.containerPreview);

  bool get isPanelDoc => identical(_docType, DocumentTypes.panel);

  bool get canTransferDocument => hasActiveDocument && _docType.transferable;

  WorkspacePanelDecodeResult? get activePanel {
    if (!isPanelDoc) return null;
    final WorkspaceDoc? doc = workspace.active;
    return doc == null ? null : decodeWorkspacePanel(doc.json);
  }

  /// The active container-preview document, or null while [isPreviewDoc] is
  /// false.
  @override
  HuiPreviewDoc? get previewDoc => _previewDoc;

  /// The active Gloss document, or null while [isGlossDoc] is false.
  @override
  GlossDoc? get glossDoc => _glossDoc;

  /// Whether the active document is one of the Gloss kinds.
  bool get isGlossDoc => _docType is GlossDocumentTypeAdapter;

  /// The active hologram, or null while another kind is open.
  GlossHologramDoc? get hologramDoc {
    final GlossDoc? doc = _glossDoc;
    return doc is GlossHologramDoc ? doc : null;
  }

  /// The active animation, or null while another kind is open.
  GlossAnimationDoc? get animationDoc {
    final GlossDoc? doc = _glossDoc;
    return doc is GlossAnimationDoc ? doc : null;
  }

  /// The active scoreboard, or null while another kind is open.
  GlossScoreboardDoc? get scoreboardDoc {
    final GlossDoc? doc = _glossDoc;
    return doc is GlossScoreboardDoc ? doc : null;
  }

  /// The active MOTD document, or null while another kind is open.
  GlossMotdDoc? get motdDoc {
    final GlossDoc? doc = _glossDoc;
    return doc is GlossMotdDoc ? doc : null;
  }

  /// The active emoji document, or null while another kind is open.
  GlossEmojiDoc? get emojiDoc {
    final GlossDoc? doc = _glossDoc;
    return doc is GlossEmojiDoc ? doc : null;
  }

  /// The active bubble style, or null while another kind is open.
  GlossBubbleStyleDoc? get bubbleStyleDoc {
    final GlossDoc? doc = _glossDoc;
    return doc is GlossBubbleStyleDoc ? doc : null;
  }

  /// The active tablist, or null while another kind is open.
  GlossTablistDoc? get tablistDoc {
    final GlossDoc? doc = _glossDoc;
    return doc is GlossTablistDoc ? doc : null;
  }

  GlossRealDropSettingsDoc? get realDropSettingsDoc {
    final GlossDoc? doc = _glossDoc;
    return doc is GlossRealDropSettingsDoc ? doc : null;
  }

  /// Monotonic counter over every change to [glossDoc] — an edit, an undo, a
  /// code commit, an import, a document switch.
  int get glossRevision => _glossRevision;

  /// The one place [_glossDoc] is assigned, so no swap can be made without
  /// the revision moving with it.
  void _setGlossDoc(GlossDoc? doc) {
    _glossDoc = doc;
    _glossRevision++;
  }

  /// The byte-exact source the active menu document was decoded from, kept
  /// until the first semantic edit. Null for every other kind.
  @override
  String? get preservedMenuSource => _preservedMenuSource;

  /// Monotonic counter over every change to [previewDoc] — an edit, an undo, a
  /// code commit, an import, a document switch.
  ///
  /// The card surface rebuilds its scene on every simulation tick but derives
  /// its simulated category, its variant `vars` (which compiles a RegExp per
  /// glob) and its animation gate from the DOCUMENT, which changes far more
  /// rarely. Those three are memoized against this, so a steady frame does none
  /// of that work. A revision, not a hash: the model is mutable and edited in
  /// place, so identity proves nothing and hashing it every frame would cost
  /// more than it saved.
  int get previewRevision => _previewRevision;

  /// The one place [_previewDoc] is assigned, so no swap can be made without
  /// the revision moving with it.
  void _setPreviewDoc(HuiPreviewDoc? doc) {
    _previewDoc = doc;
    _previewRevision++;
  }

  /// Every write path below (`mutate`, `replaceMenu`, `applyCode`) requires
  /// this to keep the guarantee that [_menu] is really the live document.
  bool get _menuWritable => hasActiveDocument && isMenuDoc;

  /// Export file base name, always sanitized.
  String get menuId => _menuId;

  set menuId(String value) => setMenuId(value);

  String get exportFileName => '$_menuId.json';

  void setMenuId(String value) {
    if (!_docType.hasRuntimeId) return;
    final String sanitized = sanitizeMenuId(value);
    if (sanitized == _menuId) return;
    _menuId = sanitized;
    _documentDirty = true;
    _documentRevision++;
    _scheduleSave();
    _notify();
  }

  bool renameDocumentRuntimeId(String documentId, String value) {
    final WorkspaceDoc? target = workspace.byId(documentId);
    if (target == null ||
        !target.kind.hasRuntimeId ||
        target.runtimeId == null) {
      return false;
    }
    final String previous = target.runtimeId!;
    final String next = sanitizeMenuId(value);
    if (previous == next) return true;
    final bool conflict = workspace.docs.any(
      (WorkspaceDoc document) =>
          document.id != target.id &&
          document.kind == target.kind &&
          document.runtimeId?.toLowerCase() == next.toLowerCase(),
    );
    if (conflict) {
      _fail('A {document} already uses "{id}".', <String, Object?>{
        'document': DocumentTypeRegistry.of(target.kind).noun,
        'id': next,
      });
      return false;
    }

    flushAutosave();
    if (target.kind != DocumentTypes.menu.kind) {
      final bool renamed = workspace.updateDocuments(<WorkspaceDocumentUpdate>[
        WorkspaceDocumentUpdate(documentId: target.id, runtimeId: next),
      ]);
      if (renamed && workspace.activeId == target.id) {
        _menuId = next;
        _notify();
      }
      return renamed;
    }
    return _renameMenuProject(target, previous, next);
  }

  bool renameActiveRuntimeId(String value) {
    final WorkspaceDoc? active = workspace.active;
    if (active == null) return false;
    return renameDocumentRuntimeId(active.id, value);
  }

  bool _renameMenuProject(WorkspaceDoc target, String previous, String next) {
    final List<WorkspaceDocumentUpdate> updates = <WorkspaceDocumentUpdate>[];
    int navigationLinks = 0;
    int panelRoots = 0;

    for (final WorkspaceDoc document in workspace.docs) {
      final MenuRenameRewrite rewrite = DocumentTypeRegistry.of(
        document.kind,
      ).rewriteForMenuRename(document, previous, next);
      final String? failure = rewrite.failure;
      if (failure != null) {
        _failResolved(() => rewrite.failure ?? failure);
        return false;
      }
      navigationLinks += rewrite.navigationLinks;
      panelRoots += rewrite.panelRoots;
      if (rewrite.json != null || document.id == target.id) {
        updates.add(
          WorkspaceDocumentUpdate(
            documentId: document.id,
            runtimeId: document.id == target.id ? next : null,
            json: rewrite.json,
          ),
        );
      }
    }

    if (!workspace.updateDocuments(updates)) {
      _fail('The workspace could not save the menu rename.');
      return false;
    }
    if (updates.any(
      (WorkspaceDocumentUpdate update) =>
          update.documentId == workspace.activeId,
    )) {
      _adoptActiveDocument();
    } else {
      _notify();
    }
    final List<String> effects = <String>[
      if (navigationLinks > 0)
        huiPlural(
          'workspace.rename.navigation-links',
          navigationLinks,
          oneEnglish: '{count} navigation link',
          otherEnglish: '{count} navigation links',
        ),
      if (panelRoots > 0)
        huiPlural(
          'workspace.rename.panel-roots',
          panelRoots,
          oneEnglish: '{count} world-panel root',
          otherEnglish: '{count} world-panel roots',
        ),
    ];
    if (effects.isEmpty) {
      _inform('Renamed {previous} to {next}.', <String, Object?>{
        'previous': previous,
        'next': next,
      });
    } else {
      _inform(
        'Renamed {previous} to {next} and updated {effects}.',
        <String, Object?>{
          'previous': previous,
          'next': next,
          'effects': effects.join(huiText(' and ')),
        },
      );
    }
    return true;
  }

  // --- selection ------------------------------------------------------------

  /// Every selected id, oldest first.
  Set<String> get selectionIds => _selectionView;

  /// The primary: the most recently added member, or null when nothing is
  /// selected. Single-select call sites read this and keep their old meaning.
  String? get selectedId => _selection.isEmpty ? null : _selection.last;

  set selectedId(String? value) => select(value);

  HuiComponent? get selected {
    final String? id = selectedId;
    return id == null ? null : _menu.componentById(id);
  }

  /// Document order, not selection order: align, distribute and duplicate all
  /// need the components laid out the way the file declares them.
  List<HuiComponent> get selectedComponents => <HuiComponent>[
    for (final HuiComponent component in _menu.components)
      if (_selection.contains(component.id)) component,
  ];

  bool isSelected(String id) => _selection.contains(id);

  /// Replaces the selection with [id]; null clears it. An unknown id is
  /// ignored, so a stale click can never wipe a good selection.
  void select(String? id) {
    if (id == null) {
      if (_selection.isEmpty) return;
      _selection.clear();
      _notify();
      return;
    }
    if (_menu.componentById(id) == null) return;
    if (_selection.length == 1 && _selection.first == id) return;
    _selection
      ..clear()
      ..add(id);
    _notify();
  }

  /// Adds [id] and makes it the primary. Re-adding an existing member only
  /// re-primaries it, which is what clicking an already-selected component in
  /// a group has to do.
  void addToSelection(String id) {
    if (_menu.componentById(id) == null) return;
    if (_selection.isNotEmpty && _selection.last == id) return;
    _selection
      ..remove(id)
      ..add(id);
    _notify();
  }

  void toggleInSelection(String id) {
    if (_selection.remove(id)) {
      _notify();
      return;
    }
    addToSelection(id);
  }

  /// Replaces the selection with [ids], dropping any the document does not
  /// have. [primary] moves that id to the end of the order when it survived.
  void selectMany(Iterable<String> ids, {String? primary}) {
    final Set<String> next = <String>{
      for (final String id in ids)
        if (_menu.componentById(id) != null) id,
    };
    if (primary != null && next.remove(primary)) next.add(primary);
    if (_sameSelection(next)) return;
    _selection
      ..clear()
      ..addAll(next);
    _notify();
  }

  void selectAll() => selectMany(components.map((HuiComponent c) => c.id));

  /// Order matters as much as membership: the primary is positional.
  bool _sameSelection(Set<String> next) {
    if (next.length != _selection.length) return false;
    final Iterator<String> mine = _selection.iterator;
    final Iterator<String> theirs = next.iterator;
    while (mine.moveNext() && theirs.moveNext()) {
      if (mine.current != theirs.current) return false;
    }
    return true;
  }

  // --- view state -----------------------------------------------------------

  EditorView get view => _view;

  /// Rejects a view the active document kind cannot serve, landing on that
  /// kind's default instead. A keyboard shortcut, the command palette and the
  /// switcher all route through here, so none of them can strand a flow map on
  /// the code editor. The accepted view becomes this kind's remembered one.
  set view(EditorView value) {
    final EditorView next = _docType.supportsView(value)
        ? value
        : _docType.availableViews.first;
    _viewByKind[_docType.kind] = next;
    if (_view == next) {
      _preferencesDirty = true;
      _scheduleSave();
      return;
    }
    _view = next;
    _savePreference();
  }

  /// The views the active document kind can enter, in switcher order. First
  /// entry is that kind's default.
  List<EditorView> get availableViews => _docType.availableViews;

  /// Why the active kind cannot enter [view], or null when it can.
  String? unavailableViewReason(EditorView view) =>
      _docType.unavailableViewReason(view);

  /// The library scope. Null lists the whole workspace; an adapter lists only
  /// that kind's documents and defaults the rail's create action to it.
  DocumentTypeAdapter? get mode => _mode;

  set mode(DocumentTypeAdapter? value) {
    if (identical(_mode, value)) return;
    _mode = value;
    _savePreference();
  }

  /// Whether [doc] belongs to the current scope. Null mode admits everything.
  bool inMode(WorkspaceDoc doc) {
    final DocumentTypeAdapter? mode = _mode;
    return mode == null || doc.kind == mode.kind;
  }

  /// The documents in [folderId] the current scope lists, in workspace order.
  List<WorkspaceDoc> documentsInMode(String? folderId) => <WorkspaceDoc>[
    for (final WorkspaceDoc doc in workspace.documentsInFolder(folderId))
      if (inMode(doc)) doc,
  ];

  /// Whether the folder holds, at any depth, a document the current scope
  /// lists. A scoped library hides the folders that hold none: an empty tree
  /// of folders is not what "show me my scoreboards" means.
  bool folderInMode(String folderId) =>
      _mode == null || _folderInMode(folderId, <String>{});

  /// [seen] keeps a corrupt parent cycle from recursing forever.
  bool _folderInMode(String folderId, Set<String> seen) {
    if (!seen.add(folderId)) return false;
    if (documentsInMode(folderId).isNotEmpty) return true;
    for (final WorkspaceFolder child in workspace.childFolders(folderId)) {
      if (_folderInMode(child.id, seen)) return true;
    }
    return false;
  }

  /// Called after every document adoption: the mode follows the document that
  /// was opened, so a hologram reached from search or the palette leaves the
  /// library scoped to holograms rather than showing a list it is not in.
  void _followMode() {
    if (_restoringSession || _mode == null || identical(_mode, _docType)) {
      return;
    }
    _mode = _docType;
    _preferencesDirty = true;
    _scheduleSave();
  }

  /// Called after every document adoption: the new kind gets the view it was
  /// last left in, coerced to one it can actually serve.
  void _coerceView() {
    final EditorView remembered = _viewByKind[_docType.kind] ?? _view;
    final EditorView next = _docType.supportsView(remembered)
        ? remembered
        : _docType.availableViews.first;
    _viewByKind[_docType.kind] = next;
    if (_view == next) return;
    _view = next;
    // No `_savePreference`: every caller notifies once it has finished
    // adopting, and a second notification mid-adoption would rebuild the shell
    // against a half-swapped document.
    _preferencesDirty = true;
    _scheduleSave();
  }

  double get previewUiScale => _previewUiScale;

  set previewUiScale(double value) {
    final double clamped = value.isFinite ? value.clamp(0.25, 4).toDouble() : 1;
    if (clamped == _previewUiScale) return;
    _previewUiScale = clamped;
    _savePreference();
  }

  bool get showHitboxes => _showHitboxes;

  set showHitboxes(bool value) {
    if (_showHitboxes == value) return;
    _showHitboxes = value;
    _savePreference();
  }

  bool get showAnchors => _showAnchors;

  set showAnchors(bool value) {
    if (_showAnchors == value) return;
    _showAnchors = value;
    _savePreference();
  }

  bool get showGrid => _showGrid;

  set showGrid(bool value) {
    if (_showGrid == value) return;
    _showGrid = value;
    _savePreference();
  }

  bool get snapToGrid => _snapToGrid;

  set snapToGrid(bool value) {
    if (_snapToGrid == value) return;
    _snapToGrid = value;
    _savePreference();
  }

  bool get trueRender => _trueRender;

  set trueRender(bool value) {
    if (_trueRender == value) return;
    _trueRender = value;
    _savePreference();
  }

  /// Snap step in blocks.
  double get gridSize => _gridSize;

  set gridSize(double value) {
    final double clamped = value.isFinite && value > 0
        ? value.clamp(0.01, 1).toDouble()
        : 0.05;
    if (clamped == _gridSize) return;
    _gridSize = clamped;
    _savePreference();
  }

  HuiBackdropMode get backdrop => _backdrop;

  set backdrop(HuiBackdropMode value) {
    if (_backdrop == value) return;
    _backdrop = value;
    _savePreference();
  }

  bool get animationsPlaying => _animationsPlaying;

  set animationsPlaying(bool value) {
    if (_animationsPlaying == value) return;
    _animationsPlaying = value;
    _notify();
  }

  /// Which icon a toggle previews on the canvas. Defaults to the true icon.
  Map<String, bool> get togglePreviewState => _togglePreviewState;

  bool togglePreviewFor(String id) => _togglePreviewState[id] ?? true;

  void setTogglePreview(String id, bool showTrue) {
    if (togglePreviewFor(id) == showTrue) return;
    _togglePreviewState[id] = showTrue;
    _notify();
  }

  // --- preview settings -----------------------------------------------------

  /// Collision planes, drawn where the runtime re-aims them each tick
  /// (`ClickableComponent.java:60-62`). Off by default: they hide the icons.
  bool get previewShowPlanes => _previewShowPlanes;

  set previewShowPlanes(bool value) {
    if (_previewShowPlanes == value) return;
    _previewShowPlanes = value;
    _savePreference();
  }

  bool get previewShowNormals => _previewShowNormals;

  set previewShowNormals(bool value) {
    if (_previewShowNormals == value) return;
    _previewShowNormals = value;
    _savePreference();
  }

  /// Component anchors, which are NOT where the icon draws.
  bool get previewShowAnchors => _previewShowAnchors;

  set previewShowAnchors(bool value) {
    if (_previewShowAnchors == value) return;
    _previewShowAnchors = value;
    _savePreference();
  }

  bool get previewShowCenter => _previewShowCenter;

  set previewShowCenter(bool value) {
    if (_previewShowCenter == value) return;
    _previewShowCenter = value;
    _savePreference();
  }

  /// The `maxDistance` shell the session closes outside of.
  bool get previewShowDistanceSphere => _previewShowDistanceSphere;

  set previewShowDistanceSphere(bool value) {
    if (_previewShowDistanceSphere == value) return;
    _previewShowDistanceSphere = value;
    _savePreference();
  }

  bool get previewShowGroundGrid => _previewShowGroundGrid;

  set previewShowGroundGrid(bool value) {
    if (_previewShowGroundGrid == value) return;
    _previewShowGroundGrid = value;
    _savePreference();
  }

  bool get previewLogOpen => _previewLogOpen;

  set previewLogOpen(bool value) {
    if (_previewLogOpen == value) return;
    _previewLogOpen = value;
    _savePreference();
  }

  /// Whether the in-stage facing note has been closed for good. Set by its own
  /// close button and by the first real camera or click interaction, because
  /// someone who has started using the preview has stopped reading it. The
  /// copy stays reachable from the toolbar's facing help.
  bool get previewBannerDismissed => _previewBannerDismissed;

  set previewBannerDismissed(bool value) {
    if (_previewBannerDismissed == value) return;
    _previewBannerDismissed = value;
    _savePreference();
  }

  PreviewCameraMode get previewCameraMode => _previewCameraMode;

  set previewCameraMode(PreviewCameraMode value) {
    if (_previewCameraMode == value) return;
    _previewCameraMode = value;
    _savePreference();
  }

  // --- validation -----------------------------------------------------------

  List<HuiIssue> get issues => _issues;

  bool get hasErrors => errorCount > 0;

  int get errorCount => _countSeverity(HuiSeverity.error);

  int get warningCount => _countSeverity(HuiSeverity.warning);

  int get infoCount => _countSeverity(HuiSeverity.info);

  List<HuiIssue> issuesFor(String componentId) => _issues
      .where((HuiIssue issue) => issue.componentId == componentId)
      .toList();

  /// Every issue whose path names element [index] specifically — the preview
  /// counterpart of [issuesFor], since a preview element has no id to key by.
  List<HuiIssue> issuesForPreviewElement(int index) {
    final String prefix = 'elements[$index]';
    return _issues
        .where(
          (HuiIssue issue) =>
              issue.path == prefix || issue.path.startsWith('$prefix.'),
        )
        .toList();
  }

  /// Clickable hitbox pairs that intersect in the resolved scene. Nearest-hit
  /// arbitration can hide one behind another, so validation receives the list.
  List<CanvasOverlap> get overlapPairs =>
      _scene?.overlaps ?? const <CanvasOverlap>[];

  @override
  HuiCatalogs get catalogs => _catalogs;

  @override
  ImageLibrary? get images => _images;

  /// Swaps in the catalogs once they finish loading and re-runs validation.
  void setCatalogs(HuiCatalogs value) {
    _catalogs = value;
    // The emoji resolver folds the catalog in, so its memo dies with the old
    // catalog snapshot.
    _emojiCache = null;
    _refreshIssues();
    _notify();
  }

  void refreshValidation() {
    _refreshIssues();
    _notify();
  }

  /// Recomputes [_issues] against whichever document is active. The active
  /// kind's adapter never throws, so every call site can run this
  /// unconditionally.
  void _refreshIssues() {
    _issues = _docType.validate(this);
  }

  // --- history --------------------------------------------------------------

  UndoStack get undo => _undo;

  bool get canUndo => _undo.canUndo;

  bool get canRedo => _undo.canRedo;

  String? get undoLabel => _localizeHistoryLabel(_undo.undoLabel);

  String? get redoLabel => _localizeHistoryLabel(_undo.redoLabel);

  String? _localizeHistoryLabel(String? label) {
    if (label == null) return null;
    if (_directHistoryLabels.contains(label)) return huiText(label);
    final RegExpMatch? addedFrames = RegExp(
      r'^frames\.add:(\d+)$',
    ).firstMatch(label);
    if (addedFrames != null) {
      final int count = int.parse(addedFrames.group(1)!);
      return huiPlural(
        'history.add-frames',
        count,
        oneEnglish: 'add {count} frame',
        otherEnglish: 'add {count} frames',
      );
    }
    final RegExpMatch? counted = RegExp(
      r'^(delete|depth|move|nudge) (\d+) components$',
    ).firstMatch(label);
    if (counted != null) {
      final int count = int.parse(counted.group(2)!);
      return switch (counted.group(1)) {
        'delete' => huiPlural(
          'history.delete-components',
          count,
          oneEnglish: 'delete {count} component',
          otherEnglish: 'delete {count} components',
        ),
        'depth' => huiPlural(
          'history.depth-components',
          count,
          oneEnglish: 'change depth of {count} component',
          otherEnglish: 'change depth of {count} components',
        ),
        'move' => huiPlural(
          'history.move-components',
          count,
          oneEnglish: 'move {count} component',
          otherEnglish: 'move {count} components',
        ),
        _ => huiPlural(
          'history.nudge-components',
          count,
          oneEnglish: 'nudge {count} component',
          otherEnglish: 'nudge {count} components',
        ),
      };
    }
    final RegExpMatch? add = RegExp(r'^add (.+)$').firstMatch(label);
    if (add != null) {
      return huiText('add {type}', <String, Object?>{
        'type': _localizeHistorySubject(add.group(1)!),
      });
    }
    final RegExpMatch? randomize = RegExp(
      r'^Randomize (.+)$',
    ).firstMatch(label);
    if (randomize != null) {
      return huiText('Randomize {type}', <String, Object?>{
        'type': _localizeHistorySubject(randomize.group(1)!),
      });
    }
    final RegExpMatch? component = RegExp(
      r'^(depth|duplicate|delete|move|nudge|rename) (.+?)( hitbox)?$',
    ).firstMatch(label);
    if (component != null) {
      final String operation = component.group(1)!;
      final String id = component.group(2)!;
      if (component.group(3) != null) {
        return huiText('move {id} hitbox', <String, Object?>{'id': id});
      }
      return switch (operation) {
        'duplicate' => huiText('duplicate {id}', <String, Object?>{'id': id}),
        'delete' => huiText('delete {id}', <String, Object?>{'id': id}),
        'depth' => huiText('change depth of {id}', <String, Object?>{'id': id}),
        'move' => huiText('move {id}', <String, Object?>{'id': id}),
        'nudge' => huiText('nudge {id}', <String, Object?>{'id': id}),
        _ => huiText('rename {id}', <String, Object?>{'id': id}),
      };
    }
    final RegExpMatch? hitbox = RegExp(
      r'^(link|detach) (.+) hitbox$',
    ).firstMatch(label);
    if (hitbox != null) {
      return hitbox.group(1) == 'link'
          ? huiText('link {id} hitbox', <String, Object?>{
              'id': hitbox.group(2),
            })
          : huiText('detach {id} hitbox', <String, Object?>{
              'id': hitbox.group(2),
            });
    }
    final RegExpMatch? imported = RegExp(r'^import (.+)$').firstMatch(label);
    if (imported != null) {
      return huiText('import {id}', <String, Object?>{'id': imported.group(1)});
    }
    final RegExpMatch? copied = RegExp(
      r'^copy (true|false) icon to (true|false)$',
    ).firstMatch(label);
    if (copied != null) {
      return huiText('copy {from} icon to {to}', <String, Object?>{
        'from': _localizeHistorySubject(copied.group(1)!),
        'to': _localizeHistorySubject(copied.group(2)!),
      });
    }
    return huiText(label);
  }

  String _localizeHistorySubject(String subject) => switch (subject) {
    'button' => huiText('button'),
    'toggle' => huiText('toggle'),
    'decoration' => huiText('decoration'),
    'element' => huiText('element'),
    'frame' => huiText('frame'),
    'menu' => huiText('menu'),
    'container preview' => huiText('container preview'),
    'hologram' => huiText('hologram'),
    'animation' => huiText('animation'),
    'scoreboard' => huiText('scoreboard'),
    'MOTD' => huiText('MOTD'),
    'emoji' => huiText('emoji'),
    'bubble style' => huiText('bubble style'),
    'tablist' => huiText('tablist'),
    'real drops' => huiText('real drops'),
    'component' => huiText('component'),
    'panel' => huiText('panel'),
    'cell' => huiText('cell'),
    'slot' => huiText('slot'),
    'label' => huiText('label'),
    'true' => huiTextKey('history.boolean.true', 'true'),
    'false' => huiTextKey('history.boolean.false', 'false'),
    _ => subject,
  };

  /// The only write path into a menu document. A no-op while [isPreviewDoc] is
  /// true; that document is written through [mutatePreview].
  void mutate(String label, void Function(HuiMenu menu) fn) {
    if (!_menuWritable) return;
    final String before = _snapshot();
    final String beforeSemantic = encodeHuiMenu(_menu);
    final int countBefore = _menu.components.length;
    fn(_menu);
    final String afterSemantic = encodeHuiMenu(_menu);
    if (afterSemantic == beforeSemantic) {
      _notify();
      return;
    }
    if (_preservedMenuSource != null) {
      _menu = decodeHuiMenu(afterSemantic);
    }
    // Adding or removing a component is a step in its own right, however fast
    // it follows the last one; field edits are not.
    _pushUndo(label, before, coalesce: countBefore == _menu.components.length);
    _afterChange();
  }

  /// Replaces the whole document in one undoable step. A no-op while
  /// [isPreviewDoc] is true; see [mutate].
  void replaceMenu(String label, HuiMenu next) {
    if (!_menuWritable) return;
    final String before = _snapshot();
    _menu = next;
    _pruneSelection();
    _pushUndo(label, before, coalesce: false);
    _afterChange();
  }

  // --- container-preview document -------------------------------------------

  /// The only write path into a container-preview document, and the exact twin
  /// of [mutate]: snapshot, run, compare, push one undo entry, revalidate,
  /// autosave, notify. A no-op while [isPreviewDoc] is false.
  ///
  /// The two paths are deliberately separate rather than one generic method
  /// over `Object`: the callbacks take different models, and a single entry
  /// point would have to be typed loosely enough that a menu edit could be
  /// handed a preview document at runtime.
  void mutatePreview(String label, void Function(HuiPreviewDoc doc) fn) {
    final HuiPreviewDoc? doc = _previewDoc;
    if (doc == null) return;
    final String before = _snapshot();
    final int countBefore = doc.elements.length;
    fn(doc);
    final String after = _snapshot();
    if (after == before) {
      _notify();
      return;
    }
    // Edited in place, so nothing assigned [_previewDoc] and the revision has
    // to be moved by hand — the counter is what every consumer memoizes on.
    _previewRevision++;
    // Same rule as [mutate]: adding or removing an element is its own step
    // however fast it follows the last one, a field edit is not.
    _pushUndo(label, before, coalesce: countBefore == doc.elements.length);
    _prunePreviewSelection();
    _afterChange();
  }

  /// Edits one element by index — the preview counterpart of [editComponent].
  /// An index the document does not have is ignored, so a stale pointer gesture
  /// can never write to the wrong element.
  void editPreviewElement(
    int index,
    String label,
    void Function(HuiPreviewElement element) fn,
  ) {
    final HuiPreviewDoc? doc = _previewDoc;
    if (doc == null || index < 0 || index >= doc.elements.length) return;
    mutatePreview(label, (HuiPreviewDoc edited) {
      if (index < edited.elements.length) fn(edited.elements[index]);
    });
  }

  /// Replaces the whole container-preview document in one undoable step.
  void replacePreviewDoc(String label, HuiPreviewDoc next) {
    if (!isPreviewDoc) return;
    final String before = _snapshot();
    _setPreviewDoc(next);
    _pushUndo(label, before, coalesce: false);
    _prunePreviewSelection();
    _afterChange();
  }

  // --- gloss documents ------------------------------------------------------

  /// The only write path into a Gloss document (hologram, animation or
  /// scoreboard) — the exact twin of [mutatePreview]: snapshot, run, compare,
  /// push one undo entry, revalidate, autosave, notify. A no-op while
  /// [isGlossDoc] is false.
  void mutateGloss(String label, void Function(GlossDoc doc) fn) {
    final GlossDoc? doc = _glossDoc;
    if (doc == null || !isGlossDoc) return;
    final String before = _snapshot();
    fn(doc);
    final String after = _snapshot();
    if (after == before) {
      _notify();
      return;
    }
    // Edited in place, so nothing assigned [_glossDoc] and the revision has
    // to be moved by hand — the counter is what the surfaces memoize on.
    _glossRevision++;
    _animationCache = null;
    _emojiCache = null;
    _pushUndo(label, before);
    _afterChange();
  }

  /// Typed arm of [mutateGloss] for the hologram inspector and surface; a
  /// no-op while the active document is not a hologram.
  void mutateHologram(String label, void Function(GlossHologramDoc doc) fn) {
    final GlossHologramDoc? doc = hologramDoc;
    if (doc == null) return;
    mutateGloss(label, (GlossDoc _) => fn(doc));
  }

  /// Typed arm of [mutateGloss] for the animation inspector and surface; a
  /// no-op while the active document is not an animation.
  void mutateAnimation(String label, void Function(GlossAnimationDoc doc) fn) {
    final GlossAnimationDoc? doc = animationDoc;
    if (doc == null) return;
    mutateGloss(label, (GlossDoc _) => fn(doc));
  }

  /// Typed arm of [mutateGloss] for the scoreboard inspector and surface; a
  /// no-op while the active document is not a scoreboard.
  void mutateScoreboard(
    String label,
    void Function(GlossScoreboardDoc doc) fn,
  ) {
    final GlossScoreboardDoc? doc = scoreboardDoc;
    if (doc == null) return;
    mutateGloss(label, (GlossDoc _) => fn(doc));
  }

  /// Typed arm of [mutateGloss] for the MOTD inspector and surface; a no-op
  /// while the active document is not a MOTD.
  void mutateMotd(String label, void Function(GlossMotdDoc doc) fn) {
    final GlossMotdDoc? doc = motdDoc;
    if (doc == null) return;
    mutateGloss(label, (GlossDoc _) => fn(doc));
  }

  /// Typed arm of [mutateGloss] for the emoji inspector and surface; a no-op
  /// while the active document is not an emoji.
  void mutateEmoji(String label, void Function(GlossEmojiDoc doc) fn) {
    final GlossEmojiDoc? doc = emojiDoc;
    if (doc == null) return;
    mutateGloss(label, (GlossDoc _) => fn(doc));
  }

  /// Typed arm of [mutateGloss] for the bubble-style inspector and surface;
  /// a no-op while the active document is not a bubble style.
  void mutateBubbleStyle(
    String label,
    void Function(GlossBubbleStyleDoc doc) fn,
  ) {
    final GlossBubbleStyleDoc? doc = bubbleStyleDoc;
    if (doc == null) return;
    mutateGloss(label, (GlossDoc _) => fn(doc));
  }

  /// Typed arm of [mutateGloss] for the tablist inspector and surface; a
  /// no-op while the active document is not a tablist.
  void mutateTablist(String label, void Function(GlossTablistDoc doc) fn) {
    final GlossTablistDoc? doc = tablistDoc;
    if (doc == null) return;
    mutateGloss(label, (GlossDoc _) => fn(doc));
  }

  void mutateRealDropSettings(
    String label,
    void Function(GlossRealDropSettingsDoc doc) fn,
  ) {
    final GlossRealDropSettingsDoc? doc = realDropSettingsDoc;
    if (doc == null) return;
    mutateGloss(label, (GlossDoc _) => fn(doc));
  }

  /// Replaces the whole Gloss document in one undoable step.
  void replaceGlossDoc(String label, GlossDoc next) {
    if (!isGlossDoc) return;
    final String before = _snapshot();
    _setGlossDoc(next);
    _animationCache = null;
    _emojiCache = null;
    _pushUndo(label, before, coalesce: false);
    _afterChange();
  }

  /// Decoded animation documents by runtime id, rebuilt lazily after any
  /// workspace or Gloss-document change. An unreadable document maps to null
  /// so it is only decoded once per generation.
  Map<String, GlossAnimationDoc?>? _animationCache;

  late final GlossAnimationResolver _workspaceAnimations =
      _StoreAnimationResolver(this);

  /// The workspace's animation documents, resolved for `|animation.<id>|`
  /// rendering and reference validation. Before the animation kind exists in
  /// the registry this resolves nothing.
  @override
  GlossAnimationResolver get workspaceAnimations => _workspaceAnimations;

  /// Merged emoji entries, rebuilt lazily after any workspace, Gloss-document
  /// or catalog change: the shipped catalog first, workspace emoji documents
  /// layered over it by id.
  List<GlossEmojiEntry>? _emojiCache;

  late final GlossEmojiResolver _workspaceEmoji = _StoreEmojiResolver(this);

  /// The emoji available to text rendering: shipped catalog entries with the
  /// workspace's emoji documents overriding by id, sorted the way
  /// `EmojiService.rebuild` sorts.
  @override
  GlossEmojiResolver get workspaceEmoji => _workspaceEmoji;

  List<GlossEmojiEntry> _emojiEntries() {
    final List<GlossEmojiEntry>? cached = _emojiCache;
    if (cached != null) return cached;
    final Map<String, GlossEmojiEntry> byId = <String, GlossEmojiEntry>{
      for (final GlossEmojiEntry entry in _catalogs.emoji) entry.id: entry,
    };
    final WorkspaceDocKind? kind = DocumentTypeRegistry.byWireKind(
      'emoji',
    )?.kind;
    if (kind != null) {
      for (final WorkspaceDoc doc in workspace.docs) {
        final String? id = doc.runtimeId;
        if (doc.kind != kind || id == null) continue;
        // The stored JSON lags the live model by the autosave debounce, so
        // the open emoji resolves from the model itself below.
        GlossEmojiDoc? model;
        if (doc.id == workspace.activeId && _glossDoc is GlossEmojiDoc) {
          model = _glossDoc! as GlossEmojiDoc;
        } else {
          try {
            model = decodeGlossEmojiDoc(doc.json);
          } catch (_) {
            // An unreadable document substitutes nothing, exactly like a
            // file the plugin's registry failed to parse.
            continue;
          }
        }
        byId[id] = GlossEmojiEntry(
          id: id,
          trigger: model.trigger,
          glyph: model.resolvedGlyph,
          enabled: model.enabled,
          fromWorkspace: true,
        );
      }
    }
    final List<GlossEmojiEntry> built = byId.values.toList()
      ..sort((GlossEmojiEntry a, GlossEmojiEntry b) => a.id.compareTo(b.id));
    _emojiCache = built;
    return built;
  }

  Map<String, GlossAnimationDoc?> _animationDocs() {
    final Map<String, GlossAnimationDoc?>? cached = _animationCache;
    if (cached != null) return cached;
    final Map<String, GlossAnimationDoc?> built = <String, GlossAnimationDoc?>{
      for (final MapEntry<String, GlossAnimationDoc Function()> entry
          in shippedGlossAnimationBuilders.entries)
        entry.key: entry.value(),
    };
    final WorkspaceDocKind? kind = DocumentTypeRegistry.byWireKind(
      'animation',
    )?.kind;
    if (kind != null) {
      for (final WorkspaceDoc doc in workspace.docs) {
        final String? id = doc.runtimeId;
        if (doc.kind != kind || id == null) continue;
        // The stored JSON lags the live model by the autosave debounce, so
        // the open animation resolves from the model itself below.
        if (doc.id == workspace.activeId && _glossDoc is GlossAnimationDoc) {
          built[id] = _glossDoc! as GlossAnimationDoc;
          continue;
        }
        try {
          built[id] = decodeGlossAnimationDoc(doc.json);
        } catch (_) {
          built[id] = null;
        }
      }
    }
    _animationCache = built;
    return built;
  }

  /// Index into `previewDoc.elements` of the selected element, or null.
  int? get previewSelectedIndex => _previewSelection;

  HuiPreviewElement? get previewSelectedElement {
    final int? index = _previewSelection;
    final HuiPreviewDoc? doc = _previewDoc;
    if (index == null || doc == null || index >= doc.elements.length) {
      return null;
    }
    return doc.elements[index];
  }

  /// Selects one element by index; null clears. An index the document does not
  /// have is ignored, the rule [select] applies to an unknown component id.
  void selectPreviewElement(int? index) {
    if (index != null) {
      final HuiPreviewDoc? doc = _previewDoc;
      if (doc == null || index < 0 || index >= doc.elements.length) return;
    }
    if (_previewSelection == index) return;
    _previewSelection = index;
    _notify();
  }

  /// Elements are addressed by position, so a step that shortened the list can
  /// leave the selection pointing past the end. Dropped rather than clamped:
  /// silently re-selecting a different element is worse than selecting none.
  ///
  /// This only catches the "now out of range" case. It cannot fix DRIFT — a
  /// selection that stays numerically in range but now names a different
  /// element because something was removed or moved earlier in the list —
  /// because [mutatePreview] runs this generically after every mutation and
  /// has no idea which index (if any) was removed or moved. [deletePreviewElement]
  /// and [reorderPreviewElement] compute the correct remapped index BEFORE
  /// calling [mutatePreview] and re-apply it with [selectPreviewElement]
  /// afterward, which is what actually keeps the selection glued to the
  /// element it named rather than to a numeric slot.
  void _prunePreviewSelection() {
    final int? index = _previewSelection;
    if (index == null) return;
    final HuiPreviewDoc? doc = _previewDoc;
    if (doc != null && index < doc.elements.length) return;
    _previewSelection = null;
  }

  /// Where selection [p] lands after element [removedIndex] is deleted: gone
  /// if it named the removed element, shifted down by one if it named
  /// anything after it, unchanged otherwise.
  static int? _remapSelectionAfterRemoval(int? p, int removedIndex) {
    if (p == null) return null;
    if (p == removedIndex) return null;
    return p > removedIndex ? p - 1 : p;
  }

  /// Where selection [p] lands after the element at [from] is moved to [to]
  /// via a remove-then-insert (what [reorderPreviewElement] does): the moved
  /// element's own selection follows it to [to]; everything strictly between
  /// the two endpoints shifts one slot the other way; everything else is
  /// unaffected. Deliberately NOT "select whatever moved" — a reorder
  /// triggered on a row that is not the current selection must leave the
  /// actual selection exactly where it visually is, which may or may not be
  /// the row that moved.
  static int? _remapSelectionAfterMove(int? p, int from, int to) {
    if (p == null) return null;
    if (p == from) return to;
    if (from < to) {
      // Moved later: everything strictly between shifts one earlier.
      return (p > from && p <= to) ? p - 1 : p;
    }
    // Moved earlier: everything strictly between shifts one later.
    return (p >= to && p < from) ? p + 1 : p;
  }

  // --- preview element list operations ---------------------------------

  /// Appends a new element of [type] (defaulting to `cell` for an unknown
  /// name) and selects it — the preview counterpart of [addComponent]. A
  /// no-op while [isPreviewDoc] is false.
  void addPreviewElement(String type) {
    final HuiPreviewDoc? doc = _previewDoc;
    if (doc == null) return;
    final String normalized = previewElementTypes.contains(type)
        ? type
        : 'cell';
    final HuiPreviewElement element = createDefaultPreviewElement(normalized);
    final int newIndex = doc.elements.length;
    mutatePreview('add $normalized', (HuiPreviewDoc edited) {
      edited.elements.add(element);
    });
    selectPreviewElement(newIndex);
  }

  /// Deep-copies element [index] directly after itself and selects the copy —
  /// the preview counterpart of [duplicateComponent].
  void duplicatePreviewElement(int index) {
    final HuiPreviewDoc? doc = _previewDoc;
    if (doc == null || index < 0 || index >= doc.elements.length) return;
    final HuiPreviewElement copy = doc.elements[index].copy();
    mutatePreview('duplicate element', (HuiPreviewDoc edited) {
      if (index < edited.elements.length) {
        edited.elements.insert(index + 1, copy);
      }
    });
    selectPreviewElement(index + 1);
  }

  /// Moves element [index] to [newIndex] — the preview counterpart of
  /// [reorder]. Click order is paint order for these elements (later entries
  /// draw in front at equal `z`), so reordering is a document edit like it is
  /// for a menu component.
  ///
  /// The selection is remapped by position, not forced onto whichever element
  /// moved: the row tools sit on every row, so this can just as easily be
  /// called on a row that is not the current selection, and that selection
  /// must stay exactly where it visually is.
  void reorderPreviewElement(int index, int newIndex) {
    final HuiPreviewDoc? doc = _previewDoc;
    if (doc == null) return;
    final int length = doc.elements.length;
    if (index < 0 || index >= length) return;
    final int clamped = newIndex.clamp(0, length - 1);
    if (clamped == index) return;
    final int? remapped = _remapSelectionAfterMove(
      _previewSelection,
      index,
      clamped,
    );
    mutatePreview('reorder element', (HuiPreviewDoc edited) {
      final HuiPreviewElement moved = edited.elements.removeAt(index);
      edited.elements.insert(clamped, moved);
    });
    selectPreviewElement(remapped);
  }

  /// Removes element [index] — the preview counterpart of [deleteComponent].
  /// Delete lives only here (not on the card surface), so it always goes
  /// through the rail's own confirm step.
  ///
  /// Deleting an earlier element shifts every later one down by one position;
  /// without remapping, a selection on one of them would silently keep
  /// pointing at its old numeric slot — now occupied by a different element —
  /// while the inspector, keyed on that same index, would go on showing (and
  /// editing) draft state for the element that used to be there.
  void deletePreviewElement(int index) {
    final HuiPreviewDoc? doc = _previewDoc;
    if (doc == null || index < 0 || index >= doc.elements.length) return;
    final int? remapped = _remapSelectionAfterRemoval(_previewSelection, index);
    mutatePreview('delete element', (HuiPreviewDoc edited) {
      if (index < edited.elements.length) edited.elements.removeAt(index);
    });
    selectPreviewElement(remapped);
  }

  /// Canvas drags call [beginDrag] on pointer down and [endDrag] on pointer up
  /// so the whole gesture collapses into a single undo step.
  void beginDrag() {
    _dragActive = true;
    _dragPushed = false;
    _clearCoalesce();
  }

  void endDrag() {
    _dragActive = false;
    _dragPushed = false;
    _clearCoalesce();
  }

  bool performUndo() {
    if (!_docType.undoable) return false;
    _clearCoalesce();
    final String? restored = _undo.undo(_snapshot());
    if (restored == null) return false;
    return _applySnapshot(restored);
  }

  bool performRedo() {
    if (!_docType.undoable) return false;
    _clearCoalesce();
    final String? restored = _undo.redo(_snapshot());
    if (restored == null) return false;
    return _applySnapshot(restored);
  }

  // --- component operations -------------------------------------------------

  /// Adds a component of [type] with sensible defaults at the first free slot
  /// and selects it. Returns the new id.
  String? addComponent(String type, {Vec3? offset, String? id}) {
    final String normalized = huiComponentTypes.contains(type)
        ? type
        : 'decoration';
    return addComponentData(
      createDefaultComponentData(normalized),
      offset: offset,
      id: id ?? normalized,
    );
  }

  String? addComponentData(HuiComponentData data, {Vec3? offset, String? id}) {
    final String normalized = huiComponentTypes.contains(data.type)
        ? data.type
        : 'decoration';
    final String newId = uniqueComponentId(id ?? normalized, _takenIds());
    final Vec3 place = offset ?? nextFreeOffset(_menu);
    _selection
      ..clear()
      ..add(newId);
    mutate('add $normalized', (HuiMenu menu) {
      menu.components.add(HuiComponent(newId, place, data.copy()));
    });
    return newId;
  }

  /// Deep-copies [id] one slot below the original and selects the copy.
  String? duplicateComponent(String id) {
    final HuiComponent? source = _menu.componentById(id);
    if (source == null) return null;
    final int index = _menu.indexOfComponent(id);
    final String newId = _duplicateId(source.id, _takenIds());
    final HuiComponent copy = source.copy()
      ..id = newId
      ..offset = Vec3(
        source.offset.x,
        _round(source.offset.y - huiPlacementStep),
        source.offset.z,
      );
    _selection
      ..clear()
      ..add(newId);
    mutate('duplicate $id', (HuiMenu menu) {
      menu.components.insert(index + 1, copy);
    });
    return newId;
  }

  /// Deep-copies every selected component, inserting each copy directly after
  /// its source, and selects the copies. One undo step.
  ///
  /// Copies land exactly on their sources. The caller is usually an alt-drag
  /// that is about to move them, and a placement nudge would fight the gesture.
  List<String> duplicateSelection() {
    if (_selection.isEmpty) return const <String>[];
    final Set<String> taken = _takenIds();
    final List<String> created = <String>[];
    final List<HuiComponent> next = <HuiComponent>[];
    for (final HuiComponent component in _menu.components) {
      next.add(component);
      if (!_selection.contains(component.id)) continue;
      final String copyId = _duplicateId(component.id, taken);
      taken.add(copyId);
      created.add(copyId);
      next.add(component.copy()..id = copyId);
    }
    if (created.isEmpty) return const <String>[];
    _selection
      ..clear()
      ..addAll(created);
    mutate('duplicate selection', (HuiMenu menu) {
      menu.components
        ..clear()
        ..addAll(next);
    });
    return created;
  }

  void deleteComponent(String id) {
    final int index = _menu.indexOfComponent(id);
    if (index < 0) return;
    mutate('delete $id', (HuiMenu menu) {
      // removeAt, never removeWhere: duplicate ids are legal and deleting one
      // row must never take its namesakes with it.
      menu.components.removeAt(index);
    });
    // Namesakes keep the id addressable, so only a truly gone id is dropped.
    if (_menu.componentById(id) != null) return;
    _togglePreviewState.remove(id);
    if (_selection.remove(id)) _notify();
  }

  /// Deletes one row per id in [ids], in a single undo step.
  ///
  /// Index-based for the same reason [deleteComponent] is: duplicate ids are
  /// legal in the document even though the runtime ignores later namesakes,
  /// and a selection is a set, so it can name a duplicated id exactly once. An
  /// id-keyed bulk delete therefore removed rows the user never selected —
  /// which is what the canvas used to do while the rail and the shell did not.
  ///
  /// Indices are resolved against the list as it stands and removed descending,
  /// because re-resolving each id after a removal reads a list that has already
  /// shifted.
  void deleteComponents(Iterable<String> ids) {
    final List<String> wanted = ids.toList(growable: false);
    if (wanted.isEmpty) return;
    if (wanted.length == 1) {
      deleteComponent(wanted.single);
      return;
    }

    final Set<int> doomed = <int>{};
    for (final String id in wanted) {
      for (int i = 0; i < _menu.components.length; i++) {
        // First index not already claimed, so a request naming one id twice
        // takes two rows rather than the same row twice.
        if (_menu.components[i].id == id && doomed.add(i)) break;
      }
    }
    if (doomed.isEmpty) return;

    final List<int> descending = doomed.toList()
      ..sort((int a, int b) => b.compareTo(a));
    mutate('delete ${descending.length} components', (HuiMenu menu) {
      for (final int index in descending) {
        menu.components.removeAt(index);
      }
    });

    // Namesakes keep an id addressable, so only truly gone ids are dropped —
    // the rule [deleteComponent] applies one at a time.
    for (final String id in wanted) {
      if (_menu.componentById(id) == null) _togglePreviewState.remove(id);
    }
    final int before = _selection.length;
    _pruneSelection();
    if (_selection.length != before) _notify();
  }

  /// Order is serialized, controls rendering ties, and breaks equal-distance
  /// click intersections, so reordering is a real document change.
  void reorder(String id, int newIndex) {
    final int index = _menu.indexOfComponent(id);
    if (index < 0) return;
    final int target = newIndex.clamp(0, _menu.components.length - 1);
    if (target == index) return;
    mutate('reorder components', (HuiMenu menu) {
      final HuiComponent component = menu.components.removeAt(index);
      menu.components.insert(target, component);
    });
  }

  /// Relative move (arrow-key nudge). Only the axes [delta] actually touches
  /// are snapped: an authored `z` of 0.13 must survive a vertical nudge, the
  /// same way it survives an xy drag on the canvas.
  void moveComponent(String id, Vec3 delta) {
    final HuiComponent? component = _menu.componentById(id);
    if (component == null) return;
    _applyOffset(
      id,
      Vec3(
        delta.x == 0
            ? component.offset.x
            : snapValue(component.offset.x + delta.x),
        delta.y == 0
            ? component.offset.y
            : snapValue(component.offset.y + delta.y),
        delta.z == 0
            ? component.offset.z
            : snapValue(component.offset.z + delta.z),
      ),
    );
  }

  /// Absolute move; snaps all three axes because the caller is setting all
  /// three.
  void setComponentOffset(String id, Vec3 offset) =>
      _applyOffset(id, snapVec(offset));

  void setHitboxOffset(String id, Vec3 offset) {
    final HuiComponent? component = _menu.componentById(id);
    if (component == null || component.data is HuiDecorationData) return;
    mutate('move $id hitbox', (HuiMenu menu) {
      final HuiComponent? edited = menu.componentById(id);
      final HuiComponentData? rawData = edited?.data;
      final HuiHitbox? existing = switch (rawData) {
        HuiButtonData(:final HuiHitbox? hitbox) => hitbox,
        HuiToggleData(:final HuiHitbox? hitbox) => hitbox,
        _ => null,
      };
      if (rawData == null || rawData is HuiDecorationData) return;
      final HuiHitbox hitbox = existing ?? HuiHitbox();
      hitbox.offset = offset.copy();
      final HuiHitbox? next = hitbox.isDefault ? null : hitbox;
      switch (rawData) {
        case HuiButtonData():
          rawData.hitbox = next;
        case HuiToggleData():
          rawData.hitbox = next;
        case HuiDecorationData():
          break;
      }
    });
  }

  void setHitboxAnchor(String id, HuiHitboxAnchor anchor) {
    final HuiComponent? component = _menu.componentById(id);
    final HuiComponentData? rawData = component?.data;
    final HuiHitbox? currentHitbox = switch (rawData) {
      HuiButtonData(:final HuiHitbox? hitbox) => hitbox,
      HuiToggleData(:final HuiHitbox? hitbox) => hitbox,
      _ => null,
    };
    if (rawData == null || rawData is HuiDecorationData) return;
    final HuiHitboxAnchor currentAnchor =
        currentHitbox?.anchor ?? HuiHitboxAnchor.button;
    if (currentAnchor == anchor) return;
    final CanvasItem? current = _runtimeCanvasItem(_menu, id);
    mutate(
      anchor == HuiHitboxAnchor.button
          ? 'link $id hitbox'
          : 'detach $id hitbox',
      (HuiMenu menu) {
        final HuiComponent? edited = menu.componentById(id);
        final HuiComponentData? editedData = edited?.data;
        final HuiHitbox? existing = switch (editedData) {
          HuiButtonData(:final HuiHitbox? hitbox) => hitbox,
          HuiToggleData(:final HuiHitbox? hitbox) => hitbox,
          _ => null,
        };
        if (editedData == null || editedData is HuiDecorationData) return;
        final HuiHitbox hitbox = existing ?? HuiHitbox();
        hitbox
          ..anchor = anchor
          ..offset = Vec3.zero();
        switch (editedData) {
          case HuiButtonData():
            editedData.hitbox = hitbox;
          case HuiToggleData():
            editedData.hitbox = hitbox;
          case HuiDecorationData():
            break;
        }
        final CanvasItem? base = _runtimeCanvasItem(menu, id);
        if (current != null && base != null) {
          hitbox.offset = Vec3(
            _round(current.hitbox.x - base.hitbox.x),
            _round(current.hitbox.y - base.hitbox.y),
            _round(current.hitboxDepth - base.hitboxDepth),
          );
        }
        if (hitbox.isDefault) {
          switch (editedData) {
            case HuiButtonData():
              editedData.hitbox = null;
            case HuiToggleData():
              editedData.hitbox = null;
            case HuiDecorationData():
              break;
          }
        }
      },
    );
  }

  /// Moves several components in ONE undo step.
  ///
  /// Offsets are taken verbatim: a group drag snaps the component under the
  /// pointer and applies that snapped delta to the rest, so snapping here a
  /// second time would tear the group apart.
  void setOffsets(String label, Map<String, Vec3> offsets) {
    if (offsets.isEmpty) return;
    mutate(label, (HuiMenu menu) {
      for (final MapEntry<String, Vec3> entry in offsets.entries) {
        menu.componentById(entry.key)?.offset = entry.value.copy();
      }
    });
  }

  void _applyOffset(String id, Vec3 target) {
    final HuiComponent? component = _menu.componentById(id);
    if (component == null || component.offset == target) return;
    mutate('move $id', (HuiMenu menu) {
      menu.componentById(id)?.offset = target;
    });
  }

  /// Inspector edits: mutate one component by id.
  void editComponent(
    String id,
    String label,
    void Function(HuiComponent component) fn,
  ) {
    if (_menu.componentById(id) == null) return;
    mutate(label, (HuiMenu menu) {
      final HuiComponent? component = menu.componentById(id);
      if (component != null) fn(component);
    });
  }

  /// Renames a component and carries the selection and preview state across.
  bool renameComponent(String id, String nextId) {
    final HuiComponent? component = _menu.componentById(id);
    if (component == null) return false;
    final String sanitized = sanitizeComponentId(nextId);
    if (sanitized == id) return true;
    final bool? preview = _togglePreviewState.remove(id);
    if (preview != null) _togglePreviewState[sanitized] = preview;
    // Remapped in place: the renamed component keeps its position in the
    // selection order, so the primary does not jump to it.
    if (_selection.contains(id)) {
      final List<String> remapped = <String>[
        for (final String selected in _selection)
          selected == id ? sanitized : selected,
      ];
      _selection
        ..clear()
        ..addAll(remapped);
    }
    mutate('rename $id', (HuiMenu menu) {
      menu.componentById(id)?.id = sanitized;
    });
    return true;
  }

  double snapValue(double value) {
    if (!value.isFinite) return 0;
    if (!_snapToGrid || _gridSize <= 0) return _round(value);
    return _round((value / _gridSize).roundToDouble() * _gridSize);
  }

  Vec3 snapVec(Vec3 value) =>
      Vec3(snapValue(value.x), snapValue(value.y), snapValue(value.z));

  // --- import / export ------------------------------------------------------

  /// The active document's JSON, in whichever shape [docKind] says it is.
  String exportJson() => _docType.exportJson(this);

  String formattedJson() => _docType.formattedJson(this);

  /// Replaces the active document with [content], auto-detecting whether it
  /// is a Gloss menu or a container-preview document via
  /// [looksLikePreviewDoc]. Only malformed JSON is refused: a well-formed
  /// document of either shape always replaces the current one, reporting
  /// through [onInfo]. A parse failure reports through [onError] and leaves
  /// the current document untouched.
  void importJson(String name, String content) {
    if (isPanelDoc) {
      _fail('Open a menu or preview document before importing runtime JSON.');
      return;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      _fail('That file could not be read as JSON.');
      return;
    }
    if (looksLikePreviewDoc(decoded)) {
      _importPreviewJson(name, content);
      return;
    }
    final GlossDocumentTypeAdapter? gloss = _glossKindOf(decoded);
    if (gloss != null) {
      _importGlossJson(gloss, name, content);
    } else {
      _importMenuJson(name, content);
    }
  }

  /// The Gloss kind [decoded] looks like, or null when it is a menu or
  /// nothing recognizable. The kinds' shape checks are mutually exclusive
  /// (anchor / frames / title+lines under a versioned envelope), so registry
  /// order does not decide anything here.
  GlossDocumentTypeAdapter? _glossKindOf(Object? decoded) {
    for (final DocumentTypeAdapter adapter in DocumentTypeRegistry.all) {
      if (adapter is GlossDocumentTypeAdapter && adapter.looksLike(decoded)) {
        return adapter;
      }
    }
    return null;
  }

  /// Imports [content] into a new workspace document. This is the safe default
  /// for global drag and drop; replacing the active document remains an
  /// explicit action in the import dialog.
  bool importJsonAsNewDocument(String name, String content) {
    if (!workspace.canWrite) {
      _failWorkspaceProtected();
      return false;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      _fail('That file could not be read as JSON.');
      return false;
    }
    final String requestedId = menuIdFromFileName(name);
    if (looksLikePreviewDoc(decoded)) {
      return _importPreviewAsNewDocument(requestedId, content);
    }
    final GlossDocumentTypeAdapter? gloss = _glossKindOf(decoded);
    if (gloss != null) {
      return _importGlossAsNewDocument(gloss, requestedId, content);
    }
    final String runtimeId = _availableRuntimeId(
      DocumentTypes.menu.kind,
      requestedId,
    );
    final bool created = newMenuDocumentFromJson(
      name: runtimeId,
      runtimeId: runtimeId,
      json: content,
    );
    if (created) {
      _inform('Imported {id} as a new menu.', <String, Object?>{
        'id': runtimeId,
      });
    }
    return created;
  }

  bool _importGlossAsNewDocument(
    GlossDocumentTypeAdapter type,
    String requestedId,
    String content,
  ) {
    final GlossDoc parsed;
    try {
      parsed = type.decodeDoc(content);
    } on HuiFormatException catch (error) {
      _failResolved(
        () => huiText('{message} (at {path})', <String, Object?>{
          'message': error.message,
          'path': error.path,
        }),
      );
      return false;
    } catch (_) {
      _failResolved(
        () => huiText(
          'That file could not be read as a {document} document.',
          <String, Object?>{'document': type.noun},
        ),
      );
      return false;
    }
    final String runtimeId = _availableRuntimeId(type.kind, requestedId);
    flushAutosave();
    workspace.create(
      title: runtimeId,
      runtimeId: runtimeId,
      json: content,
      kind: type.kind,
    );
    _adoptDocument(
      type,
      AdoptedDocument(editorId: sanitizeMenuId(runtimeId), model: parsed),
    );
    _inform('Imported {id} as a new {document}.', <String, Object?>{
      'id': runtimeId,
      'document': type.noun,
    });
    return true;
  }

  /// Replaces the active document with Gloss-kind JSON — the Gloss arm of
  /// [importJson], mirroring [_importPreviewJson].
  void _importGlossJson(
    GlossDocumentTypeAdapter type,
    String name,
    String content,
  ) {
    final GlossDoc parsed;
    try {
      parsed = type.decodeDoc(content);
    } on HuiFormatException catch (e) {
      _failResolved(
        () => huiText('{message} (at {path})', <String, Object?>{
          'message': e.message,
          'path': e.path,
        }),
      );
      return;
    } catch (_) {
      _failResolved(
        () => huiText(
          'That file could not be read as a {document} document.',
          <String, Object?>{'document': type.noun},
        ),
      );
      return;
    }
    _lastError = null;
    _codeError = null;
    _selection.clear();
    _previewSelection = null;
    _togglePreviewState.clear();
    final String importedId = menuIdFromFileName(name);
    _undo.clear();
    _clearCoalesce();
    _docType = type;
    _setPreviewDoc(null);
    _setGlossDoc(parsed);
    _animationCache = null;
    _emojiCache = null;
    _menuId = importedId;
    _coerceView();
    _afterChange();
    _inform('Imported {id}.', <String, Object?>{'id': importedId});
  }

  bool _importPreviewAsNewDocument(String requestedId, String content) {
    final HuiPreviewDoc parsed;
    try {
      parsed = decodeHuiPreviewDoc(content);
    } on HuiFormatException catch (error) {
      _failResolved(
        () => huiText('{message} (at {path})', <String, Object?>{
          'message': error.message,
          'path': error.path,
        }),
      );
      return false;
    } catch (_) {
      _fail('That file could not be read as a container-preview document.');
      return false;
    }
    final String runtimeId = _availableRuntimeId(
      DocumentTypes.containerPreview.kind,
      requestedId,
    );
    flushAutosave();
    workspace.create(
      title: runtimeId,
      runtimeId: runtimeId,
      json: content,
      kind: DocumentTypes.containerPreview.kind,
    );
    _adoptPreview(parsed, runtimeId);
    _inform('Imported {id} as a new preview.', <String, Object?>{
      'id': runtimeId,
    });
    return true;
  }

  String _availableRuntimeId(WorkspaceDocKind kind, String requestedId) {
    final Set<String> taken = <String>{
      for (final WorkspaceDoc document in workspace.docs)
        if (document.kind == kind && document.runtimeId != null)
          document.runtimeId!.toLowerCase(),
    };
    final String canonical = sanitizeMenuId(requestedId);
    if (!taken.contains(canonical.toLowerCase())) return canonical;
    final List<String> segments = canonical.split('/');
    final String prefix = segments.length == 1
        ? ''
        : '${segments.take(segments.length - 1).join('/')}/';
    final String canonicalLeaf = segments.last;
    final RegExpMatch? match = RegExp(
      r'^(.*)-(\d+)$',
    ).firstMatch(canonicalLeaf);
    final String leaf = match?.group(1) ?? canonicalLeaf;
    final int start = match == null
        ? 2
        : (int.tryParse(match.group(2)!) ?? 1) + 1;
    for (int index = start; index < start + 100000; index++) {
      final String number = index.toString().padLeft(2, '0');
      final String suffix = '-$number';
      final int available = math.min(
        huiMaxMenuIdSegmentLength - suffix.length,
        huiMaxMenuIdLength - prefix.length - suffix.length,
      );
      final String base = leaf.substring(0, math.min(leaf.length, available));
      final String candidate = '$prefix$base$suffix';
      if (!taken.contains(candidate.toLowerCase()) &&
          !taken.contains('$prefix$base-$index'.toLowerCase())) {
        return candidate;
      }
    }
    return sanitizeMenuId('$prefix${DateTime.now().microsecondsSinceEpoch}');
  }

  void _importMenuJson(String name, String content) {
    final HuiMenu parsed;
    try {
      parsed = decodeHuiMenu(content);
    } on HuiFormatException catch (e) {
      _failResolved(
        () => huiText('{message} (at {path})', <String, Object?>{
          'message': e.message,
          'path': e.path,
        }),
      );
      return;
    } catch (_) {
      _fail('That file could not be read as Gloss menu JSON.');
      return;
    }
    _lastError = null;
    _codeError = null;
    _selection.clear();
    _previewSelection = null;
    _togglePreviewState.clear();
    final String importedId = menuIdFromFileName(name);
    final bool wasMenu = _menuWritable;
    final String before = _snapshot();
    _docType = DocumentTypes.menu;
    _setPreviewDoc(null);
    _setGlossDoc(null);
    _menu = parsed;
    _menuId = importedId;
    _coerceView();
    if (wasMenu) {
      _pushUndo('import $importedId', before, coalesce: false);
    } else {
      // Every entry on the stack is a snapshot of ONE document kind, and
      // `_applySnapshot` decodes it as whichever kind is open — so a step that
      // crosses the two can never be pushed. Starting fresh matches what
      // opening a different document already does.
      _undo.clear();
      _clearCoalesce();
    }
    _afterChange(menuSource: content);
    _inform('Imported {id}.', <String, Object?>{'id': importedId});
  }

  void _importPreviewJson(String name, String content) {
    final HuiPreviewDoc parsed;
    try {
      parsed = decodeHuiPreviewDoc(content);
    } on HuiFormatException catch (e) {
      _failResolved(
        () => huiText('{message} (at {path})', <String, Object?>{
          'message': e.message,
          'path': e.path,
        }),
      );
      return;
    } catch (_) {
      _fail('That file could not be read as a container-preview document.');
      return;
    }
    _lastError = null;
    _codeError = null;
    _selection.clear();
    _previewSelection = null;
    _togglePreviewState.clear();
    final String importedId = menuIdFromFileName(name);
    _undo.clear();
    _clearCoalesce();
    _docType = DocumentTypes.containerPreview;
    _setPreviewDoc(parsed);
    _setGlossDoc(null);
    _menuId = importedId;
    _coerceView();
    _afterChange();
    _inform('Imported {id}.', <String, Object?>{'id': importedId});
  }

  String? get codeError => _codeError?.call();

  /// Code-editor commit, in whichever shape [docKind] says the document is.
  /// Returns false and keeps the text when it does not parse, so the editor can
  /// show the error without losing the user's typing.
  bool applyCode(String text) {
    if (isPanelDoc) return false;
    if (isPreviewDoc) return _applyPreviewCode(text);
    final DocumentTypeAdapter type = _docType;
    if (type is GlossDocumentTypeAdapter) return _applyGlossCode(type, text);
    final HuiMenu parsed;
    try {
      parsed = decodeHuiMenu(text);
    } on HuiFormatException catch (e) {
      _setCodeFormatError(e);
      _notify();
      return false;
    } catch (_) {
      _setCodeError('That is not valid JSON.');
      _notify();
      return false;
    }
    _codeError = null;
    final String before = _snapshot();
    if (text == before) {
      _notify();
      return true;
    }
    _menu = parsed;
    _pruneSelection();
    _pushUndo('code edit', before);
    _afterChange(menuSource: text);
    return true;
  }

  /// The container-preview arm of [applyCode].
  ///
  /// Text that is not a preview document is REFUSED rather than decoded: the
  /// preview decoder is lenient by design (an object with no `elements` key
  /// reads back as a document with no elements), so pasting a menu file in
  /// would silently empty the card instead of failing. [looksLikePreviewDoc] is
  /// the same shape check the importer routes on.
  bool _applyPreviewCode(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      _setCodeError('That is not valid JSON.');
      _notify();
      return false;
    }
    if (!looksLikePreviewDoc(decoded)) {
      _setCodeError(
        'That is not a container-preview document: it needs an "elements" '
        'list and no "components".',
      );
      _notify();
      return false;
    }
    final HuiPreviewDoc parsed;
    try {
      parsed = HuiPreviewDoc.fromJson(decoded);
    } on HuiFormatException catch (e) {
      _setCodeFormatError(e);
      _notify();
      return false;
    } catch (_) {
      // Mirrors the menu arm's own fallback above: `HuiFormatException` is
      // the decoder's documented failure mode, not its only possible one, and
      // an uncaught exception here would crash the whole store notification
      // chain instead of reporting a code error the user can fix.
      _setCodeError('That is not valid container-preview JSON.');
      _notify();
      return false;
    }
    _codeError = null;
    final String before = _snapshot();
    if (encodeHuiPreviewDoc(parsed) == before) {
      _notify();
      return true;
    }
    _setPreviewDoc(parsed);
    _pushUndo('code edit', before);
    _prunePreviewSelection();
    _afterChange();
    return true;
  }

  /// The Gloss arm of [applyCode], shared by the hologram, animation and
  /// scoreboard kinds. Text that is not this kind's shape is REFUSED rather
  /// than decoded, the same discipline as [_applyPreviewCode]: the decoders
  /// are lenient by design, so pasting the wrong document in would silently
  /// hollow the current one out instead of failing.
  bool _applyGlossCode(GlossDocumentTypeAdapter type, String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      _setCodeError('That is not valid JSON.');
      _notify();
      return false;
    }
    if (!type.looksLike(decoded)) {
      _codeError = () => huiText(type.codeShapeError);
      _notify();
      return false;
    }
    final GlossDoc parsed;
    try {
      parsed = type.decodeDoc(text);
    } on HuiFormatException catch (e) {
      _setCodeFormatError(e);
      _notify();
      return false;
    } catch (_) {
      _codeError = () => huiText(
        'That is not a valid {document} document.',
        <String, Object?>{'document': type.noun},
      );
      _notify();
      return false;
    }
    _codeError = null;
    final String before = _snapshot();
    if (type.encodeDoc(parsed) == before) {
      _notify();
      return true;
    }
    _setGlossDoc(parsed);
    _animationCache = null;
    _emojiCache = null;
    _pushUndo('code edit', before);
    _afterChange();
    return true;
  }

  // --- documents ------------------------------------------------------------

  String? get lastError => _lastError?.call();

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    _notify();
  }

  DateTime? get lastSavedAt => _lastSavedAt;

  bool get hasUnsavedChanges =>
      _documentDirty || _preferencesDirty || workspace.hasUnsavedChanges;

  Future<bool> retryAutosave() async {
    final bool documentWasPending = _documentDirty;
    flushAutosave();
    if (!workspace.hasUnsavedChanges) return !hasUnsavedChanges;
    final bool saved = await workspace.retrySave();
    if (!saved) {
      _notify();
      return false;
    }
    if (documentWasPending && _documentPersistedInWorkspace) {
      _documentDirty = false;
      _documentPersistedInWorkspace = false;
    }
    _lastSavedAt = DateTime.now();
    _notify();
    return !hasUnsavedChanges;
  }

  /// Starts a new document in its own workspace entry.
  bool newDocument({
    String? name,
    String? runtimeId,
    HuiMenu? from,
    String? folderId,
  }) {
    if (!workspace.canWrite) {
      _failWorkspaceProtected();
      return false;
    }
    flushAutosave();
    final HuiMenu next = from ?? createDefaultMenu();
    final String title = name ?? huiDefaultMenuId;
    final String id = _availableRuntimeId(
      DocumentTypes.menu.kind,
      runtimeId ?? title,
    );
    workspace.create(
      title: title,
      runtimeId: id,
      json: encodeHuiMenu(next),
      kind: DocumentTypes.menu.kind,
      folderId: folderId,
    );
    _adoptMenu(next, id);
    return true;
  }

  bool newMenuDocumentFromJson({
    required String name,
    required String runtimeId,
    required String json,
    String? folderId,
  }) {
    if (!workspace.canWrite) {
      _failWorkspaceProtected();
      return false;
    }
    final HuiMenu parsed;
    try {
      parsed = decodeHuiMenu(json);
    } on HuiFormatException catch (error) {
      _failResolved(
        () => huiText('{message} (at {path})', <String, Object?>{
          'message': error.message,
          'path': error.path,
        }),
      );
      return false;
    } catch (_) {
      _fail('That handoff could not be read as Gloss menu JSON.');
      return false;
    }
    flushAutosave();
    final String id = _availableRuntimeId(DocumentTypes.menu.kind, runtimeId);
    workspace.create(
      title: name,
      runtimeId: id,
      json: json,
      kind: DocumentTypes.menu.kind,
      folderId: folderId,
    );
    _adoptMenu(parsed, id, source: json);
    return true;
  }

  Future<bool> importBundle(WorkspaceBundle bundle) async {
    flushAutosave();
    final WorkspaceBundleImportResult result = await importWorkspaceBundle(
      bundle,
      workspace,
      _images,
    );
    if (!result.isSuccess) {
      _failResolved(
        () =>
            result.error ??
            huiText('The workspace bundle could not be imported.'),
      );
      return false;
    }
    _documentDirty = false;
    _documentPersistedInWorkspace = false;
    _preferencesDirty = false;
    _adoptActiveDocument();
    return true;
  }

  /// Templates apply as a brand new document.
  void createDocumentFromMenu(String name, HuiMenu template) =>
      newDocument(name: name, from: template);

  /// Starts a new container-preview document in its own workspace entry —
  /// the preview counterpart of [newDocument].
  void newPreviewDocument({
    String? name,
    HuiPreviewDoc? from,
    String? folderId,
  }) {
    if (!workspace.canWrite) {
      _failWorkspaceProtected();
      return;
    }
    flushAutosave();
    final HuiPreviewDoc next = from ?? HuiPreviewDoc();
    final String title = name ?? huiDefaultMenuId;
    final String id = _availableRuntimeId(
      DocumentTypes.containerPreview.kind,
      title,
    );
    workspace.create(
      title: title,
      runtimeId: id,
      json: encodeHuiPreviewDoc(next),
      kind: DocumentTypes.containerPreview.kind,
      folderId: folderId,
    );
    _adoptPreview(next, id);
  }

  /// Starts a new Gloss document (hologram, animation or scoreboard) in its
  /// own workspace entry — the Gloss counterpart of [newDocument]. [from] is
  /// a template model; without one the kind's blank applies.
  void newGlossDocument(
    GlossDocumentTypeAdapter type, {
    String? name,
    GlossDoc? from,
    String? folderId,
  }) {
    if (!workspace.canWrite) {
      _failWorkspaceProtected();
      return;
    }
    flushAutosave();
    final GlossDoc next = from ?? type.newBlank();
    final String title = name ?? type.defaultDocumentName;
    final String id = _availableRuntimeId(type.kind, sanitizeMenuId(title));
    workspace.create(
      title: id,
      runtimeId: id,
      json: type.encodeDoc(next),
      kind: type.kind,
      folderId: folderId,
    );
    _adoptDocument(type, AdoptedDocument(editorId: id, model: next));
  }

  void newPanelDocument({
    String? name,
    String? folderId,
    String? scopeFolderId,
  }) {
    if (!workspace.canWrite) {
      _failWorkspaceProtected();
      return;
    }
    flushAutosave();
    workspace.create(
      title: name ?? huiText('Menu flow map'),
      runtimeId: null,
      json: encodeWorkspacePanel(
        WorkspacePanelData(scopeFolderId: scopeFolderId),
      ),
      kind: DocumentTypes.panel.kind,
      folderId: folderId,
    );
    _adoptActiveDocument();
  }

  bool updatePanel(WorkspacePanelData panel) {
    if (!isPanelDoc) return false;
    final bool saved = workspace.updateActive(
      json: encodeWorkspacePanel(panel),
    );
    if (saved) _lastSavedAt = DateTime.now();
    _notify();
    return saved;
  }

  /// Templates apply as a brand new document.
  void createDocumentFromPreview(String name, HuiPreviewDoc template) =>
      newPreviewDocument(name: name, from: template);

  bool openDocument(String docId) {
    final WorkspaceDoc? target = workspace.byId(docId);
    if (target == null) return false;
    if (docId == workspace.activeId) return true;
    flushAutosave();
    if (!workspace.switchTo(docId)) return false;
    _adoptActiveDocument();
    return true;
  }

  WorkspaceDoc? duplicateDocument(String docId) {
    final WorkspaceDoc? source = workspace.byId(docId);
    if (source == null || !workspace.canWrite) return null;
    flushAutosave();
    final String? runtimeId = source.runtimeId == null
        ? null
        : _availableRuntimeId(source.kind, source.runtimeId!);
    final WorkspaceDoc copy = workspace.create(
      title: huiText('{title} copy', <String, Object?>{'title': source.title}),
      runtimeId: runtimeId,
      json: source.json,
      kind: source.kind,
      folderId: source.folderId,
    );
    _adoptActiveDocument();
    return copy;
  }

  bool deleteDocument(String docId) {
    final bool wasActive = docId == workspace.activeId;
    if (!workspace.delete(docId)) return false;
    if (wasActive) {
      _documentDirty = false;
      _documentPersistedInWorkspace = false;
      _adoptActiveDocument();
    } else {
      _notify();
    }
    return true;
  }

  void adoptEmptyWorkspace() {
    _keepWorkspaceEmpty = true;
    workspace.write(emptyWorkspaceKey, 'true');
    _adoptActiveDocument();
  }

  /// Writes pending changes immediately. Called by the debounce timer, before a
  /// document switch, and on dispose.
  ///
  void flushAutosave({bool notify = true}) {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    bool changed = false;
    if (_documentDirty) {
      final int editorRevision = _documentRevision;
      final bool documentSaved = workspace.updateActive(
        runtimeId: _menuId,
        json: _snapshot(),
        kind: docKind,
      );
      if (documentSaved) {
        _documentPersistedInWorkspace = true;
        _pendingDocumentRevision = editorRevision;
        _pendingWorkspaceRevision = workspace.saveRevision;
        changed = _finishPendingDocumentSave() || changed;
      }
    }
    if (_preferencesDirty) {
      if (_writePreferences()) {
        _preferencesDirty = false;
        changed = true;
      }
    }
    if (changed) _lastSavedAt = DateTime.now();
    if (notify && (changed || _documentDirty || _preferencesDirty)) _notify();
  }

  @override
  void dispose() {
    flushAutosave(notify: false);
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _images?.removeListener(_onImagesChanged);
    workspace.removeListener(_onWorkspaceChanged);
    previewSim.removeListener(_notify);
    previewSim.dispose();
    _disposed = true;
    super.dispose();
  }

  // --- internals ------------------------------------------------------------

  Set<String> _takenIds() =>
      _menu.components.map((HuiComponent c) => c.id).toSet();

  CanvasItem? _runtimeCanvasItem(HuiMenu menu, String id) => buildCanvasScene(
    menu: menu,
    uiScale: 1,
    trueRender: true,
    togglePreview: togglePreviewFor,
    textCache: _textCache,
    images: _images,
    catalogs: _catalogs,
    charCache: _charCache,
    animations: workspaceAnimations,
    emoji: workspaceEmoji,
  ).byId(id);

  /// `button-02` duplicates as `button-03` and `slot-01` as `slot-02`: an existing
  /// numeric suffix is incremented, never dropped, because the number is just
  /// as often the author's own naming scheme as it is editor bookkeeping.
  String _duplicateId(String id, Set<String> taken) {
    return uniqueComponentId(id, taken);
  }

  /// The active document, encoded in whichever shape [docKind] says it is.
  /// Menu-editing call sites only ever run while [_menuWritable] is true, so
  /// they always see the menu encoding; the adapter dispatch is what lets
  /// [flushAutosave] persist a preview document too.
  String _snapshot() => _docType.snapshot(this);

  /// Blocks are authored to two or three decimals; killing float noise keeps
  /// exported JSON and snapshot comparisons stable.
  double _round(double value) =>
      !value.isFinite ? 0 : (value * 10000).roundToDouble() / 10000;

  int _countSeverity(HuiSeverity severity) =>
      _issues.where((HuiIssue issue) => issue.severity == severity).length;

  /// Resolves the validation-scale canvas scene for the menu slot and caches
  /// it for [overlapPairs].
  ///
  /// uiScale 1, always. Overlap is scale-invariant — positions and plane sizes
  /// both scale linearly — so the issue list must not move when someone drags
  /// the canvas toolbar's preview scale.
  @override
  CanvasScene resolveValidationScene() {
    final CanvasScene scene = buildCanvasScene(
      menu: _menu,
      uiScale: 1,
      trueRender: false,
      togglePreview: togglePreviewFor,
      textCache: _textCache,
      images: _images,
      catalogs: _catalogs,
      charCache: _charCache,
      animations: workspaceAnimations,
      emoji: workspaceEmoji,
    );
    _scene = scene;
    return scene;
  }

  /// Text fields and sliders mutate on every keystroke and every pointer move,
  /// so a burst of same-label edits collapses into one step. Without this a
  /// 110-character label would evict the entire 100-entry history and undo
  /// would walk back one character at a time.
  static const Duration _coalesceWindow = Duration(milliseconds: 700);

  void _pushUndo(String label, String before, {bool coalesce = true}) {
    if (_dragActive) {
      if (_dragPushed) return;
      _dragPushed = true;
      _clearCoalesce();
      _undo.push(label, before);
      return;
    }
    final DateTime now = DateTime.now();
    final DateTime? last = _coalesceAt;
    if (coalesce &&
        label == _coalesceLabel &&
        last != null &&
        now.difference(last) < _coalesceWindow) {
      _coalesceAt = now;
      return;
    }
    _coalesceLabel = coalesce ? label : null;
    _coalesceAt = coalesce ? now : null;
    _undo.push(label, before);
  }

  /// Any deliberate step boundary starts a fresh entry.
  void _clearCoalesce() {
    _coalesceLabel = null;
    _coalesceAt = null;
  }

  void _afterChange({String? menuSource}) {
    if (_menuWritable) _preservedMenuSource = menuSource;
    _refreshIssues();
    _documentDirty = true;
    _documentRevision++;
    _scheduleSave();
    _notify();
  }

  /// Restores one history entry, in whichever shape the active document is.
  /// The stack only ever holds snapshots of the document that is open — every
  /// kind switch clears it — so the adapter here can never read a menu
  /// snapshot into a preview document or the other way round.
  bool _applySnapshot(String snapshot) {
    try {
      _installModel(_docType.decodeSnapshot(snapshot));
    } on HuiFormatException catch (e) {
      _failResolved(
        () => huiText(
          'Could not restore that step: {message}',
          <String, Object?>{'message': e.message},
        ),
      );
      return false;
    }
    if (isPreviewDoc) {
      _prunePreviewSelection();
    } else {
      _pruneSelection();
    }
    _afterChange(menuSource: _docType.sourcePreserving ? snapshot : null);
    return true;
  }

  /// Installs a decoded model into the slot its type belongs to, leaving the
  /// other slots untouched — the kind cannot change across an undo step.
  void _installModel(Object model) {
    if (model is HuiMenu) {
      _menu = model;
    } else if (model is HuiPreviewDoc) {
      _setPreviewDoc(model);
    } else if (model is GlossDoc) {
      _setGlossDoc(model);
      _animationCache = null;
      _emojiCache = null;
    }
  }

  /// Selection is deliberately not part of the undo snapshot: a restored step
  /// drops ids the restored document no longer has rather than resurrecting an
  /// old selection.
  void _pruneSelection() =>
      _selection.removeWhere((String id) => _menu.componentById(id) == null);

  void _fail(String english, [Map<String, Object?> arguments = const {}]) {
    final Map<String, Object?> captured = Map<String, Object?>.of(arguments);
    _lastError = () => huiText(english, captured);
    onError?.call(_lastError!());
    _notify();
  }

  void _failResolved(String Function() resolver) {
    _lastError = resolver;
    onError?.call(resolver());
    _notify();
  }

  void _failWorkspaceProtected() => _failResolved(
    () =>
        workspace.lastError ??
        huiText(
          'The workspace is protected from overwrite until it is recovered.',
        ),
  );

  void _inform(String english, [Map<String, Object?> arguments = const {}]) {
    onInfo?.call(huiText(english, arguments));
  }

  void _setCodeError(
    String english, [
    Map<String, Object?> arguments = const {},
  ]) {
    final Map<String, Object?> captured = Map<String, Object?>.of(arguments);
    _codeError = () => huiText(english, captured);
  }

  void _setCodeFormatError(HuiFormatException error) {
    _codeError = () => huiText('{message} (at {path})', <String, Object?>{
      'message': error.message,
      'path': error.path,
    });
  }

  void _onImagesChanged() {
    // A re-uploaded path keeps its name but changes its pixels, and the plane
    // character count is memoized by path, so the memo has to go.
    _charCache.clear();
    if (_menuWritable) _refreshIssues();
    _notify();
  }

  void _onWorkspaceChanged() {
    // Any workspace write may have touched an animation document another
    // surface renders through.
    _animationCache = null;
    _emojiCache = null;
    final bool saved = _finishPendingDocumentSave();
    if (saved) {
      _lastSavedAt = DateTime.now();
      _notify();
      return;
    }
    if (workspace.lastError != null || workspace.requiresReload) _notify();
  }

  bool _finishPendingDocumentSave() {
    final int? editorRevision = _pendingDocumentRevision;
    final int? workspaceRevision = _pendingWorkspaceRevision;
    if (editorRevision == null || workspaceRevision == null) return false;
    if (workspace.persistedRevision < workspaceRevision) return false;
    _pendingDocumentRevision = null;
    _pendingWorkspaceRevision = null;
    if (editorRevision != _documentRevision) return false;
    _documentDirty = false;
    _documentPersistedInWorkspace = false;
    return true;
  }

  void _scheduleSave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(autosaveDelay, flushAutosave);
  }

  void _savePreference() {
    _preferencesDirty = true;
    _scheduleSave();
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  void _adoptActiveDocument() {
    final WorkspaceDoc? doc = workspace.active;
    if (doc == null) {
      if (_keepWorkspaceEmpty) {
        _adoptEmptyWorkspace();
        return;
      }
      final HuiMenu fresh = createDefaultMenu();
      if (workspace.isLoadProtected) {
        _adoptMenu(fresh, huiDefaultMenuId);
        return;
      }
      workspace.create(
        title: huiDefaultMenuId,
        runtimeId: huiDefaultMenuId,
        json: encodeHuiMenu(fresh),
        kind: DocumentTypes.menu.kind,
      );
      _adoptMenu(fresh, huiDefaultMenuId);
      return;
    }
    if (_keepWorkspaceEmpty) {
      _keepWorkspaceEmpty = false;
      workspace.write(emptyWorkspaceKey, 'false');
    }
    final DocumentTypeAdapter type = DocumentTypeRegistry.of(doc.kind);
    _adoptDocument(type, type.adopt(doc));
  }

  void _adoptEmptyWorkspace() {
    _docType = DocumentTypes.menu;
    _menu = HuiMenu();
    _menuId = '';
    _preservedMenuSource = null;
    _setPreviewDoc(null);
    _setGlossDoc(null);
    _animationCache = null;
    _emojiCache = null;
    _selection.clear();
    _previewSelection = null;
    _togglePreviewState.clear();
    _codeError = null;
    _clearCoalesce();
    _undo.clear();
    _issues = const <HuiIssue>[];
    _documentDirty = false;
    _documentPersistedInWorkspace = false;
    _pendingDocumentRevision = null;
    _pendingWorkspaceRevision = null;
    _coerceView();
    _notify();
  }

  void _adoptMenu(HuiMenu menu, String menuId, {String? source}) =>
      _adoptDocument(
        DocumentTypes.menu,
        AdoptedDocument(
          editorId: sanitizeMenuId(menuId),
          model: menu,
          preservedSource: source,
        ),
      );

  /// The preview counterpart of [_adoptMenu].
  void _adoptPreview(HuiPreviewDoc doc, String docId) => _adoptDocument(
    DocumentTypes.containerPreview,
    AdoptedDocument(editorId: sanitizeMenuId(docId), model: doc),
  );

  /// Makes [adopted] the open document: installs the model, resets every
  /// per-document piece of editor state and reports a decode failure after
  /// the replacement document is fully up.
  void _adoptDocument(DocumentTypeAdapter type, AdoptedDocument adopted) {
    if (_keepWorkspaceEmpty && workspace.active != null) {
      _keepWorkspaceEmpty = false;
      workspace.write(emptyWorkspaceKey, 'false');
    }
    _docType = type;
    _preservedMenuSource = adopted.preservedSource;
    final Object? model = adopted.model;
    // The menu slot is cleared, not left behind, when another kind takes over.
    // Holding the previous menu made every consumer of [menu] a trap: the
    // library rail offered a Contents tab for a hologram and listed the last
    // menu's components in it. Measured before this fix.
    _menu = model is HuiMenu ? model : HuiMenu();
    _setPreviewDoc(model is HuiPreviewDoc ? model : null);
    _setGlossDoc(model is GlossDoc ? model : null);
    _animationCache = null;
    _emojiCache = null;
    _menuId = adopted.editorId;
    _selection.clear();
    _previewSelection = null;
    _coerceView();
    _followMode();
    _codeError = null;
    _togglePreviewState.clear();
    _clearCoalesce();
    _undo.clear();
    _documentDirty = false;
    _documentPersistedInWorkspace = false;
    _pendingDocumentRevision = null;
    _pendingWorkspaceRevision = null;
    _refreshIssues();
    _notify();
    final String? failure = adopted.failure;
    if (failure != null) {
      _lastError = () => adopted.failure ?? failure;
      onError?.call(_lastError!());
      _notify();
    }
  }

  void _loadPreferences() {
    final String? raw = workspace.read(preferencesKey);
    if (raw == null || raw.isEmpty) return;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    _view = _viewFromName(decoded['view']);
    _loadViewsByKind(decoded['views']);
    _mode = DocumentTypeRegistry.byKindName(decoded['mode']);
    _previewUiScale = _readDouble(decoded['previewUiScale'], 1, 0.25, 4);
    _gridSize = _readDouble(decoded['gridSize'], 0.05, 0.01, 1);
    _showHitboxes = _readBool(decoded['showHitboxes'], false);
    _showAnchors = _readBool(decoded['showAnchors'], true);
    _showGrid = _readBool(decoded['showGrid'], true);
    _snapToGrid = _readBool(decoded['snapToGrid'], true);
    _trueRender = _readBool(decoded['trueRender'], false);
    _backdrop = _backdropFromName(decoded['backdrop']);
    _previewShowPlanes = _readBool(decoded['previewShowPlanes'], false);
    _previewShowNormals = _readBool(decoded['previewShowNormals'], false);
    _previewShowAnchors = _readBool(decoded['previewShowAnchors'], false);
    _previewShowCenter = _readBool(decoded['previewShowCenter'], true);
    _previewShowDistanceSphere = _readBool(
      decoded['previewShowDistanceSphere'],
      false,
    );
    _previewShowGroundGrid = _readBool(decoded['previewShowGroundGrid'], true);
    _previewLogOpen = _readBool(decoded['previewLogOpen'], true);
    _previewBannerDismissed = _readBool(
      decoded['previewBannerDismissed'],
      false,
    );
    _previewCameraMode = PreviewCameraMode.fromName(
      decoded['previewCameraMode'],
    );
  }

  /// Reads the per-kind view memory. A blob written before this key existed
  /// carries only `view`, which [_loadPreferences] has already taken as the
  /// current one; the map simply starts empty and fills as kinds are opened.
  void _loadViewsByKind(Object? raw) {
    if (raw is! Map) return;
    for (final MapEntry<Object?, Object?> entry in raw.entries) {
      final DocumentTypeAdapter? type = DocumentTypeRegistry.byKindName(
        entry.key,
      );
      if (type == null) continue;
      final EditorView view = _viewFromName(entry.value);
      if (type.supportsView(view)) _viewByKind[type.kind] = view;
    }
  }

  bool _writePreferences() => workspace.write(
    preferencesKey,
    jsonEncode(<String, dynamic>{
      'view': _view.name,
      'views': <String, String>{
        for (final MapEntry<WorkspaceDocKind, EditorView> entry
            in _viewByKind.entries)
          entry.key.name: entry.value.name,
      },
      'mode': _mode?.kind.name,
      'previewUiScale': _previewUiScale,
      'gridSize': _gridSize,
      'showHitboxes': _showHitboxes,
      'showAnchors': _showAnchors,
      'showGrid': _showGrid,
      'snapToGrid': _snapToGrid,
      'trueRender': _trueRender,
      'backdrop': _backdrop.name,
      'previewShowPlanes': _previewShowPlanes,
      'previewShowNormals': _previewShowNormals,
      'previewShowAnchors': _previewShowAnchors,
      'previewShowCenter': _previewShowCenter,
      'previewShowDistanceSphere': _previewShowDistanceSphere,
      'previewShowGroundGrid': _previewShowGroundGrid,
      'previewLogOpen': _previewLogOpen,
      'previewBannerDismissed': _previewBannerDismissed,
      'previewCameraMode': _previewCameraMode.name,
    }),
  );

  void resetLocalPreferences() {
    _view = EditorView.visual;
    _viewByKind.clear();
    _mode = null;
    _previewUiScale = 1;
    _showHitboxes = false;
    _showAnchors = true;
    _showGrid = true;
    _snapToGrid = true;
    _trueRender = false;
    _gridSize = 0.05;
    _backdrop = HuiBackdropMode.image;
    _animationsPlaying = true;
    _previewShowPlanes = false;
    _previewShowNormals = false;
    _previewShowAnchors = false;
    _previewShowCenter = true;
    _previewShowDistanceSphere = false;
    _previewShowGroundGrid = true;
    _previewLogOpen = true;
    _previewBannerDismissed = false;
    _previewCameraMode = PreviewCameraMode.orbit;
    _preferencesDirty = false;
    _catalogs = _catalogs.withCustomItems(HuiCustomItemCatalog.empty());
    _charCache.clear();
    _coerceView();
    _refreshIssues();
    _notify();
  }

  /// Reads a stored view name.
  ///
  /// Every per-kind surface name this editor persisted before the four-mode
  /// remodel — `board`, `panel`, `previewCard`, `hologram` and the rest — was
  /// that kind's editing surface, which is now [EditorView.visual]. Only
  /// `preview`, `code` and `split` survive as themselves.
  static EditorView _viewFromName(Object? raw) {
    for (final EditorView value in EditorView.values) {
      if (value.name == raw) return value;
    }
    return EditorView.visual;
  }

  static HuiBackdropMode _backdropFromName(Object? raw) {
    for (final HuiBackdropMode value in HuiBackdropMode.values) {
      if (value.name == raw) return value;
    }
    return HuiBackdropMode.image;
  }

  static bool _readBool(Object? raw, bool fallback) =>
      raw is bool ? raw : fallback;

  static double _readDouble(
    Object? raw,
    double fallback,
    double min,
    double max,
  ) {
    if (raw is! num) return fallback;
    final double value = raw.toDouble();
    if (!value.isFinite) return fallback;
    return value.clamp(min, max).toDouble();
  }
}

/// [GlossAnimationResolver] over the store's workspace: animation documents
/// by runtime id, with the open one served from its live model. A handle,
/// not a snapshot — every read goes through the store's cache, which any
/// workspace or Gloss-document change invalidates.
final class _StoreAnimationResolver implements GlossAnimationResolver {
  _StoreAnimationResolver(this._store);

  final EditorStore _store;

  @override
  List<String> get ids {
    final List<String> out = _store._animationDocs().keys.toList()..sort();
    return out;
  }

  @override
  GlossAnimationDoc? byId(String id) => _store._animationDocs()[id];
}

final class _StoreEmojiResolver implements GlossEmojiResolver {
  _StoreEmojiResolver(this._store);

  final EditorStore _store;

  @override
  List<GlossEmojiEntry> get entries => _store._emojiEntries();
}

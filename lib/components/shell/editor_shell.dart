/// The application frame.
///
/// A fixed-height grid: bar / (rail, centre, inspector) / status. The shell
/// itself never scrolls — each pane owns `min-height: 0; overflow-y: auto`, so
/// there is never a scrollbar inside a scrollbar.
///
/// Panels built by other modules arrive as slots, so this file depends on none
/// of them. The centre pane takes two maps keyed by [DocumentSurface] — the
/// editing surfaces and their in-game renderings — plus the two surfaces the
/// shell keeps mounted in every view:
///
/// ```dart
/// EditorScope(
///   store: store,
///   child: EditorShell(
///     rail: const ComponentsRail(),
///     canvas: const CanvasViewport(),
///     previewCard: const PreviewCardViewport(),
///     surfaces: <DocumentSurface, Widget>{
///       DocumentSurface.scoreboard: const ScoreboardView(),
///     },
///     previews: <DocumentSurface, Widget>{
///       DocumentSurface.canvas: const PreviewView(),
///       DocumentSurface.scoreboard: const ScoreboardView(gameContext: true),
///     },
///     inspector: const InspectorPane(),
///     codeEditor: const CodeEditorView(),
///     overlays: <Widget>[ExportDialog(...), HelpDialog(...)],
///   ),
/// );
/// ```
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../doctype/doctype.dart';
import '../../services/file_transfer.dart';
import '../../services/image_library.dart';
import '../../state/editor_scope.dart';
import '../../state/editor_store.dart';
import 'command_palette.dart';
import 'editor_sync_bar.dart';
import 'key_listener.dart';
import 'keyboard_shortcuts.dart';
import 'pane_dom.dart';
import 'pane_layout.dart';
import 'pane_splitter.dart';
import 'shell_actions.dart';
import 'shell_intents.dart';
import 'shell_keys.dart';
import 'shell_status.dart';
import 'shortcut_sheet.dart';
import 'status_bar.dart';
import 'store_selector.dart';
import 'top_bar.dart';
import 'tour.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class EditorShell extends StatefulWidget {
  const EditorShell({
    required this.rail,
    required this.canvas,
    required this.previewCard,
    required this.surfaces,
    required this.previews,
    required this.inspector,
    required this.codeEditor,
    required this.overlays,
    required this.activeLocale,
    required this.localeLoading,
    required this.onLocaleChanged,
    this.store,
    this.status,
    this.onOpenImport,
    this.onOpenExport,
    this.onOpenImages,
    this.onOpenTemplates,
    this.onOpenHelp,
    this.onOpenSettings,
    this.onOpenValidation,
    this.syncControls,
    this.onCloseOverlay,
    this.onToggleTheme,
    this.darkMode = true,
    super.key,
  });

  final Widget rail;

  /// The component canvas. Mounted in every view and hidden by CSS; see
  /// [_CenterArea].
  final Widget canvas;

  /// The pixel-space container-preview surface. Mounted in every view and
  /// hidden by CSS, exactly like [canvas]; see [_CenterArea].
  final Widget previewCard;

  /// The editing surface for every kind whose surface is neither [canvas] nor
  /// [previewCard]. Mounted only while its kind is open and the visual or
  /// split mode is active: each of these owns a playback clock.
  final Map<DocumentSurface, Widget> surfaces;

  /// The in-game rendering behind the preview mode, per surface. The menu's is
  /// the 3D stage; every other kind's is its own surface asked to draw in game
  /// context. Absent for kinds with nothing to render.
  final Map<DocumentSurface, Widget> previews;

  final Widget inspector;
  final Widget codeEditor;

  /// Dialogs and sheets owned by other modules, mounted above the frame.
  final List<Widget> overlays;
  final String activeLocale;
  final bool localeLoading;
  final ValueChanged<String> onLocaleChanged;

  /// Falls back to the ambient [EditorScope] when omitted.
  final EditorStore? store;

  /// Canvas-owned pointer, zoom and hint readouts for the status bar.
  final ShellStatus? status;

  final void Function()? onOpenImport;
  final void Function()? onOpenExport;
  final void Function()? onOpenImages;
  final void Function()? onOpenTemplates;
  final void Function()? onOpenHelp;
  final void Function()? onOpenSettings;
  final void Function()? onOpenValidation;
  final EditorSyncControls? syncControls;

  /// Escape handler for whichever dialog or sheet the owner has open.
  final void Function()? onCloseOverlay;
  final void Function()? onToggleTheme;
  final bool darkMode;

  @override
  State<EditorShell> createState() => _EditorShellState();
}

class _EditorShellState extends State<EditorShell> {
  EditorStore? _store;
  ShellIntents? _intents;
  void Function()? _uninstallDrop;
  bool _apple = false;
  bool _paletteOpen = false;
  bool _dropActive = false;
  bool _confirmDelete = false;
  int _confirmSeq = 0;
  bool _tourOpen = false;
  bool _tourLeaving = false;
  bool _tourChecked = false;
  bool _shortcutsOpen = false;
  bool _shortcutsLeaving = false;
  bool _mobileRailOpen = false;
  bool _mobileInspectorOpen = false;

  /// Bumped on every open and close so a dismissal already in flight cannot
  /// unmount a surface the user has since re-opened.
  int _dismissSeq = 0;
  PaneLayout _panes = PaneLayout.defaults;

  @override
  void initState() {
    super.initState();
    _apple = isApplePlatform();
    // Restored before the first paint: the custom properties live on the
    // document root, which exists long before this tree mounts, so a stored
    // layout never flashes through the defaults.
    _panes = PaneLayout.load();
    _paintPanes();
  }

  void _paintPanes() {
    writePaneVariable(PaneLayout.variableOf(PaneSide.rail), _panes.railWidth);
    writePaneVariable(
      PaneLayout.variableOf(PaneSide.inspector),
      _panes.inspectorWidth,
    );
  }

  /// One rebuild per settled gesture, never one per pointer move.
  void _commitPanes(PaneLayout next) {
    if (next == _panes) return;
    setState(() => _panes = next);
    _paintPanes();
    _panes.persist();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final EditorStore resolved = component.store ?? EditorScope.of(context);
    _maybeStartTour(resolved);
    if (identical(resolved, _store)) {
      _intents = _buildIntents(resolved);
      return;
    }
    _detach();
    _store = resolved;
    _intents = _buildIntents(resolved);
    resolved.onError = ArcaneSonner.error;
    resolved.onInfo = ArcaneSonner.info;
    _uninstallDrop = installDropHandler(
      onJson: resolved.importJsonAsNewDocument,
      onImages: _acceptImages,
      onDragActive: (bool active) {
        if (!mounted || active == _dropActive) return;
        setState(() => _dropActive = active);
      },
    );
  }

  @override
  void didUpdateComponent(covariant EditorShell oldComponent) {
    super.didUpdateComponent(oldComponent);
    final EditorStore? store = _store;
    if (store != null) _intents = _buildIntents(store);
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    _uninstallDrop?.call();
    _uninstallDrop = null;
    final EditorStore? store = _store;
    if (store != null) {
      store.onError = null;
      store.onInfo = null;
    }
  }

  ShellIntents _buildIntents(EditorStore store) => ShellIntents(
    store: store,
    requestDeleteSelected: _armDelete,
    openPalette: _openPalette,
    onOpenImport: component.onOpenImport,
    onOpenExport: component.onOpenExport,
    onOpenImages: component.onOpenImages,
    onOpenTemplates: component.onOpenTemplates,
    onOpenHelp: component.onOpenHelp,
    onOpenSettings: component.onOpenSettings,
    onOpenValidation: component.onOpenValidation,
    onToggleTheme: component.onToggleTheme,
  );

  void _openPalette() {
    if (_paletteOpen) return;
    setState(() => _paletteOpen = true);
  }

  void _togglePalette() => setState(() => _paletteOpen = !_paletteOpen);

  /// The injected arcane_jaspr runtime claims `(meta|ctrl)+K` on the document
  /// and `stopPropagation`s it before the shell's binder ever sees it
  /// (`command_palette_scripts.dart:239-250`), then clicks
  /// `[data-command-trigger]`. This app rendered no such node, so ⌘K did
  /// nothing at all while the top bar advertised it. Rather than fight the
  /// script, give it the node it is looking for — the same shape of fix as
  /// `data-arcane-interactive` for the accordion binder. The shell's own table
  /// row still runs if the script is ever gone; the two cannot both fire,
  /// because the script consumes the event when it is present.
  void _triggerPalette() {
    // The binder stands all three of these down; the script knows about none of
    // them. Measured before this guard: with `hui-settings-dialog` open, one
    // Meta+K put the palette on top of it.
    if (_tourOpen || _shortcutsOpen || huiArcaneOverlayOpen()) return;
    _togglePalette();
  }

  void _closePalette() {
    if (!_paletteOpen) return;
    setState(() => _paletteOpen = false);
  }

  void _armDelete() {
    setState(() {
      _confirmDelete = true;
      _confirmSeq++;
    });
  }

  /// Escape while any Arcane surface is open.
  ///
  /// The delete confirm is the one dialog `app.dart` cannot close: its flag
  /// lives here, so `onCloseOverlay` cleared the other overlays, reported the
  /// key as handled and left the confirm on screen with Escape swallowed —
  /// the only dialog in the app that ignored it. Measured before this fix.
  void _escapeOverlay() {
    switch (huiOverlayEscapeTarget(confirmDeleteOpen: _confirmDelete)) {
      case HuiOverlayEscape.confirmDelete:
        setState(() => _confirmDelete = false);
      case HuiOverlayEscape.appOverlay:
        component.onCloseOverlay?.call();
    }
  }

  // --- tour and shortcut sheet ----------------------------------------------

  /// Runs once per shell, before the first build, so an unseen tour is up in
  /// the first frame rather than arriving after the user has already started
  /// clicking. The flag is browser state, not document state: it lives in the
  /// workspace's storage under `gloss.tour.v1` and never touches the store.
  void _maybeStartTour(EditorStore store) {
    if (_tourChecked) return;
    _tourChecked = true;
    final String? seen = store.workspace.read(huiTourSeenKey);
    if (seen == null || seen.isEmpty) _tourOpen = true;
  }

  void _replayTour() {
    setState(() {
      _tourOpen = true;
      _tourLeaving = false;
      _dismissSeq++;
    });
  }

  void _endTour({required bool remember}) {
    if (remember) _store?.workspace.write(huiTourSeenKey, 'seen');
    _dismiss(() => _tourLeaving = true, () {
      _tourOpen = false;
      _tourLeaving = false;
    });
  }

  void _toggleShortcuts() {
    if (_shortcutsOpen && !_shortcutsLeaving) {
      _dismiss(() => _shortcutsLeaving = true, () {
        _shortcutsOpen = false;
        _shortcutsLeaving = false;
      });
      return;
    }
    setState(() {
      _shortcutsOpen = true;
      _shortcutsLeaving = false;
      _dismissSeq++;
    });
  }

  void _toggleMobileRail() {
    setState(() {
      _mobileRailOpen = !_mobileRailOpen;
      if (_mobileRailOpen) _mobileInspectorOpen = false;
    });
  }

  void _toggleMobileInspector() {
    setState(() {
      _mobileInspectorOpen = !_mobileInspectorOpen;
      if (_mobileInspectorOpen) _mobileRailOpen = false;
    });
  }

  void _closeMobilePanes() {
    if (!_mobileRailOpen && !_mobileInspectorOpen) return;
    setState(() {
      _mobileRailOpen = false;
      _mobileInspectorOpen = false;
    });
  }

  /// Exit animations are impossible for an Arcane surface — the runtime writes
  /// `hidden` with `display:none!important` in the same batch as the state flip
  /// (06-motion.css, foot of file). These two are ours to unmount, so the class
  /// runs first and the node drops after it. The wait is deliberately shorter
  /// than the entrance: a dismissal must never feel held up.
  void _dismiss(void Function() start, void Function() finish) {
    setState(start);
    final int seq = ++_dismissSeq;
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (!mounted || seq != _dismissSeq) return;
      setState(finish);
    });
  }

  Future<void> _acceptImages(List<Object> files) async {
    final ImageLibrary? library = _store?.images;
    if (library == null) {
      ArcaneSonner.error(
        huiText('The image library is not available in this build.'),
      );
      return;
    }
    final ImageAddOutcome outcome = await library.addFromFiles(files);
    for (final String error in outcome.errors) {
      ArcaneSonner.error(error);
    }
    for (final String warning in outcome.warnings) {
      ArcaneSonner.warning(warning);
    }
    if (outcome.added.isNotEmpty) {
      final int count = outcome.added.length;
      ArcaneSonner.success(
        huiPlural(
          'images.added_count',
          count,
          oneEnglish: 'Added {count} image.',
          otherEnglish: 'Added {count} images.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final EditorStore? store = _store;
    final ShellIntents? intents = _intents;
    if (store == null || intents == null) {
      return const dom.div(classes: 'hui-shell', <Widget>[]);
    }
    return KeyboardShortcuts(
      intents: intents,
      paletteOpen: _paletteOpen,
      tourOpen: _tourOpen,
      shortcutsOpen: _shortcutsOpen,
      mobilePaneOpen: _mobileRailOpen || _mobileInspectorOpen,
      onTogglePalette: _togglePalette,
      onToggleShortcuts: _toggleShortcuts,
      onSkipTour: () => _endTour(remember: false),
      onCloseOverlay: _escapeOverlay,
      onCloseMobilePane: _closeMobilePanes,
      child: dom.div(
        id: 'hui-shell',
        classes: component.syncControls == null
            ? 'hui-shell'
            : 'hui-shell has-sync',
        <Widget>[
          TopBar(
            intents: intents,
            activeLocale: component.activeLocale,
            localeLoading: component.localeLoading,
            onLocaleChanged: component.onLocaleChanged,
            syncControls: component.syncControls,
            apple: _apple,
            darkMode: component.darkMode,
            mobileRailOpen: _mobileRailOpen,
            mobileInspectorOpen: _mobileInspectorOpen,
            onToggleMobileRail: _toggleMobileRail,
            onToggleMobileInspector: _toggleMobileInspector,
          ),
          if (component.syncControls != null)
            EditorSyncBar(controls: component.syncControls!),
          dom.div(classes: 'hui-shell-body', <Widget>[
            dom.aside(
              classes:
                  'hui-pane hui-rail${_mobileRailOpen ? ' is-mobile-open' : ''}',
              attributes: <String, String>{
                'aria-label': huiText('Library and document contents'),
              },
              <Widget>[component.rail],
            ),
            PaneSplitter(
              side: PaneSide.rail,
              layout: _panes,
              onCommit: _commitPanes,
            ),
            _CenterArea(
              store: store,
              canvas: component.canvas,
              previewCard: component.previewCard,
              surfaces: component.surfaces,
              previews: component.previews,
              codeEditor: component.codeEditor,
            ),
            PaneSplitter(
              side: PaneSide.inspector,
              layout: _panes,
              onCommit: _commitPanes,
            ),
            if (_mobileRailOpen || _mobileInspectorOpen)
              dom.button(
                classes: 'hui-pane-scrim',
                attributes: <String, String>{
                  'type': 'button',
                  'aria-label': huiText('Close side panel'),
                },
                events: dom.events<Null>(onClick: _closeMobilePanes),
                const <Widget>[],
              ),
            dom.aside(
              classes:
                  'hui-pane hui-inspector${_mobileInspectorOpen ? ' is-mobile-open' : ''}',
              attributes: <String, String>{'aria-label': huiText('Inspector')},
              <Widget>[component.inspector],
            ),
          ]),
          StatusBar(
            store: store,
            status: component.status,
            onOpenValidation: component.onOpenValidation,
          ),
          // Never reachable by pointer or Tab (see `.hui-cmd-trigger`); it
          // exists only so the runtime's ⌘K handler has something to click.
          dom.button(
            classes: 'hui-cmd-trigger',
            attributes: const <String, String>{
              'type': 'button',
              'tabindex': '-1',
              'aria-hidden': 'true',
              'data-command-trigger': '',
            },
            events: dom.events<Null>(onClick: _triggerPalette),
            const <Widget>[],
          ),
          ...component.overlays,
          if (_paletteOpen)
            ShellCommandPalette(
              actions: buildShellActions(
                intents,
                onShowShortcuts: _toggleShortcuts,
                onReplayTour: _replayTour,
              ),
              onClose: _closePalette,
              apple: _apple,
            ),
          if (_confirmDelete) _deleteDialog(store, intents),
          if (_shortcutsOpen)
            ShortcutSheet(
              onClose: _toggleShortcuts,
              apple: _apple,
              leaving: _shortcutsLeaving,
            ),
          // Last of the overlays and above them all: a spotlight over a region
          // a dialog was covering would be teaching the wrong thing.
          if (_tourOpen)
            HuiTour(
              onFinish: () => _endTour(remember: true),
              onSkip: () => _endTour(remember: false),
              onNever: () => _endTour(remember: true),
              leaving: _tourLeaving,
            ),
          if (_dropActive) const _DropOverlay(),
          // Bottom-left, not bottom-right: the right edge is the inspector, the
          // one surface the user is typing into while toasts fire. Bottom-centre
          // is out too — the canvas keyboard-hint row spans the full width of
          // the canvas column at its bottom edge. The rail's tail is the only
          // bottom strip whose controls all live at the top, and the stylesheet
          // caps the toaster width so it can never reach the inspector. The
          // offset lifts the stack clear of the status bar.
          // Top centre: the only region no pane owns. Bottom-right buries the
          // inspector, bottom-left buries the rail, and bottom-centre lands on
          // the canvas hint line. Toasts are transient, so briefly covering the
          // top of the artboard costs nothing.
          const ArcaneSonner(position: ToastPosition.topCenter, offset: 16),
        ],
      ),
    );
  }

  /// Keyed per arming: the dialog surface is closed by the injected JS runtime,
  /// so reusing the element would re-open a node the runtime already hid.
  ///
  /// Counted, not named: the confirm deletes the whole selection, so naming the
  /// primary while removing three was a dialog that lied about its own effect.
  Widget _deleteDialog(EditorStore store, ShellIntents intents) {
    final int count = store.selectionIds.length;
    final bool many = count > 1;
    return ArcaneConfirmDialog(
      key: ValueKey<int>(_confirmSeq),
      title: many
          ? huiPlural(
              'shell.delete_components.question',
              count,
              oneEnglish: 'Delete {count} component?',
              otherEnglish: 'Delete {count} components?',
            )
          : huiText('Delete {id}?', <String, Object?>{
              'id': store.selectedId ?? huiText('this component'),
            }),
      message: huiPlural(
        'shell.delete_components.message',
        count,
        oneEnglish:
            'The component is removed from the menu. Undo brings it back.',
        otherEnglish:
            'The components are removed from the menu. Undo brings them back.',
      ),
      confirmText: huiText('Delete'),
      cancelText: huiText('Keep'),
      destructive: true,
      onCancel: () => setState(() => _confirmDelete = false),
      onConfirm: () {
        setState(() => _confirmDelete = false);
        intents.deleteSelectedNow();
      },
    );
  }
}

/// Visual / preview / code / split for a menu, card / code for a container
/// preview. Rebuilds only when the view actually changes, not on every store
/// notification.
///
/// The canvas cell is child 0 in every arm and the card cell child 1, and both
/// are only ever hidden by CSS, never unmounted. Anything else destroys their
/// state on a view switch — Jaspr replaces a child whose runtimeType changed —
/// which resets zoom and pan and throws away the font calibration and every
/// decoded bitmap. Both surfaces gate their clocks on having a box to draw
/// into, so a hidden one costs nothing.
///
/// The code and preview cells ARE genuinely unmounted when inactive, for
/// opposite reasons that land in the same place: a live [CodeEditorView]
/// re-serializes the whole document on every store notification, and a live 3D
/// preview keeps a rAF loop and a 50 ms simulation timer running with no
/// equivalent gate.
class _CenterArea extends StatelessWidget {
  const _CenterArea({
    required this.store,
    required this.canvas,
    required this.previewCard,
    required this.surfaces,
    required this.previews,
    required this.codeEditor,
  });

  final EditorStore store;
  final Widget canvas;
  final Widget previewCard;
  final Map<DocumentSurface, Widget> surfaces;
  final Map<DocumentSurface, Widget> previews;
  final Widget codeEditor;

  @override
  Widget build(BuildContext context) =>
      StoreSelector<({bool active, EditorView view, DocumentSurface surface})>(
        listenable: store,
        selector: () => (
          active: store.hasActiveDocument,
          view: store.view,
          surface: store.docType.surface,
        ),
        builder:
            (
              BuildContext context,
              ({bool active, EditorView view, DocumentSurface surface}) state,
            ) => state.active
            ? _active(state.view, state.surface)
            : dom.section(
                classes: 'hui-pane hui-center is-empty-workspace',
                <Widget>[
                  ArcaneEmptyState(
                    title: huiText('Workspace is empty'),
                    description: huiText(
                      'Create a document in the Library or start from a '
                      'template.',
                    ),
                    icon: ArcaneIcon.filePlus(size: IconSize.lg),
                  ),
                ],
              ),
      );

  Widget _active(EditorView view, DocumentSurface surface) => dom.section(
    classes: switch (view) {
      EditorView.visual => 'hui-pane hui-center is-visual',
      EditorView.preview => 'hui-pane hui-center is-preview',
      EditorView.code => 'hui-pane hui-center is-code',
      EditorView.split => 'hui-pane hui-center is-split',
    },
    // Which of the two always-mounted cells is on screen is decided here, in
    // CSS, because neither may be unmounted to hide it.
    attributes: <String, String>{'data-surface': surface.name},
    <Widget>[
      dom.div(classes: 'hui-split-cell is-canvas', <Widget>[canvas]),
      dom.div(classes: 'hui-split-cell is-preview-card', <Widget>[previewCard]),
      if (_mountsSurfaceCell(view, surface))
        dom.div(
          key: ValueKey<String>('surface-${surface.name}'),
          classes: 'hui-split-cell ${_surfaceCellClass(surface)}',
          <Widget>[surfaces[surface] ?? _missing(surface)],
        ),
      if (view == EditorView.preview)
        dom.div(
          key: ValueKey<String>('preview-${surface.name}'),
          classes: 'hui-split-cell is-preview',
          attributes: <String, String>{'data-surface': surface.name},
          <Widget>[previews[surface] ?? _missing(surface)],
        ),
      if (view == EditorView.code || view == EditorView.split)
        dom.div(
          key: const ValueKey<String>('code'),
          classes: 'hui-split-cell is-code',
          <Widget>[codeEditor],
        ),
    ],
  );

  /// The two always-mounted surfaces never get a second cell; every other
  /// surface is mounted for exactly as long as it is on screen.
  static bool _mountsSurfaceCell(EditorView view, DocumentSurface surface) =>
      (view == EditorView.visual || view == EditorView.split) &&
      surface != DocumentSurface.canvas &&
      surface != DocumentSurface.previewCard;

  /// The world panel kept its pre-Gloss cell name; the rest are their own.
  static String _surfaceCellClass(DocumentSurface surface) => switch (surface) {
    DocumentSurface.canvas => 'is-canvas',
    DocumentSurface.previewCard => 'is-preview-card',
    DocumentSurface.panel => 'is-board',
    DocumentSurface.hologram => 'is-hologram',
    DocumentSurface.animation => 'is-animation',
    DocumentSurface.scoreboard => 'is-scoreboard',
    DocumentSurface.motd => 'is-motd',
    DocumentSurface.emoji => 'is-emoji',
    DocumentSurface.bubble => 'is-bubble',
    DocumentSurface.damageIndicators => 'is-damage-indicators',
    DocumentSurface.tablist => 'is-tablist',
    DocumentSurface.realDrops => 'is-real-drops',
  };

  /// A slot the owner did not supply. Reachable only from a wiring mistake, so
  /// it names the missing surface instead of rendering an empty pane.
  static Widget _missing(DocumentSurface surface) => ArcaneEmptyState(
    title: huiText('That surface is not in this build'),
    description: huiText(
      "No widget is wired for the {name} surface.",
      <String, Object?>{'name': surface.name},
    ),
    icon: ArcaneIcon.triangleAlert(size: IconSize.lg),
  );
}

class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-dropzone',
    attributes: const <String, String>{'aria-hidden': 'true'},
    <Widget>[
      dom.div(classes: 'hui-dropzone-card', <Widget>[
        ArcaneIcon.upload(size: IconSize.lg),
        dom.p(<Widget>[Text(huiText('Drop a menu .json or PNG images'))]),
      ]),
    ],
  );
}

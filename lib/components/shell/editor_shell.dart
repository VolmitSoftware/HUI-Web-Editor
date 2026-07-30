/// The application frame.
///
/// A fixed-height grid: bar / (rail, centre, inspector) / status. The shell
/// itself never scrolls — each pane owns `min-height: 0; overflow-y: auto`, so
/// there is never a scrollbar inside a scrollbar.
///
/// Panels built by other modules arrive as slots, so this file depends on none
/// of them:
///
/// ```dart
/// EditorScope(
///   store: store,
///   child: EditorShell(
///     rail: const ComponentsRail(),
///     canvas: const CanvasViewport(),
///     inspector: const InspectorPane(),
///     codeEditor: const CodeEditorView(),
///     overlays: <Widget>[ExportDialog(...), HelpDialog(...)],
///   ),
/// );
/// ```
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../services/file_transfer.dart';
import '../../services/image_library.dart';
import '../../state/editor_scope.dart';
import '../../state/editor_store.dart';
import 'command_palette.dart';
import 'key_listener.dart';
import 'keyboard_shortcuts.dart';
import 'shell_actions.dart';
import 'shell_intents.dart';
import 'shell_status.dart';
import 'status_bar.dart';
import 'store_selector.dart';
import 'top_bar.dart';

class EditorShell extends StatefulWidget {
  const EditorShell({
    required this.rail,
    required this.canvas,
    required this.inspector,
    required this.codeEditor,
    required this.overlays,
    this.store,
    this.status,
    this.onOpenImport,
    this.onOpenExport,
    this.onOpenImages,
    this.onOpenTemplates,
    this.onOpenHelp,
    this.onOpenSettings,
    this.onOpenValidation,
    this.onCloseOverlay,
    this.onToggleTheme,
    this.darkMode = true,
    super.key,
  });

  final Widget rail;
  final Widget canvas;
  final Widget inspector;
  final Widget codeEditor;

  /// Dialogs and sheets owned by other modules, mounted above the frame.
  final List<Widget> overlays;

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

  @override
  void initState() {
    super.initState();
    _apple = isApplePlatform();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final EditorStore resolved = component.store ?? EditorScope.of(context);
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
      onJson: resolved.importJson,
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

  Future<void> _acceptImages(List<Object> files) async {
    final ImageLibrary? library = _store?.images;
    if (library == null) {
      ArcaneSonner.error('The image library is not available in this build.');
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
      ArcaneSonner.success('Added $count image${count == 1 ? '' : 's'}.');
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
      onTogglePalette: _togglePalette,
      onCloseOverlay: component.onCloseOverlay,
      child: dom.div(
        classes: 'hui-shell',
        <Widget>[
          TopBar(
            intents: intents,
            apple: _apple,
            darkMode: component.darkMode,
          ),
          dom.div(
            classes: 'hui-shell-body',
            <Widget>[
              dom.aside(
                classes: 'hui-pane hui-rail',
                attributes: const <String, String>{'aria-label': 'Components'},
                <Widget>[component.rail],
              ),
              _CenterArea(
                store: store,
                canvas: component.canvas,
                codeEditor: component.codeEditor,
              ),
              dom.aside(
                classes: 'hui-pane hui-inspector',
                attributes: const <String, String>{'aria-label': 'Inspector'},
                <Widget>[component.inspector],
              ),
            ],
          ),
          StatusBar(
            store: store,
            status: component.status,
            onOpenValidation: component.onOpenValidation,
          ),
          ...component.overlays,
          if (_paletteOpen)
            ShellCommandPalette(
              actions: buildShellActions(intents),
              onClose: _closePalette,
              apple: _apple,
            ),
          if (_confirmDelete) _deleteDialog(store, intents),
          if (_dropActive) const _DropOverlay(),
          const ArcaneSonner(position: ToastPosition.bottomRight),
        ],
      ),
    );
  }

  /// Keyed per arming: the dialog surface is closed by the injected JS runtime,
  /// so reusing the element would re-open a node the runtime already hid.
  Widget _deleteDialog(EditorStore store, ShellIntents intents) {
    final String id = store.selectedId ?? 'this component';
    return ArcaneConfirmDialog(
      key: ValueKey<int>(_confirmSeq),
      title: 'Delete $id?',
      message: 'The component is removed from the menu. Undo brings it back.',
      confirmText: 'Delete',
      cancelText: 'Keep',
      destructive: true,
      onCancel: () => setState(() => _confirmDelete = false),
      onConfirm: () {
        setState(() => _confirmDelete = false);
        intents.deleteSelectedNow();
      },
    );
  }
}

/// Visual / code / split. Rebuilds only when the view actually changes, not on
/// every store notification.
///
/// The canvas cell is child 0 in all three arms and is only ever hidden by CSS,
/// never unmounted. Anything else destroys `_CanvasViewportState` on a view
/// switch — Jaspr replaces a child whose runtimeType changed — which resets
/// zoom and pan and throws away every decoded bitmap and the font calibration.
/// The code cell is genuinely unmounted in the visual view instead of hidden,
/// because a live [CodeEditorView] re-serializes the whole document on every
/// store notification.
class _CenterArea extends StatelessWidget {
  const _CenterArea({
    required this.store,
    required this.canvas,
    required this.codeEditor,
  });

  final EditorStore store;
  final Widget canvas;
  final Widget codeEditor;

  @override
  Widget build(BuildContext context) => StoreSelector<EditorView>(
        listenable: store,
        selector: () => store.view,
        builder: (BuildContext context, EditorView view) => dom.section(
          classes: switch (view) {
            EditorView.visual => 'hui-pane hui-center is-visual',
            EditorView.code => 'hui-pane hui-center is-code',
            EditorView.split => 'hui-pane hui-center is-split',
          },
          <Widget>[
            dom.div(classes: 'hui-split-cell', <Widget>[canvas]),
            if (view != EditorView.visual)
              dom.div(
                classes: 'hui-split-cell is-code',
                <Widget>[codeEditor],
              ),
          ],
        ),
      );
}

class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) => dom.div(
        classes: 'hui-dropzone',
        attributes: const <String, String>{'aria-hidden': 'true'},
        <Widget>[
          dom.div(
            classes: 'hui-dropzone-card',
            <Widget>[
              ArcaneIcon.upload(size: IconSize.lg),
              const dom.p(<Widget>[Text('Drop a menu .json or PNG images')]),
            ],
          ),
        ],
      );
}

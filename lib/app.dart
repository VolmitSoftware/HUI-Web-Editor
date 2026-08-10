import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:arcane_jaspr_shadcn/arcane_jaspr_shadcn.dart';

import 'components/canvas/canvas.dart';
import 'components/code_editor/code_editor_view.dart';
import 'components/dialogs/dialogs.dart';
import 'components/inspector/inspector.dart';
import 'components/panels/panels.dart';
import 'components/preview/preview_view.dart';
import 'components/preview_card/preview_card.dart';
import 'components/shell/shell.dart';
import 'services/catalogs.dart';
import 'services/image_library.dart';
import 'state/editor_scope.dart';
import 'state/editor_store.dart';
import 'theme/theme_state.dart';

enum _EditorDialog { none, import, export, images, templates, settings, help }

/// Shadcn with every remote asset stripped out.
///
/// The stock stylesheet injects a render-blocking Google Fonts link and its
/// preconnects for Inter. Geist is bundled in `web/assets/fonts/`, so the
/// remote list is emptied and the font stack is declared here.
class _OfflineShadcnStylesheet extends ShadcnStylesheet {
  const _OfflineShadcnStylesheet({super.theme});

  @override
  List<String> get externalCssUrls => const <String>[];

  @override
  FontConfig get fonts => const FontConfig(
    sans:
        "'Geist', ui-sans-serif, system-ui, -apple-system, "
        "BlinkMacSystemFont, 'Segoe UI', sans-serif",
    mono:
        "'Geist Mono', ui-monospace, SFMono-Regular, Menlo, Monaco, "
        'Consolas, monospace',
  );
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  Brightness _brightness = Brightness.dark;

  late final ImageLibrary _images;
  late final EditorStore _store;
  final ShellStatus _status = ShellStatus();
  HuiCatalogs? _catalogs;

  _EditorDialog _dialog = _EditorDialog.none;
  bool _validationOpen = false;

  @override
  void initState() {
    super.initState();
    _brightness = loadStoredBrightness();
    stampDocumentTheme(_brightness);

    _images = ImageLibrary();
    _store = EditorStore(images: _images);

    HuiCatalogs.load().then((HuiCatalogs catalogs) {
      if (!mounted) return;
      setState(() {
        _catalogs = catalogs;
        _store.setCatalogs(catalogs);
      });
    });
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  void _toggleBrightness() {
    setState(() {
      _brightness = _brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark;
      persistBrightness(_brightness);
      stampDocumentTheme(_brightness);
    });
  }

  void _openDialog(_EditorDialog dialog) => setState(() {
    _validationOpen = false;
    _dialog = dialog;
  });

  void _closeDialog() => setState(() => _dialog = _EditorDialog.none);

  void _closeOverlay() => setState(() {
    _dialog = _EditorDialog.none;
    _validationOpen = false;
  });

  @override
  Widget build(BuildContext context) => ArcaneApp(
    stylesheet: const _OfflineShadcnStylesheet(theme: ShadcnTheme.midnight),
    brightness: _brightness,
    title: 'HoloUI Editor',
    description:
        'Visual web editor for creating and previewing HoloUI menu configurations.',
    // Stays true, and the reason is not the one the flag's name suggests.
    // `ArcaneApp` gates ONE component on it (`support/app.dart:114`) and
    // that component emits `ArcaneScripts.all` — the modern
    // `data-arcane-*` interaction runtime AND the legacy one-shot binder,
    // in a single <script>. There is no switch for the binder alone.
    //
    // Measured with it false, against this build: every dialog overlay
    // rendered as a visible full-screen scrim (the dropped
    // `arcaneInteractivityRuntimeCss` owns
    // `[data-arcane-surface][hidden]{display:none!important}`, which we can
    // port), and — which we cannot port — no `ArcaneDropdownMenu` opened
    // (the top bar's document switcher, the rail's component-type menu) and
    // no `ArcaneContextMenu` opened (rail rows), because their open state
    // lives entirely in that runtime. Dialog backdrop dismissal went with
    // it too. Dialogs, sheets, popovers, selects, tooltips, toasts and the
    // theme toggle were unaffected: those are Dart-driven.
    //
    // Recovering the three broken surfaces would mean reimplementing the
    // runtime's attribute protocol ourselves, which is strictly worse than
    // paying for its one-shot querySelectorAll scan at boot.
    includeFallbackScripts: true,
    home: EditorScope(
      store: _store,
      child: EditorShell(
        store: _store,
        status: _status,
        darkMode: _brightness == Brightness.dark,
        onToggleTheme: _toggleBrightness,
        onOpenImport: () => _openDialog(_EditorDialog.import),
        onOpenExport: () => _openDialog(_EditorDialog.export),
        onOpenImages: () => _openDialog(_EditorDialog.images),
        onOpenTemplates: () => _openDialog(_EditorDialog.templates),
        onOpenSettings: () => _openDialog(_EditorDialog.settings),
        onOpenHelp: () => _openDialog(_EditorDialog.help),
        onOpenValidation: () =>
            setState(() => _validationOpen = !_validationOpen),
        onCloseOverlay: _closeOverlay,
        rail: ComponentsRail(store: _store),
        canvas: CanvasViewport(
          store: _store,
          images: _images,
          catalogs: _catalogs,
          status: _status,
        ),
        previewCard: PreviewCardViewport(
          store: _store,
          catalogs: _catalogs,
          status: _status,
        ),
        preview: PreviewView(
          store: _store,
          images: _images,
          catalogs: _catalogs,
        ),
        inspector: InspectorPane(
          store: _store,
          images: _images,
          catalogs: _catalogs,
        ),
        codeEditor: CodeEditorView(store: _store),
        overlays: <Widget>[
          ImportDialog(
            store: _store,
            isOpen: _dialog == _EditorDialog.import,
            onClose: _closeDialog,
          ),
          ExportDialog(
            store: _store,
            images: _images,
            isOpen: _dialog == _EditorDialog.export,
            onClose: _closeDialog,
          ),
          ImageManagerDialog(
            store: _store,
            images: _images,
            isOpen: _dialog == _EditorDialog.images,
            onClose: _closeDialog,
          ),
          TemplatesDialog(
            store: _store,
            isOpen: _dialog == _EditorDialog.templates,
            onClose: _closeDialog,
          ),
          SettingsDialog(
            store: _store,
            isOpen: _dialog == _EditorDialog.settings,
            onClose: _closeDialog,
            onToggleTheme: _toggleBrightness,
            isDarkMode: _brightness == Brightness.dark,
          ),
          HelpDialog(
            store: _store,
            isOpen: _dialog == _EditorDialog.help,
            onClose: _closeDialog,
          ),
          ValidationPanel(
            store: _store,
            isOpen: _validationOpen,
            onClose: () => setState(() => _validationOpen = false),
          ),
        ],
      ),
    ),
  );
}

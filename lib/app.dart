import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:arcane_jaspr_shadcn/arcane_jaspr_shadcn.dart';

import 'components/canvas/canvas.dart';
import 'components/code_editor/code_editor_view.dart';
import 'components/dialogs/dialogs.dart';
import 'components/inspector/inspector.dart';
import 'components/panels/panels.dart';
import 'components/shell/shell.dart';
import 'services/catalogs.dart';
import 'services/image_library.dart';
import 'state/editor_scope.dart';
import 'state/editor_store.dart';
import 'theme/theme_state.dart';

enum _EditorDialog { none, import, export, images, templates, settings, help }

/// Shadcn with every remote asset stripped out.
///
/// The stock stylesheet injects a render-blocking Google Fonts link (plus its
/// preconnects) for Inter. This editor is served from `/holoui builder start`
/// on game servers that may have no outbound internet, where that request
/// stalls the first paint until it times out. Geist is bundled in
/// `web/assets/fonts/`, so the remote list is emptied and the font stack is
/// declared here rather than being overridden later in CSS.
class _OfflineShadcnStylesheet extends ShadcnStylesheet {
  const _OfflineShadcnStylesheet({super.theme});

  @override
  List<String> get externalCssUrls => const <String>[];

  @override
  FontConfig get fonts => const FontConfig(
        sans: "'Geist', ui-sans-serif, system-ui, -apple-system, "
            "BlinkMacSystemFont, 'Segoe UI', sans-serif",
        mono: "'Geist Mono', ui-monospace, SFMono-Regular, Menlo, Monaco, "
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
      _brightness = _brightness == Brightness.dark ? Brightness.light : Brightness.dark;
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
        description: 'Visual web editor for creating and previewing HoloUI menu configurations.',
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
            onOpenValidation: () => setState(() => _validationOpen = !_validationOpen),
            onCloseOverlay: _closeOverlay,
            rail: ComponentsRail(store: _store),
            canvas: CanvasViewport(
              store: _store,
              images: _images,
              catalogs: _catalogs,
              status: _status,
            ),
            inspector: InspectorPane(store: _store, images: _images, catalogs: _catalogs),
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

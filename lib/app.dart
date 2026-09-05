import 'dart:async';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:arcane_jaspr_shadcn/arcane_jaspr_shadcn.dart';

import 'components/canvas/canvas.dart';
import 'components/panel/panel.dart';
import 'components/code_editor/code_editor_view.dart';
import 'components/dialogs/dialogs.dart';
import 'components/animation/animation_view.dart';
import 'components/bubble/bubble_view.dart';
import 'components/damage_indicators/damage_indicator_view.dart';
import 'components/emoji/emoji_view.dart';
import 'components/entity_overlays/entity_overlay_view.dart';
import 'components/motd/motd_view.dart';
import 'components/scoreboard/scoreboard_view.dart';
import 'components/real_drops/real_drops_view.dart';
import 'components/tablist/tablist_view.dart';
import 'components/hologram/hologram_view.dart';
import 'components/inspector/inspector.dart';
import 'components/panels/panels.dart';
import 'components/preview/preview_view.dart';
import 'components/preview_card/preview_card.dart';
import 'components/shell/shell.dart';
import 'config/defaults.dart';
import 'model/model.dart';
import 'services/catalogs.dart';
import 'services/clipboard.dart';
import 'services/editor_sync.dart';
import 'services/file_transfer.dart';
import 'services/image_library.dart';
import 'services/page_lifecycle.dart';
import 'services/workspace_location.dart';
import 'state/editor_scope.dart';
import 'doctype/doctype.dart';
import 'l10n/hui_locale_loader.dart';
import 'l10n/hui_locale_preferences.dart';
import 'l10n/hui_localizations.dart';
import 'logic/preview_sim.dart';
import 'state/editor_store.dart';
import 'state/workspace.dart';
import 'state/workspace_bundle.dart';
import 'state/workspace_route.dart';
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
  FontConfig get fonts => const FontConfig(
    sans:
        "'Geist', ui-sans-serif, system-ui, -apple-system, "
        "BlinkMacSystemFont, 'Segoe UI', sans-serif",
    mono:
        "'Geist Mono', ui-monospace, SFMono-Regular, Menlo, Monaco, "
        'Consolas, monospace',
  );

  @override
  RadiusConfig get radius => const RadiusConfig.sharp();
}

class App extends StatefulWidget {
  const App({
    required this.workspace,
    required this.images,
    required this.localeController,
    super.key,
  });

  final Workspace workspace;
  final ImageLibrary images;
  final HuiLocaleController localeController;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  Brightness _brightness = Brightness.dark;
  late String _activeLocale;
  bool _localeLoading = false;
  int _localeRequest = 0;

  late final ImageLibrary _images;
  late final EditorStore _store;
  final ShellStatus _status = ShellStatus();
  HuiCatalogs? _catalogs;
  WorkspaceMenuImportEnvelope? _menuHandoff;
  final EditorSyncClient _syncClient = EditorSyncClient();
  final EditorSyncPollGate _syncPollGate = EditorSyncPollGate();
  EditorSyncBinding? _syncBinding;
  EditorSyncSession? _syncSession;
  EditorSyncSession? _syncImportSession;
  EditorSyncBinding? _syncImportCapability;
  Timer? _syncPollTimer;
  String Function()? _syncError;
  String Function()? _syncPersistenceWarning;
  bool _syncLoading = false;
  bool _syncPublishing = false;
  bool _syncConflictOpen = false;
  void Function() _stopHashListener = () {};
  void Function() _stopPageExitListener = () {};
  bool _applyingHash = false;

  _EditorDialog _dialog = _EditorDialog.none;
  bool _validationOpen = false;
  ({String? documentId, Vec3 offset})? _pendingCanvasMedia;

  @override
  void initState() {
    super.initState();
    _activeLocale = component.localeController.activeLocale;
    stampHuiLocaleDocument(_activeLocale);
    _brightness = loadStoredBrightness();
    stampDocumentTheme(_brightness);

    _images = component.images;
    _store = EditorStore(workspace: component.workspace, images: _images);
    _stopPageExitListener = listenForPageExit(
      () => _store.flushAutosave(notify: false),
    );
    _applyWorkspaceHash(readWorkspaceLocationHash(), notify: false);
    if (_syncImportCapability == null) {
      _restoreSyncBinding();
    }
    _store.addListener(_syncWorkspaceHash);
    _stopHashListener = listenWorkspaceLocationHash(
      (String hash) => _applyWorkspaceHash(hash, notify: true),
    );
    if (_menuHandoff == null && readWorkspaceLocationHash().isEmpty) {
      _syncWorkspaceHash(replace: true);
    }

    HuiCatalogs.load().then((HuiCatalogs catalogs) {
      if (!mounted) return;
      final HuiCatalogs localized = _withActivePreviewLocale(catalogs);
      setState(() {
        _catalogs = localized;
        _store.setCatalogs(localized);
      });
    });
  }

  Future<void> _changeLocale(String locale) async {
    if (locale == _activeLocale && !_localeLoading) return;
    final int request = ++_localeRequest;
    setState(() => _localeLoading = true);
    final HuiLocaleInstallResult result = await component.localeController
        .activate(locale);
    if (!mounted || request != _localeRequest) return;
    if (!result.applied) {
      setState(() => _localeLoading = false);
      ArcaneSonner.error(
        huiText(
          'Could not change language. The current language is still active.',
        ),
      );
      return;
    }
    final String activeLocale = component.localeController.activeLocale;
    persistHuiLocale(activeLocale);
    stampHuiLocaleDocument(activeLocale);
    final HuiCatalogs localized = _withActivePreviewLocale(_store.catalogs);
    setState(() {
      _activeLocale = activeLocale;
      _localeLoading = false;
      _catalogs = localized;
    });
    _store.setCatalogs(localized);
  }

  HuiCatalogs _withActivePreviewLocale(HuiCatalogs catalogs) {
    final Map<String, String> messages =
        huiLocalizations.snapshot.previewMessages;
    if (messages.isEmpty) return catalogs;
    return catalogs.withPreviewLang(PreviewLangCatalog(messages));
  }

  @override
  void dispose() {
    _syncPollTimer?.cancel();
    _syncClient.close();
    _stopPageExitListener();
    _stopHashListener();
    _store.removeListener(_syncWorkspaceHash);
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
    _pendingCanvasMedia = null;
    _validationOpen = false;
    _dialog = dialog;
  });

  void _closeDialog() => setState(() {
    _pendingCanvasMedia = null;
    _dialog = _EditorDialog.none;
  });

  void _openCanvasMedia(Vec3 offset) => setState(() {
    _pendingCanvasMedia = (
      documentId: _store.workspace.activeId,
      offset: offset.copy(),
    );
    _validationOpen = false;
    _dialog = _EditorDialog.images;
  });

  void _closeImageDialog() => setState(() {
    _pendingCanvasMedia = null;
    _dialog = _EditorDialog.none;
  });

  void _useCanvasImage(StoredImage image) {
    final ({String? documentId, Vec3 offset})? pending = _pendingCanvasMedia;
    if (pending == null || pending.documentId != _store.workspace.activeId) {
      return;
    }
    _store.addComponentData(
      HuiDecorationData(HuiTextImageIcon(image.path)),
      offset: pending.offset,
      id: 'image',
    );
  }

  void _useCanvasAnimation(List<StoredImage> frames) {
    final ({String? documentId, Vec3 offset})? pending = _pendingCanvasMedia;
    if (pending == null ||
        pending.documentId != _store.workspace.activeId ||
        frames.isEmpty) {
      return;
    }
    _store.addComponentData(
      HuiDecorationData(
        HuiAnimatedImageIcon(
          frames.map((StoredImage image) => image.path).toList(),
          huiDefaultAnimationSpeed,
        ),
      ),
      offset: pending.offset,
      id: 'animation',
    );
  }

  void _closeOverlay() => setState(() {
    _pendingCanvasMedia = null;
    _dialog = _EditorDialog.none;
    _validationOpen = false;
  });

  void _applyWorkspaceHash(String hash, {required bool notify}) {
    final WorkspaceRouteResult parsed = parseWorkspaceRoute(hash);
    final WorkspaceRoute? route = parsed.route;
    if (route is WorkspaceMenuImportRoute) {
      if (notify) {
        setState(() => _menuHandoff = route.envelope);
      } else {
        _menuHandoff = route.envelope;
      }
      return;
    }
    if (route is WorkspaceSyncRoute) {
      _beginSyncRoute(route);
      return;
    }
    if (route is WorkspaceDocumentRoute) {
      if (_menuHandoff != null) {
        if (notify) {
          setState(() => _menuHandoff = null);
        } else {
          _menuHandoff = null;
        }
      }
      if (route.workspaceId != _store.workspace.id) {
        _reportRouteError(
          huiText(
            'That link belongs to a different local workspace. Import its workspace bundle first.',
          ),
        );
        return;
      }
      _applyingHash = true;
      final bool opened = _store.openDocument(route.documentId);
      _applyingHash = false;
      if (!opened) {
        _reportRouteError(
          huiText('That linked document is not in this workspace.'),
        );
      }
      return;
    }
    if (parsed.error != null) _reportRouteError(parsed.error!);
  }

  void _syncWorkspaceHash({bool replace = false}) {
    if (_applyingHash ||
        _menuHandoff != null ||
        _syncImportCapability != null) {
      return;
    }
    final EditorSyncBinding? syncBinding = _syncBinding;
    if (syncBinding != null && _syncPersistenceWarning != null) {
      writeWorkspaceLocationHash(
        workspaceSyncHash(
          sessionId: syncBinding.sessionId,
          editorToken: syncBinding.editorToken,
          relayEndpoint: syncBinding.relayEndpoint,
        ),
        replace: true,
      );
      return;
    }
    final String? documentId = _store.workspace.activeId;
    final String current = readWorkspaceLocationHash();
    if (documentId == null) {
      if (current.startsWith('#/workspace/')) {
        writeWorkspaceLocationHash('', replace: true);
      }
      return;
    }
    writeWorkspaceLocationHash(
      workspaceDocumentHash(_store.workspace.id, documentId),
      replace: replace || current.startsWith('#/import/menu/'),
    );
  }

  void _reportRouteError(String message) {
    Timer.run(() {
      if (mounted) ArcaneSonner.error(message);
    });
  }

  void _cancelMenuHandoff() {
    setState(() => _menuHandoff = null);
    _syncWorkspaceHash(replace: true);
  }

  void _confirmMenuHandoff() {
    final WorkspaceMenuImportEnvelope? envelope = _menuHandoff;
    if (envelope == null) return;
    final bool created = _store.newMenuDocumentFromJson(
      name: envelope.runtimeId.split('/').last,
      runtimeId: envelope.runtimeId,
      json: envelope.json,
    );
    if (!created) return;
    setState(() => _menuHandoff = null);
    ArcaneSonner.success(
      huiText('Added {document} to the workspace.', <String, Object?>{
        'document': envelope.runtimeId,
      }),
    );
  }

  void _restoreSyncBinding() {
    final EditorSyncBinding? binding = loadEditorSyncBinding(
      _store.workspace.id,
    );
    if (binding == null) return;
    _syncBinding = binding;
    _startSyncPolling();
  }

  void _beginSyncRoute(WorkspaceSyncRoute route) {
    final EditorSyncBinding capability = EditorSyncBinding(
      sessionId: route.sessionId,
      editorToken: route.editorToken,
      relayEndpoint: route.relayEndpoint,
      kind: 'workspace',
      subjectId: 'workspace',
      baseRevision: 'sha256:${List<String>.filled(64, '0').join()}',
      documentIds: const <String, String>{},
      imagePaths: const <String>[],
      constraints: EditorSyncConstraints(
        subjectId: 'workspace',
        documentKinds: huiEditorSyncDocumentKinds,
        createDocumentKinds: huiEditorSyncDocumentKinds,
        allowDeletes: true,
      ),
      warnings: const <String>[],
    );
    setState(() {
      _syncImportCapability = capability;
      _syncImportSession = null;
      _syncError = null;
      _syncLoading = false;
    });
  }

  void _loadSyncImport() {
    final EditorSyncBinding? capability = _syncImportCapability;
    if (capability == null || _syncLoading) return;
    setState(() {
      _syncLoading = true;
      _syncError = null;
    });
    _syncClient
        .fetch(capability, initialSnapshot: true)
        .then((EditorSyncSession session) {
          if (!mounted ||
              _syncImportCapability?.sessionId != capability.sessionId) {
            return;
          }
          setState(() {
            _syncImportSession = session;
            _syncLoading = false;
          });
        })
        .catchError((Object error) {
          if (!mounted ||
              _syncImportCapability?.sessionId != capability.sessionId) {
            return;
          }
          setState(() {
            _syncError = error is EditorSyncFailure
                ? () => error.message
                : () => huiText('The relay response could not be read.');
            _syncLoading = false;
          });
        });
  }

  bool get _syncImportHasConflicts {
    final EditorSyncProject? project = _syncImportSession?.project;
    if (project == null) return false;
    return _store.workspace.docs.isNotEmpty || _images.images.isNotEmpty;
  }

  EditorSyncStatus get _visibleSyncStatus {
    final EditorSyncStatus? current = _syncSession?.status;
    if (current == EditorSyncStatus.expired ||
        current == EditorSyncStatus.revoked) {
      return current!;
    }
    if (_syncConflictOpen) {
      return current == EditorSyncStatus.rejected
          ? EditorSyncStatus.rejected
          : EditorSyncStatus.conflict;
    }
    if (_syncError != null) return EditorSyncStatus.unavailable;
    return current ?? EditorSyncStatus.connected;
  }

  void _cancelSyncImport() {
    setState(() {
      _syncImportCapability = null;
      _syncImportSession = null;
      _syncError = null;
      _syncLoading = false;
    });
    _syncWorkspaceHash(replace: true);
  }

  Future<void> _confirmSyncImport() async {
    final EditorSyncBinding? capability = _syncImportCapability;
    final EditorSyncSession? session = _syncImportSession;
    if (capability == null || session == null) return;
    try {
      final EditorSyncBinding binding = await importEditorSyncProject(
        capability: capability,
        project: session.project,
        workspace: _store.workspace,
        images: _images,
      );
      final bool durable = _persistSyncBinding(binding);
      setState(() {
        _syncBinding = binding;
        _syncSession = session;
        _syncImportCapability = null;
        _syncImportSession = null;
        _syncError = null;
      });
      final String? first = binding.firstDocumentId;
      if (first != null) _store.openDocument(first);
      if (durable) {
        _syncWorkspaceHash(replace: true);
      } else {
        writeWorkspaceLocationHash(
          workspaceSyncHash(
            sessionId: binding.sessionId,
            editorToken: binding.editorToken,
            relayEndpoint: binding.relayEndpoint,
          ),
          replace: true,
        );
      }
      _startSyncPolling();
      ArcaneSonner.success(
        huiText('Connected {subject}.', <String, Object?>{
          'subject': binding.subjectId,
        }),
      );
    } on EditorSyncFailure catch (error) {
      setState(() => _syncError = () => error.message);
    }
  }

  void _startSyncPolling() {
    _syncPollTimer?.cancel();
    _refreshSyncStatus();
    _syncPollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshSyncStatus(),
    );
  }

  Future<void> _refreshSyncStatus() async {
    final EditorSyncBinding? binding = _syncBinding;
    if (binding == null) return;
    final EditorSyncBinding? captured = _syncPollGate.begin(binding);
    if (captured == null) return;
    try {
      final EditorSyncSession session = await _syncClient.fetch(captured);
      if (!mounted || !_syncPollGate.shouldApply(captured, _syncBinding)) {
        return;
      }
      EditorSyncBinding next = captured;
      if (session.status == EditorSyncStatus.applied &&
          session.baseRevision != captured.baseRevision) {
        final EditorSyncAppliedResolution resolution =
            await resolveEditorSyncApplied(
              binding: captured,
              serverProject: session.project,
              workspace: _store.workspace,
              images: _images,
            );
        if (resolution.decision == EditorSyncAppliedDecision.reconcile) {
          next = resolution.binding;
          _persistSyncBinding(next);
        } else {
          setState(() {
            _syncSession = session;
            _syncError = () => huiText(
              'The server applied the publication, but this tab changed while it was pending. Export or refresh before publishing again.',
            );
            _syncConflictOpen = true;
          });
          return;
        }
      }
      final EditorSyncBinding terminal = reconcileEditorSyncTerminalStatus(
        next,
        session.status,
      );
      if (!identical(terminal, next)) {
        next = terminal;
        _persistSyncBinding(next);
      }
      final EditorSyncSession visibleSession =
          session.status == EditorSyncStatus.conflict &&
              next.pendingContentRevision == null &&
              session.baseRevision == next.baseRevision
          ? EditorSyncSession(
              sessionId: session.sessionId,
              baseRevision: session.baseRevision,
              expiresAt: session.expiresAt,
              project: session.project,
              status: EditorSyncStatus.connected,
              message: session.message,
              serverRevision: session.serverRevision,
            )
          : session;
      setState(() {
        _syncBinding = next;
        _syncSession = visibleSession;
        _syncError = null;
        _syncConflictOpen = visibleSession.status == EditorSyncStatus.conflict;
      });
    } on EditorSyncGone catch (error) {
      if (!mounted || !_syncPollGate.shouldApply(captured, _syncBinding)) {
        return;
      }
      _syncPollTimer?.cancel();
      setState(() {
        _syncError = () => error.message;
        _syncConflictOpen = false;
        _syncSession = EditorSyncSession(
          sessionId: captured.sessionId,
          baseRevision: captured.baseRevision,
          expiresAt: DateTime.now().toUtc(),
          project: _syncSession?.project ?? _emptySyncProject(captured),
          status: error.revoked
              ? EditorSyncStatus.revoked
              : EditorSyncStatus.expired,
        );
      });
    } on EditorSyncFailure catch (error) {
      if (!mounted || !_syncPollGate.shouldApply(captured, _syncBinding)) {
        return;
      }
      setState(() => _syncError = () => error.message);
    } finally {
      if (_syncPollGate.complete(captured) && mounted) {
        Timer.run(_refreshSyncStatus);
      }
    }
  }

  Future<void> _publishSync() async {
    final EditorSyncBinding? binding = _syncBinding;
    if (binding == null || _syncPublishing) return;
    setState(() {
      _syncPublishing = true;
      _syncError = null;
    });
    try {
      _store.flushAutosave();
      await _store.workspace.writesSettled;
      final EditorSyncProject project = collectEditorSyncProject(
        binding: binding,
        workspace: _store.workspace,
        images: _images,
      );
      await _syncClient.publish(binding, project);
      if (!mounted) return;
      final EditorSyncBinding pending = binding.copyWith(
        pendingContentRevision: project.baseRevision,
      );
      _persistSyncBinding(pending);
      setState(() {
        _syncPublishing = false;
        _syncBinding = pending;
        _syncSession = EditorSyncSession(
          sessionId: binding.sessionId,
          baseRevision: binding.baseRevision,
          expiresAt: _syncSession?.expiresAt ?? DateTime.now().toUtc(),
          project: project,
          status: EditorSyncStatus.pending,
        );
      });
      _refreshSyncStatus();
      ArcaneSonner.success(
        huiText('Published for server validation and apply.'),
      );
    } on EditorSyncConflict catch (error) {
      if (!mounted) return;
      setState(() {
        _syncPublishing = false;
        _syncError = () => error.message;
        _syncConflictOpen = true;
      });
    } on EditorSyncFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _syncPublishing = false;
        _syncError = () => error.message;
      });
      ArcaneSonner.error(error.message);
    }
  }

  Future<void> _copySyncLink() async {
    final EditorSyncBinding? binding = _syncBinding;
    if (binding == null) return;
    final String hash = workspaceSyncHash(
      sessionId: binding.sessionId,
      editorToken: binding.editorToken,
      relayEndpoint: binding.relayEndpoint,
    );
    final bool copied = await copyText(workspaceUrlForHash(hash));
    if (copied) {
      ArcaneSonner.success(
        huiText('Copied the capability link. Anyone with it can edit.'),
      );
    } else {
      ArcaneSonner.error(huiText('The browser refused clipboard access.'));
    }
  }

  bool _persistSyncBinding(EditorSyncBinding binding) {
    final bool persisted = persistEditorSyncBinding(
      _store.workspace.id,
      binding,
      onFailure: (EditorSyncBinding failed) {
        writeWorkspaceLocationHash(
          workspaceSyncHash(
            sessionId: failed.sessionId,
            editorToken: failed.editorToken,
            relayEndpoint: failed.relayEndpoint,
          ),
          replace: true,
        );
      },
    );
    if (persisted) {
      _syncPersistenceWarning = null;
    } else {
      _syncPersistenceWarning = () => huiText(
        'This browser blocked tab storage. The connection still works, but reload will lose it. Copy the sync link before continuing.',
      );
      ArcaneSonner.error(_syncPersistenceWarning!());
    }
    return persisted;
  }

  void _disconnectSync() {
    clearEditorSyncBinding(_store.workspace.id);
    _syncPollTimer?.cancel();
    _syncPollGate.reset();
    setState(() {
      _syncBinding = null;
      _syncSession = null;
      _syncError = null;
      _syncPersistenceWarning = null;
      _syncConflictOpen = false;
    });
    ArcaneSonner.info(
      huiText('Disconnected this tab. The server session was not revoked.'),
    );
    _syncWorkspaceHash(replace: true);
  }

  Future<void> _refreshFromServer() async {
    final EditorSyncBinding? binding = _syncBinding;
    final EditorSyncSession? session = _syncSession;
    if (binding == null || session == null) return;
    try {
      final EditorSyncBinding refreshed = await refreshEditorSyncProject(
        binding: binding.copyWith(baseRevision: session.baseRevision),
        project: session.project,
        workspace: _store.workspace,
        images: _images,
      );
      _persistSyncBinding(refreshed);
      setState(() {
        _syncBinding = refreshed;
        _syncConflictOpen = false;
        _syncError = null;
        _syncSession = EditorSyncSession(
          sessionId: session.sessionId,
          baseRevision: session.baseRevision,
          expiresAt: session.expiresAt,
          project: session.project,
          status: EditorSyncStatus.connected,
        );
      });
      ArcaneSonner.success(
        huiText('Replaced the bound scope with the server copy.'),
      );
    } on EditorSyncFailure catch (error) {
      ArcaneSonner.error(error.message);
    }
  }

  void _exportConflictWork() {
    downloadText(
      'gloss-workspace.json',
      encodeWorkspaceBundle(_store.workspace, _images),
      mime: 'application/json',
    );
    ArcaneSonner.success(huiText('Saved a complete local workspace backup.'));
  }

  EditorSyncProject _emptySyncProject(EditorSyncBinding binding) =>
      EditorSyncProject(
        kind: binding.kind,
        subjectId: binding.subjectId,
        baseRevision: binding.baseRevision,
        documents: const <EditorSyncDocument>[],
        images: const <EditorSyncImage>[],
        constraints: binding.constraints,
      );

  @override
  Widget build(BuildContext context) => ArcaneApp(
    stylesheet: const _OfflineShadcnStylesheet(theme: ShadcnTheme.midnight),
    brightness: _brightness,
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
        activeLocale: _activeLocale,
        localeLoading: _localeLoading,
        onLocaleChanged: _changeLocale,
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
        syncControls: _syncBinding == null
            ? null
            : EditorSyncControls(
                status: _visibleSyncStatus,
                subjectId: _syncBinding!.subjectId,
                busy: _syncPublishing,
                message:
                    _syncError?.call() ??
                    _syncPersistenceWarning?.call() ??
                    _syncSession?.message,
                onPublish: _publishSync,
                onCopyLink: _copySyncLink,
                onDisconnect: _disconnectSync,
              ),
        rail: EditorRail(
          store: _store,
          contents: ComponentsRail(store: _store),
          syncBinding: _syncBinding,
          isDarkMode: _brightness == Brightness.dark,
        ),
        canvas: CanvasViewport(
          store: _store,
          images: _images,
          catalogs: _catalogs,
          status: _status,
          onAddMedia: _openCanvasMedia,
          onAddPlayerHead: _openCanvasMedia,
        ),
        previewCard: PreviewCardViewport(
          store: _store,
          catalogs: _catalogs,
          status: _status,
        ),
        surfaces: <DocumentSurface, Widget>{
          DocumentSurface.panel: PanelView(store: _store),
          DocumentSurface.hologram: HologramView(store: _store),
          DocumentSurface.animation: AnimationView(store: _store),
          DocumentSurface.scoreboard: ScoreboardView(store: _store),
          DocumentSurface.motd: MotdView(store: _store),
          DocumentSurface.emoji: EmojiView(store: _store),
          DocumentSurface.bubble: BubbleView(store: _store),
          DocumentSurface.damageIndicators: DamageIndicatorView(store: _store),
          DocumentSurface.entityOverlays: EntityOverlayView(store: _store),
          DocumentSurface.tablist: TablistView(store: _store),
          DocumentSurface.realDrops: RealDropsView(store: _store),
        },
        // The preview mode's in-game renderings. The menu's is the 3D stage;
        // every other kind renders through its own surface asked for game
        // context, which is what mounts it in the shared game-screen frame —
        // the card included, centred on the GUI screen with its editing chrome
        // dropped. The flow map has no entry at all: it is a diagram of
        // documents, not a thing the server draws, and its adapter reports no
        // runtime preview.
        previews: <DocumentSurface, Widget>{
          DocumentSurface.canvas: PreviewView(
            store: _store,
            images: _images,
            catalogs: _catalogs,
          ),
          DocumentSurface.previewCard: PreviewCardViewport(
            store: _store,
            catalogs: _catalogs,
            gameContext: true,
          ),
          DocumentSurface.hologram: HologramView(
            store: _store,
            gameContext: true,
          ),
          DocumentSurface.animation: AnimationView(
            store: _store,
            gameContext: true,
          ),
          DocumentSurface.scoreboard: ScoreboardView(
            store: _store,
            gameContext: true,
          ),
          DocumentSurface.motd: MotdView(store: _store, gameContext: true),
          DocumentSurface.emoji: EmojiView(store: _store, gameContext: true),
          DocumentSurface.bubble: BubbleView(store: _store, gameContext: true),
          DocumentSurface.damageIndicators: DamageIndicatorView(
            store: _store,
            gameContext: true,
          ),
          DocumentSurface.entityOverlays: EntityOverlayView(
            store: _store,
            gameContext: true,
          ),
          DocumentSurface.tablist: TablistView(
            store: _store,
            gameContext: true,
          ),
          DocumentSurface.realDrops: RealDropsView(
            store: _store,
            gameContext: true,
          ),
        },
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
            onClose: _closeImageDialog,
            onUseImage: _pendingCanvasMedia == null ? null : _useCanvasImage,
            onUseAnimation: _pendingCanvasMedia == null
                ? null
                : _useCanvasAnimation,
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
          MenuHandoffDialog(
            envelope: _menuHandoff,
            onConfirm: _confirmMenuHandoff,
            onClose: _cancelMenuHandoff,
          ),
          EditorSyncImportDialog(
            session: _syncImportSession,
            loading: _syncLoading,
            error: _syncError?.call(),
            hasLocalConflicts: _syncImportHasConflicts,
            relayEndpoint: _syncImportCapability?.relayEndpoint,
            onExportBackup: _exportConflictWork,
            onConfirm: _syncImportSession == null
                ? _loadSyncImport
                : _confirmSyncImport,
            onCancel: _cancelSyncImport,
          ),
          EditorSyncConflictDialog(
            isOpen: _syncConflictOpen,
            message: _syncError?.call() ?? _syncSession?.message,
            onRefresh: _refreshFromServer,
            onExport: _exportConflictWork,
            onClose: () => setState(() => _syncConflictOpen = false),
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

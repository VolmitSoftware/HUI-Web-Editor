/// Editor settings: appearance, canvas defaults, and local data.
///
/// Nothing here is part of the menu format. Everything is a preview or an
/// editor preference, which is why the canvas section says so explicitly — the
/// server's real `uiScale` lives in `plugins/holoui/settings.json` and is
/// global, not per menu.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show ListenableBuilder;

import '../../services/catalogs.dart';
import '../../services/file_transfer.dart';
import '../../services/storage_service.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import '../panels/two_step_button.dart';
import 'dialog_parts.dart';

/// Mirrors the key in `lib/theme/theme_state.dart`. Only re-stamped here, never
/// read: the shell owns the brightness.
const String _themeStorageKey = 'holoui.theme';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({
    required this.store,
    required this.isOpen,
    required this.onClose,
    this.onToggleTheme,
    this.isDarkMode = true,
    super.key,
  });

  final EditorStore store;
  final bool isOpen;
  final VoidCallback onClose;

  /// Supplied by the app shell, which owns the `Brightness` the theme uses.
  final VoidCallback? onToggleTheme;
  final bool isDarkMode;

  /// Wiping storage is not enough on its own: the store still holds the live
  /// document, the workspace still holds every erased entry and the pending
  /// autosave would write all of them straight back on the next edit. So the
  /// autosave is flushed first (which cancels the timer and clears the dirty
  /// flags), then storage is dropped, then the in-memory state is rebuilt from
  /// the now empty keys.
  Future<void> _resetLocalData() async {
    store.flushAutosave();
    final bool reset = await store.workspace.reset();
    if (!reset) {
      toast.error(
        store.workspace.lastError ?? 'Browser storage refused the reset.',
      );
      return;
    }
    final bool imagesCleared = store.images?.clear() ?? true;
    final bool localStorageCleared = StorageService.clearAll();
    // The brightness belongs to the shell, not to the document data, so it is
    // re-stamped: a reload after a reset keeps the theme on screen.
    final bool themeSaved = StorageService.write(
      _themeStorageKey,
      isDarkMode ? 'dark' : 'light',
    );
    store.images?.load();
    store.resetLocalPreferences();
    final bool documentCreated = store.newDocument();
    await store.workspace.writesSettled;
    final bool workspaceReady =
        documentCreated && !store.workspace.hasUnsavedChanges;
    if (imagesCleared && localStorageCleared && themeSaved && workspaceReady) {
      toast.warning('Local data cleared. A new empty workspace is ready.');
      return;
    }
    toast.error(
      'The workspace was reset, but some browser data could not be cleared or '
      'the new empty document could not be saved. Reload and verify local data '
      'before continuing.',
    );
  }

  @override
  Widget build(BuildContext context) => ArcaneDialog(
    id: 'hui-settings-dialog',
    isOpen: isOpen,
    onClose: onClose,
    title: 'Settings',
    maxWidth: 720,
    actions: <Widget>[
      Button(
        variant: ButtonVariant.outline,
        onPressed: onClose,
        label: 'Close',
      ),
    ],
    children: <Widget>[
      ListenableBuilder(
        listenable: store,
        builder: (BuildContext inner) => _body(),
      ),
    ],
  );

  /// The catalog is only ever an aid: autocomplete, an approximate canvas
  /// sprite and an informational hint. A failed import changes nothing.
  Future<void> _importCustomItems() async {
    final (String, String)? picked = await pickJsonFile();
    if (picked == null) return;
    final HuiCustomItemCatalog? parsed = HuiCustomItemCatalog.parse(picked.$2);
    if (parsed == null) {
      toast.error(
        '${picked.$1} is not a HoloUI custom item catalog. Run /holoui item '
        'export and pick the file it names.',
      );
      return;
    }
    store.setCatalogs(store.catalogs.withCustomItems(parsed));
    if (!HuiCustomItemCatalog.store(picked.$2)) {
      toast.warning(
        'Loaded ${parsed.items.length} items, but this browser refused to '
        'save them, so they are gone on reload.',
      );
      return;
    }
    toast.success(
      'Loaded ${parsed.items.length} custom item'
      '${parsed.items.length == 1 ? '' : 's'} from '
      '${parsed.providers.length} provider'
      '${parsed.providers.length == 1 ? '' : 's'}.',
    );
  }

  void _forgetCustomItems() {
    HuiCustomItemCatalog.forgetStored();
    store.setCatalogs(
      store.catalogs.withCustomItems(HuiCustomItemCatalog.empty()),
    );
    toast.warning('Custom item catalog cleared.');
  }

  Widget _body() => dom.div(classes: 'hui-dialog-body hui-stagger', <Widget>[
    _appearance(),
    _canvas(),
    _customItems(),
    _localData(),
  ]);

  Widget _customItems() {
    final HuiCustomItemCatalog catalog = store.catalogs.customItems;
    return HuiDialogSection(
      title: 'Custom item catalog',
      description:
          'Optional. Only powers autocomplete and the canvas preview '
          'for customItem icons; ids always work without it.',
      children: <Widget>[
        HuiChips(
          labels: <String>[
            if (catalog.isEmpty)
              'no catalog loaded'
            else ...<String>[
              '${catalog.items.length} item'
                  '${catalog.items.length == 1 ? '' : 's'}',
              ...catalog.providers,
            ],
          ],
        ),
        const dom.p(classes: 'hui-dialog-note', <Widget>[
          Text(
            'Run /holoui item export on your server, then import '
            'plugins/holoui/custom-items.json here. The server is still '
            'the only thing that can confirm an id.',
          ),
        ]),
        dom.div(classes: 'hui-catalog-actions', <Widget>[
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            onPressed: _importCustomItems,
            child: const Text('Import custom item catalog'),
          ),
          if (catalog.isNotEmpty)
            HuiTwoStepButton(
              label: 'Forget catalog',
              confirmLabel: 'Forget it',
              icon: ArcaneIcon.trash2(size: IconSize.sm),
              onConfirm: _forgetCustomItems,
            ),
        ]),
      ],
    );
  }

  Widget _appearance() => HuiDialogSection(
    title: 'Appearance',
    description: 'Stored in this browser at holoui.theme.',
    children: <Widget>[
      HuiField(
        label: 'Dark mode',
        inline: true,
        help: onToggleTheme == null
            ? 'The theme switch is wired up by the editor shell.'
            : 'The page is stamped before paint, so reloading never '
                  'flashes the wrong theme.',
        control: ArcaneToggleSwitch(
          value: isDarkMode,
          disabled: onToggleTheme == null,
          onChanged: (bool _) => onToggleTheme?.call(),
          label: isDarkMode ? 'Dark' : 'Light',
        ),
      ),
    ],
  );

  Widget _canvas() => HuiDialogSection(
    title: 'Canvas defaults',
    description: 'Preview only. None of this is written to the menu file.',
    children: <Widget>[
      HuiField(
        label: 'Show grid',
        inline: true,
        control: ArcaneToggleSwitch(
          value: store.showGrid,
          onChanged: (bool value) => store.showGrid = value,
        ),
      ),
      HuiField(
        label: 'Snap to grid',
        inline: true,
        control: ArcaneToggleSwitch(
          value: store.snapToGrid,
          onChanged: (bool value) => store.snapToGrid = value,
        ),
      ),
      HuiField(
        label: 'Grid size',
        help: 'Blocks per snap step. 0.05 matches the arrow-key nudge.',
        control: HuiNumberField(
          value: store.gridSize,
          min: 0.01,
          max: 1,
          step: 0.05,
          onChanged: (double value) => store.gridSize = value,
          suffix: 'blocks',
        ),
      ),
      HuiField(
        label: 'Show anchors',
        inline: true,
        help: 'Draws the component anchor dots and the menu centre.',
        control: ArcaneToggleSwitch(
          value: store.showAnchors,
          onChanged: (bool value) => store.showAnchors = value,
        ),
      ),
      HuiField(
        label: 'Show hitboxes',
        inline: true,
        help: 'Mirrors the plugin debugHitbox particles.',
        control: ArcaneToggleSwitch(
          value: store.showHitboxes,
          onChanged: (bool value) => store.showHitboxes = value,
        ),
      ),
      HuiField(
        label: 'True render offsets',
        inline: true,
        help:
            'Applies the in-game vertical bias: text sits lower than its '
            'anchor and items lower still. Turn it off to author against '
            'clean anchors.',
        control: ArcaneToggleSwitch(
          value: store.trueRender,
          onChanged: (bool value) => store.trueRender = value,
        ),
      ),
      HuiField(
        label: 'Backdrop',
        control: ArcaneSelect(
          value: store.backdrop.name,
          size: ComponentSize.sm,
          fullWidth: true,
          options: const <ArcaneSelectOption>[
            ArcaneSelectOption(label: 'Screenshot', value: 'image'),
            ArcaneSelectOption(label: 'Dark', value: 'dark'),
            ArcaneSelectOption(label: 'Light', value: 'light'),
            ArcaneSelectOption(label: 'None', value: 'none'),
          ],
          onChange: (String value) {
            for (final HuiBackdropMode mode in HuiBackdropMode.values) {
              if (mode.name == value) store.backdrop = mode;
            }
          },
        ),
      ),
      _uiScale(),
    ],
  );

  /// The server uiScale, as a native range input.
  ///
  /// Not `ArcaneSlider`. That renderer never binds `onChanged` to the DOM — it
  /// reads `props.onChangeAction` and emits no `events:` map at all — so the
  /// injected JS dragged the fill while the store stayed put. Measured before
  /// replacing it: a full-width drag and five ArrowRight presses both left
  /// `previewUiScale` at 1.00, while the canvas toolbar's native range moved
  /// the same field to 1.25.
  ///
  /// Bounds, step, rounding and the reset target are copied from that toolbar
  /// control (`canvas_toolbar.dart`) on purpose: the two edit one store field,
  /// and a user who nudges one and then the other must not find a different
  /// number. Keep them in step if either changes.
  Widget _uiScale() {
    final String value = store.previewUiScale.toStringAsFixed(2);
    return HuiField(
      label: 'Server uiScale (preview)',
      help:
          'The real value lives in plugins/holoui/settings.json and is '
          'global for the server. It multiplies every offset and every '
          'icon size.',
      // Always mounted, disabled at 1.00: a button that appears only once the
      // value moves would shift the row's header as the user drags.
      trailing: Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.sm,
        disabled: store.previewUiScale == 1,
        onPressed: () => store.previewUiScale = 1,
        icon: ArcaneIcon.rotateCcw(size: IconSize.sm),
        label: 'Reset',
        attributes: const <String, String>{
          'aria-label': 'Reset uiScale to 1.00',
        },
      ),
      control: dom.div(classes: 'hui-range-row', <Widget>[
        // HuiField's <label> carries no `for`, so the accessible name has to
        // ride on the input itself.
        dom.input<num>(
          type: dom.InputType.range,
          classes: 'hui-range',
          value: value,
          // No setState: the store notifies and the ListenableBuilder that
          // wraps this body rebuilds it, exactly as the toolbar does.
          onInput: (num next) =>
              store.previewUiScale = (next.toDouble() * 100).round() / 100,
          attributes: const <String, String>{
            'min': '0.25',
            'max': '4',
            'step': '0.05',
            'aria-label': 'Server uiScale (preview)',
          },
        ),
        dom.span(classes: 'hui-range-value', <Widget>[Text('${value}x')]),
      ]),
    );
  }

  Widget _localData() {
    final int used = StorageService.estimateUsageBytes();
    final int workspaceBytes = store.workspace.estimateBytes();
    return HuiDialogSection(
      title: 'Local data',
      description:
          'Documents use transactional IndexedDB storage. Images and '
          'preferences remain in this browser too. Nothing is uploaded.',
      children: <Widget>[
        HuiChips(
          labels: <String>[
            '${huiFormatBytes(workspaceBytes)} workspace',
            '${huiFormatBytes(used)} localStorage',
            '${store.workspace.docs.length} document'
                '${store.workspace.docs.length == 1 ? '' : 's'}',
            '${store.images?.images.length ?? 0} image'
                '${(store.images?.images.length ?? 0) == 1 ? '' : 's'}',
            if (!StorageService.isWritable)
              'image and preference storage is read-only',
          ],
        ),
        const dom.p(classes: 'hui-dialog-note', <Widget>[
          Text(
            'Each workspace save retains the previous committed transaction '
            'for recovery. Resetting removes both copies, every stored image '
            'and the canvas preferences, then starts one new empty document. '
            'The reset reports an error if any browser store refuses its part. '
            'Only the light or dark choice survives. Export anything you want '
            'to keep first.',
          ),
        ]),
        HuiTwoStepButton(
          label: 'Reset local data',
          confirmLabel: 'Erase everything',
          icon: ArcaneIcon.trash2(size: IconSize.sm),
          onConfirm: _resetLocalData,
        ),
      ],
    );
  }
}

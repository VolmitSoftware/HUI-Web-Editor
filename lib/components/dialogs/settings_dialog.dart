/// Editor settings: appearance, canvas defaults, and local data.
///
/// Nothing here is part of the menu format. Everything is a preview or an
/// editor preference, which is why the canvas section says so explicitly — the
/// server's real `uiScale` lives in `plugins/Gloss/settings.json` and is
/// global, not per menu.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show ListenableBuilder;

import '../../services/catalogs.dart';
import '../../services/file_transfer.dart';
import '../../services/local_data_reset.dart';
import '../../services/storage_service.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import '../panels/two_step_button.dart';
import 'dialog_parts.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

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
    final LocalDataResetResult result = await resetAllLocalEditorData(
      store,
      isDarkMode: isDarkMode,
    );
    if (result.success) {
      toast.warning(result.message);
    } else {
      toast.error(result.message);
    }
  }

  @override
  Widget build(BuildContext context) => ArcaneDialog(
    id: 'hui-settings-dialog',
    isOpen: isOpen,
    onClose: onClose,
    title: huiText('Settings'),
    maxWidth: 720,
    actions: <Widget>[
      Button(
        variant: ButtonVariant.outline,
        onPressed: onClose,
        label: huiText('Close'),
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
        huiText(
          "{value} is not a Gloss custom item catalog. Run /gloss item export and pick the file it names.",
          <String, Object?>{'value': picked.$1},
        ),
      );
      return;
    }
    store.setCatalogs(store.catalogs.withCustomItems(parsed));
    if (!HuiCustomItemCatalog.store(picked.$2)) {
      toast.warning(
        huiPlural(
          'custom_items.storage_failure',
          parsed.items.length,
          oneEnglish:
              'Loaded {count} item, but this browser refused to save it, so it will be gone after a reload.',
          otherEnglish:
              'Loaded {count} items, but this browser refused to save them, so they will be gone after a reload.',
        ),
      );
      return;
    }
    final String itemCount = huiPlural(
      'custom_items.item_count',
      parsed.items.length,
      oneEnglish: '{count} custom item',
      otherEnglish: '{count} custom items',
    );
    final String providerCount = huiPlural(
      'custom_items.provider_count',
      parsed.providers.length,
      oneEnglish: '{count} provider',
      otherEnglish: '{count} providers',
    );
    toast.success(
      huiText('Loaded {items} from {providers}.', <String, Object?>{
        'items': itemCount,
        'providers': providerCount,
      }),
    );
  }

  void _forgetCustomItems() {
    HuiCustomItemCatalog.forgetStored();
    store.setCatalogs(
      store.catalogs.withCustomItems(HuiCustomItemCatalog.empty()),
    );
    toast.warning(huiText('Custom item catalog cleared.'));
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
      title: huiText('Custom item catalog'),
      description: huiText(
        'Optional. Only powers autocomplete and the canvas preview '
        'for customItem icons; ids always work without it.',
      ),
      children: <Widget>[
        HuiChips(
          labels: <String>[
            if (catalog.isEmpty)
              huiText('no catalog loaded')
            else ...<String>[
              huiPlural(
                'settings.custom_items.count',
                catalog.items.length,
                oneEnglish: '{count} item',
                otherEnglish: '{count} items',
              ),
              ...catalog.providers,
            ],
          ],
        ),
        dom.p(classes: 'hui-dialog-note', <Widget>[
          Text(
            huiText(
              'Run /gloss item export on your server, then import '
              'plugins/Gloss/custom-items.json here. The server is still '
              'the only thing that can confirm an id.',
            ),
          ),
        ]),
        dom.div(classes: 'hui-catalog-actions', <Widget>[
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            onPressed: _importCustomItems,
            label: huiText('Import custom item catalog'),
          ),
          if (catalog.isNotEmpty)
            HuiTwoStepButton(
              label: huiText('Forget catalog'),
              confirmLabel: huiText('Forget it'),
              icon: ArcaneIcon.trash2(size: IconSize.sm),
              onConfirm: _forgetCustomItems,
            ),
        ]),
      ],
    );
  }

  Widget _appearance() => HuiDialogSection(
    title: huiText('Appearance'),
    description: huiText('Stored in this browser at gloss.theme.'),
    children: <Widget>[
      HuiField(
        label: huiText('Dark mode'),
        inline: true,
        help: onToggleTheme == null
            ? huiText('The theme switch is wired up by the editor shell.')
            : huiText(
                'The page is stamped before paint, so reloading never flashes the wrong theme.',
              ),
        control: ArcaneToggleSwitch(
          value: isDarkMode,
          disabled: onToggleTheme == null,
          onChanged: (bool _) => onToggleTheme?.call(),
          label: isDarkMode ? huiText('Dark') : huiText('Light'),
        ),
      ),
    ],
  );

  Widget _canvas() => HuiDialogSection(
    title: huiText('Canvas defaults'),
    description: huiText(
      'Preview only. None of this is written to the menu file.',
    ),
    children: <Widget>[
      HuiField(
        label: huiText('Show grid'),
        inline: true,
        control: ArcaneToggleSwitch(
          value: store.showGrid,
          onChanged: (bool value) => store.showGrid = value,
        ),
      ),
      HuiField(
        label: huiText('Snap to grid'),
        inline: true,
        control: ArcaneToggleSwitch(
          value: store.snapToGrid,
          onChanged: (bool value) => store.snapToGrid = value,
        ),
      ),
      HuiField(
        label: huiText('Grid size'),
        help: huiText(
          'Blocks per snap step. 0.05 matches the arrow-key nudge.',
        ),
        control: HuiNumberField(
          value: store.gridSize,
          min: 0.01,
          max: 1,
          step: 0.05,
          onChanged: (double value) => store.gridSize = value,
          suffix: huiText('blocks'),
        ),
      ),
      HuiField(
        label: huiText('Show anchors'),
        inline: true,
        help: huiText('Draws the component anchor dots and the menu centre.'),
        control: ArcaneToggleSwitch(
          value: store.showAnchors,
          onChanged: (bool value) => store.showAnchors = value,
        ),
      ),
      HuiField(
        label: huiText('Show hitboxes'),
        inline: true,
        help: huiText('Mirrors the plugin debugHitbox particles.'),
        control: ArcaneToggleSwitch(
          value: store.showHitboxes,
          onChanged: (bool value) => store.showHitboxes = value,
        ),
      ),
      HuiField(
        label: huiText('True render offsets'),
        inline: true,
        help: huiText(
          'Applies the in-game vertical bias: text sits lower than its '
          'anchor and items lower still. Turn it off to author against '
          'clean anchors.',
        ),
        control: ArcaneToggleSwitch(
          value: store.trueRender,
          onChanged: (bool value) => store.trueRender = value,
        ),
      ),
      HuiField(
        label: huiText('Backdrop'),
        control: ArcaneSelect(
          value: store.backdrop.name,
          size: ComponentSize.sm,
          fullWidth: true,
          options: <ArcaneSelectOption>[
            ArcaneSelectOption(label: huiText('Screenshot'), value: 'image'),
            ArcaneSelectOption(label: huiText('Dark'), value: 'dark'),
            ArcaneSelectOption(label: huiText('Light'), value: 'light'),
            ArcaneSelectOption(label: huiText('None'), value: 'none'),
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
      label: huiText('Server uiScale (preview)'),
      help: huiText(
        'The real value lives in plugins/Gloss/settings.json and is '
        'global for the server. It multiplies every offset and every '
        'icon size.',
      ),
      // Always mounted, disabled at 1.00: a button that appears only once the
      // value moves would shift the row's header as the user drags.
      trailing: Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.sm,
        disabled: store.previewUiScale == 1,
        onPressed: () => store.previewUiScale = 1,
        icon: ArcaneIcon.rotateCcw(size: IconSize.sm),
        label: huiText('Reset'),
        attributes: <String, String>{
          'aria-label': huiText('Reset uiScale to 1.00'),
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
          attributes: <String, String>{
            'min': '0.25',
            'max': '4',
            'step': '0.05',
            'aria-label': huiText('Server uiScale (preview)'),
          },
        ),
        dom.span(classes: 'hui-range-value', <Widget>[
          Text(huiText("{value}x", <String, Object?>{'value': value})),
        ]),
      ]),
    );
  }

  Widget _localData() {
    final int used = StorageService.estimateUsageBytes();
    final int workspaceBytes = store.workspace.estimateBytes();
    return HuiDialogSection(
      title: huiText('Local data'),
      description: huiText(
        'Documents use transactional IndexedDB storage. Images and '
        'preferences remain in this browser too. Nothing is uploaded.',
      ),
      children: <Widget>[
        HuiChips(
          labels: <String>[
            huiText('{size} workspace', <String, Object?>{
              'size': huiFormatBytes(workspaceBytes),
            }),
            huiText('{size} localStorage', <String, Object?>{
              'size': huiFormatBytes(used),
            }),
            huiPlural(
              'settings.documents.count',
              store.workspace.docs.length,
              oneEnglish: '{count} document',
              otherEnglish: '{count} documents',
            ),
            huiPlural(
              'settings.images.count',
              store.images?.images.length ?? 0,
              oneEnglish: '{count} image',
              otherEnglish: '{count} images',
            ),
            if (!StorageService.isWritable)
              huiText('image and preference storage is read-only'),
          ],
        ),
        dom.p(classes: 'hui-dialog-note', <Widget>[
          Text(
            huiText(
              'Each workspace save retains the previous committed transaction '
              'for recovery. Resetting removes both copies, every stored image '
              'and the canvas preferences, then starts one new empty document. '
              'The reset reports an error if any browser store refuses its part. '
              'Only the light or dark choice survives. Export anything you want '
              'to keep first.',
            ),
          ),
        ]),
        HuiTwoStepButton(
          label: huiText('Reset local data'),
          confirmLabel: huiText('Erase everything'),
          icon: ArcaneIcon.trash2(size: IconSize.sm),
          onConfirm: _resetLocalData,
        ),
      ],
    );
  }
}

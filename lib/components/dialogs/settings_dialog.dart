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
  void _resetLocalData() {
    store.flushAutosave();
    store.images?.clear();
    StorageService.clearAll();
    // The brightness belongs to the shell, not to the document data, so it is
    // re-stamped: a reload after a reset keeps the theme on screen.
    StorageService.write(_themeStorageKey, isDarkMode ? 'dark' : 'light');
    store.workspace.load();
    store.newDocument();
    toast.warning('Local data cleared. A new empty workspace is ready.');
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

  Widget _body() => dom.div(
        classes: 'hui-dialog-body',
        <Widget>[
          _appearance(),
          _canvas(),
          _localData(),
        ],
      );

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
            help: 'Applies the in-game vertical bias: text sits lower than its '
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
          HuiField(
            label: 'Server uiScale (preview)',
            help: 'The real value lives in plugins/holoui/settings.json and is '
                'global for the server. It multiplies every offset and every '
                'icon size.',
            control: ArcaneSlider(
              value: store.previewUiScale,
              min: 0.25,
              max: 4,
              step: 0.05,
              valueDecimals: 2,
              onChanged: (double value) => store.previewUiScale = value,
            ),
          ),
        ],
      );

  Widget _localData() {
    final int used = StorageService.estimateUsageBytes();
    return HuiDialogSection(
      title: 'Local data',
      description: 'Documents, images and preferences are kept in this '
          'browser only. Nothing is uploaded anywhere.',
      children: <Widget>[
        HuiChips(
          labels: <String>[
            '${huiFormatBytes(used)} used',
            '${store.workspace.docs.length} document'
                '${store.workspace.docs.length == 1 ? '' : 's'}',
            '${store.images?.images.length ?? 0} image'
                '${(store.images?.images.length ?? 0) == 1 ? '' : 's'}',
            if (!StorageService.isWritable) 'storage is read-only',
          ],
        ),
        const dom.p(
          classes: 'hui-dialog-note',
          <Widget>[
            Text(
              'Resetting removes every saved menu, every stored image and the '
              'canvas preferences, then starts one new empty document. Only '
              'the light or dark choice survives. Export anything you want to '
              'keep first.',
            ),
          ],
        ),
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

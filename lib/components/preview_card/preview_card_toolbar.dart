/// The control strip above the container-preview card surface.
///
/// Same shape and the same stylesheet contract as the component canvas strip
/// (`web/styles/03-canvas.css`): ONE row at every width, every droppable word
/// inside `.hui-canvas-tool-label`, and every control keeping its `aria-label`
/// and tooltip when the text goes.
///
/// The simulation cluster is deliberately thin — play/pause, one step, reset,
/// and a read-only note of which category is being simulated. Picking the
/// category, pinning variables and driving a surge is the simulation panel's
/// job (task E8); these are the two controls a layout author needs without
/// leaving the canvas.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show Component;

import '../../state/editor_store.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class PreviewCardToolbar extends StatelessWidget {
  const PreviewCardToolbar({
    required this.store,
    required this.zoomLabelId,
    required this.zoomLabel,
    required this.simCategory,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onZoomReset,
    required this.onFit,
    required this.onStepSim,
    required this.onResetSim,
    super.key,
  });

  final EditorStore store;

  /// Patched in place by the viewport while zooming, so a wheel notch never
  /// rebuilds the Jaspr tree.
  final String zoomLabelId;
  final String zoomLabel;

  /// Which [previewSimCategories] entry the surface is drawing against.
  final String simCategory;

  final void Function() onZoomIn;
  final void Function() onZoomOut;
  final void Function() onZoomReset;
  final void Function() onFit;
  final void Function() onStepSim;
  final void Function() onResetSim;

  @override
  Widget build(
    BuildContext context,
  ) => dom.div(classes: 'hui-canvas-toolbar', <Widget>[
    _group(<Widget>[
      _iconAction(
        icon: ArcaneIcon.zoomOut(size: IconSize.sm),
        label: huiText('Zoom out'),
        onPressed: onZoomOut,
      ),
      dom.span(id: zoomLabelId, classes: 'hui-canvas-zoom', <Widget>[
        Component.text(zoomLabel),
      ]),
      _iconAction(
        icon: ArcaneIcon.zoomIn(size: IconSize.sm),
        label: huiText('Zoom in'),
        onPressed: onZoomIn,
      ),
      _iconAction(
        icon: ArcaneIcon.refreshCcw(size: IconSize.sm),
        label: huiText('Reset view (0)'),
        onPressed: onZoomReset,
      ),
      _iconAction(
        icon: ArcaneIcon.maximize(size: IconSize.sm),
        label: huiText('Fit to card (F)'),
        onPressed: onFit,
      ),
    ]),
    _group(<Widget>[
      _toggle(
        icon: ArcaneIcon.grid3x3(size: IconSize.sm),
        label: huiText('Pixel grid'),
        tooltip: huiText(
          'Pixel grid: 8 px minor, 24 px major, plus the card axes',
        ),
        active: store.showGrid,
        onPressed: () => store.showGrid = !store.showGrid,
      ),
    ]),
    _group(<Widget>[
      dom.span(
        classes: 'hui-eyebrow hui-canvas-tool-label hui-preview-sim-label',
        <Widget>[Component.text(huiText('sim'))],
      ),
      ArcaneTooltip(
        text: huiText(
          'Simulated state: {category}. The document\'s own match criteria chose it',
          <String, Object?>{'category': _simCategoryLabel(simCategory)},
        ),
        child: dom.span(classes: 'hui-preview-sim-chip', <Widget>[
          Component.text(_simCategoryLabel(simCategory)),
        ]),
      ),
      _toggle(
        icon: store.animationsPlaying
            ? ArcaneIcon.pause(size: IconSize.sm)
            : ArcaneIcon.play(size: IconSize.sm),
        label: store.animationsPlaying ? huiText('Pause') : huiText('Play'),
        tooltip: huiText(
          'The simulation advances one game tick every 50 ms, the '
          'rate the plugin refreshes a live card at',
        ),
        active: store.animationsPlaying,
        onPressed: () => store.animationsPlaying = !store.animationsPlaying,
      ),
      _iconAction(
        icon: ArcaneIcon.stepForward(size: IconSize.sm),
        label: huiText('Step one second of simulation'),
        onPressed: onStepSim,
      ),
      _iconAction(
        icon: ArcaneIcon.rotateCcw(size: IconSize.sm),
        label: huiText('Reset the simulated state'),
        onPressed: onResetSim,
      ),
    ]),
  ]);

  Widget _group(List<Widget> children) =>
      dom.div(classes: 'hui-canvas-toolgroup', children);

  String _simCategoryLabel(String category) => switch (category) {
    'chest' => huiText('Chest'),
    'furnace' => huiText('Furnace'),
    'brewing' => huiText('Brewing stand'),
    'beehive' => huiText('Beehive'),
    'cauldron' => huiText('Cauldron'),
    'jukebox' => huiText('Jukebox'),
    'enderChest' => huiText('Ender chest'),
    'entity' => huiText('Entity'),
    'statics' => huiText('Static values'),
    _ => category,
  };

  Widget _iconAction({
    required Widget icon,
    required String label,
    required void Function() onPressed,
  }) => ArcaneTooltip(
    text: label,
    child: Button(
      icon: icon,
      variant: ButtonVariant.ghost,
      size: ButtonSize.iconSm,
      type: ButtonType.button,
      attributes: <String, String>{'aria-label': label},
      onPressed: onPressed,
    ),
  );

  Widget _toggle({
    required Widget icon,
    required String label,
    required String tooltip,
    required bool active,
    required void Function() onPressed,
  }) => ArcaneTooltip(
    text: tooltip,
    child: Button(
      icon: icon,
      variant: active ? ButtonVariant.secondary : ButtonVariant.ghost,
      size: ButtonSize.sm,
      type: ButtonType.button,
      attributes: <String, String>{
        'aria-pressed': '$active',
        'aria-label': label,
      },
      onPressed: onPressed,
      child: dom.span(classes: 'hui-canvas-tool-label', <Widget>[
        Component.text(label),
      ]),
    ),
  );
}

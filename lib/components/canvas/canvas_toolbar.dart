/// The fused control strip above the canvas.
///
/// Every control writes straight to the store; the store notifies, the strip
/// rebuilds and the canvas marks itself dirty. The one exception is the zoom
/// readout, which the viewport patches directly in the DOM so panning and
/// zooming never rebuild the Jaspr tree.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show Component;

import '../../model/model.dart';
import '../../state/editor_store.dart';

/// Cycle order for the backdrop button.
const List<HuiBackdropMode> huiBackdropCycle = <HuiBackdropMode>[
  HuiBackdropMode.image,
  HuiBackdropMode.dark,
  HuiBackdropMode.light,
  HuiBackdropMode.none,
];

const Map<HuiBackdropMode, String> huiBackdropLabels =
    <HuiBackdropMode, String>{
  HuiBackdropMode.image: 'In-game',
  HuiBackdropMode.dark: 'Dark',
  HuiBackdropMode.light: 'Light',
  HuiBackdropMode.none: 'None',
};

class CanvasToolbar extends StatelessWidget {
  const CanvasToolbar({
    required this.store,
    required this.zoomLabelId,
    required this.zoomPercent,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onZoomReset,
    required this.onFit,
    required this.hasAnimatedIcons,
    super.key,
  });

  final EditorStore store;

  /// Patched in place by the viewport during pan and zoom.
  final String zoomLabelId;
  final String zoomPercent;

  final void Function() onZoomIn;
  final void Function() onZoomOut;
  final void Function() onZoomReset;
  final void Function() onFit;
  final bool hasAnimatedIcons;

  @override
  Widget build(BuildContext context) => dom.div(
        classes: 'hui-canvas-toolbar',
        <Widget>[
          dom.div(classes: 'hui-canvas-toolgroup', <Widget>[
            _iconAction(
              icon: ArcaneIcon.zoomOut(size: IconSize.sm),
              label: 'Zoom out',
              onPressed: onZoomOut,
            ),
            dom.span(
              id: zoomLabelId,
              classes: 'hui-canvas-zoom',
              <Widget>[Component.text(zoomPercent)],
            ),
            _iconAction(
              icon: ArcaneIcon.zoomIn(size: IconSize.sm),
              label: 'Zoom in',
              onPressed: onZoomIn,
            ),
            _iconAction(
              icon: ArcaneIcon.refreshCcw(size: IconSize.sm),
              label: 'Reset view (0)',
              onPressed: onZoomReset,
            ),
            _iconAction(
              icon: ArcaneIcon.maximize(size: IconSize.sm),
              label: 'Fit to components (F)',
              onPressed: onFit,
            ),
          ]),
          dom.div(classes: 'hui-canvas-toolgroup', <Widget>[
            _toggle(
              icon: ArcaneIcon.grid3x3(size: IconSize.sm),
              label: 'Block grid',
              tooltip: 'Show the 1-block grid and rulers',
              active: store.showGrid,
              onPressed: () => store.showGrid = !store.showGrid,
            ),
            _toggle(
              icon: ArcaneIcon.magnet(size: IconSize.sm),
              label: 'Snap',
              tooltip: 'Snap dragged components to '
                  '${_trimNumber(store.gridSize)} blocks',
              active: store.snapToGrid,
              onPressed: () => store.snapToGrid = !store.snapToGrid,
            ),
            _toggle(
              icon: ArcaneIcon.frame(size: IconSize.sm),
              label: 'Hitboxes',
              tooltip: 'Draw each click plane. Solid = clickable, '
                  'dashed = decoration',
              active: store.showHitboxes,
              onPressed: () => store.showHitboxes = !store.showHitboxes,
            ),
            _toggle(
              icon: ArcaneIcon.locateFixed(size: IconSize.sm),
              label: 'Anchors',
              tooltip: 'Component anchors, menu centre and component ids',
              active: store.showAnchors,
              onPressed: () => store.showAnchors = !store.showAnchors,
            ),
            _toggle(
              icon: ArcaneIcon.moveVertical(size: IconSize.sm),
              label: 'True render',
              tooltip: 'Reproduce the in-game vertical bias: text draws about '
                  '0.325 x uiScale blocks BELOW the anchor while the click '
                  'plane stays on it',
              active: store.trueRender,
              onPressed: () => store.trueRender = !store.trueRender,
            ),
            ArcaneTooltip(
              text: 'Canvas backdrop: ${huiBackdropLabels[store.backdrop]}',
              child: Button(
                label: huiBackdropLabels[store.backdrop] ?? 'Backdrop',
                icon: ArcaneIcon.image(size: IconSize.sm),
                variant: ButtonVariant.ghost,
                size: ButtonSize.sm,
                type: ButtonType.button,
                attributes: const <String, String>{
                  'aria-label': 'Cycle canvas backdrop',
                },
                onPressed: _cycleBackdrop,
              ),
            ),
          ]),
          dom.div(classes: 'hui-canvas-toolgroup hui-canvas-toolgroup-scale', <Widget>[
            const dom.span(
              classes: 'hui-eyebrow hui-canvas-scale-label',
              <Widget>[Component.text('server uiScale (preview)')],
            ),
            dom.div(classes: 'hui-canvas-scale-slider', <Widget>[
              ArcaneSlider(
                value: store.previewUiScale,
                min: 0.25,
                max: 4,
                step: 0.05,
                showValue: false,
                size: ComponentSize.sm,
                onChanged: (double value) => store.previewUiScale = value,
              ),
            ]),
            dom.span(
              classes: 'hui-canvas-scale-value',
              <Widget>[Component.text(store.previewUiScale.toStringAsFixed(2))],
            ),
            _iconAction(
              icon: ArcaneIcon.rotateCcw(size: IconSize.sm),
              label: 'Reset uiScale to 1.00',
              onPressed: () => store.previewUiScale = 1,
            ),
          ]),
          dom.div(classes: 'hui-canvas-toolgroup', <Widget>[
            if (hasAnimatedIcons)
              _toggle(
                icon: store.animationsPlaying
                    ? ArcaneIcon.pause(size: IconSize.sm)
                    : ArcaneIcon.play(size: IconSize.sm),
                label: store.animationsPlaying ? 'Pause' : 'Play',
                tooltip: 'Animated icons advance one frame every '
                    'speed x 50 ms',
                active: store.animationsPlaying,
                onPressed: () =>
                    store.animationsPlaying = !store.animationsPlaying,
              ),
            ..._togglePreviewControl(),
          ]),
        ],
      );

  /// Only meaningful while a toggle component is selected: it decides which of
  /// the two icons the canvas previews.
  List<Widget> _togglePreviewControl() {
    final HuiComponent? selected = store.selected;
    if (selected == null || selected.data is! HuiToggleData) {
      return const <Widget>[];
    }
    final bool showsTrue = store.togglePreviewFor(selected.id);
    return <Widget>[
      const dom.span(
        classes: 'hui-canvas-toolbar-divider',
        <Widget>[],
      ),
      const dom.span(
        classes: 'hui-eyebrow hui-canvas-toggle-label',
        <Widget>[Component.text('toggle preview')],
      ),
      ArcaneTooltip(
        text: 'Condition matched: shows trueIcon',
        child: Button(
          label: 'True',
          variant: showsTrue ? ButtonVariant.secondary : ButtonVariant.ghost,
          size: ButtonSize.sm,
          type: ButtonType.button,
          attributes: <String, String>{
            'aria-pressed': '$showsTrue',
            'aria-label': 'Preview the true icon',
          },
          onPressed: () => store.setTogglePreview(selected.id, true),
        ),
      ),
      ArcaneTooltip(
        text: 'Condition not matched: shows falseIcon',
        child: Button(
          label: 'False',
          variant: showsTrue ? ButtonVariant.ghost : ButtonVariant.secondary,
          size: ButtonSize.sm,
          type: ButtonType.button,
          attributes: <String, String>{
            'aria-pressed': '${!showsTrue}',
            'aria-label': 'Preview the false icon',
          },
          onPressed: () => store.setTogglePreview(selected.id, false),
        ),
      ),
    ];
  }

  void _cycleBackdrop() {
    final int index = huiBackdropCycle.indexOf(store.backdrop);
    store.backdrop =
        huiBackdropCycle[(index + 1) % huiBackdropCycle.length];
  }

  Widget _iconAction({
    required Widget icon,
    required String label,
    required void Function() onPressed,
  }) =>
      ArcaneTooltip(
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
  }) =>
      ArcaneTooltip(
        text: tooltip,
        child: Button(
          label: label,
          icon: icon,
          variant: active ? ButtonVariant.secondary : ButtonVariant.ghost,
          size: ButtonSize.sm,
          type: ButtonType.button,
          attributes: <String, String>{
            'aria-pressed': '$active',
            'aria-label': label,
          },
          onPressed: onPressed,
        ),
      );

  static String _trimNumber(double value) {
    final String text = value.toStringAsFixed(3);
    return text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

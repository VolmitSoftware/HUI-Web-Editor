/// The fused control strip above the canvas.
///
/// Every control writes straight to the store; the store notifies, the strip
/// rebuilds and the canvas marks itself dirty. The one exception is the zoom
/// readout, which the viewport patches directly in the DOM so panning and
/// zooming never rebuild the Jaspr tree.
///
/// Layout contract with `web/styles/03-canvas.css`:
/// - the strip is ONE row at every width; it never wraps. Density is a CSS
///   decision, not a Dart one: every label that may be dropped when the canvas
///   cell gets narrow is wrapped in `.hui-canvas-tool-label`, and the
///   stylesheet decides whether that span renders. The buttons keep their
///   `aria-label` and their `ArcaneTooltip` either way, so dropping the text
///   costs nothing but pixels.
/// - the uiScale control is a popover, not an inline slider. An inline slider
///   in a single row collapses to an unusable stub as soon as anything else
///   grows, so the row only carries the readout and the real slider lives in
///   the popover panel.
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
  Widget build(BuildContext context) {
    final List<Widget> stateControls = _stateControls();
    return dom.div(
      classes: 'hui-canvas-toolbar',
      <Widget>[
        _group(_zoomControls()),
        _group(_viewControls()),
        _group(<Widget>[_UiScaleControl(store: store)]),
        if (stateControls.isNotEmpty) _group(stateControls),
      ],
    );
  }

  Widget _group(List<Widget> children) =>
      dom.div(classes: 'hui-canvas-toolgroup', children);

  List<Widget> _zoomControls() => <Widget>[
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
      ];

  List<Widget> _viewControls() => <Widget>[
        _toggle(
          icon: ArcaneIcon.grid3x3(size: IconSize.sm),
          label: 'Block grid',
          tooltip: 'Block grid: the 1-block grid and the rulers',
          active: store.showGrid,
          onPressed: () => store.showGrid = !store.showGrid,
        ),
        _toggle(
          icon: ArcaneIcon.magnet(size: IconSize.sm),
          label: 'Snap',
          tooltip: 'Snap: dragged components land on '
              '${_trimNumber(store.gridSize)} block steps',
          active: store.snapToGrid,
          onPressed: () => store.snapToGrid = !store.snapToGrid,
        ),
        _toggle(
          icon: ArcaneIcon.frame(size: IconSize.sm),
          label: 'Hitboxes',
          tooltip: 'Hitboxes: draw each click plane. Solid = clickable, '
              'dashed = decoration',
          active: store.showHitboxes,
          onPressed: () => store.showHitboxes = !store.showHitboxes,
        ),
        _toggle(
          icon: ArcaneIcon.locateFixed(size: IconSize.sm),
          label: 'Anchors',
          tooltip: 'Anchors: component anchors, menu centre and component ids',
          active: store.showAnchors,
          onPressed: () => store.showAnchors = !store.showAnchors,
        ),
        _toggle(
          icon: ArcaneIcon.moveVertical(size: IconSize.sm),
          label: 'True render',
          tooltip: 'True render: reproduce the in-game vertical bias. Text '
              'draws about 0.325 x uiScale blocks BELOW the anchor while the '
              'click plane stays on it',
          active: store.trueRender,
          onPressed: () => store.trueRender = !store.trueRender,
        ),
        ArcaneTooltip(
          text: 'Canvas backdrop: ${huiBackdropLabels[store.backdrop]}. '
              'Click to cycle',
          child: Button(
            icon: ArcaneIcon.image(size: IconSize.sm),
            variant: ButtonVariant.ghost,
            size: ButtonSize.sm,
            type: ButtonType.button,
            attributes: <String, String>{
              'aria-label': 'Cycle canvas backdrop, currently '
                  '${huiBackdropLabels[store.backdrop]}',
            },
            onPressed: _cycleBackdrop,
            child: _toolLabel(huiBackdropLabels[store.backdrop] ?? 'Backdrop'),
          ),
        ),
      ];

  /// Playback and toggle-preview live in the same trailing group: both are
  /// about what the canvas is currently *showing*, and both come and go.
  List<Widget> _stateControls() => <Widget>[
        if (hasAnimatedIcons)
          _toggle(
            icon: store.animationsPlaying
                ? ArcaneIcon.pause(size: IconSize.sm)
                : ArcaneIcon.play(size: IconSize.sm),
            label: store.animationsPlaying ? 'Pause' : 'Play',
            tooltip: 'Animated icons advance one frame every speed x 50 ms',
            active: store.animationsPlaying,
            onPressed: () =>
                store.animationsPlaying = !store.animationsPlaying,
          ),
        ..._togglePreviewControl(),
      ];

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
        classes: 'hui-eyebrow hui-canvas-tool-label hui-canvas-toggle-label',
        <Widget>[Component.text('toggle')],
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
          icon: icon,
          variant: active ? ButtonVariant.secondary : ButtonVariant.ghost,
          size: ButtonSize.sm,
          type: ButtonType.button,
          attributes: <String, String>{
            'aria-pressed': '$active',
            'aria-label': label,
          },
          onPressed: onPressed,
          child: _toolLabel(label),
        ),
      );

  /// Text that the stylesheet is allowed to drop when the canvas cell is too
  /// narrow to carry it. Never the only description of a control.
  static Widget _toolLabel(String text) => dom.span(
        classes: 'hui-canvas-tool-label',
        <Widget>[Component.text(text)],
      );

  static String _trimNumber(double value) {
    final String text = value.toStringAsFixed(3);
    return text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

/// The server-side `ui-scale` preview knob.
///
/// The row carries a readout button only; the slider itself lives in a popover
/// so it always has a usable track. Same store field, same clamp, same
/// semantics as the settings dialog.
class _UiScaleControl extends StatefulWidget {
  const _UiScaleControl({required this.store});

  final EditorStore store;

  @override
  State<_UiScaleControl> createState() => _UiScaleControlState();
}

class _UiScaleControlState extends State<_UiScaleControl> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final EditorStore store = component.store;
    final String value = store.previewUiScale.toStringAsFixed(2);
    return ArcanePopover(
      isOpen: _open,
      onOpenChange: (bool open) => setState(() => _open = open),
      position: FloatingPosition.bottom,
      trigger: Button(
        icon: ArcaneIcon.scaling(size: IconSize.sm),
        variant: ButtonVariant.ghost,
        size: ButtonSize.sm,
        type: ButtonType.button,
        attributes: <String, String>{
          'aria-label': 'Preview uiScale $value. Opens the uiScale slider',
          'aria-haspopup': 'dialog',
          'aria-expanded': _open ? 'true' : 'false',
        },
        child: dom.span(classes: 'hui-canvas-scale-trigger', <Widget>[
          const dom.span(
            classes: 'hui-canvas-tool-label',
            <Widget>[Component.text('uiScale')],
          ),
          dom.span(
            classes: 'hui-canvas-scale-value',
            <Widget>[Component.text(value)],
          ),
        ]),
      ),
      content: dom.div(classes: 'hui-scale-pop', <Widget>[
        const dom.span(
          classes: 'hui-eyebrow',
          <Widget>[Component.text('server uiScale (preview)')],
        ),
        const dom.p(
          classes: 'hui-scale-pop-note',
          <Widget>[
            Component.text(
              'Mirrors the ui-scale the server renders the menu at. Preview '
              'only: it is never written to the layout file.',
            ),
          ],
        ),
        // A native range input, not ArcaneSlider: the Arcane slider renderer
        // never wires its `onChanged` to the DOM, so its thumb moves while the
        // store stays put. `input[type=range]` gives a real input event, real
        // arrow-key support and a real focus ring.
        dom.input<num>(
          type: dom.InputType.range,
          classes: 'hui-scale-range',
          value: value,
          // No setState: the store notifies, the viewport's ListenableBuilder
          // rebuilds the strip and this popover with it.
          onInput: (num next) =>
              store.previewUiScale = (next.toDouble() * 100).round() / 100,
          attributes: <String, String>{
            'min': '0.25',
            'max': '4',
            'step': '0.05',
            'aria-label': 'Preview uiScale',
          },
        ),
        const dom.div(classes: 'hui-scale-pop-ticks', <Widget>[
          dom.span(<Widget>[Component.text('0.25')]),
          dom.span(<Widget>[Component.text('1.00')]),
          dom.span(<Widget>[Component.text('4.00')]),
        ]),
        dom.div(classes: 'hui-scale-pop-foot', <Widget>[
          dom.span(
            classes: 'hui-scale-pop-value',
            <Widget>[Component.text('${value}x')],
          ),
          Button(
            label: 'Reset to 1.00',
            icon: ArcaneIcon.rotateCcw(size: IconSize.sm),
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            type: ButtonType.button,
            attributes: const <String, String>{
              'aria-label': 'Reset uiScale to 1.00',
            },
            onPressed: () => store.previewUiScale = 1,
          ),
        ]),
      ]),
    );
  }
}

/// The fused control strip above the canvas.
///
/// Every control writes straight to the store; the store notifies, the strip
/// rebuilds and the canvas marks itself dirty. The one exception is the zoom
/// readout, which the viewport patches directly in the DOM so panning and
/// zooming never rebuild the Jaspr tree.
///
/// Layout contract with `web/styles/03-canvas.css`:
/// - the strip is ONE row at every width; it never wraps or scrolls. Density is
///   a CSS decision: labels disappear first, then a compact More handoff swaps
///   the view/order/state groups for one menu containing the same actions.
///   Every action therefore has exactly one visible route at every width.
/// - the uiScale control is a popover, not an inline slider. An inline slider
///   in a single row collapses to an unusable stub as soon as anything else
///   grows, so the row only carries the readout and the real slider lives in
///   the popover panel.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show Component, EventCallback;
import 'package:web/web.dart' as web;

import '../../config/editing.dart';
import '../../logic/multi_select.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/class_names.dart';
import '../common/hui_action_menu.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

/// Cycle order for the backdrop button.
const List<HuiBackdropMode> huiBackdropCycle = <HuiBackdropMode>[
  HuiBackdropMode.image,
  HuiBackdropMode.dark,
  HuiBackdropMode.light,
  HuiBackdropMode.none,
];

const Map<HuiBackdropMode, String> huiBackdropLabels =
    <HuiBackdropMode, String>{
      HuiBackdropMode.image: 'Scene',
      HuiBackdropMode.dark: 'Dark',
      HuiBackdropMode.light: 'Light',
      HuiBackdropMode.none: 'None',
    };

String huiBackdropLabel(HuiBackdropMode mode) => switch (mode) {
  HuiBackdropMode.image => huiText('Scene'),
  HuiBackdropMode.dark => huiText('Dark'),
  HuiBackdropMode.light => huiText('Light'),
  HuiBackdropMode.none => huiText('None'),
};

/// Undo labels for the restack controls. Shared with the viewport so the
/// history entry and the button say the same thing.
const Map<HuiZOrder, String> huiZOrderLabels = <HuiZOrder, String>{
  HuiZOrder.forward: 'bring forward',
  HuiZOrder.backward: 'send back',
  HuiZOrder.toFront: 'bring to front',
  HuiZOrder.toBack: 'send to back',
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
    required this.onZOrder,
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

  /// Restack the whole selection. The viewport owns the geometry because it is
  /// the only side holding a resolved scene.
  final void Function(HuiZOrder op) onZOrder;

  @override
  Widget build(BuildContext context) {
    final List<Widget> stateControls = _stateControls();
    final List<Widget> orderControls = _orderControls();
    return dom.div(classes: 'hui-canvas-toolbar', <Widget>[
      _group(_zoomControls(), 'is-zoom'),
      _group(_viewControls(), 'is-view'),
      _group(<Widget>[_UiScaleControl(store: store)], 'is-scale'),
      if (orderControls.isNotEmpty) _group(orderControls, 'is-order'),
      if (stateControls.isNotEmpty) _group(stateControls, 'is-state'),
      _group(<Widget>[
        _CanvasCompactControl(
          store: store,
          hasAnimatedIcons: hasAnimatedIcons,
          onZoomReset: onZoomReset,
          onFit: onFit,
          onZOrder: onZOrder,
        ),
      ], 'is-compact'),
    ]);
  }

  Widget _group(List<Widget> children, String role) =>
      dom.div(classes: 'hui-canvas-toolgroup $role', children);

  List<Widget> _zoomControls() => <Widget>[
    _iconAction(
      icon: ArcaneIcon.zoomOut(size: IconSize.sm),
      label: huiText('Zoom out'),
      onPressed: onZoomOut,
    ),
    dom.span(id: zoomLabelId, classes: 'hui-canvas-zoom', <Widget>[
      Component.text(zoomPercent),
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
      label: huiText('Fit to components (F)'),
      onPressed: onFit,
    ),
  ];

  List<Widget> _viewControls() => <Widget>[
    _toggle(
      icon: ArcaneIcon.grid3x3(size: IconSize.sm),
      label: huiText('Block grid'),
      tooltip: huiText('Block grid: the 1-block grid and the rulers'),
      active: store.showGrid,
      onPressed: () => store.showGrid = !store.showGrid,
    ),
    _toggle(
      icon: ArcaneIcon.magnet(size: IconSize.sm),
      label: huiText('Snap'),
      tooltip: huiText(
        "Snap: dragged components land on {trimNumber} block steps",
        <String, Object?>{'trimNumber': _trimNumber(store.gridSize)},
      ),
      active: store.snapToGrid,
      onPressed: () => store.snapToGrid = !store.snapToGrid,
    ),
    _toggle(
      icon: ArcaneIcon.frame(size: IconSize.sm),
      label: huiText('Hitboxes'),
      tooltip: huiText(
        'Hitboxes: draw each click plane. Solid = clickable, '
        'dashed = decoration',
      ),
      active: store.showHitboxes,
      onPressed: () => store.showHitboxes = !store.showHitboxes,
    ),
    _toggle(
      icon: ArcaneIcon.locateFixed(size: IconSize.sm),
      label: huiText('Anchors'),
      tooltip: huiText(
        'Anchors: component anchors, menu centre and component ids',
      ),
      active: store.showAnchors,
      onPressed: () => store.showAnchors = !store.showAnchors,
    ),
    _toggle(
      icon: ArcaneIcon.moveVertical(size: IconSize.sm),
      label: huiText('True render'),
      tooltip: huiText(
        'True render: reproduce the in-game vertical bias. Text '
        'draws about 0.325 x uiScale blocks BELOW the anchor and its '
        'click plane follows it',
      ),
      active: store.trueRender,
      onPressed: () => store.trueRender = !store.trueRender,
    ),
    ArcaneTooltip(
      text: huiText(
        'Canvas backdrop: {backdrop}. Click to cycle',
        <String, Object?>{'backdrop': huiBackdropLabel(store.backdrop)},
      ),
      child: Button(
        icon: ArcaneIcon.image(size: IconSize.sm),
        variant: ButtonVariant.ghost,
        size: ButtonSize.sm,
        type: ButtonType.button,
        attributes: <String, String>{
          'aria-label': huiText(
            "Cycle canvas backdrop, currently {value}",
            <String, Object?>{'value': huiBackdropLabel(store.backdrop)},
          ),
        },
        onPressed: _cycleBackdrop,
        child: _toolLabel(huiBackdropLabel(store.backdrop)),
      ),
    ),
  ];

  /// Draw order. Only meaningful with something selected, and the whole group
  /// comes and goes so the strip stays one row when nothing is.
  List<Widget> _orderControls() {
    if (store.selectionIds.isEmpty) return const <Widget>[];
    return <Widget>[
      dom.span(
        classes: 'hui-eyebrow hui-canvas-tool-label hui-canvas-order-label',
        <Widget>[Component.text(huiText('order'))],
      ),
      _iconAction(
        icon: ArcaneIcon.chevronUp(size: IconSize.sm),
        label: huiText('Bring forward'),
        onPressed: () => onZOrder(HuiZOrder.forward),
      ),
      _iconAction(
        icon: ArcaneIcon.chevronDown(size: IconSize.sm),
        label: huiText('Send back'),
        onPressed: () => onZOrder(HuiZOrder.backward),
      ),
      _iconAction(
        icon: ArcaneIcon.bringToFront(size: IconSize.sm),
        label: huiText('Bring to front'),
        onPressed: () => onZOrder(HuiZOrder.toFront),
      ),
      _iconAction(
        icon: ArcaneIcon.sendToBack(size: IconSize.sm),
        label: huiText('Send to back'),
        onPressed: () => onZOrder(HuiZOrder.toBack),
      ),
      _ZScrubber(store: store),
    ];
  }

  /// Playback and toggle-preview live in the same trailing group: both are
  /// about what the canvas is currently *showing*, and both come and go.
  List<Widget> _stateControls() => <Widget>[
    if (hasAnimatedIcons)
      _toggle(
        icon: store.animationsPlaying
            ? ArcaneIcon.pause(size: IconSize.sm)
            : ArcaneIcon.play(size: IconSize.sm),
        label: store.animationsPlaying ? huiText('Pause') : huiText('Play'),
        tooltip: huiText(
          'Animated icons advance one frame every speed x 50 ms',
        ),
        active: store.animationsPlaying,
        onPressed: () => store.animationsPlaying = !store.animationsPlaying,
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
      dom.span(
        classes: 'hui-eyebrow hui-canvas-tool-label hui-canvas-toggle-label',
        <Widget>[Component.text(huiText('toggle'))],
      ),
      ArcaneTooltip(
        text: huiText('Condition matched: shows trueIcon'),
        child: Button(
          label: huiText('True'),
          variant: showsTrue ? ButtonVariant.secondary : ButtonVariant.ghost,
          size: ButtonSize.sm,
          type: ButtonType.button,
          attributes: <String, String>{
            'aria-pressed': '$showsTrue',
            'aria-label': huiText('Preview the true icon'),
          },
          onPressed: () => store.setTogglePreview(selected.id, true),
        ),
      ),
      ArcaneTooltip(
        text: huiText('Condition not matched: shows falseIcon'),
        child: Button(
          label: huiText('False'),
          variant: showsTrue ? ButtonVariant.ghost : ButtonVariant.secondary,
          size: ButtonSize.sm,
          type: ButtonType.button,
          attributes: <String, String>{
            'aria-pressed': '${!showsTrue}',
            'aria-label': huiText('Preview the false icon'),
          },
          onPressed: () => store.setTogglePreview(selected.id, false),
        ),
      ),
    ];
  }

  void _cycleBackdrop() {
    final int index = huiBackdropCycle.indexOf(store.backdrop);
    store.backdrop = huiBackdropCycle[(index + 1) % huiBackdropCycle.length];
  }

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

class _CanvasCompactControl extends StatefulWidget {
  const _CanvasCompactControl({
    required this.store,
    required this.hasAnimatedIcons,
    required this.onZoomReset,
    required this.onFit,
    required this.onZOrder,
  });

  final EditorStore store;
  final bool hasAnimatedIcons;
  final void Function() onZoomReset;
  final void Function() onFit;
  final void Function(HuiZOrder op) onZOrder;

  @override
  State<_CanvasCompactControl> createState() => _CanvasCompactControlState();
}

class _CanvasCompactControlState extends State<_CanvasCompactControl> {
  static const String _triggerId = 'hui-canvas-compact-trigger';
  static const String _menuId = 'hui-canvas-compact-menu';

  HuiActionMenuPoint? _menuPoint;

  EditorStore get _store => component.store;

  void _open() {
    setState(() => _menuPoint = huiActionMenuAnchor(_triggerId));
    context.binding.addPostFrameCallback(() {
      if (mounted) focusHuiActionMenu(_menuId);
    });
  }

  void _close() {
    if (_menuPoint == null) return;
    setState(() => _menuPoint = null);
    context.binding.addPostFrameCallback(() {
      if (mounted) focusHuiActionMenu(_triggerId);
    });
  }

  void _cycleBackdrop() {
    final int index = huiBackdropCycle.indexOf(_store.backdrop);
    _store.backdrop = huiBackdropCycle[(index + 1) % huiBackdropCycle.length];
  }

  void _changeScale(double delta) {
    final double next =
        ((_store.previewUiScale + delta).clamp(0.25, 4.0) * 100).round() / 100;
    _store.previewUiScale = next;
  }

  void _nudgeDepth(double delta) {
    final Map<String, Vec3> offsets = <String, Vec3>{
      for (final HuiComponent selected in _store.selectedComponents)
        selected.id: selected.offset.copy(),
    };
    if (offsets.isEmpty) return;
    final Map<String, Vec3> next = shiftOffsets(offsets: offsets, dz: delta);
    _store.setOffsets(
      next.length == 1
          ? 'depth ${next.keys.first}'
          : 'depth ${next.length} components',
      next,
    );
  }

  HuiActionMenuItem _toggleItem({
    required String activeLabel,
    required String inactiveLabel,
    required Widget icon,
    required bool active,
    required void Function() onSelect,
    String? hint,
    bool separatorBefore = false,
  }) => HuiActionMenuItem(
    label: active ? activeLabel : inactiveLabel,
    icon: icon,
    hint: hint,
    separatorBefore: separatorBefore,
    onSelect: onSelect,
  );

  List<HuiActionMenuItem> _items() {
    final HuiComponent? selected = _store.selected;
    final bool hasSelection = _store.selectionIds.isNotEmpty;
    final bool showsTrue = selected != null && selected.data is HuiToggleData
        ? _store.togglePreviewFor(selected.id)
        : false;
    return <HuiActionMenuItem>[
      HuiActionMenuItem(
        label: huiText('Reset view'),
        icon: ArcaneIcon.refreshCcw(size: IconSize.sm),
        hint: huiText('Reset zoom and pan'),
        onSelect: component.onZoomReset,
      ),
      HuiActionMenuItem(
        label: huiText('Fit to components'),
        icon: ArcaneIcon.maximize(size: IconSize.sm),
        onSelect: component.onFit,
      ),
      _toggleItem(
        activeLabel: huiText('Hide grid'),
        inactiveLabel: huiText('Show grid'),
        icon: ArcaneIcon.grid3x3(size: IconSize.sm),
        active: _store.showGrid,
        separatorBefore: true,
        onSelect: () => _store.showGrid = !_store.showGrid,
      ),
      _toggleItem(
        activeLabel: huiText('Disable snapping'),
        inactiveLabel: huiText('Enable snapping'),
        icon: ArcaneIcon.magnet(size: IconSize.sm),
        active: _store.snapToGrid,
        onSelect: () => _store.snapToGrid = !_store.snapToGrid,
      ),
      _toggleItem(
        activeLabel: huiText('Hide hitboxes'),
        inactiveLabel: huiText('Show hitboxes'),
        icon: ArcaneIcon.frame(size: IconSize.sm),
        active: _store.showHitboxes,
        onSelect: () => _store.showHitboxes = !_store.showHitboxes,
      ),
      _toggleItem(
        activeLabel: huiText('Hide anchors'),
        inactiveLabel: huiText('Show anchors'),
        icon: ArcaneIcon.locateFixed(size: IconSize.sm),
        active: _store.showAnchors,
        onSelect: () => _store.showAnchors = !_store.showAnchors,
      ),
      _toggleItem(
        activeLabel: huiText('Disable true render'),
        inactiveLabel: huiText('Enable true render'),
        icon: ArcaneIcon.moveVertical(size: IconSize.sm),
        active: _store.trueRender,
        onSelect: () => _store.trueRender = !_store.trueRender,
      ),
      HuiActionMenuItem(
        label: huiText("Backdrop: {value}", <String, Object?>{
          'value': huiBackdropLabel(_store.backdrop),
        }),
        icon: ArcaneIcon.image(size: IconSize.sm),
        hint: huiText('Cycle the canvas backdrop'),
        onSelect: _cycleBackdrop,
      ),
      HuiActionMenuItem(
        label: huiText('Decrease uiScale'),
        icon: ArcaneIcon.minus(size: IconSize.sm),
        hint: huiText("{toStringAsFixed} · step 0.05", <String, Object?>{
          'toStringAsFixed': _store.previewUiScale.toStringAsFixed(2),
        }),
        separatorBefore: true,
        disabled: _store.previewUiScale <= 0.25,
        onSelect: () => _changeScale(-0.05),
      ),
      HuiActionMenuItem(
        label: huiText('Increase uiScale'),
        icon: ArcaneIcon.plus(size: IconSize.sm),
        hint: huiText("{toStringAsFixed} · step 0.05", <String, Object?>{
          'toStringAsFixed': _store.previewUiScale.toStringAsFixed(2),
        }),
        disabled: _store.previewUiScale >= 4,
        onSelect: () => _changeScale(0.05),
      ),
      HuiActionMenuItem(
        label: huiText('Reset uiScale to 1.00'),
        icon: ArcaneIcon.rotateCcw(size: IconSize.sm),
        disabled: _store.previewUiScale == 1,
        onSelect: () => _store.previewUiScale = 1,
      ),
      if (hasSelection) ...<HuiActionMenuItem>[
        HuiActionMenuItem(
          label: huiText('Bring forward'),
          icon: ArcaneIcon.chevronUp(size: IconSize.sm),
          separatorBefore: true,
          onSelect: () => component.onZOrder(HuiZOrder.forward),
        ),
        HuiActionMenuItem(
          label: huiText('Send back'),
          icon: ArcaneIcon.chevronDown(size: IconSize.sm),
          onSelect: () => component.onZOrder(HuiZOrder.backward),
        ),
        HuiActionMenuItem(
          label: huiText('Bring to front'),
          icon: ArcaneIcon.bringToFront(size: IconSize.sm),
          onSelect: () => component.onZOrder(HuiZOrder.toFront),
        ),
        HuiActionMenuItem(
          label: huiText('Send to back'),
          icon: ArcaneIcon.sendToBack(size: IconSize.sm),
          onSelect: () => component.onZOrder(HuiZOrder.toBack),
        ),
        HuiActionMenuItem(
          label: huiText('Move nearer (-z)'),
          icon: ArcaneIcon.moveLeft(size: IconSize.sm),
          hint: huiText("Depth step {toStringAsFixed}", <String, Object?>{
            'toStringAsFixed': huiDepthStep.toStringAsFixed(2),
          }),
          onSelect: () => _nudgeDepth(-huiDepthStep),
        ),
        HuiActionMenuItem(
          label: huiText('Move deeper (+z)'),
          icon: ArcaneIcon.moveRight(size: IconSize.sm),
          hint: huiText("Depth step {toStringAsFixed}", <String, Object?>{
            'toStringAsFixed': huiDepthStep.toStringAsFixed(2),
          }),
          onSelect: () => _nudgeDepth(huiDepthStep),
        ),
      ],
      if (component.hasAnimatedIcons)
        _toggleItem(
          activeLabel: huiText('Pause animations'),
          inactiveLabel: huiText('Play animations'),
          icon: _store.animationsPlaying
              ? ArcaneIcon.pause(size: IconSize.sm)
              : ArcaneIcon.play(size: IconSize.sm),
          active: _store.animationsPlaying,
          separatorBefore: true,
          onSelect: () => _store.animationsPlaying = !_store.animationsPlaying,
        ),
      if (selected != null &&
          selected.data is HuiToggleData) ...<HuiActionMenuItem>[
        HuiActionMenuItem(
          label: huiText('Preview true icon'),
          icon: ArcaneIcon.toggleRight(size: IconSize.sm),
          separatorBefore: !component.hasAnimatedIcons,
          disabled: showsTrue,
          onSelect: () => _store.setTogglePreview(selected.id, true),
        ),
        HuiActionMenuItem(
          label: huiText('Preview false icon'),
          icon: ArcaneIcon.toggleLeft(size: IconSize.sm),
          disabled: !showsTrue,
          onSelect: () => _store.setTogglePreview(selected.id, false),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) =>
      dom.span(classes: 'hui-canvas-compact-control', <Widget>[
        ArcaneTooltip(
          text: huiText('More canvas controls'),
          child: Button(
            id: _triggerId,
            key: ValueKey<bool>(_menuPoint != null),
            icon: ArcaneIcon.ellipsis(size: IconSize.sm),
            variant: ButtonVariant.ghost,
            size: ButtonSize.iconSm,
            type: ButtonType.button,
            attributes: <String, String>{
              'aria-label': huiText('More canvas controls'),
              'aria-haspopup': 'menu',
              'aria-expanded': '${_menuPoint != null}',
              'aria-controls': _menuId,
              'data-arcane-interactive': 'true',
            },
            onPressed: _menuPoint == null ? _open : _close,
          ),
        ),
        if (_menuPoint != null)
          HuiActionMenu(
            id: _menuId,
            label: huiText('More canvas controls'),
            point: _menuPoint!,
            items: _items(),
            onClose: _close,
          ),
      ]);
}

/// Pointer travel that buys one [huiDepthStep] of depth.
const double huiZScrubPxPerStep = 4;

/// Drag-to-change depth for the whole selection.
///
/// Hand-built rather than `ArcaneSlider`, which never wires `onChanged` to the
/// DOM — its thumb moves while the store stays put. A native `input[type=range]`
/// is no good here either: `z` has no useful bounds, and this is a relative
/// scrubber, not an absolute track.
///
/// One pointer gesture is one undo step, exactly like a canvas drag: every
/// frame re-applies the total delta to the offsets captured at pointer-down,
/// wrapped in `beginDrag`/`endDrag`.
class _ZScrubber extends StatefulWidget {
  const _ZScrubber({required this.store});

  final EditorStore store;

  @override
  State<_ZScrubber> createState() => _ZScrubberState();
}

class _ZScrubberState extends State<_ZScrubber> {
  static int _instances = 0;

  late final String _uid = 'hui-zscrub-${_instances++}';

  int? _pointerId;
  double _startClientX = 0;
  int _steps = 0;
  Map<String, Vec3> _startOffsets = const <String, Vec3>{};

  web.Element? get _element => web.document.getElementById(_uid);

  /// `package:web` declares `clientX` as `int` while real pointers report
  /// fractions, and dynamic dispatch on extension types throws under dart2js.
  double _eventDouble(Object? event, String property) {
    final JSObject? object = event as JSObject?;
    final JSAny? value = object?.getProperty<JSAny?>(property.toJS);
    if (value == null || !value.isA<JSNumber>()) return 0;
    return (value as JSNumber).toDartDouble;
  }

  int _eventInt(Object? event, String property) =>
      _eventDouble(event, property).round();

  String _eventString(Object? event, String property) {
    final JSObject? object = event as JSObject?;
    final JSAny? value = object?.getProperty<JSAny?>(property.toJS);
    if (value == null || !value.isA<JSString>()) return '';
    return (value as JSString).toDart;
  }

  Map<String, Vec3> _captureOffsets() => <String, Vec3>{
    for (final HuiComponent selected in component.store.selectedComponents)
      selected.id: selected.offset.copy(),
  };

  void _onDown(Object? event) {
    if (_eventInt(event, 'button') != 0) return;
    final Map<String, Vec3> captured = _captureOffsets();
    if (captured.isEmpty) return;
    _startOffsets = captured;
    _startClientX = _eventDouble(event, 'clientX');
    _steps = 0;
    final int pointerId = _eventInt(event, 'pointerId');
    try {
      _element?.setPointerCapture(pointerId);
    } catch (_) {
      // Capture is an enhancement; the drag still works over the control.
    }
    _pointerId = pointerId;
    component.store.beginDrag();
    setState(() {});
    (event as JSObject?)?.callMethod<JSAny?>('preventDefault'.toJS);
  }

  void _onMove(Object? event) {
    if (_pointerId == null) return;
    if (_eventInt(event, 'pointerId') != _pointerId) return;
    final int steps =
        ((_eventDouble(event, 'clientX') - _startClientX) / huiZScrubPxPerStep)
            .round();
    if (steps == _steps) return;
    _steps = steps;
    _write(_startOffsets, steps * huiDepthStep);
  }

  void _onUp(Object? event) {
    if (_pointerId == null) return;
    _release();
    component.store.endDrag();
    _startOffsets = const <String, Vec3>{};
    setState(() {});
  }

  void _release() {
    final int? pointerId = _pointerId;
    _pointerId = null;
    if (pointerId == null) return;
    try {
      final web.Element? element = _element;
      if (element != null && element.hasPointerCapture(pointerId)) {
        element.releasePointerCapture(pointerId);
      }
    } catch (_) {
      // Already released by the browser.
    }
  }

  /// Arrow keys step depth. The event is stopped here because the shell's
  /// document binder stands down only for real form controls, and would
  /// otherwise nudge the selection in x/y at the same time.
  void _onKeyDown(Object? event) {
    final double delta = switch (_eventString(event, 'key')) {
      'ArrowRight' || 'ArrowUp' => huiDepthStep,
      'ArrowLeft' || 'ArrowDown' => -huiDepthStep,
      _ => 0,
    };
    if (delta == 0) return;
    final JSObject? raw = event as JSObject?;
    raw?.callMethod<JSAny?>('preventDefault'.toJS);
    raw?.callMethod<JSAny?>('stopPropagation'.toJS);
    _write(_captureOffsets(), delta);
  }

  void _write(Map<String, Vec3> from, double dz) {
    if (from.isEmpty) return;
    final Map<String, Vec3> next = shiftOffsets(offsets: from, dz: dz);
    component.store.setOffsets(
      next.length == 1
          ? 'depth ${next.keys.first}'
          : 'depth ${next.length} components',
      next,
    );
  }

  @override
  Widget build(BuildContext context) {
    final EditorStore store = component.store;
    final List<HuiComponent> selected = store.selectedComponents;
    final double value = store.selected?.offset.z ?? 0;
    final bool mixed = selected.any((HuiComponent c) => c.offset.z != value);
    return ArcaneTooltip(
      text: mixed
          ? huiPlural(
              'canvas.depth.mixed_components',
              selected.length,
              oneEnglish:
                  'Depth of {count} component (mixed). Drag or use the arrows '
                  'to move it; larger z paints first, so it draws further back',
              otherEnglish:
                  'Depth of {count} components (mixed). Drag or use the arrows '
                  'to move them all; larger z paints first, so it draws '
                  'further back',
            )
          : huiText(
              'Depth. Drag or use the arrows; larger z paints first, so it '
              'draws further back',
            ),
      child: dom.span(
        id: _uid,
        classes: classNames(<String?>[
          'hui-canvas-zscrub',
          _pointerId != null ? 'is-scrubbing' : null,
        ]),
        attributes: <String, String>{
          'tabindex': '0',
          'role': 'slider',
          'aria-valuenow': _format(value),
          'aria-label': selected.length == 1
              ? huiText('Depth of {id}', <String, Object?>{
                  'id': selected.first.id,
                })
              : huiPlural(
                  'canvas.depth.selected_components',
                  selected.length,
                  oneEnglish: 'Depth of {count} selected component',
                  otherEnglish: 'Depth of {count} selected components',
                ),
        },
        events: <String, EventCallback>{
          'pointerdown': _onDown,
          'pointermove': _onMove,
          'pointerup': _onUp,
          'pointercancel': _onUp,
          'keydown': _onKeyDown,
        },
        <Widget>[
          dom.span(classes: 'hui-canvas-zscrub-key', <Widget>[
            Component.text(huiText('z')),
          ]),
          dom.span(classes: 'hui-canvas-zscrub-value', <Widget>[
            Component.text(mixed ? '${_format(value)}*' : _format(value)),
          ]),
        ],
      ),
    );
  }

  static String _format(double value) => value.toStringAsFixed(2);
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
          'aria-label': huiText(
            "Preview uiScale {value}. Opens the uiScale slider",
            <String, Object?>{'value': value},
          ),
          'aria-haspopup': 'dialog',
          'aria-expanded': _open ? 'true' : 'false',
          // Inside a floating container the trigger's next sibling IS the
          // popup, so the legacy accordion binder would write `display` onto
          // it and fight the popover script. `data-arcane-interactive` is that
          // binder's opt-out (accordion_scripts.dart:8); the popover script
          // keys on `arcanePopoverInteractive` and is unaffected.
          'data-arcane-interactive': 'true',
        },
        child: dom.span(classes: 'hui-canvas-scale-trigger', <Widget>[
          dom.span(classes: 'hui-canvas-tool-label', <Widget>[
            Component.text(huiText('uiScale')),
          ]),
          dom.span(classes: 'hui-canvas-scale-value', <Widget>[
            Component.text(value),
          ]),
        ]),
      ),
      content: dom.div(classes: 'hui-scale-pop', <Widget>[
        dom.span(classes: 'hui-eyebrow', <Widget>[
          Component.text(huiText('server uiScale (preview)')),
        ]),
        dom.p(classes: 'hui-scale-pop-note', <Widget>[
          Component.text(
            huiText(
              'Mirrors the ui-scale the server renders the menu at. Preview '
              'only: it is never written to the layout file.',
            ),
          ),
        ]),
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
            'aria-label': huiText('Preview uiScale'),
          },
        ),
        const dom.div(classes: 'hui-scale-pop-ticks', <Widget>[
          dom.span(<Widget>[Component.text('0.25')]),
          dom.span(<Widget>[Component.text('1.00')]),
          dom.span(<Widget>[Component.text('4.00')]),
        ]),
        dom.div(classes: 'hui-scale-pop-foot', <Widget>[
          dom.span(classes: 'hui-scale-pop-value', <Widget>[
            Component.text('${value}x'),
          ]),
          Button(
            label: huiText('Reset to 1.00'),
            icon: ArcaneIcon.rotateCcw(size: IconSize.sm),
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            type: ButtonType.button,
            attributes: <String, String>{
              'aria-label': huiText('Reset uiScale to 1.00'),
            },
            onPressed: () => store.previewUiScale = 1,
          ),
        ]),
      ]),
    );
  }
}

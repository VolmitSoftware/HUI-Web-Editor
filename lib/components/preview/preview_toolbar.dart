/// The preview's control strip.
///
/// Every control here writes to exactly one place — the store, the pose, or the
/// stage through [PreviewStageController] — and then gets out of the way; the
/// stage observes those and repaints itself. Nothing in this file touches the
/// stage's DOM.
///
/// The strip is rebuilt by its caller's `ListenableBuilder`s, so the only state
/// it owns is whether the overlays menu is open.
///
/// Layout contract with `web/styles/07-preview.css`: the strip WRAPS. The canvas
/// toolbar is a one-row contract that drops labels to stay on one line, but this
/// strip carries a range input, and a range that shrinks to a stub or vanishes
/// at a narrow width is a control the user can no longer reach. Wrapping keeps
/// every control usable at every width; the `.hui-preview-tool-label` spans are
/// still the stylesheet's to drop.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:arcane_jaspr/core/dom_value.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show Component, EventCallback;
import 'package:web/web.dart' as web;

import '../../preview/preview_types.dart';
import '../../state/editor_store.dart';
import '../inspector/field_help.dart';
import 'preview_pose.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

/// One of the six overlay flags W0 put on the store, with the runtime truth it
/// exists to show. Kept as data so the menu, the count chip and the accessible
/// names can never drift apart.
class _Overlay {
  const _Overlay({
    required this.label,
    required this.hint,
    required this.read,
    required this.write,
  });

  final String label;
  final String hint;
  final bool Function(EditorStore store) read;
  final void Function(EditorStore store, bool value) write;
}

const List<_Overlay> _overlays = <_Overlay>[
  _Overlay(
    label: 'Collision planes',
    hint:
        'The rectangle a click is tested against. It uses the icon\'s fixed, '
        'vertical, horizontal or center billboard rule.',
    read: _readPlanes,
    write: _writePlanes,
  ),
  _Overlay(
    label: 'Plane normals',
    hint: 'The direction a hovered icon is pushed along.',
    read: _readNormals,
    write: _writeNormals,
  ),
  _Overlay(
    label: 'Anchors',
    hint:
        'The offset point each icon hangs from, before its own vertical '
        'anchor and the one-nametag spawn drop.',
    read: _readAnchors,
    write: _writeAnchors,
  ),
  _Overlay(
    label: 'Menu centre',
    hint:
        'Current anchor plus the transformed menu offset — the point '
        'maxDistance is measured to.',
    read: _readCenter,
    write: _writeCenter,
  ),
  _Overlay(
    label: 'maxDistance sphere',
    hint:
        'The shell the menu closes outside of, loosened by the menu offset '
        '(MenuSession.java:147-151).',
    read: _readSphere,
    write: _writeSphere,
  ),
  _Overlay(
    label: 'Ground grid',
    hint: 'One square per block, at the height of the player\'s feet.',
    read: _readGround,
    write: _writeGround,
  ),
];

// Tear-offs: a const list cannot hold closures.
bool _readPlanes(EditorStore store) => store.previewShowPlanes;
void _writePlanes(EditorStore store, bool value) =>
    store.previewShowPlanes = value;
bool _readNormals(EditorStore store) => store.previewShowNormals;
void _writeNormals(EditorStore store, bool value) =>
    store.previewShowNormals = value;
bool _readAnchors(EditorStore store) => store.previewShowAnchors;
void _writeAnchors(EditorStore store, bool value) =>
    store.previewShowAnchors = value;
bool _readCenter(EditorStore store) => store.previewShowCenter;
void _writeCenter(EditorStore store, bool value) =>
    store.previewShowCenter = value;
bool _readSphere(EditorStore store) => store.previewShowDistanceSphere;
void _writeSphere(EditorStore store, bool value) =>
    store.previewShowDistanceSphere = value;
bool _readGround(EditorStore store) => store.previewShowGroundGrid;
void _writeGround(EditorStore store, bool value) =>
    store.previewShowGroundGrid = value;

class PreviewToolbar extends StatefulWidget {
  const PreviewToolbar({required this.store, required this.pose, super.key});

  final EditorStore store;
  final PreviewPose pose;

  @override
  State<PreviewToolbar> createState() => _PreviewToolbarState();
}

class _PreviewToolbarState extends State<PreviewToolbar> {
  static int _instances = 0;

  late final String _uid = 'hui-preview-overlays-${_instances++}';
  String get _menuId => '$_uid-menu';
  String get _triggerId => '$_uid-trigger';

  bool _overlaysOpen = false;

  EditorStore get _store => component.store;

  PreviewPose get _pose => component.pose;

  /// Opens or closes the overlays menu and moves focus with it.
  ///
  /// Moving focus is not decoration: Arcane's button feedback script calls
  /// `preventDefault` on mousedown, so clicking the trigger leaves focus on
  /// `body` and a keydown handler anywhere inside this widget never sees
  /// Escape. Measured — Escape did nothing until the menu took focus itself.
  void _setOverlaysOpen(bool open) {
    if (_overlaysOpen == open) return;
    setState(() => _overlaysOpen = open);
    context.binding.addPostFrameCallback(() {
      final web.Element? target = web.document.getElementById(
        open ? _menuId : _triggerId,
      );
      (target as web.HTMLElement?)?.focus();
    });
  }

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-preview-toolbar',
    attributes: <String, String>{
      'role': 'toolbar',
      'aria-label': huiText('Preview controls'),
    },
    <Widget>[
      _group(huiText('Icon facing'), <Widget>[_billboardHelp()]),
      _group(null, _cameraControls()),
      _group(null, <Widget>[_playPauseControl()]),
      _group(null, <Widget>[_scaleControl()]),
      _group(null, <Widget>[_overlaysControl()]),
      _group(null, _logControls()),
    ],
  );

  Widget _group(String? eyebrow, List<Widget> children) =>
      dom.div(classes: 'hui-preview-toolgroup', <Widget>[
        if (eyebrow != null)
          dom.span(classes: 'hui-eyebrow hui-preview-tool-label', <Widget>[
            Component.text(eyebrow),
          ]),
        ...children,
      ]);

  Widget _billboardHelp() => HuiHelpPopover(
    title: huiText('Runtime billboard facing'),
    body: huiText(
      'Fixed icons use the menu yaw, pitch and roll. Vertical icons yaw '
      'toward the viewer while keeping world up. Horizontal icons keep the '
      'menu-right axis and pitch toward the viewer. Center icons fully face '
      'the viewer. Click planes use the same rule. A static menu keeps its '
      'open pose; followPlayer updates its position and yaw as the player '
      'moves or looks.',
    ),
    triggerLabel: huiText('How runtime billboard facing works'),
    align: HuiFieldHelpAlign.start,
  );

  List<Widget> _cameraControls() => <Widget>[
    _modeButton(
      mode: PreviewCameraMode.orbit,
      label: huiText('Orbit'),
      icon: ArcaneIcon.orbit(size: IconSize.sm),
      tooltip: huiText(
        'Orbit camera: drag to turn around the menu, scroll to '
        'dolly, space-drag to pan',
      ),
    ),
    _modeButton(
      mode: PreviewCameraMode.player,
      label: huiText('Player'),
      icon: ArcaneIcon.user(size: IconSize.sm),
      tooltip: huiText(
        'Player camera: the view from eye height, 1.62 blocks above '
        'the feet the menu is anchored to',
      ),
    ),
    _action(
      icon: ArcaneIcon.refreshCcw(size: IconSize.sm),
      label: huiText('Reset view'),
      tooltip: huiText(
        'Reset to the open position - where the player was standing '
        'and looking when the menu opened (0)',
      ),
      onPressed: () => _pose.controller?.resetCamera(),
    ),
    _action(
      icon: ArcaneIcon.rotate3d(size: IconSize.sm),
      label: huiText('Reopen here'),
      tooltip: huiText(
        'Open a fresh session from where the camera is now. The new '
        'yaw becomes the menu\'s open facing, and the log starts over. '
        'A followPlayer menu can turn with the player after opening',
      ),
      onPressed: () => _pose.controller?.reopenHere(),
    ),
  ];

  Widget _modeButton({
    required PreviewCameraMode mode,
    required String label,
    required Widget icon,
    required String tooltip,
  }) {
    final bool active = _store.previewCameraMode == mode;
    return ArcaneTooltip(
      text: tooltip,
      child: Button(
        key: ValueKey<String>('camera-${mode.name}-$active'),
        icon: icon,
        variant: active ? ButtonVariant.secondary : ButtonVariant.ghost,
        size: ButtonSize.sm,
        type: ButtonType.button,
        attributes: <String, String>{
          'aria-pressed': '$active',
          'aria-label': huiText("{label} camera. {tooltip}", <String, Object?>{
            'label': label,
            'tooltip': tooltip,
          }),
        },
        onPressed: () => _store.previewCameraMode = mode,
        child: _toolLabel(label),
      ),
    );
  }

  /// The server's global `uiScale`, inline.
  ///
  /// A native `input[type=range]`, never `ArcaneSlider`: its `onChanged` never
  /// reaches Dart, so its thumb moves while the document stays put. Shares
  /// `.hui-range` with the Settings dialog and the inspector, and edits the
  /// same store field all three do.
  Widget _scaleControl() {
    final String value = _store.previewUiScale.toStringAsFixed(2);
    return dom.div(classes: 'hui-preview-scale', <Widget>[
      dom.span(classes: 'hui-eyebrow hui-preview-tool-label', <Widget>[
        Component.text(huiText('uiScale')),
      ]),
      dom.input<num>(
        type: dom.InputType.range,
        classes: 'hui-range hui-preview-scale-range',
        value: value,
        // No setState: the store notifies and the ListenableBuilder that
        // wraps this strip rebuilds it, exactly as the canvas toolbar does.
        onInput: (num next) =>
            _store.previewUiScale = (next.toDouble() * 100).round() / 100,
        attributes: <String, String>{
          'min': '0.25',
          'max': '4',
          'step': '0.05',
          'aria-label': huiText(
            'Server uiScale. Multiplies every component offset '
            'and every icon size, but never the menu offset',
          ),
        },
      ),
      dom.span(classes: 'hui-preview-scale-value', <Widget>[
        Component.text('${value}x'),
      ]),
    ]);
  }

  /// The preview's own playback switch, the pointer half of `K`.
  ///
  /// Writes `pose.paused`, which is deliberately NOT
  /// `store.animationsPlaying` — the canvas keeps playing while the preview is
  /// frozen. Always shown, never gated on the menu having animated icons: a
  /// pause also stops obfuscated glyphs and takes the stage to zero scheduled
  /// frames, and it annotates the banner, so it is observable on any document.
  Widget _playPauseControl() {
    final bool playing = !_pose.paused;
    return _toggle(
      icon: playing
          ? ArcaneIcon.pause(size: IconSize.sm)
          : ArcaneIcon.play(size: IconSize.sm),
      label: playing ? huiText('Pause') : huiText('Play'),
      tooltip: huiText(
        'Preview clock (K): animated frames advance and obfuscated '
        'glyphs scramble every 50 ms. Paused, the stage schedules nothing; '
        'hover and clicks still run',
      ),
      active: playing,
      onPressed: () => _pose.paused = playing,
    );
  }

  /// The six overlay flags, in a hand-built menu.
  ///
  /// Hand-built because `ArcaneDropdownMenu` never opens in this arcane_jaspr
  /// build in either script configuration; same shape as the rail's row menu.
  /// Items are `menuitemcheckbox` and deliberately do NOT close the menu — the
  /// point of a group of overlays is turning several on at once.
  Widget _overlaysControl() {
    final int on = _overlays.where((_Overlay o) => o.read(_store)).length;
    return dom.div(
      classes: 'hui-preview-overlays',
      // Escape is caught on the wrapper, not on the menu: opening from the
      // trigger leaves focus ON the trigger, which is a sibling of the menu, so
      // a handler bound to the menu alone never sees the key. Measured.
      events: _overlaysOpen
          ? <String, EventCallback>{
              'keydown': (Object event) {
                if (domEventKey(event) != 'Escape') return;
                domStopPropagation(event);
                _setOverlaysOpen(false);
              },
            }
          : null,
      <Widget>[
        ArcaneTooltip(
          text: huiText(
            'Overlays: what the runtime measures against, drawn in the scene',
          ),
          child: Button(
            id: _triggerId,
            key: ValueKey<String>('overlays-$_overlaysOpen-$on'),
            icon: ArcaneIcon.layers(size: IconSize.sm),
            variant: _overlaysOpen
                ? ButtonVariant.secondary
                : ButtonVariant.ghost,
            size: ButtonSize.sm,
            type: ButtonType.button,
            attributes: <String, String>{
              'aria-haspopup': 'menu',
              'aria-expanded': _overlaysOpen ? 'true' : 'false',
              // Never the word "Menu" with a capital M: the mobile-menu binder
              // claims `[aria-label*="Menu"]` (`mobile_menu_scripts.dart:7`).
              'aria-label': huiText(
                "Overlays, {on} of {length} shown",
                <String, Object?>{'on': on, 'length': _overlays.length},
              ),
              // The legacy accordion binder claims every `button[aria-expanded]`
              // in a one-shot scan 100 ms after boot and then writes
              // `display: none|block` onto the button's next sibling. This is
              // that binder's own opt-out (`accordion_scripts.dart:8`) — a
              // guarantee, where a CSS guard is only a race that usually wins.
              'data-arcane-interactive': 'true',
            },
            onPressed: () => _setOverlaysOpen(!_overlaysOpen),
            child: dom.span(classes: 'hui-preview-overlays-trigger', <Widget>[
              _toolLabel(huiText('Overlays')),
              if (on > 0)
                dom.span(classes: 'hui-count-chip', <Widget>[
                  Component.text('$on'),
                ]),
            ]),
          ),
        ),
        if (_overlaysOpen) ..._overlaysMenu(),
      ],
    );
  }

  List<Widget> _overlaysMenu() => <Widget>[
    // A transparent full-viewport layer under the menu: one click anywhere
    // closes it. Rendered by the same condition as the menu, so unlike a
    // document listener it cannot outlive it.
    dom.div(
      classes: 'hui-preview-overlaymenu-scrim',
      attributes: const <String, String>{'aria-hidden': 'true'},
      events: <String, EventCallback>{
        'pointerdown': (Object _) => _setOverlaysOpen(false),
      },
      const <Widget>[],
    ),
    dom.div(
      id: _menuId,
      classes: 'hui-preview-overlaymenu hui-anim-in',
      attributes: <String, String>{
        'role': 'menu',
        'aria-label': huiText('Preview overlays'),
        // Focused on open; see [_setOverlaysOpen]. Never reachable by Tab,
        // which is what -1 buys over 0.
        'tabindex': '-1',
      },
      <Widget>[for (final _Overlay overlay in _overlays) _overlayItem(overlay)],
    ),
  ];

  Widget _overlayItem(_Overlay overlay) {
    final bool on = overlay.read(_store);
    return dom.button(
      classes: 'hui-preview-overlaymenu-item${on ? ' is-on' : ''}',
      attributes: <String, String>{
        'type': 'button',
        'role': 'menuitemcheckbox',
        'aria-checked': '$on',
      },
      events: <String, EventCallback>{
        // The store notifies synchronously, which rebuilds this strip while the
        // click is still being handled. That is safe here only because the menu
        // stays open — its open flag is untouched — so the item survives the
        // patch. A menu item that also closed the menu would have to close
        // first and act second (the rail's rule).
        'click': (Object _) => overlay.write(_store, !on),
      },
      <Widget>[
        dom.span(
          classes: 'hui-preview-overlaymenu-tick',
          attributes: const <String, String>{'aria-hidden': 'true'},
          <Widget>[if (on) ArcaneIcon.check(size: IconSize.sm)],
        ),
        dom.span(classes: 'hui-preview-overlaymenu-text', <Widget>[
          dom.span(classes: 'hui-preview-overlaymenu-label', <Widget>[
            Component.text(huiText(overlay.label)),
          ]),
          dom.span(classes: 'hui-preview-overlaymenu-hint', <Widget>[
            Component.text(huiText(overlay.hint)),
          ]),
        ]),
      ],
    );
  }

  List<Widget> _logControls() => <Widget>[
    _toggle(
      icon: ArcaneIcon.terminal(size: IconSize.sm),
      label: huiText('Log'),
      tooltip: huiText('Action log: what each simulated click would have run'),
      active: _store.previewLogOpen,
      onPressed: () => _store.previewLogOpen = !_store.previewLogOpen,
    ),
    ArcaneTooltip(
      text: huiText('Clear the action log'),
      child: Button(
        icon: ArcaneIcon.trash2(size: IconSize.sm),
        variant: ButtonVariant.ghost,
        size: ButtonSize.sm,
        type: ButtonType.button,
        disabled: _pose.log.isEmpty,
        attributes: <String, String>{'aria-label': huiText('Clear log')},
        onPressed: _pose.log.clear,
        child: _toolLabel(huiText('Clear log')),
      ),
    ),
  ];

  Widget _action({
    required Widget icon,
    required String label,
    required String tooltip,
    required void Function() onPressed,
  }) => ArcaneTooltip(
    text: tooltip,
    child: Button(
      icon: icon,
      variant: ButtonVariant.ghost,
      size: ButtonSize.sm,
      type: ButtonType.button,
      attributes: <String, String>{'aria-label': label},
      onPressed: onPressed,
      child: _toolLabel(label),
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
      key: ValueKey<String>('toggle-$label-$active'),
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

  /// Text the stylesheet may drop when the preview cell is narrow. Never the
  /// only description of a control.
  static Widget _toolLabel(String text) => dom.span(
    classes: 'hui-preview-tool-label',
    <Widget>[Component.text(text)],
  );
}

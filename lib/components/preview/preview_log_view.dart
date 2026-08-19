/// The dockable action log.
///
/// Every simulated click appends the nearest component that fired. Rows retain
/// the exact left/right and sneak-modified interaction used for action
/// filtering.
///
/// Two behaviours here are deliberate and load-bearing:
///
///  * **The dock has a height, never a content size.** It is the last row of the
///    preview grid and the stage is the flexible one, so a dock that grew with
///    each logged entry would shrink the stage under the pointer: clicking a
///    button would move the menu, and the second click of a toggle round trip
///    would miss. Rows scroll inside a fixed box instead, and the only thing
///    that ever changes that height is the user dragging the splitter.
///  * **The splitter is hand-built.** `ArcaneResizable` exposes no Dart
///    callbacks at all. A drag writes `--hui-preview-log-h` straight onto the
///    document root — an inline custom property on `<html>`, which Jaspr renders
///    nothing above, so no rebuild can stomp it and the gesture needs no
///    `setState` until it settles.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show Component;
import 'package:web/web.dart' as web;

import '../../preview/action_log.dart';
import '../../state/editor_store.dart';
import 'preview_pose.dart';

/// The custom property `.hui-preview-log` reads its height from. Its fallback
/// in `07-preview.css` is [huiPreviewLogDefaultHeight].
const String huiPreviewLogHeightVar = '--hui-preview-log-h';

const double huiPreviewLogDefaultHeight = 190;
const double huiPreviewLogMinHeight = 96;

/// The stage is never dragged below this. A preview you cannot see is not a
/// preview, however much log you wanted.
const double huiPreviewStageMinHeight = 180;

/// Splitter keyboard step, and the coarse step Shift buys.
const double huiPreviewLogKeyStep = 16;
const double huiPreviewLogKeyStepCoarse = 48;

/// How close to the tail still counts as pinned. One row of slack, so a
/// half-pixel scroll position or a sub-pixel row height never unpins.
const double huiPreviewLogPinSlack = 24;

class PreviewLogView extends StatefulWidget {
  const PreviewLogView({required this.store, required this.log, super.key});

  final EditorStore store;
  final PreviewLogBuffer log;

  @override
  State<PreviewLogView> createState() => _PreviewLogViewState();
}

class _PreviewLogViewState extends State<PreviewLogView> {
  static int _instances = 0;

  late final String _uid = 'hui-preview-log-${_instances++}';
  String get _dockId => '$_uid-dock';
  String get _rowsId => '$_uid-rows';
  String get _splitterId => '$_uid-splitter';

  /// False once the user has scrolled away from the tail. New entries then stop
  /// yanking the view back, and the head offers a way to return.
  bool _pinned = true;

  /// Committed height, only ever used to render `aria-valuenow`. The live value
  /// during a drag is in the DOM.
  double _heightPx = huiPreviewLogDefaultHeight;

  bool _disposed = false;
  bool _postFramePending = false;
  void Function()? _uninstall;
  web.HTMLElement? _boundDock;

  EditorStore get _store => component.store;

  PreviewLogBuffer get _log => component.log;

  @override
  void dispose() {
    _disposed = true;
    _uninstall?.call();
    _uninstall = null;
    _boundDock = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _schedulePostFrame();
    if (!_store.previewLogOpen) {
      // An empty row rather than nothing: the grid keeps its shape and the
      // stage never resizes twice for one toggle.
      return const dom.div(classes: 'hui-preview-log-closed', <Widget>[]);
    }
    final List<List<ActionLogEntry>> groups = _groups(_log.entries);
    return dom.div(
      id: _dockId,
      // Entrance only; the caller owns the unmount, so there is nothing to
      // animate out (see the note at the foot of 06-motion.css).
      classes: 'hui-preview-log hui-anim-slide-up',
      attributes: const <String, String>{
        'role': 'region',
        'aria-label': 'Action log',
      },
      <Widget>[
        _splitter(),
        _head(),
        if (groups.isEmpty) _empty() else _rows(groups),
      ],
    );
  }

  // --- chrome ----------------------------------------------------------------

  Widget _splitter() => dom.div(
    id: _splitterId,
    classes: 'hui-preview-log-splitter',
    attributes: <String, String>{
      'role': 'separator',
      'aria-orientation': 'horizontal',
      'aria-label': 'Resize the action log',
      'aria-valuemin': huiPreviewLogMinHeight.round().toString(),
      'aria-valuenow': _heightPx.round().toString(),
      'aria-valuetext': '${_heightPx.round()} pixels tall',
      'tabindex': '0',
    },
    const <Widget>[
      dom.span(
        classes: 'hui-preview-log-grip',
        attributes: <String, String>{'aria-hidden': 'true'},
        <Widget>[],
      ),
    ],
  );

  Widget _head() => dom.div(classes: 'hui-preview-log-head', <Widget>[
    const dom.span(classes: 'hui-eyebrow', <Widget>[
      Component.text('action log'),
    ]),
    dom.span(classes: 'hui-preview-log-count', <Widget>[
      Component.text(_countText()),
    ]),
    dom.div(classes: 'hui-preview-log-headtools', <Widget>[
      if (!_pinned && _log.isNotEmpty)
        ArcaneTooltip(
          text: 'Jump back to the newest entry and follow it again',
          // Opens leftward: these two sit hard against the dock's right
          // edge, and a top-positioned bubble hangs past it — clipped by
          // `.hui-preview`'s overflow, and it widens the dock's scroll
          // width on the way out.
          position: FloatingPosition.left,
          child: Button(
            icon: ArcaneIcon.arrowDownToLine(size: IconSize.sm),
            label: 'Newest',
            variant: ButtonVariant.ghost,
            size: ButtonSize.sm,
            type: ButtonType.button,
            attributes: const <String, String>{
              'aria-label': 'Scroll to the newest entry',
            },
            onPressed: () {
              _scrollToTail();
              setState(() => _pinned = true);
            },
          ),
        ),
      ArcaneTooltip(
        text: 'Close the log dock',
        position: FloatingPosition.left,
        child: Button(
          icon: ArcaneIcon.x(size: IconSize.sm),
          variant: ButtonVariant.ghost,
          size: ButtonSize.iconSm,
          type: ButtonType.button,
          attributes: const <String, String>{
            'aria-label': 'Close the action log',
          },
          onPressed: () => _store.previewLogOpen = false,
        ),
      ),
    ]),
  ]);

  String _countText() {
    if (_log.isEmpty) return 'nothing fired yet';
    final String dropped = _log.droppedCount > 0
        ? ' · ${_log.droppedCount} dropped'
        : '';
    return '${_log.length} ${_log.length == 1 ? 'entry' : 'entries'}$dropped';
  }

  Widget _empty() => const dom.p(classes: 'hui-preview-log-empty', <Widget>[
    Component.text(
      'Left- or right-click a component in the preview. The nearest hitbox '
      'fires; hold Shift to test sneak-bound actions.',
    ),
  ]);

  // --- rows ------------------------------------------------------------------

  Widget _rows(List<List<ActionLogEntry>> groups) => dom.div(
    id: _rowsId,
    classes: 'hui-preview-log-rows',
    attributes: const <String, String>{'tabindex': '0'},
    <Widget>[
      for (int i = 0; i < groups.length; i++)
        _group(groups[i], newest: i == groups.length - 1),
    ],
  );

  /// Entries sharing a tick are grouped under one compact heading.
  Widget _group(List<ActionLogEntry> entries, {required bool newest}) =>
      dom.div(
        // Only the newest group carries the entrance, so an append animates the
        // arrival and leaves everything above it alone.
        classes:
            'hui-preview-log-group${newest ? ' is-newest hui-anim-in' : ''}',
        <Widget>[
          dom.div(classes: 'hui-preview-log-grouphead', <Widget>[
            dom.span(classes: 'hui-preview-log-tick', <Widget>[
              Component.text('#${entries.first.tick}'),
            ]),
            if (entries.length > 1)
              dom.span(classes: 'hui-preview-log-groupnote', <Widget>[
                Component.text(
                  '${entries.length} clicks were recorded before the next '
                  'simulation tick',
                ),
              ]),
          ]),
          for (final ActionLogEntry entry in entries) _row(entry),
        ],
      );

  Widget _row(ActionLogEntry entry) =>
      dom.div(classes: 'hui-preview-log-row', <Widget>[
        dom.div(classes: 'hui-preview-log-meta', <Widget>[
          dom.span(classes: 'hui-preview-log-id', <Widget>[
            Component.text(entry.componentId),
          ]),
          dom.span(classes: 'hui-preview-log-trigger', <Widget>[
            Component.text(
              '${entry.trigger.label} · '
              '${actionClickTriggerLabel(entry.clickTrigger)}',
            ),
          ]),
        ]),
        if (entry.actions.isEmpty)
          const dom.div(classes: 'hui-preview-log-action is-empty', <Widget>[
            Component.text('no actions — it still fired'),
          ])
        else
          for (final LoggedAction action in entry.actions) _action(action),
      ]);

  Widget _action(LoggedAction action) => switch (action) {
    LoggedCommand() => _command(action),
    LoggedSound() => _sound(action),
    LoggedMessage() => _message(action),
    LoggedTeleport() => _teleport(action),
    LoggedConnect() => _connect(action),
    LoggedNavigation() => _navigation(action),
  };

  Widget _message(LoggedMessage message) =>
      dom.div(classes: 'hui-preview-log-action is-message', <Widget>[
        const dom.span(classes: 'hui-preview-log-verb', <Widget>[
          Component.text('message player'),
        ]),
        dom.code(classes: 'hui-preview-log-cmd', <Widget>[
          Component.text(message.message),
        ]),
        if (message.hasStrippedInteractions)
          _badge(
            'interactions stripped',
            'is-unknown',
            'Gloss keeps MiniMessage styling but removes click and insertion '
                'events before sending the message.',
          ),
      ]);

  Widget _teleport(LoggedTeleport teleport) =>
      dom.div(classes: 'hui-preview-log-action is-teleport', <Widget>[
        const dom.span(classes: 'hui-preview-log-verb', <Widget>[
          Component.text('teleport'),
        ]),
        dom.code(classes: 'hui-preview-log-cmd', <Widget>[
          Component.text(
            '${teleport.world} ${_number(teleport.x)} '
            '${_number(teleport.y)} ${_number(teleport.z)}',
          ),
        ]),
        dom.span(classes: 'hui-preview-log-soundmeta', <Widget>[
          Component.text(
            'yaw ${_number(teleport.yaw)} · pitch ${_number(teleport.pitch)}',
          ),
        ]),
      ]);

  Widget _connect(LoggedConnect connect) =>
      dom.div(classes: 'hui-preview-log-action is-connect', <Widget>[
        const dom.span(classes: 'hui-preview-log-verb', <Widget>[
          Component.text('connect'),
        ]),
        dom.code(classes: 'hui-preview-log-cmd', <Widget>[
          Component.text(connect.server),
        ]),
        const dom.span(classes: 'hui-preview-log-dispatch is-player', <Widget>[
          Component.text('via proxy'),
        ]),
      ]);

  Widget _navigation(LoggedNavigation navigation) =>
      dom.div(classes: 'hui-preview-log-action is-navigation', <Widget>[
        const dom.span(classes: 'hui-preview-log-verb', <Widget>[
          Component.text('navigate'),
        ]),
        dom.code(classes: 'hui-preview-log-cmd', <Widget>[
          Component.text(
            navigation.target.isEmpty
                ? navigation.mode
                : '${navigation.mode} ${navigation.target}',
          ),
        ]),
      ]);

  /// A command, with its dispatch spelled out.
  ///
  /// `as console` is emphasised because it is the dispatch that ignores the
  /// clicking player's permissions.
  Widget _command(LoggedCommand command) {
    final bool unknown =
        command.rawSource.isNotEmpty && !command.sourceRecognized;
    return dom.div(
      classes:
          'hui-preview-log-action is-command'
          '${command.asConsole ? ' is-console' : ''}',
      <Widget>[
        const dom.span(classes: 'hui-preview-log-verb', <Widget>[
          Component.text('run'),
        ]),
        dom.code(classes: 'hui-preview-log-cmd', <Widget>[
          Component.text('/${command.command}'),
        ]),
        dom.span(
          classes:
              'hui-preview-log-dispatch'
              '${command.asPlayer ? ' is-player' : ' is-console'}'
              '${unknown ? ' is-uncertain' : ''}',
          attributes: <String, String>{
            'title': command.asPlayer
                ? 'Anything but the exact token "server" dispatches as the '
                      'clicking player, with their own permissions.'
                : 'Dispatched from the server console, so the player\'s own '
                      'permissions never apply.',
          },
          <Widget>[
            Component.text(command.asPlayer ? 'as player' : 'as console'),
          ],
        ),
        if (unknown)
          _badge(
            'source "${command.rawSource}"',
            'is-unknown',
            'Not a spelling Gloss defines. It resolves to null and the command '
                'uses the player default.',
          ),
      ],
    );
  }

  Widget _sound(LoggedSound sound) =>
      dom.div(classes: 'hui-preview-log-action is-sound', <Widget>[
        const dom.span(classes: 'hui-preview-log-verb', <Widget>[
          Component.text('play'),
        ]),
        dom.code(classes: 'hui-preview-log-cmd', <Widget>[
          Component.text(sound.key),
        ]),
        dom.span(classes: 'hui-preview-log-soundmeta', <Widget>[
          Component.text(
            sound.categoryMissing
                ? 'master · volume ${_number(sound.volume)} · '
                      'pitch ${_number(sound.pitch)}'
                : '${sound.category} · volume ${_number(sound.volume)} · '
                      'pitch ${_number(sound.pitch)}',
          ),
        ]),
        if (sound.inaudible)
          _badge(
            'inaudible',
            'is-inaudible',
            'An omitted volume defaults to 1, so a volume of 0 is one the '
                'file wrote itself, and the click is silent.',
          ),
        if (sound.categoryMissing)
          _badge(
            'source defaulted',
            'is-omitted',
            'No category on the action, so the plugin plays it on master.',
          ),
      ]);

  Widget _badge(String text, String modifier, String title) => dom.span(
    classes: 'hui-preview-log-badge $modifier',
    attributes: <String, String>{'title': title},
    <Widget>[Component.text(text)],
  );

  /// Consecutive entries sharing a tick came from one click.
  static List<List<ActionLogEntry>> _groups(List<ActionLogEntry> entries) {
    final List<List<ActionLogEntry>> out = <List<ActionLogEntry>>[];
    for (final ActionLogEntry entry in entries) {
      if (out.isNotEmpty && out.last.first.tick == entry.tick) {
        out.last.add(entry);
      } else {
        out.add(<ActionLogEntry>[entry]);
      }
    }
    return out;
  }

  /// Whole values read as whole numbers; `1.0` in a log row is noise.
  static String _number(double value) =>
      value == value.roundToDouble() && value.isFinite
      ? value.toStringAsFixed(0)
      : value.toString();

  // --- DOM wiring ------------------------------------------------------------

  void _schedulePostFrame() {
    if (_postFramePending || _disposed) return;
    _postFramePending = true;
    context.binding.addPostFrameCallback(() {
      _postFramePending = false;
      if (_disposed) return;
      _sync();
    });
  }

  void _sync() {
    final web.HTMLElement? dock = _element(_dockId);
    if (dock == null) {
      _uninstall?.call();
      _uninstall = null;
      _boundDock = null;
      return;
    }
    if (!identical(_boundDock, dock)) {
      _uninstall?.call();
      _uninstall = _install(dock);
      _boundDock = dock;
    }
    if (_pinned) _scrollToTail();
  }

  void _scrollToTail() {
    final web.HTMLElement? rows = _element(_rowsId);
    if (rows == null) return;
    _setNumber(rows, 'scrollTop', _number0(rows, 'scrollHeight'));
  }

  void Function() _install(web.HTMLElement dock) {
    final web.HTMLElement? splitter = _element(_splitterId);
    if (splitter == null) return () {};

    final List<(web.EventTarget, String, JSFunction, bool)> bound =
        <(web.EventTarget, String, JSFunction, bool)>[];
    void bind(
      web.EventTarget target,
      String type,
      void Function(web.Event event) handler, {
      bool passive = true,
      bool capture = false,
    }) {
      final JSFunction listener = handler.toJS;
      bound.add((target, type, listener, capture));
      target.addEventListener(
        type,
        listener,
        web.AddEventListenerOptions(passive: passive, capture: capture),
      );
    }

    double dockBottom = 0;
    double maxHeight = huiPreviewLogDefaultHeight;
    int pointer = -1;

    void endDrag() {
      if (pointer < 0) return;
      try {
        splitter.releasePointerCapture(pointer);
      } catch (_) {}
      pointer = -1;
      try {
        web.document.body?.classList.remove('hui-resizing-row');
      } catch (_) {}
      final double settled = _number0(dock, 'offsetHeight');
      if (settled > 0 && settled != _heightPx) {
        setState(() => _heightPx = settled);
      }
    }

    bind(splitter, 'pointerdown', (web.Event event) {
      if (!event.isA<web.PointerEvent>()) return;
      final web.PointerEvent typed = event as web.PointerEvent;
      if (typed.button != 0) return;
      event.preventDefault();
      dockBottom = dock.getBoundingClientRect().bottom;
      maxHeight = _maxHeight(dock);
      pointer = typed.pointerId;
      try {
        splitter.setPointerCapture(pointer);
      } catch (_) {}
      try {
        web.document.body?.classList.add('hui-resizing-row');
      } catch (_) {}
      splitter.focus();
    }, passive: false);

    bind(splitter, 'pointermove', (web.Event event) {
      if (pointer < 0 || !event.isA<web.PointerEvent>()) return;
      event.preventDefault();
      // The dock grows upward, so the height is whatever is left between the
      // pointer and the bottom edge the dock is pinned to.
      _writeHeight(
        _clamp(dockBottom - _jsDouble(event as JSObject, 'clientY'), maxHeight),
      );
    }, passive: false);

    bind(splitter, 'pointerup', (web.Event _) => endDrag());
    bind(splitter, 'pointercancel', (web.Event _) => endDrag());

    bind(splitter, 'dblclick', (web.Event event) {
      event.preventDefault();
      _resetHeight();
    }, passive: false);

    bind(splitter, 'keydown', (web.Event event) {
      if (!event.isA<web.KeyboardEvent>()) return;
      final web.KeyboardEvent typed = event as web.KeyboardEvent;
      const List<String> handled = <String>[
        'ArrowUp',
        'ArrowDown',
        'Home',
        'End',
      ];
      if (!handled.contains(typed.key)) return;
      event.preventDefault();
      // The shell's document-level binder turns arrows into a component
      // nudge; a focused separator has to keep them.
      event.stopPropagation();
      final double step = typed.shiftKey
          ? huiPreviewLogKeyStepCoarse
          : huiPreviewLogKeyStep;
      final double max = _maxHeight(dock);
      final double current = _number0(dock, 'offsetHeight');
      final double next = switch (typed.key) {
        'ArrowUp' => current + step,
        'ArrowDown' => current - step,
        'Home' => huiPreviewLogMinHeight,
        _ => max,
      };
      final double clamped = _clamp(next, max);
      _writeHeight(clamped);
      if (clamped != _heightPx) setState(() => _heightPx = clamped);
    }, passive: false);

    // Captured on the dock, not bound to the row scroller: `scroll` does not
    // bubble, but it still runs the capture phase — and the row container is
    // recreated whenever the log crosses between its empty state and its rows,
    // so a listener bound directly to it would silently go stale.
    bind(dock, 'scroll', (web.Event event) {
      final web.HTMLElement? rows = _element(_rowsId);
      if (rows == null) return;
      final double distance =
          _number0(rows, 'scrollHeight') -
          _number0(rows, 'scrollTop') -
          _number0(rows, 'clientHeight');
      final bool pinned = distance <= huiPreviewLogPinSlack;
      if (pinned == _pinned) return;
      setState(() => _pinned = pinned);
    }, capture: true);

    return () {
      for (final (
            web.EventTarget target,
            String type,
            JSFunction listener,
            bool capture,
          )
          in bound) {
        target.removeEventListener(
          type,
          listener,
          web.EventListenerOptions(capture: capture),
        );
      }
      bound.clear();
      try {
        web.document.body?.classList.remove('hui-resizing-row');
      } catch (_) {}
    };
  }

  /// The tallest the dock may be drawn without starving the stage.
  ///
  /// Measured rather than guessed: the toolbar and the readout strip are both
  /// content-sized and wrap, so their combined height is a runtime fact.
  double _maxHeight(web.HTMLElement dock) {
    final web.Element? parent = dock.parentElement;
    if (parent == null) return huiPreviewLogDefaultHeight;
    final double total = parent.getBoundingClientRect().height;
    final double stage = _stageHeight(parent);
    final double dockNow = dock.getBoundingClientRect().height;
    final double chrome = total - stage - dockNow;
    final double room = total - chrome - huiPreviewStageMinHeight;
    return math.max(huiPreviewLogMinHeight, room);
  }

  double _stageHeight(web.Element parent) {
    final web.Element? stage = parent.querySelector('.hui-preview-stage');
    return stage == null ? 0 : stage.getBoundingClientRect().height;
  }

  double _clamp(double raw, double max) {
    if (!raw.isFinite) return huiPreviewLogDefaultHeight;
    return math.min(
      math.max(raw, huiPreviewLogMinHeight),
      math.max(max, huiPreviewLogMinHeight),
    );
  }

  /// An inline custom property on `<html>`: Jaspr renders nothing above `<body>`
  /// so no rebuild can stomp it, which is what lets a drag skip `setState`.
  void _writeHeight(double px) {
    try {
      (web.document.documentElement as web.HTMLElement?)?.style.setProperty(
        huiPreviewLogHeightVar,
        '${px.round()}px',
      );
    } catch (_) {}
    try {
      _element(_splitterId)
        ?..setAttribute('aria-valuenow', px.round().toString())
        ..setAttribute('aria-valuetext', '${px.round()} pixels tall');
    } catch (_) {}
  }

  void _resetHeight() {
    try {
      (web.document.documentElement as web.HTMLElement?)?.style.removeProperty(
        huiPreviewLogHeightVar,
      );
    } catch (_) {}
    if (_heightPx != huiPreviewLogDefaultHeight) {
      setState(() => _heightPx = huiPreviewLogDefaultHeight);
    }
  }

  web.HTMLElement? _element(String id) =>
      web.document.getElementById(id) as web.HTMLElement?;

  /// `scrollTop`, `scrollHeight` and `clientY` are all declared `int` or `num`
  /// somewhere in the stack while really returning fractions on fractional-DPI
  /// displays; reading them through the typed getter throws under dart2js.
  static double _jsDouble(JSObject owner, String property) {
    final JSAny? value = owner.getProperty<JSAny?>(property.toJS);
    if (value == null || !value.isA<JSNumber>()) return 0;
    return (value as JSNumber).toDartDouble;
  }

  static double _number0(web.Element element, String property) =>
      _jsDouble(element as JSObject, property);

  static void _setNumber(web.Element element, String property, double value) =>
      (element as JSObject).setProperty(property.toJS, value.toJS);
}

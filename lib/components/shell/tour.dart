/// The first-run guided tour: a spotlight over one shell region at a time.
///
/// The spotlight is four dimming rectangles around the target rather than one
/// scrim with a hole. A `box-shadow` cut-out would have been fewer nodes, but
/// pointer events do not hit a shadow, so that shape cannot block clicks
/// anywhere — the four-rect form blocks everything outside the highlight while
/// leaving the highlighted region genuinely usable.
///
/// Targets are resolved by selector at measure time, and every step lists
/// fallbacks. Nothing here reaches into another module's markup by structure:
/// `.hui-rail`, `.hui-center` and `.hui-inspector` are written by
/// `editor_shell.dart` itself, and the other two are class hooks the shell
/// mounts. A step whose target is missing at this viewport width still shows
/// its card, centred, rather than breaking the run.
///
/// The seen flag lives under `gloss.tour.v1` in the workspace's storage, not
/// in the store: it is a property of this browser, never of the document, and
/// it must not ride along in an export or an undo step.
library;

import 'dart:js_interop';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:web/web.dart' as web;

/// Storage key for "this browser has been shown the tour".
const String huiTourSeenKey = 'gloss.tour.v1';

class HuiTourStep {
  const HuiTourStep({
    required this.title,
    required this.body,
    required this.selectors,
    this.hint,
  });

  final String title;
  final String body;

  /// Tried in order; the first that measures a real box wins.
  final List<String> selectors;

  /// One extra line, set smaller — the sharp edge of the region.
  final String? hint;
}

/// The steps follow the order a menu is actually built — pick a component,
/// place it, tune it, check it, then find everything else — behind the one
/// piece of navigation that frames all of it: the kind the workspace is
/// showing.
const List<HuiTourStep> huiTourSteps = <HuiTourStep>[
  HuiTourStep(
    title: 'Choose the document kind',
    body:
        'The kind strip or picker scopes the library to one document type — '
        'menus, scoreboards, holograms, tab lists — and points New document '
        'at it. All keeps the whole workspace in view.',
    selectors: <String>[
      '.hui-kind-tabs',
      '.hui-kind-picker',
      '.hui-bar-center',
    ],
    hint: 'Opening a document from search or the palette moves the tab to it.',
  ),
  HuiTourStep(
    title: 'Components live in the rail',
    body:
        'Add a button, toggle or decoration from the split button at the '
        'top, then pick a row to select it. Right-click a row — or use its ⋮ '
        'button — for duplicate, restack and delete.',
    selectors: <String>['.hui-rail', '.hui-mobile-panes'],
    hint:
        'The nearest overlapping hitbox fires. Rail order breaks an exact '
        'distance tie.',
  ),
  HuiTourStep(
    title: 'The artboard places them',
    body:
        'Drag a component to move it. On touch, drag empty canvas to pan. '
        'With a mouse, drag empty space to marquee-select, hold Shift to add, '
        'and Space-drag or middle-drag to pan. Scroll zooms.',
    selectors: <String>['.hui-center', '.hui-canvas'],
    hint:
        'X is mirrored against the JSON on purpose — the runtime negates it, '
        'so the artboard shows what the player sees.',
  ),
  HuiTourStep(
    title: 'The inspector tunes them',
    body:
        'Everything about the selection is edited here: id, offset, icon, '
        'actions and any extra keys the file carried. The ? button beside a '
        'field explains what Gloss does with it.',
    selectors: <String>['.hui-inspector', '.hui-mobile-panes'],
  ),
  HuiTourStep(
    title: 'Four modes, whatever is open',
    body:
        'Visual is the document\'s own editing surface, Preview renders it '
        'the way the server does, Code is its JSON, and Split shows both. A '
        'mode a document cannot serve says why instead of disappearing.',
    selectors: <String>[
      '.hui-view-switcher',
      '.hui-bar-view-picker',
      '.hui-bar-views',
    ],
    hint:
        'For a menu, Preview runs hover push, click dispatch and the distance '
        'close, logging every command and sound instead of firing it.',
  ),
  HuiTourStep(
    title: 'Export puts it on the server',
    body:
        'This page never writes your Minecraft server. Download the JSON, '
        'drop it into plugins/Gloss/menus/, then /gloss menu open <id>. Live '
        'sync only exists when /gloss menu edit <id> gave you a capability link.',
    selectors: <String>['.hui-bar'],
    hint:
        'File → Export, or the command palette. Images unzip into plugins/Gloss/images/.',
  ),
  HuiTourStep(
    title: 'Everything else is one keystroke away',
    body:
        'The command palette in the Editor cluster runs any command by name, '
        'including this tour. Press ? at any time for the full shortcut sheet.',
    selectors: <String>['.hui-bar'],
  ),
];

/// A viewport-space rectangle. Plain doubles so `build` stays free of interop.
class _Box {
  const _Box(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
}

/// Card geometry, mirrored in `.hui-tour-card`. Placement needs the numbers in
/// Dart; the stylesheet needs them for the box. They are the same numbers.
const double _cardWidth = 340;
const double _cardHeight = 232;
const double _gap = 12;
const double _edge = 16;
const double _spotPad = 6;

class HuiTour extends StatefulWidget {
  const HuiTour({
    required this.onFinish,
    required this.onSkip,
    required this.onNever,
    this.leaving = false,
    super.key,
  });

  /// Ran through the last step. Marks the tour seen.
  final void Function() onFinish;

  /// Dismissed for now. Deliberately does NOT mark it seen, so a reload brings
  /// it back — "not now" and "never" are different answers.
  final void Function() onSkip;

  /// Never again. Marks it seen.
  final void Function() onNever;

  /// The caller has started the dismissal and unmounts after the exit
  /// animation.
  final bool leaving;

  @override
  State<HuiTour> createState() => _HuiTourState();
}

class _HuiTourState extends State<HuiTour> {
  int _step = 0;
  _Box? _target;
  double _viewWidth = 0;
  double _viewHeight = 0;
  JSFunction? _resizeListener;

  @override
  void initState() {
    super.initState();
    final JSFunction listener = ((web.Event _) => _measure()).toJS;
    _resizeListener = listener;
    web.window.addEventListener('resize', listener);
    // The shell's pane widths are custom properties written before the first
    // paint, but the panes have no box until the browser has laid the grid out
    // once. Measuring in this turn returns zeros for all five targets.
    web.window.requestAnimationFrame(((double _) => _measure()).toJS);
  }

  @override
  void dispose() {
    final JSFunction? listener = _resizeListener;
    if (listener != null) web.window.removeEventListener('resize', listener);
    _resizeListener = null;
    super.dispose();
  }

  void _measure() {
    if (!mounted) return;
    final double width = web.window.innerWidth.toDouble();
    final double height = web.window.innerHeight.toDouble();
    _Box? found;
    for (final String selector in huiTourSteps[_step].selectors) {
      final web.Element? element = _query(selector);
      if (element == null) continue;
      final web.DOMRect rect = element.getBoundingClientRect();
      if (rect.width < 1 || rect.height < 1) continue;
      if (rect.right <= 0 ||
          rect.left >= width ||
          rect.bottom <= 0 ||
          rect.top >= height) {
        continue;
      }
      found = _Box(rect.left, rect.top, rect.width, rect.height);
      break;
    }
    setState(() {
      _target = found;
      _viewWidth = width;
      _viewHeight = height;
    });
  }

  web.Element? _query(String selector) {
    try {
      return web.document.querySelector(selector);
    } catch (_) {
      return null;
    }
  }

  void _goto(int step) {
    if (step < 0 || step >= huiTourSteps.length) return;
    setState(() => _step = step);
    _measure();
  }

  @override
  Widget build(BuildContext context) {
    final HuiTourStep step = huiTourSteps[_step];
    final _Box? spot = _padded(_target);
    final bool last = _step == huiTourSteps.length - 1;
    // `display: contents` in the stylesheet: `.hui-shell` is a three-row grid
    // and an in-flow wrapper here would add a fourth implicit row. The card
    // carries the accessible name; a landmark role on a contents box is not
    // reliably kept in the accessibility tree.
    return dom.div(classes: 'hui-tour', <Widget>[
      ..._dimming(spot),
      if (spot != null)
        dom.div(
          // Keyed on the step so the ring's entrance replays as it moves.
          key: ValueKey<String>('ring-$_step'),
          classes: 'hui-tour-ring',
          styles: dom.Styles(
            raw: <String, String>{
              'left': '${spot.left}px',
              'top': '${spot.top}px',
              'width': '${spot.width}px',
              'height': '${spot.height}px',
            },
          ),
          attributes: const <String, String>{'aria-hidden': 'true'},
          const <Widget>[],
        ),
      _card(step, spot, last),
    ]);
  }

  _Box? _padded(_Box? box) {
    if (box == null) return null;
    final double left = _clamp(box.left - _spotPad, 0, _viewWidth);
    final double top = _clamp(box.top - _spotPad, 0, _viewHeight);
    final double right = _clamp(box.right + _spotPad, 0, _viewWidth);
    final double bottom = _clamp(box.bottom + _spotPad, 0, _viewHeight);
    return _Box(left, top, right - left, bottom - top);
  }

  /// Four rectangles rather than one scrim: they block every click outside the
  /// highlight while leaving the highlight itself live.
  List<Widget> _dimming(_Box? spot) {
    if (spot == null) {
      return <Widget>[
        _dim(const <String, String>{'inset': '0'}),
      ];
    }
    return <Widget>[
      _dim(<String, String>{
        'left': '0',
        'right': '0',
        'top': '0',
        'height': '${spot.top}px',
      }),
      _dim(<String, String>{
        'left': '0',
        'right': '0',
        'top': '${spot.bottom}px',
        'bottom': '0',
      }),
      _dim(<String, String>{
        'left': '0',
        'top': '${spot.top}px',
        'width': '${spot.left}px',
        'height': '${spot.height}px',
      }),
      _dim(<String, String>{
        'left': '${spot.right}px',
        'right': '0',
        'top': '${spot.top}px',
        'height': '${spot.height}px',
      }),
    ];
  }

  /// Clicking the dimmed area is a dismissal, not a trap: the tour is
  /// onboarding, and an overlay you cannot get out of by clicking away is the
  /// worst thing onboarding can be.
  Widget _dim(Map<String, String> rect) => dom.div(
    classes: component.leaving
        ? 'hui-tour-dim hui-anim-fade-out'
        : 'hui-tour-dim',
    styles: dom.Styles(raw: rect),
    events: dom.events<Null>(onClick: component.onSkip),
    const <Widget>[],
  );

  Widget _card(HuiTourStep step, _Box? spot, bool last) {
    final (double left, double top) = _place(spot);
    return dom.div(
      // Same reason as the ring: a fresh element per step replays the arrival,
      // which is the only signal that the card moved rather than just changed
      // its text.
      key: ValueKey<String>('card-$_step'),
      classes: component.leaving
          ? 'hui-tour-card hui-anim-out'
          : 'hui-tour-card',
      styles: dom.Styles(
        raw: <String, String>{'left': '${left}px', 'top': '${top}px'},
      ),
      attributes: <String, String>{'role': 'dialog', 'aria-label': step.title},
      <Widget>[
        dom.div(classes: 'hui-tour-eyebrow', <Widget>[
          Text('Step ${_step + 1} of ${huiTourSteps.length}'),
        ]),
        dom.h2(classes: 'hui-tour-title', <Widget>[Text(step.title)]),
        dom.p(classes: 'hui-tour-body', <Widget>[Text(step.body)]),
        if (step.hint != null)
          dom.p(classes: 'hui-tour-hint', <Widget>[Text(step.hint!)]),
        dom.div(classes: 'hui-tour-actions', <Widget>[
          Button(
            variant: ButtonVariant.ghost,
            size: ButtonSize.small,
            onPressed: component.onNever,
            label: "Don't show again",
            attributes: const <String, String>{
              'aria-label': 'Never show the guided tour again',
            },
          ),
          const dom.span(classes: 'hui-tour-spacer', <Widget>[]),
          Button(
            variant: ButtonVariant.ghost,
            size: ButtonSize.small,
            onPressed: component.onSkip,
            label: 'Skip',
            attributes: const <String, String>{
              'aria-label': 'Close the tour for now',
            },
          ),
          if (_step > 0)
            Button(
              variant: ButtonVariant.outline,
              size: ButtonSize.small,
              onPressed: () => _goto(_step - 1),
              label: 'Back',
            ),
          Button(
            // Arcane renders a Button's attributes one build behind (C15);
            // keying it on the step keeps the label and its aria-label from
            // reporting the previous step.
            key: ValueKey<int>(_step),
            variant: ButtonVariant.primary,
            size: ButtonSize.small,
            onPressed: last ? component.onFinish : () => _goto(_step + 1),
            label: last ? 'Done' : 'Next',
            attributes: <String, String>{
              'aria-label': last
                  ? 'Finish the tour'
                  : 'Go to step ${_step + 2} of ${huiTourSteps.length}',
            },
          ),
        ]),
      ],
    );
  }

  /// Below the target, else above, else beside it, else centred inside it.
  /// The side arms are what make the rail and the inspector work: both are
  /// full-height, so neither has room above or below.
  (double, double) _place(_Box? spot) {
    if (spot == null || _viewWidth == 0) {
      return (
        _clamp((_viewWidth - _cardWidth) / 2, _edge, _maxLeft),
        _clamp((_viewHeight - _cardHeight) / 2, _edge, _maxTop),
      );
    }
    final double alignedLeft = spot.width > _cardWidth
        ? spot.left + (spot.width - _cardWidth) / 2
        : spot.left;
    if (spot.bottom + _gap + _cardHeight <= _viewHeight - _edge) {
      return (_clamp(alignedLeft, _edge, _maxLeft), spot.bottom + _gap);
    }
    if (spot.top - _gap - _cardHeight >= _edge) {
      return (
        _clamp(alignedLeft, _edge, _maxLeft),
        spot.top - _gap - _cardHeight,
      );
    }
    final double centredTop = _clamp(
      spot.top + (spot.height - _cardHeight) / 2,
      _edge,
      _maxTop,
    );
    if (spot.right + _gap + _cardWidth <= _viewWidth - _edge) {
      return (spot.right + _gap, centredTop);
    }
    if (spot.left - _gap - _cardWidth >= _edge) {
      return (spot.left - _gap - _cardWidth, centredTop);
    }
    // Nothing fits beside it, which means the target is most of the viewport.
    // Sitting inside the highlight reads as belonging to it.
    return (
      _clamp(spot.left + (spot.width - _cardWidth) / 2, _edge, _maxLeft),
      centredTop,
    );
  }

  double get _maxLeft {
    final double max = _viewWidth - _cardWidth - _edge;
    return max < _edge ? _edge : max;
  }

  double get _maxTop {
    final double max = _viewHeight - _cardHeight - _edge;
    return max < _edge ? _edge : max;
  }
}

/// `num.clamp` widens to `num`; every coordinate here stays a double.
double _clamp(double value, double low, double high) {
  if (!value.isFinite) return low;
  if (value < low) return low;
  return value > high ? high : value;
}

/// The top bar's hand-built dropdown menu.
///
/// `ArcaneDropdownMenu` never opens in this arcane_jaspr build: its open state
/// lives entirely in the injected JS runtime and nothing there flips it.
/// Measured on the shipped bar — clicking the document switcher left
/// `[data-arcane-id="hui-doc-menu"]` at `data-arcane-state="closed"` and
/// `hidden`, so "New menu" and "Delete this document" were unreachable and a
/// second document could not be created at all. Same for the overflow menu,
/// which is the only route to Templates, the palette and Settings once the bar
/// is too narrow to show them.
///
/// The shape is the one the rail's row menu and the preview's overlays menu
/// already use: Dart owns the open flag, an outside-click layer is rendered by
/// the same condition so it cannot outlive the menu, Escape closes, and focus
/// moves to the menu on open and back to the trigger on close — without that
/// last part Escape never arrives, because Arcane's button-feedback script
/// `preventDefault`s mousedown and leaves focus on `body`.
library;

import 'dart:async' show Timer;
import 'dart:js_interop';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:arcane_jaspr/core/dom_value.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show EventCallback;
import 'package:web/web.dart' as web;

import 'bar_menu_navigation.dart';

/// One row of a [BarMenu].
sealed class BarMenuEntry {
  const BarMenuEntry();
}

/// A non-interactive group heading.
class BarMenuHeading extends BarMenuEntry {
  const BarMenuHeading(this.label);

  final String label;
}

class BarMenuSeparator extends BarMenuEntry {
  const BarMenuSeparator();
}

/// A row that does something. A null [onSelect] renders it disabled.
class BarMenuAction extends BarMenuEntry {
  const BarMenuAction({
    required this.label,
    this.icon,
    this.onSelect,
    this.destructive = false,
    this.attributes = const <String, String>{},
  });

  final String label;
  final Widget? icon;
  final void Function()? onSelect;
  final bool destructive;
  final Map<String, String> attributes;
}

enum BarMenuAlign { left, right }

class BarMenu extends StatefulWidget {
  const BarMenu({
    required this.id,
    required this.triggerIcon,
    required this.triggerLabel,
    required this.entries,
    this.triggerText,
    this.triggerTrailing,
    this.align = BarMenuAlign.left,
    this.width = 240,
    super.key,
  });

  /// Also the DOM id of the menu; the trigger takes `$id-trigger`.
  final String id;
  final Widget triggerIcon;

  /// Visible text beside [triggerIcon]. Null keeps the trigger a square icon
  /// button; a value turns it into a labelled one, which is what the narrow
  /// bar's kind picker needs — a picker whose current value is invisible is a
  /// worse control than the tab strip it replaces.
  final String? triggerText;

  /// Drawn after the label. A chevron here is the only thing that says the
  /// control opens rather than acts.
  final Widget? triggerTrailing;

  /// Accessible name of the trigger. Never contains a capital-M "Menu": the
  /// mobile-menu binder claims `[aria-label*="Menu"]`
  /// (`mobile_menu_scripts.dart:7`) and would hijack the click.
  final String triggerLabel;

  /// Rebuilt on every open so rows reflect current state.
  final List<BarMenuEntry> Function() entries;

  final BarMenuAlign align;
  final int width;

  @override
  State<BarMenu> createState() => _BarMenuState();
}

class _BarMenuState extends State<BarMenu> {
  bool _open = false;

  String get _triggerId => '${component.id}-trigger';

  void _setOpen(bool open, {bool restoreFocus = true}) {
    if (_open == open) return;
    setState(() => _open = open);
    context.binding.addPostFrameCallback(() {
      if (!mounted) return;
      if (open) {
        _focusInitialItem();
      } else if (restoreFocus) {
        _focusElement(_triggerId);
      }
    });
  }

  void _focusElement(String elementId) {
    final web.Element? element = web.document.getElementById(elementId);
    if (element == null || !element.isA<web.HTMLElement>()) return;
    (element as web.HTMLElement).focus(web.FocusOptions(preventScroll: true));
  }

  void _focusInitialItem() {
    final web.Element? menu = web.document.getElementById(component.id);
    if (menu == null) return;
    final web.Element? preferred = menu.querySelector(
      '.hui-bar-menu-item[data-hui-menu-initial="true"]:not(:disabled)',
    );
    final web.Element? first = menu.querySelector(
      '.hui-bar-menu-item:not(:disabled)',
    );
    final web.Element target = preferred ?? first ?? menu;
    if (!target.isA<web.HTMLElement>()) return;
    final web.HTMLElement focusable = target as web.HTMLElement;
    focusable.focus(web.FocusOptions(preventScroll: true));
    focusable.scrollIntoView(
      web.ScrollIntoViewOptions(block: 'nearest', inline: 'nearest'),
    );
  }

  void _moveFocus(String key) {
    final web.Element? menu = web.document.getElementById(component.id);
    if (menu == null) return;
    final web.NodeList items = menu.querySelectorAll(
      '.hui-bar-menu-item:not(:disabled)',
    );
    final web.Element? active = web.document.activeElement;
    int current = -1;
    for (int index = 0; index < items.length; index += 1) {
      if (identical(items.item(index), active)) {
        current = index;
        break;
      }
    }
    final int target = huiBarMenuTargetIndex(
      current: current,
      count: items.length,
      key: key,
    );
    if (target < 0) return;
    (items.item(target) as web.HTMLElement?)?.focus();
  }

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-bar-menu',
    styles: const dom.Styles(
      raw: <String, String>{'position': 'relative', 'display': 'inline-flex'},
    ),
    // Escape is caught on the wrapper rather than the menu: closing returns
    // focus to the trigger, which is a sibling of the menu, so a handler
    // bound to the menu alone would miss the key on the way back.
    events: _open
        ? <String, EventCallback>{
            'keydown': (Object event) {
              final String key = domEventKey(event);
              if (key == 'Escape') {
                domPreventDefault(event);
                domStopPropagation(event);
                _setOpen(false);
                return;
              }
              if (key == 'Tab') {
                Timer.run(() {
                  if (mounted && _open) {
                    _setOpen(false, restoreFocus: false);
                  }
                });
                return;
              }
              if (key != 'ArrowDown' &&
                  key != 'ArrowUp' &&
                  key != 'Home' &&
                  key != 'End') {
                return;
              }
              domPreventDefault(event);
              domStopPropagation(event);
              _moveFocus(key);
            },
          }
        : null,
    <Widget>[
      Button.ghost(
        // Keyed on the state it reports: Arcane's Button renders its
        // `attributes` one build behind, so an unkeyed `aria-expanded` is
        // always the previous value.
        key: ValueKey<bool>(_open),
        id: _triggerId,
        // A square icon slot cannot hold a label or a chevron beside the icon,
        // so anything past the bare icon takes the regular small button box.
        size: component.triggerText == null && component.triggerTrailing == null
            ? ButtonSize.iconSm
            : ButtonSize.sm,
        icon: component.triggerIcon,
        // A `label` renders as a bare text node with nothing to hang a class
        // on; the narrowest phone rung needs to drop this text and keep the
        // icon, so it goes through `child` and carries its own hook.
        child: component.triggerText == null
            ? null
            : dom.span(classes: 'hui-picker-label', <Widget>[
                Text(component.triggerText!),
              ]),
        trailing: component.triggerTrailing,
        attributes: <String, String>{
          'aria-haspopup': 'menu',
          'aria-expanded': _open ? 'true' : 'false',
          'aria-controls': component.id,
          'aria-label': component.triggerLabel,
          // The legacy accordion binder claims every `button[aria-expanded]`
          // in a one-shot scan and writes `display` onto the next sibling.
          // This is its own opt-out (`accordion_scripts.dart:8`).
          'data-arcane-interactive': 'true',
        },
        onPressed: () => _setOpen(!_open),
      ),
      if (_open) ..._menu(),
    ],
  );

  List<Widget> _menu() => <Widget>[
    dom.div(
      styles: const dom.Styles(
        raw: <String, String>{
          'position': 'fixed',
          'inset': '0',
          'z-index': '60',
        },
      ),
      attributes: const <String, String>{'aria-hidden': 'true'},
      events: <String, EventCallback>{
        // Dismissing by clicking away leaves focus alone: the pointer has
        // already moved on.
        'pointerdown': (Object _) => _setOpen(false, restoreFocus: false),
      },
      const <Widget>[],
    ),
    dom.div(
      id: component.id,
      classes: 'hui-bar-menu-panel hui-anim-in',
      styles: dom.Styles(
        raw: <String, String>{
          'position': 'absolute',
          'z-index': '61',
          'top': 'calc(100% + 4px)',
          if (component.align == BarMenuAlign.left)
            'left': '0'
          else
            'right': '0',
          'min-width': '${component.width}px',
          'display': 'flex',
          'flex-direction': 'column',
          'gap': '1px',
          'padding': '5px',
          'border': '1px solid var(--hui-border)',
          'border-radius': 'var(--hui-radius)',
          'background': 'var(--hui-surface-raised)',
          'box-shadow': 'var(--hui-shadow-md)',
        },
      ),
      attributes: <String, String>{
        'role': 'menu',
        'aria-label': component.triggerLabel,
        // Focused on open so the Escape handler is reachable; never in the
        // Tab order, which is what -1 buys over 0.
        'tabindex': '-1',
      },
      <Widget>[
        for (final BarMenuEntry entry in component.entries()) _row(entry),
      ],
    ),
  ];

  Widget _row(BarMenuEntry entry) => switch (entry) {
    BarMenuHeading(label: final String label) => dom.div(
      styles: const dom.Styles(
        raw: <String, String>{
          'padding': '5px 8px 3px',
          'color': 'var(--hui-muted)',
          'font-size': '0.66rem',
          'font-weight': '680',
          'letter-spacing': '0.09em',
          'text-transform': 'uppercase',
        },
      ),
      <Widget>[Text(label)],
    ),
    BarMenuSeparator() => const dom.div(
      styles: dom.Styles(
        raw: <String, String>{
          'height': '1px',
          'margin': '4px 2px',
          'background': 'var(--hui-border-soft)',
        },
      ),
      attributes: <String, String>{'role': 'separator'},
      <Widget>[],
    ),
    BarMenuAction(
      label: final String label,
      icon: final Widget? icon,
      onSelect: final void Function()? onSelect,
      destructive: final bool destructive,
      attributes: final Map<String, String> attributes,
    ) =>
      _action(label, icon, onSelect, destructive, attributes),
  };

  Widget _action(
    String label,
    Widget? icon,
    void Function()? onSelect,
    bool destructive,
    Map<String, String> attributes,
  ) {
    final bool disabled = onSelect == null;
    return dom.button(
      classes: 'hui-bar-menu-item',
      styles: dom.Styles(
        raw: <String, String>{
          'display': 'flex',
          'align-items': 'center',
          'gap': '8px',
          'width': '100%',
          'padding': '6px 8px',
          'border': '0',
          'border-radius': '0',
          'background': 'transparent',
          'color': destructive ? 'var(--hui-danger)' : 'var(--hui-text)',
          'font': 'inherit',
          'font-size': '0.8rem',
          'text-align': 'start',
          'cursor': disabled ? 'default' : 'pointer',
          'opacity': disabled ? '0.45' : '1',
        },
      ),
      attributes: <String, String>{
        'type': 'button',
        ...attributes,
        'role': attributes['role'] ?? 'menuitem',
        'tabindex': '-1',
        if (disabled) 'disabled': '',
        if (disabled) 'aria-disabled': 'true',
      },
      events: <String, EventCallback>{
        'click': (Object _) {
          if (disabled) return;
          // Close first, act second: a store mutation notifies synchronously
          // and would rebuild this subtree mid-frame.
          _setOpen(false);
          onSelect();
        },
      },
      <Widget>[
        dom.span(
          styles: const dom.Styles(
            raw: <String, String>{
              'flex': '0 0 auto',
              'display': 'inline-flex',
              'width': '18px',
              'justify-content': 'center',
            },
          ),
          attributes: const <String, String>{'aria-hidden': 'true'},
          <Widget>[?icon],
        ),
        dom.span(
          styles: const dom.Styles(raw: <String, String>{'flex': '1 1 auto'}),
          <Widget>[Text(label)],
        ),
      ],
    );
  }
}

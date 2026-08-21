/// Left rail: the ordered component list.
///
/// Order is serialized menu order and breaks exact-distance click ties in-game.
/// Reordering is a document edit, not a view preference, so every move goes
/// through the store and lands in the undo stack.
///
/// The rail is also the non-canvas face of the selection: rows carry set
/// membership, and shift-click toggles it, so a multi-selection can be built
/// and read without touching the artboard.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:arcane_jaspr/core/dom_value.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show ListenableBuilder;
import 'package:web/web.dart' as web;

import '../../config/defaults.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../services/catalogs.dart';
import '../../services/showcase_randomizer.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'drag_data.dart';
import 'preview_elements_rail.dart';

class ComponentsRail extends StatefulWidget {
  const ComponentsRail({required this.store, super.key});

  final EditorStore store;

  @override
  State<ComponentsRail> createState() => _ComponentsRailState();
}

class _ComponentsRailState extends State<ComponentsRail> {
  /// Two-step delete: the first press arms the row, the check runs it.
  String? _armedDeleteId;
  String? _renameId;
  String _renameDraft = '';

  /// The row whose action menu is open; at most one at a time.
  String? _menuRowId;

  /// Element id of the tools button that opened [_menuRowId], so closing can
  /// put focus back where the user left it.
  String? _menuTriggerId;
  HuiActionMenuPoint _menuPoint = const HuiActionMenuPoint(8, 8);
  String? _dragId;
  int _dropIndex = -1;
  bool _typesOpen = false;

  /// The catalogs the store held when this rail mounted.
  ///
  /// `HuiCatalogs.loaded` is false both before the fetch and after it fails, so
  /// it cannot tell "still loading" from "gave up" on its own. The instance
  /// can: `EditorStore.setCatalogs` swaps in a new one exactly once, whichever
  /// way the fetch went.
  late final HuiCatalogs _bootCatalogs;

  EditorStore get _store => component.store;

  @override
  void initState() {
    super.initState();
    _bootCatalogs = _store.catalogs;
  }

  bool get _catalogsPending =>
      identical(_store.catalogs, _bootCatalogs) && !_store.catalogs.loaded;

  /// Moves focus to [elementId] once the frame that renders it has been built.
  ///
  /// Focus is the mechanism here, not a courtesy. Arcane's button-feedback
  /// script calls `preventDefault` on mousedown, so clicking a trigger leaves
  /// focus on `body` — and both popups below listen for Escape inside their own
  /// subtree, which a body-level keydown never enters. Measured before this
  /// landed: Escape left the row menu open (its scrim went on swallowing every
  /// click) and left all three type buttons on screen.
  void _focusAfterFrame(String elementId) {
    context.binding.addPostFrameCallback(() {
      (web.document.getElementById(elementId) as web.HTMLElement?)?.focus();
    });
  }

  void _setTypesOpen(bool open) {
    if (_typesOpen == open) return;
    setState(() => _typesOpen = open);
    _focusAfterFrame(open ? _typesPanelId : _typesTriggerId);
  }

  /// Opens the action menu for [rowId], or closes it when [rowId] is null.
  ///
  /// [triggerId] is the tools button focus returns to on close. It is keyed on
  /// the row's index, so after a reorder focus lands on the same slot rather
  /// than following the component — which is the list convention and keeps
  /// focus inside the rail either way.
  void _setMenuRow(
    String? rowId,
    String? triggerId, {
    HuiActionMenuPoint? point,
  }) {
    final String? previous = _menuTriggerId;
    setState(() {
      _menuRowId = rowId;
      _menuTriggerId = rowId == null ? null : triggerId;
      if (point != null) _menuPoint = point;
      _armedDeleteId = null;
    });
    if (rowId != null) {
      _focusAfterFrame(_rowMenuId);
    } else if (previous != null) {
      _focusAfterFrame(previous);
    }
  }

  /// Closes the row menu without moving focus.
  void _dismissMenu() => setState(() {
    _menuRowId = null;
    _menuTriggerId = null;
  });

  /// Plain click replaces the selection; shift or Ctrl/Cmd toggles membership.
  ///
  /// The canvas deliberately keeps the group when a member is clicked plainly —
  /// the click is the start of a group drag. A rail row has no such gesture
  /// (dragging one reorders that component alone), so here the list convention
  /// wins and a plain click always collapses to the row that was clicked. It is
  /// also the only way back to a single selection without reaching for Escape.
  void _click(Object? event, String id) {
    if (_multiSelectModifier(event)) {
      _store.toggleInSelection(id);
    } else {
      _store.select(id);
    }
    if (_armedDeleteId != null || _menuRowId != null) {
      setState(() {
        _armedDeleteId = null;
        _menuRowId = null;
        _menuTriggerId = null;
      });
    }
  }

  void _add(String type) {
    _store.addComponent(type);
    setState(() {
      _armedDeleteId = null;
      _menuRowId = null;
      _menuTriggerId = null;
      _typesOpen = false;
    });
  }

  void _delete(String id) {
    setState(() => _armedDeleteId = null);
    _store.deleteComponent(id);
  }

  /// True when the click asked to extend the selection rather than replace it.
  ///
  /// Shift is the documented gesture; Ctrl and Cmd come along because every
  /// list in every other editor accepts them and costs nothing here.
  bool _multiSelectModifier(Object? event) {
    try {
      final web.MouseEvent mouse = event! as web.MouseEvent;
      return mouse.shiftKey || mouse.ctrlKey || mouse.metaKey;
    } catch (_) {
      // Not a mouse event (keyboard activation of the row button): a plain
      // Enter selects, which is the right default.
      return false;
    }
  }

  void _move(String id, int newIndex) {
    _store.reorder(id, newIndex);
    setState(() {
      _dragId = null;
      _dropIndex = -1;
      _menuRowId = null;
      _menuTriggerId = null;
    });
  }

  void _dropOn(int index) {
    final String? dragged = _dragId;
    setState(() {
      _dragId = null;
      _dropIndex = -1;
      _menuRowId = null;
      _menuTriggerId = null;
    });
    if (dragged == null) return;
    _store.reorder(dragged, index);
  }

  // The shell already renders the scrolling `<aside class="hui-pane hui-rail">`
  // cell around this slot with its own `aria-label`, so the rail root is a
  // plain filler div: no second landmark, no second border, no second scroller.
  //
  // A container-preview document delegates whole to [PreviewElementsRail]:
  // elements have no id, no drag reorder and no right-click menu, so sharing
  // this state class's id-keyed bookkeeping would only be friction.
  @override
  Widget build(BuildContext context) =>
      dom.div(classes: 'hui-rail-pane', <Widget>[
        ListenableBuilder(
          listenable: _store,
          builder: (BuildContext inner) => _store.isPreviewDoc
              ? PreviewElementsRail(store: _store)
              : _body(),
        ),
      ]);

  Widget _body() {
    final List<HuiComponent> components = _store.components;
    final int selected = _store.selectionIds.length;
    return dom.div(classes: 'hui-rail-inner', <Widget>[
      _header(components.length),
      if (_typesOpen) _typeChooser(),
      if (components.isEmpty)
        // Nothing authored yet AND nothing fetched yet is the one moment the
        // rail genuinely has nothing to say. Skeleton rows read as "loading";
        // the empty state reads as "there is nothing here", and showing that
        // first would be a lie the boot sequence corrects a moment later.
        _catalogsPending ? _skeleton() : _empty()
      else ...<Widget>[
        if (components.length > 1) _hintLine(selected, components.length),
        dom.div(
          classes: 'hui-rail-list',
          attributes: const <String, String>{'role': 'list'},
          <Widget>[
            for (int i = 0; i < components.length; i++)
              _row(i, components[i], components.length),
          ],
        ),
      ],
    ]);
  }

  /// Three placeholder rows at the height of a real one. Sized inline: the rail
  /// stylesheet is not this task's to extend, and a skeleton that lands one
  /// build ahead of its CSS is worse than no skeleton.
  Widget _skeleton() => dom.div(
    classes: 'hui-rail-list',
    attributes: const <String, String>{
      'aria-busy': 'true',
      'aria-label': 'Loading',
    },
    <Widget>[
      for (int i = 0; i < 3; i++)
        dom.div(
          classes: 'hui-rail-row',
          styles: dom.Styles(
            raw: <String, String>{
              'height': '38px',
              'opacity': (0.5 - i * 0.13).toStringAsFixed(2),
              'background': 'var(--hui-panel-soft)',
              'pointer-events': 'none',
            },
          ),
          const <Widget>[],
        ),
    ],
  );

  /// Heading, count and the add split-button share one line: the rail is
  /// 240-280px wide and every line spent here is a component row lost.
  Widget _header(int count) => dom.div(classes: 'hui-rail-header', <Widget>[
    dom.div(classes: 'hui-rail-heading', <Widget>[
      const HuiEyebrow('Components'),
      // Plain text, not an aria-label: "Components 14" already reads
      // correctly and a labelled <span> has no role to carry a name.
      // The selection count is NOT here: a two-digit chip steals the
      // last pixel from the eyebrow and ellipsizes "Components". It
      // goes on the hint line below, which has a whole row to itself.
      dom.span(classes: 'hui-rail-count', <Widget>[Text('$count')]),
    ]),
    _addSplitButton(),
  ]);

  /// One muted line, and while a group is selected it says so instead: the
  /// count is the more urgent fact — every command in the palette is about to
  /// act on all of them — and the ordering rule keeps its hover text either
  /// way. The full explanation lives there rather than in body copy.
  Widget _hintLine(int selected, int count) {
    final bool group = selected > 1;
    return dom.p(
      classes: 'hui-rail-hint',
      // `data-no-tooltip` keeps Arcane's title-to-tooltip upgrade away: it
      // re-parents the element into a wrapper span, and this subtree belongs
      // to Jaspr's differ.
      attributes: <String, String>{
        'data-no-tooltip': 'true',
        'title': group
            ? 'Commands act on all $selected. Shift-click a row to add or '
                  'remove it; Escape clears the selection.'
            : 'The nearest hitbox fires; list order breaks an exact-distance '
                  'tie. Drag a row, use the arrows, or use the right-click '
                  'menu to change it.',
      },
      <Widget>[
        Text(
          group
              ? '$selected of $count selected'
              : 'List order breaks click ties',
        ),
      ],
    );
  }

  Widget _addSplitButton() => dom.div(classes: 'hui-rail-add', <Widget>[
    // No ArcaneTooltip in here: its surface is a 211px absolutely
    // positioned box that overflows a 240px rail and gives the scroll
    // container a horizontal scrollbar. The label is visible anyway.
    Button(
      variant: ButtonVariant.primary,
      size: ButtonSize.small,
      onPressed: () => _add('button'),
      icon: ArcaneIcon.plus(size: IconSize.sm),
      label: 'Add',
      attributes: const <String, String>{
        'aria-label': 'Add a button component',
      },
    ),
    // Was an ArcaneDropdownMenu. That component never opens in this
    // arcane_jaspr build — its open state lives entirely in the injected
    // JS runtime and nothing there flips it — so the type list is a
    // plain disclosure the rail owns, the way the command palette is a
    // plain dialog for the same class of reason.
    Button(
      // Keyed on the state it reports. Arcane's Button renders its
      // `attributes` one build behind — measured: opening the panel left
      // `aria-expanded="false"` and closing it left `true` — so the key
      // forces a fresh element and the disclosure state stays honest.
      key: ValueKey<bool>(_typesOpen),
      id: _typesTriggerId,
      variant: ButtonVariant.primary,
      size: ButtonSize.small,
      onPressed: () => _setTypesOpen(!_typesOpen),
      // The stylesheet trims this half of the split button through
      // `.hui-rail-add > .arcane-dropdown .arcane-button`, a selector the
      // dropdown's removal stopped matching. Ten extra pixels here
      // ellipsize the "Components" eyebrow, so the same declaration is
      // restored inline — `!important` because the rule it is replacing
      // is one, and 05-panels-dialogs.css belongs to another task.
      styles: const ArcaneStyleData(
        raw: <String, String>{'padding': '0 4px !important'},
      ),
      attributes: <String, String>{
        'aria-label': 'Choose a component type',
        'aria-expanded': _typesOpen ? 'true' : 'false',
        'aria-controls': _typesPanelId,
        // See the row menu's trigger: every `button[aria-expanded]` is
        // claimed by the legacy accordion binder unless it carries this
        // (`accordion_scripts.dart:7-16`). This one survives today only
        // because it is the last child of `.hui-rail-add` and so has no
        // next sibling for the binder to hide — one added sibling would
        // break it silently. The opt-out is the guarantee.
        'data-arcane-interactive': 'true',
      },
      child: _typesOpen
          ? ArcaneIcon.chevronUp(size: IconSize.sm)
          : ArcaneIcon.chevronDown(size: IconSize.sm),
    ),
  ]);

  static const String _typesPanelId = 'hui-rail-types';
  static const String _typesTriggerId = 'hui-rail-types-trigger';

  /// At most one row menu is open, so one id is enough.
  static const String _rowMenuId = 'hui-rail-rowmenu';

  static String _rowMenuTriggerId(int index) => 'hui-rail-rowtools-$index';

  /// In flow under the header rather than floating over the list: an absolutely
  /// positioned card in a 240px scroll container needs the rail stylesheet to
  /// contain it, and pushing three rows down for one click does not.
  Widget _typeChooser() => dom.div(
    classes: 'hui-rail-types',
    id: _typesPanelId,
    styles: const dom.Styles(
      raw: <String, String>{
        'display': 'flex',
        'flex-direction': 'column',
        'gap': '2px',
        'padding': '6px',
        'margin': '0 0 8px',
        'border': '1px solid var(--hui-border-soft)',
        'border-radius': 'var(--hui-radius)',
        'background': 'var(--hui-panel-soft)',
      },
    ),
    attributes: const <String, String>{
      'role': 'group',
      'aria-label': 'Component types',
      // Focused on open so the Escape handler below is reachable; never
      // in the Tab order, which is what -1 buys over 0.
      'tabindex': '-1',
    },
    events: <String, void Function(Object)>{
      'keydown': (Object event) {
        if (domEventKey(event) != 'Escape') return;
        domStopPropagation(event);
        _setTypesOpen(false);
      },
    },
    <Widget>[
      for (final String type in huiComponentTypes)
        dom.button(
          classes: 'hui-rail-type',
          styles: const dom.Styles(
            raw: <String, String>{
              'display': 'flex',
              'align-items': 'flex-start',
              'gap': '8px',
              'width': '100%',
              'padding': '7px 8px',
              'border': '0',
              'border-radius': '0',
              'background': 'transparent',
              'color': 'var(--hui-text)',
              'text-align': 'left',
              'cursor': 'pointer',
              'font': 'inherit',
            },
          ),
          attributes: <String, String>{
            'type': 'button',
            'data-no-tooltip': 'true',
            'title': huiComponentTypeDescriptions[type] ?? '',
          },
          events: <String, void Function(Object)>{
            'click': (Object _) => _add(type),
          },
          <Widget>[
            dom.span(
              styles: const dom.Styles(
                raw: <String, String>{
                  'flex': '0 0 auto',
                  'margin-top': '2px',
                  'color': 'var(--hui-accent)',
                },
              ),
              attributes: const <String, String>{'aria-hidden': 'true'},
              <Widget>[_typeIcon(type, true)],
            ),
            dom.span(
              styles: const dom.Styles(
                raw: <String, String>{
                  'display': 'flex',
                  'flex-direction': 'column',
                  'gap': '1px',
                  'min-width': '0',
                },
              ),
              <Widget>[
                dom.span(
                  styles: const dom.Styles(
                    raw: <String, String>{
                      'font-size': '0.82rem',
                      'font-weight': '600',
                    },
                  ),
                  <Widget>[Text(_typeLabel(type))],
                ),
                dom.span(
                  styles: const dom.Styles(
                    raw: <String, String>{
                      'font-size': '0.72rem',
                      'line-height': '1.35',
                      'color': 'var(--hui-muted)',
                    },
                  ),
                  <Widget>[Text(huiComponentTypeDescriptions[type] ?? '')],
                ),
              ],
            ),
          ],
        ),
    ],
  );

  Widget _empty() => dom.div(classes: 'hui-rail-empty', <Widget>[
    ArcaneEmptyState(
      title: 'No components yet',
      description:
          'A menu needs at least one component to render. '
          'Start with a text decoration or a button.',
      icon: ArcaneIcon.layers(size: IconSize.lg),
      action: Button(
        variant: ButtonVariant.primary,
        size: ButtonSize.small,
        onPressed: () => _add('decoration'),
        icon: ArcaneIcon.plus(size: IconSize.sm),
        label: 'Add your first component',
      ),
    ),
  ]);

  Widget _row(int index, HuiComponent data, int total) {
    final String id = data.id;
    final String label = id.isEmpty ? '(no id)' : id;
    final String summary = _summary(data.data);
    final bool selected = _store.isSelected(id);
    final bool group = _store.selectionIds.length > 1;
    final bool primary = _store.selectedId == id;
    final bool armed = _armedDeleteId == id;
    final bool menuOpen = _menuRowId == id;
    final List<HuiIssue> issues = _store.issuesFor(id);
    final bool hasError = issues.any(
      (HuiIssue issue) => issue.severity == HuiSeverity.error,
    );
    final bool hasWarning = issues.any(
      (HuiIssue issue) => issue.severity == HuiSeverity.warning,
    );

    // A div, not an li: the row lives inside a positioning wrapper that carries
    // the list semantics, so a second listitem here would double them.
    final Widget row = dom.div(
      classes: classNames(<String?>[
        'hui-rail-row',
        selected ? 'is-selected' : null,
        armed ? 'is-armed' : null,
        _dragId == id ? 'is-dragging' : null,
        _dropIndex == index && _dragId != null && _dragId != id
            ? 'is-drop-target'
            : null,
      ]),
      attributes: const <String, String>{'draggable': 'true'},
      events: <String, void Function(Object)>{
        // Right-click still opens the row menu, the way the dead
        // ArcaneContextMenu was supposed to.
        'contextmenu': (Object event) {
          domPreventDefault(event);
          _setMenuRow(
            id,
            _rowMenuTriggerId(index),
            point: huiActionMenuEventPoint(event),
          );
        },
        'dragstart': (Object event) {
          setDragPayload(event, id);
          setState(() => _dragId = id);
        },
        'dragover': (Object event) {
          domPreventDefault(event);
          setDropEffectMove(event);
          if (_dropIndex != index) setState(() => _dropIndex = index);
        },
        'drop': (Object event) {
          domPreventDefault(event);
          _dropOn(index);
        },
        'dragend': (Object _) => setState(() {
          _dragId = null;
          _dropIndex = -1;
        }),
      },
      <Widget>[
        dom.button(
          classes: 'hui-rail-main',
          // Both lines are ellipsized in a 240px rail, so the untruncated text
          // has to stay reachable: the hover text is the only place it fits.
          // `data-no-tooltip` keeps Arcane's title-to-tooltip upgrade away — it
          // re-parents the button into a wrapper span behind Jaspr's back, and
          // the next row rebuild would patch against a node it no longer owns.
          attributes: <String, String>{
            'type': 'button',
            'data-no-tooltip': 'true',
            'aria-pressed': selected ? 'true' : 'false',
            'title':
                '$label\n${_typeLabel(data.data.type)} - $summary'
                '\nShift-click to add or remove it from the selection',
          },
          events: <String, void Function(Object)>{
            'click': (Object event) => _click(event, id),
          },
          <Widget>[
            // One 22px column for the type glyph, which becomes the drag grip
            // on hover: two icon columns would not fit next to the text.
            dom.span(
              classes: 'hui-rail-mark',
              attributes: const <String, String>{'aria-hidden': 'true'},
              <Widget>[
                dom.span(classes: 'hui-rail-glyph', <Widget>[
                  _typeIcon(data.data.type, selected),
                ]),
                dom.span(classes: 'hui-rail-grip', <Widget>[
                  ArcaneIcon.gripVertical(size: IconSize.sm),
                ]),
              ],
            ),
            dom.span(classes: 'hui-rail-text', <Widget>[
              dom.span(classes: 'hui-rail-id', <Widget>[Text(label)]),
              dom.span(classes: 'hui-rail-summary', <Widget>[Text(summary)]),
            ]),
            // The tint alone cannot say "one of eight" — every member wears the
            // same one. The check marks membership; the double check marks the
            // primary, which is the row the inspector is editing and the one a
            // group nudge snaps to. Decorative: `aria-pressed` on the button
            // is what a screen reader reads.
            if (group && selected)
              dom.span(
                styles: const dom.Styles(
                  raw: <String, String>{
                    'flex': '0 0 auto',
                    'display': 'inline-flex',
                    'color': 'var(--hui-accent)',
                  },
                ),
                attributes: const <String, String>{'aria-hidden': 'true'},
                <Widget>[
                  primary
                      ? ArcaneIcon.checkCheck(size: IconSize.sm)
                      : ArcaneIcon.check(size: IconSize.sm),
                ],
              ),
            if (hasError || hasWarning)
              dom.span(
                classes: classNames(<String?>[
                  'hui-rail-dot',
                  hasError ? 'is-error' : 'is-warning',
                ]),
                attributes: <String, String>{
                  'aria-label': hasError ? 'Has errors' : 'Has warnings',
                },
                const <Widget>[],
              ),
          ],
        ),
        if (armed)
          dom.div(classes: 'hui-rail-confirm', <Widget>[
            const dom.span(classes: 'hui-rail-confirm-label', <Widget>[
              Text('Delete?'),
            ]),
            Button(
              variant: ButtonVariant.destructive,
              size: ButtonSize.iconSm,
              onPressed: () => _delete(id),
              attributes: <String, String>{'aria-label': 'Delete $label'},
              child: ArcaneIcon.check(size: IconSize.sm),
            ),
            Button(
              variant: ButtonVariant.ghost,
              size: ButtonSize.iconSm,
              onPressed: () => setState(() => _armedDeleteId = null),
              attributes: const <String, String>{'aria-label': 'Keep it'},
              child: ArcaneIcon.x(size: IconSize.sm),
            ),
          ])
        else
          // Hidden until the row is hovered, focused or selected (CSS), so a
          // long list is not a wall of chevrons. Focus reveals them, so they
          // stay reachable from the keyboard.
          dom.div(
            classes: 'hui-rail-tools',
            // An open menu is a fourth reason to show the tools, and it is not
            // expressible in `05-panels-dialogs.css` from here. Plain
            // properties, so the stylesheet's transition still runs them.
            styles: menuOpen
                ? const dom.Styles(
                    raw: <String, String>{
                      'opacity': '1',
                      'visibility': 'visible',
                      'transform': 'none',
                    },
                  )
                : null,
            <Widget>[
              Button(
                variant: ButtonVariant.ghost,
                size: ButtonSize.iconSm,
                disabled: index == 0,
                onPressed: index == 0 ? null : () => _move(id, index - 1),
                attributes: <String, String>{'aria-label': 'Move $label up'},
                child: ArcaneIcon.chevronUp(size: IconSize.sm),
              ),
              Button(
                variant: ButtonVariant.ghost,
                size: ButtonSize.iconSm,
                disabled: index >= total - 1,
                onPressed: index >= total - 1
                    ? null
                    : () => _move(id, index + 1),
                attributes: <String, String>{'aria-label': 'Move $label down'},
                child: ArcaneIcon.chevronDown(size: IconSize.sm),
              ),
              Button(
                // Keyed on the state it reports: Arcane's Button renders its
                // `attributes` one build behind, so without this the
                // `aria-expanded` it carries would always be the previous
                // value.
                key: ValueKey<bool>(menuOpen),
                id: _rowMenuTriggerId(index),
                variant: ButtonVariant.ghost,
                size: ButtonSize.iconSm,
                onPressed: () => _setMenuRow(
                  menuOpen ? null : id,
                  _rowMenuTriggerId(index),
                  point: menuOpen
                      ? null
                      : huiActionMenuAnchor(_rowMenuTriggerId(index)),
                ),
                attributes: <String, String>{
                  'aria-haspopup': 'menu',
                  'aria-expanded': menuOpen ? 'true' : 'false',
                  // Never the word "Menu" with a capital M: the mobile-menu
                  // binder claims `[aria-label*="Menu"]`
                  // (`mobile_menu_scripts.dart:7`) and would hijack the click.
                  'aria-label': 'Row actions for $label',
                  // Opts this button out of the legacy accordion binder, which
                  // claims every `button[aria-expanded]` in a one-shot scan
                  // 100 ms after boot (`accordion_scripts.dart:7-16`). Left
                  // bound, it flips the attribute behind Jaspr's back and
                  // writes `display: none|block` onto the button's next
                  // sibling. `data-arcane-interactive` is the binder's own
                  // opt-out — the same trick as `data-no-tooltip` above.
                  'data-arcane-interactive': 'true',
                },
                child: ArcaneIcon.ellipsisVertical(size: IconSize.sm),
              ),
            ],
          ),
      ],
    );

    // The wrapper carries the list semantics and the positioning context for
    // the menu. It replaces the element `ArcaneContextMenu` used to wrap the
    // row in, so the list's child structure is unchanged.
    return dom.div(
      classes: 'hui-rail-item',
      styles: const dom.Styles(
        raw: <String, String>{'position': 'relative', 'min-width': '0'},
      ),
      attributes: const <String, String>{'role': 'listitem'},
      <Widget>[
        row,
        if (_renameId == id) _renameEditor(id),
        if (menuOpen) ..._rowMenu(index, id, label, total),
      ],
    );
  }

  Widget _renameEditor(String id) =>
      dom.div(classes: 'hui-rail-rename', <Widget>[
        TextInput(
          value: _renameDraft,
          fullWidth: true,
          size: ComponentSize.sm,
          onInput: (String value) => setState(() => _renameDraft = value),
        ),
        Button(
          variant: ButtonVariant.primary,
          size: ButtonSize.iconSm,
          onPressed: () {
            final String draft = _renameDraft;
            setState(() => _renameId = null);
            _store.renameComponent(id, draft);
          },
          attributes: const <String, String>{'aria-label': 'Save component id'},
          child: ArcaneIcon.check(size: IconSize.sm),
        ),
        Button(
          variant: ButtonVariant.ghost,
          size: ButtonSize.iconSm,
          onPressed: () => setState(() => _renameId = null),
          attributes: const <String, String>{'aria-label': 'Cancel rename'},
          child: ArcaneIcon.x(size: IconSize.sm),
        ),
      ]);

  List<Widget> _rowMenu(
    int index,
    String id,
    String label,
    int total,
  ) => <Widget>[
    HuiActionMenu(
      id: _rowMenuId,
      label: 'Actions for $label',
      point: _menuPoint,
      onClose: _dismissMenu,
      items: <HuiActionMenuItem>[
        HuiActionMenuItem(
          label:
              'Randomize ${_typeLabel(_store.menu.componentById(id)!.data.type).toLowerCase()}',
          icon: ArcaneIcon.dices(size: IconSize.sm),
          onSelect: () => randomizeMenuComponent(_store, id),
        ),
        HuiActionMenuItem(
          label: 'Rename',
          icon: ArcaneIcon.pencil(size: IconSize.sm),
          separatorBefore: true,
          onSelect: () => setState(() {
            _renameId = id;
            _renameDraft = id;
          }),
        ),
        HuiActionMenuItem(
          label: 'Duplicate',
          icon: ArcaneIcon.copy(size: IconSize.sm),
          onSelect: () => _store.duplicateComponent(id),
        ),
        HuiActionMenuItem(
          label: 'Move to top',
          icon: ArcaneIcon.arrowUp(size: IconSize.sm),
          disabled: index == 0,
          onSelect: () => _move(id, 0),
        ),
        HuiActionMenuItem(
          label: 'Move to bottom',
          icon: ArcaneIcon.arrowDown(size: IconSize.sm),
          disabled: index >= total - 1,
          onSelect: () => _move(id, total - 1),
        ),
        HuiActionMenuItem(
          label: 'Delete',
          icon: ArcaneIcon.trash2(size: IconSize.sm),
          destructive: true,
          separatorBefore: true,
          onSelect: () => setState(() => _armedDeleteId = id),
        ),
      ],
    ),
  ];

  Widget _typeIcon(String type, bool active) => switch (type) {
    'button' => ArcaneIcon.mousePointerClick(size: IconSize.sm),
    'toggle' =>
      active
          ? ArcaneIcon.toggleRight(size: IconSize.sm)
          : ArcaneIcon.toggleLeft(size: IconSize.sm),
    _ => ArcaneIcon.square(size: IconSize.sm),
  };

  String _typeLabel(String type) => switch (type) {
    'button' => 'Button',
    'toggle' => 'Toggle',
    _ => 'Decoration',
  };

  String _summary(HuiComponentData data) => switch (data) {
    HuiButtonData(
      icon: final HuiIcon? icon,
      actions: final List<HuiAction> a,
    ) =>
      '${_iconSummary(icon)} · ${a.length} action${a.length == 1 ? '' : 's'}',
    HuiDecorationData(icon: final HuiIcon? icon) =>
      '${_iconSummary(icon)} · not clickable',
    HuiToggleData(trueIcon: final HuiIcon? t, falseIcon: final HuiIcon? f) =>
      'true ${_iconSummary(t)} / false ${_iconSummary(f)}',
  };

  String _iconSummary(HuiIcon? icon) => switch (icon) {
    null => 'no icon',
    final HuiTextIcon text => 'text "${_plain(text.text)}"',
    final HuiTextImageIcon image =>
      'image ${image.path.isEmpty ? '(unset)' : image.path}',
    final HuiAnimatedImageIcon animated =>
      'animated ${animated.source.length} frame'
          '${animated.source.length == 1 ? '' : 's'}',
    final HuiItemIcon item =>
      'item ${item.item.isEmpty ? '(unset)' : item.item}'
          '${item.count > 1 ? ' x${item.count}' : ''}',
    final HuiBlockIcon block =>
      'block ${block.block.isEmpty ? '(unset)' : block.block}',
    final HuiCustomItemIcon custom =>
      '${custom.provider} ${custom.item.isEmpty ? '(unset)' : custom.item}'
          '${custom.count > 1 ? ' x${custom.count}' : ''}',
    final HuiEntityIcon entity =>
      'entity ${entity.entity.isEmpty ? '(unset)' : entity.entity}',
    final HuiPlayerHeadIcon head =>
      'head ${head.player.trim().isEmpty ? '(unset)' : head.player.trim()}',
  };

  /// First line only, colour codes and MiniMessage tags removed, ellipsized.
  String _plain(String raw) {
    final int newline = raw.indexOf('\n');
    String line = newline >= 0 ? raw.substring(0, newline) : raw;
    line = line.replaceAll(_legacyCode, '').replaceAll(_tag, '').trim();
    if (line.isEmpty) return '(empty)';
    return line.length <= 22 ? line : '${line.substring(0, 21)}…';
  }
}

final RegExp _legacyCode = RegExp('[&§][0-9a-fk-orA-FK-OR]');
final RegExp _tag = RegExp('<[^<>]*>');

/// Left rail: the ordered component list.
///
/// Order is click-dispatch order in-game (the first component whose hitbox
/// contains the cursor wins), so reordering is a document edit, not a view
/// preference — every move goes through the store and lands in the undo stack.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:arcane_jaspr/core/dom_value.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show ListenableBuilder;

import '../../config/defaults.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'drag_data.dart';

class ComponentsRail extends StatefulWidget {
  const ComponentsRail({required this.store, super.key});

  final EditorStore store;

  @override
  State<ComponentsRail> createState() => _ComponentsRailState();
}

class _ComponentsRailState extends State<ComponentsRail> {
  /// Two-step delete: the first press arms the row, the check runs it.
  String? _armedDeleteId;
  String? _dragId;
  int _dropIndex = -1;

  EditorStore get _store => component.store;

  void _select(String id) {
    _store.select(id);
    if (_armedDeleteId != null) setState(() => _armedDeleteId = null);
  }

  void _add(String type) {
    _store.addComponent(type);
    if (_armedDeleteId != null) setState(() => _armedDeleteId = null);
  }

  void _delete(String id) {
    setState(() => _armedDeleteId = null);
    _store.deleteComponent(id);
  }

  void _move(String id, int newIndex) {
    _store.reorder(id, newIndex);
    setState(() {
      _dragId = null;
      _dropIndex = -1;
    });
  }

  void _dropOn(int index) {
    final String? dragged = _dragId;
    setState(() {
      _dragId = null;
      _dropIndex = -1;
    });
    if (dragged == null) return;
    _store.reorder(dragged, index);
  }

  // The shell already renders the scrolling `<aside class="hui-pane hui-rail">`
  // cell around this slot with its own `aria-label`, so the rail root is a
  // plain filler div: no second landmark, no second border, no second scroller.
  @override
  Widget build(BuildContext context) => dom.div(
        classes: 'hui-rail-pane',
        <Widget>[
          ListenableBuilder(
            listenable: _store,
            builder: (BuildContext inner) => _body(),
          ),
        ],
      );

  Widget _body() {
    final List<HuiComponent> components = _store.components;
    return dom.div(
      classes: 'hui-rail-inner',
      <Widget>[
        _header(components.length),
        if (components.isEmpty)
          _empty()
        else ...<Widget>[
          if (components.length > 1) _orderHint(),
          dom.div(
            classes: 'hui-rail-list',
            attributes: const <String, String>{'role': 'list'},
            <Widget>[
              for (int i = 0; i < components.length; i++)
                _row(i, components[i], components.length),
            ],
          ),
        ],
      ],
    );
  }

  /// Heading, count and the add split-button share one line: the rail is
  /// 240-280px wide and every line spent here is a component row lost.
  Widget _header(int count) => dom.div(
        classes: 'hui-rail-header',
        <Widget>[
          dom.div(
            classes: 'hui-rail-heading',
            <Widget>[
              const HuiEyebrow('Components'),
              // Plain text, not an aria-label: "Components 14" already reads
              // correctly and a labelled <span> has no role to carry a name.
              dom.span(
                classes: 'hui-rail-count',
                <Widget>[Text('$count')],
              ),
            ],
          ),
          _addSplitButton(),
        ],
      );

  /// The ordering rule, demoted to one muted line. The full explanation lives
  /// in the hover text rather than in three lines of body copy.
  Widget _orderHint() => const dom.p(
        classes: 'hui-rail-hint',
        // `data-no-tooltip` keeps Arcane's title-to-tooltip upgrade away: it
        // re-parents the element into a wrapper span, and this subtree belongs
        // to Jaspr's differ.
        attributes: <String, String>{
          'data-no-tooltip': 'true',
          'title': 'Order is click order: the first component whose hitbox '
              'contains the cursor wins. Drag a row, use the arrows, or use '
              'the right-click menu to change it.',
        },
        <Widget>[Text('Top of the list wins clicks')],
      );

  Widget _addSplitButton() => dom.div(
        classes: 'hui-rail-add',
        <Widget>[
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
          ArcaneDropdownMenu(
            id: 'hui-rail-add-menu',
            alignment: DropdownAlignment.right,
            width: 300,
            trigger: Button(
              variant: ButtonVariant.primary,
              size: ButtonSize.small,
              attributes: const <String, String>{
                'aria-label': 'Choose a component type',
              },
              child: ArcaneIcon.chevronDown(size: IconSize.sm),
            ),
            items: <ArcaneMenuItem>[
              for (final String type in huiComponentTypes)
                MenuItemAction(
                  label: _typeLabel(type),
                  description: huiComponentTypeDescriptions[type],
                  icon: _typeIcon(type, true),
                  onSelect: () => _add(type),
                ),
            ],
          ),
        ],
      );

  Widget _empty() => dom.div(
        classes: 'hui-rail-empty',
        <Widget>[
          ArcaneEmptyState(
            title: 'No components yet',
            description: 'A menu needs at least one component to render. '
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
        ],
      );

  Widget _row(int index, HuiComponent data, int total) {
    final String id = data.id;
    final String label = id.isEmpty ? '(no id)' : id;
    final String summary = _summary(data.data);
    final bool selected = _store.selectedId == id;
    final bool armed = _armedDeleteId == id;
    final List<HuiIssue> issues = _store.issuesFor(id);
    final bool hasError =
        issues.any((HuiIssue issue) => issue.severity == HuiSeverity.error);
    final bool hasWarning =
        issues.any((HuiIssue issue) => issue.severity == HuiSeverity.warning);

    // A div, not an li: ArcaneContextMenu wraps the trigger in its own element,
    // which would put a stray node between the list and its items.
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
      attributes: <String, String>{'draggable': 'true', 'role': 'listitem'},
      events: <String, void Function(Object)>{
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
            'title': '$label\n${_typeLabel(data.data.type)} - $summary',
          },
          events: <String, void Function(Object)>{
            'click': (Object _) => _select(id),
          },
          <Widget>[
            // One 22px column for the type glyph, which becomes the drag grip
            // on hover: two icon columns would not fit next to the text.
            dom.span(
              classes: 'hui-rail-mark',
              attributes: const <String, String>{'aria-hidden': 'true'},
              <Widget>[
                dom.span(
                  classes: 'hui-rail-glyph',
                  <Widget>[_typeIcon(data.data.type, selected)],
                ),
                dom.span(
                  classes: 'hui-rail-grip',
                  <Widget>[ArcaneIcon.gripVertical(size: IconSize.sm)],
                ),
              ],
            ),
            dom.span(
              classes: 'hui-rail-text',
              <Widget>[
                dom.span(
                  classes: 'hui-rail-id',
                  <Widget>[Text(label)],
                ),
                dom.span(
                  classes: 'hui-rail-summary',
                  <Widget>[Text(summary)],
                ),
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
          dom.div(
            classes: 'hui-rail-confirm',
            <Widget>[
              const dom.span(
                classes: 'hui-rail-confirm-label',
                <Widget>[Text('Delete?')],
              ),
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
            ],
          )
        else
          // Hidden until the row is hovered, focused or selected (CSS), so a
          // long list is not a wall of chevrons. Focus reveals them, so they
          // stay reachable from the keyboard.
          dom.div(
            classes: 'hui-rail-tools',
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
                onPressed:
                    index >= total - 1 ? null : () => _move(id, index + 1),
                attributes: <String, String>{'aria-label': 'Move $label down'},
                child: ArcaneIcon.chevronDown(size: IconSize.sm),
              ),
            ],
          ),
      ],
    );

    return ArcaneContextMenu(
      id: 'hui-rail-menu-$index',
      trigger: row,
      items: <ArcaneMenuItem>[
        MenuItemAction(
          label: 'Duplicate',
          icon: ArcaneIcon.copy(size: IconSize.sm),
          shortcut: 'Ctrl D',
          onSelect: () => _store.duplicateComponent(id),
        ),
        MenuItemAction(
          label: 'Move to top',
          icon: ArcaneIcon.arrowUp(size: IconSize.sm),
          disabled: index == 0,
          onSelect: () => _move(id, 0),
        ),
        MenuItemAction(
          label: 'Move to bottom',
          icon: ArcaneIcon.arrowDown(size: IconSize.sm),
          disabled: index >= total - 1,
          onSelect: () => _move(id, total - 1),
        ),
        const MenuItemSeparator(),
        MenuItemAction(
          label: 'Delete',
          icon: ArcaneIcon.trash2(size: IconSize.sm),
          description: 'Asks for confirmation on the row',
          destructive: true,
          onSelect: () => setState(() => _armedDeleteId = id),
        ),
      ],
    );
  }

  Widget _typeIcon(String type, bool active) => switch (type) {
        'button' => ArcaneIcon.mousePointerClick(size: IconSize.sm),
        'toggle' => active
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
        HuiButtonData(icon: final HuiIcon? icon, actions: final List<HuiAction> a) =>
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

library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:arcane_jaspr/core/dom_value.dart';
import 'package:jaspr/dom.dart' as dom;

import 'class_names.dart';
import 'hui_action_menu_dom.dart';

final class HuiActionMenuItem {
  const HuiActionMenuItem({
    required this.label,
    required this.icon,
    required this.onSelect,
    this.hint,
    this.disabled = false,
    this.destructive = false,
    this.separatorBefore = false,
  });

  final String label;
  final Widget icon;
  final void Function() onSelect;
  final String? hint;
  final bool disabled;
  final bool destructive;
  final bool separatorBefore;
}

final class HuiActionMenuPoint {
  const HuiActionMenuPoint(this.x, this.y);

  final double x;
  final double y;
}

HuiActionMenuPoint huiActionMenuEventPoint(Object? event) {
  final ({double x, double y}) point = huiActionMenuEventCoordinates(event);
  return HuiActionMenuPoint(point.x, point.y);
}

HuiActionMenuPoint huiActionMenuAnchor(String elementId) {
  final ({double x, double y}) point = huiActionMenuAnchorCoordinates(
    elementId,
  );
  return HuiActionMenuPoint(point.x, point.y);
}

void focusHuiActionMenu(String elementId) =>
    focusHuiActionMenuElement(elementId);

class HuiActionMenu extends StatelessWidget {
  const HuiActionMenu({
    required this.id,
    required this.label,
    required this.point,
    required this.items,
    required this.onClose,
    super.key,
  });

  final String id;
  final String label;
  final HuiActionMenuPoint point;
  final List<HuiActionMenuItem> items;
  final void Function() onClose;

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-action-menu-layer',
    <Widget>[
      dom.div(
        classes: 'hui-action-menu-scrim',
        attributes: const <String, String>{'aria-hidden': 'true'},
        events: <String, void Function(Object)>{
          'pointerdown': (Object _) => onClose(),
          'contextmenu': (Object event) {
            domPreventDefault(event);
            onClose();
          },
        },
        const <Widget>[],
      ),
      dom.div(
        id: id,
        classes: 'hui-action-menu',
        styles: dom.Styles(
          raw: <String, String>{
            '--hui-menu-x': '${point.x.round()}px',
            '--hui-menu-y': '${point.y.round()}px',
            '--hui-menu-height': '${(items.length * 42 + 20).clamp(96, 440)}px',
          },
        ),
        attributes: <String, String>{
          'role': 'menu',
          'aria-label': label,
          'tabindex': '-1',
        },
        events: <String, void Function(Object)>{
          'keydown': (Object event) {
            final String key = domEventKey(event);
            if (key == 'Escape') {
              domStopPropagation(event);
              onClose();
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
            moveHuiActionMenuFocus(id, key);
          },
        },
        <Widget>[
          for (final HuiActionMenuItem item in items) ...<Widget>[
            if (item.separatorBefore)
              const dom.div(
                classes: 'hui-action-menu-separator',
                attributes: <String, String>{'role': 'separator'},
                <Widget>[],
              ),
            dom.button(
              classes: classNames(<String?>[
                'hui-action-menu-item',
                item.destructive ? 'is-destructive' : null,
              ]),
              attributes: <String, String>{
                'type': 'button',
                'role': 'menuitem',
                if (item.disabled) 'disabled': '',
                if (item.disabled) 'aria-disabled': 'true',
              },
              events: <String, void Function(Object)>{
                'click': (Object _) {
                  if (item.disabled) return;
                  onClose();
                  item.onSelect();
                },
              },
              <Widget>[
                dom.span(
                  classes: 'hui-action-menu-icon',
                  attributes: const <String, String>{'aria-hidden': 'true'},
                  <Widget>[item.icon],
                ),
                dom.span(classes: 'hui-action-menu-label', <Widget>[
                  Text(item.label),
                ]),
                if (item.hint != null)
                  dom.span(classes: 'hui-action-menu-hint', <Widget>[
                    Text(item.hint!),
                  ]),
              ],
            ),
          ],
        ],
      ),
    ],
  );
}

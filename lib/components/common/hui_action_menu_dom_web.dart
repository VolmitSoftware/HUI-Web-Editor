library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

({double x, double y}) huiActionMenuEventCoordinates(Object? event) {
  final JSObject? object = event as JSObject?;
  final JSAny? rawX = object?.getProperty<JSAny?>('clientX'.toJS);
  final JSAny? rawY = object?.getProperty<JSAny?>('clientY'.toJS);
  final double x = rawX.isA<JSNumber>() ? (rawX! as JSNumber).toDartDouble : 8;
  final double y = rawY.isA<JSNumber>() ? (rawY! as JSNumber).toDartDouble : 8;
  return (x: x, y: y);
}

({double x, double y}) huiActionMenuAnchorCoordinates(String elementId) {
  final web.Element? element = web.document.getElementById(elementId);
  if (element == null) return (x: 8, y: 8);
  final web.DOMRect rect = element.getBoundingClientRect();
  return (x: rect.right - 8, y: rect.bottom + 4);
}

void focusHuiActionMenuElement(String elementId) {
  (web.document.getElementById(elementId) as web.HTMLElement?)?.focus();
}

void moveHuiActionMenuFocus(String elementId, String key) {
  final web.Element? menu = web.document.getElementById(elementId);
  if (menu == null) return;
  final web.NodeList buttons = menu.querySelectorAll(
    '.hui-action-menu-item:not(:disabled)',
  );
  if (buttons.length == 0) return;
  final web.Element? active = web.document.activeElement;
  int current = -1;
  for (int index = 0; index < buttons.length; index += 1) {
    if (identical(buttons.item(index), active)) {
      current = index;
      break;
    }
  }
  final int target = switch (key) {
    'Home' => 0,
    'End' => buttons.length - 1,
    'ArrowUp' => current <= 0 ? buttons.length - 1 : current - 1,
    _ => current >= buttons.length - 1 ? 0 : current + 1,
  };
  (buttons.item(target) as web.HTMLElement?)?.focus();
}

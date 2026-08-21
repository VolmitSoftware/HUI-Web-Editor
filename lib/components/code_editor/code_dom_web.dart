/// Browser backend for `code_dom.dart`.
///
/// Addressed by element id rather than by an event target, for the same reason
/// `inspector/dom_bridge_web.dart` is: `package:web`'s DOM classes are
/// extension types, so an `is` test against an `Object?` callback argument is
/// unsound, while `getElementById` plus a `tagName` check is.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Viewport rect of [elementId], or null when it is not in the document.
({double left, double top, double width, double height})? huiCodeRect(
  String elementId,
) {
  final web.Element? element = web.document.getElementById(elementId);
  if (element == null) return null;
  final web.DOMRect rect = element.getBoundingClientRect();
  return (
    left: rect.left.toDouble(),
    top: rect.top.toDouble(),
    width: rect.width.toDouble(),
    height: rect.height.toDouble(),
  );
}

/// Hard ceiling on how many key spans one harvest measures.
///
/// Each box costs a layout read, and the harvest runs on the first pointer move
/// after an edit. A menu with more keys than this loses hovers past the cap
/// rather than stalling the pane; nothing shipped comes close.
const int huiCodeKeyBoxLimit = 4000;

/// Every `[data-hui-key]` span inside [preId], flattened as
/// `offset, left, top, right, bottom` and expressed relative to the pre's own
/// border box so the table survives scrolling.
List<double> huiCodeKeyBoxes(String preId) {
  final web.Element? pre = web.document.getElementById(preId);
  if (pre == null) return const <double>[];
  final web.DOMRect base = pre.getBoundingClientRect();
  final double originX = base.left.toDouble();
  final double originY = base.top.toDouble();
  final web.NodeList spans = pre.querySelectorAll('[data-hui-key]');
  final int count = spans.length < huiCodeKeyBoxLimit
      ? spans.length
      : huiCodeKeyBoxLimit;
  final List<double> out = <double>[];
  for (int i = 0; i < count; i++) {
    final web.Node? node = spans.item(i);
    if (node == null || !node.isA<web.Element>()) continue;
    final web.Element span = node as web.Element;
    final String? raw = span.getAttribute('data-hui-key');
    final int? offset = raw == null ? null : int.tryParse(raw);
    if (offset == null) continue;
    final web.DOMRect rect = span.getBoundingClientRect();
    out
      ..add(offset.toDouble())
      ..add(rect.left.toDouble() - originX)
      ..add(rect.top.toDouble() - originY)
      ..add(rect.right.toDouble() - originX)
      ..add(rect.bottom.toDouble() - originY);
  }
  return out;
}

double _number(JSObject? object, String property) {
  final JSAny? value = object?.getProperty<JSAny?>(property.toJS);
  return (value as JSNumber?)?.toDartDouble ?? 0;
}

bool _flag(JSObject? object, String property) {
  final JSAny? value = object?.getProperty<JSAny?>(property.toJS);
  return (value as JSBoolean?)?.toDart ?? false;
}

/// `clientX` / `clientY` off a pointer event.
({double x, double y}) huiCodePointerPoint(Object? event) {
  final JSObject? typed = event as JSObject?;
  return (x: _number(typed, 'clientX'), y: _number(typed, 'clientY'));
}

/// The four modifier flags off a keyboard event.
({bool ctrl, bool meta, bool shift, bool alt}) huiCodeModifiers(Object? event) {
  final JSObject? typed = event as JSObject?;
  return (
    ctrl: _flag(typed, 'ctrlKey'),
    meta: _flag(typed, 'metaKey'),
    shift: _flag(typed, 'shiftKey'),
    alt: _flag(typed, 'altKey'),
  );
}

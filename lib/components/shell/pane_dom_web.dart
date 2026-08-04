/// Browser backend for `pane_dom.dart`.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Reads a numeric event/window property without trusting package:web's `int`
/// typing.
///
/// `clientX` and `innerWidth` are declared `int` but genuinely return fractions
/// on trackpads, zoomed displays and fractional-DPI screens; reading `1094.8`
/// through the typed getter throws `type 'double' is not a subtype of type
/// 'int'` under both DDC and dart2js.
double _jsDouble(JSObject owner, String property) {
  final JSAny? value = owner.getProperty<JSAny?>(property.toJS);
  if (value == null || !value.isA<JSNumber>()) return 0;
  return (value as JSNumber).toDartDouble;
}

/// Writes a pane width onto the document root's inline style.
///
/// `--hui-rail-width` / `--hui-inspector-width` are declared on `:root` in
/// 02-shell.css and an inline custom property on `<html>` out-cascades that,
/// including the responsive overrides. jaspr renders nothing above `<body>`, so
/// no rebuild can stomp the value back — which is exactly what lets a drag skip
/// `setState` entirely.
void writePaneVariable(String name, double px) {
  try {
    final web.Element? root = web.document.documentElement;
    if (root == null) return;
    (root as web.HTMLElement).style.setProperty(name, '${px.round()}px');
  } catch (_) {}
}

/// Keeps the handle's `aria-valuenow` in step during a drag.
///
/// A widget rebuild re-declares the attribute from the committed layout, so a
/// mid-drag rebuild only ever loses the preview value, never the real one.
void writePaneAria(String handleId, double width) {
  try {
    web.document
        .getElementById(handleId)
        ?.setAttribute('aria-valuenow', width.round().toString());
  } catch (_) {}
}

/// Viewport width in CSS pixels, or 0 when it cannot be measured.
double paneViewportWidth() {
  try {
    final double width = _jsDouble(web.window as JSObject, 'innerWidth');
    return width.isFinite && width > 0 ? width : 0;
  } catch (_) {
    return 0;
  }
}

/// Wires pointer, double-click and keyboard resizing onto the handle with
/// [handleId]. Returns its uninstaller.
///
/// All geometry stays in Dart: this reports the dragged position of the
/// handle's left edge and lets the caller decide what width that means.
void Function() installPaneSplitter({
  required String handleId,
  required void Function(double edgeX) onDragMove,
  required void Function() onDragEnd,
  required void Function() onReset,
  required void Function(String key, bool shift) onKey,
}) {
  final web.Element? element = web.document.getElementById(handleId);
  if (element == null) return () {};
  final web.HTMLElement handle = element as web.HTMLElement;

  double grabOffset = 0;
  int activePointer = -1;

  final Map<String, JSFunction> listeners = <String, JSFunction>{};
  void bind(
    String type,
    void Function(web.Event event) handler, {
    bool passive = true,
  }) {
    final JSFunction listener = handler.toJS;
    listeners[type] = listener;
    handle.addEventListener(
      type,
      listener,
      web.AddEventListenerOptions(passive: passive),
    );
  }

  void endDrag() {
    if (activePointer < 0) return;
    try {
      handle.releasePointerCapture(activePointer);
    } catch (_) {}
    activePointer = -1;
    try {
      web.document.body?.classList.remove('hui-resizing');
    } catch (_) {}
    onDragEnd();
  }

  bind(
    'pointerdown',
    (web.Event event) {
      if (!event.isA<web.PointerEvent>()) return;
      final web.PointerEvent pointer = event as web.PointerEvent;
      if (pointer.button != 0) return;
      event.preventDefault();
      // Grabbing the handle anywhere along its 6px must not jump the pane:
      // track where inside the handle the pointer landed.
      grabOffset =
          _jsDouble(pointer as JSObject, 'clientX') - handle.getBoundingClientRect().x;
      activePointer = pointer.pointerId;
      try {
        handle.setPointerCapture(activePointer);
      } catch (_) {}
      try {
        web.document.body?.classList.add('hui-resizing');
      } catch (_) {}
      handle.focus();
    },
    passive: false,
  );

  bind(
    'pointermove',
    (web.Event event) {
      if (activePointer < 0 || !event.isA<web.PointerEvent>()) return;
      event.preventDefault();
      onDragMove(_jsDouble(event as JSObject, 'clientX') - grabOffset);
    },
    passive: false,
  );

  bind('pointerup', (web.Event event) => endDrag());
  bind('pointercancel', (web.Event event) => endDrag());

  bind(
    'dblclick',
    (web.Event event) {
      event.preventDefault();
      onReset();
    },
    passive: false,
  );

  bind(
    'keydown',
    (web.Event event) {
      if (!event.isA<web.KeyboardEvent>()) return;
      final web.KeyboardEvent typed = event as web.KeyboardEvent;
      const List<String> handled = <String>[
        'ArrowLeft',
        'ArrowRight',
        'Home',
        'End',
      ];
      if (!handled.contains(typed.key)) return;
      event.preventDefault();
      // The shell's document-level binder turns arrows into a component nudge;
      // a focused splitter has to keep them.
      event.stopPropagation();
      onKey(typed.key, typed.shiftKey);
    },
    passive: false,
  );

  return () {
    for (final MapEntry<String, JSFunction> entry in listeners.entries) {
      handle.removeEventListener(entry.key, entry.value);
    }
    listeners.clear();
    try {
      web.document.body?.classList.remove('hui-resizing');
    } catch (_) {}
  };
}

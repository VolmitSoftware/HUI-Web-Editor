/// Browser backend for `key_listener.dart`.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'shell_keys.dart';

/// Installs a document-level keydown listener and returns its uninstaller.
///
/// The listener is kept as a [JSFunction] because `removeEventListener` only
/// matches the identical JS callback: converting the same Dart closure twice
/// produces two different functions and leaks the first one.
void Function() installShellKeyListener(ShellKeyHandler handler) {
  final JSFunction listener = ((web.Event event) {
    if (!event.isA<web.KeyboardEvent>()) return;
    final web.KeyboardEvent typed = event as web.KeyboardEvent;
    final ShellKey key = ShellKey(
      key: typed.key,
      ctrl: typed.ctrlKey,
      meta: typed.metaKey,
      shift: typed.shiftKey,
      alt: typed.altKey,
      editable: _isEditable(event.target),
      overlayOpen: _overlayOpen(),
    );
    if (handler(key)) {
      event.preventDefault();
      event.stopPropagation();
    }
  }).toJS;
  web.document.addEventListener('keydown', listener);
  return () => web.document.removeEventListener('keydown', listener);
}

bool isApplePlatform() {
  try {
    final String platform = web.window.navigator.platform.toLowerCase();
    if (platform.contains('mac') ||
        platform.contains('iphone') ||
        platform.contains('ipad')) {
      return true;
    }
    return web.window.navigator.userAgent.toLowerCase().contains('mac os');
  } catch (_) {
    return false;
  }
}

bool _overlayOpen() {
  try {
    return web.document
            .querySelector('[data-arcane-surface][data-arcane-state="open"]') !=
        null;
  } catch (_) {
    return false;
  }
}

bool _isEditable(web.EventTarget? target) {
  if (target == null) return false;
  if (!target.isA<web.HTMLElement>()) return false;
  final web.HTMLElement element = target as web.HTMLElement;
  final String tag = element.tagName.toUpperCase();
  if (tag == 'INPUT' || tag == 'TEXTAREA' || tag == 'SELECT') return true;
  return element.isContentEditable;
}

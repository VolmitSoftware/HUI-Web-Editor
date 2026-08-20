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
      overlayOpen: huiArcaneOverlayOpen(),
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

/// Surfaces that do NOT take keyboard ownership when they open.
///
/// `ArcaneTooltip` renders `data-arcane-surface="hovercard"`
/// (`floating_render_base.dart:120`) and the interaction layer also emits
/// `tooltip`. Both are pointer-hover decoration with nothing focusable inside.
///
/// Excluding them is a bug fix, not a refinement: the predicate used to match
/// any open surface, so **every** shortcut in the app went dead while a tooltip
/// was showing. Measured — with the pointer resting on the top bar's Settings
/// button, `P` left the view on Visual; moved away, the same key switched to
/// Preview. Anything not listed here still stands the shell down, so a new
/// modal surface type is safe by default.
const String _passiveSurfaces =
    ':not([data-arcane-surface="hovercard"])'
    ':not([data-arcane-surface="tooltip"])';

/// True while an Arcane surface that owns the keyboard is open — a dialog,
/// sheet, drawer, menu or popover, but never a tooltip.
///
/// Public because the shell's `[data-command-trigger]` needs the same answer:
/// the injected runtime claims the ⌘K chord on the document and consumes it
/// before this listener runs, so a stand-down expressed only in [ShellKey]
/// cannot reach it. The trigger's click handler asks this directly instead, and
/// both paths therefore agree on what "an overlay owns the keyboard" means.
bool huiArcaneOverlayOpen() {
  try {
    return web.document.querySelector(
          '[data-arcane-surface][data-arcane-state="open"]$_passiveSurfaces',
        ) !=
        null;
  } catch (_) {
    return false;
  }
}

bool huiMobilePaneOpen() {
  try {
    return web.document.querySelector('.hui-pane.is-mobile-open') != null;
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

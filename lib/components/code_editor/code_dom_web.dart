/// Web backend for `code_dom.dart`.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Mirrors [sourceId]'s scroll offsets onto [targetId] and returns a detacher,
/// or null when either element is not in the document yet.
///
/// The offsets are copied immediately as well, so a rebind after a remount does
/// not leave the two panes one gesture apart.
void Function()? bindScrollMirror(String sourceId, String targetId) {
  final web.Element? source = web.document.getElementById(sourceId);
  final web.Element? target = web.document.getElementById(targetId);
  if (source == null || target == null) return null;

  void sync() {
    target.scrollLeft = source.scrollLeft;
    target.scrollTop = source.scrollTop;
  }

  final JSFunction listener = ((web.Event _) => sync()).toJS;
  source.addEventListener(
    'scroll',
    listener,
    web.AddEventListenerOptions(passive: true),
  );
  sync();
  return () => source.removeEventListener('scroll', listener);
}

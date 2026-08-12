library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

String readWorkspaceLocationHash() => web.window.location.hash;

String workspaceUrlForHash(String hash) {
  final String href = web.window.location.href;
  final int fragment = href.indexOf('#');
  return '${fragment < 0 ? href : href.substring(0, fragment)}$hash';
}

void writeWorkspaceLocationHash(String hash, {bool replace = false}) {
  if (web.window.location.hash == hash) return;
  if (replace) {
    web.window.history.replaceState(null, '', hash);
  } else {
    web.window.location.hash = hash;
  }
}

void Function() listenWorkspaceLocationHash(
  void Function(String hash) onChanged,
) {
  final JSFunction listener = ((web.Event _) {
    onChanged(web.window.location.hash);
  }).toJS;
  web.window.addEventListener('hashchange', listener);
  return () => web.window.removeEventListener('hashchange', listener);
}

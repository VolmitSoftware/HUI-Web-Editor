library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

void Function() listenForPlatformPageExit(void Function() listener) {
  final JSFunction pageHide = ((web.Event event) => listener()).toJS;
  final JSFunction visibilityChange = ((web.Event event) {
    if (web.document.visibilityState == 'hidden') listener();
  }).toJS;
  web.window.addEventListener('pagehide', pageHide);
  web.document.addEventListener('visibilitychange', visibilityChange);
  return () {
    web.window.removeEventListener('pagehide', pageHide);
    web.document.removeEventListener('visibilitychange', visibilityChange);
  };
}

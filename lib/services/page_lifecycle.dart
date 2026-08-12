library;

import 'page_lifecycle_stub.dart'
    if (dart.library.js_interop) 'page_lifecycle_web.dart';

void Function() listenForPageExit(void Function() listener) =>
    listenForPlatformPageExit(listener);

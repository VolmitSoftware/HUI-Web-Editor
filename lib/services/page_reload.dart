library;

import 'page_reload_stub.dart'
    if (dart.library.js_interop) 'page_reload_web.dart';

void reloadEditorPage() => reloadPlatformPage();

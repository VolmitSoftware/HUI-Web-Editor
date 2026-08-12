library;

import 'package:web/web.dart' as web;

typedef EditorSyncBindingWriter =
    bool Function(String workspaceId, String value);

String _key(String workspaceId) => 'holoui.sync.tab.$workspaceId';

String? readEditorSyncBinding(String workspaceId) =>
    web.window.sessionStorage.getItem(_key(workspaceId));

bool writeEditorSyncBinding(String workspaceId, String value) {
  try {
    web.window.sessionStorage.setItem(_key(workspaceId), value);
    return true;
  } catch (_) {
    return false;
  }
}

void removeEditorSyncBinding(String workspaceId) {
  try {
    web.window.sessionStorage.removeItem(_key(workspaceId));
  } catch (_) {}
}

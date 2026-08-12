library;

typedef EditorSyncBindingWriter =
    bool Function(String workspaceId, String value);

String? readEditorSyncBinding(String workspaceId) => null;

bool writeEditorSyncBinding(String workspaceId, String value) => false;

void removeEditorSyncBinding(String workspaceId) {}

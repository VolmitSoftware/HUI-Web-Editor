library;

String readWorkspaceLocationHash() => '';

String workspaceUrlForHash(String hash) => hash;

void writeWorkspaceLocationHash(String hash, {bool replace = false}) {}

void Function() listenWorkspaceLocationHash(
  void Function(String hash) onChanged,
) => () {};

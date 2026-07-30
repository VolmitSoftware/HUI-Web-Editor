/// Off-web no-op backend for `dom_bridge.dart`.
library;

(int start, int end)? readTextSelection(String elementId) => null;

void writeTextValue(
  String elementId,
  String value, {
  int? selectionStart,
  int? selectionEnd,
  bool focus = true,
}) {}

List<Object> readInputFiles(String elementId) => const <Object>[];

void resetFileInput(String elementId) {}

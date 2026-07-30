/// Browser backend for `dom_bridge.dart`.
///
/// Everything is addressed by element id rather than by an event target: the
/// `package:web` DOM classes are extension types, so an `is` test against an
/// `Object?` callback argument is not sound, while `getElementById` plus a
/// `tagName` check is.
library;

import 'package:web/web.dart' as web;

web.HTMLTextAreaElement? _textArea(String elementId) {
  final web.Element? element = web.document.getElementById(elementId);
  if (element == null || element.tagName.toUpperCase() != 'TEXTAREA') {
    return null;
  }
  return element as web.HTMLTextAreaElement;
}

web.HTMLInputElement? _input(String elementId) {
  final web.Element? element = web.document.getElementById(elementId);
  if (element == null || element.tagName.toUpperCase() != 'INPUT') {
    return null;
  }
  return element as web.HTMLInputElement;
}

/// Caret or selection range of the textarea/input with [elementId], or null
/// when it is absent or not a text control.
(int start, int end)? readTextSelection(String elementId) {
  final web.HTMLTextAreaElement? area = _textArea(elementId);
  if (area != null) {
    return (area.selectionStart, area.selectionEnd);
  }
  final web.HTMLInputElement? input = _input(elementId);
  if (input == null) return null;
  final int? start = input.selectionStart;
  final int? end = input.selectionEnd;
  if (start == null || end == null) return null;
  return (start, end);
}

/// Writes [value] straight onto the control's `value` property and restores the
/// caret. Required because a jaspr-rendered textarea carries its text as a child
/// node, which only feeds `defaultValue`: the browser stops mirroring it once
/// the field is user-dirty, so a spliced edit would otherwise not show.
void writeTextValue(
  String elementId,
  String value, {
  int? selectionStart,
  int? selectionEnd,
  bool focus = true,
}) {
  final int start = selectionStart ?? value.length;
  final int end = selectionEnd ?? start;
  final web.HTMLTextAreaElement? area = _textArea(elementId);
  if (area != null) {
    if (area.value != value) area.value = value;
    if (focus) area.focus();
    area.setSelectionRange(start, end);
    return;
  }
  final web.HTMLInputElement? input = _input(elementId);
  if (input == null) return;
  if (input.value != value) input.value = value;
  if (focus) input.focus();
  input.setSelectionRange(start, end);
}

/// `File` objects off the file input with [elementId], typed as [Object] so
/// callers stay free of `dart:js_interop`. `ImageLibrary.addFromFiles` takes
/// exactly this shape.
List<Object> readInputFiles(String elementId) {
  final web.HTMLInputElement? input = _input(elementId);
  if (input == null) return const <Object>[];
  final web.FileList? list = input.files;
  if (list == null) return const <Object>[];
  final List<Object> out = <Object>[];
  for (int i = 0; i < list.length; i++) {
    final web.File? file = list.item(i);
    if (file != null) out.add(file);
  }
  return out;
}

/// Clearing the input is what makes picking the same file twice fire `change` a
/// second time.
void resetFileInput(String elementId) {
  _input(elementId)?.value = '';
}

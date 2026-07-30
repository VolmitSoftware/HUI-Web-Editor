/// Browser backend for `image_picker.dart`.
///
/// Returns `package:web` `File` objects typed as [Object] so `ImageLibrary`
/// stays free of `dart:js_interop`; it decodes them through its own conditional
/// import.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<List<Object>> pickImageFiles() {
  final Completer<List<Object>> completer = Completer<List<Object>>();
  final web.HTMLInputElement input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/png,image/gif,image/jpeg,image/webp,image/bmp'
    ..multiple = true;
  input.style.display = 'none';
  late final JSFunction onChange;
  late final JSFunction onCancel;

  void finish(List<Object> files) {
    input.removeEventListener('change', onChange);
    input.removeEventListener('cancel', onCancel);
    input.remove();
    if (!completer.isCompleted) {
      completer.complete(files);
    }
  }

  onChange = ((web.Event _) {
    final web.FileList? list = input.files;
    final List<Object> files = <Object>[];
    if (list != null) {
      for (int i = 0; i < list.length; i++) {
        final web.File? file = list.item(i);
        if (file != null) {
          files.add(file);
        }
      }
    }
    finish(files);
  }).toJS;
  // Without this the future never completes when the OS dialog is dismissed.
  onCancel = ((web.Event _) => finish(const <Object>[])).toJS;

  input.addEventListener('change', onChange);
  input.addEventListener('cancel', onCancel);
  web.document.body?.appendChild(input);
  input.click();
  return completer.future;
}

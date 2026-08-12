/// Browser backend for `file_transfer.dart`.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const List<String> _imageExtensions = <String>[
  '.png',
  '.gif',
  '.jpg',
  '.jpeg',
  '.bmp',
  '.webp',
  '.tif',
  '.tiff',
];

void downloadText(
  String fileName,
  String text, {
  String mime = 'application/json',
}) {
  _save(
    fileName,
    web.Blob(
      <JSAny>[text.toJS].toJS,
      web.BlobPropertyBag(type: '$mime;charset=utf-8'),
    ),
  );
}

void downloadBytes(
  String fileName,
  List<int> bytes, {
  String mime = 'application/octet-stream',
}) {
  final Uint8List data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  _save(
    fileName,
    web.Blob(<JSAny>[data.toJS].toJS, web.BlobPropertyBag(type: mime)),
  );
}

Future<(String name, String content)?> pickJsonFile() {
  final Completer<(String name, String content)?> completer =
      Completer<(String name, String content)?>();
  final web.HTMLInputElement input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.json,application/json'
    ..multiple = false;
  input.style.display = 'none';
  late final JSFunction onChange;
  late final JSFunction onCancel;
  void finish((String name, String content)? result) {
    input.removeEventListener('change', onChange);
    input.removeEventListener('cancel', onCancel);
    input.remove();
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  onChange = ((web.Event _) {
    final web.File? file = input.files?.item(0);
    if (file == null) {
      finish(null);
      return;
    }
    file.text().toDart.then(
      (JSString value) => finish((file.name, value.toDart)),
      onError: (Object _) => finish(null),
    );
  }).toJS;
  // Fired when the OS dialog is dismissed; without it the future would hang.
  onCancel = ((web.Event _) => finish(null)).toJS;
  input.addEventListener('change', onChange);
  input.addEventListener('cancel', onCancel);
  web.document.body?.appendChild(input);
  input.click();
  return completer.future;
}

/// Wires drag-and-drop on the whole document. Returns the uninstall function;
/// call it from `dispose()`.
void Function() installDropHandler({
  required void Function(String name, String content) onJson,
  required void Function(List<Object> files) onImages,
  void Function(bool active)? onDragActive,
}) {
  // dragenter/dragleave fire per element under the pointer, so nesting is
  // counted rather than treated as a single enter/leave pair.
  int depth = 0;

  final JSFunction onDragEnter = ((web.Event event) {
    if (!_carriesFiles(event)) return;
    event.preventDefault();
    depth++;
    if (depth == 1) {
      onDragActive?.call(true);
    }
  }).toJS;
  final JSFunction onDragOver = ((web.Event event) {
    if (!_carriesFiles(event)) return;
    event.preventDefault();
    (event as web.DragEvent).dataTransfer?.dropEffect = 'copy';
  }).toJS;
  final JSFunction onDragLeave = ((web.Event event) {
    if (!_carriesFiles(event)) return;
    event.preventDefault();
    depth = depth > 0 ? depth - 1 : 0;
    if (depth == 0) {
      onDragActive?.call(false);
    }
  }).toJS;
  final JSFunction onDrop = ((web.Event event) {
    if (!_carriesFiles(event)) return;
    event.preventDefault();
    depth = 0;
    onDragActive?.call(false);
    _dispatchDrop(event as web.DragEvent, onJson, onImages);
  }).toJS;

  web.document.addEventListener('dragenter', onDragEnter);
  web.document.addEventListener('dragover', onDragOver);
  web.document.addEventListener('dragleave', onDragLeave);
  web.document.addEventListener('drop', onDrop);

  return () {
    web.document.removeEventListener('dragenter', onDragEnter);
    web.document.removeEventListener('dragover', onDragOver);
    web.document.removeEventListener('dragleave', onDragLeave);
    web.document.removeEventListener('drop', onDrop);
  };
}

/// True only for an OS file drag. The rail reorders its rows with native HTML5
/// drag-and-drop and those events bubble to the document too; without this gate
/// dragging a row raises the full-screen file-drop overlay and overrides the
/// move cursor. `dataTransfer.types` is readable during dragenter/dragover,
/// unlike `dataTransfer.files`.
bool _carriesFiles(web.Event event) {
  final web.DataTransfer? transfer = (event as web.DragEvent).dataTransfer;
  if (transfer == null) return false;
  for (final JSString type in transfer.types.toDart) {
    if (type.toDart == 'Files') return true;
  }
  return false;
}

void _dispatchDrop(
  web.DragEvent event,
  void Function(String name, String content) onJson,
  void Function(List<Object> files) onImages,
) {
  final web.DataTransfer? transfer = event.dataTransfer;
  if (transfer == null) {
    return;
  }
  final web.FileList files = transfer.files;
  final List<Object> images = <Object>[];
  for (int i = 0; i < files.length; i++) {
    final web.File? file = files.item(i);
    if (file == null) {
      continue;
    }
    final String name = file.name;
    final String lower = name.toLowerCase();
    if (lower.endsWith('.json') || file.type == 'application/json') {
      file.text().toDart.then(
        (JSString value) => onJson(name, value.toDart),
        onError: (Object _) {},
      );
    } else if (file.type.startsWith('image/') ||
        _imageExtensions.any((String extension) => lower.endsWith(extension))) {
      images.add(file);
    }
  }
  if (images.isNotEmpty) {
    onImages(images);
  }
}

void _save(String fileName, web.Blob blob) {
  final String url = web.URL.createObjectURL(blob);
  final web.HTMLAnchorElement anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  anchor.style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  // Safari aborts the download if the object URL dies in the same task.
  Timer(const Duration(seconds: 10), () => web.URL.revokeObjectURL(url));
}

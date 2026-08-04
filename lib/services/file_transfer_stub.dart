/// Off-web no-op backend for `file_transfer.dart`.
library;

void downloadText(String fileName, String text, {String mime = 'application/json'}) {}

void downloadBytes(
  String fileName,
  List<int> bytes, {
  String mime = 'application/octet-stream',
}) {}

Future<(String name, String content)?> pickJsonFile() async => null;

void Function() installDropHandler({
  required void Function(String name, String content) onJson,
  required void Function(List<Object> files) onImages,
  void Function(bool active)? onDragActive,
}) =>
    () {};

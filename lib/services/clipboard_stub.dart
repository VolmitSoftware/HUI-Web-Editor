/// Off-web no-op backend for `clipboard.dart`.
library;

Future<bool> copyText(String text) async => false;

Future<String?> readText() async => null;

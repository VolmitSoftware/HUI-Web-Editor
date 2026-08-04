/// Browser backend for `clipboard.dart`.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Chrome leaves the async clipboard promise pending forever when the document
/// is not focused (verified in a headless browser), so every call is raced.
const Duration _clipboardTimeout = Duration(milliseconds: 1200);

Future<bool> copyText(String text) async {
  try {
    await web.window.navigator.clipboard.writeText(text).toDart.timeout(_clipboardTimeout);
    return true;
  } catch (_) {
    return _copyWithExecCommand(text);
  }
}

Future<String?> readText() async {
  try {
    final JSString value =
        await web.window.navigator.clipboard.readText().toDart.timeout(_clipboardTimeout);
    return value.toDart;
  } catch (_) {
    return null;
  }
}

/// Insecure contexts (plain HTTP) have no `navigator.clipboard` at all. The
/// selection dance is required: `execCommand` copies the current selection, and
/// the textarea must be on-screen-ish for iOS to select it.
bool _copyWithExecCommand(String text) {
  try {
    final web.HTMLTextAreaElement area = web.HTMLTextAreaElement()..value = text;
    area.setAttribute('readonly', 'true');
    area.style
      ..position = 'fixed'
      ..top = '0'
      ..left = '0'
      ..width = '1px'
      ..height = '1px'
      ..opacity = '0';
    web.document.body?.appendChild(area);
    area.select();
    area.setSelectionRange(0, text.length);
    final bool copied = web.document.execCommand('copy');
    area.remove();
    return copied;
  } catch (_) {
    return false;
  }
}

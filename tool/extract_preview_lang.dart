/// Regenerates `web/assets/catalog/preview-lang-en.json` from the plugin's
/// `HoloMessages.java`.
///
/// The plugin carries every English message template inline, as the second
/// argument of a `TextKey.of("<id>", "<english>")` constant. The editor's
/// `lang()` simulation needs the same templates to bind positional call
/// arguments onto placeholder names, so this script lifts the
/// `holoui.preview.*` subset out of the Java source rather than having anyone
/// retype it. Re-run it whenever the plugin adds or edits a preview key:
///
/// ```
/// dart run tool/extract_preview_lang.dart
/// dart run tool/extract_preview_lang.dart /path/to/HoloMessages.java
/// ```
///
/// Output is sorted by id and pretty-printed, so a regeneration produces a
/// reviewable diff instead of a reshuffle.
library;

import 'dart:convert';
import 'dart:io';

/// Only these ids are lifted: the state, stat and theme-title keys a preview
/// document can pass to `lang()`. Command and chat messages live under
/// `holoui.message.*` / `holoui.command.*` and are not reachable from a
/// document.
const String idPrefix = 'holoui.preview.';

/// Default source, relative to this repo — the plugin checkout sits beside it.
const String defaultSource =
    '../Gloss/src/main/java/art/arcane/gloss/locale/HoloMessages.java';

const String outputPath = 'web/assets/catalog/preview-lang-en.json';

void main(List<String> args) {
  final String sourcePath = args.isEmpty ? defaultSource : args.first;
  final File source = File(sourcePath);
  if (!source.existsSync()) {
    stderr.writeln('missing HoloMessages.java: $sourcePath');
    exitCode = 1;
    return;
  }

  final Map<String, String> messages = extractPreviewMessages(source.readAsStringSync());
  if (messages.isEmpty) {
    stderr.writeln('no $idPrefix keys found in $sourcePath');
    exitCode = 1;
    return;
  }

  final List<String> ids = messages.keys.toList()..sort();
  final Map<String, String> sorted = <String, String>{
    for (final String id in ids) id: messages[id]!,
  };
  final String body =
      '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{'messages': sorted})}\n';
  File(outputPath).writeAsStringSync(body);
  stdout.writeln('wrote ${messages.length} messages to $outputPath');
}

/// Every `TextKey.of("<id>", "<english>")` pair whose id starts with
/// [idPrefix]. Scans the whole source text rather than line by line so a
/// wrapped declaration is still picked up.
Map<String, String> extractPreviewMessages(String source) {
  const String marker = 'TextKey.of(';
  final Map<String, String> out = <String, String>{};
  int cursor = 0;
  while (true) {
    final int start = source.indexOf(marker, cursor);
    if (start < 0) break;
    cursor = start + marker.length;
    final _Literal? id = _readLiteral(source, cursor);
    if (id == null) continue;
    final int comma = _skipSpace(source, id.end);
    if (comma >= source.length || source[comma] != ',') continue;
    final _Literal? english = _readLiteral(source, comma + 1);
    if (english == null) continue;
    cursor = english.end;
    if (id.value.startsWith(idPrefix)) {
      out[id.value] = english.value;
    }
  }
  return out;
}

class _Literal {
  const _Literal(this.value, this.end);

  final String value;

  /// Index just past the closing quote.
  final int end;
}

/// Reads the Java string literal starting at the first non-space character at
/// or after [from], unescaping it. Null when that character is not a quote.
_Literal? _readLiteral(String source, int from) {
  int i = _skipSpace(source, from);
  if (i >= source.length || source[i] != '"') return null;
  i++;
  final StringBuffer out = StringBuffer();
  while (i < source.length) {
    final String c = source[i];
    if (c == '"') return _Literal(out.toString(), i + 1);
    if (c == r'\' && i + 1 < source.length) {
      final String escape = source[i + 1];
      switch (escape) {
        case 'n':
          out.write('\n');
        case 't':
          out.write('\t');
        case 'r':
          out.write('\r');
        case '"':
          out.write('"');
        case r'\':
          out.write(r'\');
        case "'":
          out.write("'");
        default:
          out
            ..write(r'\')
            ..write(escape);
      }
      i += 2;
      continue;
    }
    out.write(c);
    i++;
  }
  return null;
}

int _skipSpace(String source, int from) {
  int i = from;
  while (i < source.length && _isSpace(source.codeUnitAt(i))) {
    i++;
  }
  return i;
}

bool _isSpace(int c) => c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;

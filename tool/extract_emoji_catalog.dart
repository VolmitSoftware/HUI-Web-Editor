/// Regenerates `web/assets/catalog/emoji.json` from the plugin's shipped
/// emoji defaults.
///
/// Gloss ships one emoji document per file under
/// `src/main/resources/defaults/emoji/` and extracts them into
/// `plugins/Gloss/emoji/` on first run. The editor's text pipeline mirror
/// substitutes `:tokens:` and triggers through this catalog (workspace emoji
/// documents override same-named entries), so the catalog carries what
/// `EmojiService.rebuild` computes at load: the id (the file name), the
/// trigger, and the glyph already resolved through `UnicodeText.parse`.
/// Re-run whenever the plugin's defaults change:
///
/// ```
/// dart run tool/extract_emoji_catalog.dart
/// dart run tool/extract_emoji_catalog.dart /path/to/defaults/emoji
/// ```
///
/// Output is sorted by name and pretty-printed, so a regeneration produces a
/// reviewable diff instead of a reshuffle. `test/emoji_catalog_test.dart`
/// holds the shipped output against the plugin tree.
library;

import 'dart:convert';
import 'dart:io';

import 'package:gloss_editor/model/model.dart';

/// Default source, relative to this repo — the plugin checkout sits beside it.
const String defaultSource = '../Gloss/src/main/resources/defaults/emoji';

const String outputPath = 'web/assets/catalog/emoji.json';

void main(List<String> args) {
  final String sourcePath = args.isEmpty ? defaultSource : args.first;
  final Directory source = Directory(sourcePath);
  if (!source.existsSync()) {
    stderr.writeln('missing emoji defaults directory: $sourcePath');
    exitCode = 1;
    return;
  }

  final List<Map<String, Object?>> entries = <Map<String, Object?>>[];
  for (final FileSystemEntity entity in source.listSync()) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    final String name = entity.uri.pathSegments.last
        .replaceFirst(RegExp(r'\.json$'), '');
    final GlossEmojiDoc doc;
    try {
      doc = decodeGlossEmojiDoc(entity.readAsStringSync());
    } on HuiFormatException catch (failure) {
      stderr.writeln('unreadable ${entity.path}: ${failure.message}');
      exitCode = 1;
      return;
    }
    entries.add(<String, Object?>{
      'name': name,
      'trigger': doc.trigger,
      'glyph': doc.resolvedGlyph,
      'enabled': doc.enabled,
    });
  }

  if (entries.isEmpty) {
    stderr.writeln('no emoji documents found in $sourcePath');
    exitCode = 1;
    return;
  }

  entries.sort(
    (Map<String, Object?> a, Map<String, Object?> b) =>
        (a['name']! as String).compareTo(b['name']! as String),
  );
  final String body =
      '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{'emoji': entries})}\n';
  File(outputPath).writeAsStringSync(body);
  stdout.writeln('wrote ${entries.length} emoji to $outputPath');
}

/// Live in-game text preview.
///
/// Rendered as styled DOM spans rather than on a canvas so it stays selectable,
/// scales with the browser and needs no paint loop. The parse comes from
/// `logic/mc_text.dart`, which mirrors the plugin's `TextUtils.parse` exactly —
/// including the two legacy codes that turn into literal text in game — behind
/// `glossRenderMenuText`, the emoji and bracket-hex prelude `TextMenuIcon`
/// runs before it.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/gloss_text.dart'
    show GlossEmojiResolver, GlossNoEmoji, glossRenderMenuText;
import '../../logic/mc_text.dart';
import '../common/common.dart';

class McTextPreview extends StatelessWidget {
  const McTextPreview({
    required this.raw,
    this.emoji = const GlossNoEmoji(),
    this.showWarnings = true,
    this.showMetrics = true,
    this.classes = '',
    super.key,
  });

  final String raw;

  /// Emoji available to the menu text stage — the shipped catalog with the
  /// workspace's emoji documents layered over it.
  final GlossEmojiResolver emoji;

  /// Parser warnings for unknown tags listed under the preview.
  final bool showWarnings;

  /// Line count and longest-line character count, which drive the hitbox.
  final bool showMetrics;
  final String classes;

  static String hex(int rgb) =>
      '#${(rgb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    final McTextResult result = parseMcText(
      glossRenderMenuText(raw, emoji: emoji),
    );
    return dom.div(
      classes: classNames(<String?>['hui-mc-preview', classes]),
      <Widget>[
        dom.div(classes: 'hui-mc-preview-surface', <Widget>[
          if (result.lines.isEmpty)
            const dom.div(classes: 'hui-mc-line is-empty', <Widget>[
              Text('(empty)'),
            ])
          else
            for (final List<McSpan> line in result.lines) _line(line),
        ]),
        if (showMetrics)
          dom.p(classes: 'hui-mc-preview-metrics', <Widget>[
            Text(
              '${result.lineCount} '
              '${result.lineCount == 1 ? 'line' : 'lines'} · longest '
              '${result.maxLineLength} '
              '${result.maxLineLength == 1 ? 'char' : 'chars'}',
            ),
          ]),
        if (showWarnings && result.hasWarnings)
          dom.ul(classes: 'hui-mc-preview-warnings', <Widget>[
            for (final String warning in result.warnings)
              dom.li(<Widget>[Text(warning)]),
          ]),
      ],
    );
  }

  Widget _line(List<McSpan> spans) => dom.div(classes: 'hui-mc-line', <Widget>[
    if (spans.isEmpty)
      const dom.span(classes: 'hui-mc-span is-blank', <Widget>[Text(' ')])
    else
      for (final McSpan span in spans) _span(span),
  ]);

  Widget _span(McSpan span) {
    final List<String> decorations = <String>[
      if (span.underlined) 'underline',
      if (span.strikethrough) 'line-through',
    ];
    return dom.span(
      classes: classNames(<String?>[
        'hui-mc-span',
        span.obfuscated ? 'is-obfuscated' : null,
      ]),
      styles: dom.Styles(
        raw: <String, String>{
          'color': hex(span.color),
          if (span.bold) 'font-weight': '700',
          if (span.italic) 'font-style': 'italic',
          if (decorations.isNotEmpty) 'text-decoration': decorations.join(' '),
        },
      ),
      <Widget>[Text(span.text)],
    );
  }
}

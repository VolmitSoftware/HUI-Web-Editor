/// The one styled-span renderer every Minecraft text surface draws through.
///
/// A parsed [McSpan] carries a colour plus five vanilla decorations. Both the
/// Gloss pipeline surfaces (`gloss_text_line.dart`) and the inspector's menu
/// text preview (`inspector/mc_text_preview.dart`) draw exactly this DOM, so
/// it lives here rather than being written twice: `.hui-mc-span`, inline
/// colour, and the decorations mapped onto CSS. Obfuscation is a class, not a
/// style — the flicker is a keyframe animation.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/mc_text.dart';
import '../common/common.dart';

/// One run of characters sharing a resolved style.
class GlossMcSpan extends StatelessWidget {
  const GlossMcSpan({required this.span, super.key});

  final McSpan span;

  @override
  Widget build(BuildContext context) {
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
          'color': mcColorCss(span.color),
          if (span.bold) 'font-weight': '700',
          if (span.italic) 'font-style': 'italic',
          if (decorations.isNotEmpty) 'text-decoration': decorations.join(' '),
        },
      ),
      <Widget>[Text(span.text)],
    );
  }
}

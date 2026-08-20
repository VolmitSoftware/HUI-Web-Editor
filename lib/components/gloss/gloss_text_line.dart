/// Styled-span rendering for Gloss pipeline text.
///
/// The DOM half of `logic/gloss_text.dart`: one rendered line becomes styled
/// spans (the same look as `mc_text_preview.dart`) plus placeholder chips for
/// the `%...%` tokens the editor cannot expand.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/gloss_text.dart';
import '../../logic/mc_text.dart';
import '../common/common.dart';
import 'gloss_mc_span.dart';

/// One line of Gloss text as inline spans. The container is a plain span so
/// callers decide the block layout (stage rows, sidebar rows, list previews).
class GlossTextLine extends StatelessWidget {
  const GlossTextLine({required this.render, this.classes = '', super.key});

  final GlossLineRender render;
  final String classes;

  @override
  Widget build(BuildContext context) => dom.span(
    classes: classNames(<String?>['hui-gloss-line', classes]),
    <Widget>[
      if (render.pieces.isEmpty)
        const dom.span(classes: 'hui-mc-span is-blank', <Widget>[Text(' ')])
      else
        for (final GlossTextPiece piece in render.pieces)
          switch (piece) {
            GlossTextRun(:final McSpan span) => GlossMcSpan(span: span),
            GlossPlaceholderChip(:final String token) => dom.span(
              classes: 'hui-gloss-chip',
              attributes: <String, String>{
                'title':
                    '$token — a PlaceholderAPI placeholder the server '
                    'expands per viewer.',
              },
              <Widget>[Text(token)],
            ),
            GlossMetricChip(:final String token, :final String key) => dom.span(
              classes: 'hui-gloss-chip is-metric',
              attributes: <String, String>{
                'title':
                    '$token — the "$key" metric, sampled from other Volmit '
                    'plugins via the integration bridge. It shows a compact '
                    'number in game and is empty until the first sample.',
              },
              <Widget>[Text(token)],
            ),
          },
    ],
  );
}

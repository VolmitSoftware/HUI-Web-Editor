/// Panel and label primitives.
///
/// Panels render through Arcane `Card` so they are natively themed instead of
/// hand-styled, and nested panels use the ghost variant: never a card inside a
/// card. Structural spacing is inline so a panel looks right before any
/// stylesheet module loads; the `hui-*` classes exist for those modules to
/// extend.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import 'class_names.dart';

enum HuiSurface { plain, subtle, outlined, raised, ghost }

class HuiPanel extends StatelessWidget {
  const HuiPanel({
    this.title = '',
    required this.children,
    this.nested = false,
    this.trailing,
    this.surface,
    this.featured = false,
    this.classes = '',
    this.gap = 12,
    super.key,
  });

  /// Empty renders no header row.
  final String title;
  final List<Widget> children;

  /// Nested panels drop their frame so panels never stack borders.
  final bool nested;

  /// Header-right slot: counts, toggles, a small action.
  final Widget? trailing;

  /// Overrides the variant chosen from [nested].
  final HuiSurface? surface;
  final bool featured;
  final String classes;

  /// Vertical gap between body children, in pixels.
  final num gap;

  CardVariant get _variant {
    final HuiSurface resolved =
        surface ?? (nested ? HuiSurface.ghost : HuiSurface.plain);
    return switch (resolved) {
      HuiSurface.plain => featured ? CardVariant.elevated : CardVariant.flat,
      HuiSurface.subtle => CardVariant.flat,
      HuiSurface.outlined => CardVariant.outlined,
      HuiSurface.raised => CardVariant.elevated,
      HuiSurface.ghost => CardVariant.ghost,
    };
  }

  @override
  Widget build(BuildContext context) => Card(
        variant: _variant,
        fillWidth: true,
        classes: classNames(<String?>[
          'hui-panel',
          nested ? 'is-nested' : null,
          classes,
        ]),
        children: <Widget>[
          if (title.isNotEmpty || trailing != null)
            dom.div(
              classes: 'hui-panel-header',
              styles: const dom.Styles(
                raw: <String, String>{
                  'display': 'flex',
                  'align-items': 'center',
                  'justify-content': 'space-between',
                  'gap': '8px',
                  'margin-bottom': '10px',
                },
              ),
              <Widget>[
                if (title.isNotEmpty)
                  dom.h2(
                    classes: 'hui-panel-title',
                    styles: const dom.Styles(
                      raw: <String, String>{
                        'font-size': '0.82rem',
                        'font-weight': '650',
                        'letter-spacing': '-0.01em',
                        'margin': '0',
                        'color': 'var(--foreground)',
                      },
                    ),
                    <Widget>[Text(title)],
                  )
                else
                  const dom.span(<Widget>[]),
                if (trailing != null)
                  dom.div(classes: 'hui-panel-trailing', <Widget>[trailing!]),
              ],
            ),
          dom.div(
            classes: 'hui-panel-body',
            styles: dom.Styles(
              raw: <String, String>{
                'display': 'flex',
                'flex-direction': 'column',
                'gap': '${gap}px',
                'min-width': '0',
              },
            ),
            children,
          ),
        ],
      );
}

/// Uppercase section label. One of the two typographic signatures of the design
/// language (the other is tabular numerics).
class HuiEyebrow extends StatelessWidget {
  const HuiEyebrow(this.text, {this.classes = '', super.key});

  final String text;
  final String classes;

  @override
  Widget build(BuildContext context) => dom.span(
        classes: classNames(<String?>['hui-eyebrow', classes]),
        styles: const dom.Styles(
          raw: <String, String>{
            'display': 'block',
            'font-size': '0.7rem',
            'font-weight': '680',
            'letter-spacing': '0.08em',
            'text-transform': 'uppercase',
            'color': 'var(--muted-foreground)',
          },
        ),
        <Widget>[Text(text)],
      );
}

/// Hairline divider. Panels separate rows with these, not with nested boxes.
class HuiDivider extends StatelessWidget {
  const HuiDivider({this.classes = '', super.key});

  final String classes;

  @override
  Widget build(BuildContext context) => dom.div(
        classes: classNames(<String?>['hui-divider', classes]),
        styles: const dom.Styles(
          raw: <String, String>{
            'height': '1px',
            'width': '100%',
            'background':
                'color-mix(in srgb, var(--border) 62%, transparent)',
          },
        ),
        const <Widget>[],
      );
}

/// Label-above-control form row: the single field shape used by the inspector,
/// the dialogs and the settings panels.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import 'class_names.dart';

class HuiField extends StatelessWidget {
  const HuiField({
    required this.label,
    required this.control,
    this.help,
    this.error,
    this.required = false,
    this.trailing,
    this.classes = '',
    this.inline = false,
    super.key,
  });

  final String label;

  /// The input itself. Anything: a `TextInput`, a switch, a whole sub-panel.
  final Widget control;

  /// Muted one-liner under the control explaining the in-game consequence.
  final String? help;

  /// Destructive-coloured line under the help text. Non-null also marks the row
  /// `is-invalid` for stylesheet modules.
  final String? error;

  final bool required;

  /// Header-right slot, aligned with the label (a reset button, a unit chip).
  final Widget? trailing;
  final String classes;

  /// Renders the label and control side by side instead of stacked.
  final bool inline;

  @override
  Widget build(BuildContext context) => dom.div(
    classes: classNames(<String?>[
      'hui-field',
      inline ? 'is-inline' : null,
      error != null ? 'is-invalid' : null,
      classes,
    ]),
    styles: dom.Styles(
      raw: <String, String>{
        'display': inline ? 'grid' : 'flex',
        if (inline)
          'grid-template-columns': 'minmax(90px, .38fr) minmax(0, 1fr)',
        if (inline) 'align-items': 'center',
        if (!inline) 'flex-direction': 'column',
        'gap': inline ? '10px' : '6px',
        'min-width': '0',
      },
    ),
    <Widget>[
      dom.div(
        classes: 'hui-field-head',
        styles: const dom.Styles(
          raw: <String, String>{
            'display': 'flex',
            'align-items': 'center',
            'justify-content': 'space-between',
            'gap': '8px',
            'min-width': '0',
          },
        ),
        <Widget>[
          dom.label(
            classes: 'hui-field-label',
            styles: const dom.Styles(
              raw: <String, String>{
                'font-size': '0.78rem',
                'font-weight': '600',
                'letter-spacing': '-0.01em',
                'color': 'var(--foreground)',
              },
            ),
            <Widget>[
              Text(label),
              if (required)
                const dom.span(
                  classes: 'hui-field-required',
                  styles: dom.Styles(
                    raw: <String, String>{
                      'color': 'var(--destructive)',
                      'margin-left': '3px',
                    },
                  ),
                  <Widget>[Text('*')],
                ),
            ],
          ),
          if (trailing != null)
            dom.div(classes: 'hui-field-trailing', <Widget>[trailing!]),
        ],
      ),
      dom.div(
        classes: 'hui-field-control',
        styles: const dom.Styles(raw: <String, String>{'min-width': '0'}),
        <Widget>[
          control,
          if (help != null)
            dom.p(
              classes: 'hui-field-help',
              styles: const dom.Styles(
                raw: <String, String>{
                  'font-size': '0.74rem',
                  'line-height': '1.35',
                  'margin': '5px 0 0',
                  'color': 'var(--muted-foreground)',
                },
              ),
              <Widget>[Text(help!)],
            ),
          if (error != null)
            dom.p(
              classes: 'hui-field-error',
              styles: const dom.Styles(
                raw: <String, String>{
                  'font-size': '0.74rem',
                  'line-height': '1.35',
                  'margin': '4px 0 0',
                  'color': 'var(--destructive)',
                },
              ),
              <Widget>[Text(error!)],
            ),
        ],
      ),
    ],
  );
}

/// Label-above-control form row: the single field shape used by the inspector,
/// the dialogs and the settings panels.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import 'class_names.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class HuiField extends StatelessWidget {
  const HuiField({
    required this.label,
    required this.control,
    this.help,
    this.error,
    this.required = false,
    this.trailing,
    this.defaultValue,
    this.onReset,
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

  /// Header-right slot, aligned with the label (a unit chip, a help button).
  final Widget? trailing;

  /// The value the runtime uses when the key is omitted, already formatted for
  /// reading (`1.7`, `ease_out_cubic`, `#00000000`). Rendered as a chip in the
  /// header, because a default the pane never states is a default the author
  /// has to go and find in the docs.
  final String? defaultValue;

  /// Puts the field back to [defaultValue]. Null with a [defaultValue] set
  /// renders the button disabled rather than removing it: a control that
  /// appears only once the value has moved shifts the row under the pointer.
  final void Function()? onReset;
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
          if (trailing != null || defaultValue != null)
            dom.div(classes: 'hui-field-trailing', <Widget>[
              if (defaultValue != null) ..._defaultTools(),
              ?trailing,
            ]),
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

  /// The default chip and the button that returns to it. The chip is the
  /// point; the button is the shortcut.
  List<Widget> _defaultTools() => <Widget>[
    dom.span(
      classes: 'hui-default-chip',
      attributes: <String, String>{
        'title': huiText(
          "Gloss uses {defaultValue} when this key is omitted",
          <String, Object?>{'defaultValue': defaultValue},
        ),
      },
      <Widget>[
        Text(
          huiText("default {defaultValue}", <String, Object?>{
            'defaultValue': defaultValue,
          }),
        ),
      ],
    ),
    ArcaneTooltip(
      text: huiText('Reset {label} to {defaultValue}', <String, Object?>{
        'label': label,
        'defaultValue': defaultValue,
      }),
      child: Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.iconSm,
        disabled: onReset == null,
        onPressed: onReset,
        attributes: <String, String>{
          'aria-label': huiText(
            "Reset {label} to {defaultValue}",
            <String, Object?>{'label': label, 'defaultValue': defaultValue},
          ),
        },
        child: ArcaneIcon.rotateCcw(size: IconSize.sm),
      ),
    ),
  ];
}

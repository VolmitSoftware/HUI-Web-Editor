/// Small shared pieces of the inspector: section rhythm, help notes, inline
/// validation, the two-step destructive button, segmented controls and chips.
///
/// Structural CSS lives in `web/styles/04-inspector.css`; only the bits that
/// must survive a missing stylesheet are inline here.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/validation.dart';
import '../common/common.dart';

/// One inspector section: uppercase eyebrow, optional trailing control, body.
/// Sections are separated by hairlines, never by nested cards.
class InspectorSection extends StatelessWidget {
  const InspectorSection({
    required this.title,
    required this.children,
    this.trailing,
    this.description,
    this.classes = '',
    this.gap = 10,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  /// Muted sentence under the eyebrow explaining what the section controls.
  final String? description;
  final String classes;
  final num gap;

  @override
  Widget build(BuildContext context) => dom.section(
        classes: classNames(<String?>['hui-inspector-section', classes]),
        <Widget>[
          dom.div(
            classes: 'hui-inspector-section-head',
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
              HuiEyebrow(title),
              if (trailing != null)
                dom.div(classes: 'hui-inspector-section-trailing', <Widget>[
                  trailing!,
                ]),
            ],
          ),
          if (description != null)
            dom.p(
              classes: 'hui-inspector-section-note',
              <Widget>[Text(description!)],
            ),
          dom.div(
            classes: 'hui-inspector-section-body',
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

/// Long-form explanation behind a closed native `<details>`.
///
/// The pane reads as controls first: anything longer than one muted line goes
/// in here, so the information stays reachable without shouting. Closed by
/// default, keyboard-operable because it is a real `<summary>`.
class HuiMore extends StatelessWidget {
  const HuiMore({
    required this.summary,
    required this.children,
    this.classes = '',
    super.key,
  });

  /// The one-line label on the closed row.
  final String summary;
  final List<Widget> children;
  final String classes;

  @override
  Widget build(BuildContext context) => ArcaneDisclosure.minimal(
        classes: <String>['hui-more', if (classes.isNotEmpty) classes],
        showTreeLines: false,
        summary: dom.span(
          classes: 'hui-more-summary',
          <Widget>[Text(summary)],
        ),
        child: dom.div(
          classes: 'hui-more-body',
          styles: const dom.Styles(
            raw: <String, String>{
              'display': 'flex',
              'flex-direction': 'column',
              'gap': '6px',
              'min-width': '0',
            },
          ),
          children,
        ),
      );
}

/// Muted explanatory block. [tone] tints the left rule for warnings and traps.
enum HuiNoteTone { neutral, info, warning, danger }

class HuiNote extends StatelessWidget {
  const HuiNote(this.text, {this.tone = HuiNoteTone.neutral, this.title, super.key});

  final String text;
  final String? title;
  final HuiNoteTone tone;

  String get _toneClass => switch (tone) {
        HuiNoteTone.neutral => 'is-neutral',
        HuiNoteTone.info => 'is-info',
        HuiNoteTone.warning => 'is-warning',
        HuiNoteTone.danger => 'is-danger',
      };

  String get _accent => switch (tone) {
        HuiNoteTone.neutral => 'var(--hui-border, var(--border))',
        HuiNoteTone.info => 'var(--hui-info, #007acc)',
        HuiNoteTone.warning => 'var(--hui-warning, #a06022)',
        HuiNoteTone.danger => 'var(--hui-danger, var(--destructive))',
      };

  @override
  Widget build(BuildContext context) => dom.div(
        classes: classNames(<String?>['hui-note', _toneClass]),
        styles: dom.Styles(
          raw: <String, String>{
            'border-left': '2px solid $_accent',
            'padding': '1px 0 1px 9px',
            'font-size': '0.72rem',
            'line-height': '1.45',
            'color': 'var(--muted-foreground)',
          },
        ),
        <Widget>[
          if (title != null)
            dom.strong(
              classes: 'hui-note-title',
              styles: const dom.Styles(
                raw: <String, String>{
                  'display': 'block',
                  'color': 'var(--foreground)',
                  'font-size': '0.72rem',
                  'font-weight': '620',
                },
              ),
              <Widget>[Text(title!)],
            ),
          Text(text),
        ],
      );
}

/// Key/value help rows: one hairline per row, right-aligned monospace value.
class HuiDetailRow extends StatelessWidget {
  const HuiDetailRow(this.label, this.value, {this.mono = true, super.key});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) => dom.div(
        classes: 'hui-detail-row',
        styles: const dom.Styles(
          raw: <String, String>{
            'display': 'flex',
            'align-items': 'baseline',
            'justify-content': 'space-between',
            'gap': '12px',
            'min-height': '24px',
            'padding': '3px 0',
          },
        ),
        <Widget>[
          dom.span(
            classes: 'hui-detail-label',
            styles: const dom.Styles(
              raw: <String, String>{
                'color': 'var(--muted-foreground)',
                'font-size': '0.72rem',
                'flex': '0 0 auto',
              },
            ),
            <Widget>[Text(label)],
          ),
          dom.span(
            classes: classNames(<String?>[
              'hui-detail-value',
              mono ? 'is-mono' : null,
            ]),
            styles: dom.Styles(
              raw: <String, String>{
                'min-width': '0',
                'font-size': '0.72rem',
                'font-weight': '560',
                'text-align': 'right',
                'overflow-wrap': 'anywhere',
                if (mono) 'font-family': 'var(--font-mono, ui-monospace, monospace)',
              },
            ),
            <Widget>[Text(value)],
          ),
        ],
      );
}

/// Validation issues rendered under the field they belong to.
class HuiInlineIssues extends StatelessWidget {
  const HuiInlineIssues(this.issues, {super.key});

  final List<HuiIssue> issues;

  static String severityColor(HuiSeverity severity) => switch (severity) {
        HuiSeverity.error => 'var(--hui-danger, var(--destructive))',
        HuiSeverity.warning => 'var(--hui-warning, #a06022)',
        HuiSeverity.info => 'var(--hui-info, #007acc)',
      };

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) return const dom.span(<Widget>[]);
    return dom.ul(
      classes: 'hui-inline-issues',
      styles: const dom.Styles(
        raw: <String, String>{
          'display': 'flex',
          'flex-direction': 'column',
          'gap': '3px',
          'margin': '5px 0 0',
          'padding': '0',
          'list-style': 'none',
        },
      ),
      <Widget>[
        for (final HuiIssue issue in issues)
          dom.li(
            classes: 'hui-inline-issue is-${issue.severity.name}',
            styles: dom.Styles(
              raw: <String, String>{
                'font-size': '0.72rem',
                'line-height': '1.4',
                'color': severityColor(issue.severity),
              },
            ),
            <Widget>[
              Text(issue.fix == null
                  ? issue.message
                  : '${issue.message} ${issue.fix!}'),
            ],
          ),
      ],
    );
  }
}

/// Destructive action in two clicks: arm, then confirm or cancel. No browser
/// `confirm()` anywhere in this editor.
class HuiArmedButton extends StatefulWidget {
  const HuiArmedButton({
    required this.label,
    required this.onConfirm,
    this.armedLabel,
    this.icon,
    this.size = ButtonSize.sm,
    this.variant = ButtonVariant.ghost,
    this.fullWidth = false,
    this.iconOnly = false,
    super.key,
  });

  final String label;

  /// Shown while armed; defaults to `Confirm`.
  final String? armedLabel;
  final Widget? icon;
  final void Function() onConfirm;
  final ButtonSize size;
  final ButtonVariant variant;
  final bool fullWidth;

  /// Renders the resting state as an icon button; [label] becomes the tooltip.
  final bool iconOnly;

  @override
  State<HuiArmedButton> createState() => _HuiArmedButtonState();
}

class _HuiArmedButtonState extends State<HuiArmedButton> {
  bool _armed = false;

  void _confirm() {
    setState(() => _armed = false);
    component.onConfirm();
  }

  Widget _resting() {
    if (component.iconOnly) {
      return HuiIconButton(
        icon: component.icon ?? ArcaneIcon.trash2(size: IconSize.sm),
        label: component.label,
        variant: component.variant,
        onPressed: () => setState(() => _armed = true),
      );
    }
    return Button(
      variant: component.variant,
      size: component.size,
      fullWidth: component.fullWidth,
      icon: component.icon,
      onPressed: () => setState(() => _armed = true),
      attributes: <String, String>{'aria-label': component.label},
      child: Text(component.label),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_armed) return _resting();
    return dom.div(
      classes: 'hui-armed',
      styles: const dom.Styles(
        raw: <String, String>{
          'display': 'inline-flex',
          'align-items': 'center',
          'gap': '4px',
        },
      ),
      <Widget>[
        if (component.iconOnly)
          HuiIconButton(
            icon: ArcaneIcon.check(size: IconSize.sm),
            label: component.armedLabel ?? 'Confirm',
            variant: ButtonVariant.destructive,
            onPressed: _confirm,
          )
        else
          Button(
            variant: ButtonVariant.destructive,
            size: component.size,
            fullWidth: component.fullWidth,
            onPressed: _confirm,
            icon: ArcaneIcon.check(size: IconSize.sm),
            attributes: <String, String>{
              'aria-label': component.armedLabel ?? 'Confirm',
            },
            child: Text(component.armedLabel ?? 'Confirm'),
          ),
        HuiIconButton(
          icon: ArcaneIcon.x(size: IconSize.sm),
          label: 'Cancel',
          onPressed: () => setState(() => _armed = false),
        ),
      ],
    );
  }
}

/// One choice in a [HuiSegmented] control.
class HuiSegment {
  const HuiSegment({
    required this.value,
    required this.label,
    this.icon,
    this.hint,
  });

  final String value;
  final String label;
  final Widget? icon;

  /// Tooltip text; also the accessible description of the segment.
  final String? hint;
}

/// Segmented control. Built on `ArcaneToggleGroup`, with the framework's
/// deselect-on-reclick suppressed: an inspector segment always has a value.
class HuiSegmented extends StatelessWidget {
  const HuiSegmented({
    required this.value,
    required this.segments,
    required this.onChanged,
    this.size = ToggleGroupSize.sm,
    this.classes = '',
    super.key,
  });

  final String value;
  final List<HuiSegment> segments;
  final void Function(String value) onChanged;
  final ToggleGroupSize size;
  final String classes;

  @override
  Widget build(BuildContext context) => dom.div(
        classes: classNames(<String?>['hui-segmented', classes]),
        <Widget>[
          ArcaneToggleGroup(
            value: value,
            variant: ToggleGroupVariant.outline,
            size: size,
            onChanged: (String? next) {
              if (next == null || next == value) return;
              onChanged(next);
            },
            items: <ToggleGroupItem>[
              for (final HuiSegment segment in segments)
                ToggleGroupItem(
                  value: segment.value,
                  child: _segmentChild(segment),
                ),
            ],
          ),
        ],
      );

  Widget _segmentChild(HuiSegment segment) {
    final Widget inner = dom.span(
      classes: 'hui-segment-inner',
      styles: const dom.Styles(
        raw: <String, String>{
          'display': 'inline-flex',
          'align-items': 'center',
          'gap': '6px',
          'white-space': 'nowrap',
        },
      ),
      <Widget>[
        if (segment.icon != null) segment.icon!,
        Text(segment.label),
      ],
    );
    return segment.hint == null
        ? inner
        : ArcaneTooltip(text: segment.hint!, child: inner);
  }
}

/// Small labelled switch row used for every boolean in the inspector.
class HuiSwitchRow extends StatelessWidget {
  const HuiSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.help,
    this.warning,
    this.disabled = false,
    super.key,
  });

  final String label;
  final bool value;
  final void Function(bool value) onChanged;
  final String? help;

  /// Rendered under the help line in the warning tone (used for
  /// `followPlayer` when `lockPosition` has already frozen the player).
  final String? warning;
  final bool disabled;

  @override
  Widget build(BuildContext context) => dom.div(
        classes: 'hui-switch-row',
        styles: const dom.Styles(
          raw: <String, String>{
            'display': 'flex',
            'flex-direction': 'column',
            'gap': '4px',
            'min-width': '0',
          },
        ),
        <Widget>[
          dom.div(
            classes: 'hui-switch-row-head',
            styles: const dom.Styles(
              raw: <String, String>{
                'display': 'flex',
                'align-items': 'center',
                'justify-content': 'space-between',
                'gap': '10px',
                'min-height': '28px',
              },
            ),
            <Widget>[
              dom.span(
                classes: 'hui-switch-row-label',
                styles: const dom.Styles(
                  raw: <String, String>{
                    'font-size': '0.78rem',
                    'font-weight': '600',
                    'letter-spacing': '-0.01em',
                  },
                ),
                <Widget>[Text(label)],
              ),
              ArcaneToggleSwitch(
                value: value,
                disabled: disabled,
                size: ComponentSize.sm,
                onChanged: disabled ? null : onChanged,
              ),
            ],
          ),
          if (help != null)
            dom.p(
              classes: 'hui-switch-row-help',
              styles: const dom.Styles(
                raw: <String, String>{
                  'margin': '0',
                  'font-size': '0.72rem',
                  'line-height': '1.45',
                  'color': 'var(--muted-foreground)',
                },
              ),
              <Widget>[Text(help!)],
            ),
          if (warning != null)
            dom.p(
              classes: 'hui-switch-row-warning',
              styles: const dom.Styles(
                raw: <String, String>{
                  'margin': '0',
                  'font-size': '0.72rem',
                  'line-height': '1.45',
                  'color': 'var(--hui-warning, #a06022)',
                },
              ),
              <Widget>[Text(warning!)],
            ),
        ],
      );
}

/// Slider plus an unclamped number field. HoloUI's JSON path does not clamp
/// `highlightModifier`, so the number entry deliberately allows values the
/// slider cannot reach and validation warns instead of the UI blocking.
class HuiSliderField extends StatelessWidget {
  const HuiSliderField({
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    this.step = 0.01,
    this.decimals = 3,
    this.numberMin,
    this.numberMax,
    super.key,
  });

  final double value;
  final void Function(double value) onChanged;
  final double min;
  final double max;
  final double step;
  final int decimals;

  /// Bounds for the typed entry. Null keeps it unbounded.
  final double? numberMin;
  final double? numberMax;

  @override
  Widget build(BuildContext context) => dom.div(
        classes: 'hui-slider-field',
        styles: const dom.Styles(
          raw: <String, String>{
            'display': 'grid',
            'grid-template-columns': 'minmax(0, 1fr) 104px',
            'align-items': 'center',
            'gap': '10px',
            'min-width': '0',
          },
        ),
        <Widget>[
          ArcaneSlider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            step: step,
            showValue: false,
            size: ComponentSize.sm,
            onChanged: onChanged,
          ),
          HuiNumberField(
            value: value,
            onChanged: onChanged,
            min: numberMin,
            max: numberMax,
            step: step,
            decimals: decimals,
            steppers: false,
          ),
        ],
      );
}

/// Compact icon button with a tooltip and an aria-label (never a native title).
class HuiIconButton extends StatelessWidget {
  const HuiIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.ghost,
    this.disabled = false,
    super.key,
  });

  final Widget icon;
  final String label;
  final void Function()? onPressed;
  final ButtonVariant variant;
  final bool disabled;

  @override
  Widget build(BuildContext context) => ArcaneTooltip(
        text: label,
        child: Button(
          variant: variant,
          size: ButtonSize.iconSm,
          disabled: disabled || onPressed == null,
          onPressed: disabled ? null : onPressed,
          attributes: <String, String>{'aria-label': label},
          child: icon,
        ),
      );
}

/// Reorder / remove cluster shared by the frame list and the action list.
class HuiRowTools extends StatelessWidget {
  const HuiRowTools({
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    required this.removeLabel,
    super.key,
  });

  final void Function()? onMoveUp;
  final void Function()? onMoveDown;
  final void Function() onRemove;
  final String removeLabel;

  @override
  Widget build(BuildContext context) => dom.div(
        classes: 'hui-row-tools',
        styles: const dom.Styles(
          raw: <String, String>{
            'display': 'flex',
            'align-items': 'center',
            'gap': '2px',
            'flex': '0 0 auto',
          },
        ),
        <Widget>[
          HuiIconButton(
            icon: ArcaneIcon.chevronUp(size: IconSize.sm),
            label: 'Move up',
            onPressed: onMoveUp,
          ),
          HuiIconButton(
            icon: ArcaneIcon.chevronDown(size: IconSize.sm),
            label: 'Move down',
            onPressed: onMoveDown,
          ),
          HuiArmedButton(
            label: removeLabel,
            armedLabel: 'Remove',
            icon: ArcaneIcon.trash2(size: IconSize.sm),
            iconOnly: true,
            onConfirm: onRemove,
          ),
        ],
      );
}

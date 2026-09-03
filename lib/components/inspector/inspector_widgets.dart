/// Small shared pieces of the inspector: section rhythm, help notes, inline
/// validation, the two-step destructive button, segmented controls and chips.
///
/// Structural CSS lives in `web/styles/04-inspector.css`; only the bits that
/// must survive a missing stylesheet are inline here.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../config/field_docs.dart';
import '../../logic/validation.dart';
import '../common/common.dart';
import 'field_help.dart';
import 'inspector_session.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

/// One inspector section: uppercase eyebrow, optional trailing control, body.
/// Sections are separated by hairlines, never by nested cards.
///
/// A section with a [sectionKey] is collapsible, and its open state outlives
/// selection changes and document switches in [InspectorSession.sectionOpen].
/// Closing one is a statement about how this author works, not about the
/// component that happened to be selected when they closed it.
class InspectorSection extends StatefulWidget {
  const InspectorSection({
    required this.title,
    required this.children,
    this.trailing,
    this.description,
    this.sectionKey,
    this.initiallyOpen = true,
    this.classes = '',
    this.gap = 10,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  /// Muted sentence under the eyebrow explaining what the section controls.
  final String? description;

  /// Memory key, e.g. `menu.behavior`. Null leaves the section always open and
  /// its head inert, which is what every section that is the whole point of
  /// the pane should stay.
  final String? sectionKey;

  /// The state a section takes the first time this session sees it. Everything
  /// stays open except the genuinely advanced blocks.
  final bool initiallyOpen;
  final String classes;
  final num gap;

  @override
  State<InspectorSection> createState() => _InspectorSectionState();
}

class _InspectorSectionState extends State<InspectorSection> {
  bool get _collapsible => component.sectionKey != null;

  bool get _open =>
      !_collapsible ||
      InspectorSession.isSectionOpen(
        component.sectionKey!,
        fallback: component.initiallyOpen,
      );

  void _toggle() {
    final String? key = component.sectionKey;
    if (key == null) return;
    setState(() => InspectorSession.setSectionOpen(key, !_open));
  }

  @override
  Widget build(BuildContext context) {
    final bool open = _open;
    return dom.section(
      classes: classNames(<String?>[
        'hui-inspector-section',
        _collapsible ? 'is-collapsible' : null,
        _collapsible && !open ? 'is-closed' : null,
        component.classes,
      ]),
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
            if (_collapsible)
              _toggleButton(open)
            else
              HuiEyebrow(component.title),
            if (component.trailing != null)
              dom.div(classes: 'hui-inspector-section-trailing', <Widget>[
                component.trailing!,
              ]),
          ],
        ),
        if (open) ...<Widget>[
          if (component.description != null)
            dom.p(classes: 'hui-inspector-section-note', <Widget>[
              Text(component.description!),
            ]),
          dom.div(
            classes: 'hui-inspector-section-body',
            styles: dom.Styles(
              raw: <String, String>{
                'display': 'flex',
                'flex-direction': 'column',
                'gap': '${component.gap}px',
                'min-width': '0',
              },
            ),
            component.children,
          ),
        ],
      ],
    );
  }

  /// A native button, not an Arcane one: the whole eyebrow is the target, and
  /// the framework button would wrap it in its own padding and focus box.
  Widget _toggleButton(bool open) => dom.button(
    classes: 'hui-inspector-section-toggle',
    attributes: <String, String>{
      'type': 'button',
      'aria-expanded': open ? 'true' : 'false',
      'aria-label': open
          ? huiText('Collapse {title}', <String, Object?>{
              'title': component.title,
            })
          : huiText('Expand {title}', <String, Object?>{
              'title': component.title,
            }),
    },
    events: dom.events<Null>(onClick: _toggle),
    <Widget>[
      dom.span(classes: 'hui-inspector-section-caret', <Widget>[
        open
            ? ArcaneIcon.chevronDown(size: IconSize.sm)
            : ArcaneIcon.chevronRight(size: IconSize.sm),
      ]),
      HuiEyebrow(component.title),
      if (!open)
        dom.span(classes: 'hui-inspector-section-count', <Widget>[
          Text(
            huiText("{length}", <String, Object?>{
              'length': component.children.length,
            }),
          ),
        ]),
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
    summary: dom.span(classes: 'hui-more-summary', <Widget>[Text(summary)]),
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

/// Muted explanatory block with an optional full-surface tone treatment.
enum HuiNoteTone { neutral, info, warning, danger }

class HuiNote extends StatelessWidget {
  const HuiNote(
    this.text, {
    this.tone = HuiNoteTone.neutral,
    this.title,
    super.key,
  });

  final String text;
  final String? title;
  final HuiNoteTone tone;

  String get _toneClass => switch (tone) {
    HuiNoteTone.neutral => 'is-neutral',
    HuiNoteTone.info => 'is-info',
    HuiNoteTone.warning => 'is-warning',
    HuiNoteTone.danger => 'is-danger',
  };

  @override
  Widget build(BuildContext context) => dom.div(
    classes: classNames(<String?>['hui-note', _toneClass]),
    styles: const dom.Styles(
      raw: <String, String>{
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
            if (mono)
              'font-family': 'var(--font-mono, ui-monospace, monospace)',
            if (mono) 'direction': 'ltr',
            if (mono) 'unicode-bidi': 'isolate',
          },
        ),
        <Widget>[Text(value)],
      ),
    ],
  );
}

/// The server-owned revision, as a value with its help rather than as a clause
/// in the header sentence.
///
/// Every Gloss document carries one, and every kind's header used to end with
/// the same "Revision N is server-owned and travels with the file" prose —
/// which read as filler and left the written help for the field with nowhere
/// to mount.
class HuiRevisionRow extends StatelessWidget {
  const HuiRevisionRow({
    required this.revision,
    this.docKey = 'document.revision',
    super.key,
  });

  final int revision;
  final String docKey;

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-revision-row',
    styles: const dom.Styles(
      raw: <String, String>{
        'display': 'flex',
        'align-items': 'center',
        'gap': '4px',
        'min-width': '0',
      },
    ),
    <Widget>[
      dom.div(
        styles: const dom.Styles(
          raw: <String, String>{'flex': '1 1 auto', 'min-width': '0'},
        ),
        <Widget>[HuiDetailRow(huiText('Revision'), '$revision')],
      ),
      HuiFieldHelp(docKey),
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
              Text(
                issue.fix == null
                    ? issue.message
                    : '${issue.message} ${issue.fix!}',
              ),
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
  final ArcaneGlyph? icon;
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
      label: component.label,
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
            label: component.armedLabel ?? huiText('Confirm'),
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
              'aria-label': component.armedLabel ?? huiText('Confirm'),
            },
            label: component.armedLabel ?? huiText('Confirm'),
          ),
        HuiIconButton(
          icon: ArcaneIcon.x(size: IconSize.sm),
          label: huiText('Cancel'),
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
      <Widget>[if (segment.icon != null) segment.icon!, Text(segment.label)],
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
    this.trailing,
    this.disabled = false,
    super.key,
  });

  final String label;
  final bool value;
  final void Function(bool value) onChanged;
  final String? help;

  /// Sits between the label and the switch; the field-help button lives here.
  final Widget? trailing;

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
          dom.span(
            classes: 'hui-switch-row-tail',
            styles: const dom.Styles(
              raw: <String, String>{
                'display': 'inline-flex',
                'align-items': 'center',
                'gap': '2px',
                'flex': '0 0 auto',
              },
            ),
            <Widget>[
              ?trailing,
              ArcaneToggleSwitch(
                value: value,
                disabled: disabled,
                size: ComponentSize.sm,
                onChanged: disabled ? null : onChanged,
              ),
            ],
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

/// Track plus an unclamped number field. HoloUI's JSON path does not clamp
/// `highlightModifier`, so the number entry deliberately allows values the
/// track cannot reach and validation warns instead of the UI blocking.
///
/// A native `input[type=range]`, not `ArcaneSlider`. That renderer emits only
/// `data-arcane-slider-*` and no `events:` map at all, so the injected JS drags
/// the thumb while the store never hears about it. Measured before replacing
/// it: a full-width drag on `highlightModifier` put the thumb at `left: 100%`
/// and left both the number field and the stored value at 0.05. The native
/// input brings real input events, arrow keys, Home/End and a focus ring with
/// it. Same control as the settings dialog's (`settings_dialog.dart`), down to
/// the shared `.hui-range` styling — one widget, two places.
///
/// A drag is one undo step: every input event carries the caller's label, and
/// `_pushUndo`'s coalesce window slides forward on each one, so a gesture only
/// splits if the pointer rests for longer than the window.
class HuiSliderField extends StatelessWidget {
  const HuiSliderField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    this.step = 0.01,
    this.decimals = 3,
    this.numberMin,
    this.numberMax,
    this.resetTo,
    super.key,
  });

  /// Accessible name for the track. `HuiField` renders a `<label>` with no
  /// `for`, so the name has to ride on the input itself.
  final String label;

  final double value;
  final void Function(double value) onChanged;
  final double min;
  final double max;
  final double step;
  final int decimals;

  /// Bounds for the typed entry. Null keeps it unbounded.
  final double? numberMin;
  final double? numberMax;

  /// Value the reset button returns to. Null hides the button.
  final double? resetTo;

  /// Snaps the raw track value onto the step and trims the float noise a
  /// range input reports, so a drag commits the same numbers the step buttons
  /// and the typed entry do.
  double _snap(double raw) {
    final double stepped = step <= 0
        ? raw
        : (raw / step).roundToDouble() * step;
    final num factor = _pow10(decimals);
    return (stepped * factor).roundToDouble() / factor;
  }

  static num _pow10(int digits) {
    num out = 1;
    for (int i = 0; i < digits; i++) {
      out *= 10;
    }
    return out;
  }

  String _text(double raw) {
    final String out = raw.toStringAsFixed(decimals);
    return out.contains('.')
        ? out.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : out;
  }

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-slider-field',
    styles: dom.Styles(
      raw: <String, String>{
        'display': 'grid',
        'grid-template-columns':
            'minmax(0, 1fr) 96px${resetTo == null ? '' : ' auto'}',
        'align-items': 'center',
        'gap': '8px',
        'min-width': '0',
      },
    ),
    <Widget>[
      dom.input<num>(
        type: dom.InputType.range,
        classes: 'hui-range',
        // Clamped for the track only: a value the plugin accepted but the
        // track cannot show still reads correctly in the number field.
        value: value.clamp(min, max).toString(),
        // No setState: the inspector pane rebuilds on the store's notify,
        // and jaspr writes the `value` property rather than the attribute
        // (`dom_render_object.dart:115`), so the thumb follows a typed edit
        // even after the input has been dragged.
        onInput: (num next) => onChanged(_snap(next.toDouble())),
        attributes: <String, String>{
          'min': '$min',
          'max': '$max',
          'step': '$step',
          'aria-label': label,
        },
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
      // Always mounted, disabled when there is nothing to undo: a button
      // that appeared only once the value moved would jump the row width
      // mid-drag.
      if (resetTo != null)
        HuiIconButton(
          icon: ArcaneIcon.rotateCcw(size: IconSize.sm),
          label: huiText("Reset {label} to {text}", <String, Object?>{
            'label': label,
            'text': _text(resetTo!),
          }),
          disabled: value == resetTo,
          onPressed: () => onChanged(resetTo!),
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

  final ArcaneGlyph icon;
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
      icon: icon,
    ),
  );
}

/// Placeholder for a control that is still waiting on an asset fetch.
///
/// Only the catalogue-backed affordances use it: the browse buttons appear the
/// moment `assets/catalog/*.json` resolves, so without a placeholder the field
/// jumps by a row height under whatever the user is already reading. The free
/// text control is never replaced by one — typing a key must work from the
/// first paint, catalogue or no catalogue.
class HuiSkeleton extends StatelessWidget {
  const HuiSkeleton({this.width = '100%', this.height = 26, super.key});

  final String width;
  final num height;

  @override
  Widget build(BuildContext context) => dom.span(
    classes: 'hui-skeleton',
    attributes: const <String, String>{'aria-hidden': 'true'},
    styles: dom.Styles(
      raw: <String, String>{
        'display': 'block',
        'width': width,
        'height': '${height}px',
        'border-radius': 'var(--hui-radius, 6px)',
        'background': 'var(--hui-border-soft, var(--border))',
      },
    ),
    const <Widget>[],
  );
}

/// A stack of [HuiSkeleton] rows with the widths staggered, so a loading list
/// reads as a list rather than as a solid block.
class HuiSkeletonRows extends StatelessWidget {
  const HuiSkeletonRows({this.rows = 3, this.height = 26, super.key});

  final int rows;
  final num height;

  static const List<String> _widths = <String>['100%', '82%', '64%'];

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-skeleton-rows',
    styles: const dom.Styles(
      raw: <String, String>{
        'display': 'flex',
        'flex-direction': 'column',
        'gap': '6px',
        'min-width': '0',
      },
    ),
    <Widget>[
      for (int i = 0; i < rows; i++)
        HuiSkeleton(width: _widths[i % _widths.length], height: height),
    ],
  );
}

/// What an empty list says for itself: the consequence in game first, then the
/// way out of it. Replaces the bare note the lists used to render, which read
/// as a warning about something the user had done rather than as a next step.
class HuiEmptyState extends StatelessWidget {
  const HuiEmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.tone = HuiNoteTone.neutral,
    this.actions = const <Widget>[],
    super.key,
  });

  final Widget icon;
  final String title;
  final String body;
  final HuiNoteTone tone;
  final List<Widget> actions;

  String get _toneClass => switch (tone) {
    HuiNoteTone.neutral => 'is-neutral',
    HuiNoteTone.info => 'is-info',
    HuiNoteTone.warning => 'is-warning',
    HuiNoteTone.danger => 'is-danger',
  };

  @override
  Widget build(BuildContext context) =>
      dom.div(classes: classNames(<String?>['hui-empty', _toneClass]), <Widget>[
        dom.span(classes: 'hui-empty-icon', <Widget>[icon]),
        dom.div(classes: 'hui-empty-text', <Widget>[
          dom.strong(classes: 'hui-empty-title', <Widget>[Text(title)]),
          dom.p(classes: 'hui-empty-body', <Widget>[Text(body)]),
        ]),
        if (actions.isNotEmpty) dom.div(classes: 'hui-empty-actions', actions),
      ]);
}

/// Field help for controls this pane composes but does not own.
///
/// The item, custom-item and text bodies live in their own editors, so their
/// help cannot ride in a [HuiField.trailing] slot the way every other field's
/// does. Grouping the affordances under the type switch keeps the same 28 doc
/// keys reachable without reaching across file ownership.
class HuiHelpCluster extends StatelessWidget {
  const HuiHelpCluster(this.docKeys, {this.label, super.key});

  final List<String> docKeys;

  /// Optional lead-in, e.g. `Item icon`.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final List<String> known = docKeys
        .where((String key) => huiFieldDoc(key) != null)
        .toList();
    if (known.isEmpty) return const dom.span(<Widget>[]);
    return dom.div(classes: 'hui-help-cluster', <Widget>[
      if (label != null)
        dom.span(classes: 'hui-help-cluster-label', <Widget>[Text(label!)]),
      for (final String key in known)
        dom.span(classes: 'hui-help-cluster-item', <Widget>[
          Text(huiFieldDoc(key)!.title),
          HuiFieldHelp(key, align: HuiFieldHelpAlign.start),
        ]),
    ]);
  }
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
        label: huiText('Move up'),
        onPressed: onMoveUp,
      ),
      HuiIconButton(
        icon: ArcaneIcon.chevronDown(size: IconSize.sm),
        label: huiText('Move down'),
        onPressed: onMoveDown,
      ),
      HuiArmedButton(
        label: removeLabel,
        armedLabel: huiText('Remove'),
        icon: ArcaneIcon.trash2(size: IconSize.sm),
        iconOnly: true,
        onConfirm: onRemove,
      ),
    ],
  );
}

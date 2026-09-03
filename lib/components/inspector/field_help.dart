/// On-demand help popover: one runtime trap, said in full, only when asked.
///
/// Hand-built rather than `ArcanePopover`. The framework popover does fire its
/// open callback in this version, but its open state lives in the JS runtime,
/// which writes inline styles and attributes onto nodes Jaspr manages — and the
/// inspector rebuilds this subtree on every keystroke. Owning the flag in Dart
/// keeps the card alive through those rebuilds and lets Escape and the outside
/// click close it on our terms rather than the runtime's.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:arcane_jaspr/core/dom_value.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show EventCallback;

import '../../config/field_docs.dart';
import '../common/class_names.dart';
import 'dom_bridge.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

/// Which edge of the trigger the card lines up with. The inspector is narrow,
/// so a card hanging off the right edge is the usual choice.
enum HuiFieldHelpAlign { start, end }

/// [HuiHelpPopover] fed from [huiFieldDocs].
class HuiFieldHelp extends StatelessWidget {
  const HuiFieldHelp(
    this.docKey, {
    this.align = HuiFieldHelpAlign.end,
    super.key,
  });

  /// Key into [huiFieldDocs]. An unknown key renders nothing at all, so a
  /// mistyped key costs a missing button, never a broken row.
  final String docKey;
  final HuiFieldHelpAlign align;

  @override
  Widget build(BuildContext context) {
    final HuiFieldDoc? doc = huiFieldDoc(docKey);
    if (doc == null) return const dom.span(<Widget>[]);
    return HuiHelpPopover(
      title: doc.title,
      body: doc.body,
      citation: doc.citation,
      triggerLabel: huiText("What {title} does", <String, Object?>{
        'title': doc.title,
      }),
      align: align,
    );
  }
}

/// A question-mark button and the card it opens.
class HuiHelpPopover extends StatefulWidget {
  const HuiHelpPopover({
    required this.title,
    required this.body,
    required this.triggerLabel,
    this.citation,
    this.align = HuiFieldHelpAlign.end,
    super.key,
  });

  final String title;
  final String body;

  /// Source line the claim comes from, in a mono face under the body.
  final String? citation;

  /// The trigger's accessible name; the card's is [title].
  final String triggerLabel;
  final HuiFieldHelpAlign align;

  @override
  State<HuiHelpPopover> createState() => _HuiHelpPopoverState();
}

class _HuiHelpPopoverState extends State<HuiHelpPopover> {
  bool _open = false;

  /// Per-instance, because one doc key can appear twice in a single pane (a
  /// toggle shows two `Text` rows), so the key alone would not be unique.
  late final int _seq = _nextSeq++;

  String get _triggerId => 'hui-help-t$_seq';

  String get _cardId => 'hui-help-c$_seq';

  static int _nextSeq = 0;

  void _onKeyDown(Object? event) {
    if (!_open || domEventKey(event) != 'Escape') return;
    // Swallowed so the shell's document-level Escape binder does not also run.
    domPreventDefault(event);
    domStopPropagation(event);
    _close();
  }

  /// Focus moves into the card on open and back to the trigger on close.
  ///
  /// Without this the keydown handler above was dead: the Arcane button's
  /// mousedown `preventDefault` leaves focus wherever it was — typically the
  /// text field the user was editing — so Escape never reached this subtree and
  /// the popover stayed open. Measured before the fix on the menu inspector,
  /// where there is no selection for Escape to clear and the card simply sat
  /// there.
  void _toggle() {
    if (_open) {
      _close();
      return;
    }
    setState(() => _open = true);
    // Post-frame, not inline: the card does not exist in the DOM until this
    // setState has been rendered, so focusing it synchronously silently found
    // nothing and left focus on the field the user came from.
    _focusAfterFrame(_cardId);
  }

  void _close() {
    setState(() => _open = false);
    _focusAfterFrame(_triggerId);
  }

  void _focusAfterFrame(String elementId) {
    context.binding.addPostFrameCallback(() {
      if (!mounted) return;
      focusElement(elementId);
    });
  }

  @override
  Widget build(BuildContext context) => dom.span(
    classes: classNames(<String?>['hui-field-help', _open ? 'is-open' : null]),
    styles: const dom.Styles(
      raw: <String, String>{
        'position': 'relative',
        'display': 'inline-flex',
        'flex': '0 0 auto',
      },
    ),
    events: <String, EventCallback>{'keydown': _onKeyDown},
    <Widget>[
      Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.iconSm,
        onPressed: _toggle,
        attributes: <String, String>{
          'id': _triggerId,
          'aria-label': component.triggerLabel,
          'aria-expanded': _open ? 'true' : 'false',
          // Opt out of the legacy accordion binder, which would otherwise
          // flip `aria-expanded` behind Dart's back and hide the scrim it
          // finds as this button's next sibling
          // (accordion_scripts.dart:8).
          'data-arcane-interactive': 'true',
        },
        icon: ArcaneIcon.circleQuestionMark(size: IconSize.sm),
      ),
      if (_open) ..._popover(),
    ],
  );

  /// Scrim first, card second: siblings, so a click on the card never reaches
  /// the scrim and no `stopPropagation` bookkeeping is needed. The scrim is
  /// fixed rather than document-wide listeners, which keeps outside-click
  /// dismissal entirely inside this subtree.
  List<Widget> _popover() => <Widget>[
    dom.div(
      classes: 'hui-field-help-scrim',
      styles: const dom.Styles(
        raw: <String, String>{
          'position': 'fixed',
          'inset': '0',
          'z-index': '60',
          'background': 'transparent',
        },
      ),
      events: dom.events<Null>(onClick: _close),
      const <Widget>[],
    ),
    dom.div(
      classes: 'hui-field-help-card',
      attributes: <String, String>{
        'id': _cardId,
        'role': 'dialog',
        'aria-label': component.title,
        // Focusable only programmatically: the card is not a tab stop, but
        // it has to be able to hold focus so Escape lands in this subtree.
        'tabindex': '-1',
      },
      styles: dom.Styles(
        raw: <String, String>{
          'position': 'absolute',
          'top': 'calc(100% + 6px)',
          if (component.align == HuiFieldHelpAlign.end)
            'right': '0'
          else
            'left': '0',
          'z-index': '61',
          'width': 'min(300px, 78vw)',
          'padding': '10px 12px',
          'border': '1px solid var(--border)',
          'border-radius': 'var(--hui-radius, 0px)',
          'background': 'var(--popover, var(--card, var(--background)))',
          'color': 'var(--popover-foreground, var(--foreground))',
          'box-shadow': '0 10px 30px rgb(0 0 0 / 0.22)',
          'text-align': 'left',
          'white-space': 'normal',
        },
      ),
      <Widget>[
        dom.strong(
          classes: 'hui-field-help-title',
          styles: const dom.Styles(
            raw: <String, String>{
              'display': 'block',
              'font-size': '0.76rem',
              'font-weight': '650',
              'letter-spacing': '-0.01em',
            },
          ),
          <Widget>[Text(component.title)],
        ),
        dom.p(
          classes: 'hui-field-help-body',
          styles: const dom.Styles(
            raw: <String, String>{
              'margin': '6px 0 0',
              'font-size': '0.74rem',
              'line-height': '1.5',
              'color': 'var(--muted-foreground)',
            },
          ),
          <Widget>[Text(component.body)],
        ),
        if (component.citation != null)
          dom.code(
            classes: 'hui-field-help-citation',
            styles: const dom.Styles(
              raw: <String, String>{
                'display': 'block',
                'margin-top': '8px',
                'font-size': '0.68rem',
                'font-family': 'var(--font-mono, ui-monospace, monospace)',
                'color': 'var(--muted-foreground)',
                'overflow-wrap': 'anywhere',
              },
            ),
            <Widget>[Text(component.citation!)],
          ),
      ],
    ),
  ];
}

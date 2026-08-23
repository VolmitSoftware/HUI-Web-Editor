/// Everything the code pane paints that has no state of its own.
///
/// Split off [CodeEditorView] so the pane's file stays about the buffer — sync,
/// commit, keyboard, hover hit-testing — rather than about markup. Each widget
/// here takes the values it draws and hands its interactions straight back; not
/// one of them reads the store or the buffer.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:arcane_jaspr/core/dom_value.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show EventCallback;

import '../../logic/validation.dart';
import '../common/common.dart';
import 'code_completion.dart';
import 'code_hover.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

/// The one place the pane says, in words, whether the document has the text.
class HuiCodeStateChip extends StatelessWidget {
  const HuiCodeStateChip({required this.dirty, required this.saved, super.key});

  final bool dirty;

  /// True only just after a save, so "Saved" is a confirmation of something
  /// that happened rather than a permanent label on a clean buffer.
  final bool saved;

  @override
  Widget build(BuildContext context) => dom.span(
    classes: classNames(<String?>[
      'hui-code-state',
      dirty ? 'is-dirty' : 'is-clean',
    ]),
    attributes: const <String, String>{'aria-live': 'polite'},
    <Widget>[
      if (dirty)
        ArcaneIcon.circleDot(size: IconSize.xs)
      else
        ArcaneIcon.circleCheck(size: IconSize.xs),
      dom.span(<Widget>[
        Text(
          dirty
              ? huiText('Unsaved changes')
              : saved
              ? huiText('Saved')
              : huiText('Matches the document'),
        ),
      ]),
    ],
  );
}

/// Loud, and only ever raised by something the user did: a refused save, or a
/// format that could not parse.
class HuiCodeErrorStrip extends StatelessWidget {
  const HuiCodeErrorStrip(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-code-error',
    attributes: const <String, String>{'role': 'alert'},
    <Widget>[
      ArcaneIcon.circleAlert(size: IconSize.sm),
      dom.span(classes: 'hui-code-error-text', <Widget>[
        Text(
          huiText(
            "{message} — nothing was committed, your text is untouched.",
            <String, Object?>{'message': message},
          ),
        ),
      ]),
    ],
  );
}

/// A standing statement about the buffer, with the choices that answer it.
class HuiCodeNotice extends StatelessWidget {
  const HuiCodeNotice({
    required this.message,
    required this.actions,
    this.warning = false,
    super.key,
  });

  final String message;
  final List<Widget> actions;

  /// Warnings carry the triangle; everything else carries the info circle.
  final bool warning;

  @override
  Widget build(BuildContext context) => dom.div(
    classes: classNames(<String?>[
      'hui-code-notice',
      warning ? 'is-warning' : null,
    ]),
    attributes: const <String, String>{'role': 'status'},
    <Widget>[
      if (warning)
        ArcaneIcon.triangleAlert(size: IconSize.sm)
      else
        ArcaneIcon.circleAlert(size: IconSize.sm),
      dom.span(classes: 'hui-code-notice-text', <Widget>[Text(message)]),
      dom.div(classes: 'hui-code-notice-tools', actions),
    ],
  );
}

/// The Ctrl+Space list, floated at the caret.
///
/// Rows accept on `mousedown` rather than `click`: a click would move focus off
/// the textarea first, and the caret the insertion is measured against would be
/// gone by the time the handler ran.
class HuiCodeCompletionPopup extends StatelessWidget {
  const HuiCodeCompletionPopup({
    required this.items,
    required this.index,
    required this.x,
    required this.y,
    required this.onAccept,
    required this.onHover,
    super.key,
  });

  final List<HuiCompletion> items;
  final int index;

  /// Viewport coordinates of the caret the popup hangs from.
  final double x;
  final double y;

  final void Function(int index) onAccept;
  final void Function(int index) onHover;

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-code-complete',
    attributes: <String, String>{
      'role': 'listbox',
      'aria-label': huiText('JSON completion'),
    },
    styles: dom.Styles(
      raw: <String, String>{
        'left': 'clamp(8px, ${x.round()}px, calc(100vw - 348px))',
        'top': '${y.round()}px',
      },
    ),
    <Widget>[for (int i = 0; i < items.length; i++) _row(items[i], i)],
  );

  Widget _row(HuiCompletion item, int at) => dom.div(
    classes: classNames(<String?>[
      'hui-code-complete-row',
      at == index ? 'is-active' : null,
      item.isDefault ? 'is-default' : null,
    ]),
    attributes: <String, String>{
      'role': 'option',
      'aria-selected': at == index ? 'true' : 'false',
    },
    events: <String, EventCallback>{
      'mousedown': (Object? event) {
        domPreventDefault(event);
        onAccept(at);
      },
      'mousemove': (Object? event) => onHover(at),
    },
    <Widget>[
      dom.div(classes: 'hui-code-complete-head', <Widget>[
        dom.code(classes: 'hui-code-complete-label', <Widget>[
          Text(item.label),
        ]),
        dom.span(classes: 'hui-code-complete-detail', <Widget>[
          Text(item.detail),
        ]),
      ]),
      if (item.description.isNotEmpty)
        dom.span(classes: 'hui-code-complete-desc', <Widget>[
          Text(item.description),
        ]),
    ],
  );
}

/// The key explanation, on the app's own tooltip surface.
///
/// The classes are `11-tooltip-overlay.css`'s, not a second look invented here:
/// the shared overlay script cannot drive this card, because it triggers on
/// `mouseover`, which fires once as the pointer enters the textarea and never
/// again as it crosses from one key to the next.
class HuiCodeHoverCard extends StatelessWidget {
  const HuiCodeHoverCard({
    required this.doc,
    required this.x,
    required this.y,
    super.key,
  });

  final HuiCodeKeyDoc doc;
  final double x;
  final double y;

  @override
  Widget build(BuildContext context) => dom.div(
    classes:
        'gloss-tooltip-overlay-content gloss-tooltip-overlay-rich is-visible '
        'hui-code-hovercard',
    attributes: const <String, String>{'role': 'tooltip'},
    styles: dom.Styles(
      raw: <String, String>{
        'left': 'clamp(8px, ${x.round()}px, calc(100vw - 336px))',
        'top': '${y.round()}px',
      },
    ),
    <Widget>[
      dom.strong(classes: 'hui-code-hovercard-title', <Widget>[
        Text(doc.title),
      ]),
      dom.code(classes: 'hui-code-hovercard-path', <Widget>[Text(doc.path)]),
      dom.span(classes: 'hui-code-hovercard-body', <Widget>[Text(doc.body)]),
      if (doc.detail.isNotEmpty)
        dom.span(classes: 'hui-code-hovercard-detail', <Widget>[
          Text(doc.detail),
        ]),
      if (doc.citation != null)
        dom.code(classes: 'hui-code-hovercard-citation', <Widget>[
          Text(doc.citation!),
        ]),
    ],
  );
}

/// The validation strip under the editor. Reports the document's issues, not
/// the buffer's: nothing here moves until a save lands.
class HuiCodeIssueList extends StatelessWidget {
  const HuiCodeIssueList(this.issues, {super.key});

  final List<HuiIssue> issues;

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-code-issues',
    <Widget>[
      dom.div(classes: 'hui-code-issues-head', <Widget>[
        HuiEyebrow(
          issues.isEmpty
              ? huiText('no issues')
              : huiPlural(
                  'code.issue-count',
                  issues.length,
                  oneEnglish: '{count} issue',
                  otherEnglish: '{count} issues',
                ),
        ),
      ]),
      if (issues.isEmpty)
        dom.p(classes: 'hui-code-issues-empty', <Widget>[
          Text(huiText('This document matches everything the plugin expects.')),
        ])
      else
        dom.ul(classes: 'hui-code-issues-list', <Widget>[
          for (final HuiIssue issue in issues)
            dom.li(
              classes: classNames(<String?>[
                'hui-code-issue',
                switch (issue.severity) {
                  HuiSeverity.error => 'is-error',
                  HuiSeverity.warning => 'is-warning',
                  HuiSeverity.info => 'is-info',
                },
              ]),
              <Widget>[
                dom.code(classes: 'hui-code-issue-path', <Widget>[
                  Text(issue.path),
                ]),
                dom.span(classes: 'hui-code-issue-message', <Widget>[
                  Text(issue.message),
                ]),
              ],
            ),
        ]),
    ],
  );
}

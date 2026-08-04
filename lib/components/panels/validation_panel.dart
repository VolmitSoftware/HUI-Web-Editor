/// Bottom sheet listing every semantic issue in the current document.
///
/// Issues come from `validateHuiMenu`, which encodes the Java parser's real
/// behaviour rather than the stale shipped JSON schema, so an "error" here means
/// the plugin will actually refuse or misbehave — not merely that a key is
/// missing from the schema.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show ListenableBuilder;

import '../../logic/validation.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';

class ValidationPanel extends StatelessWidget {
  const ValidationPanel({
    required this.store,
    required this.isOpen,
    required this.onClose,
    super.key,
  });

  final EditorStore store;
  final bool isOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => ArcaneSheet.bottom(
        id: 'hui-validation-sheet',
        isOpen: isOpen,
        onClose: onClose,
        size: SheetSize.md,
        title: 'Validation',
        description:
            'Checked against the plugin parser, not the shipped JSON schema.',
        // The sheet chrome's own close control is JS-only: it hides the
        // surface without telling Dart, which owns isOpen, so the sheet
        // reappears on the next rebuild. The footer button below closes it
        // through Dart instead.
        showCloseButton: false,
        footer: dom.div(
          classes: 'hui-validation-footer',
          <Widget>[
            Button.outline(label: 'Close', onPressed: onClose),
          ],
        ),
        child: ListenableBuilder(
          listenable: store,
          builder: (BuildContext inner) => _body(),
        ),
      );

  Widget _body() {
    final List<HuiIssue> issues = store.issues;
    if (issues.isEmpty) {
      return dom.div(
        classes: 'hui-validation hui-validation-clean',
        <Widget>[
          ArcaneEmptyState(
            title: 'No issues',
            description: 'This menu matches everything the plugin expects. '
                'Export it to plugins/holoui/menus/${store.exportFileName}.',
            icon: ArcaneIcon.check(size: IconSize.lg),
          ),
        ],
      );
    }

    return dom.div(
      classes: 'hui-validation',
      <Widget>[
        _summaryStrip(),
        for (final HuiSeverity severity in HuiSeverity.values)
          ..._group(severity, issues),
      ],
    );
  }

  Widget _summaryStrip() => dom.div(
        classes: 'hui-validation-strip',
        <Widget>[
          _summaryCell('Errors', store.errorCount, 'is-error'),
          _summaryCell('Warnings', store.warningCount, 'is-warning'),
          _summaryCell('Notes', store.infoCount, 'is-info'),
        ],
      );

  Widget _summaryCell(String label, int count, String tone) => dom.div(
        classes: classNames(<String?>['hui-validation-cell', tone]),
        <Widget>[
          dom.span(
            classes: 'hui-validation-cell-value',
            <Widget>[Text('$count')],
          ),
          dom.span(
            classes: 'hui-validation-cell-label',
            <Widget>[Text(label)],
          ),
        ],
      );

  List<Widget> _group(HuiSeverity severity, List<HuiIssue> all) {
    final List<HuiIssue> group =
        all.where((HuiIssue issue) => issue.severity == severity).toList();
    if (group.isEmpty) return const <Widget>[];
    return <Widget>[
      dom.div(
        classes: classNames(<String?>[
          'hui-validation-group',
          _toneClass(severity),
        ]),
        <Widget>[
          dom.div(
            classes: 'hui-validation-group-head',
            <Widget>[
              _severityIcon(severity),
              // A plain span, not HuiEyebrow: the primitive sets its colour
              // inline, which would beat the per-severity tint.
              dom.span(
                classes: 'hui-eyebrow',
                <Widget>[
                  Text('${_severityLabel(severity)} (${group.length})'),
                ],
              ),
            ],
          ),
          dom.ul(
            classes: 'hui-validation-list',
            <Widget>[for (final HuiIssue issue in group) _row(issue)],
          ),
        ],
      ),
    ];
  }

  Widget _row(HuiIssue issue) {
    final String? componentId = issue.componentId;
    return dom.li(
      classes: 'hui-validation-row',
      <Widget>[
        dom.div(
          classes: 'hui-validation-body',
          <Widget>[
            dom.p(
              classes: 'hui-validation-message',
              <Widget>[Text(issue.message)],
            ),
            if (issue.fix != null)
              dom.p(
                classes: 'hui-validation-fix',
                <Widget>[Text('Fix: ${issue.fix!}')],
              ),
            dom.code(
              classes: 'hui-validation-path',
              <Widget>[Text(issue.path)],
            ),
          ],
        ),
        if (componentId != null)
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.small,
            onPressed: () {
              store.select(componentId);
              onClose();
            },
            icon: ArcaneIcon.crosshair(size: IconSize.sm),
            label: componentId,
            attributes: <String, String>{
              'aria-label': 'Select component $componentId',
            },
          ),
      ],
    );
  }

  Widget _severityIcon(HuiSeverity severity) => switch (severity) {
        HuiSeverity.error => ArcaneIcon.circleAlert(size: IconSize.sm),
        HuiSeverity.warning => ArcaneIcon.triangleAlert(size: IconSize.sm),
        HuiSeverity.info => ArcaneIcon.info(size: IconSize.sm),
      };

  String _severityLabel(HuiSeverity severity) => switch (severity) {
        HuiSeverity.error => 'Errors',
        HuiSeverity.warning => 'Warnings',
        HuiSeverity.info => 'Notes',
      };

  String _toneClass(HuiSeverity severity) => switch (severity) {
        HuiSeverity.error => 'is-error',
        HuiSeverity.warning => 'is-warning',
        HuiSeverity.info => 'is-info',
      };
}

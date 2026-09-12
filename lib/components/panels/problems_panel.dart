/// Bottom sheet listing what the server found wrong with the workspace.
///
/// These are the plugin's own findings, not the editor's: `/gloss check` runs
/// the same rules and reports the same codes, and they travel in the sync
/// project's `warnings` array. The editor's own validation stays in the
/// validation panel beside this one, because the two answer different
/// questions — this one knows about documents the browser never opened.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/sync_problems.dart';
import '../common/class_names.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class ProblemsPanel extends StatelessWidget {
  const ProblemsPanel({
    required this.problems,
    required this.isOpen,
    required this.onClose,
    this.conflicts = const <SyncConflict>[],
    this.onOpenDocument,
    super.key,
  });

  final SyncProblems problems;

  /// Documents the last publication could not overwrite because they moved on
  /// the server. Everything else in that publication landed.
  final List<SyncConflict> conflicts;
  final bool isOpen;
  final VoidCallback onClose;

  /// Opens the document a finding names, when the workspace has it.
  final void Function(String kind, String id)? onOpenDocument;

  @override
  Widget build(BuildContext context) => ArcaneSheet.bottom(
    id: 'hui-problems-sheet',
    isOpen: isOpen,
    onClose: onClose,
    size: SheetSize.md,
    title: huiText('Server problems'),
    description: huiText(
      'Found by the plugin across the whole workspace, including documents this browser never opened.',
    ),
    showCloseButton: false,
    footer: dom.div(classes: 'hui-validation-footer', <Widget>[
      Button.outline(label: huiText('Close'), onPressed: onClose),
    ]),
    child: _body(),
  );

  Widget _body() {
    if (problems.isEmpty && conflicts.isEmpty) {
      return dom.div(classes: 'hui-validation hui-validation-clean', <Widget>[
        ArcaneEmptyState(
          title: huiText('Nothing to report'),
          description: huiText(
            'The server checked every document it has and found no broken references.',
          ),
          icon: ArcaneIcon.check(size: IconSize.lg),
        ),
      ]);
    }
    return dom.div(classes: 'hui-validation', <Widget>[
      _summaryStrip(),
      if (conflicts.isNotEmpty) _conflicts(),
      for (final SyncProblemGroup group in problems.groups) _group(group),
    ]);
  }

  Widget _summaryStrip() => dom.div(classes: 'hui-validation-strip', <Widget>[
    _summaryCell('Errors', problems.errorCount, 'is-error'),
    _summaryCell('Warnings', problems.warningCount, 'is-warning'),
  ]);

  Widget _summaryCell(String label, int count, String tone) => dom.div(
    classes: classNames(<String?>['hui-validation-cell', tone]),
    <Widget>[
      dom.span(classes: 'hui-validation-cell-value', <Widget>[
        Text(huiText("{count}", <String, Object?>{'count': count})),
      ]),
      dom.span(classes: 'hui-validation-cell-label', <Widget>[
        Text(huiText(label)),
      ]),
    ],
  );

  /// Per-document conflicts from the last publication. They are not lint
  /// findings, so they get their own block rather than being mixed in.
  Widget _conflicts() => dom.div(
    classes: 'hui-validation-group is-warning',
    <Widget>[
      dom.div(classes: 'hui-validation-group-head', <Widget>[
        ArcaneIcon.triangleAlert(size: IconSize.sm),
        dom.span(classes: 'hui-eyebrow', <Widget>[
          Text(
            huiText("Kept the server copy ({length})", <String, Object?>{
              'length': conflicts.length,
            }),
          ),
        ]),
      ]),
      dom.ul(classes: 'hui-validation-list', <Widget>[
        for (final SyncConflict conflict in conflicts)
          dom.li(classes: 'hui-validation-row is-warning', <Widget>[
            dom.div(classes: 'hui-validation-body', <Widget>[
              dom.p(classes: 'hui-validation-message', <Widget>[
                Text(
                  huiText(
                    "{kind} {id} changed on the server, so your version was not written.",
                    <String, Object?>{
                      'kind': conflict.kind,
                      'id': conflict.id,
                    },
                  ),
                ),
              ]),
            ]),
            if (onOpenDocument != null)
              Button(
                variant: ButtonVariant.outline,
                size: ButtonSize.small,
                onPressed: () {
                  onOpenDocument!(conflict.kind, conflict.id);
                  onClose();
                },
                icon: ArcaneIcon.crosshair(size: IconSize.sm),
                label: huiText('Open'),
              ),
          ]),
      ]),
    ],
  );

  Widget _group(SyncProblemGroup group) => dom.div(
    classes: 'hui-validation-group',
    <Widget>[
      dom.div(classes: 'hui-validation-group-head', <Widget>[
        ArcaneIcon.fileText(size: IconSize.sm),
        dom.span(classes: 'hui-eyebrow', <Widget>[
          Text(
            huiText("{severityLabel} ({length})", <String, Object?>{
              'severityLabel': group.label,
              'length': group.problems.length,
            }),
          ),
        ]),
        if (!group.isWorkspace && onOpenDocument != null)
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.small,
            onPressed: () {
              onOpenDocument!(group.kind, group.id);
              onClose();
            },
            icon: ArcaneIcon.crosshair(size: IconSize.sm),
            label: huiText('Open'),
            attributes: <String, String>{
              'aria-label': huiText(
                "Open {value}",
                <String, Object?>{'value': group.label},
              ),
            },
          ),
      ]),
      dom.ul(classes: 'hui-validation-list', <Widget>[
        for (final SyncProblem problem in group.problems) _row(problem),
      ]),
    ],
  );

  Widget _row(SyncProblem problem) => dom.li(
    classes: classNames(<String?>['hui-validation-row', _tone(problem)]),
    <Widget>[
      dom.div(classes: 'hui-validation-body', <Widget>[
        dom.p(classes: 'hui-validation-message', <Widget>[
          Text(problem.message),
        ]),
        if (problem.code.isNotEmpty)
          dom.code(classes: 'hui-validation-path', <Widget>[
            Text(
              problem.pointer.isEmpty
                  ? problem.code
                  : '${problem.code} ${problem.pointer}',
            ),
          ]),
      ]),
    ],
  );

  String _tone(SyncProblem problem) => switch (problem.severity) {
    SyncProblemSeverity.error => 'is-error',
    SyncProblemSeverity.warning => 'is-warning',
    SyncProblemSeverity.info => 'is-info',
  };
}

import 'package:gloss_editor/logic/sync_problems.dart';
import 'package:test/test.dart';

/// The plugin's workspace linter reports through the sync project's `warnings`
/// array in a fixed `code|kind|id|pointer|message` shape. The Problems panel
/// reads that shape; a warning that is a plain sentence stays a plain sentence
/// rather than being parsed into a wrong row.
void main() {
  test('a coded warning splits into its five parts', () {
    final SyncProblems problems = SyncProblems.of(<String>[
      'dangling-navigate|menus|root|/components/0/data/actions/0/target|'
          'navigates to a menu that does not exist: missing',
    ]);

    final SyncProblem problem = problems.all.single;
    expect(problem.code, 'dangling-navigate');
    expect(problem.kind, 'menus');
    expect(problem.id, 'root');
    expect(problem.pointer, '/components/0/data/actions/0/target');
    expect(problem.message, 'navigates to a menu that does not exist: missing');
    expect(problem.severity, SyncProblemSeverity.error);
  });

  test('a plain sentence is kept whole with no document behind it', () {
    final SyncProblems problems = SyncProblems.of(<String>[
      'Referenced menu is not loaded: shop',
    ]);

    final SyncProblem problem = problems.all.single;
    expect(problem.code, isEmpty);
    expect(problem.kind, isEmpty);
    expect(problem.message, 'Referenced menu is not loaded: shop');
    expect(problem.severity, SyncProblemSeverity.warning);
    expect(problem.hasDocument, isFalse);
  });

  test('severity comes from the code, not from the message', () {
    final SyncProblems problems = SyncProblems.of(<String>[
      'image-missing|menus|root|/a|gone',
      'papi-expansion-missing|menus|root|/b|gone',
      'schema-skipped|animations|old||unsupported schemaVersion',
    ]);

    expect(
      problems.all.map((SyncProblem problem) => problem.severity),
      <SyncProblemSeverity>[
        SyncProblemSeverity.error,
        SyncProblemSeverity.warning,
        SyncProblemSeverity.warning,
      ],
    );
    expect(problems.errorCount, 1);
    expect(problems.warningCount, 2);
  });

  test('rows group by document in kind then id order', () {
    final SyncProblems problems = SyncProblems.of(<String>[
      'image-missing|menus|shop|/b|gone',
      'image-missing|boards|lobby|/a|gone',
      'image-missing|menus|shop|/c|gone',
      'a plain sentence',
    ]);

    expect(
      problems.groups.map((SyncProblemGroup group) => group.label),
      <String>['boards lobby', 'menus shop', 'Workspace'],
    );
    expect(problems.groups[1].problems, hasLength(2));
  });

  test('a malformed coded warning never loses its text', () {
    final SyncProblems problems = SyncProblems.of(<String>['broken|only|two']);

    expect(problems.all.single.message, 'broken|only|two');
    expect(problems.all.single.code, isEmpty);
  });

  test('a field pointer names the field it blames', () {
    final SyncProblem problem = SyncProblems.of(<String>[
      'dangling-navigate|menus|root|/components/0/data/actions/0/target|gone',
    ]).all.single;

    expect(problem.fieldName, 'target');
    expect(SyncProblems.of(<String>['x|a|b||m']).all.single.fieldName, isNull);
  });
}

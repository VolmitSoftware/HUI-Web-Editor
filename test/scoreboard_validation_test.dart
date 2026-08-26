import 'package:gloss_editor/logic/scoreboard_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

GlossScoreboardDoc _valid() => GlossScoreboardDoc(
  select: GlossScoreboardSelect(when: 'true'),
  presentation: GlossScoreboardPresentation(
    title: '&d&lGloss',
    lines: <String>['&fWelcome!'],
  ),
);

void main() {
  test('canonical default validates cleanly', () {
    expect(validateScoreboardDoc(_valid()), isEmpty);
  });

  test('invalid condition syntax is a hard error at its canonical path', () {
    final GlossScoreboardDoc doc = _valid()..select.when = 'health <';
    final HuiIssue issue = validateScoreboardDoc(doc).single;
    expect(issue.severity, HuiSeverity.error);
    expect(issue.path, r'$.select.when');
  });

  test('constant non-boolean conditions are rejected', () {
    final GlossScoreboardDoc doc = _valid()..select.when = '5';
    expect(validateScoreboardDoc(doc).single.path, r'$.select.when');
  });

  test('duplicate and blank variant ids are errors', () {
    final GlossScoreboardDoc doc = _valid()
      ..variants = <GlossScoreboardVariant>[
        GlossScoreboardVariant(id: 'same', when: 'true'),
        GlossScoreboardVariant(id: 'same', when: 'true'),
        GlossScoreboardVariant(id: '', when: 'true'),
      ];
    final List<HuiIssue> issues = validateScoreboardDoc(doc);
    expect(
      issues.where((HuiIssue issue) => issue.path.endsWith('.id')),
      hasLength(2),
    );
  });

  test('variant ids use the runtime character set after trimming', () {
    final GlossScoreboardDoc doc = _valid()
      ..variants = <GlossScoreboardVariant>[
        GlossScoreboardVariant(id: ' repeated ', when: 'true'),
        GlossScoreboardVariant(id: 'repeated', when: 'true'),
        GlossScoreboardVariant(id: 'bad/id', when: 'true'),
      ];
    final Iterable<HuiIssue> issues = validateScoreboardDoc(
      doc,
    ).where((HuiIssue issue) => issue.path.endsWith('.id'));
    expect(issues, hasLength(2));
  });

  test('full-width title and row do not produce length warnings', () {
    final GlossScoreboardDoc doc = _valid()
      ..variants.add(
        GlossScoreboardVariant(
          id: 'long',
          when: 'true',
          presentation: GlossScoreboardPresentation(
            title: 'x' * 33,
            lines: <String>['x' * 33],
          ),
        ),
      );
    expect(validateScoreboardDoc(doc), isEmpty);
  });

  test('more than fifteen lines warns at the nested presentation path', () {
    final GlossScoreboardDoc doc = _valid()
      ..presentation.lines = <String>[
        for (int index = 0; index < 16; index++) 'line $index',
      ];
    expect(validateScoreboardDoc(doc).single.path, r'$.presentation.lines');
  });
}

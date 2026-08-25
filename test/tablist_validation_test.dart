import 'package:gloss_editor/logic/tablist_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

GlossTablistDoc _valid() => GlossTablistDoc(
  headerFooter: GlossTablistHeaderFooter(
    enabled: true,
    presentation: GlossTablistHeaderFooterPresentation(
      header: '&d&lGloss',
      footer: '&7Footer',
    ),
  ),
  listNames: GlossTablistListNames(
    enabled: true,
    presentation: GlossTablistListNamePresentation(),
  ),
);

void main() {
  test('canonical default validates cleanly', () {
    expect(validateTablistDoc(_valid()), isEmpty);
  });

  test('invalid conditions are errors at their section path', () {
    final GlossTablistDoc doc = _valid()
      ..headerFooter.variants.add(
        GlossTablistHeaderFooterVariant(id: 'bad', when: 'viewer.health <'),
      );
    final HuiIssue issue = validateTablistDoc(doc).single;
    expect(issue.severity, HuiSeverity.error);
    expect(issue.path, r'$.headerFooter.variants[0].when');
  });

  test('duplicate ids are checked independently within both sections', () {
    final GlossTablistDoc doc = _valid()
      ..listNames.variants = <GlossTablistListNameVariant>[
        GlossTablistListNameVariant(id: 'vip', when: 'true'),
        GlossTablistListNameVariant(id: 'vip', when: 'true'),
      ];
    expect(validateTablistDoc(doc).single.path, r'$.listNames.variants[1].id');
  });

  test('variant ids use the runtime character set after trimming', () {
    final GlossTablistDoc doc = _valid()
      ..headerFooter.variants = <GlossTablistHeaderFooterVariant>[
        GlossTablistHeaderFooterVariant(id: ' repeated ', when: 'true'),
        GlossTablistHeaderFooterVariant(id: 'repeated', when: 'true'),
        GlossTablistHeaderFooterVariant(id: 'bad/id', when: 'true'),
      ];
    final Iterable<HuiIssue> issues = validateTablistDoc(
      doc,
    ).where((HuiIssue issue) => issue.path.endsWith('.id'));
    expect(issues, hasLength(2));
  });

  test(
    'blank format reports the vanilla reset at the complete presentation',
    () {
      final GlossTablistDoc doc = _valid()
        ..listNames.variants.add(
          GlossTablistListNameVariant(
            id: 'hidden',
            when: 'true',
            presentation: GlossTablistListNamePresentation(format: '  '),
          ),
        );
      final HuiIssue issue = validateTablistDoc(doc).single;
      expect(issue.severity, HuiSeverity.info);
      expect(issue.path, r'$.listNames.variants[0].presentation.format');
    },
  );

  test('dangling animations are validated in defaults and variants', () {
    final GlossTablistDoc doc = _valid()
      ..headerFooter.presentation.header = '|animation.missing|'
      ..listNames.variants.add(
        GlossTablistListNameVariant(
          id: 'vip',
          when: 'true',
          presentation: GlossTablistListNamePresentation(
            format: r'|animation.missing| $player',
          ),
        ),
      );
    final List<HuiIssue> issues = validateTablistDoc(doc);
    expect(issues, hasLength(2));
    expect(
      issues.every((HuiIssue issue) => issue.severity == HuiSeverity.warning),
      isTrue,
    );
  });
}

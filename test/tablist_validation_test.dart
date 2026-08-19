/// Tablist validation: unused-half infos, the key normalization info, the
/// blank-format reset, the missing-default fallback, and dangling animation
/// references.
library;

import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/logic/tablist_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

GlossTablistDoc _clean() => GlossTablistDoc(
  useHeaderFooter: true,
  header: '&d&lGloss',
  footer: '&7VolmitSoftware.com',
  groupListNames: true,
  nameFormats: <String, String>{'default': r'$player', '_op': r'&6$player'},
);

final class _OneAnimation implements GlossAnimationResolver {
  _OneAnimation(this.id);

  final String id;

  @override
  List<String> get ids => <String>[id];

  @override
  GlossAnimationDoc? byId(String wanted) =>
      wanted == id ? GlossAnimationDoc(frames: <String>['&cGloss']) : null;
}

void main() {
  test('the shipped-default shape validates clean', () {
    expect(validateTablistDoc(_clean()), isEmpty);
  });

  test('an out-of-range revision is an error', () {
    final List<HuiIssue> issues = validateTablistDoc(_clean()..revision = 0);
    expect(issues.single.severity, HuiSeverity.error);
    expect(issues.single.path, r'$.revision');
  });

  test('written header with useHeaderFooter off is an unused-half info', () {
    final List<HuiIssue> issues = validateTablistDoc(
      _clean()..useHeaderFooter = false,
    );
    expect(issues.single.severity, HuiSeverity.info);
    expect(issues.single.path, r'$.useHeaderFooter');
  });

  test('written formats with groupListNames off is an unused-half info', () {
    final List<HuiIssue> issues = validateTablistDoc(
      _clean()..groupListNames = false,
    );
    expect(issues.single.severity, HuiSeverity.info);
    expect(issues.single.path, r'$.groupListNames');
  });

  test('non-normalized keys are an info naming the effective keys', () {
    final GlossTablistDoc doc = _clean()
      ..nameFormats = <String, String>{'Default': r'$player', ' ': 'x'};
    final List<HuiIssue> issues = validateTablistDoc(doc);
    // Also fires the blank-'default' presence check? No — 'default' exists
    // effectively; only the normalization info fires.
    expect(issues.single.severity, HuiSeverity.info);
    expect(issues.single.path, r'$.nameFormats');
    expect(issues.single.message, contains('[default]'));
  });

  test('no default entry is an info about the literal fallback', () {
    final GlossTablistDoc doc = _clean()
      ..nameFormats = <String, String>{'vip': 'x'};
    final List<HuiIssue> issues = validateTablistDoc(doc);
    expect(issues.single.severity, HuiSeverity.info);
    expect(issues.single.message, contains(r'$player'));
  });

  test('a blank format is the vanilla-reset info', () {
    final GlossTablistDoc doc = _clean();
    doc.nameFormats['vip'] = '  ';
    final List<HuiIssue> issues = validateTablistDoc(doc);
    expect(issues.single.severity, HuiSeverity.info);
    expect(issues.single.message, contains('RESETS'));
  });

  test('dangling animation references warn in header, footer and formats',
      () {
    final GlossTablistDoc doc = _clean()
      ..header = '|animation.rainbow|'
      ..footer = '|animation.rainbow|';
    doc.nameFormats['default'] = r'|animation.rainbow| $player';
    final List<HuiIssue> issues = validateTablistDoc(doc);
    expect(issues, hasLength(3));
    expect(
      issues.every((HuiIssue issue) => issue.severity == HuiSeverity.warning),
      isTrue,
    );
    expect(
      validateTablistDoc(doc, animations: _OneAnimation('rainbow')),
      isEmpty,
    );
  });
}

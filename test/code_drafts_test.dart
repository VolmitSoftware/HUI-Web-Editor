/// Unsaved code text, parked per document.
///
/// The rule the pane depends on: nothing the user typed is ever dropped by
/// anything but the user.
library;

import 'package:gloss_editor/components/code_editor/code_drafts.dart';
import 'package:test/test.dart';

void main() {
  test('parks and returns text under a document id', () {
    final HuiCodeDrafts drafts = HuiCodeDrafts();
    drafts.park('doc-a', '{"a": 1}');
    expect(drafts.peek('doc-a'), '{"a": 1}');
    expect(drafts.has('doc-a'), isTrue);
  });

  test('keeps one draft per document', () {
    final HuiCodeDrafts drafts = HuiCodeDrafts();
    drafts.park('doc-a', 'a');
    drafts.park('doc-b', 'b');
    expect(drafts.peek('doc-a'), 'a');
    expect(drafts.peek('doc-b'), 'b');
    expect(drafts.length, 2);
  });

  test('the newest park wins', () {
    final HuiCodeDrafts drafts = HuiCodeDrafts();
    drafts.park('doc-a', 'first');
    drafts.park('doc-a', 'second');
    expect(drafts.peek('doc-a'), 'second');
    expect(drafts.length, 1);
  });

  test('a dropped draft is gone', () {
    final HuiCodeDrafts drafts = HuiCodeDrafts();
    drafts.park('doc-a', 'a');
    drafts.drop('doc-a');
    expect(drafts.peek('doc-a'), isNull);
    expect(drafts.has('doc-a'), isFalse);
  });

  test('a document that is not there reads as nothing', () {
    final HuiCodeDrafts drafts = HuiCodeDrafts();
    expect(drafts.peek('nope'), isNull);
    expect(drafts.has('nope'), isFalse);
    drafts.drop('nope');
    expect(drafts.length, 0);
  });

  test('a pane with no active document parks nothing', () {
    final HuiCodeDrafts drafts = HuiCodeDrafts();
    drafts.park('', 'orphan');
    expect(drafts.length, 0);
    expect(drafts.peek(''), isNull);
  });

  test('an empty draft is still a draft', () {
    // Emptying the buffer is an edit like any other, and losing it on a view
    // switch would be exactly the surprise this store exists to prevent.
    final HuiCodeDrafts drafts = HuiCodeDrafts();
    drafts.park('doc-a', '');
    expect(drafts.has('doc-a'), isTrue);
    expect(drafts.peek('doc-a'), isEmpty);
  });
}

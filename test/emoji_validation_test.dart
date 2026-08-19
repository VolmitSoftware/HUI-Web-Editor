/// Emoji validation: the blank-value parse rejection as an error, the silent
/// UnicodeText fallbacks as warnings that name the served glyph.
library;

import 'package:gloss_editor/logic/emoji_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('a shipped-style document validates clean', () {
    expect(
      validateEmojiDoc(
        GlossEmojiDoc(trigger: '<3', emoji: 'U+2764;', enabled: true),
      ),
      isEmpty,
    );
  });

  test('an out-of-range revision is an error', () {
    final List<HuiIssue> issues = validateEmojiDoc(
      GlossEmojiDoc(revision: 0, emoji: 'x'),
    );
    expect(issues.single.severity, HuiSeverity.error);
    expect(issues.single.path, r'$.revision');
  });

  test('a blank emoji value is an error — the plugin rejects the file', () {
    for (final String value in <String>['', '   ']) {
      final List<HuiIssue> issues = validateEmojiDoc(
        GlossEmojiDoc(emoji: value),
      );
      expect(issues.single.severity, HuiSeverity.error, reason: '"$value"');
      expect(issues.single.path, r'$.emoji');
    }
  });

  test('a bad escape warns and names the served glyph', () {
    final List<HuiIssue> issues = validateEmojiDoc(
      GlossEmojiDoc(emoji: 'U+ZZZZ;'),
    );
    expect(issues.single.severity, HuiSeverity.warning);
    expect(issues.single.message, contains('"?"'));
  });

  test('a valid unterminated tail is clean — flushTail resolves it', () {
    expect(validateEmojiDoc(GlossEmojiDoc(emoji: 'U+2764')), isEmpty);
  });

  test('a whitespace-only trigger warns', () {
    final List<HuiIssue> issues = validateEmojiDoc(
      GlossEmojiDoc(trigger: '  ', emoji: 'x'),
    );
    expect(issues.single.severity, HuiSeverity.warning);
    expect(issues.single.path, r'$.trigger');
  });

  test('disabled is an info', () {
    final List<HuiIssue> issues = validateEmojiDoc(
      GlossEmojiDoc(emoji: 'x', enabled: false),
    );
    expect(issues.single.severity, HuiSeverity.info);
    expect(issues.single.path, r'$.enabled');
  });
}

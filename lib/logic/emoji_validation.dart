/// Validation for Gloss emoji documents.
///
/// The one parse rejection beyond the envelope is a blank `emoji` value
/// (`EmojiDoc.java:14-16`). The escape checks mirror what `UnicodeText.parse`
/// does SILENTLY: a terminated escape that does not name a code point renders
/// as `?` (`appendCodepoint`), and an unterminated tail either renders anyway
/// or stays literal `U+<hex>` (`flushTail`) — warnings that name the served
/// glyph, per the wave-1 convention for silent fixups.
library;

import '../model/gloss_doc.dart';
import '../model/gloss_emoji.dart';
import 'validation.dart';

List<HuiIssue> validateEmojiDoc(GlossEmojiDoc doc) {
  final List<HuiIssue> issues = <HuiIssue>[];

  final HuiIssue? revisionIssue = glossRevisionIssue(doc.revision);
  if (revisionIssue != null) {
    issues.add(revisionIssue);
  }

  if (doc.emoji.trim().isEmpty) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.emoji',
        message:
            'The emoji value is empty; Gloss rejects an emoji document '
            'without one.',
        fix: 'Enter a glyph, or U+XXXX; escapes for one.',
      ),
    );
  } else if (!glossUnicodeTextIsClean(doc.emoji)) {
    issues.add(
      HuiIssue(
        severity: HuiSeverity.warning,
        path: r'$.emoji',
        message:
            'Not every U+ escape names a code point; Gloss loads the file '
            'but serves "${doc.resolvedGlyph}" — a bad terminated escape '
            'renders as ? and a bad unterminated one stays literal.',
        fix:
            'Use U+ followed by hex and a closing semicolon, e.g. U+2764; '
            'for a heart.',
      ),
    );
  }

  if (doc.trigger.isNotEmpty && doc.trigger.trim().isEmpty) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.warning,
        path: r'$.trigger',
        message:
            'The trigger is only whitespace, so every run of spaces in chat '
            'would be replaced by the glyph.',
        fix: 'Clear the trigger or give it visible characters.',
      ),
    );
  }

  if (!doc.enabled) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.info,
        path: r'$.enabled',
        message:
            'This emoji is disabled: it stays listed but is never '
            'substituted in chat.',
        fix: 'Enable it when it should substitute.',
      ),
    );
  }

  return issues;
}

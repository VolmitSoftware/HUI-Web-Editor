/// Mirror of Gloss `BubbleLines.java` — how one chat message becomes bubble
/// lines.
///
/// `ChatBubblesService.onChat` calls `BubbleLines.split(message,
/// style.wordWrapChars())`: strip `§` colour pairs (only `§`, never `&` —
/// `stripColors`), soft-wrap through VolmLib's `Form.wrapWords`, split on
/// newlines and drop blank lines. [glossFormWrapWords] is a literal port of
/// `Form.wrap(s, len, null, true, " ")` as that code actually reads: every
/// space found in a window is recorded at its absolute index (`start +
/// offset`), so wrapping always breaks at the last space that fits the
/// window and only hard-cuts a word longer than the window.
library;

/// `BubbleLines.split`.
List<String> glossBubbleSplit(String message, int wrapChars) {
  final String stripped = glossBubbleStripColors(message);
  final List<String> parts = glossFormWrapWords(stripped, wrapChars).split('\n');
  return <String>[
    for (final String part in parts)
      if (part.trim().isNotEmpty) part,
  ];
}

/// `BubbleLines.stripColors`: drops each `§` and the one character after it.
String glossBubbleStripColors(String message) {
  final StringBuffer builder = StringBuffer();
  int index = 0;
  while (index < message.length) {
    final String current = message[index];
    if (current == '§' && index + 1 < message.length) {
      index += 2;
      continue;
    }
    builder.write(current);
    index++;
  }
  return builder.toString();
}

/// `Form.wrapWords(s, len)` = `wrap(s, len, null, true)` with the `" "`
/// pattern, ported statement for statement from the shipped VolmLib source.
String glossFormWrapWords(String s, int len) {
  const String newLineSep = '\n';
  if (len < 1) len = 1;

  final RegExp pattern = RegExp(' ');
  final int inputLength = s.length;
  int offset = 0;
  final StringBuffer out = StringBuffer();

  while (offset < inputLength) {
    int spaceToWrapAt = -1;
    final String window = s.substring(
      offset,
      offset + len + 1 < inputLength ? offset + len + 1 : inputLength,
    );
    final Iterator<Match> matches = pattern.allMatches(window).iterator;
    bool found = matches.moveNext();
    if (found) {
      if (matches.current.start == 0) {
        offset += matches.current.end;
        continue;
      }
      spaceToWrapAt = matches.current.start + offset;
    }

    if (inputLength - offset <= len) break;

    while (matches.moveNext()) {
      spaceToWrapAt = matches.current.start + offset;
    }

    if (spaceToWrapAt >= offset) {
      out.write(s.substring(offset, spaceToWrapAt));
      out.write(newLineSep);
      offset = spaceToWrapAt + 1;
    } else {
      // Soft wrap: hard-cut a full window when no usable space exists.
      out.write(s.substring(offset, len + offset));
      out.write(newLineSep);
      offset += len;
    }
  }

  out.write(s.substring(offset));
  return out.toString();
}

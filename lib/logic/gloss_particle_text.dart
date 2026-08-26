library;

const String glossParticleTextOpenPrefix = '<particles:';
const String glossParticleTextClose = '</particles>';
const int _marker = 0x07;

final RegExp _particleSpanNamePattern = RegExp(r'^[a-z0-9][a-z0-9._-]*$');

final class GlossParticleTextFormatException implements Exception {
  const GlossParticleTextFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class GlossParticleTextSpan {
  const GlossParticleTextSpan({
    required this.name,
    required this.start,
    required this.end,
  });

  final String name;
  final int start;
  final int end;
}

final class GlossParticleTextTemplate {
  const GlossParticleTextTemplate(this.marked);

  final String marked;
}

final class GlossParticleTextRendered {
  const GlossParticleTextRendered({required this.text, required this.spans});

  final String text;
  final List<GlossParticleTextSpan> spans;

  List<GlossParticleTextSpan> named(String name) {
    final String normalized = normalizeGlossParticleSpanName(name);
    return List<GlossParticleTextSpan>.unmodifiable(
      spans.where((GlossParticleTextSpan span) => span.name == normalized),
    );
  }
}

GlossParticleTextTemplate parseGlossParticleText(String authored) {
  final StringBuffer marked = StringBuffer();
  String? open;
  int cursor = 0;
  while (cursor < authored.length) {
    if (_matchesIgnoreCase(authored, cursor, glossParticleTextOpenPrefix)) {
      final int end = authored.indexOf(
        '>',
        cursor + glossParticleTextOpenPrefix.length,
      );
      if (end < 0) {
        throw const GlossParticleTextFormatException(
          'Particle text span is missing its closing >.',
        );
      }
      if (open != null) {
        throw const GlossParticleTextFormatException(
          'Particle text spans may not be nested.',
        );
      }
      open = normalizeGlossParticleSpanName(
        authored.substring(cursor + glossParticleTextOpenPrefix.length, end),
      );
      _appendMarker(marked, true, open);
      cursor = end + 1;
      continue;
    }
    if (_matchesIgnoreCase(authored, cursor, glossParticleTextClose)) {
      if (open == null) {
        throw const GlossParticleTextFormatException(
          'Particle text span closes without an opening tag.',
        );
      }
      _appendMarker(marked, false, open);
      open = null;
      cursor += glossParticleTextClose.length;
      continue;
    }
    marked.write(authored[cursor]);
    cursor++;
  }
  if (open != null) {
    throw GlossParticleTextFormatException(
      'Particle text span $open is not closed.',
    );
  }
  return GlossParticleTextTemplate(marked.toString());
}

GlossParticleTextRendered renderGlossParticleText(
  String authored,
  String Function(String marked) renderer,
) {
  final GlossParticleTextTemplate template = parseGlossParticleText(authored);
  return resolveGlossParticleText(renderer(template.marked));
}

GlossParticleTextRendered resolveGlossParticleText(String marked) {
  final StringBuffer text = StringBuffer();
  final List<GlossParticleTextSpan> spans = <GlossParticleTextSpan>[];
  String? openName;
  int? openStart;
  int cursor = 0;
  while (cursor < marked.length) {
    if (marked.codeUnitAt(cursor) != _marker) {
      text.write(marked[cursor]);
      cursor++;
      continue;
    }
    final int kindIndex = cursor + 1;
    final int nameEnd = marked.indexOf(
      String.fromCharCode(_marker),
      kindIndex + 1,
    );
    if (kindIndex >= marked.length || nameEnd < 0) {
      text.write(marked[cursor]);
      cursor++;
      continue;
    }
    final String kind = marked[kindIndex];
    final String name = marked.substring(kindIndex + 1, nameEnd);
    if (kind == '+') {
      if (openName != null) {
        throw const GlossParticleTextFormatException(
          'Particle span markers were changed during text rendering.',
        );
      }
      openName = name;
      openStart = text.length;
    } else if (kind == '-') {
      if (openName != name || openStart == null) {
        throw const GlossParticleTextFormatException(
          'Particle span markers were changed during text rendering.',
        );
      }
      spans.add(
        GlossParticleTextSpan(name: name, start: openStart, end: text.length),
      );
      openName = null;
      openStart = null;
    } else {
      text.write(marked.substring(cursor, nameEnd + 1));
    }
    cursor = nameEnd + 1;
  }
  if (openName != null) {
    throw const GlossParticleTextFormatException(
      'Particle span markers were removed during text rendering.',
    );
  }
  return GlossParticleTextRendered(
    text: text.toString(),
    spans: List<GlossParticleTextSpan>.unmodifiable(spans),
  );
}

String normalizeGlossParticleSpanName(String value) {
  final String normalized = value.trim().toLowerCase();
  if (normalized.isEmpty ||
      normalized.length > 64 ||
      !_particleSpanNamePattern.hasMatch(normalized)) {
    throw const GlossParticleTextFormatException(
      'Particle text span name must match [a-z0-9][a-z0-9._-]* and be at most 64 characters.',
    );
  }
  return normalized;
}

String? glossParticleTextSyntaxError(String authored) {
  try {
    parseGlossParticleText(authored);
    return null;
  } on GlossParticleTextFormatException catch (failure) {
    return failure.message;
  }
}

bool _matchesIgnoreCase(String source, int offset, String candidate) {
  if (offset + candidate.length > source.length) return false;
  return source.substring(offset, offset + candidate.length).toLowerCase() ==
      candidate;
}

void _appendMarker(StringBuffer output, bool opening, String name) {
  output
    ..writeCharCode(_marker)
    ..write(opening ? '+' : '-')
    ..write(name)
    ..writeCharCode(_marker);
}

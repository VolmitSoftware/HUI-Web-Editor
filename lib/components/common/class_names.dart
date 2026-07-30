/// Joins optional CSS class fragments, dropping nulls and blanks.
///
/// Deliberately tiny and shared: every primitive emits stable `hui-*` hooks so
/// the stylesheet modules can restyle them without touching Dart.
String classNames(List<String?> parts) {
  final StringBuffer buffer = StringBuffer();
  for (final String? part in parts) {
    if (part == null) continue;
    final String trimmed = part.trim();
    if (trimmed.isEmpty) continue;
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(trimmed);
  }
  return buffer.toString();
}

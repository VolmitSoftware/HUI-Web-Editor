library;

import '../components/scoreboard/scoreboard_selection.dart';
import '../model/gloss_scoreboard.dart';
import '../model/json_codec.dart';
import 'gloss_show.dart';

GlossScoreboardPresentation glossResolveScoreboardLayout(
  GlossScoreboardPresentation presentation,
  GlossConditionContext context,
  int nowMs,
) {
  final Object? rawLayout = presentation.extras['layout'];
  final Map<Object?, Object?> layout = rawLayout is Map
      ? rawLayout
      : const <Object?, Object?>{};
  final Object? rawSections = layout['sections'];
  final Map<Object?, Object?> sections = rawSections is Map
      ? rawSections
      : const <Object?, Object?>{};
  List<GlossScoreboardLine> rows = presentation.lines;
  String title = presentation.title;
  final Object? rawPages = layout['pages'];
  final List<({Map<Object?, Object?> page, int duration})> pages =
      <({Map<Object?, Object?> page, int duration})>[];
  int total = 0;
  if (rawPages is List) {
    for (final Object? raw in rawPages.take(64)) {
      if (raw is! Map ||
          !glossShowMatches(raw['show'], scope: context, nowMs: nowMs)) {
        continue;
      }
      final Object? durationValue = raw['durationTicks'];
      final int duration = durationValue is num
          ? durationValue.toInt().clamp(1, 72000)
          : 100;
      pages.add((page: raw, duration: duration));
      total += duration;
    }
  }
  if (total > 0) {
    int position = (nowMs ~/ 50) % total;
    for (final ({Map<Object?, Object?> page, int duration}) candidate
        in pages) {
      if (position < candidate.duration) {
        if (candidate.page['title'] is String) {
          title = candidate.page['title']! as String;
        }
        rows = _rows(candidate.page['lines']);
        break;
      }
      position -= candidate.duration;
    }
  }
  final List<GlossScoreboardLine> expanded = <GlossScoreboardLine>[];
  _expand(rows, sections, context, nowMs, <String>{}, expanded);
  return GlossScoreboardPresentation(
    title: title,
    lines: expanded,
    hideNumbers: presentation.hideNumbers,
  );
}

String? glossScoreboardValue(
  GlossScoreboardLine line,
  int index,
  bool hideNumbers,
) {
  final String format =
      line.format ??
      (line.value != null && line.value!.isNotEmpty
          ? 'fixed'
          : hideNumbers
          ? 'blank'
          : 'number');
  return switch (format) {
    'blank' => null,
    'fixed' => line.value ?? '',
    'styled' => '${line.value ?? ''}${glossBoardScoreForRow(index)}',
    _ => '${glossBoardScoreForRow(index)}',
  };
}

List<GlossScoreboardLine> _rows(Object? raw) {
  final List<GlossScoreboardLine> rows = <GlossScoreboardLine>[];
  if (raw is! List) return rows;
  for (final (int index, Object? row) in raw.take(256).indexed) {
    try {
      rows.add(GlossScoreboardLine.fromJson(row, 'lines[$index]'));
    } on HuiFormatException {
      continue;
    }
  }
  return rows;
}

void _expand(
  List<GlossScoreboardLine> rows,
  Map<Object?, Object?> sections,
  GlossConditionContext context,
  int nowMs,
  Set<String> path,
  List<GlossScoreboardLine> expanded,
) {
  for (final GlossScoreboardLine row in rows) {
    if (expanded.length >= 256) return;
    if (!glossShowMatches(row.show, scope: context, nowMs: nowMs)) continue;
    final String? section = row.section;
    if (section == null) {
      expanded.add(row);
    } else if (path.add(section)) {
      _expand(
        _rows(sections[section]),
        sections,
        context,
        nowMs,
        path,
        expanded,
      );
      path.remove(section);
    }
  }
}

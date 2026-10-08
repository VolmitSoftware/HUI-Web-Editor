import '../model/gloss_tab_layout.dart';
import 'gloss_show.dart';
import 'preview_expr.dart';
import 'tablist_selection.dart';

final class GlossTabPreviewCell {
  const GlossTabPreviewCell(this.text, this.pingBars);
  final String text;
  final int pingBars;
}

final class GlossTabPreviewPlayer {
  const GlossTabPreviewPlayer({
    required this.name,
    required this.cell,
    required this.scope,
    this.group = '',
    this.order = 0,
    this.npc = false,
    this.visible = true,
  });
  final String name;
  final String group;
  final GlossTabPreviewCell cell;
  final PExprScope scope;
  final double order;
  final bool npc;
  final bool visible;
}

GlossTabPresentation? glossResolveTabLayout(
  GlossTabLayout? layout,
  PExprScope scope, {
  int nowMs = 0,
  Object? documentShow,
}) {
  if (!glossShowMatches(documentShow, scope: scope, nowMs: nowMs) ||
      layout == null ||
      !layout.enabled ||
      !glossShowMatches(layout.show, scope: scope, nowMs: nowMs)) {
    return null;
  }
  final List<GlossTabLayoutVariant> variants =
      List<GlossTabLayoutVariant>.of(layout.variants)
        ..sort((GlossTabLayoutVariant a, GlossTabLayoutVariant b) {
          final int priority = b.priority.compareTo(a.priority);
          return priority != 0 ? priority : a.id.compareTo(b.id);
        });
  for (final GlossTabLayoutVariant variant in variants) {
    if (glossShowMatches(variant.when, scope: scope, nowMs: nowMs)) {
      return variant.presentation;
    }
  }
  return layout;
}

List<GlossTabPreviewCell> glossTabLayoutCells(
  GlossTabPresentation layout,
  List<GlossTabPreviewPlayer> players, {
  PExprScope? viewerScope,
  int nowMs = 0,
}) {
  if (layout.entries < 1 || layout.entries > 80) {
    return const <GlossTabPreviewCell>[];
  }
  final int rows = layout.rows;
  final List<GlossTabPreviewCell> cells = List<GlossTabPreviewCell>.filled(
    layout.entries,
    const GlossTabPreviewCell('', 0),
  );
  bool inside(int column, int row) =>
      column >= 0 &&
      column < layout.columns &&
      row >= 0 &&
      row < rows &&
      column * rows + row < cells.length;
  for (final GlossTabSlot slot in layout.slots) {
    if (!inside(slot.column, slot.row)) continue;
    cells[slot.column * rows + slot.row] = GlossTabPreviewCell(
      _text(slot.text, viewerScope),
      5,
    );
  }
  for (final GlossTabSection section in layout.sections) {
    final List<int> indexes = <int>[
      for (
        int column = section.column.clamp(0, 4);
        column < (section.column + section.columns).clamp(0, 4);
        column++
      )
        for (
          int row = section.row.clamp(0, 20);
          row < (section.row + section.rows).clamp(0, 20);
          row++
        )
          if (inside(column, row)) column * rows + row,
    ];
    if (indexes.isEmpty) continue;
    final List<GlossTabPreviewPlayer> selected = <GlossTabPreviewPlayer>[
      for (final GlossTabPreviewPlayer player in players)
        if (player.visible &&
            (!player.npc || section.includeNpcs) &&
            glossShowMatches(section.filter, scope: player.scope, nowMs: nowMs))
          player,
    ];
    final Map<GlossTabPreviewPlayer, List<Object>> keys =
        <GlossTabPreviewPlayer, List<Object>>{};
    for (final GlossTabPreviewPlayer player in selected) {
      keys[player] = <Object>[
        for (final GlossTabSortKey key in section.sort) _key(key, player.scope),
      ];
    }
    selected.sort((GlossTabPreviewPlayer a, GlossTabPreviewPlayer b) {
      for (int index = 0; index < section.sort.length; index++) {
        final GlossTabSortKey key = section.sort[index];
        final Object left = keys[a]![index];
        final Object right = keys[b]![index];
        final int result = key.type == 'number'
            ? (left as double).compareTo(right as double)
            : (left as String).compareTo(right as String);
        if (result != 0) {
          return key.direction == 'descending' ? -result : result;
        }
      }
      final int weight = section.sort.isEmpty ? b.order.compareTo(a.order) : 0;
      return weight != 0
          ? weight
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    final bool count =
        section.overflow == 'count' && selected.length > indexes.length;
    final int shown = count
        ? indexes.length - 1
        : selected.length.clamp(0, indexes.length);
    for (int index = 0; index < indexes.length; index++) {
      if (index < shown) {
        final GlossTabPreviewPlayer player = selected[index];
        final String raw = section.format == null
            ? player.cell.text
            : glossTablistSubstituteTokens(
                section.format!,
                player.name,
                player.group,
              );
        cells[indexes[index]] = GlossTabPreviewCell(
          _text(raw, player.scope),
          player.cell.pingBars,
        );
      } else if (count && index == indexes.length - 1) {
        cells[indexes[index]] = GlossTabPreviewCell(
          _text(
            section.overflowFormat.replaceAll(
              '{count}',
              '${selected.length - shown}',
            ),
            viewerScope,
          ),
          0,
        );
      } else {
        cells[indexes[index]] = const GlossTabPreviewCell('', 0);
      }
    }
  }
  return cells;
}

Object _key(GlossTabSortKey key, PExprScope scope) {
  try {
    final PExpr expression = parsePreviewExpr(key.expression);
    return key.type == 'number'
        ? evalNumber(expression, scope)
        : evalString(expression, scope);
  } on PExprException {
    return key.type == 'number' ? 0.0 : '';
  }
}

String _text(String raw, PExprScope? scope) {
  if (scope == null) return raw;
  return raw.replaceAllMapped(RegExp(r'\{\{(.*?)\}\}', dotAll: true), (
    Match match,
  ) {
    try {
      return evalString(parsePreviewExpr(match.group(1)!.trim()), scope);
    } on PExprException {
      return match.group(0)!;
    }
  });
}

import '../model/gloss_tab_layout.dart';

final class GlossTabPreviewCell {
  const GlossTabPreviewCell(this.text, this.pingBars);
  final String text;
  final int pingBars;
}

List<GlossTabPreviewCell> glossTabLayoutCells(
  GlossTabLayout layout,
  List<GlossTabPreviewCell> players,
) {
  final int columns = layout.columns.clamp(1, 4);
  final int rows = layout.rows.clamp(1, 20);
  final List<GlossTabPreviewCell> cells = List<GlossTabPreviewCell>.filled(
    columns * rows,
    const GlossTabPreviewCell('', 0),
  );
  for (final Map<String, Object?> slot in layout.slots) {
    final Object? column = slot['column'];
    final Object? row = slot['row'];
    if (column is! int ||
        row is! int ||
        column < 0 ||
        column >= columns ||
        row < 0 ||
        row >= rows) {
      continue;
    }
    cells[column * rows + row] = GlossTabPreviewCell(
      slot['text'] is String ? slot['text'] as String : '',
      5,
    );
  }
  final GlossTabPlayers? block = layout.players;
  if (block == null) return cells;
  final List<int> indexes = <int>[
    for (
      int column = block.column.clamp(0, columns);
      column < (block.column + block.columns).clamp(0, columns);
      column++
    )
      for (int row = 0; row < block.rows.clamp(0, rows); row++)
        column * rows + row,
  ];
  if (indexes.isEmpty) return cells;
  final bool counts =
      block.overflow == 'count' && players.length > indexes.length;
  final int shown = counts
      ? indexes.length - 1
      : players.length.clamp(0, indexes.length);
  for (int index = 0; index < indexes.length; index++) {
    cells[indexes[index]] = index < shown
        ? players[index]
        : counts && index == indexes.length - 1
        ? GlossTabPreviewCell(
            block.overflowFormat.replaceAll(
              '{count}',
              '${players.length - shown}',
            ),
            0,
          )
        : const GlossTabPreviewCell('', 0);
  }
  return cells;
}

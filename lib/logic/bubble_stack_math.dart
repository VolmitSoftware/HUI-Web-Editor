library;

const double glossBubbleDefaultStackSpread = 0.26;

double glossBubbleStackOffset(
  double spread,
  int bubbleIndex,
  List<int> lineCounts,
) {
  if (bubbleIndex < 0 || bubbleIndex >= lineCounts.length) return 0;
  int linesBelow = 0;
  for (int index = bubbleIndex + 1; index < lineCounts.length; index++) {
    final int count = lineCounts[index];
    linesBelow += count > 0 ? count : 1;
  }
  final double offset = spread * linesBelow;
  return offset > 0 ? offset : 0;
}

double glossBubbleStackY(
  double spread,
  int bubbleIndex,
  List<int> lineCounts,
) => glossBubbleStackOffset(spread, bubbleIndex, lineCounts);

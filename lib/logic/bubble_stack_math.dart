library;

const double glossBubbleBaseLift = 0.86;
const double glossBubbleDefaultStackSpread = 0.26;

double glossBubbleStackOffset(
  double spread,
  int bubbleIndex,
  List<int> lineCounts,
) {
  if (bubbleIndex < 0 || bubbleIndex >= lineCounts.length) return 0;
  int linesAtOrBelow = 0;
  for (int index = bubbleIndex; index < lineCounts.length; index++) {
    final int count = lineCounts[index];
    linesAtOrBelow += count > 0 ? count : 1;
  }
  final double offset = spread * linesAtOrBelow;
  return offset > 0 ? offset : 0;
}

double glossBubbleStackY(
  double spread,
  int bubbleIndex,
  List<int> lineCounts,
) =>
    glossBubbleBaseLift +
    glossBubbleStackOffset(spread, bubbleIndex, lineCounts);

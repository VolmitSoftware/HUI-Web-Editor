library;

import 'package:gloss_editor/logic/bubble_stack_math.dart';
import 'package:test/test.dart';

void main() {
  test('stack spacing accounts for every wrapped line in each block', () {
    const List<int> lineCounts = <int>[3, 1, 2];
    expect(glossBubbleStackOffset(0.26, 0, lineCounts), closeTo(1.56, 1e-12));
    expect(glossBubbleStackOffset(0.26, 1, lineCounts), closeTo(0.78, 1e-12));
    expect(glossBubbleStackOffset(0.26, 2, lineCounts), closeTo(0.52, 1e-12));
  });

  test('invalid indexes and non-positive spread do not lower a block', () {
    expect(glossBubbleStackOffset(0.26, -1, const <int>[1]), 0);
    expect(glossBubbleStackOffset(0.26, 1, const <int>[1]), 0);
    expect(glossBubbleStackOffset(-0.26, 0, const <int>[1]), 0);
  });

  test('empty or invalid line counts still reserve one line', () {
    expect(
      glossBubbleStackOffset(0.26, 0, const <int>[0, -2]),
      closeTo(0.52, 1e-12),
    );
  });

  test('stack Y composes base lift and line-aware offset', () {
    expect(
      glossBubbleStackY(0.26, 0, const <int>[2, 1]),
      closeTo(0.86 + 0.78, 1e-12),
    );
  });
}

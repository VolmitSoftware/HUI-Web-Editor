import 'package:gloss_editor/components/shell/bar_menu_navigation.dart';
import 'package:test/test.dart';

void main() {
  test('bar menu navigation wraps and supports boundary keys', () {
    expect(huiBarMenuTargetIndex(current: 1, count: 4, key: 'ArrowDown'), 2);
    expect(huiBarMenuTargetIndex(current: 3, count: 4, key: 'ArrowDown'), 0);
    expect(huiBarMenuTargetIndex(current: 0, count: 4, key: 'ArrowUp'), 3);
    expect(huiBarMenuTargetIndex(current: 2, count: 4, key: 'Home'), 0);
    expect(huiBarMenuTargetIndex(current: 2, count: 4, key: 'End'), 3);
    expect(huiBarMenuTargetIndex(current: -1, count: 4, key: 'ArrowUp'), 3);
    expect(huiBarMenuTargetIndex(current: 0, count: 0, key: 'ArrowDown'), -1);
  });
}

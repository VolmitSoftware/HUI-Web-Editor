import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('real drop shadow is a circular disc on the ground plane', () {
    final String view = File(
      'lib/components/real_drops/real_drops_view.dart',
    ).readAsStringSync();
    final String css = File('web/styles/10-gloss.css').readAsStringSync();

    expect(
      RegExp(r"'width': '\$\{\(edgePx \* 1\.35\)").allMatches(view).length,
      1,
    );
    expect(
      RegExp(r"'height': '\$\{\(edgePx \* 1\.35\)").allMatches(view).length,
      1,
    );
    expect(view, contains("'rotateX(90deg)'"));
    expect(css, contains('radial-gradient(circle at center'));
    expect(css, contains('border-radius: 50%'));
    expect(css, contains('transform-origin: 50% 50%'));
  });
}

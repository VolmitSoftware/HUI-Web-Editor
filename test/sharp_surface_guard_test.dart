import 'dart:io';

import 'package:test/test.dart';

List<File> _sourceFiles(String root, String extension) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((File file) => file.path.endsWith(extension))
    .toList(growable: false);

String _block(String source, String marker) {
  final int markerIndex = source.indexOf(marker);
  expect(markerIndex, isNonNegative, reason: 'missing $marker');
  final int openIndex = source.indexOf('{', markerIndex);
  expect(
    openIndex,
    greaterThan(markerIndex),
    reason: 'missing block for $marker',
  );
  int depth = 0;
  for (int index = openIndex; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') {
      depth--;
      if (depth == 0) return source.substring(openIndex + 1, index);
    }
  }
  fail('unterminated block for $marker');
}

void main() {
  test('sharp chrome does not subtract from the zero radius token', () {
    final RegExp negativeRadius = RegExp(
      r'calc\(\s*var\(--hui-radius\)\s*-\s*\d+(?:\.\d+)?px\s*\)',
    );
    final List<String> offenders = <String>[
      for (final File file in <File>[
        ..._sourceFiles('lib', '.dart'),
        ..._sourceFiles('web/styles', '.css'),
      ])
        if (negativeRadius.hasMatch(file.readAsStringSync())) file.path,
    ];
    expect(
      offenders,
      isEmpty,
      reason: 'negative radius calculations: $offenders',
    );
  });

  test('mobile rail controls keep forty pixel targets', () {
    final String css = File(
      'web/styles/05-panels-dialogs.css',
    ).readAsStringSync();
    final String mobile = _block(
      css,
      '@media (pointer: coarse) and (max-width: 1024px), '
      '(max-width: 700px)',
    );
    for (final String selector in <String>[
      '.hui-rail-add .arcane-button',
      '.hui-rail-tools .arcane-button',
      '.hui-rail-confirm .arcane-button',
      '.hui-rail-rename .arcane-button',
    ]) {
      expect(mobile, contains(selector), reason: 'missing $selector');
    }
    expect(
      RegExp(r'height:\s*40px\s*!important;').allMatches(mobile).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      RegExp(r'min-height:\s*40px;').allMatches(mobile).length,
      greaterThanOrEqualTo(2),
    );
  });

  test('mobile library disclosure keeps a forty pixel target', () {
    final String css = File('web/styles/09-workspace.css').readAsStringSync();
    final String mobile = _block(
      css,
      '@media (pointer: coarse), (max-width: 720px)',
    );
    expect(
      mobile,
      contains(
        '.hui-library-disclosure { width: 40px; height: 40px; '
        'flex-basis: 40px; }',
      ),
    );
  });
}

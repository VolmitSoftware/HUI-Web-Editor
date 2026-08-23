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
    expect(
      css,
      contains('border-left: 1px solid var(--hui-border-soft) !important;'),
    );
  });

  test('mobile code toolbar keeps forty pixel targets after desktop rules', () {
    final String css = File(
      'web/styles/05-panels-dialogs.css',
    ).readAsStringSync();
    final int desktop = css.indexOf('.hui-code-toolbar .arcane-button {');
    final int mobile = css.lastIndexOf('.hui-code-toolbar .arcane-button {');
    expect(desktop, isNonNegative);
    expect(mobile, greaterThan(desktop));
    final String rule = _block(
      css.substring(mobile),
      '.hui-code-toolbar .arcane-button {',
    );
    expect(rule, contains('height: 40px !important;'));
    expect(rule, contains('min-height: 40px;'));
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

  test('canvas toolbar hands compact actions to More without scrolling', () {
    final String css = File('web/styles/03-canvas.css').readAsStringSync();
    final String compact = _block(
      css,
      '@container hui-canvas (max-width: 760px)',
    );
    final String coarseCompact = _block(
      css,
      '@container hui-canvas (max-width: 1000px)',
    );
    final String toolbar = File(
      'lib/components/canvas/canvas_toolbar.dart',
    ).readAsStringSync();

    expect(css, isNot(matches(RegExp(r'overflow-x\s*:\s*(auto|scroll)'))));
    expect(compact, contains('.hui-canvas-toolgroup.is-compact'));
    expect(compact, contains('display: flex;'));
    expect(
      compact,
      contains(
        '.hui-canvas-toolgroup.is-zoom > :nth-child(5) '
        '{ display: none !important; }',
      ),
    );
    for (final String group in <String>[
      '.hui-canvas-toolgroup.is-view',
      '.hui-canvas-toolgroup.is-scale',
      '.hui-canvas-toolgroup.is-order',
      '.hui-canvas-toolgroup.is-state',
    ]) {
      expect(compact, contains(group), reason: 'compact handoff misses $group');
      expect(
        coarseCompact,
        contains(group),
        reason: 'coarse compact handoff misses $group',
      );
    }
    expect(toolbar, contains("'hui-canvas-toolgroup \$role'"));
    expect(toolbar, contains("'is-compact'"));
    for (final String action in <String>[
      "label: huiText('Reset view')",
      "label: huiText('Fit to components')",
      "activeLabel: huiText('Hide grid')",
      "inactiveLabel: huiText('Show grid')",
      "activeLabel: huiText('Disable snapping')",
      "inactiveLabel: huiText('Enable snapping')",
      "activeLabel: huiText('Hide hitboxes')",
      "inactiveLabel: huiText('Show hitboxes')",
      "activeLabel: huiText('Hide anchors')",
      "inactiveLabel: huiText('Show anchors')",
      "activeLabel: huiText('Disable true render')",
      "inactiveLabel: huiText('Enable true render')",
      "label: huiText('Decrease uiScale')",
      "label: huiText('Increase uiScale')",
      "label: huiText('Bring forward')",
      "label: huiText('Send back')",
      "label: huiText('Move nearer (-z)')",
      "label: huiText('Move deeper (+z)')",
      "activeLabel: huiText('Pause animations')",
      "inactiveLabel: huiText('Play animations')",
      "label: huiText('Preview true icon')",
      "label: huiText('Preview false icon')",
    ]) {
      expect(toolbar, contains(action), reason: 'More menu misses $action');
    }
  });

  test('coarse tablet header tracks contain forty pixel controls', () {
    final String css = File('web/styles/02-shell.css').readAsStringSync();
    final String coarse = _block(
      css,
      '@media (pointer: coarse) and (max-width: 1024px)',
    );
    expect(coarse, contains('--hui-command-height: 44px;'));
    expect(coarse, contains('--hui-context-height: 44px;'));
  });

  test('workbench toolbars use one seam and borderless ghost actions', () {
    for (final ({String path, String toolbar, String button}) surface
        in <({String path, String toolbar, String button})>[
          (
            path: 'web/styles/03-canvas.css',
            toolbar: '.hui-canvas-toolbar {',
            button: '.hui-canvas-toolbar .arcane-button {',
          ),
          (
            path: 'web/styles/07-preview.css',
            toolbar: '.hui-preview-toolbar {',
            button: '.hui-preview-toolbar .arcane-button {',
          ),
        ]) {
      final String css = File(surface.path).readAsStringSync();
      final String toolbar = _block(css, surface.toolbar);
      final String button = _block(css, surface.button);
      expect(toolbar, contains('border: 0;'));
      expect(
        toolbar,
        contains('border-bottom: 1px solid var(--hui-border-soft);'),
      );
      expect(toolbar, contains('background: var(--hui-panel);'));
      expect(button, contains('border: 0 !important;'));
      expect(button, contains('background: transparent !important;'));
      expect(button, contains('box-shadow: none !important;'));
    }
  });

  test(
    'editor metadata is square while true circular controls stay circular',
    () {
      for (final ({String path, String selector}) target
          in <({String path, String selector})>[
            (
              path: 'web/styles/04-inspector.css',
              selector: '.hui-type-badge {',
            ),
            (
              path: 'web/styles/04-inspector.css',
              selector: '.hui-inspector-section-count {',
            ),
            (path: 'web/styles/04-inspector.css', selector: '.hui-count-chip,'),
            (
              path: 'web/styles/04-inspector.css',
              selector: '.hui-frame-staged-chip {',
            ),
            (
              path: 'web/styles/05-panels-dialogs.css',
              selector: '.hui-rail-count {',
            ),
            (
              path: 'web/styles/08-preview-card.css',
              selector: '.hui-preview-sim-chip {',
            ),
            (
              path: 'web/styles/09-workspace.css',
              selector: '.hui-board-badge {',
            ),
            (path: 'web/styles/10-gloss.css', selector: '.hui-gloss-chip {'),
            (
              path: 'web/styles/10-gloss.css',
              selector: '.hui-emoji-cell-trigger {',
            ),
          ]) {
        final String block = _block(
          File(target.path).readAsStringSync(),
          target.selector,
        );
        expect(
          block,
          contains('border-radius: 0;'),
          reason: '${target.selector} in ${target.path}',
        );
        expect(block, isNot(contains('999px')));
      }

      final String preview = File(
        'web/styles/07-preview.css',
      ).readAsStringSync();
      expect(
        _block(preview, '.hui-preview-avatar-disc,'),
        contains('border-radius: 50%;'),
      );
      final String canvas = File('web/styles/03-canvas.css').readAsStringSync();
      expect(
        _block(canvas, '.hui-scale-range::-webkit-slider-thumb {'),
        contains('border-radius: 999px;'),
      );
    },
  );
}

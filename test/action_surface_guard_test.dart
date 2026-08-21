import 'dart:io';

import 'package:test/test.dart';

/// The top bar sheds one cluster per rung of the give-way ladder, and each rung
/// shows its own overflow menu. Two things have to stay true for that to work,
/// and neither is visible from a unit test of the widget: a tier's menu must
/// carry every action the rungs above it folded (nothing becomes unreachable),
/// and it must carry nothing that is still on the bar at that width (no width
/// offers two routes to one command). Both are properties of the source, so
/// they are checked here.
void main() {
  final String topBar = File(
    'lib/components/shell/top_bar.dart',
  ).readAsStringSync();
  final String barMenu = File(
    'lib/components/shell/bar_menu.dart',
  ).readAsStringSync();
  final String shellCss = File('web/styles/02-shell.css').readAsStringSync();

  /// The four rungs, widest first, as `(tier, actions that rung folds)`.
  const Map<int, List<String>> foldedAtTier = <int, List<String>>{
    1: <String>[
      "label: 'Templates'",
      "label: 'Command palette'",
      "label: 'Settings'",
      "label: 'Help'",
      'Light theme',
    ],
    2: <String>["label: 'Images'"],
    3: <String>[
      "label: 'Import JSON'",
      "label: 'Export \$_documentNoun JSON'",
      "label: 'Copy \$_documentNoun JSON'",
    ],
    4: <String>["label: 'Undo'", "label: 'Redo'"],
  };

  /// The menu one tier actually renders: the entry list with every region
  /// guarded by a higher tier removed. A guard opens either a spread block
  /// (`...<BarMenuEntry>[ … ]`) or a single entry (`BarMenuAction( … )`), and
  /// both are closed by counting brackets rather than by matching indentation.
  String entriesFor(int tier) {
    final String body = _between(
      topBar,
      'List<BarMenuEntry> _overflowEntries(int tier)',
      'Widget _mobilePaneControls()',
    );
    final RegExp guard = RegExp(r'if \(tier >= (\d)\)\s*');
    final StringBuffer kept = StringBuffer();
    int cursor = 0;
    while (true) {
      final Match? match = guard.firstMatch(body.substring(cursor));
      if (match == null) {
        kept.write(body.substring(cursor));
        return kept.toString();
      }
      final int start = cursor + match.start;
      final int bodyStart = cursor + match.end;
      final int end = _regionEnd(body, bodyStart);
      kept.write(body.substring(cursor, start));
      if (int.parse(match.group(1)!) <= tier) {
        kept.write(body.substring(bodyStart, end));
      }
      cursor = end;
    }
  }

  test('each overflow tier carries every action the rungs above it folded', () {
    for (int tier = 1; tier <= 4; tier++) {
      final String menu = entriesFor(tier);
      for (int rung = 1; rung <= tier; rung++) {
        for (final String action in foldedAtTier[rung]!) {
          expect(
            menu,
            contains(action),
            reason: 'tier $tier must carry $action, folded at rung $rung',
          );
        }
      }
    }
  });

  test('no overflow tier lists an action still on the bar at its width', () {
    for (int tier = 1; tier <= 4; tier++) {
      final String menu = entriesFor(tier);
      for (int rung = tier + 1; rung <= 4; rung++) {
        for (final String action in foldedAtTier[rung]!) {
          expect(
            menu,
            isNot(contains(action)),
            reason: 'tier $tier must not duplicate $action, still on the bar',
          );
        }
      }
    }
  });

  test('every mounted overflow tier has a breakpoint that shows it', () {
    expect(topBar, contains('const int _overflowTiers = 4;'));
    for (int tier = 1; tier <= 4; tier++) {
      expect(
        shellCss,
        contains('.hui-bar-overflow.is-tier$tier { display: flex; }'),
        reason: 'tier $tier is mounted but never shown',
      );
    }
    // Tier 1 is the permanent desktop menu. Tiers 1..3 hand over to the next
    // one as a complete action cluster leaves the row; tier 4 is the floor.
    final String topBarRules = _between(
      shellCss,
      '/* ---- Top bar',
      '/* ---- Status bar',
    );
    expect(
      topBarRules,
      contains('.hui-bar-overflow.is-tier1 { display: flex; }'),
    );
    for (int tier = 1; tier <= 3; tier++) {
      expect(
        shellCss,
        contains('.hui-bar-overflow.is-tier$tier { display: none; }'),
        reason: 'tier $tier is never handed over to tier ${tier + 1}',
      );
    }
  });

  test('the ladder folds clusters in the documented order', () {
    // Widest first: the breakpoints must descend, or a narrower viewport would
    // show more of the bar than a wider one.
    const List<int> rungs = <int>[1400, 1150, 1100, 1024, 700, 430];
    int previous = 1 << 30;
    for (final int rung in rungs) {
      expect(
        shellCss,
        contains('@media (max-width: ${rung}px)'),
        reason: 'missing the ${rung}px rung',
      );
      expect(rung, lessThan(previous));
      previous = rung;
    }
    // Kind and view are permanent stateful selectors, not a scrollable icon
    // wall that changes shape at an arbitrary breakpoint.
    expect(topBar, isNot(contains('_kindTabs()')));
    expect(topBar, isNot(contains('hui-kind-tabs')));
    expect(topBar, isNot(contains('hui-bar-views')));
    expect(shellCss, isNot(contains('.hui-kind-tabs')));
    expect(shellCss, isNot(contains('.hui-bar-views')));
    expect(shellCss, contains('.hui-kind-picker { display: flex; }'));
    expect(shellCss, contains('.hui-bar-view-picker { display: flex; }'));
    expect(topBar, contains('_kindPicker(),'));
    expect(topBar, contains('_viewPicker()'));
  });

  test('the header owns no horizontal scrolling primitive', () {
    final String topBarRules = _between(
      shellCss,
      '/* ---- Top bar',
      '/* ---- Status bar',
    );
    expect(
      topBarRules,
      isNot(matches(RegExp(r'overflow(?:-x)?\s*:\s*(?:auto|scroll)'))),
    );
    expect(topBarRules, isNot(contains('scrollbar-width')));
    expect(
      topBarRules,
      isNot(matches(RegExp(r'^\s*scroll-behavior\s*:', multiLine: true))),
    );
    expect(topBar, isNot(contains('scrollLeft')));
    expect(topBar, isNot(contains('querySelector')));
  });

  test('header menus cannot focus-scroll or escape a short viewport', () {
    expect(
      shellCss,
      contains('max-height: calc(100dvh - var(--hui-command-height) - 12px);'),
    );
    expect(shellCss, contains('.hui-bar-menu-panel {'));
    expect(shellCss, contains('overflow-y: auto;'));
    expect(
      shellCss,
      contains(
        '100dvh - var(--hui-command-height) - '
        'var(--hui-context-height) - 12px',
      ),
    );
    expect(barMenu, contains('web.FocusOptions(preventScroll: true)'));
    expect(topBar, contains('align: BarMenuAlign.right,'));
    expect(shellCss, contains('#hui-doc-menu {'));
    expect(shellCss, contains('position: fixed !important;'));
    expect(shellCss, contains('right: 8px !important;'));
    expect(shellCss, contains('left: 8px !important;'));
    expect(shellCss, contains('.hui-bar-menu-item {'));
    expect(shellCss, contains('min-height: 44px;'));
    expect(
      shellCss,
      contains('.hui-bar-menu-item:hover:not(:disabled),'),
    );
  });

  test('the armed delete action keeps destructive hierarchy', () {
    expect(
      shellCss,
      contains('.hui-armed > .arcane-button[data-variant="destructive"] {'),
    );
    expect(shellCss, contains('background: var(--hui-danger) !important;'));
    expect(
      shellCss,
      contains('color: var(--destructive-foreground) !important;'),
    );
  });

  test('secondary commands have one permanent overflow route', () {
    final String commandRow = _between(
      topBar,
      'Widget _bar()',
      'Widget _cluster(',
    );
    for (final String action in foldedAtTier[1]!) {
      expect(
        commandRow,
        isNot(contains(action)),
        reason: '$action must not be duplicated outside the permanent menu',
      );
      expect(
        entriesFor(1),
        contains(action),
        reason: '$action must remain reachable from the permanent menu',
      );
    }
  });

  test(
    'the command and context rows keep actions separate from navigation',
    () {
      expect(topBar, contains("classes: 'hui-bar-primary'"));
      expect(topBar, contains("classes: 'hui-bar-context'"));
      expect(
        shellCss,
        contains(
          'grid-template-rows: var(--hui-command-height) '
          'var(--hui-context-height);',
        ),
      );
      expect(shellCss, isNot(contains('--hui-bar-side')));
      expect(shellCss, isNot(contains('button:not(.selected)')));
      expect(topBar, contains("visibleLabel: 'Import'"));
      expect(topBar, contains("visibleLabel: 'Export'"));
    },
  );

  test('phone context pickers yield space to the pane controls', () {
    final String phoneRules = _between(
      shellCss,
      '@media (max-width: 700px)',
      '@media (max-width: 430px)',
    );
    expect(
      phoneRules,
      contains('grid-template-columns: minmax(0, 1fr) minmax(0, 2.15fr);'),
    );
    expect(phoneRules, contains('grid-template-columns: minmax(0, 1fr) auto;'));
    expect(phoneRules, contains('grid-template-columns: auto auto;'));
    expect(
      phoneRules,
      contains(
        '.hui-kind-picker .hui-bar-menu,\n'
        '  .hui-bar-view-picker .hui-bar-menu { width: 100%; }',
      ),
    );
    expect(phoneRules, contains('max-width: 100%;'));
    final String topBarRules = _between(
      shellCss,
      '/* ---- Top bar',
      '/* ---- Status bar',
    );
    expect(topBarRules, contains('.hui-kind-picker .hui-bar-menu'));
    expect(topBarRules, contains('.hui-bar-view-picker .hui-bar-menu'));
    expect(shellCss, contains('.hui-picker-label {\n  min-width: 0;'));
  });

  test('export footer closes without duplicating the body download action', () {
    final String source = File(
      'lib/components/dialogs/export_dialog.dart',
    ).readAsStringSync();
    final String actions = _between(
      source,
      'actions: <Widget>[',
      'children: <Widget>[',
    );
    expect(actions, contains("label: 'Close'"));
    expect(actions, isNot(contains('_downloadJson')));
    expect(actions, isNot(contains("label: 'Download JSON'")));
  });
}

/// Index just past the bracket group that opens at or after [from].
int _regionEnd(String source, int from) {
  final int open = source.indexOf(RegExp(r'[\[(]'), from);
  if (open < 0) return source.length;
  final String opener = source[open];
  final String closer = opener == '[' ? ']' : ')';
  int depth = 0;
  for (int i = open; i < source.length; i++) {
    if (source[i] == opener) depth++;
    if (source[i] == closer) {
      depth--;
      if (depth == 0) return i + 1;
    }
  }
  return source.length;
}

String _between(String source, String start, String end) {
  final int startIndex = source.indexOf(start);
  final int endIndex = source.indexOf(end, startIndex + start.length);
  expect(startIndex, isNonNegative, reason: 'missing $start');
  expect(endIndex, greaterThan(startIndex), reason: 'missing $end');
  return source.substring(startIndex, endIndex);
}

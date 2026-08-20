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
  final String shellCss = File('web/styles/02-shell.css').readAsStringSync();

  /// The four rungs, widest first, as `(tier, actions that rung folds)`.
  const Map<int, List<String>> foldedAtTier = <int, List<String>>{
    1: <String>[
      "label: 'Templates'",
      "label: 'Command palette'",
      "label: 'Settings'",
      "label: 'Help'",
    ],
    2: <String>["label: 'Images'", 'Light theme'],
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
    // Tiers 1..3 hand over to the next one; tier 4 is the floor.
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
    const List<int> rungs = <int>[1800, 1600, 1400, 1150, 1024, 900, 700, 430];
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
    // The strip and the switcher hand over to their pickers, and never the
    // other way round.
    expect(shellCss, contains('.hui-kind-tabs { display: none; }'));
    expect(shellCss, contains('.hui-kind-picker { display: flex; }'));
    expect(shellCss, contains('.hui-bar-views { display: none; }'));
    expect(shellCss, contains('.hui-bar-view-picker { display: flex; }'));
    final String kindHandoff = _between(
      shellCss,
      '@media (max-width: 1600px)',
      '@media (max-width: 1400px)',
    );
    expect(kindHandoff, contains('.hui-kind-tabs { display: none; }'));
    expect(kindHandoff, contains('.hui-kind-picker { display: flex; }'));
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
    expect(phoneRules, contains('max-width: calc(100% - 84px);'));
    expect(phoneRules, contains('.hui-kind-picker .hui-bar-menu'));
    expect(phoneRules, contains('.hui-bar-view-picker .hui-bar-menu'));
    expect(phoneRules, contains('max-width: 100%;'));
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

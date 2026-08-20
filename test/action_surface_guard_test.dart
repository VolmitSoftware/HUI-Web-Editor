import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('tablet overflow contains only actions hidden at tablet width', () {
    final String source = File(
      'lib/components/shell/top_bar.dart',
    ).readAsStringSync();
    final String compact = _between(
      source,
      'Widget _compactOverflow()',
      'Widget _mobileOverflow()',
    );
    expect(compact, isNot(contains("label: 'Import JSON'")));
    expect(compact, isNot(contains("label: 'Export \$_documentNoun JSON'")));
    expect(compact, isNot(contains("label: 'Copy \$_documentNoun JSON'")));
    expect(compact, contains("label: 'Templates'"));
    expect(compact, contains("label: 'Command palette'"));
    expect(compact, contains("label: 'Settings'"));
  });

  test('phone overflow retains the complete transferable action surface', () {
    final String source = File(
      'lib/components/shell/top_bar.dart',
    ).readAsStringSync();
    final String mobile = _between(
      source,
      'Widget _mobileOverflow()',
      'Widget _mobilePaneControls()',
    );
    expect(mobile, contains("label: 'Import JSON'"));
    expect(mobile, contains("label: 'Export \$_documentNoun JSON'"));
    expect(mobile, contains("label: 'Copy \$_documentNoun JSON'"));
    expect(mobile, contains("label: 'Images'"));
    expect(mobile, contains("label: 'Templates'"));
    expect(mobile, contains("label: 'Command palette'"));
    expect(mobile, contains("label: 'Help'"));
    expect(mobile, contains("label: 'Settings'"));
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

String _between(String source, String start, String end) {
  final int startIndex = source.indexOf(start);
  final int endIndex = source.indexOf(end, startIndex + start.length);
  expect(startIndex, isNonNegative, reason: 'missing $start');
  expect(endIndex, greaterThan(startIndex), reason: 'missing $end');
  return source.substring(startIndex, endIndex);
}

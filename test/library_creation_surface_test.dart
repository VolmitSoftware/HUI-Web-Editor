import 'dart:io';

import 'package:test/test.dart';

void main() {
  final String source = File(
    'lib/components/panels/editor_rail.dart',
  ).readAsStringSync();
  final String css = File('web/styles/09-workspace.css').readAsStringSync();

  test('library exposes two labeled creation controls', () {
    expect(source, contains("label: 'Folder'"));
    expect(source, contains("label: 'New document'"));
    expect(source, isNot(contains('Widget _iconButton(')));
    expect(css, isNot(contains('repeat(auto-fit, minmax(34px, 1fr))')));
  });

  test('new document menu follows the document type registry', () {
    final String menu = _between(
      source,
      'Widget _newDocumentMenu()',
      'void _openNewDocumentMenu()',
    );
    expect(
      menu,
      contains(
        'for (final DocumentTypeAdapter type in DocumentTypeRegistry.tabs)',
      ),
    );
    expect(menu, contains('onSelect: () => _createDocument(type)'));
  });

  test('new document menu exposes and restores keyboard focus', () {
    final String trigger = _between(
      source,
      'Widget _newDocumentMenuButton()',
      'Widget _newDocumentMenu()',
    );
    final String lifecycle = _between(
      source,
      'void _openNewDocumentMenu()',
      'Widget _workspaceMenuButton()',
    );
    expect(trigger, contains("'aria-haspopup': 'menu'"));
    expect(trigger, contains("'aria-expanded': _newDocumentMenuOpen"));
    expect(trigger, contains("'aria-controls': _newDocumentMenuId"));
    expect(lifecycle, contains('focusHuiActionMenu(_newDocumentMenuId)'));
    expect(
      lifecycle,
      contains('focusHuiActionMenu(_newDocumentMenuTriggerId)'),
    );
  });
}

String _between(String source, String start, String end) {
  final int startIndex = source.indexOf(start);
  final int endIndex = source.indexOf(end, startIndex + start.length);
  expect(startIndex, isNonNegative, reason: 'missing $start');
  expect(endIndex, greaterThan(startIndex), reason: 'missing $end');
  return source.substring(startIndex, endIndex);
}

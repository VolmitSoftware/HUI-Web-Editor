import 'dart:io';

import 'package:test/test.dart';

void main() {
  final String rail = File(
    'lib/components/panels/editor_rail.dart',
  ).readAsStringSync();
  final String app = File('lib/app.dart').readAsStringSync();
  final String dialog = File(
    'lib/components/dialogs/new_document_dialog.dart',
  ).readAsStringSync();
  final String css = File('web/styles/09-workspace.css').readAsStringSync();

  test('library exposes two labeled creation controls', () {
    expect(rail, contains("label: huiText('Folder')"));
    expect(rail, contains("label: huiText('New document')"));
    expect(rail, isNot(contains('Widget _iconButton(')));
    expect(css, isNot(contains('repeat(auto-fit, minmax(34px, 1fr))')));
  });

  test('new document dialog follows the document type registry', () {
    expect(
      dialog,
      contains(
        'final List<DocumentTypeAdapter> types = DocumentTypeRegistry.tabs;',
      ),
    );
    expect(dialog, contains('for (final DocumentTypeAdapter type in types)'));
    expect(dialog, contains('onPressed: () => onCreate(type)'));
    final String open = _between(
      rail,
      'void _openNewDocumentDialog()',
      'Widget _workspaceMenuButton()',
    );
    expect(open, contains('component.onNewDocument(_createDocument)'));
  });

  test('new document dialog exposes and restores keyboard focus', () {
    final String trigger = _between(
      rail,
      'Widget _newDocumentButton()',
      'void _openNewDocumentDialog()',
    );
    final String lifecycle = _between(
      app,
      'void _openNewDocumentDialog(',
      'void _closeDialog()',
    );
    expect(trigger, contains('id: NewDocumentDialog.triggerId'));
    expect(trigger, contains("'aria-haspopup': 'dialog'"));
    expect(
      trigger,
      contains("'aria-expanded': component.newDocumentDialogOpen"),
    );
    expect(
      dialog,
      contains('id: identical(type, types.first) ? firstChoiceId : null'),
    );
    expect(
      lifecycle,
      contains('focusHuiActionMenu(NewDocumentDialog.firstChoiceId)'),
    );
    expect(
      lifecycle,
      contains('focusHuiActionMenu(NewDocumentDialog.triggerId)'),
    );
    expect(
      _between(app, 'void _closeDialog()', 'void _closeOverlay()'),
      contains('_restoreNewDocumentFocus();'),
    );
    expect(
      _between(app, 'void _closeOverlay()', '_dialog = _EditorDialog.none;'),
      contains('_restoreNewDocumentFocus();'),
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

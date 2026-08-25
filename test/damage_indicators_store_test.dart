library;

import 'dart:convert';

import 'package:gloss_editor/config/gloss_templates.dart';
import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:test/test.dart';

class _FakeStorage {
  final Map<String, String> values = <String, String>{};

  String? read(String key) => values[key];

  bool write(String key, String value) {
    values[key] = value;
    return true;
  }
}

EditorStore _store() {
  final _FakeStorage storage = _FakeStorage();
  return EditorStore(
    workspace: Workspace(read: storage.read, write: storage.write),
    autosaveDelay: Duration.zero,
  );
}

void main() {
  test('creation uses the canonical singleton id and shipped document', () {
    final EditorStore store = _store();
    store.newGlossDocument(DocumentTypes.damageIndicators);
    expect(store.docKind, WorkspaceDocKind.damageIndicators);
    expect(store.view, EditorView.visual);
    expect(store.workspace.active!.runtimeId, 'default');
    expect(
      jsonDecode(store.exportJson()),
      jsonDecode(kGlossDamageIndicatorsDefaultJson),
    );
  });

  test('typed mutations are undoable', () {
    final EditorStore store = _store();
    store.newGlossDocument(DocumentTypes.damageIndicators);
    store.mutateDamageIndicators(
      'damage format',
      (GlossDamageIndicatorsDoc doc) =>
          doc.damage.presentation.format = '&4{amount}',
    );
    expect(store.damageIndicatorsDoc!.damage.presentation.format, '&4{amount}');
    expect(store.performUndo(), isTrue);
    expect(
      store.damageIndicatorsDoc!.damage.presentation.format,
      '&c&l{amount}',
    );
  });

  test('import detection routes the canonical shape to damage indicators', () {
    final EditorStore store = _store();
    store.importJsonAsNewDocument(
      'default.json',
      kGlossDamageIndicatorsDefaultJson,
    );
    expect(store.docKind, WorkspaceDocKind.damageIndicators);
    expect(store.workspace.active!.runtimeId, 'default');
    expect(store.damageIndicatorsDoc!.healing.when, 'true');
  });
}

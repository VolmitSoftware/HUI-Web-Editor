import 'dart:convert';

import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/logic/document_presets.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:gloss_editor/state/workspace_panel.dart';
import 'package:test/test.dart';

const String _catalog = '''{
  "schemaVersion":1,"revision":1,
  "defaults":{"boards":{"select":{"priority":0,"when":"true"},"variants":[],"presentation":{"title":"Global","lines":["Global"],"hideNumbers":true}}},
  "presets":{"boards":{"base":{"values":{"presentation":{"title":"Base"}}},"compact":{"extends":"base","values":{"presentation":{"lines":["Inherited"]}}}}}
}''';
const String _source = '{"schemaVersion":2,"revision":7,"preset":"compact"}';

void main() {
  test('inactive workspace catalogs resolve inherited values', () {
    final Workspace workspace = Workspace(autoLoad: false);
    const String catalog = '''{"schemaVersion":1,"revision":1,"defaults":{
      "names":{"materials":{"stone":"Inherited stone"}},
      "emoji":{"trigger":":inherited:","emoji":"A","enabled":true},
      "animations":{"frames":["Inherited frame"],"frameIntervalMs":150,"mode":"ascend"}
    }}''';
    for (final String kind in <String>['names', 'emoji', 'animation']) {
      workspace.create(title: kind, runtimeId: kind,
        json: '{"schemaVersion":1,"revision":1}',
        kind: DocumentTypeRegistry.byWireKind(kind)!.kind,
        presetContext: catalog);
    }
    workspace.create(title: 'board', runtimeId: 'board', json: _source,
      kind: DocumentTypes.scoreboard.kind, presetContext: _catalog);
    final EditorStore store = EditorStore(workspace: workspace);
    addTearDown(store.dispose);
    expect(store.workspaceNames.name(GlossNameCategory.materials, 'stone'), 'Inherited stone');
    expect(store.workspaceEmoji.entries.single.glyph, 'A');
    expect(store.workspaceEmoji.entries.single.trigger, ':inherited:');
    expect(store.workspaceAnimations.byId('animation')!.frames, <String>['Inherited frame']);
  });

  test('defaults, parent, selected preset and document merge in order', () {
    final DocumentPresets catalog = DocumentPresets.parse(_catalog);
    final Map<String, Object?> resolved = jsonDecode(catalog.resolve('scoreboard',
        '{"schemaVersion":2,"revision":7,"preset":"compact","presentation":{"title":"Own"}}')) as Map<String, Object?>;
    expect(resolved['preset'], isNull);
    expect(resolved['revision'], 7);
    expect(resolved['presentation'], <String, Object?>{
      'title': 'Own', 'lines': <String>['Inherited'], 'hideNumbers': true,
    });
    expect((jsonDecode(catalog.resolve('scoreboard', _source)) as Map)['presentation']['title'], 'Base');
  });

  test('arrays replace and explicit null resets inherited fields', () {
    final DocumentPresets catalog = DocumentPresets.parse(_catalog);
    final Map<String, Object?> resolved = jsonDecode(catalog.resolve('scoreboard',
        '{"preset":"compact","presentation":{"lines":[],"title":null}}')) as Map<String, Object?>;
    expect(resolved['presentation'], <String, Object?>{'lines': <String>[], 'title': null, 'hideNumbers': true});
  });

  test('cycles, missing names, identity fields and unsupported kinds fail', () {
    for (final String fields in <String>[
      '"presets":{"boards":{"a":{"extends":"b"},"b":{"extends":"a"}}}',
      '"presets":{"boards":{"a":{"extends":"missing"}}}',
      '"defaults":{"boards":{"revision":4}}',
      '"defaults":{"boardz":{}}',
    ]) {
      expect(() => DocumentPresets.parse('{"schemaVersion":1,"revision":1,$fields}'), throwsFormatException);
    }
    expect(() => DocumentPresets.empty.resolve('scoreboard', _source), throwsFormatException);
  });

  test('unchanged inherited values stay absent after a nested visual edit', () {
    final InheritedDocumentSource source = InheritedDocumentSource(_source,
      '{"schemaVersion":2,"revision":7,"presentation":{"title":"Base","hideNumbers":true,"lines":["Inherited"]}}');
    final Map<String, Object?> edited = jsonDecode(source.encode(
      '{"schemaVersion":2,"revision":7,"presentation":{"title":"Edited","hideNumbers":true,"lines":["Inherited"]}}')) as Map<String, Object?>;
    expect(edited, <String, Object?>{'schemaVersion': 2, 'revision': 7, 'preset': 'compact',
      'presentation': <String, Object?>{'title': 'Edited'}});
  });

  test('visual edits, undo, redo and code edits retain sparse source', () {
    final Map<String, String> storage = <String, String>{};
    final Workspace workspace = Workspace(read: (String key) => storage[key],
      write: (String key, String value) { storage[key] = value; return true; });
    final WorkspaceDoc document = workspace.create(title: 'board', runtimeId: 'board',
      json: _source, kind: DocumentTypes.scoreboard.kind, presetContext: _catalog);
    final EditorStore store = EditorStore(workspace: workspace, autosaveDelay: const Duration(days: 1));
    addTearDown(store.dispose);
    expect(store.scoreboardDoc!.presentation.title, 'Base');
    expect(store.exportJson(), _source);
    store.mutateGloss('title', (GlossDoc doc) => (doc as GlossScoreboardDoc).presentation.title = 'Edited');
    expect((jsonDecode(store.exportJson()) as Map)['presentation'], <String, Object?>{'title': 'Edited'});
    expect(store.performUndo(), isTrue);
    expect(store.exportJson(), _source);
    expect(store.scoreboardDoc!.presentation.title, 'Base');
    expect(store.performRedo(), isTrue);
    expect(store.scoreboardDoc!.presentation.title, 'Edited');
    expect(store.applyCode(_source), isTrue);
    expect(store.exportJson(), _source);
    store.flushAutosave();
    expect(workspace.byId(document.id)!.json, _source);
    expect(workspace.byId(document.id)!.presetContext, _catalog);
  });

  test('invalid preset context never overwrites the authored document', () {
    final Map<String, String> storage = <String, String>{};
    final Workspace workspace = Workspace(read: (String key) => storage[key],
      write: (String key, String value) { storage[key] = value; return true; });
    final WorkspaceDoc document = workspace.create(title: 'board', runtimeId: 'board',
      json: _source, kind: DocumentTypes.scoreboard.kind, presetContext: '{bad');
    final EditorStore store = EditorStore(workspace: workspace);
    addTearDown(store.dispose);
    expect(store.lastError, contains('presets'));
    store.mutateGloss('title', (GlossDoc doc) => (doc as GlossScoreboardDoc).presentation.title = 'Wrong');
    store.flushAutosave();
    expect(workspace.byId(document.id)!.json, _source);
    expect(store.exportJson(), _source);
    expect(store.applyCode('{}'), isFalse);
  });

  test('panel visual edits keep inherited runtime fields sparse through undo', () {
    final Map<String, String> storage = <String, String>{};
    final Workspace workspace = Workspace(read: (String key) => storage[key],
      write: (String key, String value) { storage[key] = value; return true; });
    const String catalog = '{"schemaVersion":1,"revision":1,"defaults":{"panels":{"rootMenuId":"inherited","visibility":{"mode":"public"}}}}';
    workspace.create(title: 'panel', json: encodeWorkspacePanel(const WorkspacePanelData(
      runtimeBoardId: 'panel', runtimeBoard: <String, Object?>{'schemaVersion': 1, 'revision': 1, 'id': 'panel'},
    )), kind: DocumentTypes.panel.kind, presetContext: catalog);
    final EditorStore store = EditorStore(workspace: workspace);
    addTearDown(store.dispose);
    final WorkspacePanelData initial = store.panelDoc!;
    expect(initial.runtimeBoard!['rootMenuId'], 'inherited');
    store.updatePanel(initial.copyWith(runtimeBoard: <String, Object?>{
      ...initial.runtimeBoard!, 'rootMenuId': 'local',
    }));
    expect(decodeWorkspacePanel(workspace.active!.json).data.runtimeBoard, <String, Object?>{
      'schemaVersion': 1, 'revision': 1, 'id': 'panel', 'rootMenuId': 'local',
    });
    expect(store.performUndo(), isTrue);
    expect(store.panelDoc!.runtimeBoard!['rootMenuId'], 'inherited');
    expect(decodeWorkspacePanel(workspace.active!.json).data.runtimeBoard!.containsKey('rootMenuId'), isFalse);
  });
  test('reimporting a singleton replaces its authored inheritance source', () {
    final Workspace workspace = Workspace(autoLoad: false);
    const String catalog = '{"schemaVersion":1,"revision":1,"defaults":{"names":{"entities":{"pig":"Inherited"}}}}';
    workspace.create(title: 'names', runtimeId: 'names',
      json: '{"schemaVersion":1,"revision":1,"materials":{"stone":"Old"}}',
      kind: DocumentTypes.names.kind, presetContext: catalog);
    final EditorStore store = EditorStore(workspace: workspace);
    addTearDown(store.dispose);
    const String imported = '{"schemaVersion":1,"revision":2,"materials":{"stone":"New"}}';
    expect(store.importJsonAsNewDocument('names.json', imported), isTrue);
    expect(store.docKind, DocumentTypes.names.kind);
    expect(store.exportJson(), imported);
    expect(store.performUndo(), isTrue);
    expect((jsonDecode(store.exportJson()) as Map)['materials']['stone'], 'Old');
  });

  test('sparse imported documents resolve their named preset before kind detection', () {
    final Workspace workspace = Workspace(autoLoad: false);
    workspace.create(title: 'board', runtimeId: 'board', json: _source,
      kind: DocumentTypes.scoreboard.kind, presetContext: _catalog);
    final EditorStore store = EditorStore(workspace: workspace);
    addTearDown(store.dispose);
    expect(store.importJsonAsNewDocument('imported.json', _source), isTrue);
    expect(store.docKind, DocumentTypes.scoreboard.kind);
    expect(store.scoreboardDoc!.presentation.title, 'Base');
    expect(store.exportJson(), _source);
  });

  test('ambiguous sparse preset imports keep the existing document unchanged', () {
    final Map<String, dynamic> catalog = jsonDecode(_catalog) as Map<String, dynamic>;
    (catalog['presets'] as Map)['menus'] = <String, Object?>{
      'compact': <String, Object?>{'values': <String, Object?>{'components': <Object?>[]}},
    };
    final Workspace workspace = Workspace(autoLoad: false);
    workspace.create(title: 'board', runtimeId: 'board', json: _source,
      kind: DocumentTypes.scoreboard.kind, presetContext: jsonEncode(catalog));
    final EditorStore store = EditorStore(workspace: workspace);
    addTearDown(store.dispose);
    expect(store.importJsonAsNewDocument('ambiguous.json', _source), isFalse);
    expect(store.lastError, contains('intended kind'));
    expect(workspace.docs, hasLength(1));
    expect(store.exportJson(), _source);
  });

}

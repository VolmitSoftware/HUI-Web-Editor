import 'dart:convert';
import 'dart:io';

import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/logic/document_presets.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/model/gloss_scoreboard_advanced.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:test/test.dart';

import 'support/gloss_repository.dart';

void main() {
  final Map<String, Object?> fixture = jsonDecode(File(glossRepositoryFilePath(
    'src/test/resources/importer/editor-roundtrip.json',
  )).readAsStringSync()) as Map<String, Object?>;
  final Map<String, Object?> canonical = fixture['canonical']! as Map<String, Object?>;
  final Map<String, Object?> edited = fixture['edited']! as Map<String, Object?>;
  final String context = jsonEncode(fixture['presets']);
  final DocumentPresets presets = DocumentPresets.parse(context);

  test('historical board conversion edits preserve preset inheritance and undo', () {
    final Workspace workspace = Workspace(autoLoad: false);
    final String source = jsonEncode(canonical['board']);
    workspace.create(title: 'event', runtimeId: 'event', json: source,
      kind: DocumentTypes.scoreboard.kind, presetContext: context);
    final EditorStore store = EditorStore(workspace: workspace);
    addTearDown(store.dispose);
    expect(store.lastError, isNull);
    expect(store.scoreboardDoc!.presentation.title, 'Legacy board');
    store.mutateGloss('Edit imported board', (GlossDoc document) {
      final GlossScoreboardDoc board = document as GlossScoreboardDoc;
      board.presentation.title = 'Edited board';
      final GlossScoreboardLayout layout = GlossScoreboardLayout.fromJson(board.presentation.extras['layout']);
      layout.pages.add(GlossScoreboardPage(id: 'overview', durationTicks: 80,
        lines: <GlossScoreboardLine>[GlossScoreboardLine(section: 'status')]));
      layout.refresh.titleTicks = 80;
      layout.refresh.textTicks = 20;
      layout.refresh.valueTicks = 5;
      board.presentation.extras['layout'] = layout.toJson();
      final GlossScoreboardObjectives objectives = GlossScoreboardObjectives.fromJson(board.extras['objectives']);
      objectives.belowName!.conflict = 'override';
      objectives.belowName!.refreshTicks = 10;
      board.extras['objectives'] = objectives.toJson();
    });
    final String exported = store.exportJson();
    final GlossScoreboardDoc expected = decodeGlossScoreboardDoc(presets.resolve('scoreboard', jsonEncode(edited['board'])));
    final GlossScoreboardDoc actual = decodeGlossScoreboardDoc(presets.resolve('scoreboard', exported));
    expect(actual.toJson(), expected.toJson());
    final Map<String, Object?> sparse = jsonDecode(exported) as Map<String, Object?>;
    expect(sparse['preset'], 'display');
    final Map<String, Object?> presentation = sparse['presentation']! as Map<String, Object?>;
    expect((presentation['layout']! as Map<String, Object?>).containsKey('sections'), isFalse);
    expect(workspace.active!.presetContext, context);
    expect(store.performUndo(), isTrue);
    expect(store.exportJson(), source);
    expect(store.performRedo(), isTrue);
    expect(store.exportJson(), exported);
  });

  test('historical MOTD conversion accepts policy edits and canonical export', () {
    final Workspace workspace = Workspace(autoLoad: false);
    final String source = jsonEncode(canonical['motd']);
    workspace.create(title: 'motd', runtimeId: 'motd', json: source,
      kind: DocumentTypes.motd.kind, presetContext: context);
    final EditorStore store = EditorStore(workspace: workspace);
    addTearDown(store.dispose);
    expect(store.lastError, isNull);
    store.mutateGloss('Edit imported MOTD', (GlossDoc document) {
      final GlossMotdDoc motd = document as GlossMotdDoc;
      motd.rotation = GlossMotdRotation(mode: 'sequence', intervalSeconds: 30);
      motd.entries.first.counts = GlossMotdCounts(onlineMode: 'offset', onlineValue: 2,
        maximumMode: 'fixed', maximumValue: 200);
      motd.serverLinks = GlossMotdServerLinks(enabled: true,
        links: <GlossMotdLink>[GlossMotdLink(label: 'Rules', url: 'https://example.org/rules')]);
    });
    final String exported = store.exportJson();
    expect(decodeGlossMotdDoc(exported).toJson(),
      decodeGlossMotdDoc(jsonEncode(edited['motd'])).toJson());
    expect(store.performUndo(), isTrue);
    expect(jsonDecode(store.exportJson()), jsonDecode(source));
    expect(store.performRedo(), isTrue);
    expect(store.exportJson(), exported);
  });
}

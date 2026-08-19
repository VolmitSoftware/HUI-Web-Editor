library;

import 'dart:math' as math;

import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/services/showcase_randomizer.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:test/test.dart';

final class _FakeStorage {
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
  test('every runtime document kind randomizes in place without errors', () {
    for (final DocumentTypeAdapter type in DocumentTypeRegistry.all) {
      if (type.kind == WorkspaceDocKind.panel) continue;
      final EditorStore store = _store();
      type.createNew(store);
      final WorkspaceDoc before = store.workspace.active!;
      final int count = store.workspace.docs.length;

      expect(
        randomizeShowcaseDocument(store, before.id, random: math.Random(31)),
        isTrue,
        reason: type.noun,
      );
      expect(store.workspace.docs, hasLength(count), reason: type.noun);
      expect(store.workspace.activeId, before.id, reason: type.noun);
      expect(store.workspace.active!.runtimeId, before.runtimeId);
      expect(store.workspace.active!.folderId, before.folderId);
      expect(
        store.issues.where(
          (HuiIssue issue) => issue.severity == HuiSeverity.error,
        ),
        isEmpty,
        reason: type.noun,
      );
      expect(store.canUndo, isTrue, reason: type.noun);
    }
  });

  test('seeded showcase builders are deterministic and visibly vary', () {
    final EditorStore store = _store()..newDocument();
    final String first = encodeHuiMenu(
      buildRandomMenuShowcase(store, math.Random(9)),
    );
    final String repeated = encodeHuiMenu(
      buildRandomMenuShowcase(store, math.Random(9)),
    );
    final String different = encodeHuiMenu(
      buildRandomMenuShowcase(store, math.Random(10)),
    );
    expect(repeated, first);
    expect(different, isNot(first));
  });

  test('menu showcase stays validation-clean across random seeds', () {
    for (int seed = 0; seed < 128; seed++) {
      final EditorStore store = _store()..newDocument();
      store.replaceMenu(
        'Randomize menu',
        buildRandomMenuShowcase(store, math.Random(seed)),
      );
      expect(
        store.issues.where(
          (HuiIssue issue) => issue.severity != HuiSeverity.info,
        ),
        isEmpty,
        reason: 'seed $seed',
      );
    }
  });

  test('menu showcase contains every component and action type', () {
    final EditorStore store = _store()..newDocument();
    final HuiMenu menu = buildRandomMenuShowcase(store, math.Random(5));
    final Set<String> componentTypes = <String>{
      for (final HuiComponent component in menu.components) component.data.type,
    };
    final Set<String> actionTypes = <String>{};
    for (final HuiComponent component in menu.components) {
      switch (component.data) {
        case final HuiButtonData button:
          actionTypes.addAll(
            button.actions.map((HuiAction action) => action.type),
          );
        case final HuiToggleData toggle:
          actionTypes.addAll(
            <HuiAction>[
              ...toggle.trueActions,
              ...toggle.falseActions,
            ].map((HuiAction action) => action.type),
          );
        case HuiDecorationData():
          break;
      }
    }
    expect(componentTypes, containsAll(huiComponentTypes));
    expect(actionTypes, containsAll(huiActionTypes));
  });

  test('random MOTD and scoreboard are complete fake server examples', () {
    final GlossMotdDoc motd = buildRandomMotdShowcase(
      GlossMotdDoc(revision: 7),
      math.Random(4),
    );
    expect(motd.revision, 7);
    expect(motd.entries.length, greaterThanOrEqualTo(3));
    expect(
      motd.entries.any((GlossMotdEntry entry) => entry.lines.length == 1),
      isTrue,
    );
    expect(
      motd.entries.any((GlossMotdEntry entry) => entry.lines.length == 2),
      isTrue,
    );
    expect(
      motd.entries.expand((GlossMotdEntry entry) => entry.lines),
      contains('|animation.rainbow|'),
    );

    final GlossScoreboardDoc scoreboard = buildRandomScoreboardShowcase(
      GlossScoreboardDoc(revision: 11),
      math.Random(4),
    );
    expect(scoreboard.revision, 11);
    expect(scoreboard.lines.length, inInclusiveRange(8, glossBoardMaxLines));
    expect(scoreboard.lines, contains('|animation.rainbow|'));
    expect(
      scoreboard.lines.any((String line) => line.contains('%player_name%')),
      isTrue,
    );
  });

  test(
    'component randomization preserves identity, position and data type',
    () {
      final EditorStore store = _store()..newDocument();
      final HuiComponent before = store.menu.components.first.copy();
      expect(
        randomizeMenuComponent(store, before.id, random: math.Random(12)),
        isTrue,
      );
      final HuiComponent after = store.menu.componentById(before.id)!;
      expect(after.id, before.id);
      expect(after.offset, before.offset);
      expect(after.data.type, before.data.type);
      expect(after.data.toJson(), isNot(before.data.toJson()));
      expect(store.canUndo, isTrue);
    },
  );

  test('the persisted erase marker keeps a reload genuinely empty', () {
    final _FakeStorage storage = _FakeStorage();
    storage.values[EditorStore.emptyWorkspaceKey] = 'true';
    final EditorStore store = EditorStore(
      workspace: Workspace(read: storage.read, write: storage.write),
      autosaveDelay: Duration.zero,
    );
    expect(store.workspace.docs, isEmpty);
    expect(store.workspace.active, isNull);
    expect(store.hasActiveDocument, isFalse);
    expect(store.menu.components, isEmpty);

    expect(store.newDocument(), isTrue);
    expect(store.hasActiveDocument, isTrue);
    expect(storage.values[EditorStore.emptyWorkspaceKey], 'false');
  });

  test('every runtime kind has a teaching template', () {
    for (final DocumentTypeAdapter type in DocumentTypeRegistry.all) {
      if (type.kind == WorkspaceDocKind.panel) continue;
      expect(
        type.templateSections.expand(
          (DocumentTemplateSection section) => section.templates,
        ),
        isNotEmpty,
        reason: type.noun,
      );
    }
    expect(
      DocumentTypes.menu.templateSections
          .expand((DocumentTemplateSection section) => section.templates)
          .map((DocumentTemplate template) => template.id),
      contains('feature-gallery'),
    );
    expect(
      DocumentTypes.containerPreview.templateSections
          .expand((DocumentTemplateSection section) => section.templates)
          .map((DocumentTemplate template) => template.id),
      contains('all-elements'),
    );
  });
}

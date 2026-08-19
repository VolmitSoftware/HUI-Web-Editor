library;

import 'dart:math' as math;

import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/logic/gloss_text.dart';
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
      motd.entries.every(
        (GlossMotdEntry entry) => entry.lines.any(
          (String line) => line.contains('|animation.rainbow|'),
        ),
      ),
      isTrue,
      reason: 'every entry should visibly animate when randomization opens it',
    );

    final EditorStore motdStore = _store();
    DocumentTypes.motd.createNew(motdStore);
    final String motdId = motdStore.workspace.activeId!;
    expect(
      randomizeShowcaseDocument(motdStore, motdId, random: math.Random(4)),
      isTrue,
    );
    final String animatedLine = motdStore.motdDoc!.entries.first.lines.last;
    final GlossLineRender firstFrame = renderGlossLine(
      animatedLine,
      animations: motdStore.workspaceAnimations,
      nowMs: 0,
    );
    final GlossLineRender secondFrame = renderGlossLine(
      animatedLine,
      animations: motdStore.workspaceAnimations,
      nowMs: 500,
    );
    expect(firstFrame.isAnimated, isTrue);
    expect(secondFrame.isAnimated, isTrue);
    final List<int> firstColors = firstFrame.pieces
        .whereType<GlossTextRun>()
        .map((GlossTextRun run) => run.span.color)
        .toList();
    final List<int> secondColors = secondFrame.pieces
        .whereType<GlossTextRun>()
        .map((GlossTextRun run) => run.span.color)
        .toList();
    expect(
      firstColors,
      isNot(secondColors),
      reason: 'the shipped rainbow changes its rendered colour every 500 ms',
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
    expect(scoreboard.lines.join('\n'), contains('Magic_Psycho'));
    expect(scoreboard.lines.join('\n'), contains('SwiftSwamp smells >.<'));

    final GlossHologramDoc hologram = buildRandomHologramShowcase(
      GlossHologramDoc(revision: 3),
      math.Random(4),
    );
    expect(hologram.lines.join('\n'), contains('Cyberpwn'));
    expect(hologram.lines.join('\n'), contains('Puretie'));

    final GlossBubbleStyleDoc bubble = buildRandomBubbleShowcase(
      GlossBubbleStyleDoc(revision: 5),
      math.Random(4),
    );
    expect(bubble.effectiveWordWrapChars, glossBubbleMaxWordWrapChars);
    expect(bubble.effectiveMaxAliveMs, greaterThanOrEqualTo(12000));
    expect(bubble.effectivePrefix, isNotEmpty);

    final GlossTablistDoc tablist = buildRandomTablistShowcase(
      GlossTablistDoc(revision: 6),
      math.Random(4),
    );
    expect(tablist.header, contains('|animation.rainbow|'));
    expect(tablist.footer, contains('Magic_Psycho'));
    expect(tablist.footer, contains('SwiftSwamp'));
    expect(tablist.footer, contains('Cyberpwn'));
    expect(tablist.footer, contains('Puretie'));
    expect(
      tablist.effectiveNameFormats.keys,
      containsAll(<String>['_op', 'owner', 'developer', 'moderator', 'vip']),
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

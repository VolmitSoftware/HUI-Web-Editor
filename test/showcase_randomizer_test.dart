library;

import 'dart:math' as math;

import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/logic/animation_validation.dart';
import 'package:gloss_editor/logic/bubble_validation.dart';
import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/logic/preview_card_scene.dart';
import 'package:gloss_editor/logic/preview_sim.dart';
import 'package:gloss_editor/logic/preview_variant_resolver.dart';
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

  test('container showcase is a procedural furnace expression lab', () {
    final String first = encodeHuiPreviewDoc(
      buildRandomPreviewShowcase(math.Random(9)),
    );
    final String repeated = encodeHuiPreviewDoc(
      buildRandomPreviewShowcase(math.Random(9)),
    );
    final String different = encodeHuiPreviewDoc(
      buildRandomPreviewShowcase(math.Random(10)),
    );
    expect(repeated, first);
    expect(different, isNot(first));

    for (int seed = 0; seed < 64; seed++) {
      final HuiPreviewDoc doc = buildRandomPreviewShowcase(math.Random(seed));
      expect(doc.match.blocks, <String>['FURNACE', 'BLAST_FURNACE', 'SMOKER']);
      expect(
        doc.elements.map((HuiPreviewElement element) => element.type).toSet(),
        containsAll(previewElementTypes),
      );
      final String code = encodeHuiPreviewDoc(doc);
      expect(code, contains('cookTime'));
      expect(code, contains('cookTimeTotal'));
      expect(code, contains('burnTime'));
      expect(code, contains('fuelSeconds'));
      expect(code, contains('bankedXp'));
      expect(code, contains('surge.active'));
      expect(code, contains('inventory.occupied'));
      expect(code, contains('repeat'));
      expect(code, contains('palette'));
      expect(code, contains('mix'));
      expect(code, contains('sin'));
      expect(code, contains('bar'));
      expect(code, contains('lang'));
      expect(code, contains('lang(vars.activeItemKey'));
      expect(code, contains('occupied'));
      expect(code, contains('item'));
      expect(code, contains('count'));

      for (final String? material in <String?>[
        null,
        'BLAST_FURNACE',
        'SMOKER',
      ]) {
        final PreviewSim sim = PreviewSim('furnace');
        sim.vars = PreviewSim.parseVars(previewVarsForMaterial(doc, material));
        final List<String> errors = <String>[];
        final PreviewCardScene scene = buildCardScene(
          doc,
          sim,
          onError: errors.add,
        );
        expect(errors, isEmpty, reason: 'seed $seed, material $material');
        expect(scene.items, isNotEmpty);
      }
    }
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
    final List<HuiComponentData> clickables = menu.components
        .map((HuiComponent component) => component.data)
        .where(
          (HuiComponentData data) =>
              data is HuiButtonData || data is HuiToggleData,
        )
        .toList();
    expect(
      clickables.any(
        (HuiComponentData data) => switch (data) {
          HuiButtonData() =>
            data.hoverDurationTicks != huiRuntimeDefaultHoverDurationTicks,
          HuiToggleData() =>
            data.hoverDurationTicks != huiRuntimeDefaultHoverDurationTicks,
          HuiDecorationData() => false,
        },
      ),
      isTrue,
    );
    expect(
      clickables.whereType<HuiToggleData>().every(
        (HuiToggleData data) => data.hitbox != null,
      ),
      isTrue,
    );
  });

  test('random animation showcase is a smooth procedural hue gradient', () {
    for (int seed = 0; seed < 64; seed++) {
      final GlossAnimationDoc animation = buildRandomAnimationShowcase(
        GlossAnimationDoc(revision: 9),
        math.Random(seed),
      );
      expect(animation.revision, 9, reason: 'seed $seed');
      expect(animation.frameIntervalMs, 50, reason: 'seed $seed');
      expect(
        animation.frames.length,
        inInclusiveRange(48, 60),
        reason: 'seed $seed',
      );
      expect(animation.frames.toSet(), hasLength(animation.frames.length));
      expect(
        animation.frames,
        everyElement(matches(RegExp(r'^\[[0-9A-F]{6}\]'))),
        reason: 'seed $seed',
      );
      expect(validateAnimationDoc(animation), isEmpty, reason: 'seed $seed');
    }
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
          (String line) => renderGlossLine(
            line,
            animations: _store().workspaceAnimations,
          ).isAnimated,
        ),
      ),
      isTrue,
      reason: 'every entry should contain authored animation',
    );
    expect(
      motd.entries.expand((GlossMotdEntry entry) => entry.lines).join(),
      isNot(contains('%')),
      reason: 'server-list pings have no player for PlaceholderAPI',
    );

    final EditorStore motdStore = _store();
    DocumentTypes.motd.createNew(motdStore);
    final String motdId = motdStore.workspace.activeId!;
    expect(
      randomizeShowcaseDocument(motdStore, motdId, random: math.Random(4)),
      isTrue,
    );
    final String animatedLine = motdStore.motdDoc!.entries.first.lines.first;
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
      reason: 'the shipped rainbow advances through its smooth RGB gradient',
    );

    final GlossScoreboardDoc scoreboard = buildRandomScoreboardShowcase(
      GlossScoreboardDoc(revision: 11),
      math.Random(4),
    );
    expect(scoreboard.revision, 11);
    expect(scoreboard.lines.length, inInclusiveRange(8, glossBoardMaxLines));
    expect(
      scoreboard.lines.any((String line) => renderGlossLine(line).isAnimated),
      isTrue,
    );
    expect(
      scoreboard.lines.any((String line) => line.contains('{{ player.name }}')),
      isTrue,
    );
    expect(scoreboard.hideNumbers, isTrue);
    expect(scoreboard.lines.join('\n'), contains("papi('vault_prefix',"));
    expect(scoreboard.lines.join('\n'), contains("metric('react.tick-ms',"));
    expect(scoreboard.lines.join('\n'), contains('{{'));

    final GlossHologramDoc hologram = buildRandomHologramShowcase(
      GlossHologramDoc(revision: 3),
      math.Random(4),
    );
    expect(hologram.lines.join('\n'), contains('{{ player.name }}'));
    expect(hologram.lines.join('\n'), contains('server.tps'));

    final GlossBubbleStyleDoc bubble = buildRandomBubbleShowcase(
      GlossBubbleStyleDoc(revision: 5),
      math.Random(4),
    );
    expect(bubble.effectiveWordWrapChars, inInclusiveRange(36, 108));
    expect(bubble.effectiveMaxAliveMs, greaterThanOrEqualTo(9000));
    expect(bubble.effectivePrefix, isNotEmpty);
    final String motion = bubble.motion.toJson().toString();
    expect(motion, anyOf(contains('smoothstep'), contains('pow(')));
    expect(motion, anyOf(contains('sin('), contains('* t')));
    expect(bubble.shimmer.spawn, isTrue);
    expect(bubble.shimmer.flyAway, isTrue);
    expect(bubble.shimmer.colorIsValid, isTrue);
    expect(
      bubble.shimmer.effectiveFlyAwayLeadMs,
      greaterThanOrEqualTo(bubble.shimmer.effectiveDurationMs),
    );

    final GlossTablistDoc tablist = buildRandomTablistShowcase(
      GlossTablistDoc(revision: 6),
      math.Random(4),
    );
    expect(tablist.header, contains('{{ player.name }}'));
    expect(tablist.header, contains('server.tps'));
    expect(tablist.header, contains("papi('vault_prefix',"));
    expect(renderGlossLine(tablist.footer).isAnimated, isTrue);
    expect(
      tablist.effectiveNameFormats.keys,
      containsAll(<String>['_op', 'owner', 'developer', 'moderator', 'vip']),
    );
  });

  test('random bubbles demonstrate diverse procedural motion safely', () {
    final Set<String> expressions = <String>{};
    final Set<String> shimmers = <String>{};
    for (int seed = 0; seed < 128; seed++) {
      final GlossBubbleStyleDoc bubble = buildRandomBubbleShowcase(
        GlossBubbleStyleDoc(),
        math.Random(seed),
      );
      final Map<String, dynamic> motion = bubble.motion.toJson();
      expressions.add(motion.toString());
      shimmers.add(bubble.shimmer.toJson().toString());
      expect(
        validateBubbleStyleDoc(
          bubble,
        ).where((HuiIssue issue) => issue.severity == HuiSeverity.error),
        isEmpty,
        reason: 'seed $seed',
      );
    }
    final String combined = expressions.join('\n');
    expect(expressions.length, greaterThan(100));
    expect(combined, contains('smoothstep'));
    expect(combined, contains('pow('));
    expect(combined, contains('sin('));
    expect(combined, contains('cos('));
    expect(combined, contains('stackIndex'));
    expect(combined, contains('lineCount'));
    expect(combined, contains('seed'));
    expect(shimmers.length, greaterThan(100));
  });

  test('procedural showcases vary and scatter every named easter egg', () {
    final Set<String> seenNames = <String>{};
    final Set<String> scoreboards = <String>{};
    final Set<String> motds = <String>{};
    for (int seed = 0; seed < 128; seed++) {
      final GlossScoreboardDoc scoreboard = buildRandomScoreboardShowcase(
        GlossScoreboardDoc(),
        math.Random(seed),
      );
      final GlossMotdDoc motd = buildRandomMotdShowcase(
        GlossMotdDoc(),
        math.Random(seed),
      );
      final String all = <String>[
        scoreboard.title,
        ...scoreboard.lines,
        for (final GlossMotdEntry entry in motd.entries) ...entry.lines,
      ].join('\n');
      for (final String name in <String>[
        'Magic_Psycho',
        'SwiftSwamp',
        'Cyberpwn',
        'Puretie',
      ]) {
        if (all.contains(name)) seenNames.add(name);
      }
      scoreboards.add(encodeGlossScoreboardDoc(scoreboard));
      motds.add(encodeGlossMotdDoc(motd));
    }
    expect(
      seenNames,
      containsAll(<String>[
        'Magic_Psycho',
        'SwiftSwamp',
        'Cyberpwn',
        'Puretie',
      ]),
    );
    expect(scoreboards.length, greaterThan(100));
    expect(motds.length, greaterThan(100));
  });

  test('seeded scoreboard samples fit the runtime row budget', () {
    final EditorStore store = _store();
    for (int seed = 0; seed < 256; seed++) {
      final GlossScoreboardDoc scoreboard = buildRandomScoreboardShowcase(
        GlossScoreboardDoc(),
        math.Random(seed),
      );
      for (int index = 0; index < scoreboard.lines.length; index++) {
        final String line = scoreboard.lines[index];
        final GlossScoreboardLineMeasure measure = measureGlossScoreboardLine(
          line,
          store.workspaceAnimations,
          emoji: store.workspaceEmoji,
        );
        expect(
          measure.truncated,
          isFalse,
          reason:
              'seed $seed, line $index: $line rendered '
              '${measure.visibleLength} visible characters from '
              '${measure.encodedLength} encoded characters',
        );
      }
    }
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

/// The simulation panel's control model: which controls a category shows,
/// their bounds, how an edit turns into a [PreviewSim] override or a slot
/// edit, and the play/pause/step/reset semantics the panel and the card
/// surface's ticker share.
///
/// DOM-free: everything here runs on the VM, exactly like [PreviewSim] itself.
library;

import 'package:gloss_editor/logic/preview_sim.dart';
import 'package:gloss_editor/logic/preview_sim_controls.dart';
import 'package:gloss_editor/model/preview_doc.dart';
import 'package:test/test.dart';

HuiPreviewDoc _furnaceDoc() =>
    HuiPreviewDoc(match: HuiPreviewMatch(blocks: <String>['FURNACE']));

HuiPreviewDoc _brewingDoc() =>
    HuiPreviewDoc(match: HuiPreviewMatch(blocks: <String>['BREWING_STAND']));

void main() {
  group('previewSimControlsFor', () {
    test('excludes surge variables from every category', () {
      for (final String category in previewSimCategories) {
        final List<String> names = previewSimControlsFor(
          category,
        ).map((c) => c.name).toList();
        expect(names, isNot(contains('surge.active')));
        expect(names, isNot(contains('surge.gain')));
      }
    });

    test(
      'every non-surge published variable has a control, in every category',
      () {
        final Set<String> published = <String>{
          for (final List<String> groups in previewSimCategoryGroups.values)
            for (final String group in groups)
              ...?previewSimGroupVariables[group],
        }..removeAll(<String>{'surge.active', 'surge.gain'});

        final Set<String> covered = <String>{
          for (final String category in previewSimCategories)
            for (final PreviewSimVarControl control in previewSimControlsFor(
              category,
            ))
              control.name,
        };
        expect(covered, published);
      },
    );

    test('a furnace gets cookTime and friends but not brewing fields', () {
      final List<String> names = previewSimControlsFor(
        'furnace',
      ).map((c) => c.name).toList();
      expect(
        names,
        containsAll(<String>['cookTime', 'cookTimeTotal', 'burnTime', 'lit']),
      );
      expect(names, isNot(contains('brewTime')));
    });

    test('every numeric control has sane bounds', () {
      for (final String category in previewSimCategories) {
        for (final PreviewSimVarControl control in previewSimControlsFor(
          category,
        )) {
          if (control.kind != PreviewSimControlKind.number) continue;
          expect(
            control.min,
            lessThanOrEqualTo(control.max),
            reason: control.name,
          );
          expect(control.step, greaterThan(0), reason: control.name);
        }
      }
    });

    test('every control has a non-empty display label', () {
      for (final String category in previewSimCategories) {
        for (final PreviewSimVarControl control in previewSimControlsFor(
          category,
        )) {
          expect(previewSimVarLabel(control.name), isNotEmpty);
        }
      }
    });
  });

  group('previewSimCategorySupportsSurge', () {
    test('only furnace and brewing', () {
      expect(previewSimCategorySupportsSurge('furnace'), isTrue);
      expect(previewSimCategorySupportsSurge('brewing'), isTrue);
      for (final String category in previewSimCategories.where(
        (c) => c != 'furnace' && c != 'brewing',
      )) {
        expect(
          previewSimCategorySupportsSurge(category),
          isFalse,
          reason: category,
        );
      }
    });
  });

  group('previewSimCategorySupportsSlots', () {
    test('every inventory-backed category', () {
      for (final String category in <String>[
        'chest',
        'furnace',
        'brewing',
        'jukebox',
        'enderChest',
        'entity',
      ]) {
        expect(
          previewSimCategorySupportsSlots(category),
          isTrue,
          reason: category,
        );
      }
    });

    test('categories with no inventory', () {
      for (final String category in <String>[
        'beehive',
        'cauldron',
        'statics',
      ]) {
        expect(
          previewSimCategorySupportsSlots(category),
          isFalse,
          reason: category,
        );
      }
    });
  });

  group('previewSimCoerceOverride', () {
    const PreviewSimVarControl numControl = PreviewSimVarControl(
      'cookTime',
      PreviewSimControlKind.number,
      max: 100,
    );

    test('clamps below the minimum', () {
      expect(previewSimCoerceOverride(numControl, -5), 0.0);
    });

    test('clamps above the maximum', () {
      expect(previewSimCoerceOverride(numControl, 500), 100.0);
    });

    test('rounds to the declared decimals', () {
      const PreviewSimVarControl xp = PreviewSimVarControl(
        'bankedXp',
        PreviewSimControlKind.number,
        max: 100,
        step: 0.1,
        decimals: 2,
      );
      expect(previewSimCoerceOverride(xp, 1.23456), 1.23);
    });

    test('a non-finite input falls back to the minimum', () {
      expect(previewSimCoerceOverride(numControl, double.nan), 0.0);
      expect(previewSimCoerceOverride(numControl, double.infinity), 100.0);
    });

    test('boolean control coerces a string and passes through a bool', () {
      const PreviewSimVarControl lit = PreviewSimVarControl(
        'lit',
        PreviewSimControlKind.boolean,
      );
      expect(previewSimCoerceOverride(lit, true), true);
      expect(previewSimCoerceOverride(lit, 'true'), true);
      expect(previewSimCoerceOverride(lit, 'nope'), false);
    });

    test('string control stringifies a non-string input', () {
      const PreviewSimVarControl blockType = PreviewSimVarControl(
        'blockType',
        PreviewSimControlKind.string,
      );
      expect(previewSimCoerceOverride(blockType, 'CHEST'), 'CHEST');
      expect(previewSimCoerceOverride(blockType, 5), '5');
    });
  });

  group('override application on a real PreviewSim', () {
    test('set then read back through variable()', () {
      final PreviewSim sim = PreviewSim('furnace');
      const PreviewSimVarControl cookTime = PreviewSimVarControl(
        'cookTime',
        PreviewSimControlKind.number,
        max: 1200,
      );
      previewSimSetOverride(sim, cookTime, 999999.0);
      expect(sim.variable('cookTime'), 1200.0);
    });

    test('clearing hands the name back to the live sample', () {
      final PreviewSim sim = PreviewSim('furnace');
      const PreviewSimVarControl cookTime = PreviewSimVarControl(
        'cookTime',
        PreviewSimControlKind.number,
        max: 1200,
      );
      final Object? original = sim.variable('cookTime');
      previewSimSetOverride(sim, cookTime, 50.0);
      expect(sim.variable('cookTime'), 50.0);
      previewSimClearOverride(sim, 'cookTime');
      expect(sim.variable('cookTime'), original);
    });
  });

  group('previewSimSetSlot / previewSimSlotAt', () {
    test('adds a new slot', () {
      final List<SimSlotItem> items = previewSimSetSlot(
        const <SimSlotItem>[],
        2,
        material: 'IRON_ORE',
        count: 4,
      );
      expect(previewSimSlotAt(items, 2)?.material, 'IRON_ORE');
      expect(previewSimSlotAt(items, 2)?.count, 4);
    });

    test('replaces an existing slot rather than duplicating it', () {
      final List<SimSlotItem> items = previewSimSetSlot(
        const <SimSlotItem>[SimSlotItem(0, 'COAL', 1)],
        0,
        material: 'DIAMOND',
        count: 2,
      );
      expect(items, hasLength(1));
      expect(previewSimSlotAt(items, 0)?.material, 'DIAMOND');
    });

    test('an empty material clears the slot', () {
      final List<SimSlotItem> items = previewSimSetSlot(
        const <SimSlotItem>[SimSlotItem(0, 'COAL', 1)],
        0,
        material: '   ',
        count: 5,
      );
      expect(previewSimSlotAt(items, 0), isNull);
    });

    test('a zero or negative count clears the slot', () {
      final List<SimSlotItem> items = previewSimSetSlot(
        const <SimSlotItem>[SimSlotItem(0, 'COAL', 1)],
        0,
        material: 'COAL',
        count: 0,
      );
      expect(previewSimSlotAt(items, 0), isNull);
    });

    test('stays sorted by slot index', () {
      List<SimSlotItem> items = previewSimSetSlot(
        const <SimSlotItem>[],
        3,
        material: 'A',
        count: 1,
      );
      items = previewSimSetSlot(items, 1, material: 'B', count: 1);
      expect(items.map((SimSlotItem i) => i.slot), <int>[1, 3]);
    });

    test('an unknown slot reads as absent', () {
      expect(previewSimSlotAt(const <SimSlotItem>[], 9), isNull);
    });
  });

  group('previewSimClockWanted', () {
    test('requires a box to paint into', () {
      expect(
        previewSimClockWanted(
          hasArea: false,
          isPreviewDoc: true,
          playing: true,
          autoAnimated: true,
          forcePlay: false,
        ),
        isFalse,
      );
    });

    test('requires a preview document', () {
      expect(
        previewSimClockWanted(
          hasArea: true,
          isPreviewDoc: false,
          playing: true,
          autoAnimated: true,
          forcePlay: true,
        ),
        isFalse,
      );
    });

    test('requires playing regardless of forcePlay', () {
      expect(
        previewSimClockWanted(
          hasArea: true,
          isPreviewDoc: true,
          playing: false,
          autoAnimated: true,
          forcePlay: true,
        ),
        isFalse,
      );
    });

    test('an auto-animated document runs without forcePlay', () {
      expect(
        previewSimClockWanted(
          hasArea: true,
          isPreviewDoc: true,
          playing: true,
          autoAnimated: true,
          forcePlay: false,
        ),
        isTrue,
      );
    });

    test('forcePlay alone runs the clock on a static document', () {
      expect(
        previewSimClockWanted(
          hasArea: true,
          isPreviewDoc: true,
          playing: true,
          autoAnimated: false,
          forcePlay: true,
        ),
        isTrue,
      );
    });

    test('neither auto-animated nor forced means no clock', () {
      expect(
        previewSimClockWanted(
          hasArea: true,
          isPreviewDoc: true,
          playing: true,
          autoAnimated: false,
          forcePlay: false,
        ),
        isFalse,
      );
    });
  });

  group('PreviewSimController', () {
    test('starts on statics before any sync', () {
      final PreviewSimController controller = PreviewSimController();
      expect(controller.category, 'statics');
      expect(controller.autoAnimated, isFalse);
    });

    test('sync resolves the auto category from the document', () {
      final PreviewSimController controller = PreviewSimController();
      controller.sync(_furnaceDoc(), 0, PreviewLangCatalog.empty);
      expect(controller.category, 'furnace');
      expect(controller.sim.blockType, 'FURNACE');
    });

    test(
      'sync is a no-op when neither the revision nor the category changed',
      () {
        final PreviewSimController controller = PreviewSimController();
        final HuiPreviewDoc doc = _furnaceDoc();
        controller.sync(doc, 1, PreviewLangCatalog.empty);
        final PreviewSim first = controller.sim;
        controller.sync(doc, 1, PreviewLangCatalog.empty);
        expect(identical(controller.sim, first), isTrue);
      },
    );

    test('a document swap resets a manual category pick', () {
      final PreviewSimController controller = PreviewSimController();
      controller.sync(_furnaceDoc(), 0, PreviewLangCatalog.empty);
      controller.setCategory('brewing');
      expect(controller.category, 'brewing');

      // A NEW instance with the same content — mutatePreview never swaps the
      // instance, only import/undo/redo/applyCode do, so identity is the
      // signal a real swap uses too.
      controller.sync(_furnaceDoc(), 0, PreviewLangCatalog.empty);
      expect(controller.categoryOverride, isNull);
      expect(controller.category, 'furnace');
    });

    test('a document swap also resets the force-tick latch', () {
      final PreviewSimController controller = PreviewSimController();
      controller.sync(_furnaceDoc(), 0, PreviewLangCatalog.empty);
      controller.setForcePlay(true);
      expect(controller.forcePlay, isTrue);

      // Same signal the category-pick reset uses: a new instance, not an
      // in-place edit of the one `sync` last saw.
      controller.sync(_furnaceDoc(), 0, PreviewLangCatalog.empty);
      expect(controller.forcePlay, isFalse);
    });

    test('an in-place edit (same document instance) keeps a manual pick', () {
      final PreviewSimController controller = PreviewSimController();
      final HuiPreviewDoc doc = _furnaceDoc();
      controller.sync(doc, 0, PreviewLangCatalog.empty);
      controller.setCategory('brewing');
      controller.sync(doc, 1, PreviewLangCatalog.empty);
      expect(controller.category, 'brewing');
      expect(controller.categoryOverride, 'brewing');
    });

    test('an in-place edit keeps the force-tick latch too', () {
      final PreviewSimController controller = PreviewSimController();
      final HuiPreviewDoc doc = _furnaceDoc();
      controller.sync(doc, 0, PreviewLangCatalog.empty);
      controller.setForcePlay(true);
      controller.sync(doc, 1, PreviewLangCatalog.empty);
      expect(controller.forcePlay, isTrue);
    });

    test('setCategory resolves synchronously, no second sync needed', () {
      final PreviewSimController controller = PreviewSimController();
      controller.sync(_furnaceDoc(), 0, PreviewLangCatalog.empty);
      controller.setCategory('brewing');
      expect(controller.category, 'brewing');
      expect(controller.sim.blockType, 'BREWING_STAND');
    });

    test('setCategory(null) follows the document auto category again', () {
      final PreviewSimController controller = PreviewSimController();
      controller.sync(_furnaceDoc(), 0, PreviewLangCatalog.empty);
      controller.setCategory('brewing');
      controller.setCategory(null);
      expect(controller.category, 'furnace');
      expect(controller.categoryOverride, isNull);
    });

    test(
      'setCategory before any sync still resolves the requested category',
      () {
        final PreviewSimController controller = PreviewSimController();
        controller.setCategory('furnace');
        expect(controller.category, 'furnace');
      },
    );

    test('every mutator notifies its listeners', () {
      final PreviewSimController controller = PreviewSimController();
      controller.sync(_furnaceDoc(), 0, PreviewLangCatalog.empty);
      int notifications = 0;
      controller.addListener(() => notifications++);

      controller.setOverride(previewSimControlsFor('furnace').first, 5.0);
      controller.step();
      controller.reset();
      controller.setSurge(true);
      controller.setForcePlay(true);
      controller.setSlot(0, material: 'DIAMOND', count: 3);
      controller.setCategory('brewing');

      expect(notifications, 7);
    });

    test('reset restores category defaults but keeps a pinned override', () {
      final PreviewSimController controller = PreviewSimController();
      controller.sync(_furnaceDoc(), 0, PreviewLangCatalog.empty);
      final PreviewSimVarControl cookTime = previewSimControlsFor(
        'furnace',
      ).firstWhere((c) => c.name == 'cookTime');
      controller.setOverride(cookTime, 42.0);
      controller.reset();
      expect(controller.sim.overrides['cookTime'], 42.0);
    });

    test('clearOverride is a no-op (no notify) when nothing is pinned', () {
      final PreviewSimController controller = PreviewSimController();
      int notifications = 0;
      controller.addListener(() => notifications++);
      controller.clearOverride('cookTime');
      expect(notifications, 0);
    });

    test('setCategory to the value it already has does not notify', () {
      final PreviewSimController controller = PreviewSimController();
      controller.sync(_furnaceDoc(), 0, PreviewLangCatalog.empty);
      controller.setCategory(
        'furnace',
      ); // already the auto-resolved category...
      int notifications = 0;
      controller.addListener(() => notifications++);
      controller.setCategory('furnace');
      expect(notifications, 0);
    });

    test('a non-positive tick is a no-op', () {
      final PreviewSimController controller = PreviewSimController();
      controller.sync(_furnaceDoc(), 0, PreviewLangCatalog.empty);
      int notifications = 0;
      controller.addListener(() => notifications++);
      controller.tick(0);
      controller.tick(-5);
      expect(notifications, 0);
    });

    test('a running furnace really advances via step()', () {
      final PreviewSimController controller = PreviewSimController();
      controller.sync(_furnaceDoc(), 0, PreviewLangCatalog.empty);
      final double before = controller.sim.cookTime;
      controller.step();
      expect(controller.sim.cookTime, isNot(before));
    });

    test('a brewing document auto-selects the brewing category', () {
      final PreviewSimController controller = PreviewSimController();
      controller.sync(_brewingDoc(), 0, PreviewLangCatalog.empty);
      expect(controller.category, 'brewing');
    });
  });
}

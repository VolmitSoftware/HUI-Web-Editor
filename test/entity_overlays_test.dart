library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/logic/entity_overlay_preview.dart';
import 'package:gloss_editor/logic/entity_overlay_validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/services/showcase_randomizer.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:test/test.dart';

import 'support/gloss_repository.dart';

void main() {
  test('editor defaults match the shipped Gloss document and JSON schema', () {
    final Map<String, Object?> expected =
        jsonDecode(
              File(
                glossRepositoryFilePath(
                  'src/main/resources/defaults/entity-overlays/default.json',
                ),
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final Map<String, Object?> schema =
        jsonDecode(
              File(
                glossRepositoryFilePath(
                  'schema/gloss-entity-overlays.schema.json',
                ),
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final Map<String, Object?> properties =
        schema['properties']! as Map<String, Object?>;
    final Map<String, Object?> actual = GlossEntityOverlaysDoc().toJson();
    expect(actual, expected);
    expect(properties.keys, unorderedEquals(actual.keys));
    for (final MapEntry<String, Object?> entry in properties.entries) {
      final Map<String, Object?> property =
          entry.value! as Map<String, Object?>;
      if (property.containsKey('default')) {
        expect(actual[entry.key], property['default'], reason: entry.key);
      }
    }
  });

  test(
    'false settings, empty lists, formats and unknown fields survive round trips',
    () {
      final GlossEntityOverlaysDoc doc = GlossEntityOverlaysDoc(
        enabled: false,
        includePlayers: false,
        showNames: false,
        showHealthNumbers: false,
        showCombatStats: false,
        excludedEntityTypes: <String>[],
        nameFormat: '',
        extras: <String, Object?>{
          'custom': <String, Object?>{'value': 1},
        },
      );
      final GlossEntityOverlaysDoc next = decodeGlossEntityOverlaysDoc(
        encodeGlossEntityOverlaysDoc(doc),
      );
      expect(next.toJson(), doc.toJson());
      expect(validateEntityOverlaysDoc(next), isEmpty);
      expect(
        () => decodeGlossEntityOverlaysDoc('{"schemaVersion":2}'),
        throwsA(isA<HuiFormatException>()),
      );
    },
  );

  test('validation identifies every field outside runtime ranges', () {
    final GlossEntityOverlaysDoc doc = GlossEntityOverlaysDoc(
      range: 0,
      updateIntervalTicks: 41,
      maxEntitiesPerViewer: 0,
      verticalOffset: 9,
      scale: 0,
      healthSegments: 41,
      hitHighlightMs: -1,
    );
    expect(
      validateEntityOverlaysDoc(doc).map((issue) => issue.path),
      unorderedEquals(<String>[
        r'$.range',
        r'$.updateIntervalTicks',
        r'$.maxEntitiesPerViewer',
        r'$.verticalOffset',
        r'$.scale',
        r'$.healthSegments',
        r'$.hitHighlightMs',
      ]),
    );
  });

  test(
    'malformed exclusion lists fail instead of silently removing entries',
    () {
      for (final String key in <String>[
        'blacklistWorlds',
        'excludedEntityTypes',
      ]) {
        for (final Object raw in <Object>[
          42,
          'world',
          <Object>['world', false],
        ]) {
          final Map<String, Object?> document =
              GlossEntityOverlaysDoc().toJson()..[key] = raw;
          expect(
            () => GlossEntityOverlaysDoc.fromJson(document),
            throwsA(isA<HuiFormatException>()),
          );
        }
      }
    },
  );

  test(
    'Insight retains its acquisition range and final numbers are compact',
    () {
      final GlossEntityOverlaysDoc doc = GlossEntityOverlaysDoc(
        range: 2,
        damageFormat: ' ',
        statsFormat: '',
      );
      final EntityOverlayPreview preview = resolveEntityOverlayPreview(
        doc,
        const EntityOverlaySample(
          adapt: true,
          insight: true,
          distance: 8,
          health: 14.01,
          damage: 1,
        ),
      );
      expect(preview.visible, isTrue);
      expect(preview.lines[1], endsWith(' &f14&7/20'));
      expect(preview.lines, hasLength(5));
      expect(preview.lines.last, contains('Detection range'));
      expect(preview.lines.any((String line) => line.trim().isEmpty), isFalse);
    },
  );

  test(
    'nearby living entities get names, segmented health and final combat stats',
    () {
      final EntityOverlayPreview preview = resolveEntityOverlayPreview(
        GlossEntityOverlaysDoc(),
        const EntityOverlaySample(),
      );
      expect(preview.visible, isTrue);
      expect(preview.lines.first, '&fSample sentinel');
      expect(preview.lines[1], '&a|||||||&c&8||| &f14&7/20');
      expect(preview.lines.last, '&7ATK &f3 &8| &7ARM &f2');
    },
  );

  test('damage marks lost segments and expires at the configured boundary', () {
    final GlossEntityOverlaysDoc doc = GlossEntityOverlaysDoc();
    final EntityOverlayPreview hit = resolveEntityOverlayPreview(
      doc,
      const EntityOverlaySample(health: 11, damage: 3, sinceHitMs: 749),
    );
    expect(hit.lines[1], startsWith('&a||||||&c|&8|||'));
    expect(hit.lines, contains('&c-3'));
    final EntityOverlayPreview expired = resolveEntityOverlayPreview(
      doc,
      const EntityOverlaySample(health: 11, damage: 3, sinceHitMs: 750),
    );
    expect(expired.lines, isNot(contains('&c-3')));
    expect(expired.lines[1], startsWith('&a||||||&c&8||||'));
  });

  test('React count joins the custom name or the unnamed health line', () {
    final GlossEntityOverlaysDoc doc = GlossEntityOverlaysDoc();
    expect(
      resolveEntityOverlayPreview(
        doc,
        const EntityOverlaySample(react: true),
      ).lines.first,
      '&fSample sentinel &7x4',
    );
    final EntityOverlayPreview unnamed = resolveEntityOverlayPreview(
      doc,
      const EntityOverlaySample(name: '', react: true),
    );
    expect(unnamed.lines.first, endsWith(' &7x4'));
    expect(unnamed.lines, hasLength(2));
    expect(
      resolveEntityOverlayPreview(
        doc,
        const EntityOverlaySample(react: true, stackCount: 1),
      ).lines.first,
      '&fSample sentinel',
    );
  });

  test(
    'Insight enriches global overlays and exclusive mode requires Insight',
    () {
      final GlossEntityOverlaysDoc doc = GlossEntityOverlaysDoc();
      expect(
        resolveEntityOverlayPreview(
          doc,
          const EntityOverlaySample(adapt: true),
        ).visible,
        isTrue,
      );
      expect(
        resolveEntityOverlayPreview(
          doc,
          const EntityOverlaySample(adapt: true, adaptExclusive: true),
        ).visible,
        isFalse,
      );
      final EntityOverlayPreview insight = resolveEntityOverlayPreview(
        doc,
        const EntityOverlaySample(
          adapt: true,
          adaptExclusive: true,
          insight: true,
        ),
      );
      expect(insight.visible, isTrue);
      expect(insight.lines[2], '&bZombie');
      expect(insight.lines.last, contains('ATK'));
      expect(
        resolveEntityOverlayPreview(
          doc,
          const EntityOverlaySample(adaptExclusive: true),
        ).visible,
        isTrue,
      );
    },
  );

  test('visibility and content toggles match the configured audience', () {
    final GlossEntityOverlaysDoc doc = GlossEntityOverlaysDoc(
      showNames: false,
      showHealthNumbers: false,
      showCombatStats: false,
    );
    expect(
      resolveEntityOverlayPreview(doc, const EntityOverlaySample()).lines,
      <String>['&a|||||||&c&8|||'],
    );
    expect(
      resolveEntityOverlayPreview(
        doc,
        const EntityOverlaySample(distance: 17),
      ).visible,
      isFalse,
    );
    expect(
      resolveEntityOverlayPreview(
        doc,
        const EntityOverlaySample(health: 0),
      ).visible,
      isFalse,
    );
    expect(
      resolveEntityOverlayPreview(
        doc,
        const EntityOverlaySample(entityType: 'ARMOR_STAND'),
      ).visible,
      isFalse,
    );
    doc.includePlayers = false;
    expect(
      resolveEntityOverlayPreview(
        doc,
        const EntityOverlaySample(player: true),
      ).visible,
      isFalse,
    );
    doc.blacklistWorlds = <String>['world'];
    expect(
      resolveEntityOverlayPreview(doc, const EntityOverlaySample()).visible,
      isFalse,
    );
    doc.blacklistWorlds.clear();
    doc.enabled = false;
    expect(
      resolveEntityOverlayPreview(doc, const EntityOverlaySample()).visible,
      isFalse,
    );
  });

  test('creation, import, typed mutation, undo and randomization work', () {
    final EditorStore store = EditorStore(
      workspace: Workspace(autoLoad: false),
      autosaveDelay: Duration.zero,
    );
    addTearDown(store.dispose);
    store.newGlossDocument(DocumentTypes.entityOverlays);
    expect(store.workspace.active!.runtimeId, 'default');
    expect(
      DocumentTypeRegistry.byWireKind('entity-overlays'),
      DocumentTypes.entityOverlays,
    );
    store.mutateEntityOverlays(
      'segments',
      (GlossEntityOverlaysDoc doc) => doc.healthSegments = 18,
    );
    expect(store.entityOverlaysDoc!.healthSegments, 18);
    expect(store.performUndo(), isTrue);
    expect(store.entityOverlaysDoc!.healthSegments, 10);
    final String exported = store.exportJson();
    store.importJsonAsNewDocument('default.json', exported);
    expect(store.docType, DocumentTypes.entityOverlays);
    expect(
      randomizeShowcaseDocument(
        store,
        store.workspace.active!.id,
        random: Random(4),
      ),
      isTrue,
    );
    expect(store.entityOverlaysDoc!.toJson(), isNot(jsonDecode(exported)));
    expect(validateEntityOverlaysDoc(store.entityOverlaysDoc!), isEmpty);
  });

  test(
    'singleton creation and imports preserve one canonical undoable document',
    () {
      final EditorStore store = EditorStore(
        workspace: Workspace(autoLoad: false),
        autosaveDelay: Duration.zero,
      );
      addTearDown(store.dispose);
      store.newGlossDocument(DocumentTypes.entityOverlays, name: 'custom-name');
      final String documentId = store.workspace.active!.id;
      store.mutateEntityOverlays(
        'segments',
        (GlossEntityOverlaysDoc doc) => doc.healthSegments = 18,
      );
      store.newGlossDocument(DocumentTypes.entityOverlays);
      expect(store.workspace.active!.id, documentId);
      expect(store.entityOverlaysDoc!.healthSegments, 18);
      final GlossEntityOverlaysDoc imported = GlossEntityOverlaysDoc(
        healthSegments: 12,
      );
      store.importJsonAsNewDocument(
        'copy.json',
        encodeGlossEntityOverlaysDoc(imported),
      );
      expect(store.workspace.active!.id, documentId);
      expect(store.menuId, 'default');
      expect(store.entityOverlaysDoc!.healthSegments, 12);
      expect(store.performUndo(), isTrue);
      expect(store.entityOverlaysDoc!.healthSegments, 18);
      expect(store.duplicateDocument(documentId), isNull);
      expect(store.renameDocumentRuntimeId(documentId, 'renamed'), isFalse);
      store.setMenuId('renamed');
      expect(store.menuId, 'default');
      store.newDocument(name: 'separate-menu');
      final String menuId = store.workspace.active!.id;
      store.importJson(
        'another-copy.json',
        encodeGlossEntityOverlaysDoc(imported),
      );
      expect(store.workspace.active!.id, documentId);
      expect(store.workspace.byId(menuId), isNotNull);
      expect(store.entityOverlaysDoc!.healthSegments, 12);
      expect(store.performUndo(), isTrue);
      expect(store.entityOverlaysDoc!.healthSegments, 18);
      expect(
        store.workspace.docs.where(
          (WorkspaceDoc doc) => doc.kind == WorkspaceDocKind.entityOverlays,
        ),
        hasLength(1),
      );
    },
  );
}

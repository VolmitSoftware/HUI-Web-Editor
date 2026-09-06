library;

import 'package:gloss_editor/model/gloss_hologram_box.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/logic/entity_overlay_preview.dart';
import 'package:gloss_editor/logic/entity_overlay_validation.dart';
import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/logic/mc_text.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/services/showcase_randomizer.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:test/test.dart';

import 'support/gloss_repository.dart';

final class _OverlayAnimations implements GlossAnimationResolver {
  @override
  List<String> get ids => <String>['pulse'];

  @override
  GlossAnimationDoc? byId(String id) => id == 'pulse'
      ? GlossAnimationDoc(
          frameIntervalMs: 100,
          frames: <String>['<red>A</red>', '<blue>B</blue>'],
        )
      : null;
}

void main() {
  test('rainbow wraps resolved entity tokens without exposing markup', () {
    final GlossEntityOverlaysDoc doc = GlossEntityOverlaysDoc()
      ..lines = <GlossEntityOverlayLine>[
        GlossEntityOverlayLine(
          id: 'stats',
          text:
              '<particles:highlight><rainbow>ATK {attack} / ARM {armor}</rainbow></particles>',
        ),
      ];
    final EntityOverlayPreview preview = resolveEntityOverlayPreview(
      doc,
      const EntityOverlaySample(),
    );
    expect(preview.errors, isEmpty);
    expect(preview.lines.single, startsWith('ATK '));
    expect(preview.lines.single, isNot(contains('<rainbow>')));
    expect(preview.rows.single.particleSpans.single.name, 'highlight');
  });

  test('defaults match the shipped runtime document and schema', () {
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

  test('ordered rows, full styles, decorations and particles round trip', () {
    final GlossEntityOverlaysDoc doc = GlossEntityOverlaysDoc(
      show: 'entity.health > 2',
      lines: <GlossEntityOverlayLine>[
        GlossEntityOverlayLine(
          id: 'custom',
          text: '<gradient:red:blue>{name}</gradient>',
        ),
        GlossEntityOverlayLine(id: 'space', type: 'spacer', show: false),
        GlossEntityOverlayLine(
          id: 'details',
          type: 'insight',
          text: '&b{insight}',
        ),
      ],
      style: HuiIconStyle(
        billboard: 'vertical',
        shadow: true,
        seeThrough: true,
        textAlignment: 'left',
        backgroundArgb: '#AA102030',
        textOpacity: 180,
        lineWidth: 120,
        blockLight: 12,
        skyLight: 13,
        viewRange: 2,
        shadowRadius: 1,
        shadowStrength: 0.5,
        cullingWidth: 6,
        cullingHeight: 8,
        glowColor: '#FF112233',
        scaleX: 0.6,
        scaleY: 0.8,
        scaleZ: 1,
      ),
      box: GlossHologramBox(enabled: true, padding: 7, borderWidth: 2),
      particleLayers: <GlossParticleLayer>[GlossParticleLayer(id: 'edge')],
    );
    expect(
      decodeGlossEntityOverlaysDoc(encodeGlossEntityOverlaysDoc(doc)).toJson(),
      doc.toJson(),
    );
    expect(validateEntityOverlaysDoc(doc), isEmpty);
  });

  test('explicit empty lists and false show survive import', () {
    final GlossEntityOverlaysDoc doc = GlossEntityOverlaysDoc(
      show: false,
      lines: <GlossEntityOverlayLine>[],
      excludedEntityTypes: <String>[],
      extras: <String, Object?>{'custom': 42},
    );
    final GlossEntityOverlaysDoc decoded = decodeGlossEntityOverlaysDoc(
      encodeGlossEntityOverlaysDoc(doc),
    );
    expect(decoded.toJson(), doc.toJson());
    expect(decoded.lines, isEmpty);
    expect(
      resolveEntityOverlayPreview(decoded, const EntityOverlaySample()).visible,
      isFalse,
    );
  });

  test(
    'explicit empty style uses native defaults and omitted style uses pane defaults',
    () {
      expect(
        GlossEntityOverlaysDoc.fromJson(<String, Object?>{
          'schemaVersion': 2,
        }).style.scaleX,
        0.75,
      );
      final GlossEntityOverlaysDoc explicit = GlossEntityOverlaysDoc.fromJson(
        <String, Object?>{'schemaVersion': 2, 'style': <String, Object?>{}},
      );
      expect(explicit.style.scaleX, 1);
      expect(explicit.style.billboard, 'fixed');
    },
  );

  test('current document type errors are rejected', () {
    for (final Map<String, Object?> invalid in <Map<String, Object?>>[
      <String, Object?>{'schemaVersion': 3},
      <String, Object?>{'schemaVersion': 2, 'lines': 'invalid'},
      <String, Object?>{'schemaVersion': 2, 'show': 2},
      <String, Object?>{
        'schemaVersion': 2,
        'blacklistWorlds': <Object>['world', false],
      },
      <String, Object?>{
        'schemaVersion': 2,
        'lines': <Object>[42],
      },
    ]) {
      expect(
        () => GlossEntityOverlaysDoc.fromJson(invalid),
        throwsA(isA<HuiFormatException>()),
      );
    }
  });

  test(
    'validation checks line ids, kinds, text limits, conditions, styles and boxes',
    () {
      final GlossEntityOverlaysDoc doc = GlossEntityOverlaysDoc(
        show: 'entity.health >',
        lines: <GlossEntityOverlayLine>[
          GlossEntityOverlayLine(id: 'same'),
          GlossEntityOverlayLine(id: 'same'),
          GlossEntityOverlayLine(
            id: 'Bad id',
            type: 'bad',
            text: 'x' * 4097,
            show: '&&',
          ),
        ],
        style: HuiIconStyle(textOpacity: 256, backgroundArgb: 'red'),
        box: GlossHologramBox(padding: 65, borderWidth: 17, borderArgb: 'blue'),
      );
      final List<String> paths = validateEntityOverlaysDoc(
        doc,
      ).map((HuiIssue issue) => issue.path).toList();
      expect(
        paths,
        containsAll(<String>[
          r'$.show',
          r'$.lines[1].id',
          r'$.lines[2].id',
          r'$.lines[2].type',
          r'$.lines[2].text',
          r'$.lines[2].show',
          r'$.style.textOpacity',
          r'$.style.backgroundArgb',
          r'$.box.padding',
          r'$.box.borderWidth',
          r'$.box.borderArgb',
        ]),
      );
    },
  );

  test(
    'defaults render segmented health with independent React row and Insight detail rows',
    () {
      final EntityOverlayPreview plain = resolveEntityOverlayPreview(
        GlossEntityOverlaysDoc(),
        const EntityOverlaySample(),
      );
      expect(plain.lines, <String>[
        'Sample sentinel',
        '|||||||||| 14/20',
        'ATK 3 | ARM 2',
      ]);
      final EntityOverlayPreview integrated = resolveEntityOverlayPreview(
        GlossEntityOverlaysDoc(),
        const EntityOverlaySample(react: true, adapt: true, insight: true),
      );
      expect(integrated.lines[2], 'x4');
      expect(integrated.lines[3], 'Zombie');
      expect(integrated.lines.last, 'ATK 3 | ARM 2');
      expect(integrated.lines, hasLength(7));
    },
  );

  test(
    'row order, custom rich text and spacer placement determine visible output',
    () {
      final GlossEntityOverlaysDoc doc = GlossEntityOverlaysDoc(
        lines: <GlossEntityOverlayLine>[
          GlossEntityOverlayLine(id: 'stats', text: '&7ARM {armor}'),
          GlossEntityOverlayLine(id: 'space', type: 'spacer'),
          GlossEntityOverlayLine(
            id: 'custom',
            text: '<bold><red>{name}</red></bold>',
          ),
        ],
      );
      final EntityOverlayPreview preview = resolveEntityOverlayPreview(
        doc,
        const EntityOverlaySample(),
      );
      expect(preview.lines, <String>['ARM 2', ' ', 'Sample sentinel']);
      final McSpan name = (preview.rows[2].pieces.first as GlossTextRun).span;
      expect(name.bold, isTrue);
      expect(name.color, 0xFF5555);
    },
  );

  test('damage rows expire while lost segments return to empty color', () {
    final GlossEntityOverlaysDoc doc = GlossEntityOverlaysDoc();
    final EntityOverlayPreview hit = resolveEntityOverlayPreview(
      doc,
      const EntityOverlaySample(health: 11, damage: 3, sinceHitMs: 749),
    );
    expect(hit.lines, contains('-3'));
    expect(
      hit.rows[1].pieces
          .whereType<GlossTextRun>()
          .where((GlossTextRun run) => run.span.color == 0xFF5555)
          .map((GlossTextRun run) => run.span.text)
          .join(),
      '|',
    );
    final EntityOverlayPreview expired = resolveEntityOverlayPreview(
      doc,
      const EntityOverlaySample(health: 11, damage: 3, sinceHitMs: 750),
    );
    expect(expired.lines, isNot(contains('-3')));
  });

  test('pane and row conditions see typed entity state and sample time', () {
    final GlossEntityOverlaysDoc doc = GlossEntityOverlaysDoc(
      show: 'entity.healthPercent > 50',
      lines: <GlossEntityOverlayLine>[
        GlossEntityOverlayLine(
          id: 'conditional',
          text: '{{ entity.health + entity.armor }}',
          show: 'entity.type == "zombie" && world.name == "world"',
        ),
        GlossEntityOverlayLine(
          id: 'time',
          text: '{{ time.seconds }}',
          show: 'time.seconds >= 2',
        ),
      ],
    );
    final EntityOverlayPreview preview = resolveEntityOverlayPreview(
      doc,
      const EntityOverlaySample(),
      nowMs: 2000,
    );
    expect(preview.lines, <String>['16', '2']);
    expect(preview.errors, isEmpty);
    expect(
      resolveEntityOverlayPreview(
        doc,
        const EntityOverlaySample(health: 1),
      ).visible,
      isFalse,
    );
  });

  test(
    'literal names, Insight values and expression results cannot execute markup or functions',
    () {
      const String hostile =
          '<red>{{ 2 + 2 }} |animation.flash| :heart: %player_name%</red>';
      final GlossEntityOverlaysDoc doc = GlossEntityOverlaysDoc(
        lines: <GlossEntityOverlayLine>[
          GlossEntityOverlayLine(id: 'name', text: '{name}'),
          GlossEntityOverlayLine(id: 'expression', text: '{{ entity.name }}'),
          GlossEntityOverlayLine(
            id: 'detail',
            type: 'insight',
            text: '{insight}',
          ),
        ],
      );
      final EntityOverlayPreview preview = resolveEntityOverlayPreview(
        doc,
        const EntityOverlaySample(
          name: hostile,
          adapt: true,
          insight: true,
          insightDetails: <String>[hostile],
        ),
      );
      expect(preview.lines, <String>[hostile, hostile, hostile]);
      expect(
        preview.rows.every((GlossLineRender row) => row.usedAnimations.isEmpty),
        isTrue,
      );
      expect(
        preview.rows.every((GlossLineRender row) => row.placeholders.isEmpty),
        isTrue,
      );
    },
  );

  test(
    'author gradients and named particle spans render through the shared engine',
    () {
      final EntityOverlayPreview preview = resolveEntityOverlayPreview(
        GlossEntityOverlaysDoc(
          lines: <GlossEntityOverlayLine>[
            GlossEntityOverlayLine(
              id: 'color',
              text:
                  '<particles:health><gradient:red:blue>Health</gradient></particles>',
            ),
          ],
        ),
        const EntityOverlaySample(),
      );
      expect(preview.lines, <String>['Health']);
      expect(
        preview.rows.single.pieces
            .whereType<GlossTextRun>()
            .map((GlossTextRun run) => run.span.color)
            .toSet()
            .length,
        greaterThan(1),
      );
      expect(preview.particleText.spans.single.name, 'health');
      expect(preview.particleText.spans.single.start, 0);
      expect(preview.particleText.spans.single.end, 6);
    },
  );

  test(
    'Insight keeps its acquisition range and exclusive mode suppresses unrelated entities',
    () {
      final GlossEntityOverlaysDoc doc = GlossEntityOverlaysDoc(range: 2);
      expect(
        resolveEntityOverlayPreview(
          doc,
          const EntityOverlaySample(distance: 8),
        ).visible,
        isFalse,
      );
      expect(
        resolveEntityOverlayPreview(
          doc,
          const EntityOverlaySample(distance: 8, adapt: true, insight: true),
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
      expect(
        resolveEntityOverlayPreview(
          doc,
          const EntityOverlaySample(
            adapt: true,
            adaptExclusive: true,
            insight: true,
          ),
        ).visible,
        isTrue,
      );
    },
  );

  test(
    'excluded targets, players, worlds, dead entities and empty layouts remain hidden',
    () {
      final GlossEntityOverlaysDoc doc = GlossEntityOverlaysDoc(
        includePlayers: false,
        blacklistWorlds: <String>['excluded'],
      );
      for (final EntityOverlaySample sample in <EntityOverlaySample>[
        const EntityOverlaySample(player: true),
        const EntityOverlaySample(world: 'excluded'),
        const EntityOverlaySample(entityType: 'ARMOR_STAND'),
        const EntityOverlaySample(health: 0),
      ]) {
        expect(resolveEntityOverlayPreview(doc, sample).visible, isFalse);
      }
      doc.lines.clear();
      expect(
        resolveEntityOverlayPreview(doc, const EntityOverlaySample()).visible,
        isFalse,
      );
    },
  );
  test('gradients cover literal names without interpreting their markup', () {
    final EntityOverlayPreview preview = resolveEntityOverlayPreview(
      GlossEntityOverlaysDoc(
        lines: <GlossEntityOverlayLine>[
          GlossEntityOverlayLine(
            id: 'name',
            text: '<gradient:red:blue>{name}</gradient>',
          ),
        ],
      ),
      const EntityOverlaySample(name: 'Sentinel'),
    );
    expect(preview.lines, <String>['Sentinel']);
    expect(
      preview.rows.single.pieces
          .whereType<GlossTextRun>()
          .map((GlossTextRun run) => run.span.color)
          .toSet()
          .length,
      greaterThan(1),
    );
  });

  test(
    'blank rows stay between content and empty Insight details are inactive',
    () {
      final EntityOverlayPreview preview = resolveEntityOverlayPreview(
        GlossEntityOverlaysDoc(
          lines: <GlossEntityOverlayLine>[
            GlossEntityOverlayLine(id: 'name', text: '{type} {distance}'),
            GlossEntityOverlayLine(id: 'blank', text: ''),
            GlossEntityOverlayLine(id: 'tail', text: 'Tail'),
            GlossEntityOverlayLine(
              id: 'insight',
              text: 'Insight',
              show: 'insight.active',
            ),
          ],
        ),
        const EntityOverlaySample(
          adapt: true,
          insight: true,
          insightDetails: <String>[],
        ),
      );
      expect(preview.lines, <String>['zombie 6', '', 'Tail']);
      expect(preview.particleText.text, 'zombie 6\n\nTail');
    },
  );

  test(
    'animation frames advance inside authored formatting and particle spans',
    () {
      final GlossEntityOverlaysDoc doc = GlossEntityOverlaysDoc(
        lines: <GlossEntityOverlayLine>[
          GlossEntityOverlayLine(
            id: 'animation',
            text: '<particles:pulse><bold>|animation.pulse|</bold></particles>',
          ),
        ],
      );
      final EntityOverlayPreview first = resolveEntityOverlayPreview(
        doc,
        const EntityOverlaySample(),
        animations: _OverlayAnimations(),
      );
      final EntityOverlayPreview second = resolveEntityOverlayPreview(
        doc,
        const EntityOverlaySample(),
        animations: _OverlayAnimations(),
        nowMs: 100,
      );
      expect(first.lines, <String>['A']);
      expect(second.lines, <String>['B']);
      expect(
        (second.rows.single.pieces.single as GlossTextRun).span.bold,
        isTrue,
      );
      expect(
        (second.rows.single.pieces.single as GlossTextRun).span.color,
        0x5555FF,
      );
      expect(second.particleText.spans.single.name, 'pulse');
    },
  );

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

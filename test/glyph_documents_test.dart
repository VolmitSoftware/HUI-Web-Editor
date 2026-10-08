import 'dart:convert';

import 'package:gloss_editor/config/gloss_json_schema.dart';
import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/logic/glyph_validation.dart';
import 'package:gloss_editor/logic/json_schema.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:test/test.dart';

void main() {
  test('glyphs preserve all typed assets and nested extension fields', () {
    final GlossGlyphDoc doc = GlossGlyphDoc(
      namespace: 'trails',
      font: 'icons',
      revision: 17,
      glyphs: <GlossGlyph>[
        GlossGlyph(
          id: 'coin',
          image: 'icons/coin.png',
          height: 16,
          ascent: -1,
          width: 12,
          frames: 4,
          emoji: 'coin',
          fallback: 'C',
          extras: <String, Object?>{'detail': false},
        ),
      ],
      overlays: <GlossGlyphOverlay>[
        GlossGlyphOverlay(
          id: 'frame',
          image: 'hud/frame.png',
          anchor: 'bottom',
          extras: <String, Object?>{'detail': 3},
        ),
      ],
      space: GlossGlyphSpace(
        range: <int>[-16, 32],
        extras: <String, Object?>{'detail': 'space'},
      ),
      waypointStyles: <GlossWaypointStyleAsset>[
        GlossWaypointStyleAsset(
          id: 'quest',
          nearDistance: 4,
          farDistance: 80,
          sprites: <GlossWaypointSprite>[
            GlossWaypointSprite(
              id: 'near',
              image: 'waypoints/near.png',
              extras: <String, Object?>{
                'detail': <String>['sprite'],
              },
            ),
          ],
          extras: <String, Object?>{'detail': 'style'},
        ),
      ],
      extras: <String, Object?>{
        'detail': <String, Object?>{'enabled': true},
      },
    );
    final GlossGlyphDoc copy = decodeGlossGlyphDoc(encodeGlossGlyphDoc(doc));
    expect(copy.toJson(), doc.toJson());
    expect(validateGlyphDoc(copy), isEmpty);
    expect(
      DocumentTypeRegistry.detectTransferable(copy.toJson()),
      DocumentTypes.glyph,
    );
    expect(DocumentTypeRegistry.byWireKind('glyph'), DocumentTypes.glyph);
    expect(DocumentTypes.glyph.hasRuntimePreview, isFalse);
    final Map<String, Object?> exported = copy.toJson();
    (exported['detail']! as Map<String, Object?>)['enabled'] = false;
    expect((copy.extras['detail']! as Map<String, Object?>)['enabled'], isTrue);
  });

  test(
    'omitted glyph properties use server defaults and schema is checked',
    () {
      final GlossGlyphDoc doc = decodeGlossGlyphDoc(
        '''{"schemaVersion":1,"revision":1,
      "glyphs":[{"id":"coin","image":"coin.png","height":16}],
      "overlays":[{"id":"frame","image":"frame.png"}]}''',
      );
      expect(doc.namespace, 'gloss');
      expect(doc.font, 'glyphs');
      expect(doc.glyphs.single.ascent, 15);
      expect(doc.glyphs.single.width, isNull);
      expect(doc.overlays.single.anchor, 'center');
      expect(doc.space.range, <int>[-256, 256]);
      expect(doc.space.enabled, isTrue);
      expect(validateGlyphDoc(doc), isEmpty);
      expect(
        () =>
            decodeGlossGlyphDoc('{"schemaVersion":2,"revision":1,"glyphs":[]}'),
        throwsA(isA<HuiFormatException>()),
      );
    },
  );

  test('invalid paths, collisions, dimensions and ranges stay editable', () {
    final GlossGlyphDoc doc = GlossGlyphDoc(
      namespace: 'bad/name',
      glyphs: <GlossGlyph>[
        GlossGlyph(
          id: 'same',
          image: '../bad.png',
          height: 257,
          ascent: 258,
          width: -1,
          frames: 0,
        ),
      ],
      overlays: <GlossGlyphOverlay>[
        GlossGlyphOverlay(id: 'same', image: '/root.png', anchor: 'left'),
      ],
      space: GlossGlyphSpace(range: <int>[]),
      waypointStyles: <GlossWaypointStyleAsset>[
        GlossWaypointStyleAsset(id: 'quest', nearDistance: 3, farDistance: 2),
        GlossWaypointStyleAsset(
          id: 'quest',
          sprites: <GlossWaypointSprite>[
            GlossWaypointSprite(id: 'Bad!', image: 'bad.jpg'),
          ],
        ),
      ],
    );
    final GlossGlyphDoc copy = decodeGlossGlyphDoc(encodeGlossGlyphDoc(doc));
    copy.space.range = <int>[];
    final Iterable<String> paths = validateGlyphDoc(
      copy,
    ).map((HuiIssue issue) => issue.path);
    expect(
      paths,
      containsAll(<String>[
        r'$.namespace',
        r'$.glyphs[0].image',
        r'$.glyphs[0].height',
        r'$.glyphs[0].ascent',
        r'$.glyphs[0].width',
        r'$.glyphs[0].frames',
        r'$.overlays[0].id',
        r'$.overlays[0].image',
        r'$.overlays[0].anchor',
        r'$.space.range',
        r'$.waypointStyles[0].farDistance',
        r'$.waypointStyles[0].sprites',
        r'$.waypointStyles[1].id',
        r'$.waypointStyles[1].sprites[0].id',
        r'$.waypointStyles[1].sprites[0].image',
      ]),
    );
  });

  test('glyph assets edit, undo, redo and export through the shared store', () {
    final EditorStore store = EditorStore(
      workspace: Workspace(autoLoad: false),
    );
    addTearDown(store.dispose);
    store.newGlossDocument(DocumentTypes.glyph);
    expect(store.docKind, DocumentTypes.glyph.kind);
    store.mutateGloss(
      'add glyph',
      (GlossDoc doc) => (doc as GlossGlyphDoc).glyphs.add(
        GlossGlyph(id: 'coin', image: 'coin.png'),
      ),
    );
    expect((store.glossDoc as GlossGlyphDoc).glyphs.single.id, 'coin');
    expect(store.performUndo(), isTrue);
    expect((store.glossDoc as GlossGlyphDoc).glyphs, isEmpty);
    expect(store.performRedo(), isTrue);
    expect(
      (jsonDecode(store.exportJson()) as Map<String, Object?>)['glyphs'],
      hasLength(1),
    );
  });

  test('code completion resolves nested waypoint sprite and bitmap fields', () {
    final GlossJsonObject schema = glossJsonSchemaFor('glyph')!;
    final GlossJsonArray styles =
        schema.field('waypointStyles')!.node! as GlossJsonArray;
    final GlossJsonObject style = styles.item! as GlossJsonObject;
    final GlossJsonArray sprites =
        style.field('sprites')!.node! as GlossJsonArray;
    expect(
      (sprites.item! as GlossJsonObject).field('image')!.type,
      GlossJsonType.string,
    );
    final GlossJsonArray glyphs =
        schema.field('glyphs')!.node! as GlossJsonArray;
    expect(
      (glyphs.item! as GlossJsonObject).field('frames')!.type,
      GlossJsonType.integer,
    );
  });
}

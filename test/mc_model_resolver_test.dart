/// Parent chains, texture variables and item dispatch, on real jar JSON.
library;

import 'dart:convert';
import 'dart:io';

import 'package:gloss_editor/mc/assets/mc_model_json.dart';
import 'package:gloss_editor/mc/assets/mc_model_resolver.dart';
import 'package:gloss_editor/mc/assets/mc_model_store.dart';
import 'package:test/test.dart';

const String _root = 'test/fixtures/mc/assets/minecraft';

/// A store over the fixture folder, in the exact shape `models.json` packs.
McJsonModelStore _fixtureStore() {
  Map<String, Object?> folder(String sub, String prefix) {
    final Directory directory = Directory('$_root/$sub');
    return <String, Object?>{
      for (final File file
          in directory.listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.json'))
          '$prefix${file.path.substring(directory.path.length + 1, file.path.length - 5)}':
              jsonDecode(file.readAsStringSync()),
    };
  }

  return McJsonModelStore.fromJson(<String, Object?>{
    'models': <String, Object?>{
      ...folder('models/block', 'block/'),
      ...folder('models/item', 'item/'),
    },
    'items': folder('items', ''),
    'blockstates': folder('blockstates', ''),
  });
}

void main() {
  final McJsonModelStore store = _fixtureStore();
  final McModelResolver resolver = McModelResolver(store);

  test('the store counts its sections and caches parses', () {
    expect(store.modelCount, 29);
    expect(store.itemCount, 9);
    expect(store.blockstateCount, 7);
    expect(store.itemIds, contains('diamond_sword'));
    expect(store.model('block/stone'), same(store.model('block/stone')));
    expect(store.model('block/no_such_model'), isNull);
    expect(store.item('no_such_item'), isNull);
    expect(store.blockstate('no_such_block'), isNull);
  });

  test('stone resolves cube_all through cube to six textured faces', () {
    final McResolvedModel model = resolver.resolveModel('block/stone')!;
    expect(model.elements, hasLength(1));
    final McResolvedElement cube = model.elements.single;
    expect(cube.faces, hasLength(6));
    for (final McResolvedFace face in cube.faces.values) {
      expect(face.texture, 'block/stone');
    }
    expect(cube.faces['north']!.uv, <double>[0, 0, 16, 16]);
    expect(cube.faces['north']!.cullface, 'north');
    expect(model.display['fixed']!.scale, <double>[0.5, 0.5, 0.5]);
    expect(model.guiLight, 'side');
    expect(model.generated, isFalse);
    expect(model.entityBuiltin, isFalse);
    expect(resolver.resolveModel('minecraft:block/stone'), same(model));
  });

  test('grass_block substitutes every texture variable and keeps tints', () {
    final McResolvedModel model = resolver.resolveModel('block/grass_block')!;
    final McResolvedElement cube = model.elements.first;
    expect(cube.faces['up']!.texture, 'block/grass_block_top');
    expect(cube.faces['up']!.tintIndex, 0);
    expect(cube.faces['down']!.texture, 'block/dirt');
    expect(cube.faces['down']!.tintIndex, isNull);
    expect(cube.faces['north']!.texture, 'block/grass_block_side');
    expect(
      model.elements[1].faces['north']!.texture,
      'block/grass_block_side_overlay',
    );
    expect(model.aabb.min, <double>[0, 0, 0]);
    expect(model.aabb.max, <double>[1, 1, 1]);
  });

  test('a face texture names its slot with or without the hash', () {
    // `block/heavy_core.json` in the 26.2 jar writes `"texture": "all"`; the
    // client (`BlockModel.getMaterial`) strips an optional `#` and looks the
    // slot up either way, and an unknown slot is the missing texture.
    final McJsonModelStore bare = McJsonModelStore.fromJson(<String, Object?>{
      'models': <String, Object?>{
        'block/core': <String, Object?>{
          'textures': <String, Object?>{'all': 'block/heavy_core'},
          'elements': <Object?>[
            <String, Object?>{
              'from': <Object?>[4, 0, 4],
              'to': <Object?>[12, 8, 12],
              'faces': <String, Object?>{
                'up': <String, Object?>{'texture': 'all'},
                'north': <String, Object?>{'texture': '#all'},
                'down': <String, Object?>{'texture': 'nope'},
              },
            },
          ],
        },
      },
    });
    final McResolvedModel model = McModelResolver(bare).resolveModel('block/core')!;
    final Map<String, McResolvedFace> faces = model.elements.single.faces;
    expect(faces['up']!.texture, 'block/heavy_core');
    expect(faces['north']!.texture, 'block/heavy_core');
    expect(faces['down']!.texture, mcMissingTexture);
    expect(mcUsesItemAtlas(model), isFalse);
  });

  test('the atlas rule is generated or all-item faces', () {
    expect(mcUsesItemAtlas(resolver.resolveModel('block/stone')!), isFalse);
    final McItemModelResult sword = resolver.resolveItem('diamond_sword');
    expect(sword, isA<McItemModelResolved>());
    expect(mcUsesItemAtlas((sword as McItemModelResolved).model), isTrue);
  });

  test('a slab resolves half-height bounds', () {
    final McResolvedModel model = resolver.resolveModel('block/oak_slab')!;
    expect(model.aabb.max[1], 0.5);
    expect(model.aabb.height, 0.5);
    expect(model.elements.single.faces['up']!.texture, 'block/oak_planks');
  });

  test('a fence post defaults the UVs of faces that omit them', () {
    final McResolvedModel model = resolver.resolveModel('block/fence_post')!;
    final McResolvedElement post = model.elements.single;
    expect(post.faces['up']!.uv, <double>[6, 6, 10, 10]);
    expect(model.aabb.min, <double>[6 / 16, 0, 6 / 16]);
    expect(model.aabb.max, <double>[10 / 16, 1, 10 / 16]);
    // cube.json omits every uv: the element bounds fill them in.
    final McResolvedElement cube = resolver
        .resolveModel('block/cube_column')!
        .elements
        .single;
    expect(cube.faces['down']!.uv, <double>[0, 0, 16, 16]);
    expect(cube.faces['west']!.uv, <double>[0, 0, 16, 16]);
  });

  test('handheld items are generated with layer0', () {
    final McResolvedModel model = resolver.resolveModel('item/diamond_sword')!;
    expect(model.generated, isTrue);
    expect(model.layers, <String>['item/diamond_sword']);
    expect(model.elements, isEmpty);
    expect(model.display['fixed']!.rotation, <double>[0, 180, 0]);
    expect(model.display['thirdperson_righthand']!.rotation, <double>[
      0,
      -90,
      55,
    ]);
    expect(model.guiLight, 'front');
    expect(model.aabb.min, <double>[0, 0, 7.5 / 16]);
    expect(model.aabb.max, <double>[1, 1, 8.5 / 16]);
  });

  test('missing models and unresolved variables are reported, not thrown', () {
    expect(resolver.resolveModel('block/no_such_model'), isNull);
    // oak_fence_side inherits fence_side, which is in the store; its parent
    // chain is complete, but a child pointing at a missing parent is null.
    expect(resolver.resolveModel('item/bow_pulling_0'), isNotNull);
    final McModelResolver dangling = McModelResolver(
      McJsonModelStore.fromJson(<String, Object?>{
        'models': <String, Object?>{
          'block/orphan': <String, Object?>{'parent': 'block/gone'},
          'block/loose': <String, Object?>{
            'elements': <Object?>[
              <String, Object?>{
                'from': <Object?>[0, 0, 0],
                'to': <Object?>[16, 16, 16],
                'faces': <String, Object?>{
                  'up': <String, Object?>{'texture': '#nowhere'},
                },
              },
            ],
          },
        },
      }),
    );
    expect(dangling.resolveModel('block/orphan'), isNull);
    expect(
      dangling
          .resolveModel('block/loose')!
          .elements
          .single
          .faces['up']!
          .texture,
      mcMissingTexture,
    );
  });

  test('builtin/entity models carry no geometry and fall back to a sprite', () {
    final McModelResolver entity = McModelResolver(
      McJsonModelStore.fromJson(<String, Object?>{
        'models': <String, Object?>{
          'item/template_shulker_box': <String, Object?>{
            'parent': 'minecraft:builtin/entity',
          },
          'item/shulker_box': <String, Object?>{
            'parent': 'item/template_shulker_box',
          },
        },
        'items': <String, Object?>{
          'shulker_box': <String, Object?>{
            'model': <String, Object?>{
              'type': 'minecraft:model',
              'model': 'minecraft:item/shulker_box',
            },
          },
        },
      }),
    );
    final McResolvedModel model = entity.resolveModel('item/shulker_box')!;
    expect(model.entityBuiltin, isTrue);
    expect(model.generated, isFalse);
    expect(model.elements, isEmpty);
    expect(model.aabb.max, <double>[1, 1, 1]);
    final McItemModelResult result = entity.resolveItem('shulker_box');
    expect((result as McItemModelSprite).reason, contains(mcBuiltinEntity));
  });

  test('item definitions dispatch to the resting model', () {
    final McItemModelResult sword = resolver.resolveItem('diamond_sword');
    expect(sword, isA<McItemModelResolved>());
    expect((sword as McItemModelResolved).model.id, 'item/diamond_sword');
    expect(sword.tints, isEmpty);

    final McItemModelResult bow = resolver.resolveItem('bow');
    expect(bow, isA<McItemModelResolved>());
    expect((bow as McItemModelResolved).model.id, 'item/bow');

    final McItemModelResult grass = resolver.resolveItem('GRASS_BLOCK');
    expect((grass as McItemModelResolved).model.id, 'block/grass_block');
    expect(grass.tints.single.type, 'grass');

    final McItemModelResult slab = resolver.resolveItem('minecraft:oak_slab');
    expect((slab as McItemModelResolved).model.id, 'block/oak_slab');

    final McItemModelResult chest = resolver.resolveItem('chest');
    expect(chest, isA<McItemModelSprite>());
    expect((chest as McItemModelSprite).reason, contains('special'));

    // compass: condition -> range_dispatch without fallback -> first entry,
    // whose model is not in the fixture store.
    final McItemModelResult compass = resolver.resolveItem('compass');
    expect(compass, isA<McItemModelSprite>());
    expect((compass as McItemModelSprite).reason, contains('item/compass_16'));

    expect(resolver.resolveItem('no_such_item'), isA<McItemModelSprite>());
  });

  test('composites merge every resolvable child under the first id', () {
    final McModelResolver composite = McModelResolver(
      McJsonModelStore.fromJson(<String, Object?>{
        'models': <String, Object?>{
          'block/a': <String, Object?>{
            'elements': <Object?>[
              <String, Object?>{
                'from': <Object?>[0, 0, 0],
                'to': <Object?>[16, 8, 16],
                'faces': <String, Object?>{
                  'up': <String, Object?>{'texture': 'block/stone'},
                },
              },
            ],
          },
          'block/b': <String, Object?>{
            'elements': <Object?>[
              <String, Object?>{
                'from': <Object?>[0, 8, 0],
                'to': <Object?>[16, 16, 16],
                'faces': <String, Object?>{
                  'up': <String, Object?>{'texture': 'block/dirt'},
                },
              },
            ],
          },
        },
        'items': <String, Object?>{
          'stack': <String, Object?>{
            'model': <String, Object?>{
              'type': 'minecraft:composite',
              'models': <Object?>[
                <String, Object?>{
                  'type': 'minecraft:model',
                  'model': 'block/a',
                },
                <String, Object?>{'type': 'minecraft:bundle/selected_item'},
                <String, Object?>{
                  'type': 'minecraft:model',
                  'model': 'block/b',
                  'tints': <Object?>[
                    <String, Object?>{'type': 'minecraft:constant', 'value': 7},
                  ],
                },
              ],
            },
          },
          'hollow': <String, Object?>{
            'model': <String, Object?>{
              'type': 'minecraft:composite',
              'models': <Object?>[
                <String, Object?>{'type': 'minecraft:empty'},
              ],
            },
          },
        },
      }),
    );
    final McItemModelResolved stack =
        composite.resolveItem('stack') as McItemModelResolved;
    expect(stack.model.id, 'block/a');
    expect(stack.model.elements, hasLength(2));
    expect(stack.model.aabb.max[1], 1);
    expect(stack.tints.single.defaultArgb, 7);
    expect(composite.resolveItem('hollow'), isA<McItemModelSprite>());
  });

  test('blocks resolve their default variant with its rotation', () {
    final McResolvedModel log = resolver.resolveBlock('oak_log')!;
    expect(log.id, 'block/oak_log');
    expect(log.elements.single.faces['up']!.texture, 'block/oak_log_top');
    expect(log.elements.single.faces['north']!.texture, 'block/oak_log');
    expect(resolver.blockVariant('oak_log')!.rotated, isFalse);
    final McResolvedModel fence = resolver.resolveBlock('oak_fence')!;
    expect(fence.id, 'block/oak_fence_post');
    expect(fence.elements.single.faces['up']!.texture, 'block/oak_planks');
    final McBlockstateVariantJson stone = resolver.blockVariant('STONE')!;
    expect(stone.model, 'block/stone');
    expect(resolver.resolveBlock('no_such_block'), isNull);
    expect(resolver.blockVariant('no_such_block'), isNull);
  });

  test('a rotated cross keeps its rotation on the resolved element', () {
    final McResolvedModel model = resolver.resolveModel('block/short_grass')!;
    expect(model.elements, hasLength(2));
    expect(model.elements.first.rotation!.angle, 45);
    expect(model.elements.first.rotation!.rescale, isTrue);
    expect(model.elements.first.shade, isFalse);
    expect(model.elements.first.faces['north']!.tintIndex, 0);
    expect(model.elements.first.faces['north']!.texture, 'block/short_grass');
    expect(model.textures['particle'], '#cross');
    expect(model.aabb.min, <double>[0.8 / 16, 0, 0.8 / 16]);
  });
}

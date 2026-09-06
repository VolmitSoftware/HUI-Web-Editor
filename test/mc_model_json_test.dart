/// The client's model JSON, parsed into the shapes the resolver walks.
library;

import 'dart:convert';
import 'dart:io';

import 'package:gloss_editor/mc/assets/mc_model_json.dart';
import 'package:test/test.dart';

Map<String, Object?> _json(String path) =>
    jsonDecode(
          File('test/fixtures/mc/assets/minecraft/$path').readAsStringSync(),
        )
        as Map<String, Object?>;

void main() {
  test('grass_block parses its elements, faces and texture map', () {
    final McModelJson model = McModelJson.fromJson(
      _json('models/block/grass_block.json'),
    );
    expect(model.parent, 'block/block');
    expect(model.textures['top'], 'block/grass_block_top');
    expect(model.elements, hasLength(2));
    final McElementJson cube = model.elements.first;
    expect(cube.from, <double>[0, 0, 0]);
    expect(cube.to, <double>[16, 16, 16]);
    expect(cube.faces['up']!.texture, '#top');
    expect(cube.faces['up']!.tintIndex, 0);
    expect(cube.faces['up']!.cullface, 'up');
    expect(cube.faces['north']!.uv, <double>[0, 0, 16, 16]);
  });

  test('block/block carries display transforms and no elements', () {
    final McModelJson model = McModelJson.fromJson(
      _json('models/block/block.json'),
    );
    expect(model.parent, isNull);
    expect(model.elements, isEmpty);
    expect(model.declaresElements, isFalse);
    expect(model.guiLight, 'side');
    expect(model.display['fixed']!.scale, <double>[0.5, 0.5, 0.5]);
    expect(model.display['gui']!.rotation, <double>[30, 225, 0]);
  });

  test('a rotated element keeps origin, axis, angle and rescale', () {
    final McModelJson model = McModelJson.fromJson(
      _json('models/block/cross.json'),
    );
    final McRotationJson rotation = model.elements.first.rotation!;
    expect(rotation.axis, 'y');
    expect(rotation.angle, 45);
    expect(rotation.rescale, isTrue);
    expect(rotation.origin, <double>[8, 8, 8]);
    expect(model.elements.first.shade, isFalse);
  });

  test('item definitions parse model, condition and select dispatch', () {
    final McItemDefinitionNode sword = McItemDefinitionNode.fromJson(
      _json('items/diamond_sword.json')['model']! as Map<String, Object?>,
    );
    expect(sword, isA<McItemModelNode>());
    expect((sword as McItemModelNode).model, 'item/diamond_sword');

    final McItemDefinitionNode bow = McItemDefinitionNode.fromJson(
      _json('items/bow.json')['model']! as Map<String, Object?>,
    );
    expect(bow, isA<McItemConditionNode>());
    expect((bow as McItemConditionNode).property, 'using_item');
    expect(bow.onFalse, isA<McItemModelNode>());
    expect((bow.onFalse as McItemModelNode).model, 'item/bow');
    expect(bow.onTrue, isA<McItemRangeDispatchNode>());
    final McItemRangeDispatchNode pulling =
        bow.onTrue as McItemRangeDispatchNode;
    expect(pulling.entries, hasLength(2));
    expect((pulling.fallback! as McItemModelNode).model, 'item/bow_pulling_0');

    final McItemDefinitionNode grass = McItemDefinitionNode.fromJson(
      _json('items/grass_block.json')['model']! as Map<String, Object?>,
    );
    expect((grass as McItemModelNode).tints.single.type, 'grass');

    final McItemDefinitionNode leaves = McItemDefinitionNode.fromJson(
      _json('items/oak_leaves.json')['model']! as Map<String, Object?>,
    );
    final McTintJson constant = (leaves as McItemModelNode).tints.single;
    expect(constant.type, 'constant');
    expect(constant.defaultArgb, -12012264);

    // The jar wraps the chest special renderer in a date select; the resting
    // branch is the fallback.
    final McItemDefinitionNode chest = McItemDefinitionNode.fromJson(
      _json('items/chest.json')['model']! as Map<String, Object?>,
    );
    expect(chest, isA<McItemSelectNode>());
    final McItemDefinitionNode fallback = (chest as McItemSelectNode).fallback!;
    expect(fallback, isA<McItemSpecialNode>());
    expect((fallback as McItemSpecialNode).specialType, 'chest');
    expect(fallback.base, 'item/chest');
    expect(chest.cases.single, isA<McItemSpecialNode>());

    final McItemDefinitionNode bundle = McItemDefinitionNode.fromJson(
      _json('items/bundle.json')['model']! as Map<String, Object?>,
    );
    final McItemConditionNode selected =
        (bundle as McItemSelectNode).cases.single as McItemConditionNode;
    final McItemCompositeNode open = selected.onTrue as McItemCompositeNode;
    expect(open.models, hasLength(3));
    expect(open.models[1], isA<McItemUnknownNode>());
    expect((open.models[1] as McItemUnknownNode).type, 'bundle/selected_item');
  });

  test('blockstates yield a default variant with rotation', () {
    final McBlockstateJson log = McBlockstateJson.fromJson(
      _json('blockstates/oak_log.json'),
    );
    final McBlockstateVariantJson variant = log.defaultVariant!;
    expect(variant.model, 'block/oak_log');
    expect(variant.x, 0);
    expect(variant.y, 0);
    final McBlockstateJson slab = McBlockstateJson.fromJson(
      _json('blockstates/oak_slab.json'),
    );
    expect(slab.defaultVariant!.model, 'block/oak_slab');
    final McBlockstateJson stone = McBlockstateJson.fromJson(
      _json('blockstates/stone.json'),
    );
    expect(stone.defaultVariant!.model, 'block/stone');
    expect(stone.defaultVariant!.y, 0);
    final McBlockstateJson fence = McBlockstateJson.fromJson(
      _json('blockstates/oak_fence.json'),
    );
    expect(fence.multipartUnconditional.single.model, 'block/oak_fence_post');
    expect(fence.defaultVariant!.model, 'block/oak_fence_post');
    expect(fence.multipartUnconditional.single.uvlock, isFalse);
  });
}

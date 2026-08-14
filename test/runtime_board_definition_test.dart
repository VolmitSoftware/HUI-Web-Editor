import 'package:holoui_editor/model/runtime_board_definition.dart';
import 'package:test/test.dart';

void main() {
  group('runtime board definition', () {
    test('round-trips every strict contract field', () {
      final Map<String, dynamic> source = _boardJson();
      final RuntimeBoardDefinition definition = RuntimeBoardDefinition.fromJson(
        source,
      );

      expect(definition.toJson(), source);
    });

    test('typed placement changes preserve server-owned identity', () {
      final RuntimeBoardDefinition source = RuntimeBoardDefinition.fromJson(
        _boardJson(),
      );
      final RuntimeBoardDefinition changed = source.copyWith(
        transform: source.transform.copyWith(
          x: 12.5,
          y: 80,
          yaw: 135,
          scale: 1.75,
        ),
      );
      final Map<String, dynamic> encoded = changed.toJson();

      expect(encoded['schemaVersion'], 1);
      expect(encoded['id'], 'welcome');
      expect(encoded['uuid'], '00000000-0000-4000-8000-000000000042');
      expect(encoded['revision'], 7);
      expect(encoded['rootMenuId'], 'welcome/root');
      expect(encoded['follow'], source.follow.toJson());
      expect(encoded['visibility'], source.visibility.toJson());
      expect(
        encoded['transform'],
        containsPair('worldUuid', '00000000-0000-4000-8000-000000000043'),
      );
      expect(encoded['transform'], containsPair('x', 12.5));
      expect(encoded['transform'], containsPair('y', 80.0));
      expect(encoded['transform'], containsPair('yaw', 135.0));
      expect(encoded['transform'], containsPair('scale', 1.75));
    });

    test(
      'typed follow and audience settings serialize exact runtime values',
      () {
        final RuntimeBoardDefinition source = RuntimeBoardDefinition.fromJson(
          _boardJson(),
        );
        final RuntimeBoardDefinition changed = source.copyWith(
          follow: const RuntimeBoardFollow(
            mode: RuntimeBoardFollowMode.player,
            targetPlayerUuid: '00000000-0000-4000-8000-000000000099',
            rotation: RuntimeBoardFollowRotation.yaw,
          ),
          visibility: const RuntimeBoardVisibility(
            mode: RuntimeBoardVisibilityMode.permission,
            viewPermission: 'holoui.board.welcome.view',
            interactPermission: 'holoui.board.welcome.use',
            viewRange: 48,
            interactionRange: 6,
          ),
        );

        expect(changed.toJson()['follow'], <String, dynamic>{
          'mode': 'player',
          'targetPlayerUuid': '00000000-0000-4000-8000-000000000099',
          'rotation': 'yaw',
        });
        expect(changed.toJson()['visibility'], <String, dynamic>{
          'mode': 'permission',
          'viewPermission': 'holoui.board.welcome.view',
          'interactPermission': 'holoui.board.welcome.use',
          'viewRange': 48.0,
          'interactionRange': 6.0,
        });
      },
    );

    test('rejects missing and unsupported contract fields', () {
      final Map<String, dynamic> missing = _boardJson()..remove('follow');
      final Map<String, dynamic> unsupported = _boardJson()
        ..['futureField'] = true;

      expect(
        () => RuntimeBoardDefinition.fromJson(missing),
        throwsFormatException,
      );
      expect(
        () => RuntimeBoardDefinition.fromJson(unsupported),
        throwsFormatException,
      );
    });

    test('rejects unknown typed modes before controls render', () {
      final Map<String, dynamic> source = _boardJson();
      (source['visibility']! as Map<String, dynamic>)['mode'] = 'nearby';

      expect(
        () => RuntimeBoardDefinition.fromJson(source),
        throwsFormatException,
      );
    });
  });
}

Map<String, dynamic> _boardJson() => <String, dynamic>{
  'schemaVersion': 1,
  'id': 'welcome',
  'uuid': '00000000-0000-4000-8000-000000000042',
  'revision': 7,
  'rootMenuId': 'welcome/root',
  'transform': <String, dynamic>{
    'worldKey': 'minecraft:overworld',
    'worldUuid': '00000000-0000-4000-8000-000000000043',
    'x': 0.0,
    'y': 64.0,
    'z': 0.0,
    'yaw': 0.0,
    'pitch': 0.0,
    'roll': 0.0,
    'scale': 1.0,
  },
  'follow': <String, dynamic>{
    'mode': 'none',
    'targetPlayerUuid': null,
    'rotation': 'fixed',
  },
  'visibility': <String, dynamic>{
    'mode': 'public',
    'viewPermission': null,
    'interactPermission': null,
    'viewRange': 64.0,
    'interactionRange': 8.0,
  },
};

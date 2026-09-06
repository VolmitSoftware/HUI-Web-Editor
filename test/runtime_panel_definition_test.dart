import 'package:gloss_editor/model/runtime_panel_definition.dart';
import 'package:test/test.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';

void main() {
  test(
    'world panel edits undo and redo without changing local flow metadata',
    () {
      final EditorStore store = EditorStore(
        workspace: Workspace(autoLoad: false),
      );
      addTearDown(store.dispose);
      store.newPanelDocument(name: 'Panel');
      final String active = store.workspace.active!.id;
      final Map<String, dynamic> original = _panelJson();
      expect(
        store.updatePanel(
          store.activePanel!.data.copyWith(
            runtimeBoardId: 'test-panel',
            runtimeBoard: original,
          ),
        ),
        isTrue,
      );
      expect(store.activePanel!.data.runtimeBoard, original);
      expect(store.performUndo(), isTrue);
      expect(store.activePanel!.data.runtimeBoard, isNull);
      expect(store.performRedo(), isTrue);
      expect(store.workspace.active!.id, active);
      expect(store.activePanel!.data.runtimeBoard, original);
      final RuntimePanelDefinition changed =
          RuntimePanelDefinition.fromJson(original).copyWith(
            show: false,
            transform: RuntimePanelDefinition.fromJson(original).transform
                .copyWith(
                  worldKey: 'minecraft:the_end',
                  worldUuid: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                ),
          );
      store.updatePanel(
        store.activePanel!.data.copyWith(runtimeBoard: changed.toJson()),
        coalesce: false,
      );
      expect(store.activePanel!.data.runtimeBoard!['show'], false);
      expect(store.performUndo(), isTrue);
      expect(store.activePanel!.data.runtimeBoard, original);
    },
  );

  test('duplicated linked panels receive independent runtime identities', () {
    final EditorStore store = EditorStore(
      workspace: Workspace(autoLoad: false),
    );
    addTearDown(store.dispose);
    store.newPanelDocument(name: 'Panel');
    final Map<String, dynamic> original = _panelJson();
    store.updatePanel(
      store.activePanel!.data.copyWith(
        runtimeBoardId: original['id'] as String,
        runtimeBoard: original,
      ),
    );
    final WorkspaceDoc? copy = store.duplicateDocument(
      store.workspace.active!.id,
    );
    expect(copy, isNotNull);
    final Map<String, dynamic> duplicated =
        store.activePanel!.data.runtimeBoard!;
    expect(duplicated['id'], isNot(original['id']));
    expect(duplicated['uuid'], isNot(original['uuid']));
    expect(duplicated['revision'], 1);
    expect(duplicated['transform'], original['transform']);
    expect(duplicated['rootMenuId'], original['rootMenuId']);
  });

  group('runtime panel definition', () {
    test('round-trips every strict contract field', () {
      final Map<String, dynamic> source = _panelJson();
      final RuntimePanelDefinition definition = RuntimePanelDefinition.fromJson(
        source,
      );

      expect(definition.toJson(), source);
    });

    test('show accepts canonical booleans and expressions through edits', () {
      for (final Object show in <Object>[false, 'world.time < 12000']) {
        final RuntimePanelDefinition source = RuntimePanelDefinition.fromJson(
          _panelJson()..['show'] = show,
        );
        expect(
          source.copyWith(rootMenuId: 'other/root').toJson()['show'],
          show,
        );
      }
      expect(
        RuntimePanelDefinition.fromJson(_panelJson()..remove('show')).show,
        true,
      );
      expect(
        () => RuntimePanelDefinition.fromJson(_panelJson()..['show'] = 2),
        throwsFormatException,
      );
    });

    test('typed placement changes preserve server-owned identity', () {
      final RuntimePanelDefinition source = RuntimePanelDefinition.fromJson(
        _panelJson(),
      );
      final RuntimePanelDefinition changed = source.copyWith(
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
        final RuntimePanelDefinition source = RuntimePanelDefinition.fromJson(
          _panelJson(),
        );
        final RuntimePanelDefinition changed = source.copyWith(
          follow: const RuntimePanelFollow(
            mode: RuntimePanelFollowMode.player,
            targetPlayerUuid: '00000000-0000-4000-8000-000000000099',
            rotation: RuntimePanelFollowRotation.yaw,
          ),
          visibility: const RuntimePanelVisibility(
            mode: RuntimePanelVisibilityMode.permission,
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
      final Map<String, dynamic> missing = _panelJson()..remove('follow');
      final Map<String, dynamic> unsupported = _panelJson()
        ..['futureField'] = true;

      expect(
        () => RuntimePanelDefinition.fromJson(missing),
        throwsFormatException,
      );
      expect(
        () => RuntimePanelDefinition.fromJson(unsupported),
        throwsFormatException,
      );
    });

    test('rejects unknown typed modes before controls render', () {
      final Map<String, dynamic> source = _panelJson();
      (source['visibility']! as Map<String, dynamic>)['mode'] = 'nearby';

      expect(
        () => RuntimePanelDefinition.fromJson(source),
        throwsFormatException,
      );
    });
  });
}

Map<String, dynamic> _panelJson() => <String, dynamic>{
  'schemaVersion': 1,
  'id': 'welcome',
  'uuid': '00000000-0000-4000-8000-000000000042',
  'revision': 7,
  'show': true,
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

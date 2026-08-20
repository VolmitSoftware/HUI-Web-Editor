import 'package:gloss_editor/components/inspector/inspector_session.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('action type switches preserve the current click trigger', () {
    final InspectorSession session = InspectorSession();
    final String slot = InspectorSession.actionSlot('buy', 'actions', 0);
    final HuiCommandAction command = HuiCommandAction(
      'warp shop',
      'player',
      'shift_left_click',
    );

    final HuiAction sound = session.switchAction(slot, command, 'sound');
    expect(sound, isA<HuiSoundAction>());
    expect(sound.trigger, 'shift_left_click');

    sound.trigger = 'right_click';
    final HuiAction restored = session.switchAction(slot, sound, 'command');
    expect(restored, isA<HuiCommandAction>());
    expect((restored as HuiCommandAction).command, 'warp shop');
    expect(restored.trigger, 'right_click');
  });

  group('collapsible section memory', () {
    setUp(InspectorSession.sectionOpen.clear);

    test('an untouched section takes its own default', () {
      expect(
        InspectorSession.isSectionOpen('component.hitbox', fallback: true),
        isTrue,
      );
      expect(
        InspectorSession.isSectionOpen('component.extras', fallback: false),
        isFalse,
      );
    });

    test('a closed section stays closed, whatever its default was', () {
      InspectorSession.setSectionOpen('component.hitbox', false);
      expect(
        InspectorSession.isSectionOpen('component.hitbox', fallback: true),
        isFalse,
      );
    });

    test('an opened advanced section stays open', () {
      InspectorSession.setSectionOpen('component.extras', true);
      expect(
        InspectorSession.isSectionOpen('component.extras', fallback: false),
        isTrue,
      );
    });

    test('the memory is per key, not per pane', () {
      // The whole point: closing Hitbox on one component leaves it closed on
      // the next selection, and says nothing about any other section.
      InspectorSession.setSectionOpen('component.hitbox', false);
      expect(
        InspectorSession.isSectionOpen('component.highlight', fallback: true),
        isTrue,
      );
    });
  });
}

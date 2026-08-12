import 'package:holoui_editor/components/inspector/inspector_session.dart';
import 'package:holoui_editor/model/model.dart';
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
}

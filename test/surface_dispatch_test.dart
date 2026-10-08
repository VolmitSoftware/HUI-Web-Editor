import 'package:gloss_editor/logic/surface_selection.dart';
import 'package:gloss_editor/logic/surface_validation.dart';
import 'package:gloss_editor/model/gloss_surface.dart';
import 'package:gloss_editor/model/hui_actions.dart';
import 'package:test/test.dart';

void main() {
  test('visual presentation edits preserve delivery, events, groups and flags', () {
    final GlossSurfaceDoc doc = decodeGlossSurfaceDoc('''
      {"schemaVersion":1,"revision":4,"surface":"bossbar","group":"quests","automatic":false,
       "select":{"when":"true"},"delivery":{"mode":"queue","preempt":"higher","maxPending":3,"custom":"retained"},
       "on":[{"trigger":"join","delayTicks":20,"when":"viewer.op"}],
       "presentation":{"title":"Quest","flags":["create_fog"]},"variants":[]}
      ''');
    final GlossSurfaceDoc copy = doc.copy();
    copy.presentation.title = 'Updated';
    copy.presentation.flags!.add('darken_sky');
    final GlossSurfaceDoc restored = decodeGlossSurfaceDoc(encodeGlossSurfaceDoc(copy));
    expect(restored.extras, doc.extras);
    expect(restored.revision, 4);
    expect(restored.presentation.flags, <String>['create_fog', 'darken_sky']);
    expect(doc.presentation.flags, <String>['create_fog']);
    expect(glossSurfaceEffective('bossbar', restored.presentation).flags, restored.presentation.flags);
    expect(glossSurfaceSilence(restored), GlossSurfaceSilence.eventOnly);
  });

  test('invalid queues and unsupported flag placement report authoring errors', () {
    final GlossSurfaceDoc doc = decodeGlossSurfaceDoc('''
      {"schemaVersion":1,"revision":1,"surface":"actionbar","select":{"when":"true"},
       "delivery":{"maxPending":999,"preempt":"invalid"},"on":[{"trigger":"interval","everyTicks":0}],
       "presentation":{"text":"Notice","flags":["create_fog"]}}
      ''');
    final List<String> paths = validateSurfaceDoc(doc).map((issue) => issue.path).toList();
    expect(paths, containsAll(<String>[r'$.delivery.maxPending', r'$.delivery.preempt', r'$.on[0].everyTicks', r'$.presentation.flags']));
  });

  test('surface actions are lossless runtime actions', () {
    final Map<String, Object?> source = <String, Object?>{'type': 'surface', 'surface': 'notice', 'audience': <String, Object?>{'scope': 'server', 'when': 'viewer.op'}};
    final HuiAction action = HuiAction.fromJson(source);
    expect(action.toJson(), source);
  });
}

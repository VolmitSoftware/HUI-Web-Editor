import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/logic/behavior_validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:test/test.dart';

void main() {
  const String source =
      '{"schemaVersion":2,"revision":9,"on":[{"trigger":"chat","pattern":"^hello",'
      '"do":[{"type":"message","message":"Welcome"}]}],"matching":{"maxWorkUnits":50000},'
      '"state":{"visits":{"scope":"player","type":"number","default":0}},"custom":{"retained":true}}';
  test(
    'behavior import routes to its typed adapter and preserves callbacks',
    () {
      final EditorStore store = EditorStore();
      store.importJson('greeting.json', source);
      expect(store.docType.kind, WorkspaceDocKind.behavior);
      final GlossBehaviorDoc doc = store.glossDoc! as GlossBehaviorDoc;
      expect(doc.revision, 9);
      expect(doc.on.single.pattern, '^hello');
      expect(doc.matching.maxWorkUnits, 50000);
      expect(validateBehaviorDoc(doc), isEmpty);
      doc.matching.maxInputCharacters = 200;
      final GlossBehaviorDoc roundtrip = decodeGlossBehaviorDoc(
        encodeGlossBehaviorDoc(doc),
      );
      expect(roundtrip.matching.maxInputCharacters, 200);
      expect(roundtrip.on.single.actions, doc.on.single.actions);
      expect(roundtrip.extras, doc.extras);
      expect(roundtrip.state, doc.state);
      expect(DocumentTypes.behavior.syncWireKind, 'behavior');
    },
  );
  test('matching limits and trigger options are validated before export', () {
    final GlossBehaviorDoc doc = decodeGlossBehaviorDoc(source);
    doc.matching.maxInputCharacters = 0;
    doc.matching.maxNestingDepth = 129;
    doc.on.single.region = 'spawn';
    expect(
      validateBehaviorDoc(doc).map((issue) => issue.path),
      containsAll(<String>[
        r'$.matching.maxInputCharacters',
        r'$.matching.maxNestingDepth',
        r'$.on[0].region',
      ]),
    );
  });
  test('event-driven surfaces keep their surface document type', () {
    final EditorStore store = EditorStore();
    store.importJson(
      'event.json',
      '{"schemaVersion":1,"surface":"bossbar","automatic":false,'
          '"on":[{"trigger":"join"}],"presentation":{"title":"Event"}}',
    );
    expect(store.glossDoc, isA<GlossSurfaceDoc>());
    expect(store.glossDoc, isNot(isA<GlossBehaviorDoc>()));
  });
  test('nested server commands need explicit authority', () {
    final GlossBehaviorDoc doc = GlossBehaviorDoc(
      on: <GlossBehaviorEntry>[
        GlossBehaviorEntry(
          actions: <Map<String, Object?>>[
            <String, Object?>{
              'type': 'sequence',
              'steps': <Object?>[
                <String, Object?>{
                  'type': 'command',
                  'source': 'server',
                  'command': 'say Hello',
                },
              ],
            },
          ],
        ),
      ],
    );
    expect(
      validateBehaviorDoc(doc).map((issue) => issue.message),
      contains('Server commands require allowServerCommands.'),
    );
    doc.allowServerCommands = true;
    expect(validateBehaviorDoc(doc), isEmpty);
  });
}

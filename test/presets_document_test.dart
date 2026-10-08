import 'dart:convert';

import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/config/gloss_json_schema.dart';
import 'package:gloss_editor/logic/json_schema.dart';
import 'package:gloss_editor/logic/document_presets.dart';
import 'package:gloss_editor/logic/presets_validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:test/test.dart';

void main() {
  test('runtime schema registry offers preset selection except on the catalog', () {
    for (final MapEntry<String, GlossJsonObject> schema in glossJsonSchemas.entries) {
      expect(schema.value.field('preset') != null, schema.key != 'presets', reason: schema.key);
    }
  });

  final Map<String, Object?> source = <String, Object?>{
    'schemaVersion': 1,
    'revision': 23,
    'defaults': <String, Object?>{
      'boards': <String, Object?>{
        'groups': <String>['member'],
        'title': 'Base',
      },
    },
    'presets': <String, Object?>{
      'boards': <String, Object?>{
        'base': <String, Object?>{
          'values': <String, Object?>{
            'lines': <String>['line'],
          },
        },
        'event': <String, Object?>{
          'extends': 'base',
          'values': <String, Object?>{'title': 'Event'},
        },
      },
      'behaviors': <String, Object?>{
        'join': <String, Object?>{
          'values': <String, Object?>{'trigger': 'join'},
        },
      },
    },
  };

  test(
    'preset codec preserves authored defaults, ancestry and all collections',
    () {
      final GlossPresetsDoc doc = decodeGlossPresetsDoc(jsonEncode(source));
      expect(doc.toJson(), source);
      expect(validatePresetsDoc(doc), isEmpty);
      final Map<String, Object?> exported = doc.toJson();
      (exported['defaults']! as Map<String, Object?>).clear();
      expect(doc.defaults, isNotEmpty);
      final DocumentPresets compiled = DocumentPresets.parse(
        encodeGlossPresetsDoc(doc),
      );
      expect(
        jsonDecode(
          compiled.resolve(
            'scoreboard',
            '{"schemaVersion":1,"revision":1,"preset":"event"}',
          ),
        ),
        <String, Object?>{
          'schemaVersion': 1,
          'revision': 1,
          'groups': <String>['member'],
          'title': 'Event',
          'lines': <String>['line'],
        },
      );
    },
  );

  test(
    'invalid ancestry stays editable and validates without rewriting it',
    () {
      final GlossPresetsDoc doc = decodeGlossPresetsDoc('''{
      "schemaVersion":1,"revision":1,"presets":{"boards":{
        "first":{"extends":"second"},"second":{"extends":"first"}
      }},"defaults":{}}
    ''');
      expect(validatePresetsDoc(doc).single.message, contains('cycle'));
      expect((doc.presets['boards']! as Map<String, Object?>).length, 2);
      doc.defaults['boards'] = <String, Object?>{'revision': 7};
      expect(validatePresetsDoc(doc).single.message, contains('revision'));
    },
  );

  test(
    'preset catalog registers as a fixed singleton and edits undo losslessly',
    () {
      final Workspace workspace = Workspace(
        read: (_) => null,
        write: (_, _) => true,
      );
      final EditorStore store = EditorStore(workspace: workspace);
      addTearDown(store.dispose);
      expect(
        DocumentTypeRegistry.detectTransferable(source),
        DocumentTypes.presets,
      );
      expect(DocumentTypeRegistry.byWireKind('presets'), DocumentTypes.presets);
      store.newGlossDocument(
        DocumentTypes.presets,
        from: decodeGlossPresetsDoc(jsonEncode(source)),
      );
      final String first = workspace.activeId!;
      store.mutateGloss('preset title', (GlossDoc doc) {
        (doc as GlossPresetsDoc).defaults['boards'] = <String, Object?>{
          'title': 'Changed',
        };
      });
      expect(
        (store.glossDoc as GlossPresetsDoc).defaults['boards'],
        <String, Object?>{'title': 'Changed'},
      );
      store.performUndo();
      expect((store.glossDoc as GlossPresetsDoc).toJson(), source);
      expect(store.renameActiveRuntimeId('other'), isFalse);
      store.newGlossDocument(DocumentTypes.presets);
      expect(workspace.activeId, first);
      expect(workspace.active?.runtimeId, 'presets');
    },
  );
}

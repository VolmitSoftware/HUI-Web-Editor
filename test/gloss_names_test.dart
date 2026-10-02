import 'dart:convert';

import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/logic/channel_preview.dart';
import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/logic/preview_sim.dart';
import 'package:gloss_editor/logic/real_drop_labels.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:test/test.dart';

void main() {
  test(
    'all name categories preserve spelling, empty values and extensions',
    () {
      final Map<String, Object?> source = <String, Object?>{
        'schemaVersion': 1,
        'revision': 8,
        for (final GlossNameCategory category in GlossNameCategory.values)
          category.name: <String, String>{' EXAMPLE ': 'Visible', 'hidden': ''},
        'extension': <String, Object?>{'enabled': true},
      };
      final GlossNamesDoc doc = decodeGlossNamesDoc(jsonEncode(source));
      expect(doc.toJson(), source);
      expect(decodeGlossNamesDoc(encodeGlossNamesDoc(doc)).toJson(), source);
      final GlossNamesDoc copy = doc.copy();
      copy.categories[GlossNameCategory.materials]![' EXAMPLE '] = 'Changed';
      expect(
        doc.categories[GlossNameCategory.materials]![' EXAMPLE '],
        'Visible',
      );
      expect(
        DocumentTypeRegistry.detectTransferable(source),
        DocumentTypes.names,
      );
      expect(DocumentTypeRegistry.byWireKind('names'), DocumentTypes.names);
    },
  );

  test('catalog normalizes game keys but preserves exact world keys', () {
    final GlossNamesDoc doc = GlossNamesDoc();
    doc.categories[GlossNameCategory.materials] = <String, String>{
      ' MINECRAFT:OAK_LOG ': 'Timber',
      'custom:oak_log': 'Custom timber',
    };
    doc.categories[GlossNameCategory.worlds] = <String, String>{
      'MyWorld': 'Home',
    };
    doc.categories[GlossNameCategory.groups] = <String, String>{
      'VIP': 'Supporter',
      'hidden': '',
    };
    final GlossNamesCatalog names = doc.catalog;
    expect(names.name(GlossNameCategory.materials, 'oak_log'), 'Timber');
    expect(
      names.name(GlossNameCategory.materials, 'custom:oak_log'),
      'Custom timber',
    );
    expect(names.name(GlossNameCategory.worlds, 'MyWorld'), 'Home');
    expect(names.name(GlossNameCategory.worlds, 'myworld'), 'Myworld');
    expect(names.name(GlossNameCategory.groups, 'vip'), 'Supporter');
    expect(names.name(GlossNameCategory.groups, 'hidden'), '');
    expect(names.name(GlossNameCategory.groups, ''), '');
    expect(names.name(GlossNameCategory.dimensions, 'NETHER'), 'The Nether');
    expect(
      glossReadableName('minecraft:heart__of-the sea'),
      'Heart of the Sea',
    );
  });

  test(
    'non-string values and non-object maps cannot be silently rewritten',
    () {
      for (final Object? value in <Object?>[
        null,
        12,
        true,
        <Object?>[],
        <String, Object?>{},
      ]) {
        expect(
          () => decodeGlossNamesDoc(
            jsonEncode(<String, Object?>{
              'schemaVersion': 1,
              'revision': 1,
              'materials': <String, Object?>{'stone': value},
            }),
          ),
          throwsA(isA<HuiFormatException>()),
        );
      }
      expect(
        () => decodeGlossNamesDoc(
          '{"schemaVersion":1,"revision":1,"materials":[]}',
        ),
        throwsA(isA<HuiFormatException>()),
      );
    },
  );

  test('catalog is singleton and updates workspace lookups through undo', () {
    final EditorStore store = EditorStore(
      workspace: Workspace(autoLoad: false),
      autosaveDelay: Duration.zero,
    );
    addTearDown(store.dispose);
    store.newGlossDocument(DocumentTypes.names);
    final String id = store.workspace.active!.id;
    store.mutateGloss('name', (GlossDoc doc) {
      (doc as GlossNamesDoc).categories[GlossNameCategory.materials]!['stone'] =
          'Rock';
    });
    expect(
      store.workspaceNames.name(GlossNameCategory.materials, 'stone'),
      'Rock',
    );
    expect(store.performUndo(), isTrue);
    expect(
      store.workspaceNames.name(GlossNameCategory.materials, 'stone'),
      'Stone',
    );
    store.newGlossDocument(DocumentTypes.names);
    expect(store.workspace.active!.id, id);
    expect(store.duplicateDocument(id), isNull);
    expect(store.renameDocumentRuntimeId(id, 'other'), isFalse);
  });

  test(
    'normalized duplicates and empty keys remain editable validation errors',
    () {
      final EditorStore store = EditorStore(
        workspace: Workspace(autoLoad: false),
      );
      addTearDown(store.dispose);
      final GlossNamesDoc doc = GlossNamesDoc();
      doc.categories[GlossNameCategory.materials] = <String, String>{
        'STONE': 'Rock',
        'minecraft:stone': 'Stone',
        ' ': 'Empty',
      };
      store.newGlossDocument(DocumentTypes.names, from: doc);
      expect(DocumentTypes.names.validate(store), hasLength(2));
    },
  );

  test(
    'catalog names reach expressions containers chat and drop overrides',
    () {
      final GlossNamesDoc doc = GlossNamesDoc();
      doc.categories[GlossNameCategory.materials]!['iron_ore'] = 'Raw Iron';
      doc.categories[GlossNameCategory.groups]!['member'] = 'Builder';
      doc.categories[GlossNameCategory.worlds]!['world'] = 'Home';
      final GlossNamesCatalog names = doc.catalog;
      final PreviewSim sim = PreviewSim('furnace', names: names)
        ..worldName = 'world';
      expect(sim.variable('blockTypeName'), 'Furnace');
      expect(sim.variable('world.displayName'), 'Home');
      expect(sim.call('itemName', <Object?>[0.0]), 'Raw Iron');
      expect(sim.call('name', <Object?>['groups', 'member']), 'Builder');
      final GlossTextExpressionSamples samples = GlossTextExpressionSamples(
        names: names,
        values: <String, Object>{'sender.group': 'member'},
      );
      expect(
        renderGlossLine(
          "{{ sender.groupName }}: {{ name('materials', 'iron_ore') }}",
          expressionSamples: samples,
        ).plainText,
        'Builder: Raw Iron',
      );
      final GlossChannelDoc channel = GlossChannelDoc()
        ..format = '{{ sender.groupName }}: {{ message }}';
      expect(
        channelPreview(
          channel,
          message: 'Hello',
          names: names,
        ).render.plainText,
        'Builder: Hello',
      );
      final GlossRealDropLabels labels = GlossRealDropLabels();
      expect(glossDropTypeName(labels, 'IRON_ORE', names: names), 'Raw Iron');
      labels.names['IRON_ORE'] = 'Ore';
      expect(glossDropTypeName(labels, 'IRON_ORE', names: names), 'Ore');
    },
  );
}

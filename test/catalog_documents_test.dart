import 'dart:convert';

import 'package:gloss_editor/doctype/doctype.dart';
import 'package:gloss_editor/logic/catalog_document_validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/state/editor_store.dart';
import 'package:gloss_editor/state/workspace.dart';
import 'package:test/test.dart';

void main() {
  test('strings retain numeric-looking text, placeholders and extensions', () {
    final GlossStringsDoc doc = decodeGlossStringsDoc(
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'revision': 9,
        'locale': 'de_DE',
        'fallback': 'en_US',
        'entries': <String, String>{
          'count': '001',
          'hello': 'Hello {player}',
          'blank': '',
        },
        'extension': <String, Object?>{'enabled': false},
      }),
    );
    expect(
      decodeGlossStringsDoc(encodeGlossStringsDoc(doc)).toJson(),
      doc.toJson(),
    );
    expect(validateStringsDoc(doc), isEmpty);
    expect(
      DocumentTypeRegistry.detectTransferable(doc.toJson()),
      DocumentTypes.strings,
    );
    expect(DocumentTypeRegistry.byWireKind('strings'), DocumentTypes.strings);
    expect(
      () => decodeGlossStringsDoc(
        '{"schemaVersion":1,"revision":1,"locale":"en_US","entries":{"count":1}}',
      ),
      throwsA(isA<HuiFormatException>()),
    );
  });

  test('strings support store editing and undo without coercion', () {
    final EditorStore store = EditorStore(
      workspace: Workspace(autoLoad: false),
    );
    addTearDown(store.dispose);
    store.newGlossDocument(DocumentTypes.strings);
    store.mutateGloss(
      'entry',
      (GlossDoc doc) => (doc as GlossStringsDoc).entries['value'] = '001',
    );
    expect((store.glossDoc as GlossStringsDoc).entries['value'], '001');
    expect(store.performUndo(), isTrue);
    expect((store.glossDoc as GlossStringsDoc).entries, isEmpty);
    expect(store.performRedo(), isTrue);
    expect((store.glossDoc as GlossStringsDoc).entries['value'], '001');
  });

  test('invalid catalog keys and locales remain editable with validation', () {
    final GlossStringsDoc doc = GlossStringsDoc(
      locale: 'bad',
      fallback: 'x',
      entries: <String, String>{'Bad key': 'value'},
    );
    expect(
      validateStringsDoc(doc).map((issue) => issue.path),
      containsAll(<String>[r'$.locale', r'$.fallback', r'$.entries.Bad key']),
    );
  });

  test('waypoint anchor forms remain distinct from markers', () {
    for (final GlossMarkerAnchor anchor in <GlossMarkerAnchor>[
      GlossMarkerAnchor(world: 'world', x: 1, y: 70, z: -3),
      GlossMarkerAnchor(player: 'Example'),
      GlossMarkerAnchor(entity: '00000000-0000-4000-8000-000000000001'),
    ]) {
      final GlossWaypointDoc doc = GlossWaypointDoc(
        anchor: anchor,
        range: 64,
        color: '#aabbcc',
        style: 'bowtie',
        show: 'viewer.op',
        audience: 'viewer.world == "world"',
      );
      final GlossWaypointDoc copy = decodeGlossWaypointDoc(
        encodeGlossWaypointDoc(doc),
      );
      expect(copy.toJson(), doc.toJson());
      expect(validateWaypointDoc(copy), isEmpty);
      expect(
        DocumentTypeRegistry.detectTransferable(copy.toJson()),
        DocumentTypes.waypoint,
      );
    }
    expect(DocumentTypeRegistry.byWireKind('waypoint'), DocumentTypes.waypoint);
    final GlossWaypointDoc invalid = GlossWaypointDoc(
      anchor: GlossMarkerAnchor(world: 'world', player: 'Example'),
    );
    expect(
      validateWaypointDoc(invalid).map((issue) => issue.path),
      contains(r'$.anchor'),
    );
  });
}

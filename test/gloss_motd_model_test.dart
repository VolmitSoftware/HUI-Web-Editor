/// GlossMotdDoc: round-trips, unknown-key preservation at both levels, the
/// lenient decode of what `MotdDoc.java` would reject, and the shape check
/// import routing relies on.
library;

import 'dart:convert';

import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

const String _motd = '''
{
  "schemaVersion": 1,
  "revision": 4,
  "entries": [
    {
      "lines": [
        "&dA glossy server",
        "&7Line two"
      ]
    },
    {
      "lines": [
        "&bSecond entry"
      ]
    }
  ]
}
''';

void main() {
  group('decode', () {
    test('reads the full document', () {
      final GlossMotdDoc doc = decodeGlossMotdDoc(_motd);
      expect(doc.revision, 4);
      expect(doc.entries, hasLength(2));
      expect(doc.entries[0].lines, <String>['&dA glossy server', '&7Line two']);
      expect(doc.entries[0].joined, '&dA glossy server\n&7Line two');
      expect(doc.entries[1].lines, <String>['&bSecond entry']);
    });

    test('rejects a wrong or missing schemaVersion', () {
      expect(
        () => decodeGlossMotdDoc('{"schemaVersion": 2, "entries": []}'),
        throwsA(isA<HuiFormatException>()),
      );
      expect(
        () => decodeGlossMotdDoc('{"entries": []}'),
        throwsA(isA<HuiFormatException>()),
      );
    });

    test('what the plugin rejects decodes leniently for repair', () {
      // No entries, an entry with no lines, an entry with three lines: all
      // parse failures in MotdDoc.java, all open here for validation to name.
      final GlossMotdDoc empty = decodeGlossMotdDoc(
        '{"schemaVersion": 1, "revision": 1, "entries": []}',
      );
      expect(empty.entries, isEmpty);

      final GlossMotdDoc bad = decodeGlossMotdDoc(
        '{"schemaVersion": 1, "revision": 1, "entries": ['
        '{"lines": []}, {"lines": ["a", "b", "c"]}]}',
      );
      expect(bad.entries[0].lines, isEmpty);
      expect(bad.entries[1].lines, hasLength(3));
    });

    test('a scalar line stands in for a one-element list', () {
      // SingleCollectionTypeFactory in the Gson stack.
      final GlossMotdDoc doc = decodeGlossMotdDoc(
        '{"schemaVersion": 1, "revision": 1, "entries": [{"lines": "one"}]}',
      );
      expect(doc.entries.single.lines, <String>['one']);
    });
  });

  group('round-trip', () {
    test('decode-encode is stable and matches the source tree', () {
      final GlossMotdDoc doc = decodeGlossMotdDoc(_motd);
      final String encoded = encodeGlossMotdDoc(doc);
      expect(encodeGlossMotdDoc(decodeGlossMotdDoc(encoded)), encoded);
      expect(jsonDecode(encoded), jsonDecode(_motd));
    });

    test('unknown keys survive at the document and the entry level', () {
      const String withExtras = '''
{
  "schemaVersion": 1,
  "revision": 1,
  "entries": [
    {"lines": ["a"], "weight": 5}
  ],
  "futurePicker": "weighted"
}
''';
      final GlossMotdDoc doc = decodeGlossMotdDoc(withExtras);
      doc.entries[0].lines[0] = 'edited';
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossMotdDoc(doc)) as Map<String, dynamic>;
      expect(out['futurePicker'], 'weighted');
      final Map<String, dynamic> entry =
          (out['entries'] as List<dynamic>)[0] as Map<String, dynamic>;
      expect(entry['weight'], 5);
      expect(entry['lines'], <String>['edited']);
    });

    test('clone is deep', () {
      final GlossMotdDoc doc = decodeGlossMotdDoc(_motd);
      final GlossMotdDoc clone = cloneGlossMotdDoc(doc);
      clone.entries[0].lines[0] = 'changed';
      expect(doc.entries[0].lines[0], '&dA glossy server');
    });
  });

  group('shape check', () {
    test('claims MOTD documents and nothing else', () {
      expect(looksLikeMotdDoc(jsonDecode(_motd)), isTrue);
      expect(
        looksLikeMotdDoc(<String, Object?>{
          'schemaVersion': 1,
          'frames': <String>['a'],
        }),
        isFalse,
        reason: 'animation documents carry frames',
      );
      expect(
        looksLikeMotdDoc(<String, Object?>{
          'schemaVersion': 1,
          'anchor': <String, Object?>{},
          'entries': <Object?>[],
        }),
        isFalse,
        reason: 'anchor marks a hologram',
      );
      expect(looksLikeMotdDoc(<String, Object?>{'entries': <Object?>[]}), isFalse);
      // The other Gloss kinds must not claim an MOTD document either.
      expect(looksLikeScoreboardDoc(jsonDecode(_motd)), isFalse);
      expect(looksLikeAnimationDoc(jsonDecode(_motd)), isFalse);
      expect(looksLikeHologramDoc(jsonDecode(_motd)), isFalse);
    });
  });
}

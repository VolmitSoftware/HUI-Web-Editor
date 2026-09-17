/// GlossConnectionsDoc: the server edition of `connections.json`, its two
/// sections, and the proxy-only blocks it carries through untouched.
///
/// The shape is `ConnectionsDoc.java`: a section that is present is on unless
/// it says otherwise (`Section.enabled == null ? TRUE`), a section the file
/// leaves out is off entirely (`Section.DISABLED`), and `switch` plus the
/// per-section `audience` are read without complaint on a standalone server.
library;

import 'dart:convert';

import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

/// `defaults/connections/connections.json`, byte for byte.
const String _shipped = '''
{
  "schemaVersion": 1,
  "revision": 1,
  "show": true,
  "join": {
    "enabled": true,
    "show": true,
    "audience": "network",
    "presentation": { "text": "&a+ &f{{ subject.name }} &7joined" },
    "variants": []
  },
  "leave": {
    "enabled": true,
    "show": true,
    "audience": "network",
    "presentation": { "text": "&c- &f{{ subject.name }} &7left" },
    "variants": []
  }
}
''';

void main() {
  group('decode', () {
    test('reads the shipped default', () {
      final GlossConnectionsDoc doc = decodeGlossConnectionsDoc(_shipped);
      expect(doc.schemaVersion, 1);
      expect(doc.revision, 1);
      expect(doc.extras['show'], isTrue);
      expect(doc.join.enabled, isTrue);
      expect(doc.join.audience, glossConnectionsAudienceNetwork);
      expect(doc.join.presentation.text, '&a+ &f{{ subject.name }} &7joined');
      expect(doc.join.variants, isEmpty);
      expect(doc.leave.presentation.text, '&c- &f{{ subject.name }} &7left');
    });

    test('rejects a wrong or missing schemaVersion', () {
      expect(
        () => decodeGlossConnectionsDoc('{"schemaVersion": 2}'),
        throwsA(isA<HuiFormatException>()),
      );
      expect(
        () => decodeGlossConnectionsDoc('{}'),
        throwsA(isA<HuiFormatException>()),
      );
    });

    test('a present section with no enabled key is on', () {
      // Section.java: `enabled = enabled == null ? Boolean.TRUE : enabled`.
      final GlossConnectionsDoc doc = decodeGlossConnectionsDoc(
        '{"schemaVersion": 1, "revision": 1, '
        '"join": {"presentation": {"text": "hi"}}}',
      );
      expect(doc.join.present, isTrue);
      expect(doc.join.enabled, isTrue);
    });

    test('a section the file leaves out is off, not defaulted on', () {
      // Section.DISABLED — adding the block is the only way to broadcast.
      final GlossConnectionsDoc doc = decodeGlossConnectionsDoc(
        '{"schemaVersion": 1, "revision": 1}',
      );
      expect(doc.join.present, isFalse);
      expect(doc.join.enabled, isFalse);
      expect(doc.leave.present, isFalse);
      expect(doc.leave.enabled, isFalse);
    });

    test('a blank or missing audience reads as network', () {
      final GlossConnectionsDoc doc = decodeGlossConnectionsDoc(
        '{"schemaVersion": 1, "revision": 1, '
        '"join": {"audience": "   ", "presentation": {"text": "hi"}}, '
        '"leave": {"presentation": {"text": "bye"}}}',
      );
      expect(doc.join.audience, glossConnectionsAudienceNetwork);
      expect(doc.leave.audience, glossConnectionsAudienceNetwork);
    });

    test('an unknown audience decodes leniently for validation to name', () {
      final GlossConnectionsDoc doc = decodeGlossConnectionsDoc(
        '{"schemaVersion": 1, "revision": 1, '
        '"join": {"audience": "lobby", "presentation": {"text": "hi"}}}',
      );
      expect(doc.join.audience, 'lobby');
    });

    test('variants keep the authored order, not the runtime sort', () {
      // Section.copyVariants sorts by priority for selection; rewriting the
      // file in that order would be an edit the author never asked for.
      final GlossConnectionsDoc doc = decodeGlossConnectionsDoc(
        '{"schemaVersion": 1, "revision": 1, "join": {"presentation": '
        '{"text": "hi"}, "variants": ['
        '{"priority": 1, "when": "a", "presentation": {"text": "low"}}, '
        '{"priority": 9, "when": "b", "presentation": {"text": "high"}}]}}',
      );
      expect(
        doc.join.variants.map((GlossConnectionsVariant v) => v.priority),
        <int>[1, 9],
      );
      expect(doc.join.variants.first.presentation.text, 'low');
    });
  });

  group('round-trip', () {
    test('the shipped default re-encodes to the same tree', () {
      final GlossConnectionsDoc doc = decodeGlossConnectionsDoc(_shipped);
      final String encoded = encodeGlossConnectionsDoc(doc);
      expect(jsonDecode(encoded), jsonDecode(_shipped));
      expect(
        encodeGlossConnectionsDoc(decodeGlossConnectionsDoc(encoded)),
        encoded,
      );
    });

    test('an absent section stays absent through a round trip', () {
      const String source =
          '{"schemaVersion": 1, "revision": 1, '
          '"leave": {"enabled": true, "show": true, "audience": "server", '
          '"presentation": {"text": "bye"}, "variants": []}}';
      final GlossConnectionsDoc doc = decodeGlossConnectionsDoc(source);
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossConnectionsDoc(doc)) as Map<String, dynamic>;
      expect(out.containsKey('join'), isFalse);
      expect(out.containsKey('leave'), isTrue);
    });

    test('the proxy-only switch block survives untouched', () {
      // The server ignores `switch`, but the file is the proxy's file too.
      const String source =
          '{"schemaVersion": 1, "revision": 1, '
          '"join": {"presentation": {"text": "hi"}}, '
          '"switch": {"enabled": true, "audience": "network", '
          '"presentation": {"text": "&7{{ subject.name }} moved"}}}';
      final GlossConnectionsDoc doc = decodeGlossConnectionsDoc(source);
      doc.join.presentation.text = 'edited';
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossConnectionsDoc(doc)) as Map<String, dynamic>;
      final Map<String, dynamic> proxy = out['switch']! as Map<String, dynamic>;
      expect(proxy['enabled'], isTrue);
      expect(
        (proxy['presentation']! as Map<String, dynamic>)['text'],
        '&7{{ subject.name }} moved',
      );
    });

    test('unknown keys survive at every level', () {
      const String source =
          '{"schemaVersion": 1, "revision": 1, '
          '"futureFlag": 7, '
          '"join": {"presentation": {"text": "hi", "futureStyle": "bold"}, '
          '"futureSection": true, "variants": [{"priority": 1, "when": "a", '
          '"presentation": {"text": "v"}, "futureVariant": "x"}]}}';
      final GlossConnectionsDoc doc = decodeGlossConnectionsDoc(source);
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossConnectionsDoc(doc)) as Map<String, dynamic>;
      expect(out['futureFlag'], 7);
      final Map<String, dynamic> join = out['join']! as Map<String, dynamic>;
      expect(join['futureSection'], isTrue);
      expect(
        (join['presentation']! as Map<String, dynamic>)['futureStyle'],
        'bold',
      );
      expect(
        ((join['variants']! as List<dynamic>)[0]
            as Map<String, dynamic>)['futureVariant'],
        'x',
      );
    });

    test('clone is deep', () {
      final GlossConnectionsDoc doc = decodeGlossConnectionsDoc(_shipped);
      final GlossConnectionsDoc clone = cloneGlossConnectionsDoc(doc);
      clone.join.presentation.text = 'changed';
      expect(doc.join.presentation.text, '&a+ &f{{ subject.name }} &7joined');
      expect(doc.copy().leave.presentation.text, doc.leave.presentation.text);
    });
  });

  group('shape check', () {
    test('claims connections documents and nothing else', () {
      expect(looksLikeConnectionsDoc(jsonDecode(_shipped)), isTrue);
      expect(
        looksLikeConnectionsDoc(<String, Object?>{
          'schemaVersion': 1,
          'entries': <Object?>[],
        }),
        isFalse,
        reason: 'a MOTD carries entries',
      );
      expect(
        looksLikeConnectionsDoc(<String, Object?>{
          'schemaVersion': 1,
          'headerFooter': <String, Object?>{},
          'listNames': <String, Object?>{},
        }),
        isFalse,
        reason: 'a tablist carries headerFooter and listNames',
      );
      expect(looksLikeConnectionsDoc(<String, Object?>{'join': 1}), isFalse);
      // The other Gloss kinds must not claim a connections document.
      expect(looksLikeMotdDoc(jsonDecode(_shipped)), isFalse);
      expect(looksLikeTablistDoc(jsonDecode(_shipped)), isFalse);
      expect(looksLikeScoreboardDoc(jsonDecode(_shipped)), isFalse);
    });
  });
}

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

    test('a favicon round-trips at the document and the entry level', () {
      const String withIcons = '''
{
  "schemaVersion": 1,
  "revision": 1,
  "favicon": "server.png",
  "entries": [
    {"lines": ["a"], "favicon": "event.png"},
    {"lines": ["b"]}
  ]
}
''';
      final GlossMotdDoc doc = decodeGlossMotdDoc(withIcons);
      expect(doc.favicon, 'server.png');
      expect(doc.entries[0].favicon, 'event.png');
      expect(doc.entries[1].favicon, isNull);
      expect(jsonDecode(encodeGlossMotdDoc(doc)), jsonDecode(withIcons));
    });

    test('a blank favicon is dropped from the output at both levels', () {
      final GlossMotdDoc doc = decodeGlossMotdDoc(
        '{"schemaVersion": 1, "revision": 1, "favicon": "  ", '
        '"entries": [{"lines": ["a"], "favicon": ""}]}',
      );
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossMotdDoc(doc)) as Map<String, dynamic>;
      expect(out.containsKey('favicon'), isFalse);
      final Map<String, dynamic> entry =
          (out['entries'] as List<dynamic>)[0] as Map<String, dynamic>;
      expect(entry.containsKey('favicon'), isFalse);
    });

    test('an absent favicon stays absent', () {
      final GlossMotdDoc doc = decodeGlossMotdDoc(_motd);
      expect(doc.favicon, isNull);
      expect(
        doc.entries.every((GlossMotdEntry e) => e.favicon == null),
        isTrue,
      );
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossMotdDoc(doc)) as Map<String, dynamic>;
      expect(out.containsKey('favicon'), isFalse);
      for (final Object? entry in out['entries'] as List<dynamic>) {
        expect(
          (entry! as Map<String, dynamic>).containsKey('favicon'),
          isFalse,
        );
      }
    });

    test('clone is deep', () {
      final GlossMotdDoc doc = decodeGlossMotdDoc(_motd);
      doc.favicon = 'server.png';
      doc.entries[0].favicon = 'event.png';
      final GlossMotdDoc clone = cloneGlossMotdDoc(doc);
      clone.entries[0].lines[0] = 'changed';
      expect(doc.entries[0].lines[0], '&dA glossy server');
      expect(clone.favicon, 'server.png');
      expect(clone.entries[0].favicon, 'event.png');
      expect(clone.copy().entries[0].favicon, 'event.png');
    });
  });

  group('faviconFor', () {
    test('an entry icon wins, the document icon is the fallback', () {
      final GlossMotdDoc doc = GlossMotdDoc(
        favicon: 'server.png',
        entries: <GlossMotdEntry>[
          GlossMotdEntry(lines: <String>['a']),
          GlossMotdEntry(lines: <String>['b'], favicon: 'event.png'),
        ],
      );
      expect(doc.faviconFor(doc.entries[0]), 'server.png');
      expect(doc.faviconFor(doc.entries[1]), 'event.png');
    });

    test('blank at either level is no icon at that level', () {
      final GlossMotdDoc blankEntry = GlossMotdDoc(
        favicon: 'server.png',
        entries: <GlossMotdEntry>[
          GlossMotdEntry(lines: <String>['a'], favicon: '  '),
        ],
      );
      expect(blankEntry.faviconFor(blankEntry.entries.single), 'server.png');

      final GlossMotdDoc blankDoc = GlossMotdDoc(
        favicon: '',
        entries: <GlossMotdEntry>[
          GlossMotdEntry(lines: <String>['a']),
        ],
      );
      expect(blankDoc.faviconFor(blankDoc.entries.single), isNull);
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
      expect(
        looksLikeMotdDoc(<String, Object?>{'entries': <Object?>[]}),
        isFalse,
      );
      // The other Gloss kinds must not claim an MOTD document either.
      expect(looksLikeScoreboardDoc(jsonDecode(_motd)), isFalse);
      expect(looksLikeAnimationDoc(jsonDecode(_motd)), isFalse);
      expect(looksLikeHologramDoc(jsonDecode(_motd)), isFalse);
    });
  });

  group('links', () {
    const String withLinks = '''
{
  "schemaVersion": 1,
  "revision": 1,
  "entries": [
    {"lines": ["a"]}
  ],
  "links": [
    {"type": "website", "url": "https://example.net"},
    {"label": "&bStore", "url": "http://store.example.net/buy"}
  ]
}
''';

    test('reads a typed link and a labelled link', () {
      final GlossMotdDoc doc = decodeGlossMotdDoc(withLinks);
      expect(doc.links, hasLength(2));
      expect(doc.links[0].type, 'website');
      expect(doc.links[0].label, isNull);
      expect(doc.links[0].url, 'https://example.net');
      expect(doc.links[1].type, isNull);
      expect(doc.links[1].label, '&bStore');
      expect(doc.links[1].url, 'http://store.example.net/buy');
      expect(jsonDecode(encodeGlossMotdDoc(doc)), jsonDecode(withLinks));
    });

    test('a type is stored lowercase, the way MotdLink normalizes it', () {
      final GlossMotdDoc doc = decodeGlossMotdDoc(
        '{"schemaVersion": 1, "revision": 1, "entries": [{"lines": ["a"]}], '
        '"links": [{"type": "  Report_Bug  ", "url": "https://x.example"}]}',
      );
      expect(doc.links.single.type, 'report_bug');
    });

    test('a blank type or label is dropped, the url always written', () {
      final GlossMotdDoc doc = decodeGlossMotdDoc(
        '{"schemaVersion": 1, "revision": 1, "entries": [{"lines": ["a"]}], '
        '"links": [{"type": "  ", "label": "", "url": ""}]}',
      );
      final Map<String, dynamic> link =
          ((jsonDecode(encodeGlossMotdDoc(doc))
                      as Map<String, dynamic>)['links']
                  as List<dynamic>)[0]
              as Map<String, dynamic>;
      expect(link.containsKey('type'), isFalse);
      expect(link.containsKey('label'), isFalse);
      expect(link['url'], '');
    });

    test('an absent or empty link list stays out of the output', () {
      final GlossMotdDoc absent = decodeGlossMotdDoc(_motd);
      expect(absent.links, isEmpty);
      expect(
        (jsonDecode(encodeGlossMotdDoc(absent)) as Map<String, dynamic>)
            .containsKey('links'),
        isFalse,
      );
      final GlossMotdDoc empty = decodeGlossMotdDoc(
        '{"schemaVersion": 1, "revision": 1, "entries": [{"lines": ["a"]}], '
        '"links": []}',
      );
      expect(
        (jsonDecode(encodeGlossMotdDoc(empty)) as Map<String, dynamic>)
            .containsKey('links'),
        isFalse,
      );
    });

    test('unknown keys on a link survive the round trip', () {
      final GlossMotdDoc doc = decodeGlossMotdDoc(
        '{"schemaVersion": 1, "revision": 1, "entries": [{"lines": ["a"]}], '
        '"links": [{"type": "news", "url": "https://x.example", "weight": 3}]}',
      );
      doc.links.single.url = 'https://y.example';
      final Map<String, dynamic> link =
          ((jsonDecode(encodeGlossMotdDoc(doc))
                      as Map<String, dynamic>)['links']
                  as List<dynamic>)[0]
              as Map<String, dynamic>;
      expect(link['weight'], 3);
      expect(link['url'], 'https://y.example');
    });

    test('clone deep-copies the link list', () {
      final GlossMotdDoc doc = decodeGlossMotdDoc(withLinks);
      final GlossMotdDoc clone = cloneGlossMotdDoc(doc);
      clone.links[0].url = 'https://changed.example';
      clone.links.removeAt(1);
      expect(doc.links, hasLength(2));
      expect(doc.links[0].url, 'https://example.net');
      expect(doc.copy().links[1].label, '&bStore');
    });

    test('the limits mirror the Java constants', () {
      expect(glossMotdMaxLinks, 16);
      expect(glossMotdMaxSampleLines, 12);
      expect(glossMotdLinkTypes, <String>[
        'report_bug',
        'community_guidelines',
        'support',
        'status',
        'feedback',
        'community',
        'website',
        'forums',
        'news',
        'announcements',
      ]);
    });
  });

  group('entry ping extras', () {
    const String withExtras = '''
{
  "schemaVersion": 1,
  "revision": 1,
  "entries": [
    {
      "lines": ["a"],
      "sample": ["&7Now playing", "&fSkyblock"],
      "online": "42",
      "max": "{{ server.maxPlayers }}",
      "version": "&cOutdated"
    }
  ]
}
''';

    test('sample, online, max and version round-trip', () {
      final GlossMotdDoc doc = decodeGlossMotdDoc(withExtras);
      final GlossMotdEntry entry = doc.entries.single;
      expect(entry.sample, <String>['&7Now playing', '&fSkyblock']);
      expect(entry.online, '42');
      expect(entry.max, '{{ server.maxPlayers }}');
      expect(entry.version, '&cOutdated');
      expect(jsonDecode(encodeGlossMotdDoc(doc)), jsonDecode(withExtras));
    });

    test('a null sample line becomes an empty string, as MotdEntry does', () {
      final GlossMotdDoc doc = decodeGlossMotdDoc(
        '{"schemaVersion": 1, "revision": 1, '
        '"entries": [{"lines": ["a"], "sample": ["x", null]}]}',
      );
      expect(doc.entries.single.sample, <String>['x', '']);
    });

    test('blank or absent ping extras stay out of the output', () {
      final GlossMotdDoc doc = decodeGlossMotdDoc(
        '{"schemaVersion": 1, "revision": 1, "entries": [{"lines": ["a"], '
        '"sample": [], "online": "  ", "max": "", "version": " "}]}',
      );
      final Map<String, dynamic> entry =
          ((jsonDecode(encodeGlossMotdDoc(doc))
                      as Map<String, dynamic>)['entries']
                  as List<dynamic>)[0]
              as Map<String, dynamic>;
      expect(entry.containsKey('sample'), isFalse);
      expect(entry.containsKey('online'), isFalse);
      expect(entry.containsKey('max'), isFalse);
      expect(entry.containsKey('version'), isFalse);
    });

    test('copy deep-copies the sample list', () {
      final GlossMotdDoc doc = decodeGlossMotdDoc(withExtras);
      final GlossMotdEntry copy = doc.entries.single.copy();
      copy.sample[0] = 'changed';
      copy.online = '1';
      expect(doc.entries.single.sample[0], '&7Now playing');
      expect(doc.entries.single.online, '42');
    });
  });
}

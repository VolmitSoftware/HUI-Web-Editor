/// GlossScoreboardDoc: round-trips, unknown-key preservation, the silent
/// BoardDoc normalizations as derived accessors, and the shape check import
/// routing relies on.
library;

import 'dart:convert';

import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

const String _board = '''
{
  "schemaVersion": 1,
  "revision": 6,
  "title": "&d&lGloss",
  "lines": [
    "&fWelcome!",
    "&7Line two"
  ],
  "primary": true,
  "hideNumbers": true,
  "permission": "vip",
  "groups": ["vip", "mvp"]
}
''';

void main() {
  group('decode', () {
    test('reads the full document', () {
      final GlossScoreboardDoc doc = decodeGlossScoreboardDoc(_board);
      expect(doc.revision, 6);
      expect(doc.title, '&d&lGloss');
      expect(doc.lines, <String>['&fWelcome!', '&7Line two']);
      expect(doc.primary, isTrue);
      expect(doc.hideNumbers, isTrue);
      expect(doc.permission, 'vip');
      expect(doc.groups, <String>['vip', 'mvp']);
    });

    test('rejects a wrong or missing schemaVersion', () {
      expect(
        () => decodeGlossScoreboardDoc('{"schemaVersion": 2, "title": "x"}'),
        throwsA(isA<HuiFormatException>()),
      );
      expect(
        () => decodeGlossScoreboardDoc('{"title": "x", "lines": []}'),
        throwsA(isA<HuiFormatException>()),
      );
    });

    test('missing board fields fall to the record defaults', () {
      final GlossScoreboardDoc doc = decodeGlossScoreboardDoc(
        '{"schemaVersion": 1, "revision": 1, "title": "t"}',
      );
      expect(doc.lines, isEmpty);
      expect(doc.primary, isFalse);
      expect(doc.hideNumbers, isFalse);
      expect(doc.permission, '');
      expect(doc.effectivePermission, glossBoardUnrestrictedPermission);
      expect(doc.groups, isEmpty);
    });
  });

  group('the silent normalizations are derived, never destructive', () {
    test('permission trims, lowercases, and blank means default', () {
      final GlossScoreboardDoc doc = decodeGlossScoreboardDoc(_board)
        ..permission = '  VIP ';
      expect(doc.permission, '  VIP ');
      expect(doc.effectivePermission, 'vip');
      expect(doc.permissionGated, isTrue);
      doc.permission = '';
      expect(doc.effectivePermission, 'default');
      expect(doc.permissionGated, isFalse);
      doc.permission = 'Default';
      expect(doc.permissionGated, isFalse);
    });

    test('groups trim, lowercase, drop blanks and deduplicate in order', () {
      final GlossScoreboardDoc doc = decodeGlossScoreboardDoc(_board)
        ..groups = <String>[' VIP', '', 'mvp', 'vip', '  '];
      expect(doc.effectiveGroups, <String>['vip', 'mvp']);
      expect(
        doc.groups,
        hasLength(5),
        reason: 'the file keeps what was written',
      );
    });
  });

  group('round-trip', () {
    test('decode-encode is stable and matches the source tree', () {
      final GlossScoreboardDoc doc = decodeGlossScoreboardDoc(_board);
      final String encoded = encodeGlossScoreboardDoc(doc);
      expect(
        encodeGlossScoreboardDoc(decodeGlossScoreboardDoc(encoded)),
        encoded,
      );
      expect(jsonDecode(encoded), jsonDecode(_board));
    });

    test('unknown keys survive after the known ones', () {
      const String withExtras = '''
{
  "schemaVersion": 1,
  "revision": 1,
  "title": "t",
  "lines": ["a"],
  "primary": false,
  "permission": "default",
  "groups": [],
  "futureSelector": {"weight": 5}
}
''';
      final GlossScoreboardDoc doc = decodeGlossScoreboardDoc(withExtras);
      doc.title = 'edited';
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossScoreboardDoc(doc)) as Map<String, dynamic>;
      expect(out['futureSelector'], <String, dynamic>{'weight': 5});
      expect(out['title'], 'edited');
    });

    test('absent optional keys stay absent until they carry meaning', () {
      final GlossScoreboardDoc doc = decodeGlossScoreboardDoc(
        '{"schemaVersion": 1, "revision": 1, "title": "t"}',
      );
      expect(jsonDecode(encodeGlossScoreboardDoc(doc)), <String, dynamic>{
        'schemaVersion': 1,
        'revision': 1,
        'title': 't',
      });
      doc.primary = true;
      doc.hideNumbers = true;
      doc.groups.add('vip');
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossScoreboardDoc(doc)) as Map<String, dynamic>;
      expect(out['primary'], isTrue);
      expect(out['hideNumbers'], isTrue);
      expect(out['groups'], <String>['vip']);
    });
  });

  group('copy', () {
    test('is deep', () {
      final GlossScoreboardDoc doc = decodeGlossScoreboardDoc(_board);
      final GlossScoreboardDoc copied = doc.copy();
      copied.lines.add('extra');
      copied.groups.add('admin');
      copied.title = 'other';
      expect(doc.lines, hasLength(2));
      expect(doc.groups, hasLength(2));
      expect(doc.title, '&d&lGloss');
    });
  });

  group('looksLikeScoreboardDoc', () {
    test(
      'needs the envelope plus a board key, and no other kind\'s marker',
      () {
        expect(looksLikeScoreboardDoc(jsonDecode(_board)), isTrue);
        expect(
          looksLikeScoreboardDoc(<String, dynamic>{
            'schemaVersion': 1,
            'lines': <String>[],
          }),
          isFalse,
          reason: 'lines alone are ambiguous with a broken hologram',
        );
        expect(
          looksLikeScoreboardDoc(<String, dynamic>{
            'schemaVersion': 1,
            'anchor': <String, dynamic>{},
            'title': 't',
          }),
          isFalse,
          reason: 'an anchor makes it a hologram',
        );
        expect(
          looksLikeScoreboardDoc(<String, dynamic>{
            'schemaVersion': 1,
            'frames': <String>[],
            'title': 't',
          }),
          isFalse,
          reason: 'frames make it an animation',
        );
        // The three Gloss shape checks stay mutually exclusive.
        expect(looksLikeHologramDoc(jsonDecode(_board)), isFalse);
        expect(looksLikeAnimationDoc(jsonDecode(_board)), isFalse);
      },
    );
  });
}

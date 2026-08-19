/// GlossTablistDoc: round-trips, the silent copyFormats normalization as a
/// derived accessor, the chooseListName/substituteTokens mirrors, and the
/// shape check import routing relies on.
library;

import 'dart:convert';

import 'package:gloss_editor/logic/tablist_selection.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

const String _tablist = '''
{
  "schemaVersion": 1,
  "revision": 7,
  "useHeaderFooter": true,
  "header": "&d&lGloss",
  "footer": "&7VolmitSoftware.com",
  "groupListNames": true,
  "nameFormats": {
    "default": "\$player",
    "_op": "&6\$player",
    "vip": "&6[\$group] \$player"
  }
}
''';

void main() {
  group('decode', () {
    test('reads the full document, formats in file order', () {
      final GlossTablistDoc doc = decodeGlossTablistDoc(_tablist);
      expect(doc.revision, 7);
      expect(doc.useHeaderFooter, isTrue);
      expect(doc.header, '&d&lGloss');
      expect(doc.footer, '&7VolmitSoftware.com');
      expect(doc.groupListNames, isTrue);
      expect(
        doc.nameFormats.keys.toList(),
        <String>['default', '_op', 'vip'],
      );
    });

    test('rejects a wrong or missing schemaVersion', () {
      expect(
        () => decodeGlossTablistDoc('{"schemaVersion": 2, "header": "x"}'),
        throwsA(isA<HuiFormatException>()),
      );
      expect(
        () => decodeGlossTablistDoc('{"useHeaderFooter": true}'),
        throwsA(isA<HuiFormatException>()),
      );
    });

    test('missing keys carry the Gson defaults', () {
      final GlossTablistDoc doc = decodeGlossTablistDoc(
        '{"schemaVersion": 1, "revision": 1}',
      );
      expect(doc.useHeaderFooter, isFalse);
      expect(doc.header, isEmpty);
      expect(doc.groupListNames, isFalse);
      expect(doc.nameFormats, isEmpty);
    });
  });

  group('copyFormats normalization is derived, never destructive', () {
    test('keys trim, lowercase and drop blanks', () {
      final GlossTablistDoc doc = decodeGlossTablistDoc(_tablist)
        ..nameFormats = <String, String>{
          ' VIP ': 'a',
          '': 'dropped',
          'Default': 'b',
        };
      expect(doc.effectiveNameFormats, <String, String>{
        'vip': 'a',
        'default': 'b',
      });
      expect(doc.nameFormats.keys, contains(' VIP '),
          reason: 'the file keeps what was written');
    });

    test('normalized duplicates: the later value wins', () {
      final GlossTablistDoc doc = GlossTablistDoc(
        nameFormats: <String, String>{'VIP': 'first', 'vip ': 'second'},
      );
      expect(doc.effectiveNameFormats, <String, String>{'vip': 'second'});
    });
  });

  group('glossTablistChooseListName mirrors TablistService', () {
    const Map<String, String> formats = <String, String>{
      'default': r'$player',
      '_op': r'&6$player',
      'vip': r'&6[$group] $player',
    };

    test('an operator takes _op first, whatever their group', () {
      final GlossTablistChoice choice = glossTablistChooseListName(
        true,
        'vip',
        formats,
      );
      expect(choice.template, r'&6$player');
      expect(choice.groupName, '_op');
    });

    test('a matching primary group takes its own entry', () {
      final GlossTablistChoice choice = glossTablistChooseListName(
        false,
        'vip',
        formats,
      );
      expect(choice.template, r'&6[$group] $player');
      expect(choice.groupName, 'vip');
    });

    test('a mixed-case Vault group matches its lowercased format key', () {
      final GlossTablistChoice choice = glossTablistChooseListName(
        false,
        'VIP',
        formats,
      );
      expect(choice.template, r'&6[$group] $player');
      expect(choice.groupName, 'VIP');
    });

    test('default catches unlisted groups, keeping the group name', () {
      final GlossTablistChoice choice = glossTablistChooseListName(
        false,
        'builder',
        formats,
      );
      expect(choice.template, r'$player');
      expect(choice.groupName, 'builder');
    });

    test('a blank group skips the group step', () {
      final GlossTablistChoice choice = glossTablistChooseListName(
        false,
        '  ',
        formats,
      );
      expect(choice.template, r'$player');
      expect(choice.groupName, '  ');
    });

    test('no default at all falls to the literal fallback', () {
      final GlossTablistChoice choice = glossTablistChooseListName(
        false,
        'builder',
        const <String, String>{'vip': 'x'},
      );
      expect(choice.template, r'$player');
      expect(choice.groupName, 'builder');
    });

    test('an op without an _op entry falls through the normal order', () {
      final GlossTablistChoice choice = glossTablistChooseListName(
        true,
        'vip',
        const <String, String>{'vip': 'v', 'default': 'd'},
      );
      expect(choice.template, 'v');
      expect(choice.groupName, 'vip');
    });
  });

  test('glossTablistSubstituteTokens replaces both tokens, nulls as empty',
      () {
    expect(
      glossTablistSubstituteTokens(r'&6[$group] $player', 'Alex', 'vip'),
      '&6[vip] Alex',
    );
    expect(glossTablistSubstituteTokens(r'$player', null, null), '');
    expect(
      glossTablistSubstituteTokens(r'$player $player', 'A', ''),
      'A A',
    );
  });

  group('round-trip', () {
    test('decode-encode is stable and matches the source tree', () {
      final GlossTablistDoc doc = decodeGlossTablistDoc(_tablist);
      final String encoded = encodeGlossTablistDoc(doc);
      expect(encodeGlossTablistDoc(decodeGlossTablistDoc(encoded)), encoded);
      expect(jsonDecode(encoded), jsonDecode(_tablist));
    });

    test('unknown keys survive after the known ones', () {
      final GlossTablistDoc doc = decodeGlossTablistDoc(
        '{"schemaVersion": 1, "revision": 1, "useHeaderFooter": true, '
        '"header": "h", "footer": "f", "sortMode": "alphabetical"}',
      );
      doc.header = 'edited';
      final Map<String, dynamic> out =
          jsonDecode(encodeGlossTablistDoc(doc)) as Map<String, dynamic>;
      expect(out['sortMode'], 'alphabetical');
      expect(out['header'], 'edited');
    });
  });

  group('shape check', () {
    test('claims tablist documents and nothing else', () {
      expect(looksLikeTablistDoc(jsonDecode(_tablist)), isTrue);
      expect(
        looksLikeTablistDoc(<String, Object?>{
          'schemaVersion': 1,
          'frames': <String>['a'],
          'nameFormats': <String, String>{},
        }),
        isFalse,
        reason: 'frames marks an animation',
      );
      expect(
        looksLikeTablistDoc(<String, Object?>{
          'useHeaderFooter': true,
        }),
        isFalse,
      );
      // The other Gloss kinds must not claim a tablist document either.
      expect(looksLikeMotdDoc(jsonDecode(_tablist)), isFalse);
      expect(looksLikeEmojiDoc(jsonDecode(_tablist)), isFalse);
      expect(looksLikeBubbleStyleDoc(jsonDecode(_tablist)), isFalse);
      expect(looksLikeScoreboardDoc(jsonDecode(_tablist)), isFalse);
      expect(looksLikeAnimationDoc(jsonDecode(_tablist)), isFalse);
      expect(looksLikeHologramDoc(jsonDecode(_tablist)), isFalse);
    });
  });
}

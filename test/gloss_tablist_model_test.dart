import 'dart:convert';

import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

const String _tablist = r'''
{
  "schemaVersion": 2,
  "revision": 7,
  "headerFooter": {
    "enabled": true,
    "presentation": {"header": "&d&lGloss", "footer": "&7Footer"},
    "variants": [
      {
        "id": "nether",
        "priority": 50,
        "when": "world.environment == 'nether'",
        "presentation": {"header": "&4Nether", "footer": "&7Hot"}
      }
    ]
  },
  "listNames": {
    "enabled": true,
    "presentation": {"format": "&7$player"},
    "variants": [
      {
        "id": "operator",
        "priority": 100,
        "when": "subject.op",
        "presentation": {"format": "&6$player"}
      }
    ]
  }
}
''';

void main() {
  test('decodes both conditional schema 2 sections', () {
    final GlossTablistDoc doc = decodeGlossTablistDoc(_tablist);
    expect(doc.schemaVersion, glossTablistCurrentSchemaVersion);
    expect(doc.headerFooter.enabled, isTrue);
    expect(doc.headerFooter.presentation.header, '&d&lGloss');
    expect(doc.headerFooter.variants.single.id, 'nether');
    expect(doc.listNames.enabled, isTrue);
    expect(doc.listNames.presentation.format, r'&7$player');
    expect(doc.listNames.variants.single.presentation.format, r'&6$player');
  });

  test('rejects unsupported and missing schema versions', () {
    expect(
      () => decodeGlossTablistDoc(
        '{"schemaVersion":1,"useHeaderFooter":true,"header":"x"}',
      ),
      throwsA(isA<HuiFormatException>()),
    );
  });

  test('round-trip is stable and writes only canonical root fields', () {
    final String encoded = encodeGlossTablistDoc(
      decodeGlossTablistDoc(_tablist),
    );
    expect(encodeGlossTablistDoc(decodeGlossTablistDoc(encoded)), encoded);
    final Map<String, dynamic> json =
        jsonDecode(encoded) as Map<String, dynamic>;
    expect(json.keys, <String>[
      'schemaVersion',
      'revision',
      'headerFooter',
      'listNames',
    ]);
    expect(json, isNot(contains('nameFormats')));
  });

  test('copy is deep', () {
    final GlossTablistDoc doc = decodeGlossTablistDoc(_tablist);
    final GlossTablistDoc copied = doc.copy();
    copied.headerFooter.presentation.header = 'changed';
    copied.listNames.variants.single.presentation.format = 'changed';
    expect(doc.headerFooter.presentation.header, '&d&lGloss');
    expect(doc.listNames.variants.single.presentation.format, r'&6$player');
  });

  test('shape routing requires the canonical section fields', () {
    expect(looksLikeTablistDoc(jsonDecode(_tablist)), isTrue);
    expect(
      looksLikeTablistDoc(<String, Object?>{
        'schemaVersion': 2,
        'useHeaderFooter': true,
      }),
      isFalse,
    );
  });
}

import 'package:gloss_editor/logic/channel_validation.dart';
import 'package:gloss_editor/logic/json_schema.dart';
import 'package:gloss_editor/config/gloss_json_schema.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  test(
    'base and variant policy retain every authored limit and unknown field',
    () {
      final GlossChannelDoc doc = decodeGlossChannelDoc('''{
      "schemaVersion":2,"revision":9,"channel":{"name":"global"},"format":"{{ message }}",
      "filtering":{"syntax":"re2","maxInputCharacters":128,"maxOutputCharacters":512,
       "maxPatternCharacters":64,"maxReplacementCharacters":128,"maxFilters":8,"maxMatches":16,
       "maxProgramSize":512,"maxNestingDepth":8,"maxWorkUnits":50000,"budgetMicros":700,
       "onLimit":"keep-completed","custom":"retained"},
      "variants":[{"id":"staff","when":"true","filtering":{"maxMatches":2,"onLimit":"drop"}}]}
    ''');
      final GlossChannelDoc copy = decodeGlossChannelDoc(
        encodeGlossChannelDoc(doc),
      );
      expect(copy.filtering!.toJson(), doc.filtering!.toJson());
      expect(copy.filtering!.extras['custom'], 'retained');
      expect(copy.revision, 9);
      expect(copy.variants.single.filtering!.maxMatches, 2);
      expect(
        copy.variants.single.apply(copy).filtering!.maxInputCharacters,
        4096,
      );
      expect(validateChannelDoc(copy), isEmpty);
      copy.variants.single.filtering = null;
      expect(copy.variants.single.apply(copy).filtering, same(copy.filtering));
    },
  );

  test('invalid authored limits are retained and reported, never clamped', () {
    final GlossChannelDoc doc = GlossChannelDoc(
      filtering: GlossChannelFiltering(
        maxMatches: 0,
        maxOutputCharacters: 999999,
        maxPatternCharacters: 1,
        maxReplacementCharacters: 0,
        syntax: 'java',
        onLimit: 'ignore',
      ),
      filters: <GlossChannelFilter>[
        GlossChannelFilter(match: 'ab', replace: 'c'),
      ],
    );
    final GlossChannelDoc copy = decodeGlossChannelDoc(
      encodeGlossChannelDoc(doc),
    );
    expect(copy.filtering!.maxOutputCharacters, 999999);
    expect(
      validateChannelDoc(copy).map((issue) => issue.path),
      containsAll(<String>[
        r'$.filtering.maxMatches',
        r'$.filtering.maxOutputCharacters',
        r'$.filtering.syntax',
        r'$.filtering.onLimit',
        r'$.filters[0].match',
        r'$.filters[0].replace',
      ]),
    );
  });

  test('new and imported channels require schema 2', () {
    expect(GlossChannelDoc().schemaVersion, 2);
    for (final num version in <num>[1, 2.5, 3]) {
      expect(
        () => decodeGlossChannelDoc(
          '{"schemaVersion":$version,"revision":1,"channel":{"name":"global"},"format":"x"}',
        ),
        throwsA(isA<HuiFormatException>()),
      );
    }
  });

  test('code completion exposes policy on base and variants', () {
    final GlossJsonField policy = glossChannelJsonSchema.fields.firstWhere(
      (field) => field.key == 'filtering',
    );
    final GlossJsonObject shape = policy.node! as GlossJsonObject;
    expect(
      shape.fields.map((field) => field.key).toSet(),
      GlossChannelFiltering().toJson().keys.toSet(),
    );
    final GlossJsonArray variants =
        glossChannelJsonSchema.fields
                .firstWhere((field) => field.key == 'variants')
                .node!
            as GlossJsonArray;
    expect(
      (variants.item! as GlossJsonObject).fields.any(
        (field) => field.key == 'filtering',
      ),
      isTrue,
    );
  });
}

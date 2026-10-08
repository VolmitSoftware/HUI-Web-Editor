import 'package:gloss_editor/logic/preview_doc_validation.dart';
import 'package:gloss_editor/model/preview_doc.dart';
import 'package:test/test.dart';

void main() {
  test('preview cadence edits preserve the other document fields', () {
    final HuiPreviewDoc source = HuiPreviewDoc.fromJson(<String, Object?>{
      'elements': <Object?>[],
      'contentRefreshTicks': 6,
      'accessCheckTicks': 7,
      'custom': <String, Object?>{'retained': true},
    });
    final HuiPreviewDoc edited = source.copy()..contentRefreshTicks = 12;
    expect(edited.toJson()['contentRefreshTicks'], 12);
    expect(edited.toJson()['accessCheckTicks'], 7);
    expect(edited.toJson()['custom'], <String, Object?>{'retained': true});
    expect(source.contentRefreshTicks, 6);
    expect(parseCheckPreviewDoc(edited), isEmpty);
  });

  test('preview cadence defaults remain omitted and bounds are validated', () {
    final HuiPreviewDoc source = HuiPreviewDoc.fromJson(<String, Object?>{});
    expect(source.toJson().containsKey('contentRefreshTicks'), isFalse);
    expect(source.toJson().containsKey('accessCheckTicks'), isFalse);
    expect(parseCheckPreviewDoc(source), isEmpty);
    source.contentRefreshTicks = 0;
    source.accessCheckTicks = 1201;
    expect(
      parseCheckPreviewDoc(source).map((issue) => issue.path),
      containsAll(<String>[r'$.contentRefreshTicks', r'$.accessCheckTicks']),
    );
    for (final Object invalid in <Object>[1.5, '4', true, <Object>[]]) {
      expect(
        () => HuiPreviewDoc.fromJson(<String, Object?>{
          'contentRefreshTicks': invalid,
        }),
        throwsFormatException,
      );
    }
  });
}

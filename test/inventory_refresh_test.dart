import 'package:gloss_editor/config/gloss_json_schema.dart';
import 'package:gloss_editor/logic/display_lane_validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  test(
    'inventory refresh survives visual edits and copy with slot actions intact',
    () {
      final GlossInventoryDoc doc = decodeGlossInventoryDoc('''{
      "schemaVersion":1,"revision":8,"resolution":"9x1","mask":["........."],
      "refresh":{"mode":"always","titleTicks":0,"slotsTicks":3,"conditionsTicks":8,"listTicks":40},
      "slots":{"0":{"type":"button","actions":[{"type":"message","message":"{{ entry }}"}]}}
    }''');
      final GlossInventoryDoc copy = cloneGlossInventoryDoc(doc)
        ..title = 'Changed';
      expect(copy.extras['refresh'], doc.extras['refresh']);
      expect(copy.slots, doc.slots);
      expect(copy.revision, 8);
      expect(validateInventoryDoc(copy), isEmpty);
      expect(
        glossJsonSchemaFor('inventory')?.field('refresh')?.node,
        isNotNull,
      );
    },
  );

  test(
    'invalid refresh modes and fractional negative or excessive rates report errors',
    () {
      final GlossInventoryDoc doc = decodeGlossInventoryDoc('''{
      "schemaVersion":1,"revision":1,"resolution":"9x1","mask":["........."],
      "refresh":{"mode":"other","titleTicks":-1,"slotsTicks":0.5,"listTicks":1201}
    }''');
      expect(
        validateInventoryDoc(doc).map((issue) => issue.path),
        containsAll(<String>[
          r'$.refresh.mode',
          r'$.refresh.titleTicks',
          r'$.refresh.slotsTicks',
          r'$.refresh.listTicks',
        ]),
      );
    },
  );
}

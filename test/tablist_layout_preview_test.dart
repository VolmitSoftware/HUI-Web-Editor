import 'package:gloss_editor/logic/tablist_layout_preview.dart';
import 'package:gloss_editor/logic/tablist_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  test(
    'typed player settings preserve static cells and unknown nested values',
    () {
      final GlossTablistDoc doc = decodeGlossTablistDoc(
        '''{"schemaVersion":2,"revision":1,"headerFooter":{"presentation":{}},"listNames":{"presentation":{}},"layout":{"enabled":true,"columns":2,"rows":3,"slots":[{"column":0,"row":1,"text":"Welcome","skin":"Example","ping":85,"custom":"retain"}],"players":{"column":1,"columns":1,"rows":3,"overflow":"count","overflowFormat":"and {count} more","extra":7},"custom":true}}''',
      );
      doc.layout!.players!.overflowFormat = 'More: {count}';
      final GlossTablistDoc copy = decodeGlossTablistDoc(
        encodeGlossTablistDoc(doc),
      );
      expect(copy.layout!.players!.overflowFormat, 'More: {count}');
      expect(copy.layout!.players!.extras['extra'], 7);
      expect(copy.layout!.slots.single['skin'], 'Example');
      expect(copy.layout!.slots.single['custom'], 'retain');
      expect(copy.layout!.extras['custom'], true);
      expect(
        validateTablistDoc(
          copy,
        ).where((HuiIssue issue) => issue.path.startsWith(r'$.layout')),
        isEmpty,
      );
    },
  );
  test('overflow reserves its last cell and counts every omitted player', () {
    final GlossTabLayout layout = GlossTabLayout(
      enabled: true,
      rows: 3,
      players: GlossTabPlayers(
        rows: 3,
        overflow: 'count',
        overflowFormat: 'More: {count}',
      ),
    );
    final List<GlossTabPreviewCell> players = <GlossTabPreviewCell>[
      for (int index = 0; index < 5; index++)
        GlossTabPreviewCell('Player $index', index),
    ];
    expect(
      glossTabLayoutCells(
        layout,
        players,
      ).map((GlossTabPreviewCell cell) => cell.text),
      <String>['Player 0', 'Player 1', 'More: 3'],
    );
    layout.players!.overflow = 'hide';
    expect(
      glossTabLayoutCells(
        layout,
        players,
      ).map((GlossTabPreviewCell cell) => cell.text),
      <String>['Player 0', 'Player 1', 'Player 2'],
    );
    expect(
      GlossTabPlayers.fromJson(<String, Object?>{}).overflowFormat,
      '+{count}',
    );
  });
  test(
    'static cells remain outside player columns and empty formats stay blank',
    () {
      final GlossTabLayout layout = GlossTabLayout(
        enabled: true,
        columns: 2,
        rows: 1,
        slots: <Map<String, Object?>>[
          <String, Object?>{'column': 0, 'row': 0, 'text': 'Title'},
        ],
        players: GlossTabPlayers(
          column: 1,
          rows: 1,
          overflow: 'count',
          overflowFormat: '',
        ),
      );
      expect(
        glossTabLayoutCells(layout, const <GlossTabPreviewCell>[
          GlossTabPreviewCell('A', 5),
          GlossTabPreviewCell('B', 4),
        ]).map((GlossTabPreviewCell cell) => cell.text),
        <String>['Title', ''],
      );
    },
  );
}

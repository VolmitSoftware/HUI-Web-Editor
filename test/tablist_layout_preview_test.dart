import 'package:gloss_editor/components/scoreboard/scoreboard_selection.dart';
import 'package:gloss_editor/logic/tablist_layout_preview.dart';
import 'package:gloss_editor/logic/tablist_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

GlossConditionContext _scope(String name) => GlossConditionContext(
  variables: <String, Object?>{
    'viewer.name': 'Reader',
    'viewer.bedrock': false,
    'subject.name': name,
  },
);
GlossTabPreviewPlayer _player(String name) => GlossTabPreviewPlayer(
  name: name,
  cell: GlossTabPreviewCell(name, 5),
  scope: _scope(name),
);

void main() {
  test(
    'schema3 preserves all nested authored settings through edit and clone',
    () {
      final GlossTablistDoc doc = decodeGlossTablistDoc(
        r'''{"schemaVersion":3,"revision":8,"headerFooter":{"presentation":{}},"listNames":{"presentation":{}},"layout":{"enabled":true,"entries":40,"slots":[{"column":0,"row":1,"text":"Welcome","skin":"brand","ping":85,"hat":false,"custom":"retain"}],"sections":[{"id":"members","column":1,"row":2,"columns":1,"rows":18,"overflow":"count","overflowFormat":"and {count} more","format":"$player","includeNpcs":true,"skin":"brand","hat":false,"sort":[{"expression":"subject.name","type":"text","direction":"descending","extra":7}],"extra":7}],"skins":{"brand":{"value":"texture","signature":"signature","other":9}},"variants":[{"id":"special","priority":5,"when":"false","presentation":{"entries":1,"slots":[{"column":0,"row":0,"text":"Alternate"}]}}],"custom":true}}''',
      );
      doc.layout!.sections.single.overflowFormat = 'More: {count}';
      final GlossTablistDoc copy = decodeGlossTablistDoc(
        encodeGlossTablistDoc(doc),
      );
      expect(copy.revision, 8);
      expect(copy.layout!.entries, 40);
      expect(copy.layout!.sections.single.overflowFormat, 'More: {count}');
      expect(copy.layout!.sections.single.extras['extra'], 7);
      expect(copy.layout!.sections.single.sort.single.extras['extra'], 7);
      expect(copy.layout!.slots.single.skin, 'brand');
      expect(copy.layout!.slots.single.extras['custom'], 'retain');
      expect(copy.layout!.slots.single.hat, isFalse);
      expect(copy.layout!.skins['brand']!.signature, 'signature');
      expect(copy.layout!.skins['brand']!.extras['other'], 9);
      expect(copy.layout!.variants.single.presentation.entries, 1);
      expect(copy.layout!.extras['custom'], true);
      expect(
        validateTablistDoc(
          copy,
        ).where((HuiIssue issue) => issue.path.startsWith(r'$.layout')),
        isEmpty,
      );
      copy.layout!.sections.single.sort.single.direction = 'ascending';
      expect(doc.layout!.sections.single.sort.single.direction, 'descending');
    },
  );
  test(
    'entry count geometry rejects partial final-column tail and overlaps',
    () {
      final GlossTabLayout layout = GlossTabLayout(
        enabled: true,
        entries: 21,
        slots: <GlossTabSlot>[GlossTabSlot(column: 1, row: 10)],
      );
      expect(layout.columns, 2);
      expect(layout.rows, 11);
      expect(
        validateTablistDoc(
          GlossTablistDoc(layout: layout),
        ).any((HuiIssue issue) => issue.path == r'$.layout.slots[0]'),
        isTrue,
      );
      layout.slots = <GlossTabSlot>[GlossTabSlot()];
      layout.sections = <GlossTabSection>[GlossTabSection(rows: 1)];
      expect(
        validateTablistDoc(
          GlossTablistDoc(layout: layout),
        ).any((HuiIssue issue) => issue.message.contains('overlap')),
        isTrue,
      );
      expect(
        () => GlossTabLayout.fromJson(<String, Object?>{'entries': 21.5}),
        throwsFormatException,
      );
    },
  );
  test(
    'overflow reserves the final section cell and counts every omitted player',
    () {
      final GlossTabLayout layout = GlossTabLayout(
        enabled: true,
        entries: 3,
        sections: <GlossTabSection>[
          GlossTabSection(
            rows: 3,
            overflow: 'count',
            overflowFormat: 'More: {count}',
          ),
        ],
      );
      final List<GlossTabPreviewPlayer> players = <GlossTabPreviewPlayer>[
        for (int index = 0; index < 5; index++) _player('Player $index'),
      ];
      expect(
        glossTabLayoutCells(
          layout,
          players,
        ).map((GlossTabPreviewCell cell) => cell.text),
        <String>['Player 0', 'Player 1', 'More: 3'],
      );
      layout.sections.single.overflow = 'hide';
      expect(
        glossTabLayoutCells(
          layout,
          players,
        ).map((GlossTabPreviewCell cell) => cell.text),
        <String>['Player 0', 'Player 1', 'Player 2'],
      );
    },
  );
  test(
    'independent sections filter sort and format with their own row origins',
    () {
      final GlossTabLayout layout = GlossTabLayout(
        enabled: true,
        entries: 6,
        slots: <GlossTabSlot>[GlossTabSlot(text: '{{ viewer.name }}')],
        sections: <GlossTabSection>[
          GlossTabSection(
            id: 'ascending',
            row: 1,
            rows: 2,
            sort: <GlossTabSortKey>[
              GlossTabSortKey(expression: '1', type: 'number'),
              GlossTabSortKey(),
            ],
          ),
          GlossTabSection(
            id: 'descending',
            row: 4,
            rows: 2,
            format: r'<$player>',
            sort: <GlossTabSortKey>[GlossTabSortKey(direction: 'descending')],
          ),
        ],
      );
      expect(
        glossTabLayoutCells(
          layout,
          <GlossTabPreviewPlayer>[_player('B'), _player('A')],
          viewerScope: _scope('Reader'),
        ).map((GlossTabPreviewCell cell) => cell.text),
        <String>['Reader', 'A', 'B', '', '<B>', '<A>'],
      );
    },
  );
  test(
    'variants choose priority then id and replace the complete presentation',
    () {
      final GlossTabLayout layout = GlossTabLayout(
        enabled: true,
        variants: <GlossTabLayoutVariant>[
          GlossTabLayoutVariant(
            id: 'z',
            priority: 4,
            when: 'true',
            presentation: GlossTabPresentation(entries: 2),
          ),
          GlossTabLayoutVariant(
            id: 'a',
            priority: 4,
            when: 'true',
            presentation: GlossTabPresentation(entries: 1),
          ),
        ],
      );
      expect(glossResolveTabLayout(layout, _scope('Reader'))!.entries, 1);
    },
  );
  test('document visibility gates conditional layouts', () {
    final GlossTabLayout layout = GlossTabLayout(enabled: true);
    expect(
      glossResolveTabLayout(layout, _scope('Reader'), documentShow: false),
      isNull,
    );
    expect(
      glossResolveTabLayout(
        layout,
        _scope('Reader'),
        documentShow: 'viewer.name == "Reader"',
      ),
      same(layout),
    );
  });
  test(
    'layout identifiers match runtime normalization and character rules',
    () {
      final GlossTablistDoc doc = GlossTablistDoc.fromJson(<String, Object?>{
        'schemaVersion': 3,
        'revision': 1,
        'headerFooter': <String, Object?>{
          'enabled': true,
          'presentation': <String, Object?>{},
        },
        'listNames': <String, Object?>{
          'enabled': true,
          'presentation': <String, Object?>{},
        },
        'layout': <String, Object?>{
          'enabled': true,
          'entries': 20,
          'variants': <Object?>[
            <String, Object?>{
              'id': 'event',
              'when': 'true',
              'presentation': <String, Object?>{'entries': 20},
            },
            <String, Object?>{
              'id': ' event ',
              'when': 'true',
              'presentation': <String, Object?>{'entries': 20},
            },
          ],
          'skins': <String, Object?>{
            'invalid name': <String, Object?>{'value': 'texture'},
          },
        },
      });
      expect(
        validateTablistDoc(doc)
            .where((HuiIssue issue) => issue.severity == HuiSeverity.error)
            .map((HuiIssue issue) => issue.path),
        containsAll(<String>[r'$.layout.variants[1].id', r'$.layout.skins']),
      );
    },
  );
}

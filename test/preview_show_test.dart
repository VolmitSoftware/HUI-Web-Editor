import 'package:gloss_editor/logic/preview_card_edit.dart';
import 'package:gloss_editor/logic/preview_card_scene.dart';
import 'package:gloss_editor/logic/preview_doc_validation.dart';
import 'package:gloss_editor/logic/preview_sim.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/preview_doc.dart';
import 'package:test/test.dart';

void main() {
  test('document visibility follows the target world and clock', () {
    final HuiPreviewDoc doc = HuiPreviewDoc(
      show: "{{ world.name == 'world' && world.time < 1300 }}",
      elements: <HuiPreviewElement>[
        HuiPreviewElement('cell', size: 8, color: '#FF00FF00'),
      ],
    );
    final PreviewSim sim = PreviewSim('chest');
    expect(buildCardScene(doc, sim).items, hasLength(1));
    expect(parseCheckPreviewDoc(doc), isEmpty);
    expect(previewDocIsAnimated(doc), isTrue);
    sim.tick(100);
    expect(buildCardScene(doc, sim).items, isEmpty);
    sim.reset();
    expect(buildCardScene(doc, sim).items, hasLength(1));
    sim.worldName = 'other';
    expect(buildCardScene(doc, sim).items, isEmpty);
  });

  test('card visibility hides its chrome while keeping its content', () {
    final HuiPreviewDoc doc = HuiPreviewDoc(
      card: HuiPreviewCard(show: '{{ world.time < 1300 }}'),
      elements: <HuiPreviewElement>[
        HuiPreviewElement('cell', size: 8, color: '#FF00FF00'),
      ],
    );
    final PreviewSim sim = PreviewSim('chest');
    expect(buildCardScene(doc, sim).items.whereType<CardPanel>(), isNotEmpty);
    expect(previewDocIsAnimated(doc), isTrue);
    sim.tick(100);
    expect(buildCardScene(doc, sim).items, hasLength(1));
    expect(buildCardScene(doc, sim).items.single, isA<CardCell>());
    doc.card!.show = true;
    doc.card!.framed = false;
    expect(buildCardScene(doc, sim).items, hasLength(1));
  });

  test('element visibility combines both predicates within each repeat', () {
    final HuiPreviewDoc doc = HuiPreviewDoc(
      elements: <HuiPreviewElement>[
        HuiPreviewElement(
          'cell',
          show: '{{ i < 3 && world.time < 1300 }}',
          visible: 'i > 0',
          repeat: HuiPreviewRepeat(count: 4),
          x: 'i * 10',
          size: 8,
          color: '#FF00FF00',
        ),
      ],
    );
    final PreviewSim sim = PreviewSim('chest');
    expect(buildCardScene(doc, sim).items.map((CardItem item) => item.x), <int>[
      10,
      20,
    ]);
    expect(parseCheckPreviewDoc(doc), isEmpty);
    expect(previewDocIsAnimated(doc), isTrue);
    sim.tick(100);
    expect(buildCardScene(doc, sim).items, isEmpty);
  });

  test('show conditions survive editing and copying at every scope', () {
    final HuiPreviewDoc doc = decodeHuiPreviewDoc('''
      {
        "show": true,
        "card": {"show": false},
        "elements": [
          {"type": "cell", "show": "world.time < 1300", "size": 8, "color": "#FF00FF00"}
        ]
      }
    ''');
    for (final HuiPreviewDoc copy in <HuiPreviewDoc>[
      doc.copy(),
      cloneHuiPreviewDoc(doc),
      decodeHuiPreviewDoc(encodeHuiPreviewDoc(doc)),
    ]) {
      expect(copy.toJson(), doc.toJson());
      expect(copy.show, isTrue);
      expect(copy.card!.show, isFalse);
      expect(copy.elements.single.show, 'world.time < 1300');
    }
  });

  test('malformed show expressions report their scope', () {
    final HuiPreviewDoc doc = HuiPreviewDoc(
      show: '{{ 1 + }}',
      card: HuiPreviewCard(show: '{{ 2 + }}'),
      elements: <HuiPreviewElement>[
        HuiPreviewElement('cell', show: '{{ 3 + }}', size: 8, color: 0),
      ],
    );
    expect(
      parseCheckPreviewDoc(doc).map((HuiIssue issue) => issue.path),
      <String>['show', 'card.show', 'elements[0].show'],
    );
    final List<String> errors = <String>[];
    expect(
      buildCardScene(doc, PreviewSim('chest'), onError: errors.add).items,
      isEmpty,
    );
    expect(errors, hasLength(1));
    expect(errors.single, contains('show'));
  });

  test(
    'show rejects invalid primitives and non-boolean constant expressions',
    () {
      for (final Object invalid in <Object>[
        42,
        <Object>[],
        <String, Object>{},
        '1 + 2',
        "'yes'",
      ]) {
        final HuiPreviewDoc doc = HuiPreviewDoc(
          show: invalid,
          card: HuiPreviewCard(show: invalid),
          elements: <HuiPreviewElement>[
            HuiPreviewElement('cell', show: invalid, size: 8, color: 0),
          ],
        );
        expect(
          validatePreviewDoc(doc)
              .where((HuiIssue issue) => issue.severity == HuiSeverity.error)
              .map((HuiIssue issue) => issue.path),
          containsAll(<String>['show', 'card.show', 'elements[0].show']),
          reason: invalid.toString(),
        );
      }
    },
  );
}

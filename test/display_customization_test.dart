import 'package:gloss_editor/logic/mc_text.dart';
import 'package:gloss_editor/logic/preview_card_edit.dart';
import 'package:gloss_editor/logic/preview_card_scene.dart';
import 'package:gloss_editor/logic/preview_doc_validation.dart';
import 'package:gloss_editor/logic/preview_sim.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/gloss_hologram_box.dart';
import 'package:gloss_editor/model/hui_icons.dart';
import 'package:gloss_editor/model/preview_doc.dart';
import 'package:test/test.dart';

void main() {
  test('text icon boxes survive parsing, edits and deep copies', () {
    final HuiTextIcon icon = HuiTextIcon('Menu title')
      ..box = GlossHologramBox(enabled: true, padding: 9, borderWidth: 2);
    final HuiTextIcon parsed = HuiIcon.fromJson(icon.toJson()) as HuiTextIcon;
    expect(parsed.box!.toJson(), icon.box!.toJson());
    final HuiTextIcon copy = parsed.copy();
    copy.box!.padding = 20;
    copy.text = 'Edited';
    expect(parsed.box!.padding, 9);
    expect(parsed.text, 'Menu title');
  });

  test('preview root styles and element overrides round trip and resolve', () {
    final HuiPreviewDoc doc = HuiPreviewDoc(
      textStyle: HuiIconStyle(scaleX: 2, backgroundArgb: '#AA123456'),
      itemStyle: HuiIconStyle(scaleX: 0.8, blockLight: 12, skyLight: 8),
      elements: <HuiPreviewElement>[
        HuiPreviewElement(
          'label',
          text: "'Inherited'",
          box: GlossHologramBox(enabled: true),
        ),
        HuiPreviewElement(
          'label',
          y: 20,
          text: "'Override'",
          style: HuiIconStyle(scaleX: 3, backgroundArgb: '#99112233'),
        ),
        HuiPreviewElement('slot', y: -20, size: 18, index: 0),
        HuiPreviewElement(
          'label',
          y: 40,
          text: "'Explicit background'",
          background: '#FF123456',
        ),
      ],
    );
    final HuiPreviewDoc roundTrip = HuiPreviewDoc.fromJson(doc.toJson());
    expect(roundTrip.toJson(), doc.toJson());
    final PreviewCardScene scene = buildCardScene(
      roundTrip,
      PreviewSim('chest'),
    );
    final CardLabel inherited = scene.items[0] as CardLabel;
    final CardLabel override = scene.items[1] as CardLabel;
    final CardSlot slot = scene.items[2] as CardSlot;
    expect(inherited.style!.scaleX, 2);
    expect(inherited.background, 0xAA123456);
    expect(inherited.box!.enabled, isTrue);
    expect(override.style!.scaleX, 3);
    expect(override.background, 0x99112233);
    expect(slot.style!.blockLight, 12);
    expect(slot.wellStyle!.scaleX, 2);
    expect((scene.items[3] as CardLabel).background, 0xFF123456);
    final HuiPreviewDoc copy = doc.copy();
    copy.elements.first.box!.padding = 19;
    copy.textStyle!.scaleX = 5;
    expect(doc.elements.first.box!.padding, 4);
    expect(doc.textStyle!.scaleX, 2);
  });

  test('card spacing and ARGB colors determine the rendered chrome', () {
    final HuiPreviewDoc doc = HuiPreviewDoc(
      card: HuiPreviewCard(
        framed: true,
        title: "'Title'",
        minHalfWidth: 0,
        padding: 13,
        borderWidth: 5,
        trayPadding: 2,
        titleHeight: 22,
        titleGap: 8,
        backgroundArgb: '#A0112233',
        trayArgb: '#B0445566',
        borderArgb: '#C0778899',
        titleArgb: '#D0AABBCC',
      ),
      elements: <HuiPreviewElement>[
        HuiPreviewElement('cell', x: 10, size: 18, color: '#FFABCDEF'),
      ],
    );
    final HuiPreviewDoc parsed = HuiPreviewDoc.fromJson(doc.toJson());
    expect(parsed.card!.toJson(), doc.card!.toJson());
    final PreviewCardScene scene = buildCardScene(parsed, PreviewSim('chest'));
    final List<CardPanel> panels = scene.items.whereType<CardPanel>().toList();
    expect(panels.map((CardPanel panel) => panel.color), <int>[
      0xC0778899,
      0xA0112233,
      0xB0445566,
      0xD0AABBCC,
    ]);
    expect(panels.first.width, 54);
    expect(panels.first.height, 71);
    expect(panels[1].width, 44);
    expect(panels[1].height, 61);
    expect(panels[2].width, 22);
    expect(panels.last.height, 22);
  });

  test('scaled labels include boxes in selection bounds', () {
    final HuiPreviewDoc doc = HuiPreviewDoc(
      elements: <HuiPreviewElement>[
        HuiPreviewElement(
          'label',
          text: "'Text'",
          style: HuiIconStyle(scaleX: 2, scaleY: 0.5),
          box: GlossHologramBox(enabled: true, padding: 8, borderWidth: 2),
        ),
      ],
    );
    final CardItem label = buildCardScene(
      doc,
      PreviewSim('chest'),
    ).items.single;
    final PreviewBox bounds = previewItemBox(label);
    expect(bounds.width, 88);
    expect(bounds.height, 16);
  });

  test(
    'labels retain explicit lines and wrap styled words at native width',
    () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement(
            'label',
            text: "'&cRed green\\n&lBold'",
            style: HuiIconStyle(lineWidth: 30),
          ),
        ],
      );
      final CardLabel label =
          buildCardScene(doc, PreviewSim('chest')).items.single as CardLabel;
      final List<List<McSpan>> lines = previewLabelLines(label);
      expect(
        lines.map(
          (List<McSpan> line) => line.map((McSpan span) => span.text).join(),
        ),
        <String>['Red', 'green', 'Bold'],
      );
      expect(
        lines.first.every((McSpan span) => span.color == 0xFF5555),
        isTrue,
      );
      expect(lines.last.every((McSpan span) => span.bold), isTrue);
      expect(previewLabelWidth(label), 30);
      expect(previewItemBox(label).height, 36);
    },
  );

  test(
    'current fields reject invalid styles and card values at their paths',
    () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        textStyle: HuiIconStyle(textOpacity: -1),
        card: HuiPreviewCard(padding: 257, borderArgb: '#bad'),
        elements: <HuiPreviewElement>[
          HuiPreviewElement(
            'label',
            text: "'Text'",
            style: HuiIconStyle(scaleX: -1),
            box: GlossHologramBox(borderArgb: '#bad'),
          ),
        ],
      );
      final List<HuiIssue> issues = validatePreviewDoc(doc);
      expect(
        issues
            .where((HuiIssue issue) => issue.severity == HuiSeverity.error)
            .map((HuiIssue issue) => issue.path),
        containsAll(<String>[
          'textStyle.textOpacity',
          'card.padding',
          'card.borderArgb',
          'elements[0].style.scaleX',
          'elements[0].box.borderArgb',
        ]),
      );
    },
  );
}

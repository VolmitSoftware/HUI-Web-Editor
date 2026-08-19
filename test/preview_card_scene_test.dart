import 'dart:convert';
import 'dart:io';

import 'package:gloss_editor/logic/mc_text.dart';
import 'package:gloss_editor/logic/preview_card_scene.dart';
import 'package:gloss_editor/logic/preview_sim.dart';
import 'package:gloss_editor/logic/preview_variant_resolver.dart';
import 'package:gloss_editor/model/preview_doc.dart';
import 'package:test/test.dart';

/// The cross-repo regression gate, ported from the plugin's own
/// `GoldenEquivalenceTest`.
///
/// `test/fixtures/previews/*.json` are the SHIPPED documents copied byte for
/// byte out of `HoloUi/src/main/resources/previews`, and
/// `test/fixtures/golden/*.json` are the plugin's own captured snapshots out of
/// `HoloUi/src/test/resources/golden`. Each scenario parses the shipped
/// document, resolves the variant variables the way `PreviewDocumentRegistry`
/// does, builds against a [PreviewSim] configured exactly like the `GoldenFakes`
/// state the snapshot was captured from, and compares the result field for
/// field. A layout change in either repo fails here.
///
/// ## Comparison boundaries
///
/// EXACT (integer equality, no tolerance):
///   * every element's `type`, `x`, `y`, `z`, and the element order itself
///   * panel `width`/`height`/`color`
///   * cell `size`/`color` (the evaluated colour, not the expression)
///   * slot `size`/`wellColor`/`index`
///   * label `background`
///
/// Colours are compared as unsigned 32-bit ARGB ints. The golden writes them as
/// `"#AARRGGBB"` (`GoldenSerializer.color`), so the fixture side is parsed with
/// [_parseArgb]; nothing is masked or widened.
///
/// NORMALIZED (label text only): the golden stores a Gson-serialized Adventure
/// `Component` tree, while the editor's [parseMcText] produces flat styled runs.
/// The two are compared through [_flattenComponent], which walks the component
/// depth-first and emits one run per node that carries text, inheriting
/// `color`/`bold`/`italic`/`underlined`/`strikethrough`/`obfuscated` from its
/// ancestors. That is exactly the render-time inheritance Adventure applies, so
/// the normalization loses nothing a viewer would see; what it drops is only the
/// tree SHAPE (which node owned which style) — an encoding detail the plugin
/// itself erases with `Component.compact()` before serializing. Named colours
/// (`"white"`, `"dark_gray"`) resolve through [mcNamedColor]; a node with no
/// colour anywhere up its ancestry defaults to [mcDefaultTextColor], matching
/// the editor parser's own default. Nodes with empty text are dropped on both
/// sides (an empty run draws nothing).
void main() {
  group('golden parity', () {
    for (final _Scenario scenario in _scenarios) {
      test(
        '${scenario.golden} is reproduced by previews/${scenario.document}',
        () {
          final List<String> errors = <String>[];
          final PreviewCardScene scene = _buildScenario(scenario, errors);
          expect(
            errors,
            isEmpty,
            reason: 'the shipped document must build without errors',
          );

          final List<Map<String, Object?>> actual = _normalizeScene(scene);
          final List<Map<String, Object?>> expected = _normalizeGolden(
            _readGolden(scenario.golden),
          );

          if (!_deepEquals(actual, expected)) {
            fail(
              '${scenario.golden} is not reproduced by '
              'previews/${scenario.document}.json'
              '\nfirst difference ${_firstDifference(expected, actual)}'
              '\n--- golden ---\n${_pretty(expected)}'
              '\n--- document ---\n${_pretty(actual)}',
            );
          }
        },
      );
    }

    test('chest_27 carries the full 9x3 grid plus the card chrome', () {
      final PreviewCardScene scene = _buildScenario(_scenarios[0], <String>[]);
      expect(scene.items.whereType<CardSlot>().length, 27);
      expect(scene.items.whereType<CardPanel>().length, 4);
      expect(scene.items.whereType<CardLabel>().length, 1);
      expect(scene.items.length, 32);
    });

    test('furnace_smelting keeps only the furnace-style cells', () {
      final PreviewCardScene scene = _buildScenario(_scenarios[1], <String>[]);
      // 8 progress segments plus one flame; the blast vents and smoker wisps
      // are `visible: false` for this style.
      expect(scene.items.whereType<CardCell>().length, 9);
      expect(scene.items.whereType<CardSlot>().length, 3);
      // Two state labels plus the card title.
      expect(scene.items.whereType<CardLabel>().length, 3);
      expect(scene.items.whereType<CardPanel>().length, 4);
      expect(scene.items.length, 19);
    });

    test('locked draws no chrome at all', () {
      final PreviewCardScene scene = _buildScenario(_scenarios[2], <String>[]);
      expect(scene.items.whereType<CardPanel>(), isEmpty);
      expect(scene.items.whereType<CardLabel>(), isEmpty);
      expect(scene.items.length, 4);
    });
  });

  group('scene extent', () {
    test('measures the way CardFramer measures content', () {
      // The locked document is four bare cells: x -12..12, y -16..18.
      final PreviewCardScene scene = _buildScenario(_scenarios[2], <String>[]);
      expect(scene.widthPx, 24);
      expect(scene.heightPx, 34);
    });

    test('an empty document has no extent', () {
      final PreviewCardScene scene = buildCardScene(
        HuiPreviewDoc(),
        PreviewSim('statics'),
      );
      expect(scene.items, isEmpty);
      expect(scene.widthPx, 0);
      expect(scene.heightPx, 0);
    });
  });

  group('card chrome', () {
    test('a card with no content falls back to the well-height default', () {
      // CardFramer's `contentTop == Integer.MIN_VALUE` branch: half a well up
      // and down, so the panel is 17 + 6 + 9 tall over 9 + 7 below.
      final PreviewCardScene scene = _framed(<HuiPreviewElement>[]);
      final List<CardPanel> panels = scene.items
          .whereType<CardPanel>()
          .toList();
      expect(panels.length, 3, reason: 'frame, panel, title bar; no tray');
      expect(
        panels[1].width,
        164,
        reason: 'the 82 minimum half width, doubled',
      );
      expect(panels[1].height, 48);
      expect(panels[1].color, 0xF21B1B22);
      expect(panels[0].color, 0xCCCBD0D9, reason: 'the default accent at CC');
      expect(panels[2].color, 0xE6CBD0D9);
    });

    test('a tray appears only once a cell or slot is present', () {
      final PreviewCardScene bare = _framed(<HuiPreviewElement>[
        HuiPreviewElement('label', x: 0, y: 0, text: "'hi'"),
      ]);
      expect(bare.items.whereType<CardPanel>().length, 3);

      final PreviewCardScene withCell = _framed(<HuiPreviewElement>[
        HuiPreviewElement('cell', x: 0, y: 0, size: 8, color: '#FF00FF00'),
      ]);
      final List<CardPanel> panels = withCell.items
          .whereType<CardPanel>()
          .toList();
      expect(panels.length, 4);
      expect(panels[2].color, 0xFF33333E, reason: 'the tray');
      expect(panels[2].width, 18 + 4 * 2, reason: 'one well plus tray padding');
      expect(panels[2].height, 18 + 4 * 2);
    });

    test('chrome sits under the content in emission order', () {
      final PreviewCardScene scene = _framed(<HuiPreviewElement>[
        HuiPreviewElement('cell', x: 0, y: 0, size: 8, color: '#FF00FF00'),
      ]);
      expect(scene.items.map((CardItem i) => i.z).toList(), <int>[
        0,
        1,
        2,
        3,
        6,
        4,
      ]);
    });

    test('an unframed card emits bare content', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        card: HuiPreviewCard(framed: false, title: "'x'"),
        elements: <HuiPreviewElement>[
          HuiPreviewElement('cell', x: 0, y: 0, size: 8, color: '#FF00FF00'),
        ],
      );
      final PreviewCardScene scene = buildCardScene(doc, PreviewSim('statics'));
      expect(scene.items.length, 1);
      expect(scene.items.single, isA<CardCell>());
    });

    test('a document with no card object is never framed', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement('cell', x: 0, y: 0, size: 8, color: '#FF00FF00'),
        ],
      );
      expect(buildCardScene(doc, PreviewSim('statics')).items.length, 1);
    });

    test('a failed accent falls back to the neutral default', () {
      final List<String> errors = <String>[];
      final HuiPreviewDoc doc = HuiPreviewDoc(
        card: HuiPreviewCard(accent: 'nope'),
        elements: <HuiPreviewElement>[],
      );
      final PreviewCardScene scene = buildCardScene(
        doc,
        PreviewSim('statics'),
        onError: errors.add,
      );
      expect(scene.items.whereType<CardPanel>().first.color, 0xCCCBD0D9);
      expect(errors.single, startsWith('card accent:'));
    });

    test('a failed title renders empty and still frames', () {
      final List<String> errors = <String>[];
      final HuiPreviewDoc doc = HuiPreviewDoc(
        card: HuiPreviewCard(title: 'nope'),
        elements: <HuiPreviewElement>[],
      );
      final PreviewCardScene scene = buildCardScene(
        doc,
        PreviewSim('statics'),
        onError: errors.add,
      );
      expect(scene.items.whereType<CardLabel>().single.text, isEmpty);
      expect(errors.single, startsWith('card title:'));
    });

    test('a failed framed flag drops the chrome', () {
      final List<String> errors = <String>[];
      final HuiPreviewDoc doc = HuiPreviewDoc(
        card: HuiPreviewCard(framed: 'nope'),
        elements: <HuiPreviewElement>[
          HuiPreviewElement('cell', x: 0, y: 0, size: 8, color: '#FF00FF00'),
        ],
      );
      final PreviewCardScene scene = buildCardScene(
        doc,
        PreviewSim('statics'),
        onError: errors.add,
      );
      expect(scene.items.length, 1);
      expect(errors.single, startsWith('card framed:'));
    });
  });

  group('element defaults', () {
    test('z defaults per type', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement('panel', width: 10, height: 10, color: '#FF000000'),
          HuiPreviewElement('cell', size: 8, color: '#FF000000'),
          HuiPreviewElement('label', text: "'x'"),
        ],
      );
      final PreviewCardScene scene = buildCardScene(doc, PreviewSim('statics'));
      expect(scene.items.map((CardItem i) => i.z).toList(), <int>[1, 4, 6]);
    });

    test('a slot defaults its well colour and a label its background', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement('slot', size: 18, index: 0),
          HuiPreviewElement('label', text: "'x'"),
        ],
      );
      final PreviewCardScene scene = buildCardScene(doc, PreviewSim('chest'));
      expect(scene.items.whereType<CardSlot>().single.wellColor, 0xFF15151B);
      expect(scene.items.whereType<CardLabel>().single.background, 0);
    });

    test('x, y and visible default without a key', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement('cell', size: 8, color: '#FF010203'),
        ],
      );
      final CardItem item = buildCardScene(
        doc,
        PreviewSim('statics'),
      ).items.single;
      expect(item.x, 0);
      expect(item.y, 0);
    });

    test('coordinates round the Java way, half up', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement(
            'cell',
            x: 2.5,
            y: -2.5,
            size: 8,
            color: '#FF010203',
          ),
        ],
      );
      final CardItem item = buildCardScene(
        doc,
        PreviewSim('statics'),
      ).items.single;
      expect(item.x, 3);
      expect(item.y, -2, reason: 'Math.round(-2.5) is -2, not -3');
    });
  });

  group('repeat expansion', () {
    test('binds the loop variable per instance', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement(
            'cell',
            x: 'i * 10',
            size: 8,
            color: '#FF000000',
            repeat: HuiPreviewRepeat(count: 4),
          ),
        ],
      );
      final PreviewCardScene scene = buildCardScene(doc, PreviewSim('statics'));
      expect(scene.items.map((CardItem i) => i.x).toList(), <int>[
        0,
        10,
        20,
        30,
      ]);
    });

    test('honours a named loop variable', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement(
            'cell',
            x: 'n * 5',
            size: 8,
            color: '#FF000000',
            repeat: HuiPreviewRepeat(count: 3, varName: 'n'),
          ),
        ],
      );
      final PreviewCardScene scene = buildCardScene(doc, PreviewSim('statics'));
      expect(scene.items.map((CardItem i) => i.x).toList(), <int>[0, 5, 10]);
    });

    test('a count below one emits nothing', () {
      for (final Object count in <Object>[0, 0.9, -5]) {
        final HuiPreviewDoc doc = HuiPreviewDoc(
          elements: <HuiPreviewElement>[
            HuiPreviewElement(
              'cell',
              size: 8,
              color: '#FF000000',
              repeat: HuiPreviewRepeat(count: count),
            ),
          ],
        );
        expect(
          buildCardScene(doc, PreviewSim('statics')).items,
          isEmpty,
          reason: 'count $count',
        );
      }
    });

    test('clamps one repeat at 1024 and reports it', () {
      final List<String> errors = <String>[];
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement(
            'cell',
            size: 8,
            color: '#FF000000',
            repeat: HuiPreviewRepeat(count: 'time * 2'),
          ),
        ],
      );
      final PreviewSim sim = PreviewSim('statics');
      // 1234 * 2 = 2468 attempts asked for, 1024 allowed.
      final PreviewCardScene scene = buildCardScene(
        doc,
        sim,
        onError: errors.add,
      );
      expect(scene.items.length, 1024);
      expect(errors.single, 'repeat count 2468 exceeds 1024, truncated');
    });

    test('the aggregate budget counts attempts, not emitted elements', () {
      final List<String> errors = <String>[];
      // 4096 budget, five repeats of 1000: the first four cost 4000 and the
      // fifth is truncated to the 96 that remain, which leaves nothing for the
      // sixth element. Every instance is invisible, so nothing is emitted at
      // all — the budget still counts every attempt.
      final List<HuiPreviewElement> elements = <HuiPreviewElement>[
        for (int i = 0; i < 5; i++)
          HuiPreviewElement(
            'cell',
            size: 8,
            color: '#FF000000',
            visible: false,
            repeat: HuiPreviewRepeat(count: 1000),
          ),
        HuiPreviewElement('cell', size: 8, color: '#FF000000'),
      ];
      final PreviewCardScene scene = buildCardScene(
        HuiPreviewDoc(elements: elements),
        PreviewSim('statics'),
        onError: errors.add,
      );
      expect(scene.items, isEmpty);
      expect(errors, <String>[
        'repeat of 1000 truncated at the 4096 element cap',
        'element cap 4096 reached, remaining elements skipped',
      ]);
    });

    test('a broken repeat count skips the element', () {
      final List<String> errors = <String>[];
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement(
            'cell',
            size: 8,
            color: '#FF000000',
            repeat: HuiPreviewRepeat(count: 'nope'),
          ),
          HuiPreviewElement('cell', size: 8, color: '#FF000000'),
        ],
      );
      final PreviewCardScene scene = buildCardScene(
        doc,
        PreviewSim('statics'),
        onError: errors.add,
      );
      expect(scene.items.length, 1, reason: 'the rest of the document renders');
      expect(errors.single, startsWith('cell:'));
    });
  });

  group('failure policy', () {
    test('a broken cell colour renders transparent and keeps the cell', () {
      final List<String> errors = <String>[];
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement('cell', x: 3, size: 8, color: 'nope'),
        ],
      );
      final PreviewCardScene scene = buildCardScene(
        doc,
        PreviewSim('statics'),
        onError: errors.add,
      );
      final CardCell cell = scene.items.single as CardCell;
      expect(cell.x, 3);
      expect(cell.color, 0x00000000);
      expect(errors.single, startsWith('cell color:'));
    });

    test('a broken label text renders empty and keeps the label', () {
      final List<String> errors = <String>[];
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement('label', x: 3, text: 'nope'),
        ],
      );
      final PreviewCardScene scene = buildCardScene(
        doc,
        PreviewSim('statics'),
        onError: errors.add,
      );
      final CardLabel label = scene.items.single as CardLabel;
      expect(label.x, 3);
      expect(label.text, isEmpty);
      expect(errors.single, startsWith('label text:'));
    });

    test('a broken structural field skips just that element', () {
      final List<String> errors = <String>[];
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement(
            'panel',
            width: 'nope',
            height: 10,
            color: '#FF000000',
          ),
          HuiPreviewElement('cell', size: 8, color: '#FF000000'),
        ],
      );
      final PreviewCardScene scene = buildCardScene(
        doc,
        PreviewSim('statics'),
        onError: errors.add,
      );
      expect(scene.items.length, 1);
      expect(scene.items.single, isA<CardCell>());
      expect(errors.single, startsWith('panel:'));
    });

    test('a missing required field skips the element', () {
      final List<String> errors = <String>[];
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement('panel', width: 10, color: '#FF000000'),
        ],
      );
      final PreviewCardScene scene = buildCardScene(
        doc,
        PreviewSim('statics'),
        onError: errors.add,
      );
      expect(scene.items, isEmpty);
      expect(errors.single, contains('height'));
    });

    test('an unknown element type is skipped', () {
      final List<String> errors = <String>[];
      final PreviewCardScene scene = buildCardScene(
        HuiPreviewDoc(elements: <HuiPreviewElement>[HuiPreviewElement('blob')]),
        PreviewSim('statics'),
        onError: errors.add,
      );
      expect(scene.items, isEmpty);
      expect(errors.single, contains('blob'));
    });

    test('a slot against a target with no inventory is skipped', () {
      final List<String> errors = <String>[];
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement('slot', size: 18, index: 0),
        ],
      );
      final PreviewCardScene scene = buildCardScene(
        doc,
        PreviewSim('statics'),
        onError: errors.add,
      );
      expect(scene.items, isEmpty);
      expect(errors.single, 'slot: target has no inventory');
    });

    test('an invisible element is not emitted', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement(
            'cell',
            size: 8,
            color: '#FF000000',
            visible: false,
          ),
          HuiPreviewElement(
            'cell',
            size: 8,
            color: '#FF000000',
            visible: '1 > 2',
          ),
          HuiPreviewElement('cell', size: 8, color: '#FF000000'),
        ],
      );
      expect(buildCardScene(doc, PreviewSim('statics')).items.length, 1);
    });

    test('errors reach the sink but never throw without one', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement('cell', size: 'nope', color: '#FF000000'),
        ],
      );
      expect(() => buildCardScene(doc, PreviewSim('statics')), returnsNormally);
    });
  });

  // The model is mutable and `HuiRawExpr` is `Object?`: the JSON decoder only
  // ever stores a num/String/bool, but editor UI code assigns to these fields
  // directly and will eventually put the wrong primitive in one. None of it may
  // reach a `throw` — this pass runs on the per-tick render path.
  group('hostile model input', () {
    test(
      'a non-finite repeat count truncates at the cap instead of throwing',
      () {
        final List<String> errors = <String>[];
        final HuiPreviewDoc doc = HuiPreviewDoc(
          elements: <HuiPreviewElement>[
            HuiPreviewElement(
              'cell',
              size: 8,
              color: '#FF000000',
              repeat: HuiPreviewRepeat(count: double.infinity),
            ),
          ],
        );
        late final PreviewCardScene scene;
        expect(
          () => scene = buildCardScene(
            doc,
            PreviewSim('statics'),
            onError: errors.add,
          ),
          returnsNormally,
        );
        // Java saturates `(long) Math.floor(inf)` at Long.MAX_VALUE and then
        // truncates to the 1024 cap; the port lands on the same outcome.
        expect(scene.items.length, 1024);
        expect(
          errors.single,
          'repeat count 9223372036854775807 exceeds 1024, truncated',
        );
      },
    );

    test('a NaN repeat count emits nothing', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement(
            'cell',
            size: 8,
            color: '#FF000000',
            repeat: HuiPreviewRepeat(count: double.nan),
          ),
        ],
      );
      expect(buildCardScene(doc, PreviewSim('statics')).items, isEmpty);
    });

    test('visible holding a number skips the element instead of throwing', () {
      final List<String> errors = <String>[];
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement('cell', size: 8, color: '#FF000000', visible: 1),
          HuiPreviewElement('cell', size: 8, color: '#FF000000'),
        ],
      );
      late final PreviewCardScene scene;
      expect(
        () => scene = buildCardScene(
          doc,
          PreviewSim('statics'),
          onError: errors.add,
        ),
        returnsNormally,
      );
      expect(scene.items.length, 1, reason: 'the rest of the document renders');
      expect(
        errors.single,
        'cell: visible: must be a boolean or a string expression',
      );
    });

    test('a numeric field holding a bool skips the element', () {
      final List<String> errors = <String>[];
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement(
            'panel',
            width: true,
            height: 10,
            color: '#FF000000',
          ),
        ],
      );
      late final PreviewCardScene scene;
      expect(
        () => scene = buildCardScene(
          doc,
          PreviewSim('statics'),
          onError: errors.add,
        ),
        returnsNormally,
      );
      expect(scene.items, isEmpty);
      expect(
        errors.single,
        'panel: width: must be a number or a string expression',
      );
    });

    test('a cell colour holding a bool renders transparent', () {
      final List<String> errors = <String>[];
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement('cell', size: 8, color: true),
        ],
      );
      final PreviewCardScene scene = buildCardScene(
        doc,
        PreviewSim('statics'),
        onError: errors.add,
      );
      expect((scene.items.single as CardCell).color, previewTransparent);
      expect(errors.single, startsWith('cell color:'));
    });

    test('card framed holding a number drops the chrome', () {
      final List<String> errors = <String>[];
      final HuiPreviewDoc doc = HuiPreviewDoc(
        card: HuiPreviewCard(framed: 1),
        elements: <HuiPreviewElement>[
          HuiPreviewElement('cell', size: 8, color: '#FF000000'),
        ],
      );
      late final PreviewCardScene scene;
      expect(
        () => scene = buildCardScene(
          doc,
          PreviewSim('statics'),
          onError: errors.add,
        ),
        returnsNormally,
      );
      expect(scene.items.length, 1);
      expect(
        errors.single,
        'card framed: card.framed: must be a boolean or a string expression',
      );
    });

    test('every hostile field stays quiet without an error sink', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        card: HuiPreviewCard(framed: 1),
        elements: <HuiPreviewElement>[
          HuiPreviewElement('cell', size: 8, color: true, visible: 1),
          HuiPreviewElement('panel', width: true, height: 10, color: 1),
          HuiPreviewElement('label', x: <String>['bad'] as Object),
          HuiPreviewElement(
            'slot',
            size: 18,
            index: 0,
            repeat: HuiPreviewRepeat(count: double.nan),
          ),
        ],
      );
      expect(() => buildCardScene(doc, PreviewSim('chest')), returnsNormally);
    });
  });

  group('slot items', () {
    test('a slot carries the simulated stack, or null when empty', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement(
            'slot',
            size: 18,
            index: 'i',
            repeat: HuiPreviewRepeat(count: 5),
          ),
        ],
      );
      final List<CardSlot> slots = buildCardScene(
        doc,
        PreviewSim('chest'),
      ).items.whereType<CardSlot>().toList();
      expect(slots.length, 5);
      expect(slots[0].item?.material, 'DIAMOND');
      expect(slots[1].item?.material, 'STONE');
      expect(slots[2].item?.material, 'BOOK');
      expect(slots[3].item, isNull);
      expect(slots[4].item, isNull);
    });

    test('an out-of-range slot index carries no stack', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement('slot', size: 18, index: 99),
        ],
      );
      final CardSlot slot =
          buildCardScene(doc, PreviewSim('chest')).items.single as CardSlot;
      expect(slot.index, 99);
      expect(slot.item, isNull);
    });
  });

  group('live fields rebuild', () {
    test('a cell colour follows the ticking simulation', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement(
            'cell',
            size: 8,
            color: 'burnTime > 200 ? #FFFF0000 : #FF0000FF',
          ),
        ],
      );
      final PreviewSim sim = PreviewSim('furnace');
      expect(
        (buildCardScene(doc, sim).items.single as CardCell).color,
        0xFFFF0000,
      );
      sim.tick(150);
      expect(
        (buildCardScene(doc, sim).items.single as CardCell).color,
        0xFF0000FF,
      );
    });
  });
}

// ---------------------------------------------------------------------
// Scenarios
// ---------------------------------------------------------------------

/// One golden scenario: the shipped document, the simulated category standing in
/// for the `GoldenFakes` block state, and the material the registry resolves the
/// variant variables against.
class _Scenario {
  const _Scenario(this.golden, this.document, this.category, this.material);

  final String golden;
  final String document;
  final String category;

  /// Null for a `special` document, which the registry builds against static
  /// variables with no target (`PreviewStateContext.statics`).
  final String? material;
}

const List<_Scenario> _scenarios = <_Scenario>[
  // GoldenFakes.chest(27): a 27-slot CHEST at game time 1234 holding
  // DIAMOND x1, STONE x32, BOOK x3 — the `chest` simulated category verbatim.
  _Scenario('chest_27', 'chest', 'chest', 'CHEST'),
  // GoldenFakes.smelting(FURNACE): cookTime 100, cookTimeTotal 200,
  // burnTime 300, 0.5 experience banked three times, game time 1234, holding
  // IRON_ORE x1 / COAL x8 / IRON_INGOT x2 — the `furnace` category verbatim.
  _Scenario('furnace_smelting', 'furnace', 'furnace', 'FURNACE'),
  // The locked document is `special: locked`: no block, no inventory, statics
  // only.
  _Scenario('locked', 'locked', 'statics', null),
];

PreviewCardScene _buildScenario(_Scenario scenario, List<String> errors) {
  final HuiPreviewDoc doc = decodeHuiPreviewDoc(
    File('test/fixtures/previews/${scenario.document}.json').readAsStringSync(),
  );
  final PreviewSim sim = PreviewSim(scenario.category, lang: _lang);
  sim.vars = PreviewSim.parseVars(
    previewVarsForMaterial(doc, scenario.material),
  );
  return buildCardScene(doc, sim, onError: errors.add);
}

/// A framed card over [elements], with the document's own accent left absent so
/// the neutral default applies.
PreviewCardScene _framed(List<HuiPreviewElement> elements) => buildCardScene(
  HuiPreviewDoc(card: HuiPreviewCard(), elements: elements),
  PreviewSim('statics'),
);

final PreviewLangCatalog _lang = PreviewLangCatalog.parse(
  File('web/assets/catalog/preview-lang-en.json').readAsStringSync(),
);

// ---------------------------------------------------------------------
// Golden normalization
// ---------------------------------------------------------------------

List<Object?> _readGolden(String name) =>
    jsonDecode(File('test/fixtures/golden/$name.json').readAsStringSync())
        as List<Object?>;

/// `GoldenSerializer.color` writes `#AARRGGBB`; the scene carries the same bits
/// as an unsigned int.
int _parseArgb(Object? raw) {
  final String text = (raw as String).substring(1);
  return int.parse(text, radix: 16);
}

List<Map<String, Object?>> _normalizeGolden(List<Object?> golden) {
  final List<Map<String, Object?>> out = <Map<String, Object?>>[];
  for (final Object? raw in golden) {
    final Map<String, Object?> e = raw! as Map<String, Object?>;
    final Map<String, Object?> item = <String, Object?>{
      'type': e['type'],
      'x': e['x'],
      'y': e['y'],
      'z': e['z'],
    };
    switch (e['type']) {
      case 'panel':
        item['width'] = e['width'];
        item['height'] = e['height'];
        item['color'] = _parseArgb(e['color']);
      case 'cell':
        item['size'] = e['size'];
        item['color'] = _parseArgb(e['color']);
      case 'slot':
        item['size'] = e['size'];
        item['wellColor'] = _parseArgb(e['wellColor']);
        item['index'] = e['slot'];
      case 'label':
        item['text'] = _flattenComponent(e['text'], const _InheritedStyle());
        item['background'] = _parseArgb(e['background']);
    }
    out.add(item);
  }
  return out;
}

List<Map<String, Object?>> _normalizeScene(PreviewCardScene scene) {
  final List<Map<String, Object?>> out = <Map<String, Object?>>[];
  for (final CardItem item in scene.items) {
    final Map<String, Object?> e = <String, Object?>{
      'type': switch (item) {
        CardPanel() => 'panel',
        CardCell() => 'cell',
        CardSlot() => 'slot',
        CardLabel() => 'label',
      },
      'x': item.x,
      'y': item.y,
      'z': item.z,
    };
    switch (item) {
      case CardPanel():
        e['width'] = item.width;
        e['height'] = item.height;
        e['color'] = item.color;
      case CardCell():
        e['size'] = item.size;
        e['color'] = item.color;
      case CardSlot():
        e['size'] = item.size;
        e['wellColor'] = item.wellColor;
        e['index'] = item.index;
      case CardLabel():
        e['text'] = <Map<String, Object?>>[
          for (final McSpan span in item.text)
            if (span.text.isNotEmpty) _run(span.text, span),
        ];
        e['background'] = item.background;
    }
    out.add(e);
  }
  return out;
}

Map<String, Object?> _run(String text, McSpan style) => <String, Object?>{
  'text': text,
  'color': style.color,
  'bold': style.bold,
  'italic': style.italic,
  'underlined': style.underlined,
  'strikethrough': style.strikethrough,
  'obfuscated': style.obfuscated,
};

/// Style inherited down an Adventure component tree. Adventure's tri-state
/// decorations serialize as `true`/`false`/absent; absent means "inherit", and
/// nothing inherited means off.
class _InheritedStyle {
  const _InheritedStyle({
    this.color,
    this.bold = false,
    this.italic = false,
    this.underlined = false,
    this.strikethrough = false,
    this.obfuscated = false,
  });

  final int? color;
  final bool bold;
  final bool italic;
  final bool underlined;
  final bool strikethrough;
  final bool obfuscated;

  _InheritedStyle merge(Map<String, Object?> node) => _InheritedStyle(
    color: _componentColor(node['color']) ?? color,
    bold: _decoration(node['bold']) ?? bold,
    italic: _decoration(node['italic']) ?? italic,
    underlined: _decoration(node['underlined']) ?? underlined,
    strikethrough: _decoration(node['strikethrough']) ?? strikethrough,
    obfuscated: _decoration(node['obfuscated']) ?? obfuscated,
  );

  McSpan asSpan(String text) => McSpan(
    text: text,
    rgb: color ?? mcDefaultTextColor,
    bold: bold,
    italic: italic,
    underlined: underlined,
    strikethrough: strikethrough,
    obfuscated: obfuscated,
  );
}

bool? _decoration(Object? raw) => raw is bool ? raw : null;

/// A serialized Adventure colour is either a hex `#RRGGBB` string or one of the
/// sixteen vanilla names.
int? _componentColor(Object? raw) {
  if (raw is! String) return null;
  if (raw.startsWith('#')) return int.parse(raw.substring(1), radix: 16);
  return mcNamedColor(raw);
}

/// Flattens a Gson-serialized Adventure component into the flat run list
/// [parseMcText] produces. See the normalization note at the top of this file.
List<Map<String, Object?>> _flattenComponent(
  Object? raw,
  _InheritedStyle inherited,
) {
  if (raw is String) {
    return raw.isEmpty
        ? const <Map<String, Object?>>[]
        : <Map<String, Object?>>[_run(raw, inherited.asSpan(raw))];
  }
  if (raw is! Map) return const <Map<String, Object?>>[];
  final Map<String, Object?> node = raw.cast<String, Object?>();
  final _InheritedStyle style = inherited.merge(node);
  final List<Map<String, Object?>> runs = <Map<String, Object?>>[];
  final Object? text = node['text'];
  if (text is String && text.isNotEmpty) {
    runs.add(_run(text, style.asSpan(text)));
  }
  final Object? extra = node['extra'];
  if (extra is List) {
    for (final Object? child in extra) {
      runs.addAll(_flattenComponent(child, style));
    }
  }
  return runs;
}

// ---------------------------------------------------------------------
// Comparison
// ---------------------------------------------------------------------

bool _deepEquals(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final Object? key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  return a == b;
}

String _firstDifference(
  List<Map<String, Object?>> expected,
  List<Map<String, Object?>> actual,
) {
  final int size = expected.length < actual.length
      ? expected.length
      : actual.length;
  for (int index = 0; index < size; index++) {
    if (!_deepEquals(expected[index], actual[index])) {
      return '[$index]\n  golden:   ${jsonEncode(expected[index])}'
          '\n  document: ${jsonEncode(actual[index])}';
    }
  }
  return 'element count ${expected.length} (golden) vs ${actual.length} (document)';
}

String _pretty(List<Map<String, Object?>> items) =>
    items.map(jsonEncode).join('\n');

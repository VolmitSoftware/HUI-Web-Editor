/// Starter container-preview documents offered by the templates dialog.
///
/// Every template must parse clean and build clean against the simulated
/// category it was authored for: `test/preview_templates_test.dart` builds
/// each one and asserts zero `onError` output, the same bar
/// `preview_card_scene_test.dart` holds the plugin's own shipped documents to.
library;

import '../model/preview_doc.dart';

/// A named starter document.
class HuiPreviewTemplate {
  const HuiPreviewTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.highlights,
    required this.category,
    required this.build,
  });

  /// File base name the new document starts with.
  final String id;
  final String name;

  /// One or two sentences shown on the option card.
  final String description;

  /// Short feature bullets, rendered as chips.
  final List<String> highlights;

  /// Which `previewSimCategories` entry demonstrates this template correctly
  /// — the simulation panel preselects it so the starter renders right away.
  final String category;

  /// Builds a fresh, mutable document. Never return a shared instance: the
  /// store takes ownership of whatever comes back.
  final HuiPreviewDoc Function() build;
}

const List<HuiPreviewTemplate> huiPreviewTemplates = <HuiPreviewTemplate>[
  HuiPreviewTemplate(
    id: 'furnace-dashboard',
    name: 'Furnace dashboard',
    description:
        'The real card HoloUI draws over a furnace, blast furnace or smoker: '
        'a progress ring, a fuel flame, and two state labels. Variants swap '
        'the whole palette and cell layout per block type.',
    highlights: <String>['3 slots', '2 variants', 'Live progress + fuel'],
    category: 'furnace',
    build: buildFurnaceDashboardTemplate,
  ),
  HuiPreviewTemplate(
    id: 'minimal-chest',
    name: 'Minimal chest',
    description:
        'A clean 3x3 grid of inventory slots over a framed card, with a '
        'label reporting how many are occupied. The starting point for any '
        'plain inventory preview.',
    highlights: <String>['9 slots', 'Framed card', 'Occupied counter'],
    category: 'chest',
    build: buildMinimalChestTemplate,
  ),
  HuiPreviewTemplate(
    id: 'custom-stat-card',
    name: 'Custom stat card',
    description:
        'Bare content with no card chrome (`framed: false`), demonstrating '
        'the expression language: a ternary-driven pulsing cell, '
        'string concatenation, and the readable()/round() functions.',
    highlights: <String>['No chrome', 'Ternary + mod()', 'DSL walkthrough'],
    category: 'statics',
    build: buildCustomStatCardTemplate,
  ),
];

HuiPreviewTemplate? huiPreviewTemplateById(String id) {
  for (final HuiPreviewTemplate template in huiPreviewTemplates) {
    if (template.id == id) return template;
  }
  return null;
}

/// Verbatim copy of `HoloUi/src/main/resources/previews/furnace.json` (also
/// mirrored as the golden-parity fixture at `test/fixtures/previews/furnace.json`
/// — the two must be kept identical). Decoding rather than hand-authoring the
/// equivalent `HuiPreviewDoc` graph guarantees the template is byte-for-byte
/// the shipped document, key ordering included.
const String _furnaceDashboardJson = r'''
{
  "match": {
    "blocks": ["FURNACE", "BLAST_FURNACE", "SMOKER"],
    "priority": 10,
    "vars": {
      "style": "furnace",
      "segments": 8,
      "wellColor": "#FF15151B",
      "fill": "#FFF2A535",
      "pulseBright": "#FFFFD978",
      "pulseDim": "#FF8A5E1E",
      "chase": "#FF9A5E22",
      "idle": "#FF2A2A33",
      "flame0": "#FFE2641E",
      "flame1": "#FFF2A535",
      "flame2": "#FFF7D14C",
      "smoke0": "#FF5E5E66",
      "smoke1": "#FF8A8A92",
      "smoke2": "#FFB8B8C0",
      "activeItemKey": "holoui.preview.state.smelting_item",
      "activeKey": "holoui.preview.state.smelting",
      "stateColor": "<#F2A535>",
      "surgeColor": "<#FFD978>",
      "titleKey": "holoui.preview.theme.title.furnace",
      "accent": "#F2A535"
    }
  },
  "variants": [
    {
      "blocks": ["BLAST_FURNACE"],
      "vars": {
        "style": "blast",
        "fill": "#FF6FB8E8",
        "pulseBright": "#FFE8F7FF",
        "pulseDim": "#FF2E5E80",
        "chase": "#FF4FA8D8",
        "idle": "#FF23262E",
        "flame0": "#FF4FA8E8",
        "flame1": "#FF8ED4FF",
        "flame2": "#FFE8F7FF",
        "activeItemKey": "holoui.preview.state.blasting_item",
        "activeKey": "holoui.preview.state.blasting",
        "stateColor": "<#6FB8E8>",
        "surgeColor": "<#E8F7FF>",
        "titleKey": "holoui.preview.theme.title.blast_furnace",
        "accent": "#6FEAEA"
      }
    },
    {
      "blocks": ["SMOKER"],
      "vars": {
        "style": "smoker",
        "fill": "#FFC8893A",
        "pulseBright": "#FFF2C878",
        "pulseDim": "#FF6E4A1E",
        "chase": "#FF8A6234",
        "idle": "#FF2A2A33",
        "flame0": "#FFE25822",
        "flame1": "#FFF2A535",
        "flame2": "#FFC23B22",
        "activeItemKey": "holoui.preview.state.smoking_item",
        "activeKey": "holoui.preview.state.smoking",
        "stateColor": "<#C8893A>",
        "surgeColor": "<#F2C878>",
        "titleKey": "holoui.preview.theme.title.smoker",
        "accent": "#F2D451"
      }
    }
  ],
  "card": {
    "title": "'&f&l' + (customName != '' ? customName : plain(lang(vars.titleKey)))",
    "accent": "vars.accent"
  },
  "elements": [
    { "type": "slot", "x": -40, "y": 10, "size": 18, "index": 0 },
    { "type": "slot", "x": -40, "y": -10, "size": 18, "index": 1 },
    { "type": "slot", "x": 40, "y": 10, "size": 18, "index": 2 },
    {
      "type": "cell",
      "repeat": { "count": "vars.segments", "var": "i" },
      "x": "-24 + i * 7",
      "y": 10,
      "size": 5,
      "color": "cookTime > 0 && cookTimeTotal > 0 ? (i < floor(cookTime / cookTimeTotal * vars.segments) ? (surge.active ? (mod(floor(cookTime / 2) + i, 2) == 0 ? vars.pulseBright : vars.fill) : vars.fill) : (i == floor(cookTime / cookTimeTotal * vars.segments) ? (mod(floor(cookTime / 4), 2) == 0 ? vars.pulseBright : vars.pulseDim) : vars.wellColor)) : (burnTime > 0 && i == mod(floor(burnTime / 4), vars.segments) ? vars.chase : vars.wellColor)"
    },
    {
      "type": "cell",
      "visible": "vars.style != 'blast'",
      "x": -20,
      "y": -10,
      "size": 12,
      "color": "burnTime > 0 ? palette([vars.flame0, vars.flame1, vars.flame2], floor(burnTime / (surge.active ? 2 : 4))) : vars.idle"
    },
    {
      "type": "cell",
      "visible": "vars.style == 'blast'",
      "repeat": { "count": 3, "var": "vent" },
      "x": "-20 + vent * 8",
      "y": -10,
      "size": 6,
      "color": "burnTime > 0 ? palette([vars.flame0, vars.flame1, vars.flame2], floor(burnTime / (surge.active ? 2 : 4)) + vent) : vars.idle"
    },
    {
      "type": "cell",
      "visible": "vars.style == 'smoker'",
      "repeat": { "count": 2, "var": "wisp" },
      "x": "wisp == 0 ? -8 : 2",
      "y": -10,
      "size": "wisp == 0 ? 8 : 6",
      "color": "burnTime > 0 ? palette([vars.smoke0, vars.smoke1, vars.smoke2], floor(burnTime / (surge.active ? 2 : 4)) + wisp + 1) : vars.idle"
    },
    {
      "type": "label",
      "x": 0,
      "y": -32,
      "text": "(cookTime > 0 && cookTimeTotal > 0 ? vars.stateColor + lang(occupied(0) ? vars.activeItemKey : vars.activeKey, occupied(0) ? readable(item(0)) : round(cookTime * 100 / cookTimeTotal), round(cookTime * 100 / cookTimeTotal)) : (burnTime > 0 && occupied(0) ? '&e' + lang('holoui.preview.state.heating') : (occupied(0) && !occupied(1) ? '&c' + lang('holoui.preview.state.needs_fuel') : (!occupied(0) ? '&7' + lang('holoui.preview.state.no_input') : '&7' + lang('holoui.preview.state.waiting'))))) + (surge.active ? vars.surgeColor + lang('holoui.preview.state.surge_suffix', surge.gain == floor(surge.gain) ? str(surge.gain) : fixed(surge.gain, 1)) : '')"
    },
    {
      "type": "label",
      "x": 0,
      "y": -46,
      "text": "(burnTime > 0 ? '&e' + lang('holoui.preview.stat.fuel_seconds', fuelSeconds) : (occupied(1) ? '&7' + lang('holoui.preview.stat.fuel_ready') : '&8' + lang('holoui.preview.stat.no_fuel'))) + (bankedXp >= 0 ? '<dark_gray>  •  </dark_gray>' + (bankedXp > 0 ? '<green>' + lang('holoui.preview.stat.xp_gain', bankedXp == floor(bankedXp) ? str(bankedXp) : fixed(bankedXp, 1)) + '</green>' : '<dark_gray>' + lang('holoui.preview.stat.xp_zero') + '</dark_gray>') : '')"
    }
  ]
}
''';

HuiPreviewDoc buildFurnaceDashboardTemplate() =>
    decodeHuiPreviewDoc(_furnaceDashboardJson);

/// A framed 3x3 grid of inventory slots (pitch 27px, matching the format's
/// 18px well plus a comfortable gap) with a card title and an occupied-count
/// label. Deliberately vars-free: a starter document should build clean
/// before the author has written a single `vars` entry.
HuiPreviewDoc buildMinimalChestTemplate() => HuiPreviewDoc(
  card: HuiPreviewCard(title: "'&f&lChest'"),
  elements: <HuiPreviewElement>[
    HuiPreviewElement(
      'slot',
      x: 'mod(i, 3) * 27 - 27',
      y: '18 - floor(i / 3) * 27',
      size: 18,
      index: 'i',
      repeat: HuiPreviewRepeat(count: 9, varName: 'i'),
    ),
    HuiPreviewElement(
      'label',
      x: 0,
      y: -40,
      text: "'&7' + inventory.occupied + '/' + inventory.size + ' occupied'",
    ),
  ],
);

/// Bare content (`framed: false`) that walks through the expression language:
/// a ternary-and-mod()-driven pulsing cell, string concatenation with `+`,
/// and `readable()`/`round()` formatting a universal variable. Built against
/// the `statics` category, so it only touches variables every category
/// publishes.
HuiPreviewDoc buildCustomStatCardTemplate() => HuiPreviewDoc(
  card: HuiPreviewCard(framed: false),
  elements: <HuiPreviewElement>[
    HuiPreviewElement('label', x: 0, y: 24, text: "'&6&lCustom Stat Card'"),
    HuiPreviewElement(
      'label',
      x: 0,
      y: 8,
      text: "'&7Block: &f' + (blockType != '' ? readable(blockType) : 'none')",
    ),
    HuiPreviewElement(
      'cell',
      x: -20,
      y: -8,
      size: 16,
      // `#RRGGBB` is a NUMBER literal in this grammar (tokenized straight
      // to its unsigned ARGB value), not a quoted string — quoting it
      // would make the ternary resolve to text and fail `_color`'s
      // number requirement at build time.
      color: 'mod(floor(time / 20), 2) == 0 ? #FF55D67D : #FF3D8F57',
    ),
    HuiPreviewElement(
      'label',
      x: 10,
      y: -8,
      text: "'&7Time: &f' + round(time) + 's'",
    ),
  ],
);

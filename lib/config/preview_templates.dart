/// Starter and in-game container-preview documents offered by the templates dialog.
///
/// Every template must parse clean and build clean against the simulated
/// category it was authored for: `test/preview_templates_test.dart` builds
/// each one and asserts zero `onError` output, the same bar
/// `preview_card_scene_test.dart` holds the plugin's own shipped documents to.
library;

import '../model/preview_doc.dart';
import 'shipped_preview_json.dart';

/// A named starter or in-game document.
class HuiPreviewTemplate {
  const HuiPreviewTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.highlights,
    required this.category,
    required this.build,
    this.inGame = false,
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

  /// True when this is one of the thirteen documents the plugin extracts
  /// into `plugins/Gloss/previews/` on first start.
  final bool inGame;

  /// Builds a fresh, mutable document. Never return a shared instance: the
  /// store takes ownership of whatever comes back.
  final HuiPreviewDoc Function() build;
}

class _ShippedPreviewSpec {
  const _ShippedPreviewSpec({
    required this.id,
    required this.name,
    required this.description,
    required this.highlights,
    required this.category,
  });

  final String id;
  final String name;
  final String description;
  final List<String> highlights;
  final String category;
}

const List<_ShippedPreviewSpec> _shippedPreviewSpecs = <_ShippedPreviewSpec>[
  _ShippedPreviewSpec(
    id: 'beehive',
    name: 'Beehive',
    description:
        'The card Gloss draws over a beehive or bee nest: three honey '
        'cells and a bees-and-honey label. No inventory.',
    highlights: <String>['In-game', 'Honey gauge', 'No inventory'],
    category: 'beehive',
  ),
  _ShippedPreviewSpec(
    id: 'brewing_stand',
    name: 'Brewing stand',
    description:
        'The real brewing-stand card: ingredient and blaze-powder slots, '
        'three bottles, a brew column, fuel cells, and live state lines.',
    highlights: <String>['In-game', '5 slots', 'Live brew + fuel'],
    category: 'brewing',
  ),
  _ShippedPreviewSpec(
    id: 'cauldron',
    name: 'Cauldron',
    description:
        'Fill-level cells for empty, water, lava, and powder-snow '
        'cauldrons. Variants retint the fluid.',
    highlights: <String>['In-game', '4 variants', 'Fill gauge'],
    category: 'cauldron',
  ),
  _ShippedPreviewSpec(
    id: 'chest',
    name: 'Chest',
    description:
        'The canonical 9-wide slot grid Gloss draws over chests, barrels, '
        'copper chests, and every shulker box.',
    highlights: <String>['In-game', 'Up to 54 slots', '20 variants'],
    category: 'chest',
  ),
  _ShippedPreviewSpec(
    id: 'chiseled_bookshelf',
    name: 'Chiseled bookshelf',
    description: 'A 3-by-2 slot grid over a chiseled bookshelf.',
    highlights: <String>['In-game', '6 slots'],
    category: 'chest',
  ),
  _ShippedPreviewSpec(
    id: 'dispenser',
    name: 'Dispenser',
    description:
        'A 3-by-3 slot grid. A variant restyles the same layout for a '
        'dropper.',
    highlights: <String>['In-game', '9 slots', 'Dropper variant'],
    category: 'chest',
  ),
  _ShippedPreviewSpec(
    id: 'ender_chest',
    name: 'Ender chest',
    description:
        'The viewer\'s own ender-chest inventory on a 9-wide grid, marked '
        'special: enderChest.',
    highlights: <String>['In-game', 'Personal inventory'],
    category: 'enderChest',
  ),
  _ShippedPreviewSpec(
    id: 'furnace',
    name: 'Furnace',
    description:
        'The real card Gloss draws over a furnace, blast furnace or '
        'smoker: a progress ring, a fuel flame, and two state labels.',
    highlights: <String>['In-game', '3 slots', 'Live progress + fuel'],
    category: 'furnace',
  ),
  _ShippedPreviewSpec(
    id: 'hopper',
    name: 'Hopper',
    description: 'A five-slot row over a hopper.',
    highlights: <String>['In-game', '5 slots'],
    category: 'chest',
  ),
  _ShippedPreviewSpec(
    id: 'jukebox',
    name: 'Jukebox',
    description: 'The disc slot plus a playing, loaded, or empty label.',
    highlights: <String>['In-game', '1 slot', 'Disc state'],
    category: 'jukebox',
  ),
  _ShippedPreviewSpec(
    id: 'locked',
    name: 'Locked',
    description:
        'The unframed four-cell padlock shown when a viewer may not open '
        'the container.',
    highlights: <String>['In-game', 'No chrome', 'Access denied'],
    category: 'statics',
  ),
  _ShippedPreviewSpec(
    id: 'minecart',
    name: 'Minecart and boats',
    description:
        'Chest and hopper minecarts, chest boats, chest rafts, and the '
        'any-inventory-holder entity fallback.',
    highlights: <String>['In-game', 'Entity', 'Row or grid'],
    category: 'entity',
  ),
  _ShippedPreviewSpec(
    id: 'shelf',
    name: 'Shelf',
    description: 'A slot row for every wood shelf variant.',
    highlights: <String>['In-game', '*_SHELF glob'],
    category: 'chest',
  ),
];

final List<HuiPreviewTemplate> _shippedPreviewTemplates = _shippedPreviewSpecs
    .map(
      (_ShippedPreviewSpec spec) => HuiPreviewTemplate(
        id: spec.id,
        name: spec.name,
        description: spec.description,
        highlights: spec.highlights,
        category: spec.category,
        inGame: true,
        build: () => buildShippedPreview(spec.id),
      ),
    )
    .toList(growable: false);

final List<HuiPreviewTemplate> huiPreviewTemplates = <HuiPreviewTemplate>[
  ..._shippedPreviewTemplates,
  const HuiPreviewTemplate(
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
  const HuiPreviewTemplate(
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

/// The plugin's shipped document of that name, decoded from the byte-identical
/// copy in [kShippedPreviewJson].
HuiPreviewDoc buildShippedPreview(String id) {
  final String? json = kShippedPreviewJson[id];
  if (json == null) {
    throw ArgumentError.value(id, 'id', 'not a shipped preview document');
  }
  return decodeHuiPreviewDoc(json);
}

HuiPreviewDoc buildFurnaceDashboardTemplate() => buildShippedPreview('furnace');

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

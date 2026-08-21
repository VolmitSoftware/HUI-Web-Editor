/// "Randomize" for every runtime document kind.
///
/// Each builder writes a complete, valid, teaching document rather than
/// jittering the numbers already in the file: pressing the button twice gives
/// two different servers, not the same server nudged. The words, colours and
/// sample stacks come from `config/showcase_flavor.dart`; the motion comes
/// from `showcase_effects.dart`.
///
/// Everything a builder emits has to survive its kind's validation and, for a
/// scoreboard, the runtime's 32-character row cut — `showcase_randomizer_test`
/// replays several hundred seeds against both.
library;

import 'dart:math' as math;

import '../config/showcase_flavor.dart';
import '../doctype/doctype.dart';
import '../logic/canvas_scene.dart' show huiIsBlockLikeMaterial;
import '../logic/real_drop_model.dart';
import '../model/model.dart';
import '../state/editor_store.dart';
import 'catalogs.dart';
import 'showcase_effects.dart';

bool canRandomizeShowcase(DocumentTypeAdapter type) =>
    type is! PanelDocumentType;

bool randomizeShowcaseDocument(
  EditorStore store,
  String documentId, {
  math.Random? random,
}) {
  if (store.workspace.byId(documentId) == null) return false;
  if (!store.openDocument(documentId)) return false;
  final math.Random source = random ?? math.Random();
  switch (store.docType) {
    case MenuDocumentType():
      store.replaceMenu(
        'Randomize menu',
        buildRandomMenuShowcase(store, source),
      );
    case ContainerPreviewDocumentType():
      store.replacePreviewDoc(
        'Randomize container preview',
        buildRandomPreviewShowcase(source),
      );
    case HologramDocumentType():
      store.replaceGlossDoc(
        'Randomize hologram',
        buildRandomHologramShowcase(store.hologramDoc!, source),
      );
    case AnimationDocumentType():
      store.replaceGlossDoc(
        'Randomize animation',
        buildRandomAnimationShowcase(store.animationDoc!, source),
      );
    case ScoreboardDocumentType():
      store.replaceGlossDoc(
        'Randomize scoreboard',
        buildRandomScoreboardShowcase(store.scoreboardDoc!, source),
      );
    case MotdDocumentType():
      store.replaceGlossDoc(
        'Randomize MOTD',
        buildRandomMotdShowcase(store.motdDoc!, source),
      );
    case EmojiDocumentType():
      store.replaceGlossDoc(
        'Randomize emoji',
        buildRandomEmojiShowcase(store.emojiDoc!, source),
      );
    case BubbleStyleDocumentType():
      store.replaceGlossDoc(
        'Randomize bubble style',
        buildRandomBubbleShowcase(store.bubbleStyleDoc!, source),
      );
    case TablistDocumentType():
      store.replaceGlossDoc(
        'Randomize tablist',
        buildRandomTablistShowcase(store.tablistDoc!, source),
      );
    case RealDropDocumentType():
      store.replaceGlossDoc(
        'Randomize real drops',
        buildRandomRealDropShowcase(store.realDropSettingsDoc!, source),
      );
    case PanelDocumentType():
      return false;
  }
  return true;
}

bool randomizeMenuComponent(
  EditorStore store,
  String componentId, {
  math.Random? random,
}) {
  final HuiComponent? component = store.menu.componentById(componentId);
  if (component == null || !store.isMenuDoc) return false;
  final math.Random source = random ?? math.Random();
  store.editComponent(componentId, 'Randomize component', (HuiComponent item) {
    item.data = switch (item.data) {
      HuiButtonData() => _randomButtonData(
        store,
        source,
        componentOffset: item.offset,
      ),
      HuiDecorationData() => HuiDecorationData(_randomIcon(store, source)),
      HuiToggleData() => _randomToggleData(store, source),
    };
  });
  return true;
}

HuiMenu buildRandomMenuShowcase(EditorStore store, math.Random random) {
  final ShowcaseMood mood = showcasePick(random, showcaseMoods);
  final String server = showcasePick(random, showcaseServerNames);
  final List<HuiComponent> components = <HuiComponent>[
    HuiComponent(
      'showcase-title',
      Vec3(0, 1.15, 0),
      HuiDecorationData(
        HuiTextIcon(
          '${mood.legacy}&l$server\n&7${showcasePick(random, showcaseEvents)}',
          _randomStyle(random, mood),
          20,
        ),
      ),
    ),
    HuiComponent(
      'all-actions',
      Vec3(-2.4, 0.35, 0),
      _randomButtonData(store, random, componentOffset: Vec3(-2.4, 0.35, 0)),
    ),
    HuiComponent(
      'styled-block',
      Vec3(0, 0.35, 0),
      HuiDecorationData(
        HuiBlockIcon(_blockMaterial(random), _randomStyle(random, mood)),
      ),
    ),
    HuiComponent(
      'living-entity',
      Vec3(2.4, 0.35, 0),
      HuiDecorationData(
        HuiEntityIcon(
          huiSpawnableLivingEntityTypes[random.nextInt(
            huiSpawnableLivingEntityTypes.length,
          )],
          0.7 + random.nextDouble() * 0.7,
          0.7 + random.nextDouble() * 0.7,
        ),
      ),
    ),
    HuiComponent(
      'live-toggle',
      Vec3(0, -0.55, 0),
      _randomToggleData(store, random),
    ),
  ];
  final HuiIcon? assetIcon = _randomAssetIcon(store, random, mood);
  if (assetIcon != null) {
    components.add(
      HuiComponent(
        'local-asset',
        Vec3(0, -1.35, 0),
        HuiDecorationData(assetIcon),
      ),
    );
  }
  return HuiMenu(
    offset: Vec3(
      _round(random.nextDouble() - 0.5),
      _round(1.4 + random.nextDouble() * 0.8),
      _round(2.2 + random.nextDouble()),
    ),
    lockPosition: random.nextBool(),
    followPlayer: random.nextBool(),
    maxDistance: 8 + random.nextInt(25).toDouble(),
    closeOnDeath: true,
    closeOnTeleport: true,
    components: components,
  );
}

HuiPreviewDoc buildRandomPreviewShowcase(math.Random random) {
  final int archetype = random.nextInt(9);
  final _PreviewFurnaceTheme theme = showcasePick(
    random,
    _previewFurnaceThemes,
  );
  return switch (archetype) {
    0 => _buildRandomStoragePreview(random, theme),
    1 => _buildRandomPreviewFurnaceLab(random, theme),
    2 => _buildRandomBrewingPreview(random, theme),
    3 => _buildRandomBeehivePreview(random, theme),
    4 => _buildRandomCauldronPreview(random, theme),
    5 => _buildRandomJukeboxPreview(random, theme),
    6 => _buildRandomEnderPreview(random, theme),
    7 => _buildRandomMobilePreview(random, theme),
    _ => _buildRandomVitalsPreview(random, theme),
  };
}

HuiPreviewDoc buildRandomPreviewFurnaceLab(math.Random random) =>
    _buildRandomPreviewFurnaceLab(
      random,
      showcasePick(random, _previewFurnaceThemes),
    );

HuiPreviewDoc _buildRandomPreviewFurnaceLab(
  math.Random random,
  _PreviewFurnaceTheme selected,
) {
  final int segments = 7 + random.nextInt(6);
  final int segmentGap = 6 + random.nextInt(3);
  final int segmentSize = 4 + random.nextInt(3);
  final int pulseRate = 3 + random.nextInt(6);
  return HuiPreviewDoc(
    match: HuiPreviewMatch(
      blocks: <String>['FURNACE', 'BLAST_FURNACE', 'SMOKER'],
      priority: 10,
      vars: <String, dynamic>{
        'style': 'furnace',
        'segments': segments,
        'segmentGap': segmentGap,
        'segmentSize': segmentSize,
        'pulseRate': pulseRate,
        'panelWidth': 156 + random.nextInt(29),
        'panelHeight': 104 + random.nextInt(21),
        'panelColor': selected.panelColor,
        'wellColor': selected.wellColor,
        'fill': selected.fill,
        'pulse': selected.pulse,
        'chase': selected.chase,
        'idle': selected.idle,
        'flame0': selected.flame0,
        'flame1': selected.flame1,
        'flame2': selected.flame2,
        'smoke0': '#FF5E5E66',
        'smoke1': '#FF8A8A92',
        'smoke2': '#FFB8B8C0',
        'activeItemKey': 'gloss.preview.state.smelting_item',
        'activeKey': 'gloss.preview.state.smelting',
        'stateColor': selected.stateColor,
        'surgeColor': selected.surgeColor,
        'titleKey': 'gloss.preview.theme.title.furnace',
        'accent': selected.accent,
      },
    ),
    variants: <HuiPreviewVariant>[
      HuiPreviewVariant(
        blocks: <String>['BLAST_FURNACE'],
        vars: <String, dynamic>{
          'style': 'blast',
          'fill': '#FF6FB8E8',
          'pulse': '#FFE8F7FF',
          'chase': '#FF4FA8D8',
          'idle': '#FF23262E',
          'flame0': '#FF4FA8E8',
          'flame1': '#FF8ED4FF',
          'flame2': '#FFE8F7FF',
          'activeItemKey': 'gloss.preview.state.blasting_item',
          'activeKey': 'gloss.preview.state.blasting',
          'stateColor': '<#6FB8E8>',
          'surgeColor': '<#E8F7FF>',
          'titleKey': 'gloss.preview.theme.title.blast_furnace',
          'accent': '#6FEAEA',
        },
      ),
      HuiPreviewVariant(
        blocks: <String>['SMOKER'],
        vars: <String, dynamic>{
          'style': 'smoker',
          'fill': '#FFC8893A',
          'pulse': '#FFF2C878',
          'chase': '#FF8A6234',
          'idle': '#FF2A2A33',
          'flame0': '#FFE25822',
          'flame1': '#FFF2A535',
          'flame2': '#FFC23B22',
          'activeItemKey': 'gloss.preview.state.smoking_item',
          'activeKey': 'gloss.preview.state.smoking',
          'stateColor': '<#C8893A>',
          'surgeColor': '<#F2C878>',
          'titleKey': 'gloss.preview.theme.title.smoker',
          'accent': '#F2D451',
        },
      ),
    ],
    card: HuiPreviewCard(
      title:
          "'&f&l' + (customName != '' ? customName : "
          'plain(lang(vars.titleKey)))',
      accent: 'vars.accent',
      minHalfWidth: 92,
    ),
    elements: <HuiPreviewElement>[
      HuiPreviewElement(
        'panel',
        x: 0,
        y: -8,
        width: 'vars.panelWidth',
        height: 'vars.panelHeight',
        color: 'vars.panelColor',
      ),
      HuiPreviewElement(
        'slot',
        x: -43,
        y: 14,
        size: 20,
        index: 0,
        wellColor: 'vars.wellColor',
      ),
      HuiPreviewElement(
        'slot',
        x: -43,
        y: -10,
        size: 20,
        index: 1,
        wellColor: 'vars.wellColor',
      ),
      HuiPreviewElement(
        'slot',
        x: 43,
        y: 14,
        size: 20,
        index: 2,
        wellColor: 'vars.wellColor',
      ),
      HuiPreviewElement(
        'cell',
        repeat: HuiPreviewRepeat(count: 'vars.segments', varName: 'i'),
        x: 'round((i - (vars.segments - 1) / 2) * vars.segmentGap)',
        y: 14,
        size: 'vars.segmentSize',
        color:
            'cookTime > 0 && cookTimeTotal > 0 '
            '? (i < ceil(cookTime / cookTimeTotal * vars.segments) '
            '? mix(vars.fill, vars.pulse, '
            '(sin(time / vars.pulseRate + i) + 1) / 2) '
            ': vars.wellColor) '
            ': (burnTime > 0 && '
            'i == mod(floor(time / vars.pulseRate), vars.segments) '
            '? vars.chase : vars.wellColor)',
      ),
      HuiPreviewElement(
        'cell',
        visible: "vars.style != 'blast'",
        x: -20,
        y: -10,
        size: 12,
        color:
            'burnTime > 0 '
            '? palette([vars.flame0, vars.flame1, vars.flame2], '
            'floor(time / vars.pulseRate)) '
            ': vars.idle',
      ),
      HuiPreviewElement(
        'cell',
        visible: "vars.style == 'blast'",
        repeat: HuiPreviewRepeat(count: 3, varName: 'vent'),
        x: '-28 + vent * 8',
        y: -10,
        size: 6,
        color:
            'burnTime > 0 '
            '? palette([vars.flame0, vars.flame1, vars.flame2], '
            'floor(time / vars.pulseRate) + vent) '
            ': vars.idle',
      ),
      HuiPreviewElement(
        'cell',
        visible: "vars.style == 'smoker'",
        repeat: HuiPreviewRepeat(count: 3, varName: 'wisp'),
        x: '-12 + wisp * 10',
        y: '-9 + mod(wisp, 2) * 6',
        size: '8 - wisp',
        color:
            'burnTime > 0 '
            '? alpha(palette([vars.smoke0, vars.smoke1, vars.smoke2], '
            'floor(time / vars.pulseRate) + wisp), 210 - wisp * 45) '
            ': vars.idle',
      ),
      HuiPreviewElement(
        'label',
        x: 0,
        y: -32,
        text:
            "cookTime > 0 && cookTimeTotal > 0 "
            "? vars.stateColor + (occupied(0) "
            "? lang(vars.activeItemKey, readable(item(0)), "
            "round(cookTime * 100 / cookTimeTotal)) "
            ": lang(vars.activeKey, "
            "round(cookTime * 100 / cookTimeTotal))) "
            "+ ' &8' + bar(cookTime, cookTimeTotal, 12, '■', '□') "
            ": (occupied(0) && !occupied(1) "
            "? '&c' + lang('gloss.preview.state.needs_fuel') "
            ": (!occupied(0) ? '&7' + lang('gloss.preview.state.no_input') "
            ": '&7' + lang('gloss.preview.state.waiting')))",
      ),
      HuiPreviewElement(
        'label',
        x: 0,
        y: -46,
        text:
            "(occupied(0) ? '&f' + readable(item(0)) + ' &8×&f' "
            "+ str(count(0)) : '&8Empty input') "
            "+ ' &8• &7Fuel &f' + str(fuelSeconds) + 's' "
            "+ ' &8• &7XP &a' + fixed(max(bankedXp, 0), 1)",
      ),
      HuiPreviewElement(
        'label',
        x: 0,
        y: -59,
        text:
            "(surge.active "
            "? vars.surgeColor + '&lSURGE ×' + fixed(surge.gain, 1) "
            ": select(['&8IDLE', '&7READY', '&fMONITORING'], "
            "floor(time / 10))) + ' &8• &7Slots &f' "
            "+ str(inventory.occupied) + '/' + str(inventory.size)",
      ),
    ],
  );
}

HuiPreviewDoc _buildRandomStoragePreview(
  math.Random random,
  _PreviewFurnaceTheme theme,
) {
  final int columns = 5 + random.nextInt(3);
  final int rows = 2 + random.nextInt(2);
  final int slots = columns * rows;
  final int pulseRate = 3 + random.nextInt(7);
  return HuiPreviewDoc(
    match: HuiPreviewMatch(
      blocks: <String>['CHEST', 'TRAPPED_CHEST', 'BARREL'],
      priority: 10,
      vars: <String, dynamic>{
        ..._previewThemeVars(theme),
        'title': showcasePick(random, <String>[
          'Ghostwood Storehouse',
          'Packard Mill Inventory',
          'Bookhouse Supply Cache',
        ]),
        'columns': columns,
        'rows': rows,
        'slots': slots,
        'pulseRate': pulseRate,
        'panelWidth': columns * 22 + 34,
        'panelHeight': rows * 22 + 58,
      },
    ),
    variants: <HuiPreviewVariant>[
      HuiPreviewVariant(
        blocks: <String>['TRAPPED_CHEST'],
        vars: <String, dynamic>{
          'title': 'Red Room Lockbox',
          'accent': '#FF5577',
          'fill': '#FFFF3355',
          'pulse': '#FFFFB3C4',
        },
      ),
      HuiPreviewVariant(
        blocks: <String>['BARREL'],
        vars: <String, dynamic>{
          'title': 'Roadhouse Barrel',
          'accent': '#F2D451',
        },
      ),
    ],
    card: _previewCard(82 + columns * 4),
    elements: <HuiPreviewElement>[
      _previewPanel(),
      HuiPreviewElement(
        'cell',
        repeat: HuiPreviewRepeat(count: 'vars.columns', varName: 'scan'),
        x: 'round((scan - (vars.columns - 1) / 2) * 22)',
        y: 'round(vars.rows * 11 + 11)',
        size: 5,
        color:
            'scan == mod(floor(time / vars.pulseRate), vars.columns) '
            '? vars.pulse : mix(vars.idle, vars.fill, '
            '(sin(time / vars.pulseRate + scan) + 1) / 5)',
      ),
      HuiPreviewElement(
        'slot',
        repeat: HuiPreviewRepeat(count: 'vars.slots', varName: 'i'),
        x: 'round((mod(i, vars.columns) - (vars.columns - 1) / 2) * 22)',
        y: 'round(((vars.rows - 1) / 2 - floor(i / vars.columns)) * 22)',
        size: 18,
        index: 'i',
        wellColor: 'vars.wellColor',
      ),
      HuiPreviewElement(
        'label',
        x: 0,
        y: '-round(vars.rows * 11 + 14)',
        text:
            "'&7Loaded &f' + str(inventory.occupied) + '&8/' + "
            "str(inventory.size) + ' &8• &7Capacity &f' + "
            'round(inventory.occupied * 100 / max(inventory.size, 1)) + "%"',
      ),
    ],
  );
}

HuiPreviewDoc _buildRandomBrewingPreview(
  math.Random random,
  _PreviewFurnaceTheme theme,
) {
  final int segments = 7 + random.nextInt(5);
  final int bubbles = 4 + random.nextInt(4);
  final int pulseRate = 2 + random.nextInt(6);
  return HuiPreviewDoc(
    match: HuiPreviewMatch(
      blocks: <String>['BREWING_STAND'],
      priority: 10,
      vars: <String, dynamic>{
        ..._previewThemeVars(theme),
        'title': showcasePick(random, <String>[
          'Jacoby Formula',
          'Blue Rose Distillery',
          'Black Lodge Elixir',
        ]),
        'segments': segments,
        'bubbles': bubbles,
        'pulseRate': pulseRate,
        'panelWidth': 176,
        'panelHeight': 124,
      },
    ),
    card: _previewCard(94),
    elements: <HuiPreviewElement>[
      _previewPanel(),
      HuiPreviewElement('slot', x: 0, y: 24, size: 20, index: 3),
      HuiPreviewElement('slot', x: -54, y: 24, size: 20, index: 4),
      HuiPreviewElement(
        'slot',
        repeat: HuiPreviewRepeat(count: 3, varName: 'bottle'),
        x: '(bottle - 1) * 28',
        y: -14,
        size: 20,
        index: 'bottle',
      ),
      HuiPreviewElement(
        'cell',
        repeat: HuiPreviewRepeat(count: 'vars.segments', varName: 'i'),
        x: 56,
        y: '28 - i * 7',
        size: 5,
        color:
            'i < floor(clamp(1 - brewTime / max(brewTotal, 1), 0, 1) '
            '* vars.segments) ? mix(vars.fill, vars.pulse, '
            '(sin(time / vars.pulseRate + i) + 1) / 2) : vars.wellColor',
      ),
      HuiPreviewElement(
        'cell',
        repeat: HuiPreviewRepeat(count: 'vars.bubbles', varName: 'bubble'),
        x: '-24 + bubble * 8',
        y: '10 + mod(bubble, 3) * 7',
        size: '4 + mod(bubble, 3)',
        color:
            'brewTime > 0 ? palette([vars.fill, vars.pulse, vars.chase], '
            'floor(time / vars.pulseRate) + bubble) : vars.idle',
      ),
      HuiPreviewElement(
        'label',
        x: 0,
        y: -40,
        text:
            "brewTime > 0 ? vars.stateColor + '&lBREWING &f' + "
            'round(clamp(1 - brewTime / max(brewTotal, 1), 0, 1) * 100) '
            "+ '%' : '&7Waiting for a complete recipe'",
      ),
      HuiPreviewElement(
        'label',
        x: 0,
        y: -54,
        text:
            "'&7Fuel &e' + str(fuelLevel) + '&8/' + str(maxFuel) + "
            "' &8• &7Bottles &d' + str((occupied(0) ? 1 : 0) + "
            '(occupied(1) ? 1 : 0) + (occupied(2) ? 1 : 0))',
      ),
    ],
  );
}

HuiPreviewDoc _buildRandomBeehivePreview(
  math.Random random,
  _PreviewFurnaceTheme theme,
) {
  final int columns = 3 + random.nextInt(3);
  final int rows = 2 + random.nextInt(2);
  return HuiPreviewDoc(
    match: HuiPreviewMatch(
      blocks: <String>['BEEHIVE', 'BEE_NEST'],
      priority: 10,
      vars: <String, dynamic>{
        ..._previewThemeVars(theme),
        'title': showcasePick(random, <String>[
          'Ghostwood Apiary',
          'Pearl Lakes Honey',
          'Glastonbury Hive',
        ]),
        'columns': columns,
        'rows': rows,
        'cells': columns * rows,
        'panelWidth': columns * 24 + 52,
        'panelHeight': rows * 22 + 62,
      },
    ),
    variants: <HuiPreviewVariant>[
      HuiPreviewVariant(
        blocks: <String>['BEE_NEST'],
        vars: <String, dynamic>{'title': 'Ghostwood Wild Hive'},
      ),
    ],
    card: _previewCard(82),
    elements: <HuiPreviewElement>[
      _previewPanel(),
      HuiPreviewElement(
        'cell',
        repeat: HuiPreviewRepeat(count: 'vars.cells', varName: 'cell'),
        x: 'round((mod(cell, vars.columns) - (vars.columns - 1) / 2) * 23)',
        y: 'round(((vars.rows - 1) / 2 - floor(cell / vars.columns)) * 21)',
        size: '14 + mod(cell, 2) * 2',
        color:
            'cell < round(honey / max(maxHoney, 1) * vars.cells) '
            '? mix(vars.fill, vars.pulse, (sin(time / 9 + cell) + 1) / 2) '
            ': vars.wellColor',
      ),
      HuiPreviewElement(
        'cell',
        repeat: HuiPreviewRepeat(count: 3, varName: 'bee'),
        x: '-24 + bee * 24',
        y: 'round(vars.rows * 11 + 9)',
        size: 'bee < bees ? 7 : 4',
        color:
            'bee < bees ? palette([vars.chase, vars.fill, vars.pulse], '
            'floor(time / 6) + bee) : vars.idle',
      ),
      HuiPreviewElement(
        'label',
        x: 0,
        y: '-round(vars.rows * 11 + 17)',
        text:
            "vars.stateColor + str(bees) + '&7/' + str(maxBees) + "
            "' bees &8• ' + vars.stateColor + str(honey) + '&7/' + "
            "str(maxHoney) + ' honey'",
      ),
    ],
  );
}

HuiPreviewDoc _buildRandomCauldronPreview(
  math.Random random,
  _PreviewFurnaceTheme theme,
) {
  final int rings = 4 + random.nextInt(4);
  return HuiPreviewDoc(
    match: HuiPreviewMatch(
      blocks: <String>[
        'CAULDRON',
        'WATER_CAULDRON',
        'LAVA_CAULDRON',
        'POWDER_SNOW_CAULDRON',
      ],
      priority: 10,
      vars: <String, dynamic>{
        ..._previewThemeVars(theme),
        'title': 'Sycamore Cauldron',
        'rings': rings,
        'fluidColor': theme.fill,
        'fluidPulse': theme.pulse,
        'panelWidth': 154,
        'panelHeight': 112,
      },
    ),
    variants: <HuiPreviewVariant>[
      HuiPreviewVariant(
        blocks: <String>['WATER_CAULDRON'],
        vars: <String, dynamic>{
          'title': 'Pearl Lakes Water',
          'fluidColor': '#FF3F9DFF',
          'fluidPulse': '#FFB8EDFF',
          'accent': '#5E82FF',
        },
      ),
      HuiPreviewVariant(
        blocks: <String>['LAVA_CAULDRON'],
        vars: <String, dynamic>{
          'title': 'Fire Walk Crucible',
          'fluidColor': '#FFFF6A1A',
          'fluidPulse': '#FFFFE05A',
          'accent': '#FF8A35',
        },
      ),
      HuiPreviewVariant(
        blocks: <String>['POWDER_SNOW_CAULDRON'],
        vars: <String, dynamic>{
          'title': 'Twin Peaks Snow',
          'fluidColor': '#FFCDEBFF',
          'fluidPulse': '#FFFFFFFF',
          'accent': '#CFE6FF',
        },
      ),
    ],
    card: _previewCard(84),
    elements: <HuiPreviewElement>[
      _previewPanel(),
      HuiPreviewElement(
        'cell',
        repeat: HuiPreviewRepeat(count: 'vars.rings', varName: 'ring'),
        x: 'round((ring - (vars.rings - 1) / 2) * 18)',
        y: 6,
        size: '12 + mod(ring, 2) * 4',
        color:
            'ring < ceil(level / max(maxLevel, 1) * vars.rings) '
            '? mix(vars.fluidColor, vars.fluidPulse, '
            '(sin(time / 8 + ring * 1.7) + 1) / 2) : vars.wellColor',
      ),
      HuiPreviewElement(
        'cell',
        repeat: HuiPreviewRepeat(count: 'vars.rings', varName: 'ripple'),
        x: 'round((ripple - (vars.rings - 1) / 2) * 18)',
        y: -14,
        size: 4,
        color:
            'ripple == mod(floor(time / 5), vars.rings) '
            '? vars.fluidPulse : vars.idle',
      ),
      HuiPreviewElement(
        'label',
        x: 0,
        y: -35,
        text:
            "level > 0 ? vars.stateColor + readable(fluid) + ' &f' + "
            "str(level) + '&7/' + str(maxLevel) : '&8Empty vessel'",
      ),
    ],
  );
}

HuiPreviewDoc _buildRandomJukeboxPreview(
  math.Random random,
  _PreviewFurnaceTheme theme,
) {
  final int bars = 7 + random.nextInt(6);
  final int pulseRate = 2 + random.nextInt(5);
  return HuiPreviewDoc(
    match: HuiPreviewMatch(
      blocks: <String>['JUKEBOX'],
      priority: 10,
      vars: <String, dynamic>{
        ..._previewThemeVars(theme),
        'title': showcasePick(random, <String>[
          'Roadhouse Now Playing',
          'Double R Hi-Fi',
          'Black Lodge Broadcast',
        ]),
        'bars': bars,
        'pulseRate': pulseRate,
        'panelWidth': 172,
        'panelHeight': 116,
      },
    ),
    card: _previewCard(92),
    elements: <HuiPreviewElement>[
      _previewPanel(),
      HuiPreviewElement('slot', x: -62, y: 4, size: 24, index: 0),
      HuiPreviewElement(
        'cell',
        repeat: HuiPreviewRepeat(count: 'vars.bars', varName: 'bar'),
        x: '-38 + bar * 8',
        y: 8,
        size: '4 + mod(bar + floor(time / vars.pulseRate), 4) * 2',
        color:
            'playing ? palette([vars.fill, vars.pulse, vars.chase], '
            'floor(time / vars.pulseRate) + bar) : vars.idle',
      ),
      HuiPreviewElement(
        'cell',
        repeat: HuiPreviewRepeat(count: 'vars.bars', varName: 'beat'),
        x: '-38 + beat * 8',
        y: -8,
        size: 4,
        color:
            'playing && beat == mod(floor(time / vars.pulseRate), vars.bars) '
            '? vars.pulse : vars.wellColor',
      ),
      HuiPreviewElement(
        'label',
        x: 0,
        y: -32,
        text:
            "record != '' ? (playing ? vars.stateColor + '&lPLAYING &f' + "
            "readable(record) : '&7Loaded &f' + readable(record)) "
            ": '&8No disc loaded'",
      ),
      HuiPreviewElement(
        'label',
        x: 0,
        y: -46,
        text:
            "playing ? select(['&d♪', '&5♫', '&f◆', '&d♫'], "
            "floor(time / vars.pulseRate)) + ' &7Live from the Roadhouse' "
            ": '&8Player standing by'",
      ),
    ],
  );
}

HuiPreviewDoc _buildRandomEnderPreview(
  math.Random random,
  _PreviewFurnaceTheme theme,
) {
  final int columns = 6 + random.nextInt(3);
  final int rows = 2 + random.nextInt(2);
  return HuiPreviewDoc(
    match: HuiPreviewMatch(
      blocks: <String>['ENDER_CHEST'],
      special: 'enderChest',
      priority: 10,
      vars: <String, dynamic>{
        ..._previewThemeVars(theme),
        'title': showcasePick(random, <String>[
          'Owl Cave Vault',
          'Between Two Worlds',
          'Black Lodge Storage',
        ]),
        'columns': columns,
        'rows': rows,
        'slots': columns * rows,
        'panelWidth': columns * 21 + 38,
        'panelHeight': rows * 21 + 62,
        'portal0': '#FF512A7A',
        'portal1': '#FFB152DA',
        'portal2': '#FF6FEAEA',
      },
    ),
    card: _previewCard(94),
    elements: <HuiPreviewElement>[
      _previewPanel(),
      HuiPreviewElement(
        'cell',
        repeat: HuiPreviewRepeat(count: 12, varName: 'star'),
        x: 'round((mod(star, 6) - 2.5) * 25)',
        y: 'round((floor(star / 6) * 2 - 1) * (vars.rows * 11 + 8))',
        size: '3 + mod(star, 3)',
        color:
            'palette([vars.portal0, vars.portal1, vars.portal2], '
            'floor(time / 5) + star)',
      ),
      HuiPreviewElement(
        'slot',
        repeat: HuiPreviewRepeat(count: 'vars.slots', varName: 'i'),
        x: 'round((mod(i, vars.columns) - (vars.columns - 1) / 2) * 21)',
        y: 'round(((vars.rows - 1) / 2 - floor(i / vars.columns)) * 21)',
        size: 18,
        index: 'i',
        wellColor: 'vars.wellColor',
      ),
      HuiPreviewElement(
        'label',
        x: 0,
        y: '-round(vars.rows * 11 + 19)',
        text:
            "vars.stateColor + str(inventory.occupied) + '&7/' + "
            "str(inventory.size) + ' echoes stored between worlds'",
      ),
    ],
  );
}

HuiPreviewDoc _buildRandomMobilePreview(
  math.Random random,
  _PreviewFurnaceTheme theme,
) {
  final int slots = 5 + random.nextInt(4);
  final int trail = 8 + random.nextInt(5);
  return HuiPreviewDoc(
    match: HuiPreviewMatch(
      entities: <String>[
        'CHEST_MINECART',
        'HOPPER_MINECART',
        '*_CHEST_BOAT',
        '*_CHEST_RAFT',
      ],
      special: 'anyInventoryHolder',
      priority: 10,
      vars: <String, dynamic>{
        ..._previewThemeVars(theme),
        'title': showcasePick(random, <String>[
          'Packard Mill Freight',
          'Ghostwood Night Train',
          'Pearl Lakes Cargo',
        ]),
        'slots': slots,
        'trail': trail,
        'panelWidth': slots * 22 + 44,
        'panelHeight': 106,
      },
    ),
    variants: <HuiPreviewVariant>[
      HuiPreviewVariant(
        entities: <String>['HOPPER_MINECART'],
        vars: <String, dynamic>{'title': 'Packard Transfer Line'},
      ),
    ],
    card: _previewCard(94),
    elements: <HuiPreviewElement>[
      _previewPanel(),
      HuiPreviewElement(
        'cell',
        repeat: HuiPreviewRepeat(count: 'vars.trail', varName: 'rail'),
        x: 'round((rail - (vars.trail - 1) / 2) * 12)',
        y: 26,
        size: 5,
        color:
            'rail == mod(floor(time / 4), vars.trail) ? vars.pulse '
            ': (rail < mod(floor(time / 4), vars.trail) '
            '? vars.fill : vars.idle)',
      ),
      HuiPreviewElement(
        'slot',
        repeat: HuiPreviewRepeat(count: 'vars.slots', varName: 'i'),
        x: 'round((i - (vars.slots - 1) / 2) * 22)',
        y: 0,
        size: 18,
        index: 'i',
        wellColor: 'vars.wellColor',
      ),
      HuiPreviewElement(
        'label',
        x: 0,
        y: -28,
        text:
            "vars.stateColor + '&lIN TRANSIT &8• &7Cargo &f' + "
            "str(inventory.occupied) + '&8/' + str(inventory.size)",
      ),
      HuiPreviewElement(
        'label',
        x: 0,
        y: -42,
        text:
            "select(['&8Departed', '&7Crossing Ghostwood', '&fApproaching', "
            "vars.stateColor + 'Arrived'], floor(time / 20))",
      ),
    ],
  );
}

HuiPreviewDoc _buildRandomVitalsPreview(
  math.Random random,
  _PreviewFurnaceTheme theme,
) {
  final int bars = 9 + random.nextInt(7);
  return HuiPreviewDoc(
    match: HuiPreviewMatch(
      special: 'locked',
      priority: 10,
      vars: <String, dynamic>{
        ..._previewThemeVars(theme),
        'title': showcasePick(random, <String>[
          'Blue Rose Telemetry',
          'Sheriff Station Signal',
          'Great Northern Status',
        ]),
        'bars': bars,
        'panelWidth': 172,
        'panelHeight': 118,
      },
    ),
    card: _previewCard(92),
    elements: <HuiPreviewElement>[
      _previewPanel(),
      HuiPreviewElement(
        'cell',
        repeat: HuiPreviewRepeat(count: 'vars.bars', varName: 'bar'),
        x: 'round((bar - (vars.bars - 1) / 2) * 9)',
        y: 18,
        size: '4 + mod(bar + floor(time / 4), 4)',
        color:
            'palette([vars.fill, vars.pulse, vars.chase, vars.idle], '
            'floor(time / 4) + bar)',
      ),
      HuiPreviewElement(
        'cell',
        repeat: HuiPreviewRepeat(count: 3, varName: 'signal'),
        x: '-24 + signal * 24',
        y: -4,
        size: '8 + signal * 2',
        color:
            'mix(vars.fill, vars.pulse, '
            '(sin(time / (5 + signal * 2)) + 1) / 2)',
      ),
      HuiPreviewElement(
        'label',
        x: 0,
        y: -28,
        text:
            "vars.stateColor + '&lLIVE &8• &7TPS &a' + fixed(server.tps, 1) "
            "+ ' &8• &7Ping &f' + str(player.ping) + 'ms'",
      ),
      HuiPreviewElement(
        'label',
        x: 0,
        y: -43,
        text:
            "'&7Online &f' + str(server.online) + '&8/' + "
            "str(server.maxPlayers) + ' &8• &7Agent &f' + player.name",
      ),
    ],
  );
}

Map<String, dynamic> _previewThemeVars(_PreviewFurnaceTheme theme) =>
    <String, dynamic>{
      'panelColor': theme.panelColor,
      'wellColor': theme.wellColor,
      'fill': theme.fill,
      'pulse': theme.pulse,
      'chase': theme.chase,
      'idle': theme.idle,
      'stateColor': theme.stateColor,
      'accent': theme.accent,
    };

HuiPreviewCard _previewCard(int minHalfWidth) => HuiPreviewCard(
  title: "'&f&l' + vars.title",
  accent: 'vars.accent',
  minHalfWidth: minHalfWidth,
);

HuiPreviewElement _previewPanel() => HuiPreviewElement(
  'panel',
  x: 0,
  y: -4,
  width: 'vars.panelWidth',
  height: 'vars.panelHeight',
  color: 'vars.panelColor',
);

GlossHologramDoc buildRandomHologramShowcase(
  GlossHologramDoc current,
  math.Random random,
) {
  final ShowcaseMood mood = showcasePick(random, showcaseMoods);
  final String server = showcasePick(random, showcaseServerNames);
  final ShowcaseEffect color = showcaseColorEffect(random, mood);
  final List<String> lines = <String>[
    '${color.text}&l$server',
    '&7Hello, &f{{ player.name }}&7!',
    "&7Health {{ player.health < 7 ? '&c' : '&a' }}"
        "{{ bar(player.health, 20, 10, '■', '□') }}",
    '&7TPS &a{{ fixed(server.tps, 1) }} &8• &7'
        '${showcasePick(random, showcaseEvents)}',
    '${mood.legacy}${showcasePick(random, mood.glyphs)} '
        '&7${showcasePick(random, showcaseHologramNotes)}',
    showcaseEasterEgg(random),
  ];
  switch (random.nextInt(3)) {
    case 0:
      lines.insert(
        2,
        '${showcaseScanline(random, mood).text} &f'
        '${showcasePick(random, showcaseHeadlines)}',
      );
    case 1:
      lines.insert(
        2,
        '&f${showcaseTypewriter(random, showcasePick(random, showcaseHeadlines)).text}',
      );
    default:
      lines.insert(
        2,
        showcaseWave(random, showcasePick(random, showcaseAnimationWords)).text,
      );
  }
  return GlossHologramDoc(
    schemaVersion: current.schemaVersion,
    revision: current.revision,
    anchor: GlossHologramAnchor(
      world: showcasePick(random, showcaseWorlds),
      positionRaw: <num>[
        random.nextInt(401) - 200,
        64 + random.nextInt(48),
        random.nextInt(401) - 200,
      ],
    ),
    lines: lines,
  );
}

GlossAnimationDoc buildRandomAnimationShowcase(
  GlossAnimationDoc current,
  math.Random random,
) {
  final ShowcaseMood mood = showcasePick(random, showcaseMoods);
  final String word = showcasePick(random, showcaseAnimationWords);
  final ({String mode, int intervalMs, List<String> frames}) built =
      showcaseAnimationFrames(random, mood, word);
  return GlossAnimationDoc(
    schemaVersion: current.schemaVersion,
    revision: current.revision,
    mode: built.mode,
    frameIntervalMs: built.intervalMs,
    frames: built.frames,
  );
}

GlossScoreboardDoc buildRandomScoreboardShowcase(
  GlossScoreboardDoc current,
  math.Random random,
) {
  final ShowcaseMood mood = showcasePick(random, showcaseMoods);
  final String server = showcasePick(random, showcaseServerNames);
  final String rank = showcasePick(random, showcaseRanks);
  final List<String> lines = <String>[
    '&7Player &f{{ player.name }}',
    "&7Rank {{ papi('vault_prefix', '${mood.legacy}$rank') }}",
    '',
    "&7Ping {{ player.ping < 80 ? '&a' : "
        "player.ping < 160 ? '&e' : '&c' }}{{ player.ping }}ms",
    "&7Health &a{{ bar(player.health, 20, 8, '■', '□') }}",
    '&7Online &a{{ server.online }}&8/&a{{ server.maxPlayers }}',
    '&7TPS &a{{ fixed(server.tps, 1) }}',
    "&7Tick &f{{ fixed(metric('react.tick-ms', 1000 / server.tps), 1) }}ms",
    '',
    '${showcaseTickPrefix(random, mood).text}&l'
        '${showcasePick(random, showcaseStatusWords)}',
    '&7${showcasePick(random, showcaseEvents)}',
    showcaseBoardEasterEgg(random),
    '&8${showcasePick(random, showcaseDomains)}',
  ];
  if (random.nextBool()) {
    lines.insert(
      8,
      "&7Balance &6\$"
      "{{ fixed(papiNumber('vault_eco_balance', 0), 2) }}",
    );
  }
  if (random.nextBool()) {
    lines.insert(2, '${mood.legacy}${mood.name}&8 style');
  }
  return GlossScoreboardDoc(
    schemaVersion: current.schemaVersion,
    revision: current.revision,
    title: '${mood.legacy}&l${server.toUpperCase()}',
    lines: lines,
    primary: random.nextBool(),
    hideNumbers: true,
    permission: random.nextBool() ? 'default' : 'vip',
    groups: random.nextBool() ? <String>['vip', 'mvp'] : <String>[],
  );
}

GlossMotdDoc buildRandomMotdShowcase(GlossMotdDoc current, math.Random random) {
  final ShowcaseMood mood = showcasePick(random, showcaseMoods);
  final int count = 3 + random.nextInt(4);
  final String server = showcasePick(random, showcaseServerNames);
  final int easterIndex = random.nextInt(count);
  final List<GlossMotdEntry> entries = <GlossMotdEntry>[];
  for (int index = 0; index < count; index++) {
    final List<String> lines = <String>[
      '${showcaseColorEffect(random, mood).text}&l$server &8• &7'
          '${showcasePick(random, showcaseEvents)}',
    ];
    if (index != count - 1) {
      lines.add(
        index == easterIndex
            ? showcaseEasterEgg(random)
            : index.isEven
            ? '&8${showcasePick(random, showcaseHeadlines)}'
            : "&7Online &a{{ server.online }}&8/&a{{ server.maxPlayers }} "
                  '&8• &7${showcasePick(random, showcaseDomains)}',
      );
    }
    entries.add(GlossMotdEntry(lines: lines));
  }
  return GlossMotdDoc(
    schemaVersion: current.schemaVersion,
    revision: current.revision,
    entries: entries,
  );
}

GlossEmojiDoc buildRandomEmojiShowcase(
  GlossEmojiDoc current,
  math.Random random,
) {
  final (String, String) choice = showcasePick(random, _emojiChoices);
  return GlossEmojiDoc(
    schemaVersion: current.schemaVersion,
    revision: current.revision,
    trigger: choice.$1,
    emoji: choice.$2,
    enabled: true,
  );
}

/// Chat shorthands a town like this one would actually register.
const List<(String, String)> _emojiChoices = <(String, String)>[
  ('<3', 'U+2764;'),
  (':)', 'U+1F60A;'),
  ('*', 'U+2728;'),
  ('gg', 'U+1F3C6;'),
  (':coffee:', 'U+2615;'),
  (':pie:', 'U+1F967;'),
  (':cherry:', 'U+1F352;'),
  (':owl:', 'U+1F989;'),
  (':log:', 'U+1FAB5;'),
  (':fire:', 'U+1F525;'),
  (':ring:', 'U+1F48D;'),
  (':curtain:', 'U+1F3AD;'),
  (':pine:', 'U+1F332;'),
  (':moon:', 'U+1F319;'),
  (':record:', 'U+1F4BF;'),
  (':phone:', 'U+260E;'),
  (':key:', 'U+1F511;'),
  (':donut:', 'U+1F369;'),
  (':fish:', 'U+1F41F;'),
  (':star:', 'U+2B50;'),
];

GlossBubbleStyleDoc buildRandomBubbleShowcase(
  GlossBubbleStyleDoc current,
  math.Random random,
) {
  final ShowcaseMood mood = showcasePick(random, showcaseMoods);
  return GlossBubbleStyleDoc(
    schemaVersion: current.schemaVersion,
    revision: current.revision,
    prefix:
        '${showcaseColorEffect(random, mood).text}'
        '${showcasePick(random, _formatCodes)}',
    offsetRaw: <num>[
      _round((random.nextDouble() - 0.5) * 1.2),
      _round(1.2 + random.nextDouble() * 1.4),
      _round((random.nextDouble() - 0.5) * 0.8),
    ],
    wordWrapChars: 36 + random.nextInt(73),
    maxAliveMs: 9000 + random.nextInt(21001),
    motion: _randomBubbleMotion(random),
    shimmer: _randomBubbleShimmer(random, mood),
    followPlayer: random.nextBool(),
    hideOwn: random.nextBool(),
    select: GlossBubbleSelect(
      worlds: <String>['world*', 'twin_peaks*'],
      groups: <String>['owner', 'developer', 'vip'],
      priority: 10 + random.nextInt(41),
    ),
  );
}

GlossBubbleShimmer _randomBubbleShimmer(math.Random random, ShowcaseMood mood) {
  final int durationMs = 450 + random.nextInt(1051);
  return GlossBubbleShimmer(
    spawn: true,
    flyAway: true,
    color: showcasePick(random, <String>[
      '#ffffff',
      mood.primary.toLowerCase(),
      mood.secondary.toLowerCase(),
    ]),
    width: 2 + random.nextInt(6),
    durationMs: durationMs,
    spawnDelayMs: random.nextInt(251),
    flyAwayLeadMs: durationMs + random.nextInt(501),
  );
}

GlossBubbleMotion _randomBubbleMotion(math.Random random) {
  final double travel = _round(2.5 + random.nextDouble() * 5.5);
  final double lift = _round(3.5 + random.nextDouble() * 7.5);
  final double fall = _round(2.0 + random.nextDouble() * 8.0);
  final double spin = _round(90 + random.nextDouble() * 630);
  final double shrink = _round(0.35 + random.nextDouble() * 0.6);
  final int mode = random.nextInt(4);
  return switch (mode) {
    0 => GlossBubbleMotion(
      translation: GlossBubbleMotionVector(
        x: '$travel * t',
        y: '$lift * sin(pi * t) - $fall * t',
        z: '${_round(travel / 2)} * sin(pi * 2 * t + seed * pi)',
      ),
      scale: GlossBubbleMotionVector(
        x: '1 - $shrink * smoothstep(0.5, 1, t)',
        y: '1 - $shrink * smoothstep(0.5, 1, t)',
        z: '1 - $shrink * smoothstep(0.5, 1, t)',
      ),
      rotation: GlossBubbleMotionVector(
        x: '${_round(spin / 4)} * t',
        y: '${_round(spin / 2)} * t',
        z: '$spin * t',
      ),
      opacity: '1 - smoothstep(0.72, 1, t)',
    ),
    1 => GlossBubbleMotion(
      translation: GlossBubbleMotionVector(
        x: '0.12 * (lineCount - 1) * sin(pi * 2 * t + seed * pi)',
        y: '$lift * smoothstep(0, 1, t)',
        z: '${_round(travel / 3)} * sin(pi * t)',
      ),
      scale: GlossBubbleMotionVector.scaleDefaults(),
      rotation: GlossBubbleMotionVector(
        x: '0',
        y: '${_round(spin / 3)} * t',
        z: '${_round(spin / 8)} * sin(pi * 2 * t)',
      ),
      opacity: '1 - smoothstep(0.6, 1, t)',
    ),
    2 => GlossBubbleMotion(
      translation: GlossBubbleMotionVector(
        x: '${_round(travel / 2)} * sin(pi * 2 * t + seed * pi * 2)',
        y: '${_round(lift / 2)} * t + 0.08 * stackY',
        z: '${_round(travel / 2)} * cos(pi * 2 * t + seed * pi * 2)',
      ),
      scale: GlossBubbleMotionVector(
        x: '1 - $shrink * smoothstep(0.35, 1, t)',
        y: '1 - $shrink * smoothstep(0.35, 1, t)',
        z: '1 - $shrink * smoothstep(0.35, 1, t)',
      ),
      rotation: GlossBubbleMotionVector(
        x: '$spin * t',
        y: '${_round(spin / 2)} * t',
        z: '${_round(0 - spin)} * t',
      ),
      opacity: '1',
    ),
    _ => GlossBubbleMotion(
      translation: GlossBubbleMotionVector(
        x: '$travel * (t - smoothstep(0.55, 1, t))',
        y: '$lift * sin(pi * t) - $fall * pow(t, 3)',
        z: '${_round(travel / 4)} * sin(pi * 4 * t + stackIndex)',
      ),
      scale: GlossBubbleMotionVector(
        x: '1 + 0.18 * sin(pi * 4 * t)',
        y: '1 - 0.25 * t',
        z: '1 + 0.18 * cos(pi * 4 * t)',
      ),
      rotation: GlossBubbleMotionVector(
        x: '${_round(spin / 5)} * sin(pi * 2 * t)',
        y: '$spin * t',
        z: '${_round(spin / 3)} * t',
      ),
      opacity: 'smoothstep(0, 0.08, t) * (1 - smoothstep(0.82, 1, t))',
    ),
  };
}

GlossTablistDoc buildRandomTablistShowcase(
  GlossTablistDoc current,
  math.Random random,
) {
  final ShowcaseMood mood = showcasePick(random, showcaseMoods);
  final String server = showcasePick(random, showcaseServerNames);
  final String easterEgg = showcaseEasterEgg(random);
  return GlossTablistDoc(
    schemaVersion: current.schemaVersion,
    revision: current.revision,
    useHeaderFooter: true,
    header:
        '${showcaseColorEffect(random, mood).text}&l$server\n'
        "&7Welcome &f{{ player.name }} &8• "
        "{{ papi('vault_prefix', '&7Member') }} &8• "
        "{{ player.ping < 100 ? '&a' : '&e' }}{{ player.ping }}ms\n"
        '&7Online &a{{ server.online }}&8/&a{{ server.maxPlayers }} '
        '&8• &7TPS &a{{ fixed(server.tps, 1) }}',
    footer:
        '$easterEgg\n'
        '&8${showcasePick(random, showcaseHeadlines)}\n'
        '${showcaseTickPrefix(random, mood).text}'
        '&7${showcasePick(random, showcaseEvents)} &8• &b'
        '${showcasePick(random, showcaseDomains)}',
    groupListNames: true,
    nameFormats: <String, String>{
      'default': r'&7[Townsfolk] &f$player',
      '_op': '${showcaseColorEffect(random, mood).text}&l[Founder] &f\$player',
      'owner': '${mood.legacy}&l[Lodge Keeper] &f\$player',
      'developer': r'&b[Bookhouse] &f$player',
      'moderator': r'&a[Deputy] &f$player',
      'vip': '${mood.legacy}[\$group] &f\$player',
    },
  );
}

/// A coherent character for the drop settings, so one press gives a look
/// rather than five sliders of noise. Every band stays inside the ranges
/// `real_drop_validation.dart` reports on.
enum RealDropShowcaseArchetype {
  ricochet,
  groundRoll,
  buoyant,
  hoverRelease,
  materialReactive,
}

final class _DropProfile {
  const _DropProfile({
    required this.archetype,
    required this.tumble,
    required this.speed,
    required this.rate,
    required this.landing,
    required this.tilt,
    required this.scale,
    required this.labels,
    required this.spread,
  });

  final RealDropShowcaseArchetype archetype;
  final bool tumble;

  /// `motion.speedMultiplier` band.
  final (double, double) speed;

  /// Band each `motion.degreesPerSecond*` is drawn from.
  final (double, double) rate;

  final String landing;

  /// `landing.tiltDegrees` band.
  final (double, double) tilt;

  /// `scale.defaultScale` band; the other two families follow it.
  final (double, double) scale;

  /// `labels.scale` band, or null for a stage with no labels at all.
  final (double, double)? labels;

  final (double, double) spread;
}

const List<_DropProfile> _dropProfiles = <_DropProfile>[
  // Slow, upright, oversized labels: loot you are meant to read from across
  // the room.
  _DropProfile(
    archetype: RealDropShowcaseArchetype.hoverRelease,
    tumble: true,
    speed: (0.3, 0.8),
    rate: (30, 90),
    landing: 'UPRIGHT',
    tilt: (0, 6),
    scale: (0.45, 0.7),
    labels: (1.0, 1.6),
    spread: (0.2, 0.45),
  ),
  // Fast and chaotic, the way a mined stack scatters.
  _DropProfile(
    archetype: RealDropShowcaseArchetype.ricochet,
    tumble: true,
    speed: (1.6, 3.2),
    rate: (200, 520),
    landing: 'NATURAL',
    tilt: (12, 32),
    scale: (0.3, 0.5),
    labels: (0.6, 0.9),
    spread: (0.35, 0.85),
  ),
  // Everything lies flat and close: a tidy counter of items.
  _DropProfile(
    archetype: RealDropShowcaseArchetype.materialReactive,
    tumble: false,
    speed: (0.5, 1.2),
    rate: (0, 40),
    landing: 'FLAT',
    tilt: (0, 4),
    scale: (0.5, 0.9),
    labels: (0.7, 1.0),
    spread: (0.05, 0.2),
  ),
  // No labels, small models, quiet ground clutter.
  _DropProfile(
    archetype: RealDropShowcaseArchetype.buoyant,
    tumble: true,
    speed: (0.6, 1.4),
    rate: (60, 200),
    landing: 'NATURAL',
    tilt: (4, 14),
    scale: (0.18, 0.32),
    labels: null,
    spread: (0.1, 0.3),
  ),
  // The shipped feel, widened: fast tumble, natural landing, readable labels.
  _DropProfile(
    archetype: RealDropShowcaseArchetype.groundRoll,
    tumble: true,
    speed: (1.0, 1.9),
    rate: (90, 260),
    landing: 'NATURAL',
    tilt: (6, 18),
    scale: (0.35, 0.55),
    labels: (0.75, 1.1),
    spread: (0.12, 0.4),
  ),
];

GlossRealDropSettingsDoc buildRandomRealDropShowcase(
  GlossRealDropSettingsDoc current,
  math.Random random, {
  RealDropShowcaseArchetype? archetype,
}) {
  final ShowcaseMood mood = showcasePick(random, showcaseMoods);
  final _DropProfile profile = archetype == null
      ? showcasePick(random, _dropProfiles)
      : _dropProfiles.firstWhere(
          (_DropProfile candidate) => candidate.archetype == archetype,
        );
  final GlossRealDropSettingsDoc doc = current.copy();

  doc.limits
    ..updateIntervalTicks = 1 + random.nextInt(4)
    ..settledPollIntervalTicks = 10 + random.nextInt(51)
    ..maxVisualsPerStack = 1 + random.nextInt(glossRealDropOffsets.length)
    ..maxVisualsPerChunk = 32 + random.nextInt(225)
    ..viewRange = _band(random, (16, 64), 0)
    ..spread = _band(random, profile.spread, 2);

  final double base = _band(random, profile.scale, 2);
  doc.scale
    ..defaultScale = base
    ..flatItems = _round2(
      (base * (1.3 + random.nextDouble() * 0.6)).clamp(0.05, 2),
    )
    ..thinBlocks = _round2(
      (base * (0.8 + random.nextDouble() * 0.5)).clamp(0.05, 2),
    );

  doc.motion
    ..tumble = profile.tumble
    ..speedMultiplier = _band(random, profile.speed, 2)
    ..degreesPerSecondX = _band(random, profile.rate, 0)
    ..degreesPerSecondY = _band(random, profile.rate, 0)
    ..degreesPerSecondZ = _band(random, profile.rate, 0)
    ..variance = _round2(random.nextDouble() * 0.8)
    ..changeOnBounce = random.nextBool();

  doc.landing
    ..mode = profile.landing
    ..tiltDegrees = _band(random, profile.tilt, 0)
    ..randomYaw = random.nextBool()
    ..transitionTicks = random.nextInt(13);

  final (double, double)? labelScale = profile.labels;
  final List<int> tint = _moodTint(mood, random);
  doc.labels
    ..enabled = labelScale != null
    ..yOffset = _round2(0.2 + random.nextDouble() * 1.1)
    ..scale = labelScale == null ? 0.85 : _band(random, labelScale, 2)
    ..viewRange = _band(random, (12, 48), 0)
    ..billboard = showcasePick(random, const <String>[
      'CENTER',
      'CENTER',
      'VERTICAL',
      'HORIZONTAL',
      'FIXED',
    ])
    ..seeThrough = random.nextBool()
    ..shadow = random.nextBool()
    ..background = random.nextInt(4) != 0
    ..backgroundRed = tint[0]
    ..backgroundGreen = tint[1]
    ..backgroundBlue = tint[2]
    ..backgroundAlpha = 32 + random.nextInt(180);

  doc.filters
    ..onlyPlayerDrops = random.nextInt(4) == 0
    ..disabledWorlds = random.nextBool()
        ? <String>[]
        : <String>[showcasePick(random, showcaseWorlds)]
    ..materialBlacklist = showcasePick(random, const <List<String>>[
      <String>['BEDROCK', 'BARRIER'],
      <String>['BEDROCK', 'BARRIER', 'LIGHT', 'STRUCTURE_VOID'],
      <String>['BEDROCK', 'BARRIER', 'COBBLESTONE', 'DIRT'],
      <String>['BEDROCK'],
    ]);

  _applyDropArchetype(doc, profile.archetype, random);
  doc.physics = _buildDropPhysics(profile.archetype, random);
  doc.script = _buildDropScript(profile.archetype, mood, random);
  doc.animation = _buildDropAnimation(profile.archetype, mood, random);

  return doc;
}

void _applyDropArchetype(
  GlossRealDropSettingsDoc doc,
  RealDropShowcaseArchetype archetype,
  math.Random random,
) {
  switch (archetype) {
    case RealDropShowcaseArchetype.ricochet:
      doc.motion
        ..velocityInfluence = _band(random, (1.1, 2.4), 2)
        ..submergedSpinMultiplier = _band(random, (0.2, 0.5), 2)
        ..groundRollMultiplier = _band(random, (1.2, 2.4), 2);
      doc.landing
        ..faceAttraction = _band(random, (0.35, 0.6), 2)
        ..movingFaceAttraction = _band(random, (0.05, 0.2), 2)
        ..alignmentDegrees = _band(random, (0.25, 0.8), 2)
        ..settleDelayTicks = 3 + random.nextInt(6);
    case RealDropShowcaseArchetype.groundRoll:
      doc.motion
        ..velocityInfluence = _band(random, (0.7, 1.6), 2)
        ..submergedSpinMultiplier = _band(random, (0.2, 0.45), 2)
        ..groundRollMultiplier = _band(random, (1.4, 3.2), 2);
      doc.landing
        ..faceAttraction = _band(random, (0.45, 0.75), 2)
        ..movingFaceAttraction = _band(random, (0.04, 0.18), 2)
        ..alignmentDegrees = _band(random, (0.2, 0.65), 2)
        ..settleDelayTicks = 4 + random.nextInt(7);
    case RealDropShowcaseArchetype.buoyant:
      doc.motion
        ..velocityInfluence = _band(random, (0.3, 0.9), 2)
        ..submergedSpinMultiplier = _band(random, (0.08, 0.3), 2)
        ..groundRollMultiplier = _band(random, (0.6, 1.3), 2);
      doc.landing
        ..faceAttraction = _band(random, (0.45, 0.7), 2)
        ..movingFaceAttraction = _band(random, (0.08, 0.22), 2)
        ..alignmentDegrees = _band(random, (0.35, 1.0), 2)
        ..settleDelayTicks = 3 + random.nextInt(6);
    case RealDropShowcaseArchetype.hoverRelease:
      doc.motion
        ..velocityInfluence = _band(random, (0.5, 1.2), 2)
        ..submergedSpinMultiplier = _band(random, (0.15, 0.4), 2)
        ..groundRollMultiplier = _band(random, (0.7, 1.5), 2);
      doc.landing
        ..faceAttraction = _band(random, (0.55, 0.82), 2)
        ..movingFaceAttraction = _band(random, (0.08, 0.24), 2)
        ..alignmentDegrees = _band(random, (0.2, 0.7), 2)
        ..settleDelayTicks = 3 + random.nextInt(5);
    case RealDropShowcaseArchetype.materialReactive:
      doc.motion
        ..velocityInfluence = _band(random, (0.2, 0.8), 2)
        ..submergedSpinMultiplier = _band(random, (0.1, 0.35), 2)
        ..groundRollMultiplier = _band(random, (0.4, 1.0), 2);
      doc.landing
        ..faceAttraction = _band(random, (0.6, 0.88), 2)
        ..movingFaceAttraction = _band(random, (0.12, 0.3), 2)
        ..alignmentDegrees = _band(random, (0.15, 0.55), 2)
        ..settleDelayTicks = 2 + random.nextInt(5);
  }
}

GlossRealDropPhysics _buildDropPhysics(
  RealDropShowcaseArchetype archetype,
  math.Random random,
) => switch (archetype) {
  RealDropShowcaseArchetype.ricochet => GlossRealDropPhysics(
    enabled: true,
    gravityMultiplier: _band(random, (0.8, 1.35), 2),
    bounce: _band(random, (0.5, 0.82), 2),
    waterBuoyancy: _band(random, (0, 0.12), 2),
    waterDrag: _band(random, (0.05, 0.25), 2),
  ),
  RealDropShowcaseArchetype.groundRoll => GlossRealDropPhysics(
    enabled: true,
    gravityMultiplier: _band(random, (0.9, 1.45), 2),
    bounce: _band(random, (0.04, 0.18), 2),
    waterBuoyancy: _band(random, (0, 0.1), 2),
    waterDrag: _band(random, (0.1, 0.35), 2),
  ),
  RealDropShowcaseArchetype.buoyant => GlossRealDropPhysics(
    enabled: true,
    gravityMultiplier: _band(random, (0.55, 0.95), 2),
    bounce: _band(random, (0.08, 0.25), 2),
    waterBuoyancy: _band(random, (0.18, 0.48), 2),
    waterDrag: _band(random, (0.35, 0.78), 2),
  ),
  RealDropShowcaseArchetype.hoverRelease => GlossRealDropPhysics(
    enabled: true,
    gravityMultiplier: _band(random, (0.8, 1.15), 2),
    bounce: _band(random, (0.12, 0.34), 2),
    waterBuoyancy: _band(random, (0.05, 0.2), 2),
    waterDrag: _band(random, (0.18, 0.45), 2),
  ),
  RealDropShowcaseArchetype.materialReactive => GlossRealDropPhysics(
    enabled: true,
    gravityMultiplier: _band(random, (0.85, 1.25), 2),
    bounce: _band(random, (0.08, 0.3), 2),
    waterBuoyancy: _band(random, (0, 0.15), 2),
    waterDrag: _band(random, (0.1, 0.4), 2),
  ),
};

GlossRealDropScript _buildDropScript(
  RealDropShowcaseArchetype archetype,
  ShowcaseMood mood,
  math.Random random,
) {
  final double rate = _band(random, (1.6, 4.8), 2);
  final double amplitude = _band(random, (0.04, 0.18), 2);
  final String glow = mood.primary;
  switch (archetype) {
    case RealDropShowcaseArchetype.ricochet:
      return GlossRealDropScript(
        enabled: true,
        vars: <GlossRealDropScriptVar>[
          GlossRealDropScriptVar(
            name: 'energy',
            expression: 'min(1, impactSpeed * ${_band(random, (1.4, 2.8), 2)})',
          ),
          GlossRealDropScriptVar(
            name: 'wobble',
            expression: 'sin(t * $rate + index * 0.8)',
          ),
        ],
        offset: GlossRealDropScriptAxis(
          neutral: '0',
          y: 'onGround ? energy * (wobble + 1) * $amplitude : 0',
        ),
        rotation: GlossRealDropScriptAxis(
          neutral: '0',
          z: 'wobble * ${_band(random, (8, 24), 1)}',
        ),
        scale: GlossRealDropScriptAxis(
          neutral: '1',
          x: '1 + energy * $amplitude',
          y: '1 - energy * $amplitude',
          z: '1 + energy * $amplitude',
        ),
        glow: "materialMatches('*_PICKAXE') ? $glow : 0",
      );
    case RealDropShowcaseArchetype.groundRoll:
      return GlossRealDropScript(
        enabled: true,
        vars: <GlossRealDropScriptVar>[
          GlossRealDropScriptVar(
            name: 'spacing',
            expression: 'index - (count - 1) / 2',
          ),
          GlossRealDropScriptVar(
            name: 'rollPulse',
            expression: 'sin(stateTime * $rate + index)',
          ),
        ],
        offset: GlossRealDropScriptAxis(
          neutral: '0',
          x: 'settled ? spacing * $amplitude : 0',
          y: 'onGround ? (rollPulse + 1) * ${_round2(amplitude / 3)} : 0',
        ),
        rotation: GlossRealDropScriptAxis(
          neutral: '0',
          y: 'settled ? spacing * ${_band(random, (4, 14), 1)} : 0',
        ),
        scale: GlossRealDropScriptAxis(neutral: '1'),
      );
    case RealDropShowcaseArchetype.buoyant:
      return GlossRealDropScript(
        enabled: true,
        vars: <GlossRealDropScriptVar>[
          GlossRealDropScriptVar(
            name: 'drift',
            expression: 't * $rate + index * 1.7',
          ),
          GlossRealDropScriptVar(name: 'bob', expression: 'sin(drift)'),
        ],
        offset: GlossRealDropScriptAxis(
          neutral: '0',
          x: 'inWater ? cos(drift) * $amplitude : 0',
          y: 'inWater ? bob * ${_round2(amplitude * 1.5)} : 0',
          z: 'inWater ? sin(drift * 0.7) * $amplitude : 0',
        ),
        rotation: GlossRealDropScriptAxis(
          neutral: '0',
          y: 'inWater ? bob * ${_band(random, (10, 28), 1)} : 0',
        ),
        scale: GlossRealDropScriptAxis(
          neutral: '1',
          x: 'inWater ? 1 + bob * ${_round2(amplitude / 2)} : 1',
          z: 'inWater ? 1 - bob * ${_round2(amplitude / 2)} : 1',
        ),
        glow: "materialMatches('*_LANTERN') ? $glow : 0",
      );
    case RealDropShowcaseArchetype.hoverRelease:
      return GlossRealDropScript(
        enabled: true,
        vars: <GlossRealDropScriptVar>[
          GlossRealDropScriptVar(
            name: 'orbit',
            expression: 't * $rate + index * 2.1',
          ),
          GlossRealDropScriptVar(
            name: 'lift',
            expression: '(sin(orbit) + 1) * $amplitude',
          ),
        ],
        offset: GlossRealDropScriptAxis(
          neutral: '0',
          x: 'cos(orbit) * $amplitude',
          y: 'lift',
          z: 'sin(orbit) * $amplitude',
        ),
        rotation: GlossRealDropScriptAxis(
          neutral: '0',
          y: 't * ${_band(random, (45, 120), 0)}',
        ),
        scale: GlossRealDropScriptAxis(
          neutral: '1',
          x: '1 + sin(orbit) * ${_round2(amplitude / 2)}',
          z: '1 - sin(orbit) * ${_round2(amplitude / 2)}',
        ),
        glow: "materialMatches('DIAMOND*') ? $glow : 0",
      );
    case RealDropShowcaseArchetype.materialReactive:
      return GlossRealDropScript(
        enabled: true,
        vars: <GlossRealDropScriptVar>[
          GlossRealDropScriptVar(
            name: 'rarity',
            expression:
                "materialMatches('DIAMOND*') ? 1 : "
                "(materialMatches('*_LANTERN') ? 0.7 : 0.25)",
          ),
          GlossRealDropScriptVar(
            name: 'pulse',
            expression: '(sin(t * $rate + index) + 1) / 2',
          ),
        ],
        offset: GlossRealDropScriptAxis(
          neutral: '0',
          y: 'settled ? pulse * rarity * $amplitude : 0',
        ),
        rotation: GlossRealDropScriptAxis(
          neutral: '0',
          y: 'settled ? pulse * rarity * ${_band(random, (8, 22), 1)} : 0',
        ),
        scale: GlossRealDropScriptAxis(
          neutral: '1',
          x: '1 + pulse * rarity * ${_round2(amplitude / 2)}',
          y: '1 + pulse * rarity * ${_round2(amplitude / 2)}',
          z: '1 + pulse * rarity * ${_round2(amplitude / 2)}',
        ),
        glow: 'rarity > 0.6 ? $glow : 0',
        visible: "materialIs('BARRIER') == false",
      );
  }
}

GlossRealDropAnimation _buildDropAnimation(
  RealDropShowcaseArchetype archetype,
  ShowcaseMood mood,
  math.Random random,
) {
  const String radianceMap = 'radiance';
  const String treasureMap = 'treasure';
  final Map<String, Map<String, GlossRealDropMaterialProperties>> maps =
      <String, Map<String, GlossRealDropMaterialProperties>>{
        radianceMap: <String, GlossRealDropMaterialProperties>{
          'SEA_LANTERN': GlossRealDropMaterialProperties(
            glow: _argb('#CFE6FF'),
            lightLevel: 15,
          ),
          '*_LANTERN': GlossRealDropMaterialProperties(
            glow: _argb(mood.secondary),
            lightLevel: 14,
          ),
          '*_CANDLE': GlossRealDropMaterialProperties(
            glow: _argb(mood.primary),
            lightLevel: 11,
          ),
          '*': GlossRealDropMaterialProperties(),
        },
      };
  if (archetype == RealDropShowcaseArchetype.materialReactive ||
      archetype == RealDropShowcaseArchetype.hoverRelease) {
    maps[treasureMap] = <String, GlossRealDropMaterialProperties>{
      'DIAMOND*': GlossRealDropMaterialProperties(
        glow: _argb(mood.secondary),
        lightLevel: 9,
      ),
      '*_PICKAXE': GlossRealDropMaterialProperties(
        glow: _argb(mood.primary),
        lightLevel: 6,
      ),
      'TRIDENT': GlossRealDropMaterialProperties(
        glow: _argb('#55FFFF'),
        lightLevel: 8,
      ),
      '*': GlossRealDropMaterialProperties(),
    };
  }

  final List<GlossRealDropAnimationClip> base = _dropAnimationClips(
    archetype,
    random,
  );
  final List<GlossRealDropAnimationProfile> profiles =
      <GlossRealDropAnimationProfile>[];
  switch (archetype) {
    case RealDropShowcaseArchetype.ricochet:
      profiles.add(
        GlossRealDropAnimationProfile(
          id: 'ricochet',
          materials: <String>['*'],
          clips: <GlossRealDropAnimationClip>[
            ...base,
            _materialPulseClip(
              GlossRealDropAnimationTrigger.bounce,
              radianceMap,
              random,
            ),
          ],
        ),
      );
    case RealDropShowcaseArchetype.groundRoll:
      profiles
        ..add(
          GlossRealDropAnimationProfile(
            id: 'rolling-blocks',
            priority: 20,
            materials: <String>['*_LOG', '*_SLAB', 'COBBLESTONE', 'STONE'],
            clips: <GlossRealDropAnimationClip>[
              ...base,
              _materialPulseClip(
                GlossRealDropAnimationTrigger.settle,
                radianceMap,
                random,
              ),
            ],
          ),
        )
        ..add(
          GlossRealDropAnimationProfile(
            id: 'rolling-fallback',
            materials: <String>['*'],
            clips: base,
          ),
        );
    case RealDropShowcaseArchetype.buoyant:
      profiles
        ..add(
          GlossRealDropAnimationProfile(
            id: 'buoyant-lights',
            priority: 30,
            materials: <String>['*_LANTERN', '*_CANDLE', 'SEA_LANTERN'],
            clips: <GlossRealDropAnimationClip>[
              ...base,
              _materialPulseClip(
                GlossRealDropAnimationTrigger.enterFluid,
                radianceMap,
                random,
              ),
            ],
          ),
        )
        ..add(
          GlossRealDropAnimationProfile(
            id: 'buoyant-fallback',
            materials: <String>['*'],
            clips: base,
          ),
        );
    case RealDropShowcaseArchetype.hoverRelease:
      profiles
        ..add(
          GlossRealDropAnimationProfile(
            id: 'hover-treasure',
            priority: 25,
            materials: <String>['DIAMOND*', '*_PICKAXE', 'TRIDENT'],
            clips: <GlossRealDropAnimationClip>[
              ...base,
              _materialPulseClip(
                GlossRealDropAnimationTrigger.spawn,
                treasureMap,
                random,
              ),
            ],
          ),
        )
        ..add(
          GlossRealDropAnimationProfile(
            id: 'hover-fallback',
            materials: <String>['*'],
            clips: base,
          ),
        );
    case RealDropShowcaseArchetype.materialReactive:
      profiles
        ..add(
          GlossRealDropAnimationProfile(
            id: 'reactive-lights',
            priority: 40,
            materials: <String>['*_LANTERN', '*_CANDLE', 'SEA_LANTERN'],
            clips: <GlossRealDropAnimationClip>[
              ...base,
              _materialPulseClip(
                GlossRealDropAnimationTrigger.impact,
                radianceMap,
                random,
              ),
            ],
          ),
        )
        ..add(
          GlossRealDropAnimationProfile(
            id: 'reactive-treasure',
            priority: 30,
            materials: <String>['DIAMOND*', '*_PICKAXE', 'TRIDENT'],
            clips: <GlossRealDropAnimationClip>[
              ...base,
              _materialPulseClip(
                GlossRealDropAnimationTrigger.settle,
                treasureMap,
                random,
              ),
            ],
          ),
        )
        ..add(
          GlossRealDropAnimationProfile(
            id: 'reactive-fallback',
            materials: <String>['*'],
            clips: base,
          ),
        );
  }
  return GlossRealDropAnimation(
    enabled: true,
    materialProperties: maps,
    profiles: profiles,
  );
}

List<GlossRealDropAnimationClip> _dropAnimationClips(
  RealDropShowcaseArchetype archetype,
  math.Random random,
) => switch (archetype) {
  RealDropShowcaseArchetype.ricochet => <GlossRealDropAnimationClip>[
    _spawnRevealClip(random),
    _impactClip(random),
    _bounceClip(random),
    _airborneClip(random),
  ],
  RealDropShowcaseArchetype.groundRoll => <GlossRealDropAnimationClip>[
    _spawnRevealClip(random),
    _rollingClip(random),
    _startRollClip(random),
    _settleClip(random),
  ],
  RealDropShowcaseArchetype.buoyant => <GlossRealDropAnimationClip>[
    _spawnRevealClip(random),
    _enterFluidClip(random),
    _submergedClip(random),
    _exitFluidClip(random),
  ],
  RealDropShowcaseArchetype.hoverRelease => <GlossRealDropAnimationClip>[
    _hoverReleaseClip(random),
    _settleClip(random),
  ],
  RealDropShowcaseArchetype.materialReactive => <GlossRealDropAnimationClip>[
    _spawnRevealClip(random),
    _impactClip(random),
    _settleClip(random),
  ],
};

GlossRealDropAnimationClip _spawnRevealClip(math.Random random) {
  final double duration = (14 + random.nextInt(9)).toDouble();
  final double peak = _round2(duration * 0.55);
  final double start = _band(random, (0.25, 0.65), 2);
  return GlossRealDropAnimationClip(
    trigger: GlossRealDropAnimationTrigger.spawn,
    durationTicks: duration,
    tracks: <GlossRealDropAnimationTrack>[
      for (final GlossRealDropAnimationTarget target
          in const <GlossRealDropAnimationTarget>[
            GlossRealDropAnimationTarget.scaleX,
            GlossRealDropAnimationTarget.scaleY,
            GlossRealDropAnimationTarget.scaleZ,
          ])
        _track(
          target,
          GlossRealDropAnimationBlend.multiply,
          <GlossRealDropAnimationKeyframe>[
            _key(0, start),
            _key(peak, 1.12, easing: GlossRealDropAnimationEasing.backOut),
            _key(duration, 1, easing: GlossRealDropAnimationEasing.easeOut),
          ],
        ),
      _track(
        GlossRealDropAnimationTarget.offsetY,
        GlossRealDropAnimationBlend.add,
        <GlossRealDropAnimationKeyframe>[
          _key(0, _band(random, (0.3, 0.75), 2)),
          _key(duration, 0, easing: GlossRealDropAnimationEasing.easeOut),
        ],
      ),
    ],
  );
}

GlossRealDropAnimationClip _hoverReleaseClip(math.Random random) {
  final double holdStart = (7 + random.nextInt(4)).toDouble();
  final double release = holdStart + 24 + random.nextInt(10);
  final double duration = release + 10;
  final double small = _band(random, (0.12, 0.3), 2);
  return GlossRealDropAnimationClip(
    trigger: GlossRealDropAnimationTrigger.spawn,
    durationTicks: duration,
    tracks: <GlossRealDropAnimationTrack>[
      for (final GlossRealDropAnimationTarget target
          in const <GlossRealDropAnimationTarget>[
            GlossRealDropAnimationTarget.scaleX,
            GlossRealDropAnimationTarget.scaleY,
            GlossRealDropAnimationTarget.scaleZ,
          ])
        _track(
          target,
          GlossRealDropAnimationBlend.multiply,
          <GlossRealDropAnimationKeyframe>[
            _key(0, _band(random, (2.4, 4.2), 2)),
            _key(holdStart, small, easing: GlossRealDropAnimationEasing.easeIn),
            _key(release, small, easing: GlossRealDropAnimationEasing.hold),
            _key(duration, 1, easing: GlossRealDropAnimationEasing.backOut),
          ],
        ),
      _track(
        GlossRealDropAnimationTarget.offsetY,
        GlossRealDropAnimationBlend.add,
        <GlossRealDropAnimationKeyframe>[
          _key(0, 0),
          _key(holdStart, _band(random, (1.0, 1.8), 2)),
          _key(
            release,
            _band(random, (1.0, 1.8), 2),
            easing: GlossRealDropAnimationEasing.hold,
          ),
          _key(duration, 0, easing: GlossRealDropAnimationEasing.easeInOut),
        ],
      ),
      _track(
        GlossRealDropAnimationTarget.physics,
        GlossRealDropAnimationBlend.replace,
        <GlossRealDropAnimationKeyframe>[
          _key(0, 1, easing: GlossRealDropAnimationEasing.hold),
          _key(holdStart, 0, easing: GlossRealDropAnimationEasing.hold),
          _key(release, 0, easing: GlossRealDropAnimationEasing.hold),
          _key(release + 1, 1),
          _key(duration, 1),
        ],
      ),
      _track(
        GlossRealDropAnimationTarget.rotationX,
        GlossRealDropAnimationBlend.add,
        <GlossRealDropAnimationKeyframe>[
          _key(0, 0),
          _key(release, 1080, easing: GlossRealDropAnimationEasing.easeInOut),
          _key(duration, 1440, easing: GlossRealDropAnimationEasing.easeOut),
        ],
      ),
    ],
  );
}

GlossRealDropAnimationClip _impactClip(math.Random random) {
  final double duration = (10 + random.nextInt(7)).toDouble();
  final double peak = _round2(duration * 0.35);
  final double squash = _band(random, (0.55, 0.78), 2);
  final double widen = _band(random, (1.12, 1.32), 2);
  return GlossRealDropAnimationClip(
    trigger: GlossRealDropAnimationTrigger.impact,
    durationTicks: duration,
    tracks: <GlossRealDropAnimationTrack>[
      _pulseScaleTrack(
        GlossRealDropAnimationTarget.scaleX,
        peak,
        duration,
        widen,
      ),
      _pulseScaleTrack(
        GlossRealDropAnimationTarget.scaleY,
        peak,
        duration,
        squash,
      ),
      _pulseScaleTrack(
        GlossRealDropAnimationTarget.scaleZ,
        peak,
        duration,
        widen,
      ),
      _track(
        GlossRealDropAnimationTarget.offsetY,
        GlossRealDropAnimationBlend.add,
        <GlossRealDropAnimationKeyframe>[
          _key(0, 0),
          _key(peak, _band(random, (0.08, 0.2), 2)),
          _key(duration, 0, easing: GlossRealDropAnimationEasing.easeOut),
        ],
      ),
    ],
  );
}

GlossRealDropAnimationClip _bounceClip(math.Random random) {
  final double duration = (12 + random.nextInt(8)).toDouble();
  return GlossRealDropAnimationClip(
    trigger: GlossRealDropAnimationTrigger.bounce,
    durationTicks: duration,
    tracks: <GlossRealDropAnimationTrack>[
      _track(
        GlossRealDropAnimationTarget.rotationZ,
        GlossRealDropAnimationBlend.add,
        <GlossRealDropAnimationKeyframe>[
          _key(0, 0),
          _key(
            duration,
            random.nextBool() ? 360 : -360,
            easing: GlossRealDropAnimationEasing.easeOut,
          ),
        ],
      ),
      _pulseScaleTrack(
        GlossRealDropAnimationTarget.scaleY,
        _round2(duration * 0.3),
        duration,
        _band(random, (1.15, 1.35), 2),
      ),
    ],
  );
}

GlossRealDropAnimationClip _airborneClip(math.Random random) {
  final double duration = (24 + random.nextInt(17)).toDouble();
  return GlossRealDropAnimationClip(
    trigger: GlossRealDropAnimationTrigger.airborne,
    durationTicks: duration,
    loop: true,
    tracks: <GlossRealDropAnimationTrack>[
      _track(
        GlossRealDropAnimationTarget.rotationY,
        GlossRealDropAnimationBlend.add,
        <GlossRealDropAnimationKeyframe>[
          _key(0, 0),
          _key(duration, random.nextBool() ? 360 : -360),
        ],
      ),
    ],
  );
}

GlossRealDropAnimationClip _rollingClip(math.Random random) {
  final double duration = (18 + random.nextInt(13)).toDouble();
  return GlossRealDropAnimationClip(
    trigger: GlossRealDropAnimationTrigger.rolling,
    durationTicks: duration,
    loop: true,
    tracks: <GlossRealDropAnimationTrack>[
      _track(
        GlossRealDropAnimationTarget.rotationX,
        GlossRealDropAnimationBlend.add,
        <GlossRealDropAnimationKeyframe>[_key(0, 0), _key(duration, 360)],
      ),
      _track(
        GlossRealDropAnimationTarget.offsetY,
        GlossRealDropAnimationBlend.add,
        <GlossRealDropAnimationKeyframe>[
          _key(0, 0),
          _key(duration / 2, _band(random, (0.04, 0.12), 2)),
          _key(duration, 0),
        ],
      ),
    ],
  );
}

GlossRealDropAnimationClip _startRollClip(math.Random random) {
  final double duration = (8 + random.nextInt(7)).toDouble();
  return GlossRealDropAnimationClip(
    trigger: GlossRealDropAnimationTrigger.startRoll,
    durationTicks: duration,
    tracks: <GlossRealDropAnimationTrack>[
      _pulseScaleTrack(
        GlossRealDropAnimationTarget.scaleZ,
        duration / 2,
        duration,
        _band(random, (1.12, 1.28), 2),
      ),
    ],
  );
}

GlossRealDropAnimationClip _settleClip(math.Random random) {
  final double duration = (12 + random.nextInt(9)).toDouble();
  final double peak = _round2(duration * 0.4);
  return GlossRealDropAnimationClip(
    trigger: GlossRealDropAnimationTrigger.settle,
    durationTicks: duration,
    tracks: <GlossRealDropAnimationTrack>[
      _pulseScaleTrack(
        GlossRealDropAnimationTarget.scaleX,
        peak,
        duration,
        _band(random, (1.08, 1.22), 2),
      ),
      _pulseScaleTrack(
        GlossRealDropAnimationTarget.scaleY,
        peak,
        duration,
        _band(random, (0.82, 0.94), 2),
      ),
      _pulseScaleTrack(
        GlossRealDropAnimationTarget.scaleZ,
        peak,
        duration,
        _band(random, (1.08, 1.22), 2),
      ),
    ],
  );
}

GlossRealDropAnimationClip _enterFluidClip(math.Random random) {
  final double duration = (14 + random.nextInt(9)).toDouble();
  final double peak = _round2(duration * 0.4);
  return GlossRealDropAnimationClip(
    trigger: GlossRealDropAnimationTrigger.enterFluid,
    durationTicks: duration,
    tracks: <GlossRealDropAnimationTrack>[
      _track(
        GlossRealDropAnimationTarget.offsetY,
        GlossRealDropAnimationBlend.add,
        <GlossRealDropAnimationKeyframe>[
          _key(0, 0),
          _key(peak, _band(random, (0.18, 0.38), 2)),
          _key(duration, 0, easing: GlossRealDropAnimationEasing.easeOut),
        ],
      ),
      _pulseScaleTrack(
        GlossRealDropAnimationTarget.scaleX,
        peak,
        duration,
        _band(random, (1.16, 1.35), 2),
      ),
      _pulseScaleTrack(
        GlossRealDropAnimationTarget.scaleZ,
        peak,
        duration,
        _band(random, (1.16, 1.35), 2),
      ),
    ],
  );
}

GlossRealDropAnimationClip _submergedClip(math.Random random) {
  final double duration = (28 + random.nextInt(17)).toDouble();
  return GlossRealDropAnimationClip(
    trigger: GlossRealDropAnimationTrigger.submerged,
    durationTicks: duration,
    loop: true,
    tracks: <GlossRealDropAnimationTrack>[
      _track(
        GlossRealDropAnimationTarget.offsetY,
        GlossRealDropAnimationBlend.add,
        <GlossRealDropAnimationKeyframe>[
          _key(0, 0),
          _key(duration / 2, _band(random, (0.1, 0.24), 2)),
          _key(duration, 0),
        ],
      ),
      _track(
        GlossRealDropAnimationTarget.rotationY,
        GlossRealDropAnimationBlend.add,
        <GlossRealDropAnimationKeyframe>[_key(0, 0), _key(duration, 360)],
      ),
    ],
  );
}

GlossRealDropAnimationClip _exitFluidClip(math.Random random) {
  final double duration = (10 + random.nextInt(7)).toDouble();
  return GlossRealDropAnimationClip(
    trigger: GlossRealDropAnimationTrigger.exitFluid,
    durationTicks: duration,
    tracks: <GlossRealDropAnimationTrack>[
      _track(
        GlossRealDropAnimationTarget.offsetY,
        GlossRealDropAnimationBlend.add,
        <GlossRealDropAnimationKeyframe>[
          _key(0, _band(random, (0.16, 0.32), 2)),
          _key(duration, 0, easing: GlossRealDropAnimationEasing.easeOut),
        ],
      ),
    ],
  );
}

GlossRealDropAnimationClip _materialPulseClip(
  GlossRealDropAnimationTrigger trigger,
  String materialMap,
  math.Random random,
) {
  final double duration = (12 + random.nextInt(9)).toDouble();
  final double peak = _round2(duration * 0.3);
  final double hold = _round2(duration * 0.62);
  return GlossRealDropAnimationClip(
    trigger: trigger,
    durationTicks: duration,
    tracks: <GlossRealDropAnimationTrack>[
      for (final GlossRealDropAnimationTarget target
          in const <GlossRealDropAnimationTarget>[
            GlossRealDropAnimationTarget.glow,
            GlossRealDropAnimationTarget.lightLevel,
          ])
        _track(
          target,
          GlossRealDropAnimationBlend.replace,
          <GlossRealDropAnimationKeyframe>[
            _key(0, 0),
            _key(
              peak,
              0,
              materialMap: materialMap,
              easing: GlossRealDropAnimationEasing.easeOut,
            ),
            _key(
              hold,
              0,
              materialMap: materialMap,
              easing: GlossRealDropAnimationEasing.hold,
            ),
            _key(duration, 0, easing: GlossRealDropAnimationEasing.easeOut),
          ],
        ),
    ],
  );
}

GlossRealDropAnimationTrack _pulseScaleTrack(
  GlossRealDropAnimationTarget target,
  double peak,
  double duration,
  double value,
) => _track(
  target,
  GlossRealDropAnimationBlend.multiply,
  <GlossRealDropAnimationKeyframe>[
    _key(0, 1),
    _key(peak, value, easing: GlossRealDropAnimationEasing.backOut),
    _key(duration, 1, easing: GlossRealDropAnimationEasing.easeOut),
  ],
);

GlossRealDropAnimationTrack _track(
  GlossRealDropAnimationTarget target,
  GlossRealDropAnimationBlend blend,
  List<GlossRealDropAnimationKeyframe> keyframes,
) => GlossRealDropAnimationTrack(
  target: target,
  blend: blend,
  keyframes: keyframes,
);

GlossRealDropAnimationKeyframe _key(
  double tick,
  double value, {
  String materialMap = '',
  GlossRealDropAnimationEasing easing = GlossRealDropAnimationEasing.linear,
}) => GlossRealDropAnimationKeyframe(
  tick: tick,
  value: value,
  materialMap: materialMap,
  easing: easing,
);

double _argb(String color) {
  final String digits = color.startsWith('#') ? color.substring(1) : color;
  return (0xFF000000 | int.parse(digits, radix: 16)).toDouble();
}

/// The mood's primary colour as a label background tint, occasionally plain
/// black the way the shipped default is.
List<int> _moodTint(ShowcaseMood mood, math.Random random) {
  if (random.nextInt(3) == 0) return <int>[0, 0, 0];
  final int packed = int.parse(mood.primary.substring(1), radix: 16);
  return <int>[(packed >> 16) & 0xFF, (packed >> 8) & 0xFF, packed & 0xFF];
}

/// A value inside `(low, high)`, rounded to [decimals] places.
double _band(math.Random random, (double, double) range, int decimals) {
  final double value = range.$1 + random.nextDouble() * (range.$2 - range.$1);
  if (decimals == 0) return value.roundToDouble();
  final double factor = math.pow(10, decimals).toDouble();
  return (value * factor).roundToDouble() / factor;
}

double _round2(double value) => (value * 100).roundToDouble() / 100;

HuiButtonData _randomButtonData(
  EditorStore store,
  math.Random random, {
  required Vec3 componentOffset,
}) {
  final ShowcaseMood mood = showcasePick(random, showcaseMoods);
  final bool menuAnchored = random.nextBool();
  final Vec3 hitboxOffset = menuAnchored
      ? Vec3(componentOffset.x, componentOffset.y, componentOffset.z + 0.02)
      : Vec3(0, 0, 0.02);
  return HuiButtonData(
    0.04 + random.nextDouble() * 0.16,
    <HuiAction>[
      HuiCommandAction('/spawn', 'player', 'left_click'),
      HuiSoundAction(
        _sound(store, random),
        'master',
        1,
        0.8 + random.nextDouble(),
        'right_click',
      ),
      HuiMessageAction(
        '<gradient:${mood.primary}:${mood.secondary}>'
            '${showcasePick(random, showcaseHeadlines)}</gradient>',
        'shift_left_click',
      ),
      HuiTeleportAction(
        'minecraft:overworld',
        0,
        80,
        0,
        0,
        0,
        'shift_right_click',
      ),
      HuiConnectAction('lobby', 'any'),
      HuiNavigateAction('', 'close', 'any'),
    ],
    _randomIcon(store, random),
    HuiHitbox(
      0.8 + random.nextDouble(),
      0.35 + random.nextDouble() * 0.8,
      hitboxOffset,
      menuAnchored ? HuiHitboxAnchor.menu : HuiHitboxAnchor.button,
    ),
    random.nextInt(11),
    _randomHoverEasing(random),
  );
}

HuiToggleData _randomToggleData(EditorStore store, math.Random random) {
  final ShowcaseMood mood = showcasePick(random, showcaseMoods);
  final (String, String) labels = showcasePick(random, _toggleLabels);
  return HuiToggleData(
    0.05 + random.nextDouble() * 0.1,
    '%player_is_op%',
    'yes',
    <HuiAction>[
      HuiMessageAction('<green>${labels.$1}</green>'),
      HuiSoundAction(_sound(store, random), 'master', 1, 1.35),
    ],
    <HuiAction>[
      HuiMessageAction('<red>${labels.$2}</red>'),
      HuiSoundAction(_sound(store, random), 'master', 1, 0.7),
    ],
    HuiTextIcon('&a[ON] &f${labels.$1}', _randomStyle(random, mood), 20),
    HuiTextIcon('&c[OFF] &7${labels.$2}', _randomStyle(random, mood), 20),
    HuiHitbox(
      0.9 + random.nextDouble(),
      0.3 + random.nextDouble() * 0.6,
      Vec3(0, 0, random.nextDouble() * 0.06),
    ),
    random.nextInt(11),
    _randomHoverEasing(random),
  );
}

const List<(String, String)> _toggleLabels = <(String, String)>[
  ('Lodge lights', 'Lodge dark'),
  ('Coffee on', 'Coffee off'),
  ('Owls watching', 'Owls asleep'),
  ('Curtains open', 'Curtains shut'),
  ('Radio on', 'Radio off'),
  ('Tools', 'Tools'),
];

HuiHoverEasing _randomHoverEasing(math.Random random) =>
    HuiHoverEasing.values[random.nextInt(HuiHoverEasing.values.length)];

HuiIcon _randomIcon(EditorStore store, math.Random random) {
  final ShowcaseMood mood = showcasePick(random, showcaseMoods);
  final HuiIcon? asset = _randomAssetIcon(store, random, mood);
  final List<HuiIcon> choices = <HuiIcon>[
    HuiTextIcon(
      '${mood.legacy}&l${showcasePick(random, showcaseStatusWords)}\n'
      '&7${showcasePick(random, showcaseEvents)}',
      _randomStyle(random, mood),
      20,
    ),
    HuiItemIcon(
      _material(store, random),
      1 + random.nextInt(4),
      random.nextInt(4),
      _randomStyle(random, mood),
    ),
    HuiBlockIcon(_blockMaterial(random), _randomStyle(random, mood)),
    HuiEntityIcon(
      huiSpawnableLivingEntityTypes[random.nextInt(
        huiSpawnableLivingEntityTypes.length,
      )],
      0.75 + random.nextDouble(),
      0.75 + random.nextDouble(),
    ),
    ?asset,
  ];
  return choices[random.nextInt(choices.length)];
}

HuiIcon? _randomAssetIcon(
  EditorStore store,
  math.Random random,
  ShowcaseMood mood,
) {
  final List<String> images = store.images?.paths.toList() ?? <String>[];
  final List<CustomItemEntry> customItems = store.catalogs.customItems.items;
  final CustomItemEntry? customItem = customItems.isEmpty
      ? null
      : customItems[random.nextInt(customItems.length)];
  final List<HuiIcon> choices = <HuiIcon>[
    if (images.isNotEmpty)
      HuiTextImageIcon(
        images[random.nextInt(images.length)],
        _randomStyle(random, mood),
      ),
    if (images.length >= 2)
      HuiAnimatedImageIcon(
        <String>[images[0], images[1]],
        2 + random.nextInt(10),
        _randomStyle(random, mood),
      ),
    ?customItem == null
        ? null
        : HuiCustomItemIcon(
            customItem.provider,
            customItem.id,
            1,
            _randomStyle(random, mood),
          ),
  ];
  return choices.isEmpty ? null : choices[random.nextInt(choices.length)];
}

HuiIconStyle _randomStyle(math.Random random, ShowcaseMood mood) {
  final int? brightness = random.nextBool() ? random.nextInt(16) : null;
  return HuiIconStyle(
    billboard: huiIconBillboards[random.nextInt(huiIconBillboards.length)],
    shadow: random.nextBool(),
    seeThrough: random.nextBool(),
    textAlignment:
        huiIconTextAlignments[random.nextInt(huiIconTextAlignments.length)],
    backgroundArgb: showcasePick(random, <String>[
      '#66000000',
      '#66000000',
      '#4D${mood.primary.substring(1)}',
      '#33${mood.secondary.substring(1)}',
    ]),
    textOpacity: 180 + random.nextInt(76),
    lineWidth: 120 + random.nextInt(281),
    blockLight: brightness,
    skyLight: brightness,
    viewRange: 0.6 + random.nextDouble() * 1.8,
    shadowRadius: random.nextDouble(),
    shadowStrength: random.nextDouble(),
    cullingWidth: 1 + random.nextDouble() * 4,
    cullingHeight: 1 + random.nextDouble() * 4,
    glowColor: random.nextBool() ? '#FF${mood.primary.substring(1)}' : null,
    scaleX: 0.7 + random.nextDouble() * 0.8,
    scaleY: 0.7 + random.nextDouble() * 0.8,
    scaleZ: 0.7 + random.nextDouble() * 0.8,
  );
}

String _material(EditorStore store, math.Random random) {
  final List<String> known = store.catalogs.materialKeys.toList();
  if (known.isNotEmpty) return known[random.nextInt(known.length)];
  return showcasePick(
    random,
    showcaseDrops.map((ShowcaseDrop drop) => drop.material).toList(),
  );
}

String _blockMaterial(math.Random random) {
  final List<String> blocks = showcaseBlockDecorations
      .where(huiIsBlockLikeMaterial)
      .toList();
  return blocks.isEmpty ? 'stone' : showcasePick(random, blocks);
}

String _sound(EditorStore store, math.Random random) {
  final List<String> known = store.catalogs.soundKeys.toList();
  if (known.isNotEmpty) return known[random.nextInt(known.length)];
  const List<String> fallback = <String>[
    'ui.button.click',
    'block.note_block.harp',
    'entity.experience_orb.pickup',
  ];
  return fallback[random.nextInt(fallback.length)];
}

/// Legacy format codes a decoration can carry on top of its colour.
const List<String> _formatCodes = <String>['&l', '&o', '&n', '&l&o', ''];

String showcaseEasterEgg(math.Random random) =>
    showcasePick(random, showcaseEasterEggs);

String showcaseBoardEasterEgg(math.Random random) =>
    showcasePick(random, showcaseBoardEasterEggs);

final class _PreviewFurnaceTheme {
  const _PreviewFurnaceTheme({
    required this.panelColor,
    required this.wellColor,
    required this.fill,
    required this.pulse,
    required this.chase,
    required this.idle,
    required this.flame0,
    required this.flame1,
    required this.flame2,
    required this.stateColor,
    required this.surgeColor,
    required this.accent,
  });

  final String panelColor;
  final String wellColor;
  final String fill;
  final String pulse;
  final String chase;
  final String idle;
  final String flame0;
  final String flame1;
  final String flame2;
  final String stateColor;
  final String surgeColor;
  final String accent;
}

const List<_PreviewFurnaceTheme> _previewFurnaceThemes = <_PreviewFurnaceTheme>[
  _PreviewFurnaceTheme(
    panelColor: '#E014111B',
    wellColor: '#FF15151B',
    fill: '#FFF2A535',
    pulse: '#FFFFD978',
    chase: '#FF9A5E22',
    idle: '#FF2A2A33',
    flame0: '#FFE2641E',
    flame1: '#FFF2A535',
    flame2: '#FFF7D14C',
    stateColor: '<#F2A535>',
    surgeColor: '<#FFD978>',
    accent: '#F2A535',
  ),
  _PreviewFurnaceTheme(
    panelColor: '#E0101822',
    wellColor: '#FF101820',
    fill: '#FF43D9FF',
    pulse: '#FFB8F5FF',
    chase: '#FF25799A',
    idle: '#FF202C36',
    flame0: '#FF356BFF',
    flame1: '#FF43D9FF',
    flame2: '#FFB8F5FF',
    stateColor: '<#43D9FF>',
    surgeColor: '<#B8F5FF>',
    accent: '#43D9FF',
  ),
  _PreviewFurnaceTheme(
    panelColor: '#E01C1020',
    wellColor: '#FF1B1020',
    fill: '#FFFF55CC',
    pulse: '#FFFFB8EA',
    chase: '#FF9A357E',
    idle: '#FF302238',
    flame0: '#FFAA35FF',
    flame1: '#FFFF55CC',
    flame2: '#FFFFB8EA',
    stateColor: '<#FF55CC>',
    surgeColor: '<#FFB8EA>',
    accent: '#FF55CC',
  ),
  _PreviewFurnaceTheme(
    panelColor: '#E0101F19',
    wellColor: '#FF102019',
    fill: '#FF55E68A',
    pulse: '#FFB9FFD2',
    chase: '#FF2B8D55',
    idle: '#FF20362A',
    flame0: '#FF31B36A',
    flame1: '#FF55E68A',
    flame2: '#FFB9FFD2',
    stateColor: '<#55E68A>',
    surgeColor: '<#B9FFD2>',
    accent: '#55E68A',
  ),
  // Red Room: lacquered black panel, curtain reds.
  _PreviewFurnaceTheme(
    panelColor: '#E0140A0E',
    wellColor: '#FF190C12',
    fill: '#FFFF2D4E',
    pulse: '#FFFFB3C4',
    chase: '#FF8C1B2E',
    idle: '#FF2A1620',
    flame0: '#FFB01030',
    flame1: '#FFFF2D4E',
    flame2: '#FFFFB3C4',
    stateColor: '<#FF2D4E>',
    surgeColor: '<#FFB3C4>',
    accent: '#FF2D4E',
  ),
  // Ghostwood: mill green under sodium light.
  _PreviewFurnaceTheme(
    panelColor: '#E00E1A12',
    wellColor: '#FF0F1B14',
    fill: '#FF2F8F5B',
    pulse: '#FFBFF0C8',
    chase: '#FF1C5B39',
    idle: '#FF1C2A22',
    flame0: '#FF1E6B44',
    flame1: '#FF2F8F5B',
    flame2: '#FFBFF0C8',
    stateColor: '<#2F8F5B>',
    surgeColor: '<#BFF0C8>',
    accent: '#2F8F5B',
  ),
  // Great Northern: cold blue snowlight.
  _PreviewFurnaceTheme(
    panelColor: '#E00E1622',
    wellColor: '#FF101A26',
    fill: '#FF3C7ACF',
    pulse: '#FFCFE6FF',
    chase: '#FF244C82',
    idle: '#FF1E2836',
    flame0: '#FF27548F',
    flame1: '#FF3C7ACF',
    flame2: '#FFCFE6FF',
    stateColor: '<#3C7ACF>',
    surgeColor: '<#CFE6FF>',
    accent: '#3C7ACF',
  ),
  // Owl Cave: lamp-oil amber on cave rock.
  _PreviewFurnaceTheme(
    panelColor: '#E0181206',
    wellColor: '#FF1B1509',
    fill: '#FF8A6A2F',
    pulse: '#FFF2D89B',
    chase: '#FF5C451D',
    idle: '#FF2A2418',
    flame0: '#FF6E4F17',
    flame1: '#FF8A6A2F',
    flame2: '#FFF2D89B',
    stateColor: '<#8A6A2F>',
    surgeColor: '<#F2D89B>',
    accent: '#F2D89B',
  ),
];

double _round(double value) => (value * 100).roundToDouble() / 100;

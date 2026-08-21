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
  final _PreviewFurnaceTheme theme = showcasePick(
    random,
    _previewFurnaceThemes,
  );
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
        'panelColor': theme.panelColor,
        'wellColor': theme.wellColor,
        'fill': theme.fill,
        'pulse': theme.pulse,
        'chase': theme.chase,
        'idle': theme.idle,
        'flame0': theme.flame0,
        'flame1': theme.flame1,
        'flame2': theme.flame2,
        'smoke0': '#FF5E5E66',
        'smoke1': '#FF8A8A92',
        'smoke2': '#FFB8B8C0',
        'activeItemKey': 'gloss.preview.state.smelting_item',
        'activeKey': 'gloss.preview.state.smelting',
        'stateColor': theme.stateColor,
        'surgeColor': theme.surgeColor,
        'titleKey': 'gloss.preview.theme.title.furnace',
        'accent': theme.accent,
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

GlossBubbleShimmer _randomBubbleShimmer(
  math.Random random,
  ShowcaseMood mood,
) {
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
final class _DropProfile {
  const _DropProfile({
    required this.tumble,
    required this.speed,
    required this.rate,
    required this.landing,
    required this.tilt,
    required this.scale,
    required this.labels,
    required this.spread,
  });

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
  math.Random random,
) {
  final ShowcaseMood mood = showcasePick(random, showcaseMoods);
  final _DropProfile profile = showcasePick(random, _dropProfiles);
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
    ..flatItems = _round2((base * (1.3 + random.nextDouble() * 0.6)).clamp(
      0.05,
      2,
    ))
    ..thinBlocks = _round2((base * (0.8 + random.nextDouble() * 0.5)).clamp(
      0.05,
      2,
    ));

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

  return doc;
}

/// The mood's primary colour as a label background tint, occasionally plain
/// black the way the shipped default is.
List<int> _moodTint(ShowcaseMood mood, math.Random random) {
  if (random.nextInt(3) == 0) return <int>[0, 0, 0];
  final int packed = int.parse(mood.primary.substring(1), radix: 16);
  return <int>[
    (packed >> 16) & 0xFF,
    (packed >> 8) & 0xFF,
    packed & 0xFF,
  ];
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

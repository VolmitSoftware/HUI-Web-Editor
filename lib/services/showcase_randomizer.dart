library;

import 'dart:math' as math;

import '../doctype/doctype.dart';
import '../model/model.dart';
import '../state/editor_store.dart';
import 'catalogs.dart';

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
  final List<HuiComponent> components = <HuiComponent>[
    HuiComponent(
      'showcase-title',
      Vec3(0, 1.15, 0),
      HuiDecorationData(
        HuiTextIcon(
          '&d&lGloss Feature Gallery\n&7Every click path is editable',
          _randomStyle(random),
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
        HuiBlockIcon(_blockMaterial(random), _randomStyle(random)),
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
  final HuiIcon? assetIcon = _randomAssetIcon(store, random);
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
  final _PreviewFurnaceTheme theme = _pick(random, _previewFurnaceThemes);
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
  final String server = _pick(random, _serverNames);
  final String event = _pick(random, _events);
  final List<String> lines = <String>[
    '${_animatedColor(random)}&l$server',
    "&7Hello, &f{{ papi('player_name') }}&7!",
    "&7Health {{ papiNumber('player_health') < 7 ? '&c' : '&a' }}"
        "{{ bar(papiNumber('player_health'), 20, 10, '■', '□') }}",
    "&7TPS &a{{ fixed(metric('react.tps'), 1) }} &8• &7$event",
    '&d:heart: &7${_pick(random, _hologramNotes)}',
    _easterEgg(random),
  ];
  if (random.nextBool()) {
    lines.insert(
      2,
      "{{ select(['&d✦', '&b✧', '&6✦'], floor(time.seconds * 3)) }} "
      '&fLive authored animation',
    );
  }
  return GlossHologramDoc(
    schemaVersion: current.schemaVersion,
    revision: current.revision,
    anchor: GlossHologramAnchor(
      world: _pick(random, <String>['world', 'world_nether', 'spawn']),
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
  final int count = 4 + random.nextInt(6);
  final String word = _pick(random, _animationWords);
  final List<String> colors = List<String>.of(_legacyPalette)..shuffle(random);
  final List<String> frames = <String>[
    "{{ hex(mix(#FF55FF, #55FFFF, (sin(time.seconds * 3) + 1) / 2)) }}&l$word",
    for (int index = 1; index < count; index++)
      '${colors[index % colors.length]}${_pick(random, _effects)}$word'
          '${random.nextBool() ? ' ${_pick(random, _motionGlyphs)}' : ''}',
  ];
  return GlossAnimationDoc(
    schemaVersion: current.schemaVersion,
    revision: current.revision,
    mode: _pick(random, glossAnimationModes),
    frameIntervalMs: 90 + random.nextInt(911),
    frames: frames,
  );
}

GlossScoreboardDoc buildRandomScoreboardShowcase(
  GlossScoreboardDoc current,
  math.Random random,
) {
  final String server = _pick(random, _serverNames);
  final String rank = _pick(random, _ranks);
  final String event = _pick(random, _events);
  final List<String> lines = <String>[
    "&7Player &f{{ papi('player_name') }}",
    '&7Rank &6$rank',
    '',
    "&7Ping {{ papiNumber('player_ping') < 80 ? '&a' : "
        "papiNumber('player_ping') < 160 ? '&e' : '&c' }}"
        "{{ papi('player_ping') }}ms",
    "&7Health &a{{ bar(papiNumber('player_health'), 20, 8, '■', '□') }}",
    "&7Online &a{{ papi('server_online') }}&8/&a"
        "{{ papi('server_max_players') }}",
    "&7TPS &a{{ fixed(metric('react.tps'), 1) }}",
    '',
    '${_animatedColor(random)}&l${_pick(random, _statusWords)}',
    '&7$event',
    _easterEgg(random),
    '&8${_pick(random, _domains)}',
  ];
  if (random.nextBool()) {
    lines.insert(7, r'&7Balance &6%vault_eco_balance_formatted%');
  }
  return GlossScoreboardDoc(
    schemaVersion: current.schemaVersion,
    revision: current.revision,
    title: '${_pick(random, _legacyPalette)}&l${server.toUpperCase()}',
    lines: lines,
    primary: random.nextBool(),
    permission: random.nextBool() ? 'default' : 'vip',
    groups: random.nextBool() ? <String>['vip', 'mvp'] : <String>[],
  );
}

GlossMotdDoc buildRandomMotdShowcase(GlossMotdDoc current, math.Random random) {
  final int count = 3 + random.nextInt(4);
  final String server = _pick(random, _serverNames);
  final int easterIndex = random.nextInt(count);
  final List<GlossMotdEntry> entries = <GlossMotdEntry>[];
  for (int index = 0; index < count; index++) {
    final List<String> lines = <String>[
      '${_animatedColor(random)}&l$server &8• &7${_pick(random, _events)}',
    ];
    if (index != count - 1) {
      lines.add(
        index == easterIndex
            ? _easterEgg(random)
            : "&7Online &a{{ server.online }}&8/&a{{ server.maxPlayers }} "
                  '&8• &7${_pick(random, _domains)}',
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
  const List<(String, String)> choices = <(String, String)>[
    ('<3', 'U+2764;'),
    (':)', 'U+1F60A;'),
    ('*', 'U+2728;'),
    ('gg', 'U+1F3C6;'),
  ];
  final (String, String) choice = choices[random.nextInt(choices.length)];
  return GlossEmojiDoc(
    schemaVersion: current.schemaVersion,
    revision: current.revision,
    trigger: choice.$1,
    emoji: choice.$2,
    enabled: true,
  );
}

GlossBubbleStyleDoc buildRandomBubbleShowcase(
  GlossBubbleStyleDoc current,
  math.Random random,
) => GlossBubbleStyleDoc(
  schemaVersion: current.schemaVersion,
  revision: current.revision,
  prefix: '${_animatedColor(random)}${_pick(random, _effects)}',
  offsetRaw: <num>[
    _round((random.nextDouble() - 0.5) * 1.2),
    _round(1.2 + random.nextDouble() * 1.4),
    _round((random.nextDouble() - 0.5) * 0.8),
  ],
  wordWrapChars: 64 + random.nextInt(65),
  lineStaggerTicks: random.nextInt(13),
  maxAliveMs: 9000 + random.nextInt(21001),
  flyAway: random.nextBool(),
  followPlayer: random.nextBool(),
  hideOwn: random.nextBool(),
  select: GlossBubbleSelect(
    worlds: <String>['world*', 'spawn*'],
    groups: <String>['owner', 'developer', 'vip'],
    priority: 10 + random.nextInt(41),
  ),
);

GlossTablistDoc buildRandomTablistShowcase(
  GlossTablistDoc current,
  math.Random random,
) {
  final String server = _pick(random, _serverNames);
  final String easterEgg = _easterEgg(random);
  final String groupColor = _pick(random, _legacyPalette);
  return GlossTablistDoc(
    schemaVersion: current.schemaVersion,
    revision: current.revision,
    useHeaderFooter: true,
    header:
        '${_animatedColor(random)}&l$server\n'
        "&7Welcome &f{{ papi('player_name') }} &8• "
        "{{ papiNumber('player_ping') < 100 ? '&a' : '&e' }}"
        "{{ papi('player_ping') }}ms\n"
        "&7Online &a{{ papi('server_online') }}&8/&a"
        "{{ papi('server_max_players') }} &8• &7TPS &a"
        "{{ fixed(metric('react.tps'), 1) }}",
    footer:
        '$easterEgg\n'
        "{{ select(['&d✦', '&b✧', '&6✦'], floor(time.seconds * 2)) }} "
        '&7${_pick(random, _events)} &8• &b${_pick(random, _domains)}',
    groupListNames: true,
    nameFormats: <String, String>{
      'default': r'&7[Player] &f$player',
      '_op': '${_animatedColor(random)}&l[Founder] &f\$player',
      'owner': r'&d&l[Owner] &f$player',
      'developer': r'&b[Developer] &f$player',
      'moderator': r'&a[Moderator] &f$player',
      'vip': '$groupColor[\$group] &f\$player',
    },
  );
}

HuiButtonData _randomButtonData(
  EditorStore store,
  math.Random random, {
  required Vec3 componentOffset,
}) {
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
        '<gradient:#ff55ff:#55ffff>Gloss says hello!</gradient>',
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
  );
}

HuiToggleData _randomToggleData(EditorStore store, math.Random random) =>
    HuiToggleData(
      0.05 + random.nextDouble() * 0.1,
      '%player_is_op%',
      'yes',
      <HuiAction>[
        HuiMessageAction('<green>Enabled</green>'),
        HuiSoundAction(_sound(store, random), 'master', 1, 1.35),
      ],
      <HuiAction>[
        HuiMessageAction('<red>Disabled</red>'),
        HuiSoundAction(_sound(store, random), 'master', 1, 0.7),
      ],
      HuiTextIcon('&a[ON] &fTools', _randomStyle(random), 20),
      HuiTextIcon('&c[OFF] &7Tools', _randomStyle(random), 20),
    );

HuiIcon _randomIcon(EditorStore store, math.Random random) {
  final HuiIcon? asset = _randomAssetIcon(store, random);
  final List<HuiIcon> choices = <HuiIcon>[
    HuiTextIcon('&d&lCLICK\n&7All action types', _randomStyle(random), 20),
    HuiItemIcon(
      _material(store, random),
      1 + random.nextInt(4),
      random.nextInt(4),
      _randomStyle(random),
    ),
    HuiBlockIcon(_blockMaterial(random), _randomStyle(random)),
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

HuiIcon? _randomAssetIcon(EditorStore store, math.Random random) {
  final List<String> images = store.images?.paths.toList() ?? <String>[];
  final List<CustomItemEntry> customItems = store.catalogs.customItems.items;
  final CustomItemEntry? customItem = customItems.isEmpty
      ? null
      : customItems[random.nextInt(customItems.length)];
  final List<HuiIcon> choices = <HuiIcon>[
    if (images.isNotEmpty)
      HuiTextImageIcon(
        images[random.nextInt(images.length)],
        _randomStyle(random),
      ),
    if (images.length >= 2)
      HuiAnimatedImageIcon(
        <String>[images[0], images[1]],
        2 + random.nextInt(10),
        _randomStyle(random),
      ),
    ?customItem == null
        ? null
        : HuiCustomItemIcon(
            customItem.provider,
            customItem.id,
            1,
            _randomStyle(random),
          ),
  ];
  return choices.isEmpty ? null : choices[random.nextInt(choices.length)];
}

HuiIconStyle _randomStyle(math.Random random) {
  final int? brightness = random.nextBool() ? random.nextInt(16) : null;
  return HuiIconStyle(
    billboard: huiIconBillboards[random.nextInt(huiIconBillboards.length)],
    shadow: random.nextBool(),
    seeThrough: random.nextBool(),
    textAlignment:
        huiIconTextAlignments[random.nextInt(huiIconTextAlignments.length)],
    backgroundArgb: '#66000000',
    textOpacity: 180 + random.nextInt(76),
    lineWidth: 120 + random.nextInt(281),
    blockLight: brightness,
    skyLight: brightness,
    viewRange: 0.6 + random.nextDouble() * 1.8,
    shadowRadius: random.nextDouble(),
    shadowStrength: random.nextDouble(),
    cullingWidth: 1 + random.nextDouble() * 4,
    cullingHeight: 1 + random.nextDouble() * 4,
    glowColor: random.nextBool() ? '#FFFF55FF' : null,
    scaleX: 0.7 + random.nextDouble() * 0.8,
    scaleY: 0.7 + random.nextDouble() * 0.8,
    scaleZ: 0.7 + random.nextDouble() * 0.8,
  );
}

String _material(EditorStore store, math.Random random) {
  final List<String> known = store.catalogs.materialKeys.toList();
  if (known.isNotEmpty) return known[random.nextInt(known.length)];
  const List<String> fallback = <String>[
    'stone',
    'diamond',
    'compass',
    'grass_block',
  ];
  return fallback[random.nextInt(fallback.length)];
}

String _blockMaterial(math.Random random) {
  const List<String> fallback = <String>[
    'stone',
    'grass_block',
    'diamond_block',
    'amethyst_block',
  ];
  return fallback[random.nextInt(fallback.length)];
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

const List<String> _serverNames = <String>[
  'Aether Forge',
  'Cinder Realm',
  'Moonlit SMP',
  'Obsidian Isles',
  'Prism Network',
  'Verdant Realms',
];

const List<String> _events = <String>[
  'Double XP weekend',
  'Sky vaults are open',
  'Fresh survival season',
  'Dungeon rush begins soon',
  'Build contest voting live',
  'Rare drops are boosted',
];

const List<String> _domains = <String>[
  'play.volmitsoftware.com',
  'join.prism.example',
  'mc.aether.example',
  'play.cinder.example',
];

const List<String> _ranks = <String>[
  'Architect',
  'Explorer',
  'Artificer',
  'Pathfinder',
  'Warden',
  'Founder',
];

const List<String> _statusWords = <String>[
  'LIVE',
  'ONLINE',
  'BOOSTED',
  'EVENT ACTIVE',
  'READY',
];

const List<String> _animationWords = <String>[
  'PULSE',
  'ONLINE',
  'LEVEL UP',
  'RARE DROP',
  'QUEST READY',
  'LIVE EVENT',
];

const List<String> _effects = <String>['&l', '&o', '&n', '&l&o', ''];

const List<String> _motionGlyphs = <String>['»', '✦', '◆', '➜', '★'];

const List<String> _legacyPalette = <String>[
  '&c',
  '&6',
  '&e',
  '&a',
  '&b',
  '&d',
];

const List<String> _hologramNotes = <String>[
  'Animations, PAPI and metrics are live',
  'This line is generated procedurally',
  'Edit every expression in code view',
  'Math and progress bars run in game',
  'RGB pulses are authored, not faked',
];

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
];

const List<String> _easterEggs = <String>[
  '&dMagic_Psycho &7is debugging reality',
  '&5SwiftSwamp &fSwiftSwamp smells >.<',
  '&bCyberpwn &7charted the strange loop',
  '&6Puretie &7found another shiny edge case',
];

T _pick<T>(math.Random random, List<T> values) =>
    values[random.nextInt(values.length)];

String _easterEgg(math.Random random) => _pick(random, _easterEggs);

String _animatedColor(math.Random random) => _pick(random, <String>[
  '|animation.rainbow|',
  "{{ select(['&c', '&6', '&e', '&a', '&b', '&d'], "
      'floor(time.seconds * ${2 + random.nextInt(5)})) }}',
  "{{ hex(mix(#FF55FF, #55FFFF, "
      '(sin(time.seconds * ${2 + random.nextInt(4)}) + 1) / 2)) }}',
]);

double _round(double value) => (value * 100).roundToDouble() / 100;

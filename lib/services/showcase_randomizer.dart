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

HuiPreviewDoc buildRandomPreviewShowcase(math.Random random) => HuiPreviewDoc(
  card: HuiPreviewCard(title: "'&d&lGloss Showcase'"),
  elements: <HuiPreviewElement>[
    HuiPreviewElement(
      'panel',
      x: 0,
      y: 0,
      width: 154 + random.nextInt(32),
      height: 88 + random.nextInt(28),
      color: '#D91A1524',
    ),
    HuiPreviewElement(
      'cell',
      x: 'mod(i, 5) * 24 - 48',
      y: 16,
      size: 18 + random.nextInt(5),
      color: 'i == 2 ? #FFFF55FF : #FF55FFFF',
      repeat: HuiPreviewRepeat(count: 5, varName: 'i'),
    ),
    HuiPreviewElement(
      'slot',
      x: 'mod(i, 3) * 27 - 27',
      y: -16,
      size: 18,
      index: 'i',
      repeat: HuiPreviewRepeat(count: 3, varName: 'i'),
    ),
    HuiPreviewElement(
      'label',
      x: 0,
      y: -42,
      text: "'&7Occupied: &f' + inventory.occupied + '/' + inventory.size",
    ),
  ],
);

GlossHologramDoc buildRandomHologramShowcase(
  GlossHologramDoc current,
  math.Random random,
) => GlossHologramDoc(
  schemaVersion: current.schemaVersion,
  revision: current.revision,
  anchor: GlossHologramAnchor(
    world: <String>['world', 'world_nether', 'spawn'][random.nextInt(3)],
    positionRaw: <num>[
      random.nextInt(401) - 200,
      64 + random.nextInt(48),
      random.nextInt(401) - 200,
    ],
  ),
  lines: <String>[
    '[FF55FF]&lGloss Hologram',
    '&7Magic_Psycho &8• &fCyberpwn',
    '|animation.rainbow|',
    '&bPuretie: &fSwiftSwamp smells >.<',
    '&d:heart: &7Live colour + emoji',
    '&7Placeholder: &f%player_name%',
  ],
);

GlossAnimationDoc buildRandomAnimationShowcase(
  GlossAnimationDoc current,
  math.Random random,
) => GlossAnimationDoc(
  schemaVersion: current.schemaVersion,
  revision: current.revision,
  mode: glossAnimationModes[random.nextInt(glossAnimationModes.length)],
  frameIntervalMs: 120 + random.nextInt(881),
  frames: <String>[
    '&c&lGLOSS',
    '&6&lGLOSS',
    '&e&lGLOSS',
    '&a&lGLOSS',
    '&b&lGLOSS',
    '&d&lGLOSS',
  ],
);

GlossScoreboardDoc buildRandomScoreboardShowcase(
  GlossScoreboardDoc current,
  math.Random random,
) => GlossScoreboardDoc(
  schemaVersion: current.schemaVersion,
  revision: current.revision,
  title: '[FF55FF]&lGLOSS',
  lines: <String>[
    '&7Player: &f%player_name%',
    '&7Rank: &6Architect',
    '',
    '&dMagic_Psycho &a●',
    '&bCyberpwn &a●',
    '&6Puretie &a●',
    '&5SwiftSwamp &eAFK',
    '',
    '&7Online: &a${12 + random.nextInt(188)}&8/&a200',
    '&7Balance: &6\$${500 + random.nextInt(49500)}',
    '&7TPS: &a20.0',
    '|animation.rainbow|',
    '&dSwiftSwamp smells >.<',
  ],
  primary: random.nextBool(),
  permission: random.nextBool() ? 'default' : 'vip',
  groups: random.nextBool() ? <String>['vip', 'mvp'] : <String>[],
);

GlossMotdDoc buildRandomMotdShowcase(
  GlossMotdDoc current,
  math.Random random,
) => GlossMotdDoc(
  schemaVersion: current.schemaVersion,
  revision: current.revision,
  entries: <GlossMotdEntry>[
    GlossMotdEntry(
      lines: <String>[
        '[FF55FF]&lGloss Network &8- &7Magic_Psycho hosts Season ${2 + random.nextInt(9)}',
        '&7Join &a${20 + random.nextInt(180)} &7players with &bCyberpwn &8• |animation.rainbow|',
      ],
    ),
    GlossMotdEntry(
      lines: <String>[
        '&6&lPuretie\'s weekend event!',
        '&7Status: |animation.rainbow|',
      ],
    ),
    GlossMotdEntry(
      lines: <String>['|animation.rainbow| &d:heart: &fSwiftSwamp smells >.<'],
    ),
    GlossMotdEntry(
      lines: <String>[
        '&bNew worlds. New menus.',
        '|animation.rainbow| &8• &7play.example.net',
      ],
    ),
  ],
);

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
  prefix: '|animation.rainbow| &f',
  offsetRaw: <num>[
    _round((random.nextDouble() - 0.5) * 1.2),
    _round(1.2 + random.nextDouble() * 1.4),
    _round((random.nextDouble() - 0.5) * 0.8),
  ],
  wordWrapChars: glossBubbleMaxWordWrapChars,
  lineStaggerTicks: random.nextInt(5),
  maxAliveMs: 12000 + random.nextInt(12001),
  flyAway: true,
  followPlayer: true,
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
) => GlossTablistDoc(
  schemaVersion: current.schemaVersion,
  revision: current.revision,
  useHeaderFooter: true,
  header:
      '|animation.rainbow| &fNETWORK\n'
      '[FF55FF]&lSeason ${2 + random.nextInt(9)}\n'
      '&7Online: &a${40 + random.nextInt(160)} &8• &7TPS: &a20.0',
  footer:
      '&7Magic_Psycho &8• &7SwiftSwamp &8• &7Cyberpwn &8• &7Puretie\n'
      '&bplay.volmitsoftware.com &8• &d:heart:',
  groupListNames: true,
  nameFormats: <String, String>{
    'default': r'&7[Player] &f$player',
    '_op': r'|animation.rainbow| &c[Founder] &f$player',
    'owner': r'&d[Owner] &f$player',
    'developer': r'&b[Developer] &f$player',
    'moderator': r'&a[Moderator] &f$player',
    'vip': r'&6[$group] &f$player',
  },
);

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

double _round(double value) => (value * 100).roundToDouble() / 100;

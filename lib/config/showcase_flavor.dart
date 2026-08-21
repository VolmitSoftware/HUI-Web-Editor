/// The words, colours and sample stacks every generated showcase draws from.
///
/// The editor never ships a real server's content, so everything a "Randomize"
/// press or a mock surface shows is invented here. It is invented with a
/// theme: a small northwestern town, its lodges, its diner and its owls. The
/// point is not the joke — it is that a themed pool reads as authored content
/// rather than as lorem ipsum, so a screenshot of the editor looks like a
/// screenshot of somebody's server.
///
/// Two rules hold this file together:
///
///  * Four names are real people and stay exactly as spelled — the shipped
///    easter eggs in [showcaseEasterEggs] and [showcaseBoardEasterEggs].
///  * Scoreboard rows are cut at 32 encoded characters by
///    `_fitScoreboardLine`, so every pool a board row can reach is bounded
///    accordingly and [showcaseHeadlines] — the unbounded pool — is only ever
///    used by surfaces that wrap or scroll.
library;

import 'dart:math' as math;

/// Server names. Bounded at 28 characters: a board title adds a colour and
/// `&l` before upper-casing one of these.
const List<String> showcaseServerNames = <String>[
  'The Lodge SMP',
  'Black Lodge',
  'White Lodge',
  'Twin Peaks SMP',
  'Ghostwood Realms',
  'Great Northern',
  'Double R Network',
  'Roadhouse SMP',
  'Owl Cave',
  'Glastonbury Grove',
  'Packard Mill',
  'One Eyed Jacks',
  'Blue Pine SMP',
  'Red Room Realms',
  'Sycamore Circle',
  'Pearl Lakes',
  'Blue Rose Network',
  'Bookhouse SMP',
  'Fire Walk SMP',
  'Sheriff Station',
];

/// Short "what is happening today" lines. Bounded at 28 characters so a board
/// row can carry one behind a colour code.
const List<String> showcaseEvents = <String>[
  'Damn fine coffee weekend',
  'Cherry pie on the house',
  'The owls are watching',
  'Log Lady broadcast tonight',
  'Ghostwood vote at sundown',
  'Roadhouse doubles tonight',
  'Bookhouse meets at dusk',
  'Black Lodge gates are open',
  'Double R pie contest',
  'Miss Twin Peaks voting',
  'Sawmill night shift',
  'Waterfall fishing derby',
  'Coffee is always on',
  'Sycamore grove is quiet',
  'Fresh survival season',
  'Double XP weekend',
  'Rare drops are boosted',
  'Build contest voting live',
];

/// Long-form lines for surfaces with no row budget — MOTD entries, tablist
/// footers, hologram bodies.
const List<String> showcaseHeadlines = <String>[
  'The owls are not what they seem',
  'Fire walk with me',
  'That gum you like is back in style',
  'Where we come from the birds sing',
  'Through the darkness of future past',
  'One chants out between two worlds',
  'The magician longs to see',
  'Every day, once a day, give yourself a present',
  "Diane, I am holding in my hand a small box",
  'Damn fine cup of coffee, and hot',
  'Wrapped in plastic, found at the shore',
  'I will see you again in 25 years',
  'There is always music in the air',
  'The stars turn, and a time presents itself',
];

/// Where a hologram or a drop filter says it lives.
const List<String> showcaseWorlds = <String>[
  'world',
  'twin_peaks',
  'ghostwood',
  'black_lodge',
  'white_lodge',
  'glastonbury_grove',
  'pearl_lakes',
  'world_nether',
];

/// Bounded at 28: a board row prints one behind `&8`.
const List<String> showcaseDomains = <String>[
  'play.volmitsoftware.com',
  'join.blacklodge.example',
  'mc.twinpeaks.example',
  'play.ghostwood.example',
  'coffee.doubler.example',
  'owls.pearl-lakes.example',
  'lodge.northern.example',
  'gate.onejacks.example',
];

/// Bounded at 23: a board row prints `&7Rank ` then a colour then one of
/// these.
const List<String> showcaseRanks = <String>[
  'Bookhouse Boy',
  'Special Agent',
  'Log Lady',
  'Sheriff',
  'Deputy',
  'Mill Foreman',
  'Roadhouse Regular',
  'Dreamer',
  'Giant',
  'Blue Rose',
  'Waitress',
  'Ranger',
  'Bellhop',
  'Fireman',
  'Doc',
];

/// Bounded at 24: a board row prints an animated glyph, `&l`, then one of
/// these.
const List<String> showcaseStatusWords = <String>[
  'LODGE OPEN',
  'OWLS ACTIVE',
  'DAMN FINE',
  'COFFEE HOT',
  'PIE READY',
  'RED ROOM',
  'WIDE AWAKE',
  'FIRE WALK',
  'BLUE ROSE',
  'DREAMING',
  'LIVE',
  'BOOSTED',
];

/// Big single words for the animation player, where the frame is the whole
/// document and nothing crops it.
const List<String> showcaseAnimationWords = <String>[
  'FIRE WALK WITH ME',
  'DAMN FINE COFFEE',
  'THE OWLS ARE WATCHING',
  'BLACK LODGE',
  'WHITE LODGE',
  'RED ROOM',
  'CHERRY PIE',
  'LET US ROCK',
  'WRAPPED IN PLASTIC',
  'BLUE ROSE',
  'DOUBLE R DINER',
  'GHOSTWOOD',
  'ONE EYED JACKS',
  'MISS TWIN PEAKS',
  'DIANE',
  'JUDY',
];

/// Teaching notes for hologram bodies: themed, but each one still says
/// something true about the pipeline.
const List<String> showcaseHologramNotes = <String>[
  'Every expression here runs in game',
  'Authored RGB pulses, never faked',
  'This body was generated procedurally',
  'Edit any of it in the code view',
  'Math and bars evaluate per viewer',
  'The owls are rendered per tick',
  'Damn fine text pipeline',
];

/// Player names for the mock tablist and the canned chat scrollback.
///
/// The first four are the real handles the shipped easter eggs name; the rest
/// are the town.
const List<String> showcaseTownspeople = <String>[
  'AgentCooper',
  'LauraPalmer',
  'TheLogLady',
  'BobbyBriggs',
  'AudreyHorne',
  'DeputyHawk',
  'ShellyJohnson',
  'BigEdHurley',
  'NadineHurley',
  'LelandPalmer',
  'DrJacoby',
  'GordonCole',
  'DianeEvans',
  'JosiePackard',
  'PeteMartell',
  'CatherineM',
  'AndyBrennan',
  'LucyMoran',
  'DonnaHayward',
  'JamesHurley',
  'MaddyFerguson',
  'WindomEarle',
  'TheGiant',
  'MrsTremond',
  'BenHorne',
  'NormaJennings',
  'HankJennings',
  'LeoJohnson',
  'MikeNelson',
  'SheriffTruman',
  'AlbertRosen',
  'RonetteP',
  'HaroldSmith',
  'DougieJones',
];

/// The four real handles the shipped showcases name. Never themed away.
const List<String> showcaseCredits = <String>[
  'Magic_Psycho',
  'SwiftSwamp',
  'Cyberpwn',
  'Puretie',
];

/// Hologram, MOTD and tablist easter eggs. One entry per line, already
/// coloured; every one of [showcaseCredits] appears in several.
const List<String> showcaseEasterEggs = <String>[
  '&dMagic_Psycho &7is debugging reality',
  '&dMagic_Psycho &7took the ring off the table',
  '&dMagic_Psycho &7walked out of the waiting room',
  '&5SwiftSwamp &fSwiftSwamp smells >.<',
  '&5SwiftSwamp &7left the log with the Log Lady',
  '&5SwiftSwamp &7is still owed a cherry pie',
  '&bCyberpwn &7charted the strange loop',
  '&bCyberpwn &7mapped every road out of town',
  '&bCyberpwn &7heard it backwards first',
  '&6Puretie &7found another shiny edge case',
  '&6Puretie &7found the ring under the floor',
  '&6Puretie &7ordered the damn fine coffee',
];

/// The same eggs cut to a board row: at most 32 encoded characters.
const List<String> showcaseBoardEasterEggs = <String>[
  '&dMagic_Psycho &fdebugs',
  '&dMagic_Psycho &fdreams',
  '&5SwiftSwamp &fsmells >.<',
  '&5SwiftSwamp &fhas the log',
  '&bCyberpwn &floops',
  '&bCyberpwn &fplays it back',
  '&6Puretie &ffound loot',
  '&6Puretie &fhas the ring',
];

/// A coherent look one randomized document commits to.
///
/// Randomizing every colour independently gives noise; randomizing the mood
/// and deriving colours from it gives a document that looks designed. Every
/// showcase builder that picks a colour picks it here.
final class ShowcaseMood {
  const ShowcaseMood({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.legacy,
    required this.glyphs,
  });

  /// Shown in generated copy, so it reads as a named style.
  final String name;

  /// `#RRGGBB`, the colour a gradient or pulse starts at.
  final String primary;

  /// `#RRGGBB`, the colour it resolves to.
  final String secondary;

  /// The nearest legacy code, for the rows where a hex pair does not fit.
  final String legacy;

  /// Single-width BMP glyphs safe in a scoreboard row and a nametag.
  final List<String> glyphs;
}

const List<ShowcaseMood> showcaseMoods = <ShowcaseMood>[
  ShowcaseMood(
    name: 'Red Room',
    primary: '#FF2D4E',
    secondary: '#FFB3C4',
    legacy: '&c',
    glyphs: <String>['◆', '◇', '❖'],
  ),
  ShowcaseMood(
    name: 'Black Lodge',
    primary: '#7A2BFF',
    secondary: '#2BE8FF',
    legacy: '&5',
    glyphs: <String>['✦', '✧', '◈'],
  ),
  ShowcaseMood(
    name: 'White Lodge',
    primary: '#FFF4D6',
    secondary: '#FFC964',
    legacy: '&e',
    glyphs: <String>['✧', '·', '✦'],
  ),
  ShowcaseMood(
    name: 'Double R',
    primary: '#FF7A3C',
    secondary: '#FFD98A',
    legacy: '&6',
    glyphs: <String>['●', '◐', '○'],
  ),
  ShowcaseMood(
    name: 'Ghostwood',
    primary: '#2F8F5B',
    secondary: '#BFF0C8',
    legacy: '&a',
    glyphs: <String>['▲', '△', '⋀'],
  ),
  ShowcaseMood(
    name: 'Great Northern',
    primary: '#3C7ACF',
    secondary: '#CFE6FF',
    legacy: '&b',
    glyphs: <String>['❄', '✼', '·'],
  ),
  ShowcaseMood(
    name: 'Roadhouse',
    primary: '#C43BD1',
    secondary: '#FFB8F0',
    legacy: '&d',
    glyphs: <String>['♪', '♫', '·'],
  ),
  ShowcaseMood(
    name: 'Owl Cave',
    primary: '#8A6A2F',
    secondary: '#F2D89B',
    legacy: '&6',
    glyphs: <String>['◉', '◎', '·'],
  ),
];

/// One stack the drop stage can present.
///
/// [block] is `Material.isBlock()`, which no browser catalog carries and
/// `RealDropModel.modelKind` needs, so each entry states it. [displayName] is
/// the item meta name the plugin prefers over the registry name when
/// `drops.useItemDisplayNames` is on, which is the default.
final class ShowcaseDrop {
  const ShowcaseDrop({
    required this.material,
    required this.displayName,
    required this.amount,
    required this.block,
    this.maxStackSize = 64,
  });

  /// Lower-case registry key, as the sprite catalog spells it.
  final String material;

  /// What the label reads.
  final String displayName;

  final int amount;
  final bool block;
  final int maxStackSize;

  /// Upper-case registry name, as `Material.name()` spells it.
  String get registryName => material.toUpperCase();
}

/// The stacks the drop stage cycles through.
///
/// Chosen to cover every branch that changes what a drop looks like: all three
/// model families and the authored Y offsets (slab, carpet, bed, snow,
/// trident, shield). Samples stay at one item unless a two- or three-item
/// stack makes the stacked presentation useful to inspect.
///
/// Three rows are also the stage's unattended rotation — `dropStageRotation`
/// names them, one per model family — so removing or renaming `cobblestone`,
/// `diamond_pickaxe` or `oak_slab` changes what an untouched stage shows.
const List<ShowcaseDrop> showcaseDrops = <ShowcaseDrop>[
  ShowcaseDrop(
    material: 'cherry_log',
    displayName: 'Ghostwood Timber',
    amount: 1,
    block: true,
  ),
  ShowcaseDrop(
    material: 'cobblestone',
    displayName: 'Packard Mill Cobble',
    amount: 1,
    block: true,
  ),
  ShowcaseDrop(
    material: 'cake',
    displayName: 'Cherry Pie',
    amount: 1,
    block: true,
    maxStackSize: 1,
  ),
  ShowcaseDrop(
    material: 'mushroom_stew',
    displayName: 'Damn Fine Coffee',
    amount: 1,
    block: false,
    maxStackSize: 1,
  ),
  ShowcaseDrop(
    material: 'cookie',
    displayName: 'Double R Doughnut',
    amount: 3,
    block: false,
  ),
  ShowcaseDrop(
    material: 'red_carpet',
    displayName: 'Red Room Carpet',
    amount: 1,
    block: true,
  ),
  ShowcaseDrop(
    material: 'oak_slab',
    displayName: 'Roadhouse Floorboard',
    amount: 2,
    block: true,
  ),
  ShowcaseDrop(
    material: 'feather',
    displayName: 'Owl Feather',
    amount: 2,
    block: false,
  ),
  ShowcaseDrop(
    material: 'diamond_pickaxe',
    displayName: 'Blue Rose Pickaxe',
    amount: 1,
    block: false,
    maxStackSize: 1,
  ),
  ShowcaseDrop(
    material: 'lantern',
    displayName: 'Great Northern Lamp',
    amount: 2,
    block: true,
  ),
  ShowcaseDrop(
    material: 'black_candle',
    displayName: 'Black Lodge Candle',
    amount: 3,
    block: true,
  ),
  ShowcaseDrop(
    material: 'music_disc_13',
    displayName: 'Roadhouse 45',
    amount: 1,
    block: false,
    maxStackSize: 1,
  ),
  ShowcaseDrop(
    material: 'sea_lantern',
    displayName: 'Owl Cave Light',
    amount: 3,
    block: true,
  ),
  ShowcaseDrop(
    material: 'red_bed',
    displayName: 'Great Northern Bed',
    amount: 1,
    block: true,
    maxStackSize: 1,
  ),
  ShowcaseDrop(
    material: 'trident',
    displayName: 'Fisherman Trident',
    amount: 1,
    block: false,
    maxStackSize: 1,
  ),
  ShowcaseDrop(
    material: 'shield',
    displayName: 'Bookhouse Shield',
    amount: 1,
    block: false,
    maxStackSize: 1,
  ),
  ShowcaseDrop(
    material: 'snow',
    displayName: 'Twin Peaks Snowfall',
    amount: 2,
    block: true,
  ),
  ShowcaseDrop(
    material: 'cherry_sapling',
    displayName: 'Glastonbury Sapling',
    amount: 2,
    block: true,
  ),
  ShowcaseDrop(
    material: 'sculk',
    displayName: 'Lodge Floor Static',
    amount: 1,
    block: true,
  ),
  ShowcaseDrop(
    material: 'ender_pearl',
    displayName: 'Owl Cave Ring',
    amount: 2,
    block: false,
    maxStackSize: 16,
  ),
];

/// Block materials a decoration can draw as a cube.
///
/// Every key here passes `huiIsBlockLikeMaterial`, which is what the menu
/// validator holds a block icon to — `Material.isBlock()` is a wider set than
/// the one Minecraft actually renders as a cube in a GUI slot.
const List<String> showcaseBlockDecorations = <String>[
  'cherry_log',
  'pale_oak_log',
  'cherry_planks',
  'oak_slab',
  'red_carpet',
  'red_wool',
  'crimson_stem',
  'sea_lantern',
  'black_candle',
  'red_bed',
  'cherry_sapling',
  'cobblestone',
  'stone',
  'snow',
];

/// Uniform pick, the one random helper every flavour user shares.
T showcasePick<T>(math.Random random, List<T> values) =>
    values[random.nextInt(values.length)];

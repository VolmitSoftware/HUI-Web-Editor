/// Starter menus offered by the templates dialog.
///
/// Every template is authored against the Java parser's real behaviour rather
/// than relying on its defaults: sound actions always carry a source plus
/// volume/pitch 1, command actions always carry a source, item keys are
/// lowercase registry keys,
/// and no template uses an image icon (an image path that is not in the local
/// library would open the document with an unresolved-asset notice). Applying a
/// template must never produce a validation error.
library;

import '../model/json_codec.dart';
import '../model/model.dart';

/// A named starter document.
class HuiTemplate {
  const HuiTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.highlights,
    required this.build,
  });

  /// Menu id and export file base name the new document starts with.
  final String id;
  final String name;

  /// One or two sentences shown on the option card.
  final String description;

  /// Short feature bullets, rendered as chips.
  final List<String> highlights;

  /// Builds a fresh, mutable menu. Never return a shared instance: the store
  /// takes ownership of whatever comes back.
  final HuiMenu Function() build;
}

const List<HuiTemplate> huiTemplates = <HuiTemplate>[
  HuiTemplate(
    id: 'blank',
    name: 'Blank hologram',
    description:
        'The same baseline /holoui menus create writes on the server: a '
        'title, a hint line, and a Close button. Place it with '
        '/holoui boards create <id> <id>.',
    highlights: <String>['3 components', 'Text icons', 'Native close'],
    build: buildBlankHologramTemplate,
  ),
  HuiTemplate(
    id: 'welcome',
    name: 'Welcome hub',
    description:
        'A titled hub with three command buttons and a close button. The '
        'starting point for a server spawn menu. The close button runs '
        '/holoui close, so players need holoui.command and '
        'holoui.command.close (both default to op).',
    highlights: <String>['5 components', 'Text icons', 'Commands + sounds'],
    build: buildWelcomeTemplate,
  ),
  HuiTemplate(
    id: 'shop',
    name: 'Shop row',
    description:
        'A row of item icons that each run a buy command and play a purchase '
        'sound, with a price line under every slot.',
    highlights: <String>['14 components', 'Item icons', 'Buy commands'],
    build: buildShopTemplate,
  ),
  HuiTemplate(
    id: 'warps',
    name: 'Warp compass',
    description:
        'Four destination buttons arranged around a compass, each teleporting '
        'the player and playing the enderman warp sound.',
    highlights: <String>['6 components', 'Item icons', 'Teleport commands'],
    build: buildWarpTemplate,
  ),
  HuiTemplate(
    id: 'settings',
    name: 'Settings panel',
    description:
        'Two toggles driven by PlaceholderAPI values, showing how conditions '
        'pick an icon and how the true/false actions fire. Requires EssentialsX '
        'plus PlaceholderAPI\'s Essentials expansion. The close button runs '
        '/holoui close, so players need holoui.command and holoui.command.close '
        '(both default to op).',
    highlights: <String>['5 components', 'Toggles', 'Placeholders'],
    build: buildSettingsTemplate,
  ),
  HuiTemplate(
    id: 'info',
    name: 'Info billboard',
    description:
        'A read-only board of multi-line coloured text. No buttons, so nothing '
        'is clickable — ideal for rules or announcements.',
    highlights: <String>['3 components', 'Multi-line text', 'No hitboxes'],
    build: buildInfoTemplate,
  ),
];

HuiTemplate? huiTemplateById(String id) {
  for (final HuiTemplate template in huiTemplates) {
    if (template.id == id) return template;
  }
  return null;
}

const String kBlankHologramJson = r'''
{
  "offset": [0.0, 1.7, 2.5],
  "lockPosition": false,
  "followPlayer": false,
  "closeOnDeath": true,
  "closeOnTeleport": true,
  "components": [
    {
      "id": "title",
      "offset": [0.0, 0.35, 0.0],
      "data": {
        "type": "decoration",
        "icon": {
          "type": "text",
          "text": "&6&lHologram"
        }
      }
    },
    {
      "id": "body",
      "offset": [0.0, 0.05, 0.0],
      "data": {
        "type": "decoration",
        "icon": {
          "type": "text",
          "text": "&7Edit this with /holoui menus or the web editor."
        }
      }
    },
    {
      "id": "close",
      "offset": [0.0, -0.35, 0.0],
      "data": {
        "type": "button",
        "highlightModifier": 0.05,
        "icon": {
          "type": "text",
          "text": "&cClose"
        },
        "actions": [
          {
            "type": "sound",
            "sound": "ui.button.click",
            "source": "master",
            "volume": 1.0,
            "pitch": 1.0
          },
          {
            "type": "navigate",
            "mode": "close"
          }
        ]
      }
    }
  ]
}
''';

HuiMenu buildBlankHologramTemplate() => decodeHuiMenu(kBlankHologramJson);

/// Root defaults shared by every template: eye height, arm's length forward,
/// follows the player, closes on death and teleport.
HuiMenu _menu(List<HuiComponent> components) => HuiMenu(
  offset: Vec3(0, 1.7, 2.5),
  lockPosition: false,
  followPlayer: true,
  closeOnDeath: true,
  closeOnTeleport: true,
  components: components,
);

HuiComponent _text(String id, double x, double y, String text) =>
    HuiComponent(id, Vec3(x, y, 0), HuiDecorationData(HuiTextIcon(text)));

HuiComponent _commandButton(
  String id,
  double x,
  double y,
  HuiIcon icon,
  String command, {
  String sound = 'ui.button.click',
}) => HuiComponent(
  id,
  Vec3(x, y, 0),
  HuiButtonData(0.05, <HuiAction>[
    HuiCommandAction(command, 'player'),
    HuiSoundAction(sound, 'master', 1, 1),
  ], icon),
);

// Layout note for every template below: a text line is 0.21875 blocks tall and
// roughly `characters * 0.109` blocks wide (the plugin's own CollisionPlane
// maths), and an item is a 0.75 block square. Rows are spaced so neither the
// drawn icons nor the click planes touch — a nearer overlap can hide the one
// behind it from the event-time click ray.
HuiMenu buildWelcomeTemplate() => _menu(<HuiComponent>[
  _text('title', 0, 1.05, '&6&lWelcome, traveller!\n&7Choose where to go'),
  _commandButton(
    'spawn',
    0,
    0.45,
    HuiTextIcon('&a&lSPAWN &8- &7return to the hub'),
    '/spawn',
  ),
  _commandButton(
    'shop',
    0,
    0.1,
    HuiTextIcon('&e&lSHOP &8- &7buy and sell'),
    '/warp shop',
  ),
  _commandButton(
    'discord',
    0,
    -0.25,
    HuiTextIcon('&b&lDISCORD &8- &7join the chat'),
    '/discord',
  ),
  _commandButton(
    'close',
    0,
    -0.7,
    HuiTextIcon('&c[ Close ]'),
    '/holoui close',
    sound: 'block.note_block.bass',
  ),
]);

HuiMenu buildShopTemplate() => _menu(<HuiComponent>[
  _text('title', 0, 1.25, '&6&lVillage Store\n&7Click an item to buy one'),
  ..._shopColumn('sword', -1.725, 'iron_sword', '&fSword', '&a12'),
  ..._shopColumn('apple', -0.575, 'golden_apple', '&fApple', '&a8'),
  ..._shopColumn('pearl', 0.575, 'ender_pearl', '&fPearl', '&a6'),
  ..._shopColumn('diamond', 1.725, 'diamond', '&fDiamond', '&a24'),
  _text('footer', 0, -0.95, '&8Prices are in emeralds and set by /shop'),
]);

/// One shop column: the label above, the clickable item in the middle, the
/// price below. Only the middle component is a button.
List<HuiComponent> _shopColumn(
  String id,
  double x,
  String material,
  String label,
  String price,
) => <HuiComponent>[
  _text('$id-label', x, 0.75, label),
  _commandButton(
    id,
    x,
    0.1,
    HuiItemIcon(material, 1, 0),
    '/buy $material 1',
    sound: 'entity.experience_orb.pickup',
  ),
  _text('$id-price', x, -0.5, price),
];

HuiMenu buildWarpTemplate() => _menu(<HuiComponent>[
  _text('title', 0, 1.55, '&b&lWarp Network\n&7Pick a destination'),
  // Compass in the middle, destinations on the four points. Every gap is
  // at least 0.85 blocks so the 0.75 block item planes never touch.
  HuiComponent(
    'compass',
    Vec3(0, 0, 0),
    HuiDecorationData(HuiItemIcon('compass', 1, 0)),
  ),
  _commandButton(
    'spawn',
    0,
    0.85,
    HuiItemIcon('grass_block', 1, 0),
    '/warp spawn',
    sound: 'entity.enderman.teleport',
  ),
  _commandButton(
    'desert',
    -0.9,
    0,
    HuiItemIcon('sand', 1, 0),
    '/warp desert',
    sound: 'entity.enderman.teleport',
  ),
  _commandButton(
    'tundra',
    0.9,
    0,
    HuiItemIcon('packed_ice', 1, 0),
    '/warp tundra',
    sound: 'entity.enderman.teleport',
  ),
  _commandButton(
    'nether',
    0,
    -0.85,
    HuiItemIcon('netherrack', 1, 0),
    '/warp nether',
    sound: 'entity.enderman.teleport',
  ),
]);

HuiMenu buildSettingsTemplate() => _menu(<HuiComponent>[
  _text('title', 0, 0.95, '&d&lPlayer Settings\n&7Click a row to switch it'),
  HuiComponent(
    'flight',
    Vec3(0, 0.4, 0),
    HuiToggleData(
      0.05,
      '%essentials_fly%',
      'true',
      <HuiAction>[
        HuiCommandAction('/fly on', 'player'),
        HuiSoundAction('block.note_block.harp', 'master', 1, 1.5),
      ],
      <HuiAction>[
        HuiCommandAction('/fly off', 'player'),
        HuiSoundAction('block.note_block.harp', 'master', 1, 0.8),
      ],
      HuiTextIcon('&a[ON]  &fFlight'),
      HuiTextIcon('&8[OFF] &7Flight'),
    ),
  ),
  HuiComponent(
    'godmode',
    Vec3(0, 0.1, 0),
    HuiToggleData(
      0.05,
      '%essentials_godmode%',
      'true',
      <HuiAction>[
        HuiCommandAction('/god on', 'player'),
        HuiSoundAction('block.note_block.harp', 'master', 1, 1.5),
      ],
      <HuiAction>[
        HuiCommandAction('/god off', 'player'),
        HuiSoundAction('block.note_block.harp', 'master', 1, 0.8),
      ],
      HuiTextIcon('&a[ON]  &fGod mode'),
      HuiTextIcon('&8[OFF] &7God mode'),
    ),
  ),
  _text(
    'note',
    0,
    -0.3,
    '&7Conditions are read once, when the menu opens.\n'
        '&8Requires EssentialsX and the PAPI Essentials expansion.',
  ),
  _commandButton(
    'close',
    0,
    -0.8,
    HuiTextIcon('&c[ Close ]'),
    '/holoui close',
    sound: 'block.note_block.bass',
  ),
]);

HuiMenu buildInfoTemplate() => _menu(<HuiComponent>[
  _text('heading', 0, 1.15, '&6&lSERVER RULES'),
  _text(
    'body',
    0,
    0.3,
    '&8-----------------------------\n'
        '&f1. &7Be respectful in chat\n'
        '&f2. &7No griefing or stealing\n'
        '&f3. &7No cheats or exploits\n'
        '&f4. &7Report bugs to the staff\n'
        '&8-----------------------------',
  ),
  _text('footer', 0, -0.6, '&eRun /rules &7for the full list'),
]);

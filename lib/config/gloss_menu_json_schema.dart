/// The menu format as a JSON-path model.
///
/// Read out of `model/hui_menu.dart`, `model/hui_component.dart`,
/// `model/hui_icons.dart` and `model/hui_actions.dart` — the `toJson` bodies
/// and the `_known` sets beside them — with the allowed values taken from the
/// `const List<String>` tables those files already publish, so a new icon type
/// or action trigger lands in one place and shows up here.
///
/// Menus are the one kind with a shipped schema (`schema/gloss.schema.json` in
/// the plugin), but the schema is not the source: `field_docs.g.dart` is
/// generated from it and is wired in through [GlossJsonField.docKey], which
/// keeps the prose in one place instead of two.
///
/// Three unions live here — component data, icons and actions — and all three
/// discriminate on a mandatory `type`. `EnumType.read` throws on an unknown
/// tag and `ConfigManager.loadConfig` catches it around the whole document, so
/// a misspelled type costs the entire menu file; that is why the `type` field
/// is always the first thing completion offers inside one of these objects.
library;

import '../logic/json_schema.dart';
import '../model/hui_actions.dart';
import '../model/hui_component.dart';
import '../model/hui_icons.dart';

/// `[x, y, z]`, the shape `BukkitTypeAdapters.VECTOR` reads. Exactly three
/// numbers: two or four throw and kill the file.
const GlossJsonArray glossVector3Node = GlossJsonArray(
  itemType: GlossJsonType.number,
  itemTitle: 'Axis',
  itemSummary: 'One of x, y, z, in blocks.',
  fixedLength: 3,
);

List<GlossJsonValue> _values(List<String> tokens) => <GlossJsonValue>[
  for (final String token in tokens) GlossJsonValue('"$token"'),
];

/// `icon.style` — the shared display block behind every icon but `entity`.
final GlossJsonObject glossIconStyleNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'billboard',
      type: GlossJsonType.string,
      title: 'Billboard',
      summary: 'Which axes the display rotates on to face the viewer.',
      docKey: 'icon.style.billboard',
      values: _values(huiIconBillboards),
      defaultLiteral: '"fixed"',
    ),
    const GlossJsonField(
      key: 'shadow',
      type: GlossJsonType.boolean,
      title: 'Shadow',
      summary: 'Draws the vanilla text drop shadow.',
      docKey: 'icon.style.shadow',
      defaultLiteral: 'false',
    ),
    const GlossJsonField(
      key: 'seeThrough',
      type: GlossJsonType.boolean,
      title: 'See through',
      summary: 'Renders through blocks instead of being occluded by them.',
      docKey: 'icon.style.seeThrough',
      defaultLiteral: 'false',
    ),
    GlossJsonField(
      key: 'textAlignment',
      type: GlossJsonType.string,
      title: 'Text alignment',
      summary: 'How multi-line text lines up inside the display.',
      docKey: 'icon.style.textAlignment',
      values: _values(huiIconTextAlignments),
      defaultLiteral: '"center"',
    ),
    const GlossJsonField(
      key: 'backgroundArgb',
      type: GlossJsonType.string,
      title: 'Background',
      summary: 'Panel colour behind the text, as #AARRGGBB.',
      docKey: 'icon.style.backgroundArgb',
      defaultLiteral: '"#00000000"',
    ),
    const GlossJsonField(
      key: 'textOpacity',
      type: GlossJsonType.integer,
      title: 'Text opacity',
      summary: 'Glyph alpha, 0 through 255.',
      docKey: 'icon.style.textOpacity',
      defaultLiteral: '255',
    ),
    const GlossJsonField(
      key: 'lineWidth',
      type: GlossJsonType.integer,
      title: 'Line width',
      summary: 'Pixel width the client wraps text at.',
      docKey: 'icon.style.lineWidth',
      defaultLiteral: '16384',
    ),
    const GlossJsonField(
      key: 'blockLight',
      type: GlossJsonType.integer,
      title: 'Block light',
      summary: 'Block-light override, 0 through 15. Absent means world light.',
      docKey: 'icon.style.blockLight',
    ),
    const GlossJsonField(
      key: 'skyLight',
      type: GlossJsonType.integer,
      title: 'Sky light',
      summary: 'Sky-light override, 0 through 15. Absent means world light.',
      docKey: 'icon.style.skyLight',
    ),
    const GlossJsonField(
      key: 'viewRange',
      type: GlossJsonType.number,
      title: 'View range',
      summary: 'Render distance multiplier against the client entity range.',
      docKey: 'icon.style.viewRange',
      defaultLiteral: '1',
    ),
    const GlossJsonField(
      key: 'shadowRadius',
      type: GlossJsonType.number,
      title: 'Shadow radius',
      summary: 'Ground shadow blob radius, in blocks. 0 draws none.',
      docKey: 'icon.style.shadowRadius',
      defaultLiteral: '0',
    ),
    const GlossJsonField(
      key: 'shadowStrength',
      type: GlossJsonType.number,
      title: 'Shadow strength',
      summary: 'Ground shadow opacity.',
      docKey: 'icon.style.shadowStrength',
      defaultLiteral: '0',
    ),
    const GlossJsonField(
      key: 'cullingWidth',
      type: GlossJsonType.number,
      title: 'Culling width',
      summary: 'Client culling box width. 0 uses the client default.',
      docKey: 'icon.style.cullingWidth',
      defaultLiteral: '0',
    ),
    const GlossJsonField(
      key: 'cullingHeight',
      type: GlossJsonType.number,
      title: 'Culling height',
      summary: 'Client culling box height. 0 uses the client default.',
      docKey: 'icon.style.cullingHeight',
      defaultLiteral: '0',
    ),
    const GlossJsonField(
      key: 'glowColor',
      type: GlossJsonType.string,
      title: 'Glow colour',
      summary: 'Outline colour while glowing, as #RRGGBB.',
      docKey: 'icon.style.glowColor',
    ),
    const GlossJsonField(
      key: 'scaleX',
      type: GlossJsonType.number,
      title: 'Scale X',
      summary: 'Display scale on x.',
      docKey: 'icon.style.scaleX',
      defaultLiteral: '1',
    ),
    const GlossJsonField(
      key: 'scaleY',
      type: GlossJsonType.number,
      title: 'Scale Y',
      summary: 'Display scale on y.',
      docKey: 'icon.style.scaleY',
      defaultLiteral: '1',
    ),
    const GlossJsonField(
      key: 'scaleZ',
      type: GlossJsonType.number,
      title: 'Scale Z',
      summary: 'Display scale on z.',
      docKey: 'icon.style.scaleZ',
      defaultLiteral: '1',
    ),
  ],
);

final GlossJsonField _styleField = GlossJsonField(
  key: 'style',
  type: GlossJsonType.object,
  title: 'Style',
  summary: 'Display settings shared by every icon but entity.',
  docKey: 'icon.style',
  node: glossIconStyleNode,
);

/// `icon` — the seven authorable icon types. `itemStack` is deliberately
/// absent: `MenuIconType` declares it with a null data class, so `EnumType`
/// filters it out before reading and a file that names it is rejected.
final GlossJsonObject glossIconNode = GlossJsonObject(
  discriminator: 'type',
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'type',
      type: GlossJsonType.string,
      title: 'Icon type',
      summary: 'Which icon this is. Mandatory; an unknown type kills the file.',
      docKey: 'icon.type',
      values: _values(huiIconTypes),
    ),
  ],
  variants: <String, List<GlossJsonField>>{
    'text': <GlossJsonField>[
      const GlossJsonField(
        key: 'text',
        type: GlossJsonType.string,
        title: 'Text',
        summary: 'The rendered line. MiniMessage, legacy codes, placeholders.',
        docKey: 'icon.text.text',
        defaultLiteral: '""',
      ),
      const GlossJsonField(
        key: 'refreshTicks',
        type: GlossJsonType.integer,
        title: 'Refresh ticks',
        summary:
            'Re-render cadence for placeholder text. 20 ticks is a second.',
        docKey: 'icon.text.refreshTicks',
      ),
      _styleField,
    ],
    'textImage': <GlossJsonField>[
      const GlossJsonField(
        key: 'path',
        type: GlossJsonType.string,
        title: 'Image path',
        summary: 'File under plugins/Gloss/images/, extension included.',
        docKey: 'icon.textImage.path',
        defaultLiteral: '""',
      ),
      _styleField,
    ],
    'animatedTextImage': <GlossJsonField>[
      const GlossJsonField(
        key: 'source',
        type: GlossJsonType.array,
        title: 'Frames',
        summary: 'Image paths, one per frame, in play order.',
        docKey: 'icon.animated.source',
        node: GlossJsonArray(
          itemType: GlossJsonType.string,
          itemTitle: 'Frame',
          itemSummary: 'One image path under plugins/Gloss/images/.',
        ),
      ),
      const GlossJsonField(
        key: 'speed',
        type: GlossJsonType.integer,
        title: 'Speed',
        summary: 'Ticks per frame, from 2 through 1200.',
        docKey: 'icon.animated.speed',
        defaultLiteral: '2',
      ),
      _styleField,
      const GlossJsonField(
        key: 'path',
        type: GlossJsonType.any,
        title: 'Frames (pre-3.0)',
        summary:
            'The old name for source. Imports migrate it; Gson ignores it.',
        legacy: true,
      ),
    ],
    'item': <GlossJsonField>[
      const GlossJsonField(
        key: 'item',
        type: GlossJsonType.string,
        title: 'Item',
        summary: 'Lowercase registry key. An uppercase key parses to null.',
        docKey: 'icon.item.item',
        defaultLiteral: '""',
      ),
      const GlossJsonField(
        key: 'count',
        type: GlossJsonType.integer,
        title: 'Count',
        summary: 'Stack size, which changes the rendered model on some items.',
        docKey: 'icon.item.count',
        defaultLiteral: '1',
      ),
      const GlossJsonField(
        key: 'customModelValue',
        type: GlossJsonType.integer,
        title: 'Custom model value',
        summary: 'The resource-pack model selector. This exact spelling.',
        docKey: 'icon.item.customModelValue',
        defaultLiteral: '0',
      ),
      _styleField,
      const GlossJsonField(
        key: 'customModelData',
        type: GlossJsonType.any,
        title: 'Custom model data (pre-3.0)',
        summary: 'The old misspelling. Imports migrate it; Gson ignores it.',
        legacy: true,
      ),
    ],
    'block': <GlossJsonField>[
      const GlossJsonField(
        key: 'block',
        type: GlossJsonType.string,
        title: 'Block',
        summary: 'Lowercase namespaced block key, e.g. minecraft:stone.',
        docKey: 'icon.block.block',
        defaultLiteral: '"minecraft:stone"',
      ),
      _styleField,
    ],
    'customItem': <GlossJsonField>[
      GlossJsonField(
        key: 'provider',
        type: GlossJsonType.string,
        title: 'Provider',
        summary: 'Which custom-item plugin owns the id, or auto to try each.',
        docKey: 'icon.customItem.provider',
        values: _values(<String>[
          huiAutoItemProvider,
          ...huiCustomItemProviders,
        ]),
        defaultLiteral: '"$huiAutoItemProvider"',
      ),
      const GlossJsonField(
        key: 'item',
        type: GlossJsonType.string,
        title: 'Item id',
        summary:
            'The provider\'s own id, verbatim. Several are case-sensitive.',
        docKey: 'icon.customItem.item',
        defaultLiteral: '""',
      ),
      const GlossJsonField(
        key: 'count',
        type: GlossJsonType.integer,
        title: 'Count',
        summary: 'Stack size. 0 and 1 mean the same stack.',
        docKey: 'icon.customItem.count',
        defaultLiteral: '1',
      ),
      _styleField,
    ],
    'entity': <GlossJsonField>[
      GlossJsonField(
        key: 'entity',
        type: GlossJsonType.string,
        title: 'Entity',
        summary: 'Lowercase namespaced entity key of a spawnable living type.',
        docKey: 'icon.entity.entity',
        values: _values(huiSpawnableLivingEntityTypes),
        defaultLiteral: '"minecraft:parrot"',
      ),
      const GlossJsonField(
        key: 'width',
        type: GlossJsonType.number,
        title: 'Width',
        summary: 'Click-plane width in blocks. Not the entity model scale.',
        docKey: 'icon.entity.width',
        defaultLiteral: '1',
      ),
      const GlossJsonField(
        key: 'height',
        type: GlossJsonType.number,
        title: 'Height',
        summary: 'Click-plane height in blocks. Not the entity model scale.',
        docKey: 'icon.entity.height',
        defaultLiteral: '1',
      ),
    ],
  },
);

/// `hitbox` — the optional custom click plane on a button or toggle.
const GlossJsonObject glossHitboxNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'width',
      type: GlossJsonType.number,
      title: 'Width',
      summary: 'Click-plane width in blocks. Needs height to take effect.',
      docKey: 'hitbox.width',
    ),
    GlossJsonField(
      key: 'height',
      type: GlossJsonType.number,
      title: 'Height',
      summary: 'Click-plane height in blocks. Needs width to take effect.',
      docKey: 'hitbox.height',
    ),
    GlossJsonField(
      key: 'offset',
      type: GlossJsonType.array,
      title: 'Offset',
      summary: 'Click-plane offset from its anchor, as [x, y, z].',
      docKey: 'hitbox.offset',
      node: glossVector3Node,
    ),
    GlossJsonField(
      key: 'anchor',
      type: GlossJsonType.string,
      title: 'Anchor',
      summary: 'What the offset is measured from.',
      docKey: 'hitbox.anchor',
      values: <GlossJsonValue>[
        GlossJsonValue('"button"', summary: 'The component itself.'),
        GlossJsonValue('"menu"', summary: 'The menu centre.'),
      ],
      defaultLiteral: '"button"',
    ),
  ],
);

/// `actions[]` — the six click actions.
final GlossJsonObject glossActionNode = GlossJsonObject(
  discriminator: 'type',
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'type',
      type: GlossJsonType.string,
      title: 'Action type',
      summary: 'Which action runs. Mandatory; an unknown type kills the file.',
      docKey: 'action.type',
      values: _values(huiActionTypes),
    ),
    GlossJsonField(
      key: 'trigger',
      type: GlossJsonType.string,
      title: 'Trigger',
      summary: 'Which click runs this action.',
      docKey: 'action.trigger',
      values: _values(huiActionTriggers),
      defaultLiteral: '"any"',
    ),
  ],
  variants: <String, List<GlossJsonField>>{
    'command': <GlossJsonField>[
      const GlossJsonField(
        key: 'command',
        type: GlossJsonType.string,
        title: 'Command',
        summary:
            "%player% and %player_name% become the clicking player's name; all other command tokens stay literal.",
        docKey: 'action.command.command',
        defaultLiteral: '""',
      ),
      GlossJsonField(
        key: 'source',
        type: GlossJsonType.string,
        title: 'Source',
        summary: 'Who runs it: the clicking player, or the console.',
        docKey: 'action.command.source',
        values: _values(huiCommandSources),
        defaultLiteral: '"player"',
      ),
    ],
    'sound': <GlossJsonField>[
      const GlossJsonField(
        key: 'sound',
        type: GlossJsonType.string,
        title: 'Sound',
        summary: 'Lowercase registry key, e.g. ui.button.click.',
        docKey: 'action.sound.sound',
        defaultLiteral: '"ui.button.click"',
      ),
      GlossJsonField(
        key: 'source',
        type: GlossJsonType.string,
        title: 'Category',
        summary: 'Which volume slider the client mixes this under.',
        docKey: 'action.sound.source',
        values: _values(huiSoundSources),
        defaultLiteral: '"master"',
      ),
      const GlossJsonField(
        key: 'volume',
        type: GlossJsonType.number,
        title: 'Volume',
        summary: 'Above 1 widens the audible radius. 0 is silence.',
        docKey: 'action.sound.volume',
        defaultLiteral: '1',
      ),
      const GlossJsonField(
        key: 'pitch',
        type: GlossJsonType.number,
        title: 'Pitch',
        summary: 'Playback rate, 0.5 through 2. 0 is silence.',
        docKey: 'action.sound.pitch',
        defaultLiteral: '1',
      ),
    ],
    'message': <GlossJsonField>[
      const GlossJsonField(
        key: 'message',
        type: GlossJsonType.string,
        title: 'Message',
        summary: 'MiniMessage text sent to the clicking player.',
        docKey: 'action.message.message',
        defaultLiteral: '""',
      ),
    ],
    'teleport': <GlossJsonField>[
      const GlossJsonField(
        key: 'world',
        type: GlossJsonType.string,
        title: 'World',
        summary: 'World key or name, resolved on the server.',
        docKey: 'action.teleport.world',
        defaultLiteral: '"minecraft:overworld"',
      ),
      const GlossJsonField(
        key: 'x',
        type: GlossJsonType.number,
        title: 'X',
        summary: 'Destination x, in blocks.',
        docKey: 'action.teleport.x',
        defaultLiteral: '0',
      ),
      const GlossJsonField(
        key: 'y',
        type: GlossJsonType.number,
        title: 'Y',
        summary: 'Destination y, in blocks.',
        docKey: 'action.teleport.y',
        defaultLiteral: '0',
      ),
      const GlossJsonField(
        key: 'z',
        type: GlossJsonType.number,
        title: 'Z',
        summary: 'Destination z, in blocks.',
        docKey: 'action.teleport.z',
        defaultLiteral: '0',
      ),
      const GlossJsonField(
        key: 'yaw',
        type: GlossJsonType.number,
        title: 'Yaw',
        summary: 'Facing yaw in degrees after the teleport.',
        docKey: 'action.teleport.yaw',
        defaultLiteral: '0',
      ),
      const GlossJsonField(
        key: 'pitch',
        type: GlossJsonType.number,
        title: 'Pitch',
        summary: 'Facing pitch in degrees after the teleport.',
        docKey: 'action.teleport.pitch',
        defaultLiteral: '0',
      ),
    ],
    'connect': <GlossJsonField>[
      const GlossJsonField(
        key: 'server',
        type: GlossJsonType.string,
        title: 'Server',
        summary: 'Configured proxy server name.',
        docKey: 'action.connect.server',
        defaultLiteral: '"lobby"',
      ),
    ],
    'navigate': <GlossJsonField>[
      const GlossJsonField(
        key: 'target',
        type: GlossJsonType.string,
        title: 'Target menu',
        summary: 'Menu id to open. Required by push and replace.',
        docKey: 'action.navigation.target',
        defaultLiteral: '""',
      ),
      GlossJsonField(
        key: 'mode',
        type: GlossJsonType.string,
        title: 'Mode',
        summary: 'What this does to the viewer\'s page stack.',
        docKey: 'action.navigation.mode',
        values: _values(huiNavigationModes),
        defaultLiteral: '"push"',
      ),
    ],
  },
);

final GlossJsonArray _actionsNode = GlossJsonArray(
  item: glossActionNode,
  itemType: GlossJsonType.object,
  itemTitle: 'Action',
  itemSummary: 'One click action.',
);

const GlossJsonField _highlightModifierField = GlossJsonField(
  key: 'highlightModifier',
  type: GlossJsonType.number,
  title: 'Highlight modifier',
  summary: 'Blocks the icon leans toward the viewer while hovered.',
  docKey: 'button.highlightModifier',
  defaultLiteral: '0.05',
);

const GlossJsonField _hoverDurationField = GlossJsonField(
  key: 'hoverDurationTicks',
  type: GlossJsonType.integer,
  title: 'Hover duration',
  summary: 'Ticks the hover push takes to play in or out.',
  docKey: 'button.hoverDurationTicks',
  defaultLiteral: '4',
);

final GlossJsonField _hoverEasingField = GlossJsonField(
  key: 'hoverEasing',
  type: GlossJsonType.string,
  title: 'Hover easing',
  summary: 'Curve the hover push follows.',
  docKey: 'button.hoverEasing',
  values: _values(<String>[
    for (final HuiHoverEasing easing in HuiHoverEasing.values) easing.jsonValue,
  ]),
  defaultLiteral: '"${huiRuntimeDefaultHoverEasing.jsonValue}"',
);

const GlossJsonField _hitboxField = GlossJsonField(
  key: 'hitbox',
  type: GlossJsonType.object,
  title: 'Hitbox',
  summary: 'Optional custom click plane; absent follows the visible render.',
  docKey: 'button.hitbox',
  node: glossHitboxNode,
);

final GlossJsonField _iconField = GlossJsonField(
  key: 'icon',
  type: GlossJsonType.object,
  title: 'Icon',
  summary: 'What the component draws. Absent renders the magenta placeholder.',
  docKey: 'button.icon',
  node: glossIconNode,
);

/// `components[].data` — the three component types.
final GlossJsonObject glossComponentDataNode = GlossJsonObject(
  discriminator: 'type',
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'type',
      type: GlossJsonType.string,
      title: 'Component type',
      summary: 'Which component this is. Mandatory.',
      docKey: 'component.type',
      values: _values(huiComponentTypes),
    ),
  ],
  variants: <String, List<GlossJsonField>>{
    'button': <GlossJsonField>[
      _highlightModifierField,
      _hitboxField,
      _hoverDurationField,
      _hoverEasingField,
      _iconField,
      GlossJsonField(
        key: 'actions',
        type: GlossJsonType.array,
        title: 'Actions',
        summary: 'Everything this button runs when it is clicked.',
        docKey: 'button.actions',
        node: _actionsNode,
      ),
    ],
    'decoration': <GlossJsonField>[
      GlossJsonField(
        key: 'icon',
        type: GlossJsonType.object,
        title: 'Icon',
        summary: 'What the decoration draws. Decorations never take clicks.',
        docKey: 'decoration.icon',
        node: glossIconNode,
      ),
    ],
    'toggle': <GlossJsonField>[
      const GlossJsonField(
        key: 'highlightModifier',
        type: GlossJsonType.number,
        title: 'Highlight modifier',
        summary: 'Blocks the icon leans toward the viewer while hovered.',
        docKey: 'toggle.highlightModifier',
        defaultLiteral: '0.05',
      ),
      const GlossJsonField(
        key: 'condition',
        type: GlossJsonType.string,
        title: 'Condition',
        summary: 'Placeholder expanded once at open, then never re-evaluated.',
        docKey: 'toggle.condition',
        defaultLiteral: '""',
      ),
      const GlossJsonField(
        key: 'expectedValue',
        type: GlossJsonType.string,
        title: 'Expected value',
        summary: 'Compared to the condition with equalsIgnoreCase.',
        docKey: 'toggle.expectedValue',
        defaultLiteral: '""',
      ),
      const GlossJsonField(
        key: 'hitbox',
        type: GlossJsonType.object,
        title: 'Hitbox',
        summary: 'Optional custom click plane shared by both states.',
        docKey: 'toggle.hitbox',
        node: glossHitboxNode,
      ),
      const GlossJsonField(
        key: 'hoverDurationTicks',
        type: GlossJsonType.integer,
        title: 'Hover duration',
        summary: 'Ticks the hover push takes to play in or out.',
        docKey: 'toggle.hoverDurationTicks',
        defaultLiteral: '4',
      ),
      GlossJsonField(
        key: 'hoverEasing',
        type: GlossJsonType.string,
        title: 'Hover easing',
        summary: 'Curve the hover push follows.',
        docKey: 'toggle.hoverEasing',
        values: _values(<String>[
          for (final HuiHoverEasing easing in HuiHoverEasing.values)
            easing.jsonValue,
        ]),
        defaultLiteral: '"${huiRuntimeDefaultHoverEasing.jsonValue}"',
      ),
      GlossJsonField(
        key: 'trueIcon',
        type: GlossJsonType.object,
        title: 'True icon',
        summary: 'Drawn while the condition matches the expected value.',
        docKey: 'toggle.trueIcon',
        node: glossIconNode,
      ),
      GlossJsonField(
        key: 'falseIcon',
        type: GlossJsonType.object,
        title: 'False icon',
        summary: 'Drawn while the condition does not match.',
        docKey: 'toggle.falseIcon',
        node: glossIconNode,
      ),
      GlossJsonField(
        key: 'trueActions',
        type: GlossJsonType.array,
        title: 'True actions',
        summary: 'Run on click while the condition matches.',
        docKey: 'toggle.trueActions',
        node: _actionsNode,
      ),
      GlossJsonField(
        key: 'falseActions',
        type: GlossJsonType.array,
        title: 'False actions',
        summary: 'Run on click while the condition does not match.',
        docKey: 'toggle.falseActions',
        node: _actionsNode,
      ),
    ],
  },
);

/// `components[]`.
final GlossJsonObject glossComponentNode = GlossJsonObject(
  fields: <GlossJsonField>[
    const GlossJsonField(
      key: 'id',
      type: GlossJsonType.string,
      title: 'Component id',
      summary: 'How the Java API addresses it. The first duplicate id wins.',
      docKey: 'component.id',
      defaultLiteral: '""',
    ),
    const GlossJsonField(
      key: 'offset',
      type: GlossJsonType.array,
      title: 'Offset',
      summary: 'Position from the menu centre, as [x, y, z], times uiScale.',
      docKey: 'component.offset',
      node: glossVector3Node,
    ),
    GlossJsonField(
      key: 'data',
      type: GlossJsonType.object,
      title: 'Data',
      summary: 'The component body: button, decoration or toggle.',
      docKey: 'component.data',
      node: glossComponentDataNode,
    ),
  ],
);

/// The menu document root.
final GlossJsonObject glossMenuJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    const GlossJsonField(
      key: 'offset',
      type: GlossJsonType.array,
      title: 'Menu offset',
      summary: 'Menu centre from the player\'s feet, as [x, y, z], in blocks.',
      docKey: 'menu.offset',
      node: glossVector3Node,
    ),
    const GlossJsonField(
      key: 'lockPosition',
      type: GlossJsonType.boolean,
      title: 'Lock position',
      summary: 'Freezes the player in place while the menu is open.',
      docKey: 'menu.lockPosition',
      defaultLiteral: 'false',
    ),
    const GlossJsonField(
      key: 'followPlayer',
      type: GlossJsonType.boolean,
      title: 'Follow player',
      summary: 'Re-centres the menu on the player as they move and look.',
      docKey: 'menu.followPlayer',
      defaultLiteral: 'false',
    ),
    const GlossJsonField(
      key: 'maxDistance',
      type: GlossJsonType.number,
      title: 'Max distance',
      summary: 'Closes the menu past this range. Absent means unlimited.',
      docKey: 'menu.maxDistance',
    ),
    const GlossJsonField(
      key: 'closeOnDeath',
      type: GlossJsonType.boolean,
      title: 'Close on death',
      summary: 'Closes the session when the viewer dies.',
      docKey: 'menu.closeOnDeath',
      defaultLiteral: 'false',
    ),
    const GlossJsonField(
      key: 'closeOnTeleport',
      type: GlossJsonType.boolean,
      title: 'Close on teleport',
      summary: 'Closes the session on any teleport.',
      docKey: 'menu.closeOnTeleport',
      defaultLiteral: 'false',
    ),
    GlossJsonField(
      key: 'components',
      type: GlossJsonType.array,
      title: 'Components',
      summary: 'Everything the menu draws, in file order.',
      docKey: 'menu.components',
      node: GlossJsonArray(
        item: glossComponentNode,
        itemType: GlossJsonType.object,
        itemTitle: 'Component',
        itemSummary: 'One button, decoration or toggle.',
      ),
    ),
    const GlossJsonField(
      key: 'id',
      type: GlossJsonType.string,
      title: 'Menu id',
      summary: 'Overwritten from the file path after parsing. Never authored.',
      docKey: 'menu.id',
      legacy: true,
    ),
  ],
);

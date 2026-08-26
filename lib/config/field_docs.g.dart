// GENERATED FILE - DO NOT HAND-EDIT.
//
// Regenerate with `dart run tool/extract_field_docs.dart`.
// Source: gloss.schema.json, gloss-preview.schema.json, gloss-real-drops.schema.json in the Gloss plugin repo.

/// Schema-derived field help: the fallback layer behind the
/// hand-written entries in `field_docs.dart`.
///
/// Every body here is the plugin schema's own `description`,
/// plus the accepted values, range and default the inspector
/// cannot show inline. A hand-written doc for the same key
/// always wins, so this file never needs a review pass of its
/// own — see `huiFieldDoc` in `field_docs.dart`.
library;

import 'field_docs.dart';

const Map<String, HuiFieldDoc> huiGeneratedFieldDocs = <String, HuiFieldDoc>{
  'action.command.command': HuiFieldDoc(
    title: 'Command',
    body:
        'Defines the command run by this action. %player% and '
        '%player_name% become the clicking player\'s name before player or '
        'server dispatch.',
    citation: 'gloss.schema.json#/\$defs/commandAction/properties/command',
  ),
  'action.command.source': HuiFieldDoc(
    title: 'Source',
    body:
        'Defines the source of this command. Defaults to "player", so the '
        'command runs as the clicking player unless "server" is written '
        'explicitly. Accepted values: server, player.',
    citation: 'gloss.schema.json#/\$defs/commandAction/properties/source',
  ),
  'action.connect.server': HuiFieldDoc(
    title: 'Server',
    body:
        'Configured proxy server name. Only letters, numbers, dot, '
        'underscore, and hyphen are accepted.',
    citation: 'gloss.schema.json#/\$defs/connectAction/properties/server',
  ),
  'action.message.message': HuiFieldDoc(
    title: 'Message',
    body:
        'MiniMessage text sent to the player. %player% and PlaceholderAPI '
        'placeholders are resolved for the clicking player before '
        'parsing.',
    citation: 'gloss.schema.json#/\$defs/messageAction/properties/message',
  ),
  'action.navigation': HuiFieldDoc(
    title: 'Navigation action',
    body:
        'Changes the current viewer\'s native menu page stack. Navigation '
        'is terminal for actions matching the current click trigger.',
    citation: 'gloss.schema.json#/\$defs/navigationAction',
  ),
  'action.navigation.mode': HuiFieldDoc(
    title: 'Mode',
    body:
        'Page-stack operation. Defaults to push. Accepted values: push, '
        'replace, back, home, close.',
    citation: 'gloss.schema.json#/\$defs/navigationAction/properties/mode',
  ),
  'action.navigation.target': HuiFieldDoc(
    title: 'Target',
    body: 'Exact menu id opened by push or replace navigation.',
    citation: 'gloss.schema.json#/\$defs/navigationAction/properties/target',
  ),
  'action.sound.pitch': HuiFieldDoc(
    title: 'Pitch',
    body: 'Defines the pitch modifier for this sound. Defaults to 1.0.',
    citation: 'gloss.schema.json#/\$defs/soundAction/properties/pitch',
  ),
  'action.sound.sound': HuiFieldDoc(
    title: 'Sound',
    body:
        'Defines the sound played by this action. An unknown sound key is '
        'logged when the component resolves its actions and the action is '
        'dropped.',
    citation: 'gloss.schema.json#/\$defs/soundAction/properties/sound',
  ),
  'action.sound.source': HuiFieldDoc(
    title: 'Source',
    body:
        'Defines the audio channel of this sound. Defaults to "master". '
        'Accepted values: master, music, record, weather, block, hostile, '
        'neutral, player, ambient, voice.',
    citation: 'gloss.schema.json#/\$defs/soundAction/properties/source',
  ),
  'action.sound.volume': HuiFieldDoc(
    title: 'Volume',
    body: 'Defines the volume modifier for this sound. Defaults to 1.0.',
    citation: 'gloss.schema.json#/\$defs/soundAction/properties/volume',
  ),
  'action.teleport.pitch': HuiFieldDoc(
    title: 'Pitch',
    body: 'Finite destination pitch in degrees.',
    citation: 'gloss.schema.json#/\$defs/teleportAction/properties/pitch',
  ),
  'action.teleport.world': HuiFieldDoc(
    title: 'World',
    body:
        'Explicit lowercase namespace:key of an already-loaded Bukkit '
        'world.',
    citation: 'gloss.schema.json#/\$defs/teleportAction/properties/world',
  ),
  'action.teleport.x': HuiFieldDoc(
    title: 'X',
    body: 'Finite destination X coordinate.',
    citation: 'gloss.schema.json#/\$defs/teleportAction/properties/x',
  ),
  'action.teleport.y': HuiFieldDoc(
    title: 'Y',
    body: 'Finite destination Y coordinate.',
    citation: 'gloss.schema.json#/\$defs/teleportAction/properties/y',
  ),
  'action.teleport.yaw': HuiFieldDoc(
    title: 'Yaw',
    body: 'Finite destination yaw in degrees.',
    citation: 'gloss.schema.json#/\$defs/teleportAction/properties/yaw',
  ),
  'action.teleport.z': HuiFieldDoc(
    title: 'Z',
    body: 'Finite destination Z coordinate.',
    citation: 'gloss.schema.json#/\$defs/teleportAction/properties/z',
  ),
  'action.trigger': HuiFieldDoc(
    title: 'Trigger',
    body:
        'Optional click binding. Omitted or null matches every accepted '
        'main-hand click. Accepted values: any, left_click, right_click, '
        'shift_left_click, shift_right_click. Omitted, this is any.',
    citation: 'gloss.schema.json#/\$defs/action/properties/trigger',
  ),
  'action.type': HuiFieldDoc(
    title: 'Type',
    body:
        'Defines the type of action. Accepted values: command, sound, '
        'message, teleport, connect, navigate.',
    citation: 'gloss.schema.json#/\$defs/action/properties/type',
  ),
  'button.actions': HuiFieldDoc(
    title: 'Actions',
    body: 'Defines what happens upon a interaction.',
    citation: 'gloss.schema.json#/\$defs/buttonComponent/properties/actions',
  ),
  'button.highlightModifier': HuiFieldDoc(
    title: 'Highlight modifier',
    body: 'Menu-local travel toward the viewer at uiScale 1.',
    citation:
        'gloss.schema.json#/\$defs/buttonComponent/properties/highlightModifier',
  ),
  'button.hitbox': HuiFieldDoc(
    title: 'Hitbox',
    body:
        'Optional dimensions and displacement for the click plane. '
        'Omitted dimensions remain automatic; omitted offset remains '
        'icon-aligned.',
    citation: 'gloss.schema.json#/\$defs/buttonComponent/properties/hitbox',
  ),
  'button.hoverDurationTicks': HuiFieldDoc(
    title: 'Hover duration ticks',
    body:
        'Ticks used to enter and leave the hovered pose. Defaults to 4; '
        'zero is instant. Accepted range: 0 through 40.',
    citation:
        'gloss.schema.json#/\$defs/buttonComponent/properties/hoverDurationTicks',
  ),
  'button.hoverEasing': HuiFieldDoc(
    title: 'Hover easing',
    body:
        'Easing curve used for hover entry and exit. Defaults to '
        'ease_out_cubic. Accepted values: linear, ease_out_cubic, '
        'ease_in_out_cubic, back_out.',
    citation:
        'gloss.schema.json#/\$defs/buttonComponent/properties/hoverEasing',
  ),
  'button.icon': HuiFieldDoc(
    title: 'Icon',
    body: 'Defines the visual part of the component.',
    citation: 'gloss.schema.json#/\$defs/buttonComponent/properties/icon',
  ),
  'component.data': HuiFieldDoc(
    title: 'Data',
    body: 'The type and associated data of the object.',
    citation: 'gloss.schema.json#/\$defs/component/properties/data',
  ),
  'component.id': HuiFieldDoc(
    title: 'Id',
    body: 'A unique identifier for this menu option.',
    citation: 'gloss.schema.json#/\$defs/component/properties/id',
  ),
  'component.offset': HuiFieldDoc(
    title: 'Offset',
    body: 'The offset relative to the menu\'s center point.',
    citation: 'gloss.schema.json#/\$defs/component/properties/offset',
  ),
  'component.type': HuiFieldDoc(
    title: 'Type',
    body:
        'Defines the type of component. Accepted values: button, '
        'decoration, toggle.',
    citation: 'gloss.schema.json#/\$defs/componentData/properties/type',
  ),
  'decoration.icon': HuiFieldDoc(
    title: 'Icon',
    body: 'Defines the visual parts of a component.',
    citation: 'gloss.schema.json#/\$defs/decoComponent/properties/icon',
  ),
  'hitbox.anchor': HuiFieldDoc(
    title: 'Anchor',
    body:
        'Whether offset is relative to the clickable component or the '
        'menu centre. Menu anchoring detaches icon and plane movement. '
        'Accepted values: button, menu.',
    citation: 'gloss.schema.json#/\$defs/hitbox/properties/anchor',
  ),
  'hitbox.height': HuiFieldDoc(
    title: 'Height',
    body:
        'Click-plane height in blocks at uiScale 1. Must be greater than '
        '0.',
    citation: 'gloss.schema.json#/\$defs/hitbox/properties/height',
  ),
  'hitbox.offset': HuiFieldDoc(
    title: 'Offset',
    body:
        'Displacement from the selected anchor in right, up, forward '
        'blocks at uiScale 1.',
    citation: 'gloss.schema.json#/\$defs/hitbox/properties/offset',
  ),
  'hitbox.width': HuiFieldDoc(
    title: 'Width',
    body:
        'Click-plane width in blocks at uiScale 1. Must be greater than '
        '0.',
    citation: 'gloss.schema.json#/\$defs/hitbox/properties/width',
  ),
  'icon.animated.source': HuiFieldDoc(
    title: 'Source',
    body:
        'Defines the paths to the animation frames, relative to the '
        '"images" directory. A single path is accepted in place of the '
        'array.',
    citation:
        'gloss.schema.json#/\$defs/animatedTextImageIcon/properties/source',
  ),
  'icon.animated.speed': HuiFieldDoc(
    title: 'Speed',
    body:
        'Defines the amount of ticks between frame advances. Accepted '
        'range: 2 through 1200.',
    citation:
        'gloss.schema.json#/\$defs/animatedTextImageIcon/properties/speed',
  ),
  'icon.block.block': HuiFieldDoc(
    title: 'Block',
    body:
        'Lowercase Bukkit material id. An omitted namespace defaults to '
        'minecraft. The resolved material must be a block.',
    citation: 'gloss.schema.json#/\$defs/blockIcon/properties/block',
  ),
  'icon.customItem.count': HuiFieldDoc(
    title: 'Count',
    body:
        'Defines the count of the resolved item stack. Zero and negative '
        'values become 1.',
    citation: 'gloss.schema.json#/\$defs/customItemIcon/properties/count',
  ),
  'icon.customItem.item': HuiFieldDoc(
    title: 'Item',
    body: 'Defines the provider-specific item id, passed through verbatim.',
    citation: 'gloss.schema.json#/\$defs/customItemIcon/properties/item',
  ),
  'icon.customItem.provider': HuiFieldDoc(
    title: 'Provider',
    body:
        'Defines the item provider that resolves the item. Omitted, blank '
        'or "auto" tries every active provider in activation order.',
    citation: 'gloss.schema.json#/\$defs/customItemIcon/properties/provider',
  ),
  'icon.entity.entity': HuiFieldDoc(
    title: 'Entity',
    body:
        'Lowercase Bukkit entity registry id. An omitted namespace '
        'defaults to minecraft; only spawnable living entity types are '
        'accepted.',
    citation: 'gloss.schema.json#/\$defs/entityIcon/properties/entity',
  ),
  'icon.entity.height': HuiFieldDoc(
    title: 'Height',
    body:
        'Automatic click-plane height in blocks at uiScale 1. Omitted '
        'defaults to 1 and the plane is centered half this height above '
        'the component anchor. Accepted range: greater than 0, up to 64. '
        'Omitted, this is 1.',
    citation: 'gloss.schema.json#/\$defs/entityIcon/properties/height',
  ),
  'icon.entity.width': HuiFieldDoc(
    title: 'Width',
    body:
        'Automatic click-plane width in blocks at uiScale 1. Omitted '
        'defaults to 1. Accepted range: greater than 0, up to 64. '
        'Omitted, this is 1.',
    citation: 'gloss.schema.json#/\$defs/entityIcon/properties/width',
  ),
  'icon.item.count': HuiFieldDoc(
    title: 'Count',
    body:
        'Defines the count of the item stack constructed from the '
        'material.',
    citation: 'gloss.schema.json#/\$defs/itemIcon/properties/count',
  ),
  'icon.item.customModelValue': HuiFieldDoc(
    title: 'Custom model value',
    body:
        'Defines the custom model data property for use with resource '
        'packs.',
    citation: 'gloss.schema.json#/\$defs/itemIcon/properties/customModelValue',
  ),
  'icon.item.item': HuiFieldDoc(
    title: 'Item',
    body: 'Defines the type of item displayed.',
    citation: 'gloss.schema.json#/\$defs/itemIcon/properties/item',
  ),
  'icon.playerHead.player': HuiFieldDoc(
    title: 'Player',
    body:
        'Defines whose head to draw: a literal Minecraft username, or a '
        'placeholder resolved per viewer. %player_name%, %player% and {{ '
        'player.name }} always mean the viewer and need no '
        'PlaceholderAPI; any other placeholder resolves through the text '
        'pipeline and needs whatever provides it.',
    citation: 'gloss.schema.json#/\$defs/playerHeadIcon/properties/player',
  ),
  'icon.playerHead.refreshTicks': HuiFieldDoc(
    title: 'Refresh ticks',
    body:
        'Ticks between re-reading the name and the profile cache. Omitted '
        'defaults to 20. Zero never re-reads, which leaves a head whose '
        'lookup was still in flight as the unowned head. Accepted range: '
        '0 through 1200. Omitted, this is 20.',
    citation:
        'gloss.schema.json#/\$defs/playerHeadIcon/properties/refreshTicks',
  ),
  'icon.style': HuiFieldDoc(
    title: 'Style',
    body:
        'Optional display styling. Omitted uses fixed, fully visible, '
        'unlit-override defaults at uniform scale 1.',
    citation: 'gloss.schema.json#/\$defs/icon/properties/style',
  ),
  'icon.style.backgroundArgb': HuiFieldDoc(
    title: 'Background ARGB',
    body: 'Omitted, this is #00000000.',
    citation:
        'gloss.schema.json#/\$defs/iconDisplayStyle/properties/backgroundArgb',
  ),
  'icon.style.billboard': HuiFieldDoc(
    title: 'Billboard',
    body:
        'Accepted values: fixed, vertical, horizontal, center. Omitted, '
        'this is fixed.',
    citation: 'gloss.schema.json#/\$defs/iconDisplayStyle/properties/billboard',
  ),
  'icon.style.blockLight': HuiFieldDoc(
    title: 'Block light',
    body: 'Accepted range: 0 through 15.',
    citation:
        'gloss.schema.json#/\$defs/iconDisplayStyle/properties/blockLight',
  ),
  'icon.style.cullingHeight': HuiFieldDoc(
    title: 'Culling height',
    body: 'Accepted range: 0 through 4096. Omitted, this is 0.',
    citation:
        'gloss.schema.json#/\$defs/iconDisplayStyle/properties/cullingHeight',
  ),
  'icon.style.cullingWidth': HuiFieldDoc(
    title: 'Culling width',
    body: 'Accepted range: 0 through 4096. Omitted, this is 0.',
    citation:
        'gloss.schema.json#/\$defs/iconDisplayStyle/properties/cullingWidth',
  ),
  'icon.style.lineWidth': HuiFieldDoc(
    title: 'Line width',
    body: 'Accepted range: 1 through 16384. Omitted, this is 16384.',
    citation: 'gloss.schema.json#/\$defs/iconDisplayStyle/properties/lineWidth',
  ),
  'icon.style.scaleX': HuiFieldDoc(
    title: 'Scale X',
    body: 'Accepted range: 0.01 through 64. Omitted, this is 1.',
    citation: 'gloss.schema.json#/\$defs/iconDisplayStyle/properties/scaleX',
  ),
  'icon.style.scaleY': HuiFieldDoc(
    title: 'Scale Y',
    body: 'Accepted range: 0.01 through 64. Omitted, this is 1.',
    citation: 'gloss.schema.json#/\$defs/iconDisplayStyle/properties/scaleY',
  ),
  'icon.style.scaleZ': HuiFieldDoc(
    title: 'Scale Z',
    body: 'Accepted range: 0.01 through 64. Omitted, this is 1.',
    citation: 'gloss.schema.json#/\$defs/iconDisplayStyle/properties/scaleZ',
  ),
  'icon.style.seeThrough': HuiFieldDoc(
    title: 'See through',
    body: 'Omitted, this is false.',
    citation:
        'gloss.schema.json#/\$defs/iconDisplayStyle/properties/seeThrough',
  ),
  'icon.style.shadow': HuiFieldDoc(
    title: 'Shadow',
    body: 'Omitted, this is false.',
    citation: 'gloss.schema.json#/\$defs/iconDisplayStyle/properties/shadow',
  ),
  'icon.style.shadowRadius': HuiFieldDoc(
    title: 'Shadow radius',
    body: 'Accepted range: 0 through 64. Omitted, this is 0.',
    citation:
        'gloss.schema.json#/\$defs/iconDisplayStyle/properties/shadowRadius',
  ),
  'icon.style.shadowStrength': HuiFieldDoc(
    title: 'Shadow strength',
    body: 'Accepted range: 0 through 1. Omitted, this is 0.',
    citation:
        'gloss.schema.json#/\$defs/iconDisplayStyle/properties/shadowStrength',
  ),
  'icon.style.skyLight': HuiFieldDoc(
    title: 'Sky light',
    body: 'Accepted range: 0 through 15.',
    citation: 'gloss.schema.json#/\$defs/iconDisplayStyle/properties/skyLight',
  ),
  'icon.style.textAlignment': HuiFieldDoc(
    title: 'Text alignment',
    body: 'Accepted values: center, left, right. Omitted, this is center.',
    citation:
        'gloss.schema.json#/\$defs/iconDisplayStyle/properties/textAlignment',
  ),
  'icon.style.textOpacity': HuiFieldDoc(
    title: 'Text opacity',
    body: 'Accepted range: 0 through 255. Omitted, this is 255.',
    citation:
        'gloss.schema.json#/\$defs/iconDisplayStyle/properties/textOpacity',
  ),
  'icon.style.viewRange': HuiFieldDoc(
    title: 'View range',
    body: 'Accepted range: 0.01 through 64. Omitted, this is 1.',
    citation: 'gloss.schema.json#/\$defs/iconDisplayStyle/properties/viewRange',
  ),
  'icon.text.refreshTicks': HuiFieldDoc(
    title: 'Refresh ticks',
    body:
        'Ticks between live PlaceholderAPI updates. Omitted defaults to '
        '10; 0 disables updates after the initial render. Accepted range: '
        '0 through 1200. Omitted, this is 10.',
    citation: 'gloss.schema.json#/\$defs/textIcon/properties/refreshTicks',
  ),
  'icon.text.text': HuiFieldDoc(
    title: 'Text',
    body:
        'Defines the text displayed by this icon. Supports ampersand '
        'color codes, placeholders, and line breaks.',
    citation: 'gloss.schema.json#/\$defs/textIcon/properties/text',
  ),
  'icon.textImage.path': HuiFieldDoc(
    title: 'Path',
    body:
        'Defines the path to the image displayed, relative to the '
        '"images" directory.',
    citation: 'gloss.schema.json#/\$defs/textImageIcon/properties/path',
  ),
  'icon.type': HuiFieldDoc(
    title: 'Type',
    body:
        'Defines the type of icon. Accepted values: text, textImage, '
        'animatedTextImage, item, block, customItem, entity, playerHead.',
    citation: 'gloss.schema.json#/\$defs/icon/properties/type',
  ),
  'menu.closeOnDeath': HuiFieldDoc(
    title: 'Close on death',
    body:
        'Defines whether the menu closes when the player dies. Defaults '
        'to false.',
    citation: 'gloss.schema.json#/properties/closeOnDeath',
  ),
  'menu.closeOnTeleport': HuiFieldDoc(
    title: 'Close on teleport',
    body:
        'Defines whether the menu closes when the player teleports. '
        'Defaults to false. A teleport that leaves the menu\'s world or '
        'its range closes the menu regardless.',
    citation: 'gloss.schema.json#/properties/closeOnTeleport',
  ),
  'menu.components': HuiFieldDoc(
    title: 'Components',
    body: 'A list of menu components present in this menu.',
    citation: 'gloss.schema.json#/properties/components',
  ),
  'menu.followPlayer': HuiFieldDoc(
    title: 'Follow player',
    body:
        'Defines whether the menu follows the player, or will be frozen '
        'in place.',
    citation: 'gloss.schema.json#/properties/followPlayer',
  ),
  'menu.lockPosition': HuiFieldDoc(
    title: 'Lock position',
    body:
        'Defines whether the player is able to move while a menu is open, '
        'or will be frozen in place.',
    citation: 'gloss.schema.json#/properties/lockPosition',
  ),
  'menu.maxDistance': HuiFieldDoc(
    title: 'Max distance',
    body:
        'Defines the maximum distance between the player and menu before '
        'it closes.',
    citation: 'gloss.schema.json#/properties/maxDistance',
  ),
  'menu.offset': HuiFieldDoc(
    title: 'Offset',
    body:
        'Offset from the player\'s feet location (Player#getLocation), '
        'which acts as the menu centre. Component rotation pivots on the '
        'eye; the X component is negated on load. Not scaled by uiScale.',
    citation: 'gloss.schema.json#/properties/offset',
  ),
  'preview.card': HuiFieldDoc(
    title: 'Card',
    body:
        'The chrome drawn around the elements: frame, panel, tray, title '
        'bar and title. Omit the whole object for bare content with no '
        'chrome.',
    citation: 'gloss-preview.schema.json#/properties/card',
  ),
  'preview.card.accent': HuiFieldDoc(
    title: 'Accent',
    body:
        'Expression producing the chrome accent colour, evaluated once '
        'when the preview is built. Only the low 24 bits are used. '
        'Defaults to a neutral grey.',
    citation: 'gloss-preview.schema.json#/\$defs/card/properties/accent',
  ),
  'preview.card.framed': HuiFieldDoc(
    title: 'Framed',
    body:
        'Whether to draw the chrome. Evaluated once when the preview is '
        'built. Default true.',
    citation: 'gloss-preview.schema.json#/\$defs/card/properties/framed',
  ),
  'preview.card.minHalfWidth': HuiFieldDoc(
    title: 'Min half width',
    body:
        'Minimum half-width of the panel in pixels, so a narrow card does '
        'not collapse around a short title. Default 82.',
    citation: 'gloss-preview.schema.json#/\$defs/card/properties/minHalfWidth',
  ),
  'preview.card.title': HuiFieldDoc(
    title: 'Title',
    body:
        'Expression producing the title text, evaluated once when the '
        'preview is built. The result is parsed for legacy \'&\' codes and '
        'MiniMessage tags, so a title styles itself inline. The shipped '
        'idiom is "\'&f&l\' + (customName != \'\' ? customName : '
        'plain(lang(vars.titleKey)))".',
    citation: 'gloss-preview.schema.json#/\$defs/card/properties/title',
  ),
  'preview.element.background': HuiFieldDoc(
    title: 'Background',
    body:
        'Text background colour. Type label only. Default fully '
        'transparent.',
    citation: 'gloss-preview.schema.json#/\$defs/element/properties/background',
  ),
  'preview.element.color': HuiFieldDoc(
    title: 'Color',
    body:
        'Fill colour. Required for types panel and cell. On a cell this '
        'is one of the only two live fields: it is re-evaluated every '
        'four ticks while the preview is on screen. On a panel it is '
        'evaluated once when the preview is built.',
    citation: 'gloss-preview.schema.json#/\$defs/element/properties/color',
  ),
  'preview.element.height': HuiFieldDoc(
    title: 'Height',
    body: 'Panel height in pixels. Required for type panel.',
    citation: 'gloss-preview.schema.json#/\$defs/element/properties/height',
  ),
  'preview.element.index': HuiFieldDoc(
    title: 'Index',
    body:
        'Inventory slot index this well renders. Required for type slot. '
        'Guard it against inventory.size; nothing clamps it for you.',
    citation: 'gloss-preview.schema.json#/\$defs/element/properties/index',
  ),
  'preview.element.repeat': HuiFieldDoc(
    title: 'Repeat',
    body:
        'Emits this element once per index, with the index bound to a '
        'loop variable every field of the element can read.',
    citation: 'gloss-preview.schema.json#/\$defs/element/properties/repeat',
  ),
  'preview.element.size': HuiFieldDoc(
    title: 'Size',
    body: 'Square edge length in pixels. Required for types cell and slot.',
    citation: 'gloss-preview.schema.json#/\$defs/element/properties/size',
  ),
  'preview.element.text': HuiFieldDoc(
    title: 'Text',
    body:
        'Expression producing the label text. Required for type label. '
        'One of the only two live fields: re-evaluated every four ticks '
        'while the preview is on screen, unless it folds to a constant, '
        'in which case it is parsed once and reused. The result is parsed '
        'for legacy \'&\' codes and MiniMessage tags, so concatenating '
        'differently prefixed fragments in one expression yields one '
        'multi-run label.',
    citation: 'gloss-preview.schema.json#/\$defs/element/properties/text',
  ),
  'preview.element.type': HuiFieldDoc(
    title: 'Type',
    body:
        'panel: a flat rectangle. cell: a square swatch, the unit every '
        'gauge and flame is built from. slot: an inventory well that '
        'renders the item in it. label: parsed text. Accepted values: '
        'panel, cell, slot, label.',
    citation: 'gloss-preview.schema.json#/\$defs/element/properties/type',
  ),
  'preview.element.visible': HuiFieldDoc(
    title: 'Visible',
    body:
        'Skip this element when false. Evaluated once when the preview is '
        'built (per iteration inside a repeat), not per frame: an element '
        'hidden at build time stays hidden for the life of that preview. '
        'Default true.',
    citation: 'gloss-preview.schema.json#/\$defs/element/properties/visible',
  ),
  'preview.element.wellColor': HuiFieldDoc(
    title: 'Well color',
    body:
        'Colour of the well behind a slot\'s item. Type slot only. Default '
        '#FF15151B.',
    citation: 'gloss-preview.schema.json#/\$defs/element/properties/wellColor',
  ),
  'preview.element.width': HuiFieldDoc(
    title: 'Width',
    body: 'Panel width in pixels. Required for type panel.',
    citation: 'gloss-preview.schema.json#/\$defs/element/properties/width',
  ),
  'preview.element.x': HuiFieldDoc(
    title: 'X',
    body:
        'Horizontal offset in pixels from the card centre, positive '
        'right. Default 0.',
    citation: 'gloss-preview.schema.json#/\$defs/element/properties/x',
  ),
  'preview.element.y': HuiFieldDoc(
    title: 'Y',
    body:
        'Vertical offset in pixels from the card centre, positive up. '
        'Default 0.',
    citation: 'gloss-preview.schema.json#/\$defs/element/properties/y',
  ),
  'preview.element.z': HuiFieldDoc(
    title: 'Z',
    body:
        'Depth order, higher draws in front. Defaults to 1 for panel, 4 '
        'for cell and slot, 6 for label.',
    citation: 'gloss-preview.schema.json#/\$defs/element/properties/z',
  ),
  'preview.elements': HuiFieldDoc(
    title: 'Elements',
    body:
        'The content drawn inside the card, in paint order. A document '
        'that emits nothing draws no preview at all.',
    citation: 'gloss-preview.schema.json#/properties/elements',
  ),
  'preview.expression': HuiFieldDoc(
    title: 'Expression',
    body:
        'A string in the preview expression DSL, evaluated against the '
        'previewed container\'s live state. Only cell.color and label.text '
        'are re-evaluated while the preview is on screen (every 200 ms); '
        'every other expression field is evaluated once when the preview '
        'is built. Grammar: number, string (single- or double-quoted, '
        'escapes \\\\ \\\' \\" \\n), colour (#RGB, #RRGGBB, #AARRGGBB), '
        'true/false, variable (dotted, e.g. surge.active or vars.accent), '
        'nested array literal ([a, [b, c]]), call, unary ! and -, * / %, '
        '+ -, < <= > >=, == !=, &&, ||, and a ? b : c. Strings '
        'concatenate with +. % is Java\'s truncating remainder (-1 % 3 is '
        '-1) while mod() floors (mod(-1, 3) is 2); both throw on a zero '
        'divisor. Functions: clamp, lerp, min, max, floor, ceil, round, '
        'abs, mod, sin, cos, rgb, argb, alpha, mix, palette, str, fixed, '
        'plain, readable, align, marquee, timeline, typewriter, flash, '
        'wipe, scanner, scramble, odometer, wave, lang, count, occupied, '
        'item. See the Gloss docs pages '
        '/gloss/13-expressions-placeholders and '
        '/gloss/15-container-previews in the central VolmitSoftware/docs '
        'repo.',
    citation: 'gloss-preview.schema.json#/\$defs/expression',
  ),
  'preview.match': HuiFieldDoc(
    title: 'Match',
    body:
        'What this document draws, how strongly it claims it, and the '
        'variables it draws with.',
    citation: 'gloss-preview.schema.json#/properties/match',
  ),
  'preview.match.blocks': HuiFieldDoc(
    title: 'Blocks',
    body:
        'Block materials this document draws. A variant\'s own blocks '
        'extend this set rather than narrowing it.',
    citation: 'gloss-preview.schema.json#/\$defs/match/properties/blocks',
  ),
  'preview.match.entities': HuiFieldDoc(
    title: 'Entities',
    body:
        'Entity types this document draws. Exact names and globs make '
        'matching entities raycast targets even when they do not hold an '
        'inventory.',
    citation: 'gloss-preview.schema.json#/\$defs/match/properties/entities',
  ),
  'preview.match.priority': HuiFieldDoc(
    title: 'Priority',
    body:
        'Highest priority wins. Within one priority an exact name beats a '
        'glob, which beats the anyInventoryHolder fallback; a genuine tie '
        'is broken by document name and warned about. Shipped documents '
        'use 10, so a user document at 20 overrides one. Read from the '
        'top-level match only. Default 0.',
    citation: 'gloss-preview.schema.json#/\$defs/match/properties/priority',
  ),
  'preview.match.special': HuiFieldDoc(
    title: 'Special',
    body:
        'Marks this document as the one the plugin looks up by role '
        'rather than by target. \'enderChest\' draws the viewer\'s own ender '
        'chest instead of a tile entity, \'locked\' is the target-less card '
        'shown when a viewer may not open the container, and '
        '\'anyInventoryHolder\' is the fallback for an inventory-holding '
        'minecart or chest boat no document names. Read from the '
        'top-level match only. Accepted values: enderChest, locked, '
        'anyInventoryHolder.',
    citation: 'gloss-preview.schema.json#/\$defs/match/properties/special',
  ),
  'preview.match.vars': HuiFieldDoc(
    title: 'Vars',
    body:
        'Document-authored constants, read in expressions as vars.<name>. '
        'Values are JSON primitives only and are NEVER parsed as '
        'expressions, with one exception: a string leading with \'#\' is '
        'read as a colour literal so a variant can carry an accent as '
        '"#FFB02E26" without losing the alpha byte to a signed int. A '
        'leading \'#\' that is not a valid colour literal fails to compile.',
    citation: 'gloss-preview.schema.json#/\$defs/match/properties/vars',
  ),
  'preview.names': HuiFieldDoc(
    title: 'Match names',
    body:
        'Material or entity type names, uppercased before matching. \'*\' '
        'is the only wildcard, e.g. \'*_SHULKER_BOX\'. Names listed here '
        'and in any variant both count toward resolving the document. An '
        'exact name beats a glob at the same priority. An unknown name '
        'warns and still compiles, so a document survives a version that '
        'dropped the type.',
    citation: 'gloss-preview.schema.json#/\$defs/names',
  ),
  'preview.repeat.count': HuiFieldDoc(
    title: 'Count',
    body:
        'How many copies to emit. Evaluated once when the preview is '
        'built, not per frame, so a grid sizes itself from inventory.size '
        'at open time. A constant count above 1024 is a compile error and '
        'rejects the document; a dynamic count is truncated to 1024 at '
        'build with a reported error.',
    citation: 'gloss-preview.schema.json#/\$defs/repeat/properties/count',
  ),
  'preview.repeat.var': HuiFieldDoc(
    title: 'Var',
    body:
        'Name the 0-based index is bound to inside this element. Default '
        '\'i\'. Must be a valid identifier and must not collide with \'vars\' '
        'or a state variable name, which would make it unreachable.',
    citation: 'gloss-preview.schema.json#/\$defs/repeat/properties/var',
  ),
  'preview.variant.blocks': HuiFieldDoc(
    title: 'Blocks',
    body:
        'Material or entity type names, uppercased before matching. \'*\' '
        'is the only wildcard, e.g. \'*_SHULKER_BOX\'. Names listed here '
        'and in any variant both count toward resolving the document. An '
        'exact name beats a glob at the same priority. An unknown name '
        'warns and still compiles, so a document survives a version that '
        'dropped the type.',
    citation: 'gloss-preview.schema.json#/\$defs/variant/properties/blocks',
  ),
  'preview.variant.entities': HuiFieldDoc(
    title: 'Entities',
    body:
        'Material or entity type names, uppercased before matching. \'*\' '
        'is the only wildcard, e.g. \'*_SHULKER_BOX\'. Names listed here '
        'and in any variant both count toward resolving the document. An '
        'exact name beats a glob at the same priority. An unknown name '
        'warns and still compiles, so a document survives a version that '
        'dropped the type.',
    citation: 'gloss-preview.schema.json#/\$defs/variant/properties/entities',
  ),
  'preview.variant.vars': HuiFieldDoc(
    title: 'Vars',
    body:
        'Document-authored constants, read in expressions as vars.<name>. '
        'Values are JSON primitives only and are NEVER parsed as '
        'expressions, with one exception: a string leading with \'#\' is '
        'read as a colour literal so a variant can carry an accent as '
        '"#FFB02E26" without losing the alpha byte to a signed int. A '
        'leading \'#\' that is not a valid colour literal fails to compile.',
    citation: 'gloss-preview.schema.json#/\$defs/variant/properties/vars',
  ),
  'preview.variants': HuiFieldDoc(
    title: 'Variants',
    body:
        'Alternate variable sets for the same elements. A variant both '
        'restyles AND extends matching: the registry grades a target '
        'against the base match and every variant, so a material or '
        'entity named only in a variant makes the whole document '
        'resolvable for it. Variants are tried in declaration order; the '
        'first whose blocks/entities match wins, and its vars are merged '
        'over the document\'s own.',
    citation: 'gloss-preview.schema.json#/properties/variants',
  ),
  'preview.vars': HuiFieldDoc(
    title: 'Variables',
    body:
        'Document-authored constants, read in expressions as vars.<name>. '
        'Values are JSON primitives only and are NEVER parsed as '
        'expressions, with one exception: a string leading with \'#\' is '
        'read as a colour literal so a variant can carry an accent as '
        '"#FFB02E26" without losing the alpha byte to a signed int. A '
        'leading \'#\' that is not a valid colour literal fails to compile.',
    citation: 'gloss-preview.schema.json#/\$defs/vars',
  ),
  'realDrops.audience': HuiFieldDoc(
    title: 'Audience',
    body:
        'The per-viewer condition controlling who receives the shared '
        'real-drop models and label. A viewer who does not match receives '
        'the vanilla item instead.',
    citation: 'gloss-real-drops.schema.json#/properties/audience',
  ),
  'realDrops.axis': HuiFieldDoc(
    title: 'Axis',
    body:
        'Three expressions, one per axis. Any axis you leave out or leave '
        'blank falls back to the block\'s neutral value (0 for offset and '
        'rotation, 1 for scale).',
    citation: 'gloss-real-drops.schema.json#/\$defs/axis',
  ),
  'realDrops.axis.x': HuiFieldDoc(
    title: 'X',
    body: 'Expression for the X axis. X is east in world space.',
    citation: 'gloss-real-drops.schema.json#/\$defs/axis/properties/x',
  ),
  'realDrops.axis.y': HuiFieldDoc(
    title: 'Y',
    body: 'Expression for the Y axis. Y is up.',
    citation: 'gloss-real-drops.schema.json#/\$defs/axis/properties/y',
  ),
  'realDrops.axis.z': HuiFieldDoc(
    title: 'Z',
    body: 'Expression for the Z axis. Z is south in world space.',
    citation: 'gloss-real-drops.schema.json#/\$defs/axis/properties/z',
  ),
  'realDrops.expression': HuiFieldDoc(
    title: 'Expression',
    body:
        'A string in the Gloss expression language, compiled once when '
        'the document loads. Expressions without index are evaluated once '
        'per stack, and static settled plans are reused until an input '
        'changes. A parse error names the field and character position '
        'and refuses the document; a runtime failure logs once and falls '
        'back to the neutral field value. Variables include t, age, '
        'index, count, amount, onGround, settled, phase, stateTime, '
        'impactSpeed, inWater, inLava, bounces, velocityX, velocityY, '
        'velocityZ, speed, shape-aware height, blockLight, skyLight, '
        'random, material, isBlock, isFlat, isThin and pi. Drop-specific '
        'functions are materialIs(name) and materialMatches(glob); the '
        'expression grammar and complete standard-library reference are '
        'documented in DROP_SCRIPT_FORMAT.md.',
    citation: 'gloss-real-drops.schema.json#/\$defs/expression',
  ),
  'realDrops.filters.disabledWorlds': HuiFieldDoc(
    title: 'Disabled worlds',
    body:
        'World names, matched case-insensitively, where drops keep their '
        'vanilla appearance. Empty means every world is presented.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/filters/properties/disabledWorlds',
  ),
  'realDrops.filters.materialBlacklist': HuiFieldDoc(
    title: 'Material blacklist',
    body:
        'Material names, upper case, that are never presented. Defaults '
        'to BEDROCK and BARRIER. Setting this key to an empty array '
        'really does clear it; omitting the key restores the two '
        'defaults.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/filters/properties/materialBlacklist',
  ),
  'realDrops.filters.onlyPlayerDrops': HuiFieldDoc(
    title: 'Only player drops',
    body:
        'When true, only items a player threw or dropped are presented; '
        'mob loot, block breaks and dispensers keep their vanilla look. '
        'Default false.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/filters/properties/onlyPlayerDrops',
  ),
  'realDrops.labels.background': HuiFieldDoc(
    title: 'Background',
    body:
        'Whether the label draws its coloured background plate. When '
        'false the plate is fully transparent and the four background '
        'channels are ignored. Default true.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/labels/properties/background',
  ),
  'realDrops.labels.backgroundAlpha': HuiFieldDoc(
    title: 'Background alpha',
    body:
        'Opacity of the label background plate, 0-255. Default 80. '
        'Accepted range: 0 through 255.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/labels/properties/backgroundAlpha',
  ),
  'realDrops.labels.backgroundBlue': HuiFieldDoc(
    title: 'Background blue',
    body:
        'Blue channel of the label background plate, 0-255. Default 0. '
        'Accepted range: 0 through 255.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/labels/properties/backgroundBlue',
  ),
  'realDrops.labels.backgroundGreen': HuiFieldDoc(
    title: 'Background green',
    body:
        'Green channel of the label background plate, 0-255. Default 0. '
        'Accepted range: 0 through 255.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/labels/properties/backgroundGreen',
  ),
  'realDrops.labels.backgroundRed': HuiFieldDoc(
    title: 'Background red',
    body:
        'Red channel of the label background plate, 0-255. Default 0. '
        'Accepted range: 0 through 255.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/labels/properties/backgroundRed',
  ),
  'realDrops.labels.billboard': HuiFieldDoc(
    title: 'Billboard',
    body:
        'How the label turns to face the viewer. CENTER always faces the '
        'camera, HORIZONTAL and VERTICAL pivot on one axis only, FIXED '
        'never turns. Default CENTER. Accepted values: CENTER, FIXED, '
        'HORIZONTAL, VERTICAL.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/labels/properties/billboard',
  ),
  'realDrops.labels.enabled': HuiFieldDoc(
    title: 'Enabled',
    body:
        'Whether the floating name is drawn. When off, the item\'s own '
        'custom name visibility is restored. Default true.',
    citation: 'gloss-real-drops.schema.json#/\$defs/labels/properties/enabled',
  ),
  'realDrops.labels.scale': HuiFieldDoc(
    title: 'Scale',
    body:
        'Text size of the label. Clamped to 0.1-4, default 0.85. Accepted '
        'range: 0.1 through 4.',
    citation: 'gloss-real-drops.schema.json#/\$defs/labels/properties/scale',
  ),
  'realDrops.labels.seeThrough': HuiFieldDoc(
    title: 'See through',
    body: 'Whether the label is visible through blocks. Default true.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/labels/properties/seeThrough',
  ),
  'realDrops.labels.shadow': HuiFieldDoc(
    title: 'Shadow',
    body:
        'Whether the label text is drawn with a drop shadow. Default '
        'true.',
    citation: 'gloss-real-drops.schema.json#/\$defs/labels/properties/shadow',
  ),
  'realDrops.labels.viewRange': HuiFieldDoc(
    title: 'View range',
    body:
        'Distance in blocks at which the label stops rendering. Clamped '
        'to 4-128, default 32. Accepted range: 4 through 128.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/labels/properties/viewRange',
  ),
  'realDrops.labels.yOffset': HuiFieldDoc(
    title: 'Y offset',
    body:
        'Height of the label above the item, in blocks. Clamped to 0-4, '
        'default 0.55. Accepted range: 0 through 4.',
    citation: 'gloss-real-drops.schema.json#/\$defs/labels/properties/yOffset',
  ),
  'realDrops.landing.alignmentDegrees': HuiFieldDoc(
    title: 'Alignment degrees',
    body:
        'Subvisual tolerance for the final exact face alignment. Clamped '
        'to 0.05-10 degrees, default 0.5. Accepted range: 0.05 through '
        '10.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/landing/properties/alignmentDegrees',
  ),
  'realDrops.landing.faceAttraction': HuiFieldDoc(
    title: 'Face attraction',
    body:
        'Fraction of remaining face-alignment angle removed per sample '
        'when nearly still. Clamped to 0-1, default 0.55. Accepted range: '
        '0 through 1.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/landing/properties/faceAttraction',
  ),
  'realDrops.landing.mode': HuiFieldDoc(
    title: 'Mode',
    body:
        'The resting pose. NATURAL rolls block items onto whichever face '
        'is nearest the ground and gives everything else a small random '
        'tilt; FLAT lays every item face-up; UPRIGHT stands every item on '
        'end. Default NATURAL. Accepted values: NATURAL, FLAT, UPRIGHT.',
    citation: 'gloss-real-drops.schema.json#/\$defs/landing/properties/mode',
  ),
  'realDrops.landing.movingFaceAttraction': HuiFieldDoc(
    title: 'Moving face attraction',
    body:
        'Face attraction retained while rolling or sliding. Clamped to '
        '0-1, default 0.15. Accepted range: 0 through 1.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/landing/properties/movingFaceAttraction',
  ),
  'realDrops.landing.randomYaw': HuiFieldDoc(
    title: 'Random yaw',
    body:
        'Whether each item gets its own resting yaw, so a pile of the '
        'same drop does not look cloned. Default true.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/landing/properties/randomYaw',
  ),
  'realDrops.landing.settleDelayTicks': HuiFieldDoc(
    title: 'Settle delay ticks',
    body:
        'Ticks an aligned, motionless item remains stable before sparse '
        'settled polling. Clamped to 0-100, default 4. Accepted range: 0 '
        'through 100.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/landing/properties/settleDelayTicks',
  ),
  'realDrops.landing.tiltDegrees': HuiFieldDoc(
    title: 'Tilt degrees',
    body:
        'Maximum random lean, in degrees, applied to a resting item in '
        'NATURAL mode. 0 makes every landing perfectly square. Clamped to '
        '0-45, default 10. Accepted range: 0 through 45.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/landing/properties/tiltDegrees',
  ),
  'realDrops.landing.transitionTicks': HuiFieldDoc(
    title: 'Transition ticks',
    body:
        'Client interpolation length for continuous pose samples. Clamped '
        'to 0-20, default 4. Accepted range: 0 through 20.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/landing/properties/transitionTicks',
  ),
  'realDrops.limits.maxVisualsPerChunk': HuiFieldDoc(
    title: 'Max visuals per chunk',
    body:
        'Total display entities Gloss will spawn for drops in a single '
        'chunk, labels included. Once the budget is exhausted further '
        'drops in that chunk keep their vanilla look until room frees up. '
        'Clamped to 8-1024, default 128. Accepted range: 8 through 1024.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/limits/properties/maxVisualsPerChunk',
  ),
  'realDrops.limits.maxVisualsPerStack': HuiFieldDoc(
    title: 'Max visuals per stack',
    body:
        'Upper bound on the number of display models drawn for one '
        'dropped stack. Larger stacks earn more models up to this cap: 1 '
        'model below 2 items, 2 up to 16, 3 up to 32, 4 up to 48, then '
        'the cap. Clamped to 1-5, default 3. Accepted range: 1 through 5.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/limits/properties/maxVisualsPerStack',
  ),
  'realDrops.limits.settledPollIntervalTicks': HuiFieldDoc(
    title: 'Settled poll interval ticks',
    body:
        'Ticks between updates once an item has come to rest. A settled '
        'item is not re-posed, so this can be much slower than the moving '
        'interval. Clamped to 2-200, default 20. The physics block forces '
        'the faster moving interval while an item is in water, since a '
        'buoyant item is never really at rest. Accepted range: 2 through '
        '200.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/limits/properties/settledPollIntervalTicks',
  ),
  'realDrops.limits.spread': HuiFieldDoc(
    title: 'Spread',
    body:
        'How far the extra models of a multi-model stack sit from the '
        'first one, as a fraction of the authored offsets. 0 stacks them '
        'all in one place. Clamped to 0-1, default 0.18. Accepted range: '
        '0 through 1.',
    citation: 'gloss-real-drops.schema.json#/\$defs/limits/properties/spread',
  ),
  'realDrops.limits.updateIntervalTicks': HuiFieldDoc(
    title: 'Update interval ticks',
    body:
        'Ticks between presentation updates while an item is moving. '
        'Lower is smoother and more expensive. Clamped to 1-20, default '
        '2. Accepted range: 1 through 20.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/limits/properties/updateIntervalTicks',
  ),
  'realDrops.limits.viewRange': HuiFieldDoc(
    title: 'View range',
    body:
        'Distance in blocks at which the item models stop rendering for a '
        'client. Clamped to 4-128, default 32. A script whose visible '
        'expression is false hides a display by driving its view range to '
        'zero. Accepted range: 4 through 128.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/limits/properties/viewRange',
  ),
  'realDrops.motion.changeOnBounce': HuiFieldDoc(
    title: 'Change on bounce',
    body:
        'Whether an item re-rolls its tumble rates each time it bounces. '
        'Default true. The bounces script variable counts those bounces '
        'whether or not this is on.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/motion/properties/changeOnBounce',
  ),
  'realDrops.motion.degreesPerSecondX': HuiFieldDoc(
    title: 'Degrees per second X',
    body:
        'Base pitch tumble rate in degrees per second, before variance '
        'and the speed multiplier. Clamped to -1440 to 1440, default 160. '
        'Accepted range: -1440 through 1440.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/motion/properties/degreesPerSecondX',
  ),
  'realDrops.motion.degreesPerSecondY': HuiFieldDoc(
    title: 'Degrees per second Y',
    body:
        'Base yaw tumble rate in degrees per second. Clamped to -1440 to '
        '1440, default 120. Accepted range: -1440 through 1440.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/motion/properties/degreesPerSecondY',
  ),
  'realDrops.motion.degreesPerSecondZ': HuiFieldDoc(
    title: 'Degrees per second Z',
    body:
        'Base roll tumble rate in degrees per second. Clamped to -1440 to '
        '1440, default 100. Accepted range: -1440 through 1440.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/motion/properties/degreesPerSecondZ',
  ),
  'realDrops.motion.groundRollMultiplier': HuiFieldDoc(
    title: 'Ground roll multiplier',
    body:
        'Scales rotation generated from actual supported travel. 0 '
        'slides; 1 rolls at the natural model radius. Clamped to 0-4, '
        'default 1. Accepted range: 0 through 4.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/motion/properties/groundRollMultiplier',
  ),
  'realDrops.motion.speedMultiplier': HuiFieldDoc(
    title: 'Speed multiplier',
    body:
        'Multiplies all three tumble rates at once. Clamped to 0.1-4, '
        'default 1.35. Accepted range: 0.1 through 4.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/motion/properties/speedMultiplier',
  ),
  'realDrops.motion.submergedSpinMultiplier': HuiFieldDoc(
    title: 'Submerged spin multiplier',
    body:
        'Multiplier applied to angular motion while submerged. Clamped to '
        '0-1, default 0.35. Accepted range: 0 through 1.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/motion/properties/submergedSpinMultiplier',
  ),
  'realDrops.motion.tumble': HuiFieldDoc(
    title: 'Tumble',
    body:
        'Whether an airborne item spins. Turn this off for items that '
        'should fall flat and still. Default true.',
    citation: 'gloss-real-drops.schema.json#/\$defs/motion/properties/tumble',
  ),
  'realDrops.motion.variance': HuiFieldDoc(
    title: 'Variance',
    body:
        'How much the per-item tumble rate is allowed to wander from the '
        'configured base, as a fraction. 0 makes every item spin '
        'identically; the direction of each axis is still chosen per '
        'item. Clamped to 0-1, default 0.2. Accepted range: 0 through 1.',
    citation: 'gloss-real-drops.schema.json#/\$defs/motion/properties/variance',
  ),
  'realDrops.motion.velocityInfluence': HuiFieldDoc(
    title: 'Velocity influence',
    body:
        'How strongly real linear speed increases airborne angular speed. '
        'Clamped to 0-4, default 0.35. Accepted range: 0 through 4.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/motion/properties/velocityInfluence',
  ),
  'realDrops.physics.bounce': HuiFieldDoc(
    title: 'Bounce',
    body:
        'Restitution applied when an item lands. Vanilla items do not '
        'bounce at all; Gloss detects the landing and rewrites the '
        'vertical velocity to the given fraction of the approach speed, '
        'so the item really leaves the ground again. Each bounce '
        'increments the bounces script variable and, when '
        'motion.changeOnBounce is on, re-rolls the tumble. Very small '
        'landings below a fixed threshold are ignored so a resting item '
        'does not jitter. Clamped to 0-0.9, default 0 (off). Accepted '
        'range: 0 through 0.9.',
    citation: 'gloss-real-drops.schema.json#/\$defs/physics/properties/bounce',
  ),
  'realDrops.physics.enabled': HuiFieldDoc(
    title: 'Enabled',
    body:
        'Master switch for the physics layer. Default false, and while it '
        'is false Gloss never touches the item entity\'s velocity or '
        'gravity flag, so drops fall exactly as vanilla does.',
    citation: 'gloss-real-drops.schema.json#/\$defs/physics/properties/enabled',
  ),
  'realDrops.physics.gravityMultiplier': HuiFieldDoc(
    title: 'Gravity multiplier',
    body:
        'Scales how hard a dropped item falls. This is a real change to '
        'the entity: at 1 nothing is touched, above 1 Gloss adds extra '
        'downward velocity each update, below 1 it adds upward velocity '
        'to cancel part of the fall, and exactly 0 clears the entity\'s '
        'gravity flag so the item hangs where it is. Because the '
        'correction is applied per update rather than per tick, the '
        'effective acceleration is approximate at slow update intervals. '
        'Clamped to 0-4, default 1. Accepted range: 0 through 4.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/physics/properties/gravityMultiplier',
  ),
  'realDrops.physics.waterBuoyancy': HuiFieldDoc(
    title: 'Water buoyancy',
    body:
        'Upward velocity added each update while the item is in water, on '
        'top of whatever vanilla already does. This is real movement: a '
        'buoyant item rises and can be picked up higher in the column. '
        'Clamped to 0-1, default 0 (off). Accepted range: 0 through 1.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/physics/properties/waterBuoyancy',
  ),
  'realDrops.physics.waterDrag': HuiFieldDoc(
    title: 'Water drag',
    body:
        'Fraction of the item\'s velocity removed each update while it is '
        'in water, applied to all three axes. 0 leaves vanilla water '
        'motion alone, 1 stops the item dead the moment it is submerged. '
        'Clamped to 0-1, default 0 (off). Accepted range: 0 through 1.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/physics/properties/waterDrag',
  ),
  'realDrops.presentation': HuiFieldDoc(
    title: 'Presentation',
    body:
        'The complete fallback presentation used when no conditional '
        'variant matches.',
    citation: 'gloss-real-drops.schema.json#/properties/presentation',
  ),
  'realDrops.revision': HuiFieldDoc(
    title: 'Revision',
    body:
        'Server-owned monotonic revision counter. Starts at 1 and '
        'increases every time the server rewrites the document; editors '
        'must send back the revision they read so a concurrent change is '
        'detected instead of silently overwritten. Accepted range: 1 '
        'through 9007199254740991.',
    citation: 'gloss-real-drops.schema.json#/properties/revision',
  ),
  'realDrops.scale.defaultScale': HuiFieldDoc(
    title: 'Default scale',
    body:
        'Display size for full block items such as STONE. Clamped to '
        '0.05-2, default 0.4. Accepted range: 0.05 through 2.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/scale/properties/defaultScale',
  ),
  'realDrops.scale.flatItems': HuiFieldDoc(
    title: 'Flat items',
    body:
        'Display size for non-block items rendered through ItemDisplay. '
        'Placeable materials use BlockDisplay even when their inventory '
        'icon is flat. Clamped to 0.05-2, default 0.65. Accepted range: '
        '0.05 through 2.',
    citation: 'gloss-real-drops.schema.json#/\$defs/scale/properties/flatItems',
  ),
  'realDrops.scale.thinBlocks': HuiFieldDoc(
    title: 'Thin blocks',
    body:
        'Display size for slabs, carpets, pressure plates and snow. '
        'Clamped to 0.05-2, default 0.45. Accepted range: 0.05 through 2.',
    citation:
        'gloss-real-drops.schema.json#/\$defs/scale/properties/thinBlocks',
  ),
  'realDrops.schemaVersion': HuiFieldDoc(
    title: 'Schema version',
    body: 'Document format version. Must be exactly 2.',
    citation: 'gloss-real-drops.schema.json#/properties/schemaVersion',
  ),
  'realDrops.script.enabled': HuiFieldDoc(
    title: 'Enabled',
    body:
        'Master switch for the script layer. Default false. While it is '
        'false every expression here is still parsed and validated when '
        'the document loads, so a broken expression is reported '
        'immediately, but nothing is evaluated at runtime and the '
        'presentation is bit-for-bit what it was before the script block '
        'existed.',
    citation: 'gloss-real-drops.schema.json#/\$defs/script/properties/enabled',
  ),
  'realDrops.script.glow': HuiFieldDoc(
    title: 'Glow',
    body:
        'Colour of the display\'s glowing outline. An empty string turns '
        'the whole feature off and is the default. Otherwise it is an '
        'expression producing either a colour number (a #RRGGBB or '
        '#AARRGGBB literal, or rgb()/argb()/mix()/palette()) or a #RRGGBB '
        'string; a result of exactly 0 means no glow, which is how a '
        'conditional glow is written - for example "materialIs(\'torch\') ? '
        '#FFAA55 : 0". Only the red, green and blue channels reach the '
        'client; the outline itself is drawn by the client, so it is '
        'visible through blocks.',
    citation: 'gloss-real-drops.schema.json#/\$defs/script/properties/glow',
  ),
  'realDrops.script.offset': HuiFieldDoc(
    title: 'Offset',
    body:
        'Extra displacement of the display, in blocks, added to the '
        'offset the document already computed for this model. Positive Y '
        'lifts the model. This moves the picture only: the item entity '
        'and its pickup radius do not follow, so a large offset visually '
        'detaches the model from the thing a player walks over. Each axis '
        'is clamped to -16..16 blocks. Defaults to 0 on every axis.',
    citation: 'gloss-real-drops.schema.json#/\$defs/script/properties/offset',
  ),
  'realDrops.script.rotation': HuiFieldDoc(
    title: 'Rotation',
    body:
        'Extra rotation in degrees, composed onto the pose the tumble and '
        'landing blocks produced rather than replacing it, and applied in '
        'X then Y then Z order. The resting height correction is '
        'recomputed from the final pose, so a scripted rotation of a '
        'block item will not sink it into the floor. Each axis is clamped '
        'to -3600..3600 degrees. Defaults to 0 on every axis.',
    citation: 'gloss-real-drops.schema.json#/\$defs/script/properties/rotation',
  ),
  'realDrops.script.scale': HuiFieldDoc(
    title: 'Scale',
    body:
        'Multiplier applied to whichever scale family this item resolved '
        'to, per axis, so 1 leaves the configured size alone and 2 '
        'doubles it. Non-uniform values squash and stretch the model. '
        'Each axis is clamped to 0..16; 0 collapses the model to nothing, '
        'which is a blunter way of hiding it than the visible expression. '
        'Defaults to 1 on every axis.',
    citation: 'gloss-real-drops.schema.json#/\$defs/script/properties/scale',
  ),
  'realDrops.script.vars': HuiFieldDoc(
    title: 'Vars',
    body:
        'Author-defined intermediate values, written as a name to '
        'expression map. They are evaluated first, in the order they '
        'appear in the file, and each one is visible to every expression '
        'declared after it as well as to offset, rotation, scale, glow '
        'and visible. This is what makes non-trivial logic writable: give '
        'the condition a name once, then reuse it. Each value must '
        'evaluate to a number, so encode a flag as 1 and 0 and test it '
        'with a comparison. A name must be a plain identifier, must not '
        'repeat, and must not shadow a built-in variable. At most 32 '
        'entries.',
    citation: 'gloss-real-drops.schema.json#/\$defs/script/properties/vars',
  ),
  'realDrops.script.visible': HuiFieldDoc(
    title: 'Visible',
    body:
        'Boolean expression gating whether this display is drawn at all. '
        'Must evaluate to true or false, not a number. A false result '
        'drives the display\'s view range to zero, which stops clients '
        'rendering it; the item entity is untouched and remains '
        'pickupable. Defaults to "true".',
    citation: 'gloss-real-drops.schema.json#/\$defs/script/properties/visible',
  ),
  'realDrops.variants': HuiFieldDoc(
    title: 'Variants',
    body:
        'Complete conditional presentations. Gloss chooses the matching '
        'entry with the highest priority, then the lexicographically '
        'smallest id when priorities tie.',
    citation: 'gloss-real-drops.schema.json#/properties/variants',
  ),
  'toggle.condition': HuiFieldDoc(
    title: 'Condition',
    body:
        'Defines what placeholder value is used to determine the toggles '
        'initial state.',
    citation: 'gloss.schema.json#/\$defs/toggleComponent/properties/condition',
  ),
  'toggle.expectedValue': HuiFieldDoc(
    title: 'Expected value',
    body:
        'Defines what the condition is checked against to determine the '
        'toggles initial state.',
    citation:
        'gloss.schema.json#/\$defs/toggleComponent/properties/expectedValue',
  ),
  'toggle.falseActions': HuiFieldDoc(
    title: 'False actions',
    body:
        'Defines what happens upon a interaction that enters the false '
        'state, so upon a interaction while the toggle is true.',
    citation:
        'gloss.schema.json#/\$defs/toggleComponent/properties/falseActions',
  ),
  'toggle.falseIcon': HuiFieldDoc(
    title: 'False icon',
    body:
        'Defines the visual part of the component while the toggle is in '
        'the false state.',
    citation: 'gloss.schema.json#/\$defs/toggleComponent/properties/falseIcon',
  ),
  'toggle.highlightModifier': HuiFieldDoc(
    title: 'Highlight modifier',
    body: 'Menu-local travel toward the viewer at uiScale 1.',
    citation:
        'gloss.schema.json#/\$defs/toggleComponent/properties/highlightModifier',
  ),
  'toggle.hitbox': HuiFieldDoc(
    title: 'Hitbox',
    body: 'Optional stable click plane shared by both toggle icon states.',
    citation: 'gloss.schema.json#/\$defs/toggleComponent/properties/hitbox',
  ),
  'toggle.hoverDurationTicks': HuiFieldDoc(
    title: 'Hover duration ticks',
    body:
        'Ticks used to enter and leave the hovered pose. Defaults to 4; '
        'zero is instant. Accepted range: 0 through 40.',
    citation:
        'gloss.schema.json#/\$defs/toggleComponent/properties/hoverDurationTicks',
  ),
  'toggle.hoverEasing': HuiFieldDoc(
    title: 'Hover easing',
    body:
        'Easing curve used for hover entry and exit. Defaults to '
        'ease_out_cubic. Accepted values: linear, ease_out_cubic, '
        'ease_in_out_cubic, back_out.',
    citation:
        'gloss.schema.json#/\$defs/toggleComponent/properties/hoverEasing',
  ),
  'toggle.trueActions': HuiFieldDoc(
    title: 'True actions',
    body:
        'Defines what happens upon a interaction that enters the true '
        'state, so upon a interaction while the toggle is false.',
    citation:
        'gloss.schema.json#/\$defs/toggleComponent/properties/trueActions',
  ),
  'toggle.trueIcon': HuiFieldDoc(
    title: 'True icon',
    body:
        'Defines the visual part of the component while the toggle is in '
        'the true state.',
    citation: 'gloss.schema.json#/\$defs/toggleComponent/properties/trueIcon',
  ),
};

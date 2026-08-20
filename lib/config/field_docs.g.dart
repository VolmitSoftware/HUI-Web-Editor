// GENERATED FILE - DO NOT HAND-EDIT.
//
// Regenerate with `dart run tool/extract_field_docs.dart`.
// Source: gloss.schema.json, gloss-preview.schema.json in the Gloss plugin repo.

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
    body: 'Defines the command run by this action.',
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
        'Defines the amount of ticks between frame advances. Values of 1 '
        'or less advance every tick.',
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
    body: 'Accepted range: 1 through 16384. Omitted, this is 2000.',
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
        'animatedTextImage, item, block, customItem, entity.',
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
        'are re-evaluated while the preview is on screen (every four '
        'ticks); every other expression field is evaluated once when the '
        'preview is built. Grammar: number, string (single- or '
        'double-quoted, escapes \\\\ \\\' \\" \\n), colour (#RGB, #RRGGBB, '
        '#AARRGGBB), true/false, variable (dotted, e.g. surge.active or '
        'vars.accent), array literal ([a, b, c], used by palette), call, '
        'unary ! and -, * / %, + -, < <= > >=, == !=, &&, ||, and a ? b : '
        'c. Strings concatenate with +. % is Java\'s truncating remainder '
        '(-1 % 3 is -1) while mod() floors (mod(-1, 3) is 2); both throw '
        'on a zero divisor. Functions: clamp, lerp, min, max, floor, '
        'ceil, round, abs, mod, sin, cos, rgb, argb, alpha, mix, palette, '
        'str, fixed, plain, readable, lang, count, occupied, item. See '
        'the Gloss docs pages /gloss/13-expressions-placeholders and '
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
    body: 'Entity types this document draws.',
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
        'entity no document names. Read from the top-level match only. '
        'Accepted values: enderChest, locked, anyInventoryHolder.',
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

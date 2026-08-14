/// Per-field documentation for the inspector's help popovers.
///
/// This is where the editor teaches the runtime rather than the schema. Every
/// body is a fact read out of the HoloUi source, and the ones worth the screen
/// space are the traps: the keys older files spell wrong, the values that mean
/// silence, and the fields whose value the plugin overwrites a tick later. The
/// citation is the line that proves it, so a future reader can check the claim
/// instead of trusting it.
///
/// Keys are the contract the inspector looks docs up by; see
/// `test/field_docs_test.dart` for the list it must cover.
library;

class HuiFieldDoc {
  const HuiFieldDoc({required this.title, required this.body, this.citation});

  /// Short field name, in the editor's words rather than the JSON key's.
  final String title;

  /// The explanation. One paragraph, no markup.
  final String body;

  /// `File.java:12` or `File.java:12-34` — the source that proves the body.
  final String? citation;
}

/// Doc for [key], or null when the field has none. Unknown keys are not an
/// error: the help affordance simply does not render.
HuiFieldDoc? huiFieldDoc(String key) => huiFieldDocs[key];

const Map<String, HuiFieldDoc> huiFieldDocs = <String, HuiFieldDoc>{
  // --- menu root ------------------------------------------------------------
  'menu.offset': HuiFieldDoc(
    title: 'Menu offset',
    body:
        'For a personal menu, this is measured in blocks from the player\'s '
        'feet when it opens, so y 1.7 is roughly eye level. On a persistent '
        'world board it is local to the board anchor and rotates with the '
        'board. X is negated in both paths. Neither uiScale nor board scale '
        'changes this root offset; they scale component spacing instead.',
    citation: 'BoardPlacement.java:42-57',
  ),
  'menu.id': HuiFieldDoc(
    title: 'Menu id',
    body:
        'Comes from the JSON path relative to menus/, without the extension; '
        'subfolders become slash-separated id segments. The plugin overwrites '
        'any id carried in JSON after parsing, and there is no name key. '
        'Renaming the file or a parent '
        'folder changes the /holoui open argument, navigation targets and the '
        'holoui.open.<id> permission node.',
    citation: 'ConfigManager.java:267-301',
  ),
  'menu.lockPosition': HuiFieldDoc(
    title: 'Lock position',
    body:
        'Personal-menu behavior only. It rewrites every movement back to the '
        'open position and zeroes velocity while the menu is open. Persistent '
        'world boards ignore this key and use their own transform, follow and '
        'visibility settings.',
    citation: 'MenuSessionManager.java:115-127',
  ),
  'menu.followPlayer': HuiFieldDoc(
    title: 'Follow player',
    body:
        'Personal-menu behavior only. It re-centres the menu on the player and '
        'updates its facing yaw on movement, look, respawn and teleport. A '
        'persistent world board ignores this key and uses its separate player '
        'follow target, mode and relative transform.',
    citation: 'MenuSessionManager.java:129-131',
  ),
  'menu.maxDistance': HuiFieldDoc(
    title: 'Max distance',
    body:
        'Personal-menu behavior only. It closes the session once the player '
        'moves too far from the menu centre; the value is clamped to 0 through '
        '60000000 and changing world always closes it. Persistent boards '
        'ignore this key and use their own view and interaction ranges.',
    citation: 'MenuSession.java:147-151',
  ),
  'menu.closeOnDeath': HuiFieldDoc(
    title: 'Close on death',
    body:
        'Personal-menu behavior only. On closes at death. Off preserves the '
        'session through the death event, but respawn still closes it when the '
        'new location fails the world or max-distance check. Persistent boards '
        'ignore this key and reopen from board visibility after respawn.',
    citation: 'MenuSessionManager.java:121-140',
  ),
  'menu.closeOnTeleport': HuiFieldDoc(
    title: 'Close on teleport',
    body:
        'Personal-menu behavior only. On closes for any teleport. Even when '
        'off, a teleport to another world or beyond max distance closes the '
        'session. Persistent boards ignore this key and recalculate visibility '
        'from the destination.',
    citation: 'MenuSessionManager.java:151-159',
  ),

  // --- component wrapper ----------------------------------------------------
  'component.id': HuiFieldDoc(
    title: 'Component id',
    body:
        'How the Java API addresses this component. Duplicates are not '
        'rejected by the JSON parser, but the plugin keeps only the first '
        'component with an id. Later duplicates do not render, tick or click.',
    citation: 'MenuSession.java:76-91',
  ),
  'component.offset': HuiFieldDoc(
    title: 'Component offset',
    body:
        'Blocks from the menu centre. X is negated and all three axes are '
        'multiplied by uiScale; persistent boards also apply board scale and '
        'rotate the complete layout and click planes through board yaw, pitch '
        'and roll. Components have no independent Euler rotation field, while '
        'display-backed icon style still owns scale and text alignment.',
    citation: 'MenuTransform.java:98-135',
  ),

  // --- clickables -----------------------------------------------------------
  'button.highlightModifier': HuiFieldDoc(
    title: 'Highlight modifier',
    body:
        'How far the icon moves toward the player while the look ray remains '
        'inside its hitbox. The click plane centre stays fixed while hovered; '
        'its orientation still follows the icon billboard. On exit the icon '
        'teleports straight back; there is no easing. Values loaded from JSON '
        'are never clamped, only the Java API clamps them to 0 to 1.',
    citation: 'ClickableComponent.java:111-116',
  ),
  'button.hitbox': HuiFieldDoc(
    title: 'Button hitbox',
    body:
        'Width and height are optional, paired block dimensions at uiScale 1. '
        'Without them the plane follows the icon size. Offset moves the plane '
        'in right, up and forward axes. The button anchor keeps the plane '
        'linked to the icon; the menu anchor detaches it so each can move '
        'independently.',
    citation: 'ClickableComponent.java:123-160',
  ),
  'toggle.condition': HuiFieldDoc(
    title: 'Condition',
    body:
        'A PlaceholderAPI string, expanded once when the menu opens and '
        'compared case-insensitively against the expected value to pick the '
        'starting state. It is never re-evaluated - after that first sample the '
        'state only changes when a player clicks. A missing condition throws '
        'while the menu is opening, so this field cannot be left out.',
    citation: 'ToggleComponent.java:78-80',
  ),
  'toggle.expectedValue': HuiFieldDoc(
    title: 'Expected value',
    body:
        'What the expanded condition has to equal, ignoring case, for the '
        'toggle to open in its true state. Leaving it out does not crash: the '
        'comparison simply never matches, so the toggle always opens false.',
    citation: 'ToggleComponent.java:78-80',
  ),
  'toggle.trueActions': HuiFieldDoc(
    title: 'Actions on switch to true',
    body:
        'Run on the click that moves the toggle from false to true, before '
        'the icon swaps. Nothing runs at open, whatever the condition '
        'evaluated to - only clicks fire actions.',
    citation: 'ToggleComponent.java:52-62',
  ),
  'toggle.falseActions': HuiFieldDoc(
    title: 'Actions on switch to false',
    body:
        'Run on the click that moves the toggle from true to false. A player '
        'clicking twice runs the true list and then the false list; that round '
        'trip is the only way both lists fire.',
    citation: 'ToggleComponent.java:52-62',
  ),

  // --- icons ----------------------------------------------------------------
  'icon.item.item': HuiFieldDoc(
    title: 'Material',
    body:
        'A lowercase namespaced key such as diamond_sword or '
        'minecraft:diamond_sword. The uppercase enum spelling DIAMOND_SWORD '
        'does not resolve through the namespaced-key registry. HoloUI logs that '
        'icon failure and draws the missing-icon checkerboard instead.',
    citation: 'MenuIcon.java:64-83',
  ),
  'icon.item.count': HuiFieldDoc(
    title: 'Count',
    body:
        'Stack size on the floating item. 0 is coerced to 1, so there is no '
        'way to render an empty stack. Above 1 the plugin spawns a second '
        'display below the item showing a bold white count, which widens what '
        'the icon draws but not its hitbox.',
    citation: 'ItemMenuIcon.java:72-105',
  ),
  'icon.item.customModelValue': HuiFieldDoc(
    title: 'Custom model value',
    body:
        'The key is customModelValue. Files written against the old editor or '
        'the pre-3.0 schema call it customModelData, which the plugin does not '
        'read at all - importing one moves the value onto the key that works. '
        'It is written onto the item meta unconditionally, including 0, so '
        'leaving it at 0 still stamps custom model data 0 on the stack.',
    citation: 'ItemMenuIcon.java:72-77',
  ),
  'icon.customItem.provider': HuiFieldDoc(
    title: 'Provider',
    body:
        'Which custom-item plugin resolves the id. Blank or auto tries every '
        'installed provider in activation order and takes the first hit, '
        'which is fine while ids are unique and ambiguous the moment two '
        'plugins define the same one. Naming the provider is faster and leaves '
        'nothing to chance. Provider names are trimmed and case-insensitive.',
    citation: 'ItemProviderRegistry.java:113-130',
  ),
  'icon.customItem.item': HuiFieldDoc(
    title: 'Custom item id',
    body:
        'The provider\'s own id, passed through verbatim with its case '
        'intact - MMOItems wants SWORD:CUTLASS, Oraxen wants its yml key '
        'exactly as written. The editor cannot check it because resolution '
        'happens on the server; an id nothing recognises falls back to the '
        'missing-icon checkerboard rather than failing the menu.',
    citation: 'ItemProviderRegistry.java:125-144',
  ),
  'icon.customItem.count': HuiFieldDoc(
    title: 'Custom item count',
    body:
        'Stack size applied after the provider returns the item. Values below 1 '
        'become 1. Values above 1 add the same count label used by vanilla item '
        'icons; keep the value within the client stack limit.',
    citation: 'ItemMenuIcon.java:90-105',
  ),
  'icon.textImage.path': HuiFieldDoc(
    title: 'Image path',
    body:
        'Relative to plugins/holoui/images/. The image is drawn one block '
        'character per pixel with a hex colour, so a 64 by 64 image becomes 64 '
        'text displays of 64 characters each; fully transparent pixels are left '
        'blank. A path that does not resolve renders the magenta and black '
        'checkerboard instead of failing the menu.',
    citation: 'TextImageMenuIcon.java:86-110',
  ),
  'icon.animated.source': HuiFieldDoc(
    title: 'Frames',
    body:
        'The key is source and it holds the list of frame paths. Files written '
        'against the pre-3.0 schema call it path, which the plugin does not '
        'read - importing one moves the frames onto the key that works. Frames '
        'are bottom-padded to the tallest one, so mixed sizes stay anchored at '
        'the top. An empty list is logged as an icon failure and replaced with '
        'the missing-icon checkerboard.',
    citation: 'MenuIcon.java:64-83',
  ),
  'icon.animated.speed': HuiFieldDoc(
    title: 'Speed',
    body:
        'Ticks between frames, not milliseconds. One tick is 50 ms, so 2 is '
        '100 ms a frame and 20 is one frame a second. Zero and negative values '
        'advance every tick, the same as 1. There is no per-frame duration, '
        'ping-pong or play-once: the list loops forever at this one interval.',
    citation: 'AnimatedTextImageMenuIcon.java:52-60',
  ),
  'icon.text.text': HuiFieldDoc(
    title: 'Text',
    body:
        'A newline splits it into one text display per line. Ampersand codes, '
        'legacy section codes and full MiniMessage tags all work, and '
        'PlaceholderAPI runs over it when the icon is created and then on its '
        'configured refresh interval. Note the hitbox is a character '
        'count, not a glyph measurement: a wide line grabs clicks well past '
        'where the text appears to end.',
    citation: 'TextUtils.java:37-43',
  ),
  'icon.text.refreshTicks': HuiFieldDoc(
    title: 'Placeholder refresh',
    body:
        'Ticks between live PlaceholderAPI expansions for text containing a '
        '%name% token. The omitted default is 10 ticks, or twice per second. '
        'Zero disables updates after the initial render; the accepted range '
        'is 0 through 1200. Static text does no periodic work.',
    citation: 'TextMenuIcon.java:69-81',
  ),
  'icon.entity.entity': HuiFieldDoc(
    title: 'Entity type',
    body:
        'A lowercase namespaced Bukkit entity id. HoloUI accepts only '
        'spawnable living types, renders them entirely through packets, and '
        'never inserts a real entity into the world. Invalid, player, item, '
        'projectile, display and interaction types fall back to the missing '
        'icon without preventing the rest of the menu from opening.',
    citation: 'EntityIconData.java:62-70',
  ),
  'icon.entity.width': HuiFieldDoc(
    title: 'Entity click width',
    body:
        'Width of the automatic click plane and editor silhouette in blocks '
        'at UI scale 1. It does not resize the client entity model. Omitted '
        'defaults to 1; values must be greater than 0 and at most 64.',
    citation: 'EntityIconData.java:54-60',
  ),
  'icon.entity.height': HuiFieldDoc(
    title: 'Entity click height',
    body:
        'Height of the automatic click plane and editor silhouette in blocks '
        'at UI scale 1. The component anchor is the entity\'s feet, so this '
        'plane is centered half its height above the anchor. Omitted defaults '
        'to 1; values must be greater than 0 and at most 64.',
    citation: 'EntityMenuIcon.java:71-79',
  ),
  'icon.block.block': HuiFieldDoc(
    title: 'Block material',
    body:
        'A lowercase namespaced Bukkit block material. HoloUI renders its '
        'default block state as a packet-only block display at 0.75 blocks '
        'square before UI and display-style scaling. Unknown ids and '
        'non-block materials fall back to the missing icon.',
    citation: 'BlockIconData.java:43-54',
  ),

  // --- actions --------------------------------------------------------------
  'action.command.command': HuiFieldDoc(
    title: 'Command',
    body:
        'The leading slash is optional - the plugin strips it. Commands are '
        'never placeholder-expanded, so %player_name% arrives at the command '
        'handler literally. A missing, blank or just-slash command is logged '
        'and dropped when the menu is compiled.',
    citation: 'CommandMenuAction.java:34-40',
  ),
  'action.command.source': HuiFieldDoc(
    title: 'Run as',
    body:
        'server dispatches from the console, with full privileges and no '
        'permission check against the player. player and an omitted key run as '
        'the clicking player. Gson also accepts the Java enum names GLOBAL and '
        'PLAYER; the editor converts those to server and player on import. Any '
        'other spelling uses the player default and is reported by validation.',
    citation: 'CommandMenuAction.java:34-40',
  ),
  'action.sound.sound': HuiFieldDoc(
    title: 'Sound',
    body:
        'A lowercase namespaced key such as ui.button.click; the uppercase '
        'enum spelling parses to null. It plays at the clicking player\'s own '
        'location and only to them - nobody standing nearby hears it.',
    citation: 'SoundMenuAction.java:28-41',
  ),
  'action.sound.source': HuiFieldDoc(
    title: 'Category',
    body:
        'Which client volume slider applies: master, music, record, weather, '
        'block, hostile, neutral, player, ambient or voice. It is optional - a '
        'missing or unrecognised category plays the sound on master rather '
        'than failing the click. Gson also accepts uppercase Java enum names '
        'such as MUSIC; the editor converts them to their lowercase spelling.',
    citation: 'SoundActionData.java:33-42',
  ),
  'action.sound.volume': HuiFieldDoc(
    title: 'Volume',
    body:
        'Omitted, this is 1, the sound as recorded. Writing 0 is silence, so a '
        'zero here is a mute the file asked for rather than a default. Above 1 '
        'Minecraft extends how far the sound carries rather than making it '
        'louder.',
    citation: 'SoundActionData.java:37-42',
  ),
  'action.sound.pitch': HuiFieldDoc(
    title: 'Pitch',
    body:
        'Playback speed, which the client clamps to 0.5 to 2.0. Omitted, this '
        'is 1, the sound as recorded. Writing 0 is clamped up to 0.5: the '
        'deepest, slowest version of the sound.',
    citation: 'SoundActionData.java:37-42',
  ),
  'action.message.message': HuiFieldDoc(
    title: 'Player message',
    body:
        'Parsed as MiniMessage and sent only to the player who clicked. The '
        'literal %player% becomes that player\'s name, then PlaceholderAPI '
        'expands any installed placeholders before MiniMessage parsing. A '
        'blank message is logged and dropped when the component is compiled.',
    citation: 'MessageMenuAction.java:30-43',
  ),
  'action.teleport.world': HuiFieldDoc(
    title: 'Destination world',
    body:
        'Must be an explicit lowercase namespace:key and must already be '
        'loaded when the player clicks. The runtime never creates or loads a '
        'world for an action; it schedules on the player entity and uses the '
        'asynchronous Paper teleport path so cross-region Folia moves remain '
        'safe.',
    citation: 'TeleportMenuAction.java:50-78',
  ),
  'action.connect.server': HuiFieldDoc(
    title: 'Proxy server',
    body:
        'The exact logical server name configured on a BungeeCord-compatible '
        'proxy. HoloUI sends only the fixed Connect subchannel for the clicking '
        'player; whitespace, control characters and arbitrary subchannels are '
        'rejected when the component is compiled.',
    citation: 'ConnectMenuAction.java:38-56',
  ),
};

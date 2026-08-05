/// Per-field documentation for the inspector's help popovers.
///
/// This is where the editor teaches the runtime rather than the schema. Every
/// body is a fact read out of the HoloUi source, and the ones worth the screen
/// space are the traps: the keys the shipped JSON schema spells wrong, the
/// defaults that mean silence, and the fields whose value the plugin overwrites
/// a tick later. The citation is the line that proves it, so a future reader can
/// check the claim instead of trusting it.
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
        'Measured in blocks from the player\'s feet at the moment the menu '
        'opens, not from their eyes, so y 1.7 is roughly eye level. X is '
        'negated on load, which is why positive X reads as the player\'s right '
        'here. This is the one offset uiScale never touches: raising the '
        'server\'s uiScale spreads the components further apart without moving '
        'the menu closer or further away.',
    citation: 'MenuSession.java:70-73',
  ),
  'menu.id': HuiFieldDoc(
    title: 'Menu id',
    body:
        'Comes from the file base name, and the plugin overwrites whatever id '
        'the JSON carries immediately after parsing. There is no name key in '
        'the format either - writing one is silently ignored. Renaming the file '
        'renames the menu, and with it the /holoui open argument and the '
        'holoui.open.<id> permission node a player needs to open it.',
    citation: 'ConfigManager.java:214',
  ),
  'menu.lockPosition': HuiFieldDoc(
    title: 'Lock position',
    body:
        'Rewrites every movement back to where the player stood and zeroes '
        'their velocity, for as long as the menu is open. They can still look '
        'around and click; they cannot walk. It also means follow player never '
        'gets anything to follow.',
    citation: 'MenuSessionManager.java:115-127',
  ),
  'menu.followPlayer': HuiFieldDoc(
    title: 'Follow player',
    body:
        'Re-centres the whole menu on the player on every move, respawn and '
        'teleport, keeping the facing it opened with. Off, the menu stays where '
        'it spawned and the player can walk away from it - until max distance '
        'closes it.',
    citation: 'MenuSessionManager.java:129-131',
  ),
  'menu.maxDistance': HuiFieldDoc(
    title: 'Max distance',
    body:
        'Closes the menu once the player gets further from the menu centre '
        'than this. Leaving the key out means 60000000 blocks, and any value is '
        'clamped into 0 to 60000000. The check is loosened by the menu offset - '
        'it compares against maxDistance squared plus the offset length squared '
        '- so a menu pushed well in front of the player survives a little '
        'further than the number reads. Changing world always closes it.',
    citation: 'MenuSession.java:147-151',
  ),
  'menu.closeOnDeath': HuiFieldDoc(
    title: 'Close on death',
    body:
        'Closes the menu when the player dies. Off, it stays open through the '
        'death screen and the respawn.',
    citation: 'MenuSessionManager.java:136-140',
  ),
  'menu.closeOnTeleport': HuiFieldDoc(
    title: 'Close on teleport',
    body:
        'Closes on any teleport - commands, portals, other plugins. The '
        'shipped JSON schema does not list this key but the plugin reads it. '
        'Even with it off, a teleport that leaves the menu\'s world closes the '
        'session anyway.',
    citation: 'MenuSessionManager.java:151-159',
  ),

  // --- component wrapper ----------------------------------------------------
  'component.id': HuiFieldDoc(
    title: 'Component id',
    body:
        'How the Java API addresses this component. Duplicates are not '
        'rejected: a second component with the same id still renders and still '
        'clicks, it just never enters the lookup map, so API calls only ever '
        'reach the first one.',
    citation: 'MenuSession.java:79',
  ),
  'component.offset': HuiFieldDoc(
    title: 'Component offset',
    body:
        'Blocks from the menu centre. X is negated on load, and all three '
        'axes are multiplied by the server\'s uiScale - so a server at uiScale '
        '2 spreads every component twice as far from the centre while the menu '
        'itself stays put. Yaw and pitch are forced to zero; components cannot '
        'be tilted.',
    citation: 'MenuComponent.java:53-54',
  ),

  // --- clickables -----------------------------------------------------------
  'button.highlightModifier': HuiFieldDoc(
    title: 'Highlight modifier',
    body:
        'How far the icon moves toward the player while the look ray remains '
        'inside its hitbox. The click plane itself stays fixed so the hover '
        'does not chase the player\'s crosshair. On exit the icon teleports '
        'straight back; there is no easing. Values loaded from JSON are never '
        'clamped, only the Java API clamps them to 0 to 1.',
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
        'parses to null and then crashes when the icon is built: the value goes '
        'through a namespaced-key registry lookup, not an enum valueOf.',
    citation: 'RegistryTypeAdapter.java:25-32',
  ),
  'icon.item.count': HuiFieldDoc(
    title: 'Count',
    body:
        'Stack size on the floating item. 0 is coerced to 1, so there is no '
        'way to render an empty stack. Above 1 the plugin spawns a second '
        'display below the item showing a bold white count, which widens what '
        'the icon draws but not its hitbox.',
    citation: 'ItemMenuIcon.java:60',
  ),
  'icon.item.customModelValue': HuiFieldDoc(
    title: 'Custom model value',
    body:
        'The key is customModelValue. The shipped JSON schema calls it '
        'customModelData, which the plugin does not read at all - a file using '
        'the schema spelling silently gets no custom model. It is written onto '
        'the item meta unconditionally, including 0, so leaving it at 0 still '
        'stamps custom model data 0 on the stack.',
    citation: 'ItemIconData.java:29',
  ),
  'icon.customItem.provider': HuiFieldDoc(
    title: 'Provider',
    body:
        'Which custom-item plugin resolves the id. Blank or auto tries every '
        'installed provider in registration order and takes the first hit, '
        'which is fine while ids are unique and ambiguous the moment two '
        'plugins define the same one. Naming the provider is faster and leaves '
        'nothing to chance.',
    citation: 'ItemProviderRegistry.java:48-59',
  ),
  'icon.customItem.item': HuiFieldDoc(
    title: 'Custom item id',
    body:
        'The provider\'s own id, passed through verbatim with its case '
        'intact - MMOItems wants SWORD:CUTLASS, Oraxen wants its yml key '
        'exactly as written. The editor cannot check it because resolution '
        'happens on the server; an id nothing recognises falls back to the '
        'missing-icon checkerboard rather than failing the menu.',
    citation: 'ItemProviderRegistry.java:48-59',
  ),
  'icon.textImage.path': HuiFieldDoc(
    title: 'Image path',
    body:
        'Relative to plugins/holoui/images/. The image is drawn one block '
        'character per pixel with a hex colour, so a 64 by 64 image becomes 64 '
        'text displays of 64 characters each; fully transparent pixels are left '
        'blank. A path that does not resolve renders the magenta and black '
        'checkerboard instead of failing the menu.',
    citation: 'TextImageMenuIcon.java:43-50',
  ),
  'icon.animated.source': HuiFieldDoc(
    title: 'Frames',
    body:
        'The key is source and it holds the list of frame paths. The shipped '
        'JSON schema calls it path, which the plugin does not read - a file '
        'using the schema spelling loads with no frames. Frames are '
        'bottom-padded to the tallest one, so mixed sizes stay anchored at the '
        'top, and an empty list crashes the menu open.',
    citation: 'AnimatedImageData.java:24',
  ),
  'icon.animated.speed': HuiFieldDoc(
    title: 'Speed',
    body:
        'Ticks between frames, not milliseconds. One tick is 50 ms, so 2 is '
        '100 ms a frame and 20 is one frame a second. There is no per-frame '
        'duration, no ping-pong and no play-once: the list loops forever at '
        'this one interval.',
    citation: 'AnimatedTextImageMenuIcon.java:52-60',
  ),
  'icon.text.text': HuiFieldDoc(
    title: 'Text',
    body:
        'A newline splits it into one text display per line. Ampersand codes, '
        'legacy section codes and full MiniMessage tags all work, and '
        'PlaceholderAPI runs over it - once, when the icon is created. Nothing '
        're-resolves afterwards, so a placeholder shows whatever it meant at '
        'open for the rest of the session. Note the hitbox is a character '
        'count, not a glyph measurement: a wide line grabs clicks well past '
        'where the text appears to end.',
    citation: 'TextUtils.java:37-43',
  ),

  // --- actions --------------------------------------------------------------
  'action.command.command': HuiFieldDoc(
    title: 'Command',
    body:
        'The leading slash is optional - the plugin strips it. Commands are '
        'never placeholder-expanded, so %player_name% arrives at the command '
        'handler literally. A missing command throws on click.',
    citation: 'CommandMenuAction.java:34-40',
  ),
  'action.command.source': HuiFieldDoc(
    title: 'Run as',
    body:
        'Only the exact value player runs the command as the clicking player, '
        'with their permissions. Everything else - an unknown value, and an '
        'omitted key - dispatches from the console instead, with full '
        'privileges and no permission check against the player. That is the '
        'trap: leaving source out is not "as the player", it is "as the '
        'console". Write server when you mean the console, so the file says so.',
    citation: 'CommandMenuAction.java:34-40',
  ),
  'action.sound.sound': HuiFieldDoc(
    title: 'Sound',
    body:
        'A lowercase namespaced key such as ui.button.click; the uppercase '
        'enum spelling parses to null. It plays at the clicking player\'s own '
        'location and only to them - nobody standing nearby hears it.',
    citation: 'SoundMenuAction.java:30-32',
  ),
  'action.sound.source': HuiFieldDoc(
    title: 'Category',
    body:
        'Which client volume slider applies: master, music, record, weather, '
        'block, hostile, neutral, player, ambient or voice. It is required, and '
        'not just for the sound - a missing or unrecognised category throws on '
        'click, and the plugin catches that per component, so every remaining '
        'action in the same list is skipped.',
    citation: 'SoundMenuAction.java:30-32',
  ),
  'action.sound.volume': HuiFieldDoc(
    title: 'Volume',
    body:
        'The format default is 0, which is silence - a sound action that '
        'leaves volume out plays nothing at all, which is why the editor always '
        'writes it. Above 1 Minecraft extends how far the sound carries rather '
        'than making it louder.',
    citation: 'SoundActionData.java:24-25',
  ),
  'action.sound.pitch': HuiFieldDoc(
    title: 'Pitch',
    body:
        'Playback speed, which the client clamps to 0.5 to 2.0. The format '
        'default is 0, so a pitch left out is clamped up to 0.5: the deepest, '
        'slowest version of the sound rather than the sound as recorded. Write '
        '1 for as recorded.',
    citation: 'SoundActionData.java:24-25',
  ),
};

/// Per-field documentation for the inspector's help popovers.
///
/// This is where the editor teaches the runtime rather than the schema. Every
/// body is a fact read out of the Gloss source, and the ones worth the screen
/// space are the traps: the keys older files spell wrong, the values that mean
/// silence, and the fields whose value the plugin overwrites a tick later. The
/// citation is the line that proves it, so a future reader can check the claim
/// instead of trusting it.
///
/// Keys are the contract the inspector looks docs up by; see
/// `test/field_docs_test.dart` for the list it must cover.
///
/// Behind this map sits `field_docs.g.dart`, generated from the plugin's own
/// JSON schemas by `tool/extract_field_docs.dart`. That layer covers the long
/// tail — every schema property with a `description`, plus its accepted values,
/// range and default — so a field only needs an entry here when the schema is
/// silent or when the schema's wording hides a trap.
library;

import '../l10n/hui_localizations.dart';
import 'field_docs.g.dart';

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
///
/// Hand-written first, schema-generated second. The order is the whole point:
/// a hand-written body exists because the schema's own wording was wrong,
/// missing, or silent about a trap, so regenerating the schema layer can never
/// take a corrected explanation back off the screen.
HuiFieldDoc? huiFieldDoc(String key) {
  final HuiFieldDoc? source = huiFieldDocs[key] ?? huiGeneratedFieldDocs[key];
  if (source == null) return null;
  return HuiFieldDoc(
    title: switch (key) {
      'action.sound.pitch' => huiTextKey('field.pitch.sound', 'Pitch'),
      'action.teleport.pitch' => huiTextKey('field.pitch.orientation', 'Pitch'),
      'hologram.pitch' => huiTextKey('field.pitch.orientation', 'Pitch'),
      _ => huiText(source.title),
    },
    body: huiText(source.body),
    citation: source.citation,
  );
}

const Map<String, HuiFieldDoc> huiFieldDocs = <String, HuiFieldDoc>{
  // --- menu root ------------------------------------------------------------
  'menu.offset': HuiFieldDoc(
    title: 'Menu offset',
    body:
        'For a personal menu, this is measured in blocks from the player\'s '
        'feet when it opens, so y 1.7 is roughly eye level. On a persistent '
        'world panel it is local to the panel anchor and rotates with the '
        'panel. X is negated in both paths. Neither uiScale nor panel scale '
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
        'folder changes the /gloss menu open argument, navigation targets and the '
        'gloss.open.<id> permission node.',
    citation: 'ConfigManager.java:267-301',
  ),
  'menu.lockPosition': HuiFieldDoc(
    title: 'Lock position',
    body:
        'Personal-menu behavior only. It rewrites every movement back to the '
        'open position and zeroes velocity while the menu is open. Persistent '
        'world panels ignore this key and use their own transform, follow and '
        'visibility settings.',
    citation: 'MenuSessionManager.java:115-127',
  ),
  'menu.followPlayer': HuiFieldDoc(
    title: 'Follow player',
    body:
        'Personal-menu behavior only. It re-centres the menu on the player and '
        'updates its facing yaw on movement, look, respawn and teleport. A '
        'persistent world panel ignores this key and uses its separate player '
        'follow target, mode and relative transform.',
    citation: 'MenuSessionManager.java:129-131',
  ),
  'menu.maxDistance': HuiFieldDoc(
    title: 'Max distance',
    body:
        'Personal-menu behavior only. It closes the session once the player '
        'moves too far from the menu centre; the value is clamped to 0 through '
        '60000000 and changing world always closes it. Persistent panels '
        'ignore this key and use their own view and interaction ranges.',
    citation: 'MenuSession.java:147-151',
  ),
  'menu.closeOnDeath': HuiFieldDoc(
    title: 'Close on death',
    body:
        'Personal-menu behavior only. On closes at death. Off preserves the '
        'session through the death event, but respawn still closes it when the '
        'new location fails the world or max-distance check. Persistent panels '
        'ignore this key and reopen from panel visibility after respawn.',
    citation: 'MenuSessionManager.java:121-140',
  ),
  'menu.closeOnTeleport': HuiFieldDoc(
    title: 'Close on teleport',
    body:
        'Personal-menu behavior only. On closes for any teleport. Even when '
        'off, a teleport to another world or beyond max distance closes the '
        'session. Persistent panels ignore this key and recalculate visibility '
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
        'multiplied by uiScale; persistent panels also apply panel scale and '
        'rotate the complete layout and click planes through panel yaw, pitch '
        'and roll. Components have no independent Euler rotation field, while '
        'display-backed icon style still owns scale and text alignment.',
    citation: 'MenuTransform.java:98-135',
  ),

  // --- clickables -----------------------------------------------------------
  'button.highlightModifier': HuiFieldDoc(
    title: 'Highlight modifier',
    body:
        'How far the icon moves toward the player while the look ray remains '
        'inside its hitbox, measured at uiScale 1. The runtime multiplies the '
        'travel by effective uiScale exactly once. The click plane stays fixed '
        'while the visual moves and its normal follows the icon billboard.',
    citation: 'ClickableComponent.java:117-160',
  ),
  'button.hoverDurationTicks': HuiFieldDoc(
    title: 'Hover duration',
    body:
        'Ticks used to enter and leave the hovered pose. The runtime default '
        'is 4, 0 switches instantly, and accepted values are 0 through 40. '
        'Changing toggle state preserves the current progress.',
    citation: 'ButtonComponentData.java:17-44',
  ),
  'button.hoverEasing': HuiFieldDoc(
    title: 'Hover easing',
    body:
        'Controls the entry and exit curve: linear, cubic ease-out, cubic '
        'ease-in/out, or back-out overshoot. The runtime default is cubic '
        'ease-out.',
    citation: 'HoverEasing.java:5-50',
  ),
  'button.hitbox': HuiFieldDoc(
    title: 'Clickable hitbox',
    body:
        'Width and height are optional, paired block dimensions at uiScale 1. '
        'Without them the plane follows the icon size. Offset moves the plane '
        'in right, up and forward axes. The button anchor keeps the plane '
        'linked to the icon; the menu anchor detaches it so each can move '
        'independently. Buttons and toggles use the same contract, so a toggle '
        'can keep one stable plane while its true and false icons differ.',
    citation: 'ClickableComponent.java:123-160',
  ),
  'toggle.condition': HuiFieldDoc(
    title: 'Condition',
    body:
        'Rendered once through the full player-aware text pipeline when the '
        'menu opens, then compared case-insensitively against the expected '
        'value. Functions, {{ expressions }}, PAPI, emoji and colours are '
        'available. It is never re-evaluated; later state changes come from '
        'clicks. A missing condition fails the menu open.',
    citation: 'ToggleComponent.java:78-80',
  ),
  'toggle.expectedValue': HuiFieldDoc(
    title: 'Expected value',
    body:
        'What the rendered condition has to equal, ignoring case, for the '
        'toggle to open in its true state. It runs through the same pipeline '
        'as the condition so colors and dynamic values compare consistently. '
        'Leaving it out does not crash; the comparison never matches.',
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
        'does not resolve through the namespaced-key registry. Gloss logs that '
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
        'Relative to plugins/Gloss/images/. The image is drawn one block '
        'character per pixel with a hex colour and is limited to 16 by 16 '
        'pixels; fully transparent pixels are left blank. Vanilla glyph spacing '
        'makes this suitable for compact pixel art, not continuous photos. A '
        'path that does not resolve renders the magenta and black '
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
        '100 ms a frame and 20 is one frame a second. Values below 2 or above '
        '1200 are rejected. There is no per-frame duration, '
        'ping-pong or play-once: the list loops forever at this one interval.',
    citation: 'AnimatedTextImageMenuIcon.java:52-60',
  ),
  'icon.text.text': HuiFieldDoc(
    title: 'Text',
    body:
        'A newline splits it into one text display per line. Ampersand codes, '
        'legacy section codes, [RRGGBB] hex and full MiniMessage tags all '
        'work, :emoji: tokens are substituted from the Gloss emoji documents, '
        'and the full viewer-aware Gloss pipeline runs when the icon is '
        'created and on its configured refresh interval: |functions|, '
        '{{ expressions }}, PlaceholderAPI, emoji and colours. Note the '
        'hitbox is a character '
        'count, not a glyph measurement: a wide line grabs clicks well past '
        'where the text appears to end.',
    citation: 'TextPipeline.java:74-79',
  ),
  'icon.text.refreshTicks': HuiFieldDoc(
    title: 'Dynamic text refresh',
    body:
        'Ticks between renders for text containing a complete %placeholder%, '
        '|function| or {{ expression }} token. The omitted default is 10 '
        'ticks, or twice per second. Zero disables updates after the initial '
        'render; the accepted range is 0 through 1200. Static text does no '
        'periodic work.',
    citation: 'TextMenuIcon.java:69-81',
  ),
  'icon.entity.entity': HuiFieldDoc(
    title: 'Entity type',
    body:
        'A lowercase namespaced Bukkit entity id. Gloss accepts only '
        'spawnable living types, renders them entirely through packets, and '
        'never inserts a real entity into the world. Body, pitch and head yaw '
        'follow the menu transform, while a private client team disables '
        'physical collision. Invalid, player, item, projectile, display and '
        'interaction types fall back to the missing icon without preventing '
        'the rest of the menu from opening.',
    citation: 'EntityIconData.java:62-70',
  ),
  'icon.entity.width': HuiFieldDoc(
    title: 'Entity click width',
    body:
        'Width of the automatic button or toggle click plane and editor '
        'silhouette in blocks at UI scale 1. A decoration has no click plane, '
        'and this never creates physical collision or resizes the client '
        'entity model. Omitted defaults to 1; values must be greater than 0 '
        'and at most 64.',
    citation: 'EntityIconData.java:54-60',
  ),
  'icon.entity.height': HuiFieldDoc(
    title: 'Entity click height',
    body:
        'Height of the automatic button or toggle click plane and editor '
        'silhouette in blocks at UI scale 1. The component anchor is the '
        'entity\'s feet, so a clickable plane is centered half its height '
        'above the anchor. Decorations have no click plane. Omitted defaults '
        'to 1; values must be greater than 0 and at most 64.',
    citation: 'EntityMenuIcon.java:71-79',
  ),
  'icon.block.block': HuiFieldDoc(
    title: 'Block material',
    body:
        'A lowercase namespaced Bukkit block material. Gloss renders its '
        'default block state as a packet-only block display at 0.75 blocks '
        'square before UI and display-style scaling. Unknown ids and '
        'non-block materials fall back to the missing icon.',
    citation: 'BlockIconData.java:43-54',
  ),
  'icon.playerHead.player': HuiFieldDoc(
    title: 'Player',
    body:
        'A Minecraft username, or a placeholder resolved once per viewer. '
        '%player_name%, %player% and {{ player.name }} are answered by Gloss '
        'itself - compared lowercased with spaces stripped - so each viewer '
        'sees their own head without PlaceholderAPI installed. Anything else '
        'goes through the text pipeline, and whatever comes out has to be 1 '
        'to 16 characters of A-Z, a-z, 0-9 or underscore before a lookup is '
        'spent on it: an unexpanded token still carrying its % or {{ }} '
        'never qualifies and draws the fallback head. A blank name is the one '
        'value that cannot degrade - it throws and the component becomes the '
        'missing-icon checkerboard.',
    citation: 'PlayerHeadMenuIcon.java:78-95',
  ),
  'icon.playerHead.refreshTicks': HuiFieldDoc(
    title: 'Head refresh',
    body:
        'Ticks between re-reading the name and the profile cache. The omitted '
        'default is 20, or once a second; the accepted range is 0 through '
        '1200 and anything outside it throws, rejecting the whole document. '
        'The first render of any name is the blank unowned head because the '
        'lookup never blocks the server, so 0 - which never re-reads - leaves '
        'that first pending head on screen until something respawns the '
        'component. A literal name that has resolved stops refreshing on its '
        'own; only a viewer-dependent name keeps costing a re-read.',
    citation: 'PlayerHeadIconData.java:21-38',
  ),

  // --- icon display style ----------------------------------------------------
  // The schema declares these eighteen fields with types, ranges and defaults
  // and not one word of description, so every body here comes from the Java
  // that applies them. Out-of-range values are never clamped: the record's
  // constructor throws and the whole menu document is rejected
  // (`IconDisplayStyle.java:103-115`).
  'icon.style.billboard': HuiFieldDoc(
    title: 'Billboard',
    body:
        'Fixed keeps the icon oriented by the menu, which is the only mode '
        'that inherits menu yaw, pitch and roll. Any other mode hands '
        'orientation to the client entirely and Gloss skips its own '
        'server-side orientation pass for that icon; the click plane is then '
        're-aimed at the viewer\'s eye every tick so clicks keep tracking '
        'what is drawn.',
    citation: 'IconBillboard.java:14-22',
  ),
  'icon.style.shadow': HuiFieldDoc(
    title: 'Text shadow',
    body:
        'The drop shadow behind glyphs. Text displays only: item, custom-item '
        'and block icons never send this field, so it is silently inert on '
        'them. Image icons do honour it, because Gloss draws them as text. '
        'Unrelated to shadow radius and strength, which are the ground '
        'shadow.',
    citation: 'IconDisplayStyle.java:77-86',
  ),
  'icon.style.seeThrough': HuiFieldDoc(
    title: 'See through blocks',
    body:
        'Renders the text through terrain, so the icon stays visible from '
        'behind a wall. Text and image icons only; inert on item and block '
        'icons. Gloss never sets the vanilla default-background flag, so this '
        'does not change the background plate.',
    citation: 'DisplayEntity.java:464-469',
  ),
  'icon.style.textAlignment': HuiFieldDoc(
    title: 'Alignment',
    body:
        'Gloss splits the icon text on newlines and spawns one display per '
        'line, so this changes nothing between lines. It becomes visible only '
        'when a single line wraps inside its own display, which line width '
        'governs — and at the default line width of 2000 that essentially '
        'never happens.',
    citation: 'IconTextAlignment.java:14-20',
  ),
  'icon.style.backgroundArgb': HuiFieldDoc(
    title: 'Background',
    body:
        'The plate drawn behind the text. Gloss defaults to fully '
        'transparent, so unlike a vanilla nametag there is no dark backing '
        'unless you ask for one, and the value is always authoritative rather '
        'than a fallback. The parser demands exactly eight hex digits: a '
        'six-digit #RRGGBB is rejected and takes the whole menu with it. Text '
        'displays only.',
    citation: 'IconArgbColor.java:17-23',
  ),
  'icon.style.textOpacity': HuiFieldDoc(
    title: 'Opacity',
    body:
        '0 through 255, where 255 is fully opaque and travels on the wire as '
        'vanilla\'s -1 encoding — the JSON number needs no adjustment. Text '
        'displays only, so it does nothing on an item or block icon. Gloss\'s '
        'own legacy hologram importer floors what it emits at 24 rather than '
        'going to 0.',
    citation: 'DisplayEntity.java:534',
  ),
  'icon.style.lineWidth': HuiFieldDoc(
    title: 'Line width',
    body:
        'Wrap width in font pixels on a text display, measured before '
        'scaling. Gloss defaults to 2000 rather than vanilla\'s 200, which in '
        'practice disables wrapping — lowering it is the only way to make '
        'wrapping or alignment do anything. On an image icon it wraps the '
        'block-character raster and garbles the picture. Inert on item and '
        'block icons.',
    citation: 'DisplayEntity.java:528-532',
  ),
  'icon.style.blockLight': HuiFieldDoc(
    title: 'Block light',
    body:
        'Half of a paired brightness override that pins the icon to a '
        'constant light level whatever its surroundings. It is meaningless '
        'alone: without sky light the record throws and the menu document is '
        'rejected. Applies to every display kind Gloss styles, not only text. '
        'Set both channels to 15 for a full-bright icon.',
    citation: 'IconDisplayStyle.java:52-58',
  ),
  'icon.style.skyLight': HuiFieldDoc(
    title: 'Sky light',
    body:
        'The other half of that pair, and rejected the same way when it '
        'travels alone. Omitting both is the default and means no override, '
        'so an icon inside a dark building is dark until both channels are '
        'set.',
    citation: 'IconDisplayStyle.java:88-93',
  ),
  'icon.style.viewRange': HuiFieldDoc(
    title: 'Display view range',
    body:
        'A multiplier, not a distance: Gloss pins 1.0 to a 64-block base, so '
        '0.25 is roughly 16 blocks and 2.0 roughly 128. It is a client cull '
        'hint only — the server never despawns the icon on this value and '
        'runs no range check of its own.',
    citation: 'HologramMath.java:9-16',
  ),
  'icon.style.shadowRadius': HuiFieldDoc(
    title: 'Shadow radius',
    body:
        'Radius in blocks of the round shadow the display casts on the ground '
        'below it. Shadow strength defaults to 0, so a radius on its own '
        'produces nothing visible: the two only work as a pair. Applies to '
        'every styled display kind, and is not the text drop shadow.',
    citation: 'DisplayEntity.java:458',
  ),
  'icon.style.shadowStrength': HuiFieldDoc(
    title: 'Shadow strength',
    body:
        'Opacity of that ground shadow, 0 to 1. This is the field that '
        'silently suppresses a shadow radius, because it defaults to 0 — and '
        'strength without radius is equally invisible, since radius defaults '
        'to 0 too.',
    citation: 'IconDisplayStyle.java:23-42',
  ),
  'icon.style.cullingWidth': HuiFieldDoc(
    title: 'Cull width',
    body:
        'The display\'s culling bounding box, passed through to the client '
        'verbatim. It has no effect on clicking whatsoever: the click plane '
        'comes from the icon geometry and the X and Y scale, or from an '
        'explicit hitbox. Do not confuse it with an entity icon\'s width, '
        'which genuinely is the click plane.',
    citation: 'ClickableComponent.java:146-155',
  ),
  'icon.style.cullingHeight': HuiFieldDoc(
    title: 'Cull height',
    body:
        'The vertical half of that box, with the same caveats: no influence '
        'on the click plane, and easy to mistake for an entity icon\'s '
        'height, which is a click dimension.',
    citation: 'MenuIcon.java:227',
  ),
  'icon.style.glowColor': HuiFieldDoc(
    title: 'Glow colour',
    body:
        'Setting a colour writes the glow override AND turns the vanilla '
        'glowing flag on, so there is no separate toggle to remember; '
        'clearing it drops both. It applies per display entity, so a '
        'multi-line text icon outlines every line separately and an item icon '
        'with a count above 1 also outlines the count label.',
    citation: 'IconDisplayStyle.java:95-101',
  ),
  'icon.style.scaleX': HuiFieldDoc(
    title: 'Scale X',
    body:
        'Multiplied by the server uiScale, and it widens the automatic click '
        'plane with the visual. Block icons carry an extra 0.75 factor on top '
        'of this. Declaring an explicit hitbox size replaces the computed '
        'plane, at which point scale stops affecting clickability at all.',
    citation: 'MenuIcon.java:229-233',
  ),
  'icon.style.scaleY': HuiFieldDoc(
    title: 'Scale Y',
    body:
        'Height, the same uiScale multiplication and the same click-plane '
        'link as X — plus one extra consequence: it scales the line height '
        'used to lay multi-line text and image icons out, so changing it '
        're-spaces the lines and shifts the icon\'s vertical anchor rather '
        'than only stretching glyphs.',
    citation: 'MenuIcon.java:174-184',
  ),
  'icon.style.scaleZ': HuiFieldDoc(
    title: 'Scale Z',
    body:
        'Depth. It never affects the click plane, which is always a flat '
        'quad built from X and Y, and it is invisible on text and image '
        'icons for the same reason. It has a real effect only on block icons '
        'and on item displays with depth.',
    citation: 'BlockMenuIcon.java:43-49',
  ),

  // --- persistent world panels ----------------------------------------------
  // A panel and a personal menu are different runtimes: the menu-level
  // lockPosition, followPlayer, maxDistance, closeOnDeath and closeOnTeleport
  // keys are read into a panel's session and then never consulted, because
  // only the personal-menu path registers a session with the manager that
  // reads them (`MenuSessionManager.java:118-148`).
  'panel.rootMenuId': HuiFieldDoc(
    title: 'Root menu',
    body:
        'The menu a player sees as soon as the panel is in view — it opens '
        'with no click, and home or back navigation returns here. The root is '
        'admitted without a permission check, so a panel can show content the '
        'player could not open with a command, while deeper menus still need '
        'gloss.open. An id nothing answers opens nothing and says nothing, '
        'and the failure latches until the revision changes.',
    citation: 'PanelViewSession.java:187-207',
  ),
  'panel.transform.position': HuiFieldDoc(
    title: 'Position',
    body:
        'The panel anchor. The menu\'s own offset is applied on top of it, '
        'and both range checks measure from it. When follow mode is set to a '
        'player these three numbers stop being world coordinates and become '
        'an offset in that player\'s local frame — switching mode in the '
        'editor reinterprets them without converting, so the panel jumps.',
    citation: 'PanelPlacement.java:29-50',
  ),
  'panel.transform.rotation': HuiFieldDoc(
    title: 'Rotation',
    body:
        'Yaw turns the panel, pitch tilts it, roll banks it, all in degrees. '
        'All three are silently rewritten on load into the half-open range '
        '-180 to 180, so a published yaw of 270 comes back as -90 with no '
        'warning. Displays render at yaw plus 180, so a panel authored at yaw '
        'N faces a viewer looking along N.',
    citation: 'PanelTransform.java:53-61',
  ),
  'panel.transform.scale': HuiFieldDoc(
    title: 'Scale',
    body:
        'Multiplies every component inside the panel\'s menu, then the server '
        'multiplies that by its own menus.uiScale — so the same panel is a '
        'different size on a differently configured server. The menu offset '
        'is deliberately not scaled, so raising this grows the content in '
        'place. Outside 0.05 to 16 the document is rejected, not clamped.',
    citation: 'PanelTransform.java:25-28',
  ),
  'panel.transform.world': HuiFieldDoc(
    title: 'World binding',
    body:
        'The key and the UUID both have to resolve, and the loaded world\'s '
        'key must equal the stored one exactly. If they disagree — a world '
        'recreated under a new key, a hand-edited file — the panel simply '
        'never renders, with nothing logged. A panel following a player '
        'ignores both and uses the target\'s current world.',
    citation: 'PanelPlacement.java:29-33',
  ),
  'panel.follow.mode': HuiFieldDoc(
    title: 'Follow mode',
    body:
        'Fixed leaves the panel at its world coordinates. Following a player '
        'samples that player once a tick and rebuilds the transform from the '
        'stored offset. A followed panel is invisible to everyone while its '
        'target has never been online this session, and once the target logs '
        'out the pose is not cleared, so the panel freezes at their last '
        'known position and stays there.',
    citation: 'PanelRuntimeManager.java:232-282',
  ),
  'panel.follow.targetPlayerUuid': HuiFieldDoc(
    title: 'Player UUID',
    body:
        'A stable account UUID, never a name, so the panel survives a rename. '
        'It is strictly coupled to the mode: required when following a '
        'player, and required to be absent otherwise — a target left behind '
        'on a fixed panel is rejected outright rather than ignored. Nothing '
        'checks the UUID against a real account, so a typo is a panel that '
        'never appears.',
    citation: 'PanelFollow.java:11-17',
  ),
  'panel.follow.rotation': HuiFieldDoc(
    title: 'Rotation behavior',
    body:
        'Fixed translates with the player and keeps the stored orientation. '
        'Yaw rotates the offset around the vertical axis and adds the '
        'target\'s yaw, so the panel orbits as they turn. Full adds pitch as '
        'well. Changing this re-reads the stored offset in a different frame, '
        'so the panel jumps — the in-game command re-encodes the offset, the '
        'editor does not.',
    citation: 'PanelFollowTransform.java:26-37',
  ),
  'panel.visibility.mode': HuiFieldDoc(
    title: 'Audience',
    body:
        'Public shows the panel to everyone in range, permission gates it, '
        'and hidden shows it to nobody. Hidden does not disable the panel: it '
        'stays loaded and indexed, and still counts toward the server-wide '
        'maximum view range that sizes every viewer\'s candidate query, so it '
        'keeps costing work each tick.',
    citation: 'PanelVisibility.java:23-31',
  ),
  'panel.visibility.viewPermission': HuiFieldDoc(
    title: 'View permission',
    body:
        'Checked every tick, so revoking it removes the panel from a player '
        'already looking at it. The value is silently lowercased and trimmed '
        'on load, so a node registered with capitals will not match. Legal '
        'only while the audience is permission-gated.',
    citation: 'PanelVisibility.java:67-76',
  ),
  'panel.visibility.interactPermission': HuiFieldDoc(
    title: 'Interaction permission',
    body:
        'Empty lets every player who can see the panel click it. Set, it '
        'gates clicking only — it is checked on the click path and never on '
        'the render path, so a player without it still receives every entity '
        'and sees hover and animation state. This is not a way to hide '
        'content. Lowercased on load like the view permission.',
    citation: 'PanelRuntimeManager.java:400-403',
  ),
  'panel.visibility.viewRange': HuiFieldDoc(
    title: 'View range',
    body:
        'True 3D distance from the player\'s feet to the panel anchor, so '
        'height counts as much as ground distance. The largest view range on '
        'the server sets the radius of the candidate query run for every '
        'player, including players nowhere near this panel. Above 256, or at '
        'or below 0, the document is rejected rather than clamped.',
    citation: 'PanelVisibility.java:32-37',
  ),
  'panel.visibility.interactionRange': HuiFieldDoc(
    title: 'Interaction range',
    body:
        'Applied twice: once from the player\'s eye to the panel anchor, and '
        'again as a cap on the ray distance to the component actually '
        'clicked. Because the first test is anchor-based, a large panel can '
        'draw components that sit outside the click radius and are visibly '
        'present but unclickable. It may never exceed the view range or 32.',
    citation: 'PanelRuntimeManager.java:584-586',
  ),
  'panel.identity': HuiFieldDoc(
    title: 'Server-owned identity',
    body:
        'The id is the panel\'s name in commands and its path on disk, the '
        'UUID is its identity across renames, and the revision is the '
        'concurrency counter the server bumps by exactly one on every accepted '
        'publish. Three layers refuse a change to any of them, so the editor '
        'round-trips them untouched and re-reads the revision after a publish.',
    citation: 'PanelRepository.java:407-420',
  ),

  // --- every document --------------------------------------------------------
  'document.revision': HuiFieldDoc(
    title: 'Revision',
    body:
        'A server-owned counter between 1 and 9007199254740991, bumped on '
        'every accepted write. The editor round-trips it untouched; out of '
        'range, the whole file is rejected.',
    citation: 'DocumentEnvelope.java:18-25',
  ),

  // --- actions --------------------------------------------------------------
  'action.command.command': HuiFieldDoc(
    title: 'Command',
    body:
        'The leading slash is optional - the plugin strips it. %player% and '
        '%player_name% become the clicking player name before player or '
        'console dispatch. Other placeholders arrive at the command handler '
        'literally. A missing, blank or just-slash command is logged and '
        'dropped when the menu is compiled.',
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
        'literal %player% becomes that player\'s name, then the full '
        'viewer-aware text pipeline resolves functions, expressions, PAPI, '
        'emoji and colours before MiniMessage parsing. A '
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
        'proxy. Gloss sends only the fixed Connect subchannel for the clicking '
        'player; whitespace, control characters and arbitrary subchannels are '
        'rejected when the component is compiled.',
    citation: 'ConnectMenuAction.java:38-56',
  ),

  // --- gloss hologram -------------------------------------------------------
  'hologram.id': HuiFieldDoc(
    title: 'Hologram id',
    body:
        'The file path under plugins/Gloss/holograms/, without .json. The id '
        'is never written into the JSON itself, and |animation.<id>| style '
        'references elsewhere use exactly this path form. Renaming here '
        'renames the exported file.',
    citation: 'HologramDoc.java:14',
  ),
  'hologram.anchor.world': HuiFieldDoc(
    title: 'Anchor world',
    body:
        'The world the TextDisplay entity stands in. A blank world makes '
        'Gloss reject the whole file, and a world that is not loaded when '
        'the plugin scans leaves the hologram despawned until it is.',
    citation: 'HologramDoc.java:22-25',
  ),
  'hologram.anchor.position': HuiFieldDoc(
    title: 'Anchor position',
    body:
        'Exact block coordinates of the display entity, serialized as an '
        '[x, y, z] array of exactly three numbers — anything else fails the '
        'vector adapter and the whole file is rejected. The text stack grows '
        'upward from here.',
    citation: 'BukkitTypeAdapters.java:30-49',
  ),
  'hologram.seeThrough': HuiFieldDoc(
    title: 'See through blocks',
    body:
        'Keeps this hologram readable through solid blocks. It is enabled '
        'by default; turn it off when nearby terrain should hide the '
        'TextDisplay normally.',
    citation: 'HologramDoc.java:40',
  ),
  'hologram.billboard': HuiFieldDoc(
    title: 'Billboard',
    body:
        'Decides whether the client turns the display toward whoever is '
        'looking. CENTER and VERTICAL and HORIZONTAL are re-solved per '
        'viewer every frame, so nobody ever sees them edge-on or backwards. '
        'FIXED is the one that behaves like a real sign: it keeps the yaw '
        'and pitch below, so it thins out as you walk around it and reads '
        'mirrored and back-to-front from behind, which is exactly what you '
        'want for something meant to be approached from one side and exactly '
        'what surprises people who set it on a hologram in the open. Omitted '
        'means CENTER, which is what every hologram did before this key '
        'existed.',
    citation: 'HologramService.java:235-245',
  ),
  'hologram.yaw': HuiFieldDoc(
    title: 'Yaw',
    body:
        'The compass direction the readable face points, in Minecraft\'s own '
        'degrees: 0 is south, 90 west, 180 north, -90 east — the same number '
        'F3 shows for a player standing where the hologram should be read '
        'from. Only FIXED and HORIZONTAL keep it; the other two modes yaw '
        'toward each viewer and overwrite it. Outside -180..180 the whole '
        'file is rejected, not clamped.',
    citation: 'HologramDoc.java:84-92',
  ),
  'hologram.pitch': HuiFieldDoc(
    title: 'Pitch',
    body:
        'Tips the readable face out of vertical: positive angles aim it at '
        'the floor, negative at the ceiling, so a hologram over a doorway can '
        'lean down toward the people under it. Only FIXED and VERTICAL keep '
        'it; CENTER and HORIZONTAL pitch toward each viewer instead. Outside '
        '-90..90 the whole file is rejected, not clamped.',
    citation: 'HologramDoc.java:84-92',
  ),
  'hologram.lines': HuiFieldDoc(
    title: 'Lines',
    body:
        'Rendered top to bottom, joined into ONE TextDisplay with newlines. '
        'Each line runs the text pipeline per viewer: |functions| such as '
        'animation.<id>, then {{ authored expressions }}, %placeholders%, '
        'emoji, and colours. Expressions can use time, PAPI, metrics, math, '
        'RGB mixing, selection and progress bars. An empty list is legal.',
    citation: 'PersistentHologram.java:594-609',
  ),
  'hologram.revision': HuiFieldDoc(
    title: 'Revision',
    body:
        'Server-owned monotonic counter between 1 and 9007199254740991. The '
        'server bumps it on every accepted write; the editor round-trips it '
        'untouched. Out of range, the whole file is rejected.',
    citation: 'DocumentEnvelope.java:18-25',
  ),

  // --- gloss animation ------------------------------------------------------
  'animation.id': HuiFieldDoc(
    title: 'Animation id',
    body:
        'The file path under plugins/Gloss/animations/, without .json — and '
        'the exact name other documents play it by: the text function is '
        'registered as animation.<id>, so |animation.rainbow| plays '
        'animations/rainbow.json. Renaming here silently breaks every '
        'reference; the referencing documents get a warning, not a rewrite.',
    citation: 'AnimationService.java:16-90',
  ),
  'animation.mode': HuiFieldDoc(
    title: 'Mode',
    body:
        'ascend walks the frames forward, descend backward, ascend_descend '
        'ping-pongs without repeating the turn frames, and random scrambles '
        'the tick with a per-id seed so two animations never sync. Anything '
        'else makes Gloss reject the whole file.',
    citation: 'AnimationClip.java:20-27',
  ),
  'animation.frameIntervalMs': HuiFieldDoc(
    title: 'Frame interval',
    body:
        'Milliseconds each frame holds. Gloss clamps this into 1..60000 '
        'SILENTLY — the file keeps saying one thing while the server plays '
        'another — so the editor warns with the effective value instead of '
        'rewriting it. The clock is wall time: every viewer and every '
        'referencing document shows the same frame at the same millisecond.',
    citation: 'AnimationDoc.java:13-20',
  ),
  'animation.frames': HuiFieldDoc(
    title: 'Frames',
    body:
        'The texts the animation cycles through, each one run through the '
        'same pipeline as the line that embeds it — colours, expressions and '
        'placeholders in a frame work exactly as they would inline. A '
        'one-frame document can still move when its expression uses time; '
        'marquee, timeline, typewriter, flash, wipe, scanner, scramble, '
        'odometer and wave provide reusable effects. An empty list is '
        'rejected.',
    citation: 'AnimationDoc.java:45-55',
  ),

  // --- gloss scoreboard -----------------------------------------------------
  'scoreboard.id': HuiFieldDoc(
    title: 'Scoreboard id',
    body:
        'The file path under plugins/Gloss/boards/, without .json. The id is '
        'never written into the JSON itself. This is the sidebar scoreboard '
        'kind — unrelated to the editor\'s menu flow maps, which the old '
        'Gloss previously called boards.',
    citation: 'BoardDoc.java:12',
  ),
  'scoreboard.title': HuiFieldDoc(
    title: 'Title',
    body:
        'Rendered through the text pipeline per viewer, then safely capped '
        'at 32 UTF-16 units WITH the colour codes still counted — an & code costs 2 '
        'and a [RRGGBB] tag costs 14 of the budget, so a hex-coloured title '
        'has 18 characters left. {{ code }} evaluates before that cut, so a '
        'time-driven colour or calculated title is measured after rendering. '
        'Line breaks become spaces.',
    citation: 'Board.java:201-206',
  ),
  'scoreboard.lines': HuiFieldDoc(
    title: 'Lines',
    body:
        'Top to bottom, each through the text pipeline per viewer — '
        'placeholders, |animation.<id>|, metrics, colours and {{ code }} all '
        'work. VolmLib renders each row as a 16-character team prefix plus '
        'a 16-character suffix; inherited colour and format codes consume '
        'suffix space. Line breaks become spaces, rows never wrap, and only '
        'the first 15 lines reach the client.',
    citation: 'BoardEntry.java:24-40',
  ),
  'scoreboard.primary': HuiFieldDoc(
    title: 'Primary board',
    body:
        'A primary board volunteers as the default sidebar for players no '
        'group or permission steers to a specific one. The shipped default '
        'board deliberately sets false so a fresh install never forces a '
        'sidebar on anyone.',
    citation: 'GlossBoardMeta.java:83-85',
  ),
  'scoreboard.hideNumbers': HuiFieldDoc(
    title: 'Hide score numbers',
    body:
        'Uses Minecraft\'s blank score number format so 1.20.3+ clients do '
        'not draw the red 15..1 column. On an older server, ViaVersion\'s '
        'global hide-scoreboard-numbers option provides the equivalent '
        'translation for 1.20.3+ clients.',
    citation: 'BoardDoc.java:10-11',
  ),
  'scoreboard.permission': HuiFieldDoc(
    title: 'Permission',
    body:
        'Trimmed and lowercased; blank or "default" means everyone sees the '
        'board. Any other value gates it behind gloss.board.<permission> — '
        'operators pass through wildcard permissions, ordinary players need '
        'the node granted. This selects who GETS the board, not who can '
        'edit it.',
    citation: 'BoardDoc.java:32-35',
  ),
  'scoreboard.groups': HuiFieldDoc(
    title: 'Groups',
    body:
        'Vault group names this board attaches to: players in one of them '
        'are steered here before permission or primary selection. The '
        'server lowercases, trims, drops blanks and deduplicates the list '
        'on load without rewriting the file.',
    citation: 'BoardDoc.java:48-63',
  ),

  // --- gloss motd ------------------------------------------------------------
  'motd.id': HuiFieldDoc(
    title: 'MOTD id',
    body:
        'The plugin keeps exactly one MOTD file, plugins/Gloss/motd.json. '
        'The id is never written into the JSON itself; syncing this document '
        'to the server writes that one file.',
    citation: 'MotdService.java:31-32',
  ),
  'motd.entries': HuiFieldDoc(
    title: 'Entries',
    body:
        'The random-pick pool: every server-list ping chooses one entry '
        'uniformly at random and shows its lines. At least one entry is '
        'required, and each entry carries one or two lines — outside that, '
        'Gloss rejects the whole file.',
    citation: 'MotdDoc.java:20-37',
  ),
  'motd.lines': HuiFieldDoc(
    title: 'Entry lines',
    body:
        'One or two lines shown together in the server list, rendered '
        'without a viewer: colours, animations, metrics, server/time '
        'expressions and math work. PAPI/player/current-ping expressions do '
        'not: the response is chosen before a player or measured latency '
        'exists.',
    citation: 'TextPipeline.java:59-61',
  ),

  // --- gloss emoji -----------------------------------------------------------
  'emoji.id': HuiFieldDoc(
    title: 'Emoji id',
    body:
        'The file path under plugins/Gloss/emoji/, without .json. The id '
        'names the chat token — heart becomes :heart: — so renaming the '
        'document renames what players type. Never written into the JSON '
        'itself.',
    citation: 'EmojiEntry.java:8-10',
  ),
  'emoji.emoji': HuiFieldDoc(
    title: 'Emoji value',
    body:
        'A literal glyph, or U+XXXX; escapes resolved once at load. A '
        'terminated escape that names no code point renders as ?, and an '
        'unterminated one stays literal — quietly, without a log line. Blank '
        'is the one thing the parser rejects outright.',
    citation: 'UnicodeText.java:6-46',
  ),
  'emoji.trigger': HuiFieldDoc(
    title: 'Trigger',
    body:
        'Optional second spelling replaced in chat alongside the :token:, '
        'e.g. <3 for the heart. The replacer substitutes the trigger first, '
        'then the token, per emoji in id order. Empty means token-only.',
    citation: 'EmojiReplacer.java:44-61',
  ),
  'emoji.enabled': HuiFieldDoc(
    title: 'Enabled',
    body:
        'A disabled emoji stays in the list (and in tab-complete data the '
        'service builds) but is filtered out of the replacer, so nothing '
        'substitutes until it is enabled again. A file that omits the key '
        'is enabled.',
    citation: 'EmojiReplacer.java:14-19',
  ),

  // --- gloss bubble style ----------------------------------------------------
  'bubble.id': HuiFieldDoc(
    title: 'Bubble style id',
    body:
        'The file path under plugins/Gloss/bubbles/, without .json. Never '
        'written into the JSON itself. The id "default" is special: it is '
        'the fallback style every unmatched player gets, and explicit '
        'choices need gloss.bubbles.style.<id>.',
    citation: 'BubbleStyles.java:9-37',
  ),
  'bubble.prefix': HuiFieldDoc(
    title: 'Prefix',
    body:
        'Text prepended to every bubble line before rendering. It accepts '
        'colours, animations, PAPI and {{ authored expressions }}, so a style '
        'can pulse or react to the sender. Only a MISSING key falls back to '
        '&7; an explicit empty string stays empty.',
    citation: 'BubbleStyleDoc.java:23',
  ),
  'bubble.offset': HuiFieldDoc(
    title: 'Offset',
    body:
        'Blocks added directly to the sender\'s eye location before older '
        'messages stack above it. Absent means [0, 0.3, 0]. When present it '
        'must be exactly three '
        'numbers — the strict vector adapter rejects the whole file '
        'otherwise.',
    citation: 'BubbleStyleDoc.java:24',
  ),
  'bubble.wordWrapChars': HuiFieldDoc(
    title: 'Word wrap',
    body:
        'Visible characters per line inside one multiline bubble block. '
        'Colour and formatting codes do not consume width and their active '
        'style carries across wraps. Clamped silently into 8..128 on load.',
    citation: 'BubbleStyleDoc.java:32',
  ),
  'bubble.maxAliveMs': HuiFieldDoc(
    title: 'Lifetime',
    body:
        'Milliseconds one complete wrapped bubble block lives. Clamped '
        'silently into 500..60000. Motion expressions receive this as '
        'lifetimeMs and receive ageMs as the block advances.',
    citation: 'BubbleStyleDoc.java:33',
  ),
  'bubble.shimmer.color': HuiFieldDoc(
    title: 'Band color',
    body:
        'Every lit glyph in the moving band uses this color. The shipped '
        'original-Gloss preset is a solid white three-glyph wave. Each '
        'glyph\'s own color and formats are restored straight after it.',
    citation: 'BubbleShimmerPlan.java:128-134',
  ),
  'bubble.shimmer.durationMs': HuiFieldDoc(
    title: 'Sweep duration',
    body:
        'Wall time for one complete left-to-right pass across the entire '
        'wrapped text block. The shipped 700 ms pass is sampled by the '
        'high-frequency hologram animator, so longer messages remain smooth '
        'instead of spawning a separate shimmer on each row.',
    citation: 'BubbleShimmerPlan.java:24-28',
  ),
  'bubble.shimmer.flyAway': HuiFieldDoc(
    title: 'Fly-away shimmer',
    body:
        'Enables a second bounded sweep anchored flyAwayLeadMs before expiry. '
        'It wins if its window overlaps the spawn pass and defaults on, giving '
        'one delayed arrival shimmer and one departure shimmer.',
    citation: 'BubbleShimmerPlan.java:77-88',
  ),
  'bubble.followPlayer': HuiFieldDoc(
    title: 'Follow player',
    body:
        'When on, bubbles anchor to the sender\'s current eye location as '
        'they move; off keeps each bubble where the message was sent.',
    citation: 'ChatBubblesService.java:227',
  ),
  'bubble.hideOwn': HuiFieldDoc(
    title: 'Hide own',
    body:
        'When on, the sender is excluded from their own bubbles\' viewer '
        'set — everyone else still sees them.',
    citation: 'ChatBubblesService.java:208-210',
  ),
  'bubble.select.worlds': HuiFieldDoc(
    title: 'Select worlds',
    body:
        'World-name globs with * and ? wildcards; any match passes. Empty '
        'skips the world check. Entries are trimmed and blanks dropped, '
        'case preserved.',
    citation: 'BubbleStyles.java:40-59',
  ),
  'bubble.select.groups': HuiFieldDoc(
    title: 'Select groups',
    body:
        'Vault primary-group names; the sender\'s group, lowercased, must '
        'be in the list. Empty skips the group check. Entries are trimmed, '
        'lowercased and blanks dropped.',
    citation: 'BubbleStyleDoc.java:41-58',
  ),
  'bubble.select.priority': HuiFieldDoc(
    title: 'Select priority',
    body:
        'Among all auto-matching styles the highest priority wins; ties '
        'break to the lexicographically smaller style id. A style with no '
        'select block never enters this contest at all.',
    citation: 'BubbleStyles.java:22-35',
  ),

  // --- gloss tablist ---------------------------------------------------------
  'tablist.id': HuiFieldDoc(
    title: 'Tablist id',
    body:
        'The plugin keeps exactly one tab config, plugins/Gloss/tablist.json. '
        'The id is never written into the JSON itself; syncing this document '
        'to the server writes that one file.',
    citation: 'TablistService.java:38-39',
  ),
  'tablist.useHeaderFooter': HuiFieldDoc(
    title: 'Use header and footer',
    body:
        'When on, the header and footer render through the text pipeline '
        'per viewer on every update tick. When off, the plugin clears '
        'whatever it applied and leaves the tab screen\'s top and bottom '
        'vanilla.',
    citation: 'TablistService.java:187-199',
  ),
  'tablist.header': HuiFieldDoc(
    title: 'Header',
    body:
        'Shown above the player grid. Colours, placeholders, '
        '|animation.<id>|, metrics and {{ code }} all work. papiNumber plus '
        'math can calculate ping/status colours and progress bars; time can '
        'drive RGB effects at the update interval.',
    citation: 'TablistService.java:188-196',
  ),
  'tablist.footer': HuiFieldDoc(
    title: 'Footer',
    body:
        'Shown below the player grid, through the same per-viewer pipeline '
        'as the header.',
    citation: 'TablistService.java:188-196',
  ),
  'tablist.groupListNames': HuiFieldDoc(
    title: 'Group list names',
    body:
        'When on, every player\'s list name renders from the matching '
        'format. When off, applied names reset to vanilla and the formats '
        'go unused.',
    citation: 'TablistService.java:201-207',
  ),
  'tablist.nameFormats': HuiFieldDoc(
    title: 'Name formats',
    body:
        'Group key to format, with \$player and \$group tokens. Operators '
        'take _op first, then the player\'s primary group, then default; '
        'with no default the literal \$player fallback applies. Keys are '
        'trimmed, lowercased and blank ones dropped on load. A blank format '
        'RESETS matching players to vanilla. Formats also run authored '
        'expressions, so rank colours and effects can animate.',
    citation: 'TablistService.java:54-66',
  ),

  // --- real-drop timeline animation ----------------------------------------
  'realDrops.animation': HuiFieldDoc(
    title: 'Timeline animation',
    body:
        'Profiles select by material and priority, then lifecycle trigger clips '
        'compose typed scalar tracks over the normal drop presentation.',
    citation: 'RealDropAnimationPlan.java:16-68',
  ),
  'realDrops.animation.enabled': HuiFieldDoc(
    title: 'Animation enabled',
    body:
        'When off, Gloss skips the complete profile and clip layer while '
        'retaining the authored data.',
    citation: 'RealDropAnimationEngine.java:8-28',
  ),
  'realDrops.animation.materialProperties': HuiFieldDoc(
    title: 'Material properties',
    body:
        'Named maps resolve material globs to glow ARGB and light-level values '
        'for keyframes that opt into a map.',
    citation: 'RealDropAnimationPlan.java:278-307',
  ),
  'realDrops.animation.profiles': HuiFieldDoc(
    title: 'Animation profiles',
    body:
        'Gloss chooses the highest-priority matching profile, preserving '
        'declaration order when priorities tie.',
    citation: 'RealDropAnimationPlan.java:91-134',
  ),
  'realDrops.animation.profile.id': HuiFieldDoc(
    title: 'Profile id',
    body: 'The identifier must be non-blank and unique within the animation.',
    citation: 'RealDropAnimationPlan.java:91-104',
  ),
  'realDrops.animation.profile.priority': HuiFieldDoc(
    title: 'Profile priority',
    body:
        'Higher values win material selection; accepted values are -10000 through 10000.',
    citation: 'RealDropSettingsDoc.java:431-457',
  ),
  'realDrops.animation.profile.materials': HuiFieldDoc(
    title: 'Profile materials',
    body:
        'Patterns accept * and ? wildcards and match normalized material names '
        'without requiring the minecraft namespace.',
    citation: 'RealDropAnimationPlan.java:136-183',
  ),
  'realDrops.animation.profile.clips': HuiFieldDoc(
    title: 'Profile clips',
    body: 'Matching trigger clips evaluate in their declaration order.',
    citation: 'RealDropAnimationPlan.java:48-68',
  ),
  'realDrops.animation.clip.trigger': HuiFieldDoc(
    title: 'Clip trigger',
    body:
        'A trigger is either a continuing lifecycle state or a discrete event '
        'such as impact, bounce, fluid entry, settling, or waking.',
    citation: 'GlossConfig.java:222-240',
  ),
  'realDrops.animation.clip.durationTicks': HuiFieldDoc(
    title: 'Clip duration',
    body: 'Elapsed clip time clamps here unless looping is enabled.',
    citation: 'RealDropAnimationPlan.java:462-486',
  ),
  'realDrops.animation.clip.loop': HuiFieldDoc(
    title: 'Clip loop',
    body:
        'When on and duration is positive, elapsed time wraps at the duration.',
    citation: 'RealDropAnimationPlan.java:462-486',
  ),
  'realDrops.animation.clip.tracks': HuiFieldDoc(
    title: 'Clip tracks',
    body:
        'Each entry drives one target and must contain at least one keyframe.',
    citation: 'RealDropAnimationPlan.java:207-273',
  ),
  'realDrops.animation.track.target': HuiFieldDoc(
    title: 'Track target',
    body:
        'Targets cover offset, rotation, scale, glow, visibility, physics '
        'gating, and light level.',
    citation: 'GlossConfig.java:242-256',
  ),
  'realDrops.animation.track.blend': HuiFieldDoc(
    title: 'Track blend',
    body:
        'Replace supports every target, add is limited to offset and rotation, '
        'and multiply is limited to scale.',
    citation: 'RealDropAnimationPlan.java:309-346',
  ),
  'realDrops.animation.track.keyframes': HuiFieldDoc(
    title: 'Track keyframes',
    body:
        'Ticks must be finite, unique, non-negative, and inside the clip duration.',
    citation: 'RealDropAnimationPlan.java:239-273',
  ),
  'realDrops.animation.keyframe.tick': HuiFieldDoc(
    title: 'Keyframe tick',
    body:
        'The sample position is measured in server ticks from clip activation.',
    citation: 'RealDropAnimationPlan.java:239-273',
  ),
  'realDrops.animation.keyframe.value': HuiFieldDoc(
    title: 'Keyframe value',
    body:
        'This finite scalar is interpolated before the selected blend is applied.',
    citation: 'RealDropAnimationPlan.java:239-273',
  ),
  'realDrops.animation.keyframe.materialMap': HuiFieldDoc(
    title: 'Keyframe material map',
    body:
        'Only glow and light-level tracks may replace their scalar with a value '
        'from a named material property map.',
    citation: 'RealDropAnimationPlan.java:278-307',
  ),
  'realDrops.animation.keyframe.easing': HuiFieldDoc(
    title: 'Keyframe easing',
    body:
        'Interpolation uses the easing declared on the destination keyframe, '
        'including hold, cubic ease, and back-out curves.',
    citation: 'RealDropAnimationPlan.java:365-405',
  ),
};

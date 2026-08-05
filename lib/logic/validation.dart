import '../model/model.dart';
import '../services/catalogs.dart';
import 'canvas_scene.dart' show CanvasOverlap;
import 'hui_geometry.dart' show huiLineHeight;
import 'mc_text.dart' show parseMcText;

enum HuiSeverity { error, warning, info }

class HuiIssue {
  final HuiSeverity severity;

  /// Dotted path into the exported JSON, e.g. `components[2].data.icon.text`.
  final String path;
  final String? componentId;
  final String message;

  /// Short suggested remedy, shown as help text next to the issue.
  final String? fix;

  const HuiIssue({
    required this.severity,
    required this.path,
    required this.message,
    this.componentId,
    this.fix,
  });

  @override
  String toString() => '${severity.name.toUpperCase()} $path: $message';
}

/// Semantic validation against the Java parser's real behaviour (not the stale
/// shipped JSON schema). Catalog sets are optional: when omitted, catalog
/// membership is not checked.
///
/// [overlaps] carries intersecting clickable hitbox pairs from an already
/// resolved scene, because overlap is a geometry question the validator has no
/// business re-deriving. The store passes the pairs from a uiScale-1 scene;
/// omitting them simply skips the overlap rule.
List<HuiIssue> validateHuiMenu(
  HuiMenu menu, {
  Set<String>? knownImagePaths,
  Set<String>? knownMaterials,
  Set<String>? knownSounds,
  HuiCustomItemCatalog? customItems,
  List<CanvasOverlap> overlaps = const <CanvasOverlap>[],
}) {
  final _Validator validator = _Validator(
    knownImagePaths: knownImagePaths,
    knownMaterials: knownMaterials,
    knownSounds: knownSounds,
    customItems: customItems,
    overlaps: overlaps,
  );
  validator.validateMenu(menu);
  return validator.issues;
}

/// Stack sizes above this are refused by the client, not by HoloUI.
const int huiMaxStackCount = 99;

/// Widest line, in characters, at which a text click plane is called out.
/// `TextMenuIcon.createBoundingBox` sizes the plane at
/// `chars x lineHeight / 2` (`TextMenuIcon.java:66-71`), so 16 characters is
/// already 1.75 blocks wide — wider than most authors picture.
const int huiWideTextHitboxChars = 16;

/// `/holoui` plus its aliases (`HoloCommand.java:38`). Director resolves both
/// command and subcommand names with `equalsIgnoreCase`
/// (`DirectorRuntimeEngine.java:365,613,668`).
const Set<String> _huiCommandRoots = <String>{
  'holoui',
  'holo',
  'hui',
  'holou',
  'hu',
};

/// Subcommands that return early unless the sender is a `Player`
/// (`HoloCommand.java:99-102,115-118,133-136`).
const Set<String> _huiPlayerOnlySubcommands = <String>{'open', 'back', 'close'};

final RegExp _whitespacePattern = RegExp(r'\s+');

/// The player-only `/holoui` subcommand [command] dispatches, or null.
///
/// `open` is the exception: its menu argument defaults to `*`, and `*` returns
/// through `list(sender)` before the Player check (`HoloCommand.java:94-97`),
/// so a bare `open` genuinely does work from the console.
String? huiPlayerOnlySubcommand(String command) {
  // The plugin strips one leading slash and nothing else
  // (`CommandMenuAction.java:35`); the trim is for the author, not the parser.
  final String body = (command.startsWith('/') ? command.substring(1) : command)
      .trim();
  final List<String> tokens = body
      .split(_whitespacePattern)
      .where((String token) => token.isNotEmpty)
      .toList();
  if (tokens.length < 2) return null;
  if (!_huiCommandRoots.contains(tokens[0].toLowerCase())) return null;
  final String subcommand = tokens[1].toLowerCase();
  if (!_huiPlayerOnlySubcommands.contains(subcommand)) return null;
  if (subcommand == 'open' && (tokens.length < 3 || tokens[2] == '*')) {
    return null;
  }
  return subcommand;
}

final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_.-]+$');
final RegExp _registryKeyPattern = RegExp(r'^([a-z0-9_.-]+:)?[a-z0-9_./-]+$');
final RegExp _placeholderPattern = RegExp(r'%[^%\s]+%');

/// `&n`/`&k` (and their section-sign equivalents) translate to `<underline>` /
/// `<magic>`, which MiniMessage does not recognise.
final RegExp _brokenLegacyPattern = RegExp('&[nNkK]|§[nk]');

class _Validator {
  _Validator({
    this.knownImagePaths,
    this.knownMaterials,
    this.knownSounds,
    this.customItems,
    this.overlaps = const <CanvasOverlap>[],
  });

  final Set<String>? knownImagePaths;
  final Set<String>? knownMaterials;
  final Set<String>? knownSounds;
  final HuiCustomItemCatalog? customItems;

  /// Intersecting clickable hitboxes, resolved by the caller's scene.
  final List<CanvasOverlap> overlaps;
  final List<HuiIssue> issues = <HuiIssue>[];

  String? _componentId;

  void _add(HuiSeverity severity, String path, String message, {String? fix}) {
    issues.add(
      HuiIssue(
        severity: severity,
        path: path,
        message: message,
        componentId: _componentId,
        fix: fix,
      ),
    );
  }

  void validateMenu(HuiMenu menu) {
    if (menu.absentKeys.contains('offset')) {
      _add(
        HuiSeverity.info,
        'offset',
        'The imported file had no menu offset, which the plugin NPEs on. It '
            'was defaulted to [0, 0, 0] (the player\'s feet) and the export '
            'now writes it explicitly',
        fix: 'Set an offset such as [0, 1.7, 2.5]',
      );
    }
    if (menu.absentKeys.contains('components')) {
      _add(
        HuiSeverity.info,
        'components',
        'The imported file had no components list, which the plugin NPEs on. '
            'It was defaulted to an empty list',
        fix: 'Add the components this menu should show',
      );
    }
    if (menu.components.isEmpty) {
      _add(
        HuiSeverity.warning,
        'components',
        'The menu has no components, so it opens as an empty hologram',
        fix: 'Add at least one component',
      );
    }

    final double? maxDistance = menu.maxDistance;
    if (maxDistance != null &&
        (maxDistance < 0 || maxDistance > huiMaxDistanceCeiling)) {
      _add(
        HuiSeverity.warning,
        'maxDistance',
        'maxDistance is outside [0, 6e7] and will be clamped by the plugin',
        fix: 'Use a value between 0 and 60000000, or clear it for unlimited',
      );
    }

    // `MenuDefinitionData` has no name field, and `ConfigManager.registerMenu`
    // keys the registry by the file base name before overwriting the parsed id
    // (`ConfigManager.java:157,214`). The key survives export as an extra, so
    // the note is about expectations, not about data loss.
    if (menu.extras.containsKey('name')) {
      _add(
        HuiSeverity.info,
        'name',
        'HoloUI has no menu "name" field: the menu id is the file base name. '
            'The key is preserved on export but ignored in-game',
        fix: 'Rename the exported file to change the menu id',
      );
    }

    final Set<String> seen = <String>{};
    for (int i = 0; i < menu.components.length; i++) {
      final HuiComponent component = menu.components[i];
      _componentId = component.id.isEmpty ? null : component.id;
      _validateComponent(component, 'components[$i]', seen);
    }
    _componentId = null;
    _validateOverlaps(menu);
  }

  /// One issue per pair, anchored on the first component: a left click fires
  /// every clickable whose plane is under the crosshair, in declaration order
  /// (`MenuSessionManager.java:170-203`), so an accidental overlap silently
  /// doubles up actions.
  void _validateOverlaps(HuiMenu menu) {
    for (final CanvasOverlap overlap in overlaps) {
      final int index = menu.indexOfComponent(overlap.firstId);
      // A stale pair from a scene built before the last edit names a component
      // that is gone; reporting a path that does not exist is worse than
      // reporting nothing.
      if (index < 0 || menu.indexOfComponent(overlap.secondId) < 0) continue;
      _componentId = overlap.firstId;
      _add(
        HuiSeverity.warning,
        'components[$index]',
        'Hitbox overlaps "${overlap.secondId}": one left click fires every '
            'component under the crosshair, so both run their actions',
        fix: 'Move or shrink one of them, or make one a decoration',
      );
    }
    _componentId = null;
  }

  void _validateComponent(
    HuiComponent component,
    String path,
    Set<String> seen,
  ) {
    if (component.absentKeys.contains('offset')) {
      _add(
        HuiSeverity.info,
        '$path.offset',
        'The imported file gave this component no offset, which the plugin '
            'NPEs on. It was defaulted to the menu centre',
        fix: 'Position the component on the canvas or in the inspector',
      );
    }

    final String id = component.id;
    if (id.isEmpty) {
      _add(
        HuiSeverity.warning,
        '$path.id',
        'Component has no id, so the Java API cannot address it',
        fix: 'Give the component a short id like "buy-button"',
      );
    } else {
      if (!_idPattern.hasMatch(id)) {
        _add(
          HuiSeverity.warning,
          '$path.id',
          'Component id contains invalid characters; the Java API sanitizes to '
              '[A-Za-z0-9_.-]',
          fix: 'Use only letters, digits, underscore, dot and hyphen',
        );
      }
      if (id.length > 64) {
        _add(
          HuiSeverity.warning,
          '$path.id',
          'Component id is longer than 64 characters and the Java API '
              'truncates it',
          fix: 'Shorten the id to 64 characters or fewer',
        );
      }
      if (!seen.add(id)) {
        _add(
          HuiSeverity.warning,
          '$path.id',
          'Duplicate component id "$id": later duplicates are unaddressable by '
              'the API but still render and still click',
          fix: 'Rename this component to a unique id',
        );
      }
    }

    switch (component.data) {
      case final HuiButtonData data:
        _validateHighlight(data.highlightModifier, '$path.data');
        _validateHitbox(data.hitbox, '$path.data.hitbox');
        _validateIcon(data.icon, '$path.data.icon', clickable: true);
        _validateActions(data.actions, '$path.data.actions');
      case final HuiDecorationData data:
        _validateIcon(data.icon, '$path.data.icon', clickable: false);
      case final HuiToggleData data:
        _validateHighlight(data.highlightModifier, '$path.data');
        if (data.condition.trim().isEmpty) {
          _add(
            HuiSeverity.error,
            '$path.data.condition',
            'Toggle condition is empty, so it can only ever match an empty '
                'expected value and the toggle is stuck in one state',
            fix: 'Set a placeholder like %essentials_fly% or a literal string',
          );
        }
        if (data.expectedValue.trim().isEmpty) {
          _add(
            HuiSeverity.error,
            '$path.data.expectedValue',
            'Toggle expectedValue is empty, so only an empty condition result '
                'matches and the toggle is stuck in one state',
            fix: 'Set the value the condition is compared against, e.g. "true"',
          );
        }
        _validateIcon(data.trueIcon, '$path.data.trueIcon', clickable: true);
        _validateIcon(data.falseIcon, '$path.data.falseIcon', clickable: true);
        _validateActions(data.trueActions, '$path.data.trueActions');
        _validateActions(data.falseActions, '$path.data.falseActions');
    }
  }

  void _validateHighlight(double value, String path) {
    if (value < 0 || value > 1) {
      _add(
        HuiSeverity.warning,
        '$path.highlightModifier',
        // The clamp at HoloComponent.java:33 is on the third-party API record
        // only. ButtonComponentData/ToggleComponentData are plain records with
        // no compact constructor, so Gson writes a parsed value straight in and
        // ClickableComponent.java:65 spends it as a block distance along the
        // unit plane normal.
        'highlightModifier is outside 0..1 and a value read from a file is '
            'used verbatim - the API clamp never sees it. It is a distance in '
            'blocks along the plane normal, so large values push the icon '
            'through the player and negative ones push it away',
        fix: 'Use a value between 0 and 1 (0.05 is typical)',
      );
    }
  }

  void _validateHitbox(HuiHitbox? hitbox, String path) {
    if (hitbox == null) return;
    if ((hitbox.width == null) != (hitbox.height == null)) {
      _add(
        HuiSeverity.error,
        path,
        'Custom hitbox width and height must be supplied together',
        fix: 'Set both dimensions, or switch back to automatic size',
      );
    }
    final double? width = hitbox.width;
    if (width != null && (!width.isFinite || width <= 0)) {
      _add(
        HuiSeverity.error,
        '$path.width',
        'Custom hitbox width must be finite and greater than zero',
        fix: 'Set a positive width in blocks, or switch back to automatic',
      );
    }
    final double? height = hitbox.height;
    if (height != null && (!height.isFinite || height <= 0)) {
      _add(
        HuiSeverity.error,
        '$path.height',
        'Custom hitbox height must be finite and greater than zero',
        fix: 'Set a positive height in blocks, or switch back to automatic',
      );
    }
    if (!hitbox.offset.x.isFinite ||
        !hitbox.offset.y.isFinite ||
        !hitbox.offset.z.isFinite) {
      _add(
        HuiSeverity.error,
        '$path.offset',
        'Hitbox offset components must be finite numbers',
        fix: 'Set finite right, up and forward offsets',
      );
    }
  }

  void _validateIcon(HuiIcon? icon, String path, {required bool clickable}) {
    if (icon == null) {
      _add(
        HuiSeverity.warning,
        path,
        'No icon: the component renders the built-in magenta/black '
        'missing-icon placeholder',
        fix: 'Pick an icon type for this component',
      );
      return;
    }
    switch (icon) {
      case final HuiTextIcon text:
        _validateText(text.text, '$path.text', clickable: clickable);
      case final HuiTextImageIcon image:
        _validateImagePath(image.path, '$path.path');
      case final HuiAnimatedImageIcon animated:
        if (animated.source.isEmpty) {
          _add(
            HuiSeverity.error,
            '$path.source',
            'Animated icon has no frames; the plugin throws while opening the '
                'menu',
            fix: 'Add at least one frame image',
          );
        }
        for (int i = 0; i < animated.source.length; i++) {
          _validateImagePath(animated.source[i], '$path.source[$i]');
        }
        if (animated.speed < 1) {
          _add(
            HuiSeverity.error,
            '$path.speed',
            'Speed below 1 advances a frame every tick (20 frames per '
                'second), exactly like speed 1',
            fix: 'Use 2 or more ticks per frame for a readable animation',
          );
        }
      case final HuiItemIcon item:
        _validateMaterial(item.item, '$path.item');
      case final HuiCustomItemIcon custom:
        _validateCustomItem(custom, path);
    }
  }

  /// The editor cannot see the server's plugins, so nothing here except a blank
  /// id is an error: an id it has never heard of may still be perfectly valid.
  void _validateCustomItem(HuiCustomItemIcon icon, String path) {
    final String id = icon.item;
    if (id.trim().isEmpty) {
      _add(
        HuiSeverity.error,
        '$path.item',
        'Custom item id is empty; the plugin logs a warning and draws the '
            'magenta/black missing-icon placeholder',
        fix: 'Enter the id exactly as the provider plugin defines it',
      );
    } else if (id != id.trim()) {
      _add(
        HuiSeverity.warning,
        '$path.item',
        'The id starts or ends with whitespace and is looked up verbatim, so '
            'it will not resolve',
        fix: 'Remove the surrounding whitespace',
      );
    }

    final String provider = icon.provider.trim();
    if (provider.isNotEmpty &&
        provider != huiAutoItemProvider &&
        !huiCustomItemProviders.contains(provider)) {
      final String lowered = provider.toLowerCase();
      _add(
        HuiSeverity.warning,
        '$path.provider',
        'Unknown item provider "$provider"; HoloUI has no adapter for it and '
            'the icon will not resolve',
        fix: huiCustomItemProviders.contains(lowered)
            ? 'Provider ids are lowercase: use $lowered'
            : 'Use one of ${huiCustomItemProviders.join(", ")}, or auto',
      );
    }

    if (icon.count < 1 || icon.count > huiMaxStackCount) {
      _add(
        HuiSeverity.warning,
        '$path.count',
        'Stack count is outside 1-$huiMaxStackCount; the plugin turns anything '
            'below 1 into 1 and the client cannot draw a larger stack',
        fix: 'Use a count between 1 and $huiMaxStackCount',
      );
    }

    // Only for an id that is otherwise well formed: a padded id is already
    // reported above, and "re-run the export" would be the wrong advice.
    final HuiCustomItemCatalog? catalog = customItems;
    if (catalog != null &&
        catalog.isNotEmpty &&
        id.isNotEmpty &&
        id == id.trim() &&
        !catalog.contains(icon.provider, id)) {
      _add(
        HuiSeverity.info,
        '$path.item',
        '"$id" is not in the custom item catalog exported from your server; '
            'the server is the only thing that can confirm it',
        fix: 'Re-run /holoui items export if you added the item recently',
      );
    }
  }

  void _validateText(String text, String path, {required bool clickable}) {
    // Plain length never exceeds raw length (parsing only strips tags), so a
    // short field can skip the parse entirely — this runs on every keystroke.
    if (clickable && text.length >= huiWideTextHitboxChars) {
      final int chars = parseMcText(text).maxLineLength;
      if (chars >= huiWideTextHitboxChars) {
        final String blocks = (chars * huiLineHeight / 2).toStringAsFixed(2);
        _add(
          HuiSeverity.info,
          path,
          'Text hitboxes are sized by character count, not by how wide the '
          'glyphs look: $chars characters make this click plane $blocks '
          'blocks wide at UI scale 1',
          fix:
              'Shorten the line, or leave room around it; the canvas hitbox '
              'outline shows the real extent',
        );
      }
    }

    if (_brokenLegacyPattern.hasMatch(text)) {
      _add(
        HuiSeverity.warning,
        path,
        '&n and &k translate to invalid MiniMessage tags and render literally '
        'in-game as <underline> / <magic>',
        fix: 'Use <u>...</u> or <obf>...</obf> instead',
      );
    }
    if (_placeholderPattern.hasMatch(text)) {
      _add(
        HuiSeverity.info,
        path,
        'Uses a PlaceholderAPI placeholder: it is expanded once when the menu '
        'opens and requires PlaceholderAPI on the server',
        fix: null,
      );
    }
  }

  void _validateImagePath(String path, String jsonPath) {
    if (path.isEmpty) {
      _add(
        HuiSeverity.error,
        jsonPath,
        'Image path is empty',
        fix: 'Pick an image from the library',
      );
      return;
    }
    if (path.startsWith('/')) {
      _add(
        HuiSeverity.error,
        jsonPath,
        'Image path must not start with "/": it is resolved relative to '
        'plugins/holoui/images/',
        fix: 'Drop the leading slash',
      );
    }
    if (path.contains(':')) {
      _add(
        HuiSeverity.error,
        jsonPath,
        'Image path must not contain ":"',
        fix: 'Use a path relative to plugins/holoui/images/',
      );
    }
    if (path.contains('..')) {
      _add(
        HuiSeverity.error,
        jsonPath,
        'Image path must not contain ".."',
        fix: 'Use a path relative to plugins/holoui/images/',
      );
    }
    if (path.contains(r'\')) {
      _add(
        HuiSeverity.error,
        jsonPath,
        r'Image path must not contain "\"',
        fix: 'Use forward slashes',
      );
    }
    if (path.length > 256) {
      _add(
        HuiSeverity.error,
        jsonPath,
        'Image path is longer than 256 characters',
        fix: 'Rename the image to something shorter',
      );
    }
    final Set<String>? known = knownImagePaths;
    if (known != null && !known.contains(path)) {
      _add(
        HuiSeverity.info,
        jsonPath,
        'Image "$path" is not in the image library; make sure it exists in '
        'plugins/holoui/images/',
        fix: 'Upload the image so it ships with the exported zip',
      );
    }
  }

  void _validateMaterial(String material, String path) {
    if (material.isEmpty) {
      _add(
        HuiSeverity.error,
        path,
        'Material key is empty; the plugin fails to open the menu',
        fix: 'Pick a material such as diamond_sword',
      );
      return;
    }
    if (material != material.toLowerCase()) {
      _add(
        HuiSeverity.error,
        path,
        'Material key must be lowercase: NamespacedKey rejects uppercase and '
        'the item resolves to null',
        fix: 'Use ${material.toLowerCase()}',
      );
      return;
    }
    if (!_registryKeyPattern.hasMatch(material)) {
      _add(
        HuiSeverity.error,
        path,
        'Material key contains invalid characters',
        fix: 'Use a registry key such as minecraft:diamond_sword',
      );
      return;
    }
    final Set<String>? known = knownMaterials;
    if (known != null && !_inCatalog(material, known)) {
      _add(
        HuiSeverity.warning,
        path,
        'Material "$material" is not in the material catalog; it may still be '
        'valid on a newer server',
        fix: 'Double-check the spelling against the item picker',
      );
    }
  }

  void _validateActions(List<HuiAction> actions, String path) {
    for (int i = 0; i < actions.length; i++) {
      final HuiAction action = actions[i];
      final String actionPath = '$path[$i]';
      switch (action) {
        case final HuiCommandAction command:
          _validateCommand(command, actionPath);
        case final HuiSoundAction sound:
          _validateSound(sound, actionPath);
      }
    }
  }

  void _validateCommand(HuiCommandAction action, String path) {
    if (action.command.trim().isEmpty) {
      _add(
        HuiSeverity.error,
        '$path.command',
        'Command is empty; the plugin throws when the button is clicked',
        fix: 'Enter a command, for example /warp shop',
      );
    } else if (action.command.contains('%')) {
      _add(
        HuiSeverity.info,
        '$path.command',
        'Placeholders are not expanded in commands: the string is dispatched '
            'verbatim',
      );
    }
    // `CommandMenuAction.execute` dispatches as the player only for an exact
    // PLAYER enum match; `server` and an absent key both reach the console
    // sender (`CommandMenuAction.java:34-40`). An absent key is normalised to
    // `server` on import, so the flag is what tells those two apart.
    final bool sourceAbsent = action.absentKeys.contains('source');
    final bool consoleForCertain = sourceAbsent || action.source == 'server';
    final String? playerOnly = huiPlayerOnlySubcommand(action.command);

    // The specific failure beats the generic one: an absent source on a
    // player-only subcommand would otherwise raise two warnings that say
    // roughly the same thing and neither of them the useful part.
    if (playerOnly != null && consoleForCertain) {
      _add(
        HuiSeverity.warning,
        '$path.source',
        '"holoui $playerOnly" only works for a player, and this action runs '
            'from the console (${sourceAbsent ? 'the file gave it no source' : 'source "server"'}), '
            'so clicking does nothing but print a player-only notice to the '
            'server log',
        fix: 'Set the source to "player"',
      );
    } else if (sourceAbsent) {
      _add(
        HuiSeverity.warning,
        '$path.source',
        'The imported file gave this command no source, so HoloUI ran it from '
            'the console. It was read as "server" and the export now writes '
            'that explicitly',
        fix:
            'Switch the source to "player" if the command was meant to run as '
            'the clicking player',
      );
    } else if (!huiCommandSources.contains(action.source)) {
      // HoloUi shades no Gson and registers no adapter for
      // `MenuActionCommandSource`, so an odd spelling is resolved by whatever
      // Gson the server ships: 2.10+ falls back to matching `toString()`, so
      // "PLAYER" reaches the player, while 2.8.x leaves the field null and the
      // command runs from the console. Neither outcome can be asserted here.
      _add(
        HuiSeverity.warning,
        '$path.source',
        'Command source "${action.source}" is not one of the two spellings '
            'HoloUI declares, and no Gson adapter is registered for them, so '
            'whether it resolves to the player or falls through to the console '
            'depends on the server\'s Gson version',
        fix: 'Use "player" or "server"',
      );
    }
  }

  void _validateSound(HuiSoundAction action, String path) {
    final String sound = action.sound;
    if (sound.isEmpty) {
      _add(
        HuiSeverity.error,
        '$path.sound',
        'Sound key is empty',
        fix: 'Pick a sound such as ui.button.click',
      );
    } else if (sound != sound.toLowerCase()) {
      _add(
        HuiSeverity.error,
        '$path.sound',
        'Sound key must be lowercase: NamespacedKey rejects uppercase and the '
            'sound resolves to null',
        fix: 'Use ${sound.toLowerCase()}',
      );
    } else if (!_registryKeyPattern.hasMatch(sound)) {
      _add(
        HuiSeverity.error,
        '$path.sound',
        'Sound key contains invalid characters',
        fix: 'Use a registry key such as block.note_block.harp',
      );
    } else {
      final Set<String>? known = knownSounds;
      if (known != null && !_inCatalog(sound, known)) {
        _add(
          HuiSeverity.warning,
          '$path.sound',
          'Sound "$sound" is not in the sound catalog; it may still be valid '
              'on a newer server',
          fix: 'Double-check the spelling against the sound picker',
        );
      }
    }

    if (!huiSoundSources.contains(action.source)) {
      _add(
        HuiSeverity.error,
        '$path.source',
        'Sound source is required and must be one of '
            '${huiSoundSources.join(", ")}',
        fix: 'Pick a sound category, for example master',
      );
    }

    if (action.volume == 0) {
      _add(
        HuiSeverity.warning,
        '$path.volume',
        'Volume 0 is inaudible; the plugin defaults a missing volume to 0',
        fix: 'Set the volume to 1',
      );
    }
    if (action.pitch == 0) {
      _add(
        HuiSeverity.warning,
        '$path.pitch',
        'Pitch 0 is invalid; the plugin defaults a missing pitch to 0',
        fix: 'Set the pitch to 1',
      );
    } else if (action.pitch < 0.5 || action.pitch > 2.0) {
      _add(
        HuiSeverity.info,
        '$path.pitch',
        'Pitch is outside the 0.5-2.0 range Minecraft accepts and will be '
            'clamped by the client',
        fix: 'Use a pitch between 0.5 and 2.0',
      );
    }
  }

  bool _inCatalog(String key, Set<String> catalog) {
    if (catalog.contains(key)) return true;
    if (key.startsWith('minecraft:')) {
      return catalog.contains(key.substring('minecraft:'.length));
    }
    return catalog.contains('minecraft:$key');
  }
}

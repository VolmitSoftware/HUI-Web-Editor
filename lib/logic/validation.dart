import '../config/defaults.dart' show validateMenuId;
import '../l10n/hui_localizations.dart';
import '../model/model.dart';
import '../services/catalogs.dart';
import 'canvas_scene.dart' show CanvasOverlap, huiIsBlockLikeMaterial;
import 'gloss_text.dart'
    show
        GlossEmojiResolver,
        GlossLineRender,
        GlossNoEmoji,
        glossMenuTextNeedsRefresh,
        glossLineMetricRefs,
        glossRenderMenuText,
        renderGlossLine;
import 'hui_geometry.dart' show huiLineHeight;
import 'mc_text.dart' show parseMcText;

enum HuiSeverity { error, warning, info }

class HuiIssue {
  final HuiSeverity severity;

  /// Dotted path into the exported JSON, e.g. `components[2].data.icon.text`.
  final String path;
  final String? componentId;
  final String _message;
  final Map<String, Object?> messageArguments;
  final String? _pluralKey;
  final int? _pluralCount;
  final String? _zeroMessage;
  final String? _oneMessage;
  final String? _twoMessage;
  final String? _fewMessage;
  final String? _manyMessage;

  /// Short suggested remedy, shown as help text next to the issue.
  final String? _fix;
  final Map<String, Object?> fixArguments;

  const HuiIssue({
    required this.severity,
    required this.path,
    required String message,
    this.messageArguments = const <String, Object?>{},
    this.componentId,
    String? fix,
    this.fixArguments = const <String, Object?>{},
  }) : _message = message,
       _fix = fix,
       _pluralKey = null,
       _pluralCount = null,
       _zeroMessage = null,
       _oneMessage = null,
       _twoMessage = null,
       _fewMessage = null,
       _manyMessage = null;

  const HuiIssue.plural({
    required this.severity,
    required this.path,
    required String pluralKey,
    required int count,
    required String oneEnglish,
    required String otherEnglish,
    String? zeroEnglish,
    String? twoEnglish,
    String? fewEnglish,
    String? manyEnglish,
    this.messageArguments = const <String, Object?>{},
    this.componentId,
    String? fix,
    this.fixArguments = const <String, Object?>{},
  }) : _message = otherEnglish,
       _fix = fix,
       _pluralKey = pluralKey,
       _pluralCount = count,
       _zeroMessage = zeroEnglish,
       _oneMessage = oneEnglish,
       _twoMessage = twoEnglish,
       _fewMessage = fewEnglish,
       _manyMessage = manyEnglish;

  String get message {
    final String? pluralKey = _pluralKey;
    final int? pluralCount = _pluralCount;
    final String? oneMessage = _oneMessage;
    if (pluralKey == null || pluralCount == null || oneMessage == null) {
      return huiText(_message, messageArguments);
    }
    return huiPlural(
      pluralKey,
      pluralCount,
      oneEnglish: oneMessage,
      otherEnglish: _message,
      zeroEnglish: _zeroMessage,
      twoEnglish: _twoMessage,
      fewEnglish: _fewMessage,
      manyEnglish: _manyMessage,
      arguments: messageArguments,
    );
  }

  String? get fix => _fix == null ? null : huiText(_fix, fixArguments);

  @override
  String toString() => '${severity.name.toUpperCase()} $path: $message';
}

/// The one document-level note every Gloss content kind shares: which
/// `|metric.<key>|` references its text carries.
///
/// Informational, never a warning — a key the editor cannot resolve is not an
/// authoring mistake. `IntegrationBridgeService` registers one function per key
/// another Volmit plugin publishes, and the editor has no bridge, so the token
/// renders as a chip here and as `MetricFormat.compact` of the last sample in
/// game. Returns null when [texts] reference no metrics.
///
/// Lives here rather than in `gloss_text.dart` because it builds a [HuiIssue];
/// every Gloss validator already imports this library for that type.
HuiIssue? glossMetricInfo(Iterable<String> texts, {String path = r'$'}) {
  final List<String> keys = <String>[];
  for (final String text in texts) {
    for (final String key in glossLineMetricRefs(text)) {
      if (!keys.contains(key)) keys.add(key);
    }
  }
  if (keys.isEmpty) return null;
  return HuiIssue.plural(
    severity: HuiSeverity.info,
    path: path,
    pluralKey: 'validation.integration_metrics',
    count: keys.length,
    oneEnglish:
        'Reads the metric {keys} from other Volmit plugins through the '
        'integration bridge. The editor has no bridge, so it previews as '
        'its token; in game it is empty until the first sample lands.',
    otherEnglish:
        'Reads {count} metrics {keys} from other Volmit plugins through the '
        'integration bridge. The editor has no bridge, so each one previews '
        'as its token; in game it is empty until the first sample lands.',
    messageArguments: <String, Object?>{'keys': keys.join(', ')},
    fix:
        'Nothing to fix if the publishing plugin is installed. Check the key '
        'spelling if it stays blank in game.',
  );
}

List<HuiIssue> glossTextExpressionIssues(
  Iterable<({String path, String text})> fields, {
  bool playerBacked = true,
}) {
  final List<HuiIssue> issues = <HuiIssue>[];
  for (final ({String path, String text}) field in fields) {
    final GlossLineRender rendered = renderGlossLine(field.text);
    for (final String error in rendered.expressionErrors) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.warning,
          path: field.path,
          message:
              "This Gloss expression cannot run: {error}. The raw {{ ... }} code stays visible in game.",
          messageArguments: <String, Object?>{'error': error},
          fix: 'Correct the expression syntax, function, variable, or type.',
        ),
      );
    }
    if (!playerBacked &&
        rendered.expressions.any(
          (String source) =>
              source.contains('papi(') ||
              source.contains('papiNumber(') ||
              source.contains('player.'),
        )) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.warning,
          path: field.path,
          message:
              'This expression needs a player, but a server-list MOTD is '
              'chosen before any player exists. It cannot read PAPI, player '
              'state, or the client\'s current ping.',
          fix:
              'Use time, static text, animations, server values, or metrics '
              'in MOTDs; keep player expressions on player-backed surfaces.',
        ),
      );
    }
  }
  return issues;
}

/// Semantic validation against the Java parser's real behaviour. Catalog sets
/// are optional: when omitted, catalog membership is not checked.
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
  GlossEmojiResolver emoji = const GlossNoEmoji(),
}) {
  final _Validator validator = _Validator(
    knownImagePaths: knownImagePaths,
    knownMaterials: knownMaterials,
    knownSounds: knownSounds,
    customItems: customItems,
    overlaps: overlaps,
    emoji: emoji,
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

/// The merged plugin's one root plus its Director aliases
/// (`CommandGloss.java:10`). Director resolves both command and subcommand
/// names with `equalsIgnoreCase`.
const Set<String> _glossCommandRoots = <String>{'gloss', 'gl', 'glo', 'gg'};

/// The retired `/holoui` root and its aliases (`HoloCommand.java:38` in the
/// pre-merger plugin). The merged plugin registers NONE of these — a click
/// dispatching one prints Bukkit's unknown-command line — but imports
/// carrying them stay recognized forever so old documents never hard-fail;
/// validation warns and names the `/gloss` replacement instead.
const Set<String> _retiredHoloCommandRoots = <String>{
  'holoui',
  'holo',
  'hui',
  'holou',
  'hu',
};

/// The `/gloss menu` subtree's group name plus its alias
/// (`CommandGlossMenu.java:36`).
const Set<String> _glossMenuGroupNames = <String>{'menu', 'menus'};

/// `/gloss menu` subcommands (`CommandGlossMenu.java`), used to spell the
/// replacement for a retired `/holoui <sub>` — the old tree's root-level
/// subs moved under `menu` wholesale.
const Set<String> _glossMenuSubcommands = <String>{
  'list',
  'create',
  'open',
  'back',
  'close',
  'move',
  'builder',
  'edit',
  'addrow',
  'insertrow',
  'setrow',
  'removerow',
  'offsetrow',
  'seticon',
  'style',
  'image',
  'new',
  'copy',
};

/// Subcommands that return early unless the sender is a `Player`.
const Set<String> _huiPlayerOnlySubcommands = <String>{
  'open',
  'back',
  'close',
  'move',
};

final RegExp _whitespacePattern = RegExp(r'\s+');

List<String> _commandTokens(String command) {
  final String trimmed = command.trim();
  final String body = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
  return body
      .split(_whitespacePattern)
      .where((String token) => token.isNotEmpty)
      .toList();
}

/// The player-only subcommand [command] dispatches, or null. Recognizes both
/// trees: the merged `/gloss menu <sub>` (`CommandGlossMenu.java`) and the
/// retired flat `/holoui <sub>`.
///
/// `open` is the exception in both: its menu argument defaults to `*`, and
/// `*` returns through `list(sender)` before the Player check
/// (`CommandGlossMenu.java:134-137`), so a bare `open` genuinely does work
/// from the console.
String? huiPlayerOnlySubcommand(String command) =>
    _playerOnlyCommand(command)?.subcommand;

/// The player-only command as the file spells its tree — `gloss menu move`
/// or `holoui move` — for messages that quote it. Null when [command] is not
/// player-only.
String? huiPlayerOnlyCommandLabel(String command) {
  final ({String label, String subcommand})? match = _playerOnlyCommand(
    command,
  );
  return match?.label;
}

({String label, String subcommand})? _playerOnlyCommand(String command) {
  final List<String> tokens = _commandTokens(command);
  if (tokens.length < 2) return null;
  final String root = tokens[0].toLowerCase();
  final String subcommand;
  final String label;
  final List<String> arguments;
  if (_glossCommandRoots.contains(root)) {
    // The merged tree: the player-only subs live under `gloss menu`.
    if (tokens.length < 3 ||
        !_glossMenuGroupNames.contains(tokens[1].toLowerCase())) {
      return null;
    }
    subcommand = tokens[2].toLowerCase();
    label = 'gloss menu $subcommand';
    arguments = tokens.sublist(3);
  } else if (_retiredHoloCommandRoots.contains(root)) {
    // The retired flat tree, kept recognized for imported documents.
    subcommand = tokens[1].toLowerCase();
    label = 'holoui $subcommand';
    arguments = tokens.sublist(2);
  } else {
    return null;
  }
  if (!_huiPlayerOnlySubcommands.contains(subcommand)) return null;
  if (subcommand == 'open' && (arguments.isEmpty || arguments[0] == '*')) {
    return null;
  }
  return (label: label, subcommand: subcommand);
}

/// The `/gloss` spelling a retired `/holoui` command should use, or null
/// when [command] does not target a retired root. Known old subcommands
/// moved under `gloss menu`; anything else at least moves to the `/gloss`
/// root.
String? huiRetiredCommandReplacement(String command) {
  final List<String> tokens = _commandTokens(command);
  if (tokens.isEmpty) return null;
  if (!_retiredHoloCommandRoots.contains(tokens[0].toLowerCase())) {
    return null;
  }
  if (tokens.length >= 2 &&
      _glossMenuSubcommands.contains(tokens[1].toLowerCase())) {
    return <String>[
      'gloss menu',
      tokens[1].toLowerCase(),
      ...tokens.sublist(2),
    ].join(' ');
  }
  return <String>['gloss', ...tokens.sublist(1)].join(' ');
}

final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_.-]+$');
final RegExp _registryKeyPattern = RegExp(r'^([a-z0-9_.-]+:)?[a-z0-9_./-]+$');
final RegExp _worldKeyPattern = RegExp(r'^[a-z0-9._-]+:[a-z0-9/._-]+$');
final RegExp _proxyServerPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$');
final RegExp _argbColorPattern = RegExp(r'^#[0-9A-Fa-f]{8}$');

/// Everything Mojang could have issued as a username: 1 to 16 characters of
/// `[A-Za-z0-9_]` and nothing else (`PlayerHeadService.java:88-100`). Anything
/// that fails this is answered UNKNOWN without a request.
final RegExp _minecraftNamePattern = RegExp(r'^[A-Za-z0-9_]{1,16}$');

/// The three tokens Gloss resolves to the viewer itself, already normalized
/// the way `PlayerHeadMenuIcon.isViewerToken` does it — lowercased with spaces
/// stripped (`PlayerHeadMenuIcon.java:90-95`).
const Set<String> _playerHeadViewerTokens = <String>{
  '%player_name%',
  '%player%',
  '{{player.name}}',
};

class _Validator {
  _Validator({
    this.knownImagePaths,
    this.knownMaterials,
    this.knownSounds,
    this.customItems,
    this.overlaps = const <CanvasOverlap>[],
    this.emoji = const GlossNoEmoji(),
  });

  final Set<String>? knownImagePaths;
  final Set<String>? knownMaterials;
  final Set<String>? knownSounds;
  final HuiCustomItemCatalog? customItems;
  final GlossEmojiResolver emoji;

  /// Intersecting clickable hitboxes, resolved by the caller's scene.
  final List<CanvasOverlap> overlaps;
  final List<HuiIssue> issues = <HuiIssue>[];

  String? _componentId;

  void _add(
    HuiSeverity severity,
    String path,
    String message, {
    String? fix,
    Map<String, Object?> messageArguments = const <String, Object?>{},
    Map<String, Object?> fixArguments = const <String, Object?>{},
  }) {
    issues.add(
      HuiIssue(
        severity: severity,
        path: path,
        message: message,
        messageArguments: messageArguments,
        componentId: _componentId,
        fix: fix,
        fixArguments: fixArguments,
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

    _validateFiniteVector(menu.offset, 'offset', 'Menu offset');

    final double? maxDistance = menu.maxDistance;
    if (maxDistance != null && !maxDistance.isFinite) {
      _add(
        HuiSeverity.error,
        'maxDistance',
        'maxDistance must be a finite number',
        fix: 'Use a finite distance, or clear it for unlimited',
      );
    } else if (maxDistance != null &&
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
        'Gloss has no menu "name" field: the menu id is the file base name. '
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

  /// One issue per pair, anchored on the first component: nearest-hit
  /// arbitration can hide the farther clickable across their shared region.
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
        "Hitbox overlaps \"{secondId}\": only the nearest component fires, so one can hide the other across this region",
        fix: 'Move or shrink one of them, or make one a decoration',
        messageArguments: <String, Object?>{'secondId': overlap.secondId},
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
    _validateFiniteVector(component.offset, '$path.offset', 'Component offset');

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
          "Duplicate component id \"{id}\": the plugin keeps the first component and ignores later duplicates",
          fix: 'Rename this component to a unique id',
          messageArguments: <String, Object?>{'id': id},
        );
      }
    }

    switch (component.data) {
      case final HuiButtonData data:
        _validateHighlight(data.highlightModifier, '$path.data');
        _validateHoverDuration(data.hoverDurationTicks, '$path.data');
        _validateHitbox(data.hitbox, '$path.data.hitbox');
        _validateIcon(data.icon, '$path.data.icon', clickable: true);
        _validateActions(data.actions, '$path.data.actions');
      case final HuiDecorationData data:
        _validateIcon(data.icon, '$path.data.icon', clickable: false);
      case final HuiToggleData data:
        _validateHighlight(data.highlightModifier, '$path.data');
        _validateHoverDuration(data.hoverDurationTicks, '$path.data');
        _validateHitbox(data.hitbox, '$path.data.hitbox');
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
    if (!value.isFinite) {
      _add(
        HuiSeverity.error,
        '$path.highlightModifier',
        'highlightModifier must be a finite number',
        fix: 'Use a finite value between 0 and 1 (0.05 is typical)',
      );
    } else if (value < 0 || value > 1) {
      _add(
        HuiSeverity.warning,
        '$path.highlightModifier',
        'highlightModifier is outside 0..1 and a value read from a file is '
            'used verbatim - the API clamp never sees it. It is a distance in '
            'blocks along the plane normal, so large values push the icon '
            'through the player and negative ones push it away',
        fix: 'Use a value between 0 and 1 (0.05 is typical)',
      );
    }
  }

  void _validateHoverDuration(int value, String path) {
    if (value < 0 || value > 40) {
      _add(
        HuiSeverity.error,
        '$path.hoverDurationTicks',
        'hoverDurationTicks must be between 0 and 40',
        fix: 'Use 4 ticks for the runtime default, or 0 for an instant hover',
      );
    }
  }

  void _validateFiniteVector(Vec3 value, String path, String label) {
    if (!value.x.isFinite || !value.y.isFinite || !value.z.isFinite) {
      _add(
        HuiSeverity.error,
        path,
        "{label} components must be finite numbers",
        fix: 'Set finite right, up and forward offsets',
        messageArguments: <String, Object?>{'label': label},
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
    if (icon is HuiEntityIcon && icon.extras.containsKey('style')) {
      _add(
        HuiSeverity.error,
        '$path.style',
        'Entity icons do not accept display-entity style metadata',
        fix: 'Remove style; use entity width and height for its footprint',
      );
    } else {
      _validateIconStyle(icon.style, '$path.style');
    }
    switch (icon) {
      case final HuiTextIcon text:
        _validateText(
          text.text,
          '$path.text',
          clickable: clickable,
          refreshTicks: text.refreshTicks,
        );
        final int? refreshTicks = text.refreshTicks;
        if (refreshTicks != null && (refreshTicks < 0 || refreshTicks > 1200)) {
          _add(
            HuiSeverity.error,
            '$path.refreshTicks',
            'Dynamic text refresh must be between 0 and 1200 ticks',
            fix: 'Use 10 for twice-per-second updates, or 0 to disable them',
          );
        }
      case final HuiTextImageIcon image:
        _validateImagePath(image.path, '$path.path');
      case final HuiAnimatedImageIcon animated:
        if (animated.source.isEmpty) {
          _add(
            HuiSeverity.error,
            '$path.source',
            'Animated icon has no frames; the plugin logs the icon failure and '
                'draws the magenta/black missing-icon placeholder',
            fix: 'Add at least one frame image',
          );
        }
        for (int i = 0; i < animated.source.length; i++) {
          _validateImagePath(animated.source[i], '$path.source[$i]');
        }
        if (animated.speed < 2 || animated.speed > 1200) {
          _add(
            HuiSeverity.error,
            '$path.speed',
            'Animated image speed must be between 2 and 1200 ticks',
          );
        }
      case final HuiItemIcon item:
        _validateMaterial(item.item, '$path.item');
      case final HuiBlockIcon block:
        _validateBlock(block, path);
      case final HuiCustomItemIcon custom:
        _validateCustomItem(custom, path);
      case final HuiEntityIcon entity:
        _validateEntity(entity, path);
      case final HuiPlayerHeadIcon head:
        _validatePlayerHead(head, path);
    }
  }

  void _validateIconStyle(HuiIconStyle? style, String path) {
    if (style == null) return;
    if (!huiIconBillboards.contains(style.billboard)) {
      _add(
        HuiSeverity.error,
        '$path.billboard',
        "Unknown billboard mode \"{billboard}\"",
        fix: 'Use fixed, vertical, horizontal or center',
        messageArguments: <String, Object?>{'billboard': style.billboard},
      );
    }
    if (!huiIconTextAlignments.contains(style.textAlignment)) {
      _add(
        HuiSeverity.error,
        '$path.textAlignment',
        "Unknown text alignment \"{textAlignment}\"",
        fix: 'Use center, left or right',
        messageArguments: <String, Object?>{
          'textAlignment': style.textAlignment,
        },
      );
    }
    _validateArgb(style.backgroundArgb, '$path.backgroundArgb');
    if (style.glowColor != null) {
      _validateArgb(style.glowColor!, '$path.glowColor');
    }
    _validateStyleNumber(
      style.textOpacity.toDouble(),
      '$path.textOpacity',
      0,
      255,
    );
    _validateStyleNumber(
      style.lineWidth.toDouble(),
      '$path.lineWidth',
      1,
      16384,
    );
    if ((style.blockLight == null) != (style.skyLight == null)) {
      _add(
        HuiSeverity.error,
        path,
        'blockLight and skyLight must be supplied together',
        fix: 'Set both brightness values, or remove both',
      );
    }
    if (style.blockLight != null) {
      _validateStyleNumber(
        style.blockLight!.toDouble(),
        '$path.blockLight',
        0,
        15,
      );
    }
    if (style.skyLight != null) {
      _validateStyleNumber(style.skyLight!.toDouble(), '$path.skyLight', 0, 15);
    }
    _validateStyleNumber(style.viewRange, '$path.viewRange', 0.01, 64);
    _validateStyleNumber(style.shadowRadius, '$path.shadowRadius', 0, 64);
    _validateStyleNumber(style.shadowStrength, '$path.shadowStrength', 0, 1);
    _validateStyleNumber(style.cullingWidth, '$path.cullingWidth', 0, 4096);
    _validateStyleNumber(style.cullingHeight, '$path.cullingHeight', 0, 4096);
    _validateStyleNumber(style.scaleX, '$path.scaleX', 0.01, 64);
    _validateStyleNumber(style.scaleY, '$path.scaleY', 0.01, 64);
    _validateStyleNumber(style.scaleZ, '$path.scaleZ', 0.01, 64);
  }

  void _validateArgb(String value, String path) {
    if (_argbColorPattern.hasMatch(value)) return;
    _add(
      HuiSeverity.error,
      path,
      'ARGB color must use exactly eight hexadecimal digits',
      fix: 'Use #AARRGGBB, for example #80000000',
    );
  }

  void _validateStyleNumber(
    double value,
    String path,
    double minimum,
    double maximum,
  ) {
    if (value.isFinite && value >= minimum && value <= maximum) return;
    _add(
      HuiSeverity.error,
      path,
      "Display style value must be finite and between {minimum} and {maximum}",
      fix: 'Set a value in the supported range',
      messageArguments: <String, Object?>{
        'minimum': minimum,
        'maximum': maximum,
      },
    );
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

    final String provider = icon.provider.trim().toLowerCase();
    if (provider.isNotEmpty &&
        provider != huiAutoItemProvider &&
        !huiCustomItemProviders.contains(provider)) {
      _add(
        HuiSeverity.warning,
        '$path.provider',
        "Unknown item provider \"{provider}\"; Gloss has no adapter for it and the icon will not resolve",
        fix: "Use one of {join}, or auto",
        messageArguments: <String, Object?>{'provider': provider},
        fixArguments: <String, Object?>{
          'join': huiCustomItemProviders.join(", "),
        },
      );
    }

    if (icon.count < 1 || icon.count > huiMaxStackCount) {
      _add(
        HuiSeverity.warning,
        '$path.count',
        "Stack count is outside 1-{huiMaxStackCount}; the plugin turns anything below 1 into 1 and the client cannot draw a larger stack",
        fix: "Use a count between 1 and {huiMaxStackCount}",
        messageArguments: <String, Object?>{
          'huiMaxStackCount': huiMaxStackCount,
        },
        fixArguments: <String, Object?>{'huiMaxStackCount': huiMaxStackCount},
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
        "\"{id}\" is not in the custom item catalog exported from your server; the server is the only thing that can confirm it",
        fix: 'Re-run /gloss item export if you added the item recently',
        messageArguments: <String, Object?>{'id': id},
      );
    }
  }

  void _validateEntity(HuiEntityIcon icon, String path) {
    final String key = icon.entity.trim();
    if (key.isEmpty) {
      _add(
        HuiSeverity.error,
        '$path.entity',
        'Entity type is empty',
        fix: 'Pick a spawnable living entity such as minecraft:parrot',
      );
      _validateEntityDimension(icon.width, '$path.width', 'width');
      _validateEntityDimension(icon.height, '$path.height', 'height');
      return;
    }
    if (key != icon.entity || key != key.toLowerCase()) {
      _add(
        HuiSeverity.error,
        '$path.entity',
        'Entity type must be lowercase with no surrounding whitespace',
        fix: "Use {toLowerCase}",
        fixArguments: <String, Object?>{'toLowerCase': key.toLowerCase()},
      );
    }
    if (!_registryKeyPattern.hasMatch(key)) {
      _add(
        HuiSeverity.error,
        '$path.entity',
        'Entity type must be a lowercase namespaced registry id',
        fix: 'Use an id such as minecraft:parrot',
      );
    } else if (!huiSpawnableLivingEntityTypes.contains(
      key.contains(':') ? key : 'minecraft:$key',
    )) {
      _add(
        HuiSeverity.error,
        '$path.entity',
        'Entity type is not a supported spawnable living entity',
        fix: 'Pick one from the entity browser',
      );
    }
    _validateEntityDimension(icon.width, '$path.width', 'width');
    _validateEntityDimension(icon.height, '$path.height', 'height');
  }

  /// A head resolves in three steps, and each one has its own failure mode:
  /// Gloss answers the viewer tokens itself, the text pipeline answers
  /// everything else with a `%` or `{{` in it, and whatever comes out has to
  /// look like a username before `PlayerHeadService` will spend a request on
  /// it (`PlayerHeadService.java:88-100`). Only the first step is knowable
  /// here, so the middle one is an info and the last one is an error solely
  /// when no placeholder could have changed the string on the way.
  void _validatePlayerHead(HuiPlayerHeadIcon icon, String path) {
    final String source = icon.player;
    final String trimmed = source.trim();
    bool viewerDependent = false;
    if (trimmed.isEmpty) {
      _add(
        HuiSeverity.error,
        '$path.player',
        'Player head has no player name; the plugin throws a menu icon '
            'exception and draws the magenta/black missing-icon placeholder '
            'instead of a head',
        fix: 'Enter a username, or %player_name% for the viewer\'s own head',
      );
    } else {
      if (source != trimmed) {
        _add(
          HuiSeverity.warning,
          '$path.player',
          'The name starts or ends with whitespace; the plugin trims it '
              'before every lookup, so the padding is only stored, never used',
          fix: 'Remove the surrounding whitespace',
        );
      }
      final bool viewerToken = _playerHeadViewerTokens.contains(
        trimmed.toLowerCase().replaceAll(' ', ''),
      );
      final bool placeholder = trimmed.contains('%') || trimmed.contains('{{');
      viewerDependent = viewerToken || placeholder;
      if (viewerToken) {
        // Nothing to say: Gloss answers these three itself, with or without
        // PlaceholderAPI installed.
      } else if (placeholder) {
        _add(
          HuiSeverity.info,
          '$path.player',
          'This name is resolved by the text pipeline, so it needs whatever '
              'provides the placeholder; PlaceholderAPI is optional and an '
              'unresolved token draws the fallback head',
          fix:
              'Use %player_name%, %player% or {{player.name}} for the '
              'viewer\'s own head, which Gloss answers without any plugin',
        );
      } else if (!_minecraftNamePattern.hasMatch(trimmed)) {
        _add(
          HuiSeverity.error,
          '$path.player',
          "\"{trimmed}\" can never resolve: a lookup needs 1 to 16 characters of A-Z, a-z, 0-9 or underscore, so this icon always draws the fallback head",
          fix: 'Use a Minecraft username, or a placeholder that expands to one',
          messageArguments: <String, Object?>{'trimmed': trimmed},
        );
      }
    }

    final int? refreshTicks = icon.refreshTicks;
    if (refreshTicks != null && (refreshTicks < 0 || refreshTicks > 1200)) {
      _add(
        HuiSeverity.error,
        '$path.refreshTicks',
        'Head refresh must be between 0 and 1200 ticks; the plugin throws on '
            'anything else and the whole menu document is rejected',
        fix: 'Use 20 for once a second, or 0 to never re-read the name',
      );
    } else if (refreshTicks == 0 && viewerDependent) {
      _add(
        HuiSeverity.warning,
        '$path.refreshTicks',
        'This name changes per viewer but 0 never re-reads it; the first '
            'render is always a pending lookup, so the head stays the blank '
            'unowned one until something respawns the component',
        fix: 'Use 20, or leave the key off to get the runtime default',
      );
    }
  }

  void _validateBlock(HuiBlockIcon icon, String path) {
    final String key = icon.block;
    if (key.isEmpty) {
      _add(
        HuiSeverity.error,
        '$path.block',
        'Block material is empty',
        fix: 'Pick a block such as minecraft:stone',
      );
      return;
    }
    if (key != key.trim() || key != key.toLowerCase()) {
      _add(
        HuiSeverity.error,
        '$path.block',
        'Block material must be lowercase with no surrounding whitespace',
        fix: "Use {toLowerCase}",
        fixArguments: <String, Object?>{
          'toLowerCase': key.trim().toLowerCase(),
        },
      );
    }
    if (!_registryKeyPattern.hasMatch(key)) {
      _add(
        HuiSeverity.error,
        '$path.block',
        'Block material must be a lowercase registry id',
        fix: 'Use an id such as stone or minecraft:stone',
      );
      return;
    }
    final Set<String>? known = knownMaterials;
    if (known != null && !_inCatalog(key, known)) {
      _add(
        HuiSeverity.error,
        '$path.block',
        "Block material \"{key}\" is not in the material catalog",
        fix: 'Pick a known Bukkit block material',
        messageArguments: <String, Object?>{'key': key},
      );
      return;
    }
    if (!huiIsBlockLikeMaterial(key)) {
      _add(
        HuiSeverity.error,
        '$path.block',
        "Material \"{key}\" is not a block",
        fix: 'Pick a block from the block browser',
        messageArguments: <String, Object?>{'key': key},
      );
    }
  }

  void _validateEntityDimension(double value, String path, String label) {
    if (value.isFinite && value > 0 && value <= 64) return;
    _add(
      HuiSeverity.error,
      path,
      "Entity {label} must be finite, greater than 0, and at most 64 blocks",
      fix: "Set a positive {label} between 0 and 64 blocks",
      messageArguments: <String, Object?>{'label': label},
      fixArguments: <String, Object?>{'label': label},
    );
  }

  void _validateText(
    String text,
    String path, {
    required bool clickable,
    required int? refreshTicks,
  }) {
    // The hitbox is measured on what the icon actually renders, so the emoji
    // and bracket-hex prelude runs first — an emoji token is wider as source
    // than as the glyph it becomes. Plain length never exceeds the resolved
    // length (parsing only strips tags), so a short field still skips the
    // parse entirely — this runs on every keystroke.
    final String resolved = glossRenderMenuText(text, emoji: emoji);
    if (clickable && resolved.length >= huiWideTextHitboxChars) {
      final int chars = parseMcText(resolved).maxLineLength;
      if (chars >= huiWideTextHitboxChars) {
        final String blocks = (chars * huiLineHeight / 2).toStringAsFixed(2);
        _add(
          HuiSeverity.info,
          path,
          "Text hitboxes are sized by character count, not by how wide the glyphs look: {chars} characters make this click plane {blocks} blocks wide at UI scale 1",
          fix:
              'Shorten the line, or leave room around it; the canvas hitbox '
              'outline shows the real extent',
          messageArguments: <String, Object?>{'chars': chars, 'blocks': blocks},
        );
      }
    }

    if (glossMenuTextNeedsRefresh(text)) {
      final bool frozen = refreshTicks == 0;
      _add(
        HuiSeverity.info,
        path,
        frozen
            ? 'Uses dynamic text: it is rendered when the icon opens and '
                  'then frozen because refreshTicks is 0'
            : 'Uses live functions, expressions or PAPI: it refreshes every '
                  '{ticks} ticks. Native Gloss values do not '
                  'require PlaceholderAPI.',
        fix: null,
        messageArguments: frozen
            ? const <String, Object?>{}
            : <String, Object?>{'ticks': refreshTicks ?? 10},
      );
    }
  }

  void _validateImagePath(String path, String jsonPath) {
    if (path.trim().isEmpty) {
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
        'plugins/Gloss/images/',
        fix: 'Drop the leading slash',
      );
    }
    if (path.contains(':')) {
      _add(
        HuiSeverity.error,
        jsonPath,
        'Image path must not contain ":"',
        fix: 'Use a path relative to plugins/Gloss/images/',
      );
    }
    if (path.contains('..')) {
      _add(
        HuiSeverity.error,
        jsonPath,
        'Image path must not contain ".."',
        fix: 'Use a path relative to plugins/Gloss/images/',
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
        "Image \"{path}\" is not in the image library; make sure it exists in plugins/Gloss/images/",
        fix: 'Upload the image so it ships with the exported zip',
        messageArguments: <String, Object?>{'path': path},
      );
    }
  }

  void _validateMaterial(String material, String path) {
    if (material.isEmpty) {
      _add(
        HuiSeverity.error,
        path,
        'Material key is empty; the icon falls back to the missing-icon '
        'placeholder',
        fix: 'Pick a material such as diamond_sword',
      );
      return;
    }
    if (material != material.toLowerCase()) {
      _add(
        HuiSeverity.error,
        path,
        'Material key must be lowercase: NamespacedKey rejects uppercase, so '
        'the item resolves to null and the icon falls back to the '
        'missing-icon placeholder',
        fix: "Use {toLowerCase}",
        fixArguments: <String, Object?>{'toLowerCase': material.toLowerCase()},
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
        "Material \"{material}\" is not in the material catalog; it may still be valid on a newer server",
        fix: 'Double-check the spelling against the item picker',
        messageArguments: <String, Object?>{'material': material},
      );
    }
  }

  void _validateActions(List<HuiAction> actions, String path) {
    for (int i = 0; i < actions.length; i++) {
      final HuiAction action = actions[i];
      final String actionPath = '$path[$i]';
      if (!huiActionTriggers.contains(action.trigger)) {
        _add(
          HuiSeverity.error,
          '$actionPath.trigger',
          "Action trigger \"{trigger}\" is not recognized",
          fix: "Use {join}",
          messageArguments: <String, Object?>{'trigger': action.trigger},
          fixArguments: <String, Object?>{'join': huiActionTriggers.join(", ")},
        );
      }
      switch (action) {
        case final HuiCommandAction command:
          _validateCommand(command, actionPath);
        case final HuiSoundAction sound:
          _validateSound(sound, actionPath);
        case final HuiMessageAction message:
          _validateMessage(message, actionPath);
        case final HuiTeleportAction teleport:
          _validateTeleport(teleport, actionPath);
        case final HuiConnectAction connect:
          _validateConnect(connect, actionPath);
        case final HuiNavigateAction navigation:
          _validateNavigation(navigation, actionPath);
          if (_hasMatchingActionAfter(actions, i, navigation.trigger)) {
            _add(
              HuiSeverity.warning,
              actionPath,
              'Navigation stops later actions with the same click trigger',
              fix: 'Move navigation after actions bound to the same trigger',
            );
          }
      }
    }
  }

  bool _hasMatchingActionAfter(
    List<HuiAction> actions,
    int index,
    String navigationTrigger,
  ) {
    for (int next = index + 1; next < actions.length; next++) {
      final String nextTrigger = actions[next].trigger;
      if (navigationTrigger == 'any' ||
          nextTrigger == 'any' ||
          nextTrigger == navigationTrigger) {
        return true;
      }
    }
    return false;
  }

  void _validateMessage(HuiMessageAction action, String path) {
    if (action.message.trim().isEmpty) {
      _add(
        HuiSeverity.error,
        '$path.message',
        'Message is empty; the plugin logs the invalid action and drops it',
        fix: 'Enter the MiniMessage text sent to the clicking player',
      );
    }
    final String lowercase = action.message.toLowerCase();
    if (lowercase.contains('<click:') || lowercase.contains('<insert:')) {
      _add(
        HuiSeverity.warning,
        '$path.message',
        'Message click and insertion events are stripped by the runtime',
        fix: 'Keep MiniMessage formatting, but remove interactive tags',
      );
    }
  }

  void _validateTeleport(HuiTeleportAction action, String path) {
    if (action.world.length > 255 || !_worldKeyPattern.hasMatch(action.world)) {
      _add(
        HuiSeverity.error,
        '$path.world',
        'World must be an explicit lowercase namespace:key',
        fix: 'Use a loaded world key such as minecraft:overworld',
      );
    }
    _validateActionNumber(action.x, '$path.x', 'Teleport X');
    _validateActionNumber(action.y, '$path.y', 'Teleport Y');
    _validateActionNumber(action.z, '$path.z', 'Teleport Z');
    _validateActionNumber(action.yaw, '$path.yaw', 'Teleport yaw');
    _validateActionNumber(action.pitch, '$path.pitch', 'Teleport pitch');
  }

  void _validateConnect(HuiConnectAction action, String path) {
    if (!_proxyServerPattern.hasMatch(action.server)) {
      _add(
        HuiSeverity.error,
        '$path.server',
        'Proxy server name must be 1-64 letters, numbers, dots, underscores, or hyphens',
        fix: 'Enter the exact server name configured on BungeeCord or Velocity',
      );
    }
  }

  void _validateActionNumber(double value, String path, String label) {
    if (!value.isFinite) {
      _add(
        HuiSeverity.error,
        path,
        "{label} must be a finite number",
        fix: 'Enter a normal numeric value',
        messageArguments: <String, Object?>{'label': label},
      );
    }
  }

  void _validateNavigation(HuiNavigateAction action, String path) {
    if (!huiNavigationModes.contains(action.mode)) {
      _add(
        HuiSeverity.error,
        '$path.mode',
        "Navigation mode \"{mode}\" is not recognized",
        fix: "Use {join}",
        messageArguments: <String, Object?>{'mode': action.mode},
        fixArguments: <String, Object?>{'join': huiNavigationModes.join(", ")},
      );
    }
    if (action.requiresTarget && action.target.trim().isEmpty) {
      _add(
        HuiSeverity.error,
        '$path.target',
        'Push and replace navigation require a target menu',
        fix: 'Choose the menu page this action should open',
      );
    }
    final String? targetProblem = action.requiresTarget
        ? validateMenuId(action.target)
        : null;
    if (targetProblem != null && action.target.trim().isNotEmpty) {
      _add(
        HuiSeverity.error,
        '$path.target',
        targetProblem,
        fix: 'Use a canonical id such as shops/confirm',
      );
    }
  }

  void _validateCommand(HuiCommandAction action, String path) {
    if (action.command.trim().isEmpty) {
      _add(
        HuiSeverity.error,
        '$path.command',
        'Command is empty; the plugin logs the invalid action and drops it',
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
    // The merged plugin has no /holoui root: the command still dispatches,
    // but Bukkit answers with its unknown-command line. Old imports must
    // never hard-fail on this, so it warns and names the /gloss spelling.
    final String? replacement = huiRetiredCommandReplacement(action.command);
    if (replacement != null) {
      _add(
        HuiSeverity.warning,
        '$path.command',
        'This command targets the retired /holoui root; the merged Gloss '
            'plugin does not register it, so clicking prints an '
            'unknown-command message',
        fix: "Use \"{replacement}\"",
        fixArguments: <String, Object?>{'replacement': replacement},
      );
    }

    // Imported Java enum names have already been canonicalized. A genuinely
    // unknown spelling resolves to null and takes the player default.
    final bool consoleForCertain = action.source == 'server';
    final String? playerOnly = huiPlayerOnlyCommandLabel(action.command);

    if (playerOnly != null && consoleForCertain) {
      _add(
        HuiSeverity.warning,
        '$path.source',
        "\"{playerOnly}\" only works for a player, and source \"server\" runs this action from the console, so clicking does nothing but print a player-only notice to the server log",
        fix: 'Set the source to "player"',
        messageArguments: <String, Object?>{'playerOnly': playerOnly},
      );
    } else if (!huiCommandSources.contains(action.source)) {
      _add(
        HuiSeverity.warning,
        '$path.source',
        "Command source \"{source}\" is not recognized; Gloss resolves it to null and uses the player default",
        fix: 'Use "player" or "server"',
        messageArguments: <String, Object?>{'source': action.source},
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
        fix: "Use {toLowerCase}",
        fixArguments: <String, Object?>{'toLowerCase': sound.toLowerCase()},
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
          "Sound \"{sound}\" is not in the sound catalog; it may still be valid on a newer server",
          fix: 'Double-check the spelling against the sound picker',
          messageArguments: <String, Object?>{'sound': sound},
        );
      }
    }

    // An absent or unknown category is null to Gson and the plugin plays the
    // sound on master, so a bad spelling costs the category, not the click.
    if (action.source.trim().isNotEmpty &&
        !huiSoundSources.contains(action.source)) {
      _add(
        HuiSeverity.warning,
        '$path.source',
        "Sound source \"{source}\" is not one of {join}, so the sound falls back to master",
        fix: 'Pick a sound category, for example master',
        messageArguments: <String, Object?>{
          'source': action.source,
          'join': huiSoundSources.join(", "),
        },
      );
    }

    if (!action.volume.isFinite) {
      _add(
        HuiSeverity.error,
        '$path.volume',
        'Volume must be a finite number',
        fix: 'Use a finite volume such as 1',
      );
    } else if (action.volume == 0) {
      _add(
        HuiSeverity.warning,
        '$path.volume',
        'Volume 0 is inaudible; an omitted volume would default to 1',
        fix: 'Set the volume to 1',
      );
    }
    if (!action.pitch.isFinite) {
      _add(
        HuiSeverity.error,
        '$path.pitch',
        'Pitch must be a finite number',
        fix: 'Use a finite pitch such as 1',
      );
    } else if (action.pitch == 0) {
      _add(
        HuiSeverity.warning,
        '$path.pitch',
        'Pitch 0 is clamped up to 0.5 by the client; an omitted pitch would '
            'default to 1',
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
